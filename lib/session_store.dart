import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The signed-in session: the backend URL and the local user.
///
/// Login is local for now — there is no user table on the backend, so the only
/// accepted credentials are [adminUsername] / [adminPassword]. The session is
/// persisted with `shared_preferences` so the app reopens signed in.
class SessionStore extends ChangeNotifier {
  SessionStore([this._preferences]);

  static const adminUsername = 'admin';
  static const adminPassword = '123';

  static const _urlKey = 'backend_url';
  static const _usernameKey = 'logged_in_user';

  SharedPreferences? _preferences;
  String? _url;
  String? _username;

  /// The backend base URL, or `null` when signed out.
  String? get url => _url;

  /// The signed-in user's name, or `null` when signed out.
  String? get username => _username;

  bool get isLoggedIn => _url != null && _username != null;

  /// Restores the persisted session, if any.
  Future<void> load() async {
    final prefs = _preferences ??= await SharedPreferences.getInstance();
    final url = prefs.getString(_urlKey);
    final username = prefs.getString(_usernameKey);
    if (url != null && username != null) {
      _url = url;
      _username = username;
    } else {
      _url = null;
      _username = null;
    }
    notifyListeners();
  }

  /// Validates the local credentials and opens a session.
  ///
  /// Returns `false` for wrong credentials or an invalid backend URL.
  Future<bool> login({
    required String url,
    required String username,
    required String password,
  }) async {
    final normalizedUrl = _normalizeUrl(url);
    if (normalizedUrl == null) return false;
    if (username.trim() != adminUsername || password != adminPassword) {
      return false;
    }

    final prefs = _preferences ??= await SharedPreferences.getInstance();
    await prefs.setString(_urlKey, normalizedUrl);
    await prefs.setString(_usernameKey, adminUsername);
    _url = normalizedUrl;
    _username = adminUsername;
    notifyListeners();
    return true;
  }

  /// Clears the persisted session.
  Future<void> logout() async {
    final prefs = _preferences ??= await SharedPreferences.getInstance();
    await prefs.remove(_urlKey);
    await prefs.remove(_usernameKey);
    _url = null;
    _username = null;
    notifyListeners();
  }

  /// Trims and validates an http(s) base URL, dropping a trailing slash.
  static String? _normalizeUrl(String url) {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return null;
    final uri = Uri.tryParse(trimmed);
    if (uri == null || !uri.hasScheme) return null;
    if (uri.scheme != 'http' && uri.scheme != 'https') return null;
    if (!uri.hasAuthority) return null;
    return trimmed.endsWith('/')
        ? trimmed.substring(0, trimmed.length - 1)
        : trimmed;
  }
}
