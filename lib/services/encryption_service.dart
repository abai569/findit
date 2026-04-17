import 'dart:convert';
import 'dart:typed_data';
import 'package:encrypt/encrypt.dart';
import 'package:crypto/crypto.dart';
import 'package:crypto/pbkdf2.dart';

class EncryptionService {
  static final EncryptionService _instance = EncryptionService._internal();
  factory EncryptionService() => _instance;
  EncryptionService._internal();

  Key get _key {
    final keyBytes = pbkdf2(
      sha256,
      utf8.encode('findit_app_key'),
      1000,
      32,
      utf8.encode('findit_backup_salt_2024'),
    );
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
    return encrypted.bytes;
  }

  List<int> decryptBytes(List<int> encrypted) {
    final encrypter = Encrypter(AES(_key, mode: AESMode.cbc));
    final decrypted = encrypter.decryptBytes(Encrypted(Uint8List.fromList(encrypted)), iv: _iv);
    return decrypted;
  }
}
