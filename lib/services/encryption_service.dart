import 'dart:convert';
import 'package:encrypt/encrypt.dart';
import 'package:crypto/crypto.dart';

class EncryptionService {
  static final EncryptionService _instance = EncryptionService._internal();
  factory EncryptionService() => _instance;
  EncryptionService._internal();

  Key? _key;
  IV? _iv;

  Key get key {
    _key ??= _generateKey();
    return _key!;
  }

  IV get iv {
    _iv ??= _generateIV();
    return _iv!;
  }

  Key _generateKey() {
    final bytes = utf8.encode('findit_app_key_2024_secure_password');
    final hash = sha256.convert(bytes);
    return Key(hash.bytes);
  }

  IV _generateIV() {
    final bytes = utf8.encode('findit_iv_16byte');
    return IV(Uint8List.fromList(bytes));
  }

  String encrypt(String plain) {
    try {
      final encrypter = Encrypter(AES(key, mode: AESMode.cbc));
      final encrypted = encrypter.encrypt(plain, iv: iv);
      return encrypted.base64;
    } catch (e) {
      throw Exception('加密失败：$e');
    }
  }

  String decrypt(String encrypted) {
    try {
      final encrypter = Encrypter(AES(key, mode: AESMode.cbc));
      final decrypted = encrypter.decrypt64(encrypted, iv: iv);
      return decrypted;
    } catch (e) {
      throw Exception('解密失败：$e');
    }
  }

  List<int> encryptBytes(List<int> bytes) {
    try {
      final encrypter = Encrypter(AES(key, mode: AESMode.cbc));
      final encrypted = encrypter.encryptBytes(bytes, iv: iv);
      return encrypted.bytes;
    } catch (e) {
      throw Exception('字节加密失败：$e');
    }
  }

  List<int> decryptBytes(List<int> encrypted) {
    try {
      final encrypter = Encrypter(AES(key, mode: AESMode.cbc));
      final decrypted = encrypter.decryptBytes(encrypted, iv: iv);
      return decrypted;
    } catch (e) {
      throw Exception('字节解密失败：$e');
    }
  }
}
