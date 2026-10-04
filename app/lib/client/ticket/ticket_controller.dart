import 'package:flutter/foundation.dart';
import 'package:tuyubooking/client/ticket/ticket_models.dart';
import 'package:tuyubooking/client/ticket/ticket_repository.dart';

enum TicketStatus { loading, ready, loadingMore, acting, failed }

final class TicketController extends ChangeNotifier {
  TicketController(this.repository);

  static const attendeePageSize = 30;

  final TicketDataSource repository;
  TicketStatus status = TicketStatus.loading;
  List<TicketEvent> events = const [];
  TicketEvent? event;
  TicketCheckInStats stats = const TicketCheckInStats(totalCheckedIn: 0);
  List<TicketAttendee> attendees = const [];
  int attendeeTotal = 0;
  String search = '';
  Object? error;

  bool get canLoadMore => attendees.length < attendeeTotal;
  bool get isActing => status == TicketStatus.acting;

  Future<void> initialize() async {
    status = TicketStatus.loading;
    error = null;
    notifyListeners();
    try {
      final page = await repository.loadEvents();
      events = page.items;
      event = events.isEmpty ? null : events.first;
      if (event != null) await _loadEventData(reset: true);
      status = TicketStatus.ready;
    } on Object catch (caught) {
      error = caught;
      status = TicketStatus.failed;
    }
    notifyListeners();
  }

  Future<void> selectEvent(String eventId) async {
    for (final item in events) {
      if (item.id != eventId) continue;
      event = item;
      search = '';
      status = TicketStatus.loading;
      notifyListeners();
      try {
        await _loadEventData(reset: true);
        error = null;
        status = TicketStatus.ready;
      } on Object catch (caught) {
        error = caught;
        status = TicketStatus.failed;
      }
      notifyListeners();
      return;
    }
  }

  Future<void> refresh() async {
    if (event == null) return;
    status = TicketStatus.loading;
    notifyListeners();
    try {
      await _loadEventData(reset: true);
      error = null;
      status = TicketStatus.ready;
    } on Object catch (caught) {
      error = caught;
      status = TicketStatus.failed;
    }
    notifyListeners();
  }

  Future<void> applySearch(String value) async {
    if (event == null) return;
    search = value.trim();
    status = TicketStatus.loading;
    notifyListeners();
    try {
      final page = await repository.loadAttendees(
        event!.id,
        query: search,
        perPage: attendeePageSize,
      );
      attendees = page.items;
      attendeeTotal = page.total;
      error = null;
      status = TicketStatus.ready;
    } on Object catch (caught) {
      error = caught;
      status = TicketStatus.failed;
    }
    notifyListeners();
  }

  Future<void> loadMore() async {
    if (!canLoadMore || status != TicketStatus.ready || event == null) return;
    status = TicketStatus.loadingMore;
    notifyListeners();
    try {
      final nextPage = (attendees.length ~/ attendeePageSize) + 1;
      final page = await repository.loadAttendees(
        event!.id,
        query: search,
        page: nextPage,
        perPage: attendeePageSize,
      );
      attendees = [...attendees, ...page.items];
      attendeeTotal = page.total;
      error = null;
    } on Object catch (caught) {
      error = caught;
    }
    status = TicketStatus.ready;
    notifyListeners();
  }

  Future<TicketScanResult> scanAndCheckIn(String rawCode) async {
    final selectedEvent = event;
    final token = parseHiEventsTicketCode(rawCode);
    if (selectedEvent == null || token == null) {
      return const TicketScanResult(TicketScanResultType.invalidCode);
    }
    status = TicketStatus.acting;
    error = null;
    notifyListeners();
    try {
      final attendee = await repository.findAttendee(selectedEvent.id, token);
      if (attendee == null) return _finish(TicketScanResultType.notFound);
      if (attendee.status == 'CANCELLED') {
        return _finish(TicketScanResultType.cancelled, attendee);
      }
      if (attendee.status == 'AWAITING_PAYMENT') {
        return _finish(TicketScanResultType.awaitingPayment, attendee);
      }
      if (attendee.isCheckedIn) {
        return _finish(TicketScanResultType.duplicate, attendee);
      }
      final updated = await repository.changeCheckIn(
        selectedEvent.id,
        attendee.publicId,
        TicketCheckAction.checkIn,
      );
      await _loadEventData(reset: true);
      return _finish(TicketScanResultType.checkedIn, updated);
    } on TicketRepositoryException catch (caught) {
      error = caught;
      return _finish(_failureType(caught.failure));
    } on Object catch (caught) {
      error = caught;
      return _finish(TicketScanResultType.failed);
    }
  }

  Future<TicketScanResult> changeCheckIn(
    TicketAttendee attendee,
    TicketCheckAction action,
  ) async {
    final selectedEvent = event;
    if (selectedEvent == null || isActing) {
      return const TicketScanResult(TicketScanResultType.failed);
    }
    status = TicketStatus.acting;
    notifyListeners();
    try {
      final updated = await repository.changeCheckIn(
        selectedEvent.id,
        attendee.publicId,
        action,
      );
      await _loadEventData(reset: true);
      return _finish(
        action == TicketCheckAction.checkIn
            ? TicketScanResultType.checkedIn
            : TicketScanResultType.checkedOut,
        updated,
      );
    } on TicketRepositoryException catch (caught) {
      error = caught;
      return _finish(_failureType(caught.failure), attendee);
    } on Object catch (caught) {
      error = caught;
      return _finish(TicketScanResultType.failed, attendee);
    }
  }

  TicketScanResult _finish(
    TicketScanResultType type, [
    TicketAttendee? attendee,
  ]) {
    status = TicketStatus.ready;
    notifyListeners();
    return TicketScanResult(type, attendee: attendee);
  }

  TicketScanResultType _failureType(TicketRepositoryFailure failure) =>
      switch (failure) {
        TicketRepositoryFailure.permissionDenied =>
          TicketScanResultType.permissionDenied,
        TicketRepositoryFailure.notFound => TicketScanResultType.notFound,
        TicketRepositoryFailure.conflict => TicketScanResultType.conflict,
        _ => TicketScanResultType.failed,
      };

  Future<void> _loadEventData({required bool reset}) async {
    final selected = event!;
    stats = await repository.loadCheckInStats(selected.id);
    final page = await repository.loadAttendees(
      selected.id,
      query: search,
      page: reset ? 1 : (attendees.length ~/ attendeePageSize) + 1,
      perPage: attendeePageSize,
    );
    attendees = reset ? page.items : [...attendees, ...page.items];
    attendeeTotal = page.total;
  }
}
