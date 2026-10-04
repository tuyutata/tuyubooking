import 'dart:convert';

import 'package:tuyubooking/client/employee_access/employee_session.dart';
import 'package:tuyubooking/client/tour/tour_models.dart';

enum TourRepositoryFailure {
  unavailable,
  invalidResponse,
  sessionExpired,
  permissionDenied,
  businessConflict,
}

final class TourRepositoryException implements Exception {
  const TourRepositoryException(this.failure);
  final TourRepositoryFailure failure;
}

abstract interface class TourDataSource {
  Future<TourPage<TourProduct>> loadProducts({int offset = 0, int limit = 100});
  Future<List<TourDeparture>> loadDepartures({
    String? productId,
    int limit = 100,
  });
  Future<TourPage<TourBookingSummary>> loadBookings({
    String? search,
    String? status,
    String? productId,
    String? dateFrom,
    String? dateTo,
    int offset = 0,
    int limit = 25,
  });
  Future<TourBookingBundle> loadBookingBundle(String bookingId);
  Future<TourActionOutcome> confirmBooking(String bookingId, {String? note});
  Future<TourActionOutcome> cancelBooking(String bookingId, {String? note});
}

/// Thin Voyant adapter. Voyant remains authoritative for tenant and workflow rules.
final class TourRepository implements TourDataSource {
  const TourRepository(this.session);

  final EmployeeSession session;

  @override
  Future<TourPage<TourProduct>> loadProducts({
    int offset = 0,
    int limit = 100,
  }) async {
    final response = await _send(
      '/v1/admin/products',
      queryParameters: {'offset': '$offset', 'limit': '$limit'},
    );
    return _page(response.payload, TourProduct.fromJson, offset, limit);
  }

  @override
  Future<List<TourDeparture>> loadDepartures({
    String? productId,
    int limit = 100,
  }) async {
    final response = await _send(
      '/v1/availability/slots',
      queryParameters: {
        if (productId != null && productId.isNotEmpty) 'productId': productId,
        'limit': '$limit',
      },
    );
    final root = tourObject(response.payload);
    return tourList(root['data'] ?? response.payload)
        .map(tourObject)
        .map(TourDeparture.fromJson)
        .where((departure) => departure.id.isNotEmpty)
        .toList(growable: false);
  }

  @override
  Future<TourPage<TourBookingSummary>> loadBookings({
    String? search,
    String? status,
    String? productId,
    String? dateFrom,
    String? dateTo,
    int offset = 0,
    int limit = 25,
  }) async {
    final response = await _send(
      '/v1/admin/bookings',
      queryParameters: {
        if (search != null && search.isNotEmpty) 'search': search,
        if (status != null && status.isNotEmpty) 'status': status,
        if (productId != null && productId.isNotEmpty) 'productId': productId,
        if (dateFrom != null && dateFrom.isNotEmpty) 'dateFrom': dateFrom,
        if (dateTo != null && dateTo.isNotEmpty) 'dateTo': dateTo,
        'offset': '$offset',
        'limit': '$limit',
      },
    );
    return _page(response.payload, TourBookingSummary.fromJson, offset, limit);
  }

  @override
  Future<TourBookingBundle> loadBookingBundle(String bookingId) async {
    final detailResponse = await _send('/v1/bookings/$bookingId');
    final itemResponse = await _send('/v1/bookings/$bookingId/items');
    final travelerResponse = await _send('/v1/bookings/$bookingId/travelers');
    final detail = tourObject(_unwrapData(detailResponse.payload));
    if (detail.isEmpty) {
      throw const TourRepositoryException(
        TourRepositoryFailure.invalidResponse,
      );
    }
    return TourBookingBundle(
      booking: TourBookingDetail.fromJson(detail),
      items: tourList(
        tourObject(itemResponse.payload)['data'],
      ).map(tourObject).map(TourBookingItem.fromJson).toList(growable: false),
      travelers: tourList(
        tourObject(travelerResponse.payload)['data'],
      ).map(tourObject).map(TourTraveler.fromJson).toList(growable: false),
    );
  }

  @override
  Future<TourActionOutcome> confirmBooking(String bookingId, {String? note}) =>
      _bookingAction('/v1/admin/bookings/$bookingId/confirm', note);

  @override
  Future<TourActionOutcome> cancelBooking(String bookingId, {String? note}) =>
      _bookingAction('/v1/admin/bookings/$bookingId/cancel', note);

  Future<TourActionOutcome> _bookingAction(
    String endpoint,
    String? note,
  ) async {
    final response = await _send(
      endpoint,
      method: 'POST',
      body: jsonEncode({'note': note?.trim().isEmpty == true ? null : note}),
    );
    return response.statusCode == 202
        ? TourActionOutcome.pendingApproval
        : TourActionOutcome.completed;
  }

  Future<_TourResponse> _send(
    String endpoint, {
    String method = 'GET',
    Map<String, String> queryParameters = const {},
    String? body,
  }) async {
    final response = await session.request(
      endpoint,
      method: method,
      headers: body == null
          ? const {}
          : const {'content-type': 'application/json'},
      queryParameters: queryParameters,
      body: body,
    );
    if (response.statusCode == 401) {
      throw const TourRepositoryException(TourRepositoryFailure.sessionExpired);
    }
    if (response.statusCode == 403) {
      throw const TourRepositoryException(
        TourRepositoryFailure.permissionDenied,
      );
    }
    if (response.statusCode == 409 || response.statusCode == 422) {
      throw const TourRepositoryException(
        TourRepositoryFailure.businessConflict,
      );
    }
    if (!response.isSuccess) {
      throw const TourRepositoryException(TourRepositoryFailure.unavailable);
    }
    final payload = response.jsonBody;
    if (payload == null) {
      throw const TourRepositoryException(
        TourRepositoryFailure.invalidResponse,
      );
    }
    return _TourResponse(response.statusCode, payload);
  }

  static TourPage<T> _page<T>(
    Object? payload,
    T Function(TourJson) mapper,
    int fallbackOffset,
    int fallbackLimit,
  ) {
    final root = tourObject(payload);
    final rows = tourList(root['data']);
    final items = rows.map(tourObject).map(mapper).toList(growable: false);
    return TourPage(
      items: items,
      total: _asInt(root['total'], items.length),
      limit: _asInt(root['limit'], fallbackLimit),
      offset: _asInt(root['offset'], fallbackOffset),
    );
  }

  static Object? _unwrapData(Object? payload) {
    final root = tourObject(payload);
    return root.containsKey('data') ? root['data'] : payload;
  }

  static int _asInt(Object? value, int fallback) => value is num
      ? value.toInt()
      : int.tryParse(value?.toString() ?? '') ?? fallback;
}

final class _TourResponse {
  const _TourResponse(this.statusCode, this.payload);
  final int statusCode;
  final Object? payload;
}
