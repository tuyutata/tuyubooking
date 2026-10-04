import 'package:flutter_test/flutter_test.dart';
import 'package:tuyubooking/client/tour/tour_controller.dart';
import 'package:tuyubooking/client/tour/tour_models.dart';
import 'package:tuyubooking/client/tour/tour_repository.dart';

void main() {
  test(
    'initializes, filters bookings and refreshes after approval request',
    () async {
      final source = _FakeTourDataSource();
      final controller = TourController(source);

      await controller.initialize();
      await controller.applyBookingFilters(
        search: 'TUYU-1001',
        bookingStatus: 'on_hold',
        from: '2026-09-01',
        to: '2026-09-30',
      );
      final outcome = await controller.confirmBooking(
        'book_1',
        note: 'Reviewed',
      );

      expect(controller.status, TourStatus.ready);
      expect(controller.products.single.name, 'Silk Road');
      expect(controller.bookings.single.bookingNumber, 'TUYU-1001');
      expect(source.lastSearch, 'TUYU-1001');
      expect(source.lastStatus, 'on_hold');
      expect(outcome, TourActionOutcome.pendingApproval);
      expect(source.confirmed, ['book_1']);
      controller.dispose();
    },
  );
}

final class _FakeTourDataSource implements TourDataSource {
  String? lastSearch;
  String? lastStatus;
  final List<String> confirmed = [];

  @override
  Future<TourPage<TourProduct>> loadProducts({
    int offset = 0,
    int limit = 100,
  }) async => TourPage(
    items: const [
      TourProduct(
        id: 'prod_1',
        name: 'Silk Road',
        status: 'active',
        reference: '',
        productTypeId: '',
      ),
    ],
    total: 1,
    limit: limit,
    offset: offset,
  );

  @override
  Future<List<TourDeparture>> loadDepartures({
    String? productId,
    int limit = 100,
  }) async => const [];

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
    lastSearch = search;
    lastStatus = status;
    return TourPage(
      items: const [
        TourBookingSummary(
          id: 'book_1',
          bookingNumber: 'TUYU-1001',
          status: 'on_hold',
          contactEmail: 'guest@example.com',
          sellCurrency: 'CNY',
          sellAmountCents: 120000,
          startDate: '2026-09-10',
          endDate: '2026-09-16',
          pax: 2,
        ),
      ],
      total: 1,
      limit: limit,
      offset: offset,
    );
  }

  @override
  Future<TourActionOutcome> confirmBooking(
    String bookingId, {
    String? note,
  }) async {
    confirmed.add(bookingId);
    return TourActionOutcome.pendingApproval;
  }

  @override
  Future<TourActionOutcome> cancelBooking(
    String bookingId, {
    String? note,
  }) async => TourActionOutcome.completed;

  @override
  Future<TourBookingBundle> loadBookingBundle(String bookingId) =>
      throw UnimplementedError();
}
