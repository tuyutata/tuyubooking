import 'dart:convert';

import 'package:tuyubooking/client/employee_access/employee_session.dart';
import 'package:tuyubooking/client/ticket/ticket_models.dart';

enum TicketRepositoryFailure {
  unavailable,
  invalidResponse,
  sessionExpired,
  permissionDenied,
  notFound,
  conflict,
  invalidRequest,
}

final class TicketRepositoryException implements Exception {
  const TicketRepositoryException(this.failure);
  final TicketRepositoryFailure failure;
}

abstract interface class TicketDataSource {
  Future<TicketPage<TicketEvent>> loadEvents({
    String query = '',
    int page = 1,
    int perPage = 50,
  });
  Future<TicketCheckInStats> loadCheckInStats(String eventId);
  Future<TicketPage<TicketAttendee>> loadAttendees(
    String eventId, {
    String query = '',
    int page = 1,
    int perPage = 30,
  });
  Future<TicketAttendee?> findAttendee(String eventId, String token);
  Future<TicketAttendee> changeCheckIn(
    String eventId,
    String attendeePublicId,
    TicketCheckAction action,
  );
}

/// Thin Hi.Events adapter. Ticket validity and check-in remain upstream rules.
final class TicketRepository implements TicketDataSource {
  const TicketRepository(this.session);

  final EmployeeSession session;

  @override
  Future<TicketPage<TicketEvent>> loadEvents({
    String query = '',
    int page = 1,
    int perPage = 50,
  }) async {
    final payload = await _request(
      '/events',
      queryParameters: {
        'page': '$page',
        'per_page': '$perPage',
        if (query.isNotEmpty) 'query': query,
        'sort_by': 'start_date',
        'sort_direction': 'asc',
      },
    );
    return _page(payload, TicketEvent.fromJson, page, perPage);
  }

  @override
  Future<TicketCheckInStats> loadCheckInStats(String eventId) async =>
      TicketCheckInStats.fromJson(
        ticketObject(
          _unwrapData(await _request('/events/$eventId/check_in_stats')),
        ),
      );

  @override
  Future<TicketPage<TicketAttendee>> loadAttendees(
    String eventId, {
    String query = '',
    int page = 1,
    int perPage = 30,
  }) async {
    final payload = await _request(
      '/events/$eventId/attendees',
      queryParameters: {
        'page': '$page',
        'per_page': '$perPage',
        if (query.isNotEmpty) 'query': query,
        'sort_by': 'created_at',
        'sort_direction': 'desc',
      },
    );
    return _page(payload, TicketAttendee.fromJson, page, perPage);
  }

  @override
  Future<TicketAttendee?> findAttendee(String eventId, String token) async {
    final page = await loadAttendees(eventId, query: token, perPage: 20);
    for (final attendee in page.items) {
      if (attendee.publicId == token || attendee.shortId == token) {
        return attendee;
      }
    }
    return null;
  }

  @override
  Future<TicketAttendee> changeCheckIn(
    String eventId,
    String attendeePublicId,
    TicketCheckAction action,
  ) async {
    final payload = await _request(
      '/events/$eventId/attendees/$attendeePublicId/check_in',
      method: 'POST',
      body: jsonEncode({
        'action': action == TicketCheckAction.checkIn
            ? 'check_in'
            : 'check_out',
      }),
    );
    final attendee = ticketObject(_unwrapData(payload));
    if (attendee.isEmpty) {
      throw const TicketRepositoryException(
        TicketRepositoryFailure.invalidResponse,
      );
    }
    return TicketAttendee.fromJson(attendee);
  }

  Future<Object?> _request(
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
      throw const TicketRepositoryException(
        TicketRepositoryFailure.sessionExpired,
      );
    }
    if (response.statusCode == 403) {
      throw const TicketRepositoryException(
        TicketRepositoryFailure.permissionDenied,
      );
    }
    if (response.statusCode == 404) {
      throw const TicketRepositoryException(TicketRepositoryFailure.notFound);
    }
    if (response.statusCode == 409) {
      throw const TicketRepositoryException(TicketRepositoryFailure.conflict);
    }
    if (response.statusCode == 422) {
      throw const TicketRepositoryException(
        TicketRepositoryFailure.invalidRequest,
      );
    }
    if (!response.isSuccess) {
      throw const TicketRepositoryException(
        TicketRepositoryFailure.unavailable,
      );
    }
    final payload = response.jsonBody;
    if (payload == null) {
      throw const TicketRepositoryException(
        TicketRepositoryFailure.invalidResponse,
      );
    }
    return payload;
  }

  static TicketPage<T> _page<T>(
    Object? payload,
    T Function(TicketJson) mapper,
    int fallbackPage,
    int fallbackPerPage,
  ) {
    final root = ticketObject(payload);
    final outerData = root['data'];
    final nested = ticketObject(outerData);
    final rows = outerData is List
        ? outerData
        : ticketList(nested['data'] ?? root['items']);
    final meta = ticketObject(root['meta']).isNotEmpty
        ? ticketObject(root['meta'])
        : ticketObject(nested['meta']);
    final items = rows.map(ticketObject).map(mapper).toList(growable: false);
    return TicketPage(
      items: items,
      total: _asInt(
        meta['total'] ?? nested['total'] ?? root['total'],
        items.length,
      ),
      page: _asInt(
        meta['current_page'] ?? nested['current_page'],
        fallbackPage,
      ),
      perPage: _asInt(meta['per_page'] ?? nested['per_page'], fallbackPerPage),
    );
  }

  static Object? _unwrapData(Object? payload) {
    final root = ticketObject(payload);
    return root.containsKey('data') ? root['data'] : payload;
  }

  static int _asInt(Object? value, int fallback) => value is num
      ? value.toInt()
      : int.tryParse(value?.toString() ?? '') ?? fallback;
}
