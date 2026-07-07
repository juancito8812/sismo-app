class UpdateService {
  static const _kAvailable = 'update_available';
  static const _kUrl = 'update_url';
  static const _kInfo = 'update_info';
  static const _kBody = 'update_body';

  const UpdateService._();

  static Future<void> markAvailable({
    required String url,
    required String info,
    String? body,
  }) async {
    final prefs = await _prefs;
    await prefs.setBool(_kAvailable, true);
    await prefs.setString(_kUrl, url);
    await prefs.setString(_kInfo, info);
    if (body != null && body.trim().isNotEmpty) {
      await prefs.setString(_kBody, body);
    }
  }

  static Future<void> markUpdated() async {
    final prefs = await _prefs;
    await prefs.remove(_kAvailable);
    await prefs.remove(_kUrl);
    await prefs.remove(_kInfo);
    await prefs.remove(_kBody);
  }

  static Future<bool> get available async => (await _prefs).getBool(_kAvailable) ?? false;
  static Future<String?> get url async => (await _prefs).getString(_kUrl);
  static Future<String?> get info async => (await _prefs).getString(_kInfo);
  static Future<String?> get body async => (await _prefs).getString(_kBody);

  static Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();
}
