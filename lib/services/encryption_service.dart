import 'dart:convert';
import 'package:encrypt/encrypt.dart';
import 'package:crypto/crypto.dart';

class EncryptionService {
  static final EncryptionService _instance = EncryptionService._internal();
  factory EncryptionService() => _instance;
  EncryptionService._internal();

  String get _password {
    const salt = 'findit_backup_salt_2024';
    const iterations = 1000;
    final keyBytes = pbkdf2(
      utf8.encode(salt),
      utf8.encode('findit_app_key'),
      iterations,
      32,
      sha256,
    );
    return base64Encode(keyBytes);
  }

  Key get _key {
    final keyBytes = base64Decode(_password);
    return Key(keyBytes);
  }

  IV get _iv {
    final ivBytes = utf8.encode('findit_iv_16bytes!');
    return IV(ivBytes);
  }

  String encrypt(String plain) {
    final encrypter = Encrypter(AES(_key, mode: AESMode.cbc));
    final encrypted = encrypter.encrypt(plain, iv: _iv);
    return encrypted.base64;
  }

  String decrypt(String encrypted) {
    final encrypter = Encrypter(AES(_key, mode: AESMode.cbc));
    final decrypted = encrypter.decrypt64(encrypted, iv: _iv);
    return decrypted;
  }

  List<int> encryptBytes(List<int> bytes) {
    final encrypter = Encrypter(AES(_key, mode: AESMode.cbc));
    final encrypted = encrypter.encryptBytes(bytes, iv: _iv);
    return encrypted;
  }

  List<int> decryptBytes(List<int> encrypted) {
    final encrypter = Encrypter(AES(_key, mode: AESMode.cbc));
    final decrypted = encrypter.decryptBytes(encrypted, iv: _iv);
    return decrypted;
  }
}
