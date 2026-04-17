import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

class ImageService {
  static final ImageService _instance = ImageService._internal();
  factory ImageService() => _instance;
  ImageService._internal();

  final ImagePicker _picker = ImagePicker();

  Future<File?> pickImage() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: CameraDevice.rear,
    );

    if (image == null) return null;

    return File(image.path);
  }

  Future<File?> pickImageFromGallery() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
    );

    if (image == null) return null;

    return File(image.path);
  }

  Future<File?> compressImage(File imageFile) async {
    final appDir = await getApplicationDocumentsDirectory();
    final imagesDir = Directory('${appDir.path}/images');
    
    if (!await imagesDir.exists()) {
      await imagesDir.create(recursive: true);
    }

    final fileName = '${const Uuid().v4()}.jpg';
    final targetPath = '${imagesDir.path}/$fileName';

    try {
      final result = await FlutterImageCompress.compressAndGetFile(
        imageFile.absolute.path,
        targetPath,
        quality: 70,
        minWidth: 1024,
        minHeight: 1024,
        format: CompressFormat.jpeg,
      );

      if (result == null) {
        return await _fallbackCompress(imageFile, targetPath);
      }

      final fileSize = await result.length();
      if (fileSize > 500 * 1024) {
        return await _fallbackCompress(imageFile, targetPath);
      }

      return result;
    } catch (e) {
      return await _fallbackCompress(imageFile, targetPath);
    }
  }

  Future<File> _fallbackCompress(File imageFile, String targetPath) async {
    final result = await FlutterImageCompress.compressAndGetFile(
      imageFile.absolute.path,
      targetPath,
      quality: 50,
      minWidth: 800,
      minHeight: 800,
      format: CompressFormat.jpeg,
    );

    if (result != null) return result;

    return await imageFile.copy(targetPath);
  }

  Future<void> deleteImage(String? imagePath) async {
    if (imagePath == null) return;
    
    final file = File(imagePath);
    if (await file.exists()) {
      await file.delete();
    }
  }

  Future<String?> getCompressedImagePath(String? imagePath) async {
    if (imagePath == null) return null;
    return imagePath;
  }
}
