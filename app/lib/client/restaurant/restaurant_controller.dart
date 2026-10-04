import 'package:flutter/foundation.dart';
import 'package:tuyubooking/client/restaurant/restaurant_models.dart';
import 'package:tuyubooking/client/restaurant/restaurant_repository.dart';

enum RestaurantStatus { loading, ready, submitting, failed }

final class RestaurantController extends ChangeNotifier {
  RestaurantController(this.repository);

  final RestaurantRepository repository;
  RestaurantStatus status = RestaurantStatus.loading;
  RestaurantPosProfile? profile;
  List<RestaurantMenuCategory> categories = const [];
  List<RestaurantMenuItem> menu = const [];
  List<RestaurantRoom> rooms = const [];
  List<RestaurantTable> tables = const [];
  List<RestaurantCartLine> cart = const [];
  RestaurantOrderType orderType = RestaurantOrderType.takeAway;
  String? selectedCategory;
  String? selectedRoom;
  String? selectedTable;
  RestaurantOrderReceipt? receipt;
  RestaurantOrderReceipt? activeOrder;
  List<RestaurantOrderReceipt> orders = const [];
  String orderStatus = 'Draft';
  bool ordersLoading = false;
  Object? error;
  int numberOfGuests = 1;
  bool _dirty = false;

  List<RestaurantMenuItem> get filteredMenu => selectedCategory == null
      ? menu
      : menu.where((item) => item.course == selectedCategory).toList();
  int get itemCount => cart.fold(0, (sum, line) => sum + line.quantity.ceil());
  double get total => cart.fold(0, (sum, line) => sum + line.amount);
  bool get hasUnsavedChanges => _dirty;
  bool get canSubmit =>
      cart.isNotEmpty &&
      _dirty &&
      status == RestaurantStatus.ready &&
      (orderType == RestaurantOrderType.takeAway || selectedTable != null);

  Future<void> initialize() async {
    status = RestaurantStatus.loading;
    error = null;
    notifyListeners();
    try {
      final bootstrap = await repository.loadBootstrap();
      profile = bootstrap.profile;
      categories = bootstrap.categories;
      rooms = bootstrap.rooms;
      selectedRoom = rooms.isEmpty ? null : rooms.first.name;
      await _reloadContext();
      status = RestaurantStatus.ready;
    } on Object catch (caught) {
      error = caught;
      status = RestaurantStatus.failed;
    }
    notifyListeners();
  }

  Future<void> selectOrderType(RestaurantOrderType value) async {
    orderType = value;
    selectedTable = null;
    await _reloadContext();
    notifyListeners();
  }

  Future<void> selectRoom(String room) async {
    selectedRoom = room;
    selectedTable = null;
    await _reloadContext();
    notifyListeners();
  }

  Future<void> selectTable(String? table) async {
    selectedTable = table;
    activeOrder = null;
    cart = const [];
    _dirty = false;
    if (table != null) {
      try {
        final existing = await repository.loadTableOrder(table);
        if (existing != null) {
          activeOrder = existing.receipt;
          cart = existing.lines;
          numberOfGuests = 1;
        }
      } on Object catch (caught) {
        error = caught;
      }
    }
    notifyListeners();
  }

  void selectCategory(String? category) {
    selectedCategory = category;
    notifyListeners();
  }

  Future<RestaurantItemOptions> loadOptions(RestaurantMenuItem item) =>
      repository.loadItemOptions(item, menu);

  void addConfiguredItem({
    required RestaurantMenuItem item,
    required double quantity,
    required String comment,
    List<RestaurantMenuItem> addOns = const [],
  }) {
    if (quantity <= 0 || quantity > 99) return;
    _addLine(
      RestaurantCartLine(item: item, quantity: quantity, comment: comment),
    );
    for (final addOn in addOns) {
      _addLine(
        RestaurantCartLine(item: addOn, quantity: quantity, isAddOn: true),
      );
    }
    _dirty = true;
    notifyListeners();
  }

  void _addLine(RestaurantCartLine incoming) {
    final index = cart.indexWhere(
      (line) =>
          line.item.code == incoming.item.code &&
          line.comment == incoming.comment &&
          line.isAddOn == incoming.isAddOn,
    );
    if (index < 0) {
      cart = [...cart, incoming];
      return;
    }
    final updated = [...cart];
    updated[index] = updated[index].copyWith(
      quantity: (updated[index].quantity + incoming.quantity)
          .clamp(0, 99)
          .toDouble(),
    );
    cart = updated;
  }

  void changeQuantity(int index, double delta) {
    if (index < 0 || index >= cart.length) return;
    final quantity = cart[index].quantity + delta;
    if (quantity <= 0) {
      cart = [...cart]..removeAt(index);
    } else if (quantity <= 99) {
      final updated = [...cart];
      updated[index] = updated[index].copyWith(quantity: quantity);
      cart = updated;
    }
    _dirty = true;
    notifyListeners();
  }

  void clearCart() {
    cart = const [];
    _dirty = true;
    notifyListeners();
  }

  void setNumberOfGuests(int value) {
    numberOfGuests = value.clamp(1, 99).toInt();
    notifyListeners();
  }

  Future<RestaurantOrderReceipt?> submit() async {
    if (!canSubmit || profile == null) return null;
    status = RestaurantStatus.submitting;
    error = null;
    notifyListeners();
    try {
      receipt = await repository.submitOrder(
        profile: profile!,
        orderType: orderType,
        lines: cart,
        numberOfGuests: numberOfGuests,
        room: orderType == RestaurantOrderType.dineIn ? selectedRoom : null,
        table: orderType == RestaurantOrderType.dineIn ? selectedTable : null,
        existingOrder: activeOrder,
      );
      activeOrder = receipt;
      _dirty = false;
      status = RestaurantStatus.ready;
      notifyListeners();
      return receipt;
    } on Object catch (caught) {
      error = caught;
      status = RestaurantStatus.ready;
      notifyListeners();
      return null;
    }
  }

  Future<void> loadOrders({String? statusFilter}) async {
    if (statusFilter != null) orderStatus = statusFilter;
    ordersLoading = true;
    error = null;
    notifyListeners();
    try {
      final result = await repository.loadOrders(status: orderStatus);
      orders = result.orders;
    } on Object catch (caught) {
      error = caught;
    } finally {
      ordersLoading = false;
      notifyListeners();
    }
  }

  Future<void> selectOrder(RestaurantOrderReceipt order) async {
    activeOrder = order;
    orderType = order.table.isEmpty
        ? RestaurantOrderType.takeAway
        : RestaurantOrderType.dineIn;
    selectedTable = order.table.isEmpty ? null : order.table;
    try {
      cart = await repository.loadOrderItems(order.name);
      _dirty = false;
    } on Object catch (caught) {
      error = caught;
    }
    notifyListeners();
  }

  Future<bool> pay(
    RestaurantOrderReceipt order,
    List<RestaurantPaymentLine> payments,
  ) async {
    final currentProfile = profile;
    if (currentProfile == null) return false;
    status = RestaurantStatus.submitting;
    error = null;
    notifyListeners();
    try {
      await repository.makePayment(
        profile: currentProfile,
        order: order,
        payments: payments,
      );
      if (activeOrder?.name == order.name) {
        activeOrder = null;
        cart = const [];
        selectedTable = null;
        _dirty = false;
      }
      status = RestaurantStatus.ready;
      await loadOrders(statusFilter: orderStatus);
      return true;
    } on Object catch (caught) {
      error = caught;
      status = RestaurantStatus.ready;
      notifyListeners();
      return false;
    }
  }

  Future<void> _reloadContext() async {
    final currentProfile = profile;
    if (currentProfile == null) return;
    menu = await repository.loadMenu(
      profile: currentProfile,
      orderType: orderType,
      room: orderType == RestaurantOrderType.dineIn ? selectedRoom : null,
    );
    tables = orderType == RestaurantOrderType.dineIn && selectedRoom != null
        ? await repository.loadTables(selectedRoom!)
        : const [];
    if (selectedCategory != null &&
        !categories.any((category) => category.name == selectedCategory)) {
      selectedCategory = null;
    }
  }
}
