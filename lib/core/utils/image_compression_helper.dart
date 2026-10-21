import 'dart:io';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';

class ImageCompressionHelper {
  /// ছবিকে ২০-৫০ KB এর মধ্যে কম্প্রেস করে রিটার্ন করবে।
  static Future<File?> compressImage(File file) async {
    try {
      final dir = await getTemporaryDirectory();
      final targetPath = '${dir.absolute.path}/temp_${DateTime.now().millisecondsSinceEpoch}.jpg';

      var result = await FlutterImageCompress.compressAndGetFile(
        file.absolute.path,
        targetPath,
        quality: 70,
        minWidth: 512,
        minHeight: 512,
        format: CompressFormat.jpeg,
      );

      if (result == null) return null;

      var compressedFile = File(result.path);
      int sizeInBytes = await compressedFile.length();
      double sizeInKb = sizeInBytes / 1024;

      if (sizeInKb > 50) {
        final ultimatePath = '${dir.absolute.path}/ultimate_${DateTime.now().millisecondsSinceEpoch}.jpg';
        result = await FlutterImageCompress.compressAndGetFile(
          compressedFile.absolute.path,
          ultimatePath,
          quality: 40,
          minWidth: 400,
          minHeight: 400,
        );
        if (result != null) {
          compressedFile = File(result.path);
        }
      }

      return compressedFile;
    } catch (e) {
      return file;
    }
  }
}
