import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthSessionStorage {
  AuthSessionStorage({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(
                encryptedSharedPreferences: true,
                sharedPreferencesName: 'shared_prefs',
              ),
            );

  final FlutterSecureStorage _storage;

  static const _kLastSignedInUid = 'last_signed_in_uid';
  static const _kRememberEmail = 'remember_email';
  static const _kRememberPassword = 'remember_password';

  Future<void> setLastSignedInUid(String uid) {
    return _storage.write(key: _kLastSignedInUid, value: uid);
  }

  Future<String?> getLastSignedInUid() {
    return _storage.read(key: _kLastSignedInUid);
  }

  Future<void> clearLastSignedInUid() {
    return _storage.delete(key: _kLastSignedInUid);
  }

  Future<void> setRememberedCredentials({
    required String email,
    required String password,
  }) async {
    await _storage.write(key: _kRememberEmail, value: email);
    await _storage.write(key: _kRememberPassword, value: password);
  }

  Future<({String email, String password})?> getRememberedCredentials() async {
    final email = await _storage.read(key: _kRememberEmail);
    final password = await _storage.read(key: _kRememberPassword);
    if (email == null || email.trim().isEmpty) return null;
    if (password == null || password.isEmpty) return null;
    return (email: email, password: password);
  }

  Future<void> clearRememberedCredentials() async {
    await _storage.delete(key: _kRememberEmail);
    await _storage.delete(key: _kRememberPassword);
  }
}
