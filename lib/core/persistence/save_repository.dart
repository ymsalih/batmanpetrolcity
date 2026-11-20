import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Kayıt deposu soyutlaması. İleride Hive veya bulut kaydı (Supabase) bu
/// arayüzü uygulayarak takılabilir.
abstract interface class SaveRepository {
  Map<String, dynamic>? load();
  Future<void> save(Map<String, dynamic> data);
  Future<void> clear();
}

class SharedPrefsSaveRepository implements SaveRepository {
  SharedPrefsSaveRepository(this._prefs);

  static const _key = 'batman_petrol_agasi_save';
  final SharedPreferences _prefs;

  @override
  Map<String, dynamic>? load() {
    final raw = _prefs.getString(_key);
    if (raw == null) return null;
    try {
      return Map<String, dynamic>.from(jsonDecode(raw) as Map);
    } catch (_) {
      return null; // Bozuk kayıt: yeni oyun başlat.
    }
  }

  @override
  Future<void> save(Map<String, dynamic> data) => _prefs.setString(_key, jsonEncode(data));

  @override
  Future<void> clear() => _prefs.remove(_key);
}

/// Testler için bellekte tutan depo.
class InMemorySaveRepository implements SaveRepository {
  InMemorySaveRepository([this.data]);
  Map<String, dynamic>? data;
  int saveCount = 0;

  @override
  Map<String, dynamic>? load() => data;

  @override
  Future<void> save(Map<String, dynamic> d) async {
    data = jsonDecode(jsonEncode(d)) as Map<String, dynamic>;
    saveCount++;
  }

  @override
  Future<void> clear() async => data = null;
}
