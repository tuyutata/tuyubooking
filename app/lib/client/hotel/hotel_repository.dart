import 'dart:convert';

import 'package:tuyubooking/client/hotel/hotel_models.dart';
import 'package:tuyubooking/client/employee_access/employee_session.dart';

enum HotelRepositoryFailure {
  unavailable,
  invalidResponse,
  permissionDenied,
  businessConflict,
}

final class HotelRepositoryException implements Exception {
  const HotelRepositoryException(this.failure);
  final HotelRepositoryFailure failure;
}

abstract interface class HotelDataSource {
  Future<List<HotelProperty>> loadProperties();
  Future<HotelSnapshot> loadSnapshot(String property);
  Future<HotelAvailability> loadAvailability(
    String property, {
    required String startDate,
    int days = 14,
  });
  Future<HotelBookingOptions> loadBookingOptions(String property);
  Future<List<HotelGuest>> searchGuests(String query);
  Future<HotelReservationDetail> loadReservationDetail(String reservation);
  Future<HotelBookingReceipt> createBooking(
    String property,
    HotelBookingRequest request,
  );
  Future<void> checkIn(String reservation);
  Future<void> checkOut(String reservation);
  Future<void> updateHousekeeping(String room, String status);
}

/// Thin Kamra adapter. Kamra remains authoritative for inventory and workflow.
final class HotelRepository implements HotelDataSource {
  const HotelRepository(this.session);

  final EmployeeSession session;

  @override
  Future<List<HotelProperty>> loadProperties() async =>
      hotelList(await _rpc('kamra.api.my_properties'))
          .map(hotelObject)
          .map(HotelProperty.fromJson)
          .where((property) => property.name.isNotEmpty)
          .toList(growable: false);

  @override
  Future<HotelSnapshot> loadSnapshot(String property) async =>
      HotelSnapshot.fromJson(
        hotelObject(
          await _rpc(
            'kamra.api.front_desk_snapshot',
            parameters: {'property': property},
          ),
        ),
      );

  @override
  Future<HotelAvailability> loadAvailability(
    String property, {
    required String startDate,
    int days = 14,
  }) async => HotelAvailability.fromJson(
    hotelObject(
      await _rpc(
        'kamra.api.availability_calendar',
        parameters: {
          'property': property,
          'start_date': startDate,
          'days': days,
        },
      ),
    ),
  );

  @override
  Future<HotelBookingOptions> loadBookingOptions(String property) async =>
      HotelBookingOptions.fromJson(
        hotelObject(
          await _rpc(
            'kamra.api.booking_options',
            parameters: {'property': property},
          ),
        ),
      );

  @override
  Future<List<HotelGuest>> searchGuests(String query) async => hotelList(
    await _rpc('kamra.api.guest_search', parameters: {'q': query}),
  ).map(hotelObject).map(HotelGuest.fromJson).toList(growable: false);

  @override
  Future<HotelReservationDetail> loadReservationDetail(
    String reservation,
  ) async => HotelReservationDetail.fromJson(
    hotelObject(
      await _rpc(
        'kamra.api.reservation_detail',
        parameters: {'reservation': reservation},
      ),
    ),
  );

  @override
  Future<HotelBookingReceipt> createBooking(
    String property,
    HotelBookingRequest request,
  ) async {
    final receipt = HotelBookingReceipt.fromJson(
      hotelObject(
        await _rpc(
          'kamra.api.create_booking',
          parameters: {'property': property, ...request.toJson()},
        ),
      ),
    );
    if (receipt.reservation.isEmpty) {
      throw const HotelRepositoryException(
        HotelRepositoryFailure.invalidResponse,
      );
    }
    return receipt;
  }

  @override
  Future<void> checkIn(String reservation) =>
      _action('kamra.api.check_in', {'reservation': reservation});

  @override
  Future<void> checkOut(String reservation) =>
      _action('kamra.api.check_out', {'reservation': reservation});

  @override
  Future<void> updateHousekeeping(String room, String status) => _action(
    'kamra.api.set_housekeeping_status',
    {'room': room, 'status': status},
  );

  Future<void> _action(String method, HotelJson parameters) async {
    await _rpc(method, parameters: parameters);
  }

  Future<Object?> _rpc(String method, {HotelJson parameters = const {}}) async {
    final response = await session.request(
      '/api/method/$method',
      method: 'POST',
      headers: const {'content-type': 'application/json'},
      body: jsonEncode(parameters),
    );
    if (response.statusCode == 401 || response.statusCode == 403) {
      throw const HotelRepositoryException(
        HotelRepositoryFailure.permissionDenied,
      );
    }
    if (response.statusCode == 409 || response.statusCode == 422) {
      throw const HotelRepositoryException(
        HotelRepositoryFailure.businessConflict,
      );
    }
    if (!response.isSuccess) {
      throw const HotelRepositoryException(HotelRepositoryFailure.unavailable);
    }
    final root = hotelObject(response.jsonBody);
    if (root.isEmpty || !root.containsKey('message')) {
      throw const HotelRepositoryException(
        HotelRepositoryFailure.invalidResponse,
      );
    }
    return root['message'];
  }
}
