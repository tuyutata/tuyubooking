import 'package:flutter_test/flutter_test.dart';
import 'package:tuyubooking/client/ticket/ticket_controller.dart';
import 'package:tuyubooking/client/ticket/ticket_models.dart';
import 'package:tuyubooking/client/ticket/ticket_repository.dart';

void main() {
  test('initializes event and checks in a native attendee ticket', () async {
    final source = _FakeTicketDataSource();
    final controller = TicketController(source);

    await controller.initialize();
    final result = await controller.scanAndCheckIn('A-SHORT1');

    expect(controller.event?.id, '42');
    expect(controller.stats.totalCheckedIn, 1);
    expect(result.type, TicketScanResultType.checkedIn);
    expect(source.actions, [TicketCheckAction.checkIn]);
    controller.dispose();
  });

  test('rejects unrelated QR values without calling Hi.Events', () async {
    final source = _FakeTicketDataSource();
    final controller = TicketController(source);
    await controller.initialize();

    final result = await controller.scanAndCheckIn('https://example.com/login');

    expect(result.type, TicketScanResultType.invalidCode);
    expect(source.actions, isEmpty);
    controller.dispose();
  });
}

final class _FakeTicketDataSource implements TicketDataSource {
  final List<TicketCheckAction> actions = [];
  var checkedIn = false;

  TicketAttendee get attendee => TicketAttendee(
    id: '7',
    eventId: '42',
    orderId: '9',
    productId: '3',
    publicId: 'A-PUBLIC1',
    shortId: 'A-SHORT1',
    firstName: 'A',
    lastName: 'Guest',
    email: 'guest@example.com',
    status: 'ACTIVE',
    notes: null,
    productTitle: 'Admission',
    checkIns: const [],
    checkedInAt: checkedIn ? '2026-09-10T09:05:00Z' : null,
  );

  @override
  Future<TicketPage<TicketEvent>> loadEvents({
    String query = '',
    int page = 1,
    int perPage = 50,
  }) async => TicketPage(
    items: const [
      TicketEvent(
        id: '42',
        title: 'Travel Expo',
        startDate: '2026-09-10',
        endDate: '2026-09-10',
        status: 'LIVE',
        timezone: 'Asia/Shanghai',
        attendeesRegistered: 1,
      ),
    ],
    total: 1,
    page: page,
    perPage: perPage,
  );

  @override
  Future<TicketCheckInStats> loadCheckInStats(String eventId) async =>
      TicketCheckInStats(totalCheckedIn: checkedIn ? 1 : 0);

  @override
  Future<TicketPage<TicketAttendee>> loadAttendees(
    String eventId, {
    String query = '',
    int page = 1,
    int perPage = 30,
  }) async =>
      TicketPage(items: [attendee], total: 1, page: page, perPage: perPage);

  @override
  Future<TicketAttendee?> findAttendee(String eventId, String token) async =>
      token == attendee.shortId ? attendee : null;

  @override
  Future<TicketAttendee> changeCheckIn(
    String eventId,
    String attendeePublicId,
    TicketCheckAction action,
  ) async {
    actions.add(action);
    checkedIn = action == TicketCheckAction.checkIn;
    return attendee;
  }
}
