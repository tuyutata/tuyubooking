import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';

final class DiscoveredTuyuBookingHost {
  const DiscoveredTuyuBookingHost({
    required this.address,
    required this.port,
    required this.instanceId,
    required this.merchantName,
    required this.apiVersion,
  });

  final String address;
  final int port;
  final String instanceId;
  final String merchantName;
  final String apiVersion;
}

final class TuyuBookingMdnsDiscovery {
  const TuyuBookingMdnsDiscovery();

  static const _multicast = '224.0.0.251';
  static const _port = 5353;
  static const _service = '_tuyubooking._tcp.local';
  static const _androidChannel = MethodChannel('tuyubooking/discovery');

  /// Runs once while a client initializes its fixed merchant-host address.
  Future<List<DiscoveredTuyuBookingHost>> discover({
    Duration timeout = const Duration(seconds: 3),
  }) async {
    if (Platform.isAndroid) {
      await _androidChannel.invokeMethod<void>('acquireMulticastLock');
    }
    RawDatagramSocket? socket;
    StreamSubscription<RawSocketEvent>? subscription;
    final hosts = <String, DiscoveredTuyuBookingHost>{};
    try {
      socket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        _port,
        reuseAddress: true,
        reusePort: true,
      );
      socket.joinMulticast(InternetAddress(_multicast));
      subscription = socket.listen((event) {
        if (event != RawSocketEvent.read) return;
        while (true) {
          final datagram = socket?.receive();
          if (datagram == null) break;
          final host = _parseResponse(datagram.data, datagram.address.address);
          if (host != null) hosts[host.instanceId] = host;
        }
      });
      socket.send(_query(), InternetAddress(_multicast), _port);
      await Future<void>.delayed(timeout);
      return hosts.values.toList(
        growable: false,
      )..sort((left, right) => left.merchantName.compareTo(right.merchantName));
    } finally {
      await subscription?.cancel();
      socket?.close();
      if (Platform.isAndroid) {
        await _androidChannel.invokeMethod<void>('releaseMulticastLock');
      }
    }
  }

  static Uint8List _query() {
    final bytes = BytesBuilder(copy: false)
      ..add([0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0])
      ..add(_encodeName(_service))
      ..add([0, 12, 0, 1]);
    return bytes.takeBytes();
  }

  static Uint8List _encodeName(String value) {
    final bytes = BytesBuilder(copy: false);
    for (final label in value.split('.')) {
      final encoded = Uint8List.fromList(label.codeUnits);
      bytes.addByte(encoded.length);
      bytes.add(encoded);
    }
    bytes.addByte(0);
    return bytes.takeBytes();
  }

  static DiscoveredTuyuBookingHost? _parseResponse(
    Uint8List bytes,
    String sourceAddress,
  ) {
    if (bytes.length < 12) return null;
    final reader = _DnsReader(bytes);
    var offset = 12;
    final questions = reader.u16(4);
    final records = reader.u16(6) + reader.u16(8) + reader.u16(10);
    for (var index = 0; index < questions; index++) {
      final name = reader.name(offset);
      offset = name.next + 4;
      if (offset > bytes.length) return null;
    }

    String? serviceInstance;
    int? servicePort;
    final text = <String, String>{};
    for (var index = 0; index < records; index++) {
      final owner = reader.name(offset);
      offset = owner.next;
      if (offset + 10 > bytes.length) return null;
      final type = reader.u16(offset);
      final length = reader.u16(offset + 8);
      final dataOffset = offset + 10;
      final next = dataOffset + length;
      if (next > bytes.length) return null;
      if (type == 12 && owner.value == _service) {
        serviceInstance = reader.name(dataOffset).value;
      } else if (type == 33 && owner.value.endsWith(_service) && length >= 6) {
        serviceInstance ??= owner.value;
        servicePort = reader.u16(dataOffset + 4);
      } else if (type == 16 && owner.value.endsWith(_service)) {
        serviceInstance ??= owner.value;
        var cursor = dataOffset;
        while (cursor < next) {
          final size = bytes[cursor++];
          if (cursor + size > next) break;
          final item = String.fromCharCodes(
            bytes.sublist(cursor, cursor + size),
          );
          cursor += size;
          final separator = item.indexOf('=');
          if (separator > 0) {
            text[item.substring(0, separator)] = item.substring(separator + 1);
          }
        }
      }
      offset = next;
    }
    if (serviceInstance == null ||
        servicePort == null ||
        text['protocol'] != 'TUYU/1' ||
        text['service'] != 'TuyuBooking' ||
        text['instance_id']?.isEmpty != false) {
      return null;
    }
    return DiscoveredTuyuBookingHost(
      address: sourceAddress,
      port: servicePort,
      instanceId: text['instance_id']!,
      merchantName: text['merchant_name']?.trim().isNotEmpty == true
          ? text['merchant_name']!.trim()
          : serviceInstance.split('.').first,
      apiVersion: text['api_version'] ?? '1',
    );
  }
}

final class _DnsName {
  const _DnsName(this.value, this.next);
  final String value;
  final int next;
}

final class _DnsReader {
  const _DnsReader(this.bytes);
  final Uint8List bytes;

  int u16(int offset) => ByteData.sublistView(bytes).getUint16(offset);

  _DnsName name(int start) {
    final labels = <String>[];
    final visited = <int>{};
    var offset = start;
    int? next;
    while (offset < bytes.length) {
      if (!visited.add(offset)) throw const FormatException('DNS name loop');
      final length = bytes[offset++];
      if (length == 0) {
        next ??= offset;
        break;
      }
      if ((length & 0xc0) == 0xc0) {
        if (offset >= bytes.length) throw const FormatException('DNS pointer');
        next ??= offset + 1;
        offset = ((length & 0x3f) << 8) | bytes[offset];
        continue;
      }
      if (offset + length > bytes.length) {
        throw const FormatException('DNS label');
      }
      labels.add(String.fromCharCodes(bytes.sublist(offset, offset + length)));
      offset += length;
    }
    return _DnsName(labels.join('.'), next ?? offset);
  }
}
