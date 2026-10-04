import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:tuyubooking/client/business_mode.dart';

/// Owns the client business-mode selection and its local settings file.
final class BusinessModeSelection extends ChangeNotifier {
  BusinessModeSelection({required this.storageFile});

  static const _fileName = 'client_business_modes.json';

  final File storageFile;
  final Set<BusinessMode> _selected = <BusinessMode>{};
  bool _isLoading = false;
  bool _isSaving = false;

  Set<BusinessMode> get selected => Set.unmodifiable(_selected);
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  bool get canContinue => _selected.isNotEmpty && !_isSaving;

  static Future<BusinessModeSelection> createDefault() async {
    final supportDirectory = await getApplicationSupportDirectory();
    return BusinessModeSelection(
      storageFile: File(
        '${supportDirectory.path}${Platform.pathSeparator}$_fileName',
      ),
    );
  }

  Future<void> load() async {
    _isLoading = true;
    notifyListeners();
    try {
      if (!await storageFile.exists()) {
        return;
      }
      final decoded = jsonDecode(await storageFile.readAsString());
      if (decoded is! Map<String, dynamic> || decoded['modes'] is! List) {
        return;
      }
      final restored = <BusinessMode>{};
      for (final value in decoded['modes'] as List<dynamic>) {
        if (value is! String) {
          continue;
        }
        final mode = BusinessMode.tryParse(value);
        if (mode != null) {
          restored.add(mode);
        }
      }
      _selected
        ..clear()
        ..addAll(restored);
    } on FormatException {
      _selected.clear();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void toggle(BusinessMode mode) {
    if (!_selected.remove(mode)) {
      _selected.add(mode);
    }
    notifyListeners();
  }

  Future<void> save() async {
    if (_selected.isEmpty) {
      throw StateError('At least one business mode is required.');
    }
    _isSaving = true;
    notifyListeners();
    try {
      await storageFile.parent.create(recursive: true);
      final orderedModes = BusinessMode.values
          .where(_selected.contains)
          .map((mode) => mode.code)
          .toList(growable: false);
      await storageFile.writeAsString(
        jsonEncode(<String, Object>{'version': 1, 'modes': orderedModes}),
        flush: true,
      );
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }
}
