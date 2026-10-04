import 'package:flutter/foundation.dart';
import 'package:tuyubooking/client/tour/tour_models.dart';
import 'package:tuyubooking/client/tour/tour_repository.dart';

enum TourStatus { loading, ready, loadingMore, acting, failed }

final class TourController extends ChangeNotifier {
  TourController(this.repository);

  static const pageSize = 25;

  final TourDataSource repository;
  TourStatus status = TourStatus.loading;
  List<TourProduct> products = const [];
  List<TourDeparture> departures = const [];
  List<TourBookingSummary> bookings = const [];
  int bookingTotal = 0;
  String? selectedProductId;
  String? selectedBookingStatus;
  String bookingSearch = '';
  String? dateFrom;
  String? dateTo;
  Object? error;

  bool get isActing => status == TourStatus.acting;
  bool get canLoadMore => bookings.length < bookingTotal;

  List<TourDeparture> get upcomingDepartures {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final result = departures
        .where((departure) {
          final date = DateTime.tryParse(departure.dateLocal);
          return date == null || !date.isBefore(today);
        })
        .toList(growable: false);
    result.sort((left, right) => left.startsAt.compareTo(right.startsAt));
    return result;
  }

  Future<void> initialize() async {
    status = TourStatus.loading;
    error = null;
    notifyListeners();
    try {
      final productPage = await repository.loadProducts();
      products = productPage.items;
      departures = await repository.loadDepartures();
      await _loadBookings(reset: true);
      status = TourStatus.ready;
    } on Object catch (caught) {
      error = caught;
      status = TourStatus.failed;
    }
    notifyListeners();
  }

  Future<void> refresh() async {
    status = TourStatus.loading;
    notifyListeners();
    try {
      departures = await repository.loadDepartures(
        productId: selectedProductId,
      );
      await _loadBookings(reset: true);
      error = null;
      status = TourStatus.ready;
    } on Object catch (caught) {
      error = caught;
      status = TourStatus.failed;
    }
    notifyListeners();
  }

  Future<void> selectProduct(String? productId) async {
    selectedProductId = productId?.isEmpty == true ? null : productId;
    await refresh();
  }

  Future<void> applyBookingFilters({
    required String search,
    String? bookingStatus,
    String? from,
    String? to,
  }) async {
    bookingSearch = search.trim();
    selectedBookingStatus = bookingStatus?.isEmpty == true
        ? null
        : bookingStatus;
    dateFrom = from;
    dateTo = to;
    status = TourStatus.loading;
    notifyListeners();
    try {
      await _loadBookings(reset: true);
      error = null;
      status = TourStatus.ready;
    } on Object catch (caught) {
      error = caught;
      status = TourStatus.failed;
    }
    notifyListeners();
  }

  Future<void> loadMoreBookings() async {
    if (!canLoadMore || status != TourStatus.ready) return;
    status = TourStatus.loadingMore;
    notifyListeners();
    try {
      await _loadBookings(reset: false);
      error = null;
    } on Object catch (caught) {
      error = caught;
    }
    status = TourStatus.ready;
    notifyListeners();
  }

  Future<TourBookingBundle> loadBookingBundle(String bookingId) =>
      repository.loadBookingBundle(bookingId);

  Future<TourActionOutcome?> confirmBooking(String bookingId, {String? note}) =>
      _action(() => repository.confirmBooking(bookingId, note: note));

  Future<TourActionOutcome?> cancelBooking(String bookingId, {String? note}) =>
      _action(() => repository.cancelBooking(bookingId, note: note));

  Future<TourActionOutcome?> _action(
    Future<TourActionOutcome> Function() operation,
  ) async {
    if (isActing) return null;
    status = TourStatus.acting;
    error = null;
    notifyListeners();
    try {
      final outcome = await operation();
      await _loadBookings(reset: true);
      status = TourStatus.ready;
      notifyListeners();
      return outcome;
    } on Object catch (caught) {
      error = caught;
      status = TourStatus.ready;
      notifyListeners();
      return null;
    }
  }

  Future<void> _loadBookings({required bool reset}) async {
    final offset = reset ? 0 : bookings.length;
    final page = await repository.loadBookings(
      search: bookingSearch,
      status: selectedBookingStatus,
      productId: selectedProductId,
      dateFrom: dateFrom,
      dateTo: dateTo,
      offset: offset,
      limit: pageSize,
    );
    bookings = reset ? page.items : [...bookings, ...page.items];
    bookingTotal = page.total;
  }

  String productName(String productId) {
    for (final product in products) {
      if (product.id == productId) return product.name;
    }
    return productId;
  }
}
