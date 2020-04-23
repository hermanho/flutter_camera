import 'dart:io';
import 'package:path_provider/path_provider.dart';

class Constants {
  static Future<String> getMediaStorage() async {
    final Directory extDir = await getApplicationDocumentsDirectory();
    final String dirPath = '${extDir.path}/media';
    return dirPath;
  }
  static Future<String> getMediaThumbnailStorage() async {
    final Directory extDir = await getApplicationDocumentsDirectory();
    final String dirPath = '${extDir.path}/media-thumbnail';
    return dirPath;
  }
}
