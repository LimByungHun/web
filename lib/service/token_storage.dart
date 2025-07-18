import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TokenStorage {
  static final _storage = FlutterSecureStorage();

  static Future<void> saveTokens(
    String accessToken,
    String refreshToken,
    String expiresAt, {
    required String userID,
    required String nickname,
  }) async {
    await _storage.write(key: 'access_token', value: accessToken);
    await _storage.write(key: 'refresh_token', value: refreshToken);
    await _storage.write(key: 'expires_at', value: expiresAt);
    await _storage.write(key: 'user_id', value: userID);
    await _storage.write(key: 'nickname', value: nickname);
  }

  static Future<String?> getAccessToken() async =>
      await _storage.read(key: 'access_token');
  static Future<String?> getRefreshToken() async =>
      await _storage.read(key: 'refresh_token');
  static Future<String?> getExpiresAt() async =>
      await _storage.read(key: 'expires_at');
  static Future<String?> getUserID() async =>
      await _storage.read(key: 'user_id');
  static Future<String?> getNickName() async =>
      await _storage.read(key: 'nickname');

  static Future<void> setRefreshToken(String token) async {
    await _storage.write(key: 'refresh_token', value: token);
  }

  static Future<void> setAccessToken(String token) async {
    await _storage.write(key: 'access_token', value: token);
  }

  static Future<void> setNickName(String nickname) async {
    await _storage.write(key: 'nickname', value: nickname);
  }

  static Future<void> clearTokens() async {
    await _storage.delete(key: 'access_token');
    await _storage.delete(key: 'refresh_token');
    await _storage.delete(key: 'expires_at');
    await _storage.delete(key: 'user_id');
    await _storage.delete(key: 'nickname');
  }
}
