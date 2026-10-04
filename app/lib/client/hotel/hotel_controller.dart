import 'package:flutter/foundation.dart';
import 'package:tuyubooking/client/hotel/hotel_models.dart';
import 'package:tuyubooking/client/hotel/hotel_repository.dart';

enum HotelStatus { loading, ready, acting, failed }

final class HotelController extends ChangeNotifier {
  HotelController(this.repository);

  final HotelDataSource repository;
  HotelStatus status = HotelStatus.loading;
  List<HotelProperty> properties = const [];
  HotelProperty? property;
  HotelSnapshot? snapshot;
  HotelAvailability? availability;
  HotelBookingOptions? bookingOptions;
  Object? error;

  bool get isActing => status == HotelStatus.acting;

  Future<void> initialize() async {
    status = HotelStatus.loading;
    error = null;
    notifyListeners();
    try {
      properties = await repository.loadProperties();
      if (properties.isEmpty) {
        throw const HotelRepositoryException(
          HotelRepositoryFailure.invalidResponse,
        );
      }
      property = properties.first;
      await _loadPropertyData();
      status = HotelStatus.ready;
    } on Object catch (caught) {
      error = caught;
      status = HotelStatus.failed;
    }
    notifyListeners();
  }

  Future<void> selectProperty(String name) async {
    final selected = properties.where((item) => item.name == name);
    if (selected.isEmpty || selected.first.name == property?.name) return;
    property = selected.first;
    status = HotelStatus.loading;
    notifyListeners();
    try {
      await _loadPropertyData();
      error = null;
      status = HotelStatus.ready;
    } on Object catch (caught) {
      error = caught;
      status = HotelStatus.failed;
    }
    notifyListeners();
  }

  Future<void> refresh() async {
    if (property == null) return;
    status = HotelStatus.loading;
    notifyListeners();
    try {
      await _loadPropertyData();
      error = null;
      status = HotelStatus.ready;
    } on Object catch (caught) {
      error = caught;
      status = HotelStatus.failed;
    }
    notifyListeners();
  }

  Future<List<HotelGuest>> searchGuests(String query) => query.trim().length < 2
      ? Future.value(const [])
      : repository.searchGuests(query.trim());

  Future<HotelReservationDetail> loadReservationDetail(String reservation) =>
      repository.loadReservationDetail(reservation);

  Future<HotelBookingReceipt?> createBooking(
    HotelBookingRequest request,
  ) async {
    final selected = property;
    if (selected == null || isActing) return null;
    status = HotelStatus.acting;
    error = null;
    notifyListeners();
    try {
      final receipt = await repository.createBooking(selected.name, request);
      await _loadPropertyData();
      status = HotelStatus.ready;
      notifyListeners();
      return receipt;
    } on Object catch (caught) {
      error = caught;
      status = HotelStatus.ready;
      notifyListeners();
      return null;
    }
  }

  Future<bool> checkIn(String reservation) =>
      _perform(() => repository.checkIn(reservation));

  Future<bool> checkOut(String reservation) =>
      _perform(() => repository.checkOut(reservation));

  Future<bool> updateHousekeeping(String room, String value) =>
      _perform(() => repository.updateHousekeeping(room, value));

  Future<bool> _perform(Future<void> Function() operation) async {
    if (isActing) return false;
    status = HotelStatus.acting;
    error = null;
    notifyListeners();
    try {
      await operation();
      await _loadPropertyData();
      status = HotelStatus.ready;
      notifyListeners();
      return true;
    } on Object catch (caught) {
      error = caught;
      status = HotelStatus.ready;
      notifyListeners();
      return false;
    }
  }

  Future<void> _loadPropertyData() async {
    final selected = property!;
    snapshot = await repository.loadSnapshot(selected.name);
    availability = await repository.loadAvailability(
      selected.name,
      startDate: _date(DateTime.now()),
    );
    bookingOptions = await repository.loadBookingOptions(selected.name);
  }

  static String _date(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
}
