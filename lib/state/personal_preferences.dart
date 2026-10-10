import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract class PreferenceStorage {
  Future<String?> read();
  Future<void> write(String value);
}

class DevicePreferenceStorage implements PreferenceStorage {
  static const key = 'errandly_personal_preferences_v1';
  @override
  Future<String?> read() => SharedPreferencesAsync().getString(key);
  @override
  Future<void> write(String value) =>
      SharedPreferencesAsync().setString(key, value);
}

class AlertPreferences {
  const AlertPreferences({
    this.errands = true,
    this.messages = true,
    this.wallet = true,
    this.sound = true,
  });
  final bool errands, messages, wallet, sound;
  bool allows(String type) => switch (type) {
    'Errands' => errands,
    'Messages' => messages,
    'Wallet' => wallet,
    _ => false,
  };
  Map<String, bool> toJson() => {
    'Errands': errands,
    'Messages': messages,
    'Wallet': wallet,
    'Sound': sound,
  };
  factory AlertPreferences.fromJson(Map<String, dynamic> data) =>
      AlertPreferences(
        errands: data['Errands'] != false,
        messages: data['Messages'] != false,
        wallet: data['Wallet'] != false,
        sound: data['Sound'] != false,
      );
}

class PersonalPreferences extends ChangeNotifier {
  PersonalPreferences({PreferenceStorage? storage})
    : storage = storage ?? DevicePreferenceStorage();
  final PreferenceStorage storage;
  final Map<String, AlertPreferences> _accounts = {};
  final Map<String, bool> _roles = {};
  final Map<String, Map<String, dynamic>> _drafts = {};
  bool? roleFor(String? id) => _roles[id];
  Map<String, dynamic>? draftFor(String? id) =>
      _drafts[id] == null ? null : Map.of(_drafts[id]!);
  Future<void>? _loading;
  Future<void> _writes = Future.value();
  bool _storageReady = false;
  bool guideSeen = false;
  AlertPreferences forAccount(String? id) =>
      _accounts[id] ?? const AlertPreferences();

  Future<void> load() => _loading ??= _load();
  Future<void> _load() async {
    try {
      final raw = await storage.read().timeout(const Duration(seconds: 10));
      if (raw == null) {
        _storageReady = true;
        return;
      }
      final data = jsonDecode(raw) as Map<String, dynamic>;
      guideSeen = data['guideSeen'] == true;
      final accounts = data['accounts'] as Map<String, dynamic>? ?? {};
      final roles = data['roles'] as Map<String, dynamic>? ?? {};
      for (final entry in roles.entries) {
        if (entry.value is bool) _roles[entry.key] = entry.value;
      }
      final drafts = data['drafts'] as Map<String, dynamic>? ?? {};
      for (final entry in drafts.entries) {
        if (entry.value is Map<String, dynamic>) {
          _drafts[entry.key] = Map.of(entry.value);
        }
      }
      for (final entry in accounts.entries) {
        if (entry.value is Map<String, dynamic>) {
          _accounts[entry.key] = AlertPreferences.fromJson(entry.value);
        }
      }
      _storageReady = true;
    } catch (_) {
      // The app remains usable when device storage is unavailable.
    }
  }

  Future<void> _save() {
    if (!_storageReady) {
      return Future.error(
        StateError(
          'Settings apply for this session, but could not be saved on this device.',
        ),
      );
    }
    final value = jsonEncode({
      'guideSeen': guideSeen,
      'roles': _roles,
      'drafts': _drafts,
      'accounts': {
        for (final entry in _accounts.entries) entry.key: entry.value.toJson(),
      },
    });
    final write = _writes
        .then((_) => storage.write(value).timeout(const Duration(seconds: 10)))
        .catchError((_) {
          throw StateError(
            'Settings apply for this session, but could not be saved on this device.',
          );
        });
    _writes = write.catchError((_) {});
    return write;
  }

  Future<void> setAlert(String id, String type, bool enabled) async {
    await load();
    final values = forAccount(id).toJson();
    if (!values.containsKey(type)) {
      throw StateError('Unknown notification setting.');
    }
    values[type] = enabled;
    _accounts[id] = AlertPreferences.fromJson(values);
    notifyListeners();
    await _save();
  }

  Future<void> completeGuide() async {
    await load();
    guideSeen = true;
    notifyListeners();
    await _save();
  }

  Future<void> setRole(String id, bool runner) async {
    await load();
    _roles[id] = runner;
    await _save();
  }

  Future<void> saveDraft(String id, Map<String, dynamic>? draft) async {
    await load();
    if (draft == null) {
      _drafts.remove(id);
    } else {
      _drafts[id] = Map.of(draft);
    }
    await _save();
  }
}
