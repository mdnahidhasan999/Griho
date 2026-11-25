// noinspection SpellCheckingInspection
import 'dart:io';

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';

class ImageCompressionHelper {
  ImageCompressionHelper._();

  static int _counter = 0;

  /// ছবিকে কম্প্রেস করে (ডিফল্ট ৫০ KB-এর মধ্যে) রিটার্ন করবে।
  static Future<File?> compressImage(
    File file, {
    int maxSizeKb = 50,
    int initialQuality = 70,
    int minWidth = 600,
    int minHeight = 600,
  }) async {
    File? firstPassFile;
    try {
      final dir = await getTemporaryDirectory();
      final uniqueKey =
          '${DateTime.now().microsecondsSinceEpoch}_${++_counter}';
      final targetPath = '${dir.absolute.path}/temp_$uniqueKey.jpg';

      final result = await FlutterImageCompress.compressAndGetFile(
        file.absolute.path,
        targetPath,
        quality: initialQuality,
        minWidth: minWidth,
        minHeight: minHeight,
        format: CompressFormat.jpeg,
      );

      if (result == null) {
        return null;
      }

      firstPassFile = File(result.path);
      final sizeInKb = (await firstPassFile.length()) / 1024;

      if (sizeInKb > maxSizeKb) {
        final ultimatePath = '${dir.absolute.path}/ultimate_$uniqueKey.jpg';
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
