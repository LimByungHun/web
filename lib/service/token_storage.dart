import 'dart:js_interop';

@JS('window.localStorage')
external LocalStorage get localStorage;

@JS()
@staticInterop
class LocalStorage {}

extension LocalStorageExtension on LocalStorage {
  external String? operator [](String key);
  external void operator []=(String key, String? value);

  @JS('removeItem')
  external void remove(String key);
}

class TokenStorage {
  static Future<void> saveTokens(
    String accessToken,
    String refreshToken,
    String expiresAt, {
    required String userID,
    required String nickname,
  }) async {
    localStorage['access_token'] = accessToken;
    localStorage['refresh_token'] = refreshToken;
    localStorage['expires_at'] = expiresAt;
    localStorage['user_id'] = userID;
    localStorage['nickname'] = nickname;
  }

  static Future<String?> getAccessToken() async => localStorage['access_token'];

  static Future<String?> getRefreshToken() async =>
      localStorage['refresh_token'];

  static Future<String?> getExpiresAt() async => localStorage['expires_at'];

  static Future<String?> getUserID() async => localStorage['user_id'];

  static Future<String?> getNickName() async => localStorage['nickname'];

  static Future<void> setRefreshToken(String token) async {
    localStorage['refresh_token'] = token;
  }

  static Future<void> setAccessToken(String token) async {
    localStorage['access_token'] = token;
  }

  static Future<void> setNickName(String nickname) async {
    localStorage['nickname'] = nickname;
  }

  static Future<void> clearTokens() async {
    localStorage.remove('access_token');
    localStorage.remove('refresh_token');
    localStorage.remove('expires_at');
    localStorage.remove('user_id');
    localStorage.remove('nickname');
  }
}
