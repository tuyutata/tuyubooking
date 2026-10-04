import 'package:flutter_test/flutter_test.dart';
import 'package:tuyubooking/client/hotel/hotel_controller.dart';
import 'package:tuyubooking/client/hotel/hotel_models.dart';
import 'package:tuyubooking/client/hotel/hotel_repository.dart';

void main() {
  test('initializes property data and refreshes after check-in', () async {
    final dataSource = _FakeDataSource();
    final controller = HotelController(dataSource);
    await controller.initialize();

    expect(controller.status, HotelStatus.ready);
    expect(controller.property?.name, 'PROP-1');
    expect(controller.snapshot?.arrivals.single.name, 'RES-1');

    final succeeded = await controller.checkIn('RES-1');
    expect(succeeded, isTrue);
    expect(dataSource.checkedIn, ['RES-1']);
    expect(dataSource.snapshotLoads, 2);
    controller.dispose();
  });
}

final class _FakeDataSource implements HotelDataSource {
  final List<String> checkedIn = [];
  int snapshotLoads = 0;

  @override
  Future<List<HotelProperty>> loadProperties() async => const [
    HotelProperty(name: 'PROP-1', displayName: 'Lake Hotel', city: 'Hangzhou'),
  ];

  @override
  Future<HotelSnapshot> loadSnapshot(String property) async {
    snapshotLoads += 1;
    return const HotelSnapshot(
      date: '2026-08-27',
      arrivals: [
        HotelReservation(
          name: 'RES-1',
          guestName: 'Guest A',
          roomType: 'King',
          room: '',
          status: 'Confirmed',
          checkInDate: '2026-08-27',
          checkOutDate: '2026-08-28',
          adults: 1,
          children: 0,
          paidTotal: 0,
          balanceDue: 300,
        ),
      ],
      departures: [],
      inHouse: [],
      rooms: [],
    );
  }

  @override
  Future<HotelAvailability> loadAvailability(
    String property, {
    required String startDate,
    int days = 14,
  }) async => HotelAvailability(
    start: startDate,
    days: days,
    dates: const [],
    rows: const [],
  );

  @override
  Future<HotelBookingOptions> loadBookingOptions(String property) async =>
      const HotelBookingOptions(roomTypes: [], mealPlans: []);

  @override
  Future<void> checkIn(String reservation) async => checkedIn.add(reservation);
  @override
  Future<void> checkOut(String reservation) async {}
  @override
  Future<void> updateHousekeeping(String room, String status) async {}
  @override
  Future<List<HotelGuest>> searchGuests(String query) async => const [];
  @override
  Future<HotelReservationDetail> loadReservationDetail(String reservation) =>
      throw UnimplementedError();
  @override
  Future<HotelBookingReceipt> createBooking(
    String property,
    HotelBookingRequest request,
  ) async => const HotelBookingReceipt(reservation: 'RES-2', room: '');
}
