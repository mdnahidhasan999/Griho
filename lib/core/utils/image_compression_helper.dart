import 'dart:io';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';

class ImageCompressionHelper {
  ImageCompressionHelper._();

  /// ছবিকে ২০-৫০ KB এর মধ্যে কম্প্রেস করে রিটার্ন করবে।
  static Future<File?> compressImage(File file) async {
    File? firstPassFile;
    try {
      final dir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final targetPath = '${dir.absolute.path}/temp_$timestamp.jpg';

      var result = await FlutterImageCompress.compressAndGetFile(
        file.absolute.path,
        targetPath,
        quality: 70,
        minWidth: 600,
        minHeight: 600,
        format: CompressFormat.jpeg,
      );

      if (result == null) return null;

      firstPassFile = File(result.path);
      final int sizeInBytes = await firstPassFile.length();
      final double sizeInKb = sizeInBytes / 1024;

      if (sizeInKb > 50) {
        final ultimatePath = '${dir.absolute.path}/ultimate_$timestamp.jpg';
        final secondResult = await FlutterImageCompress.compressAndGetFile(
          firstPassFile.absolute.path,
          ultimatePath,
          quality: 42,
          minWidth: 450,
          minHeight: 450,
          format: CompressFormat.jpeg,
        );

        if (secondResult != null) {
          if (await firstPassFile.exists()) {
            await firstPassFile.delete();
          }
          return File(secondResult.path);
        }
      }

      return firstPassFile;
    } catch (_) {
      if (firstPassFile != null && await firstPassFile.exists()) {
        try {
          await firstPassFile.delete();
        } catch (_) {}
      }
      return null;
    }
  }
}
