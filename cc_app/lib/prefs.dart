import 'package:shared_preferences/shared_preferences.dart';

class SharedPrefs implements Prefs {
  final SharedPreferencesAsync inner;

  const SharedPrefs(this.inner);

  static Future<Prefs> loadPrefs() async {
    return SharedPrefs(
      SharedPreferencesAsync(options: SharedPreferencesOptions()),
    );
  }

  @override
  Future<void> setToken(String token) async {
    await inner.setString("token", token);
  }

  @override
  Future<String?> getToken() async {
    return await inner.getString("token");
  }

  @override
  Future<void> removeToken() async {
    await inner.remove("token");
  }
}

abstract class Prefs {
  Future<void> setToken(String token);
  Future<String?> getToken();
  Future<void> removeToken();
}
