import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:nai_huishi/core/constants/app_constants.dart';

class ImageUtils {
  ImageUtils._();

  /// 获取图片存储目录
  static Future<Directory> getImageDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final imageDir = Directory(p.join(appDir.path, AppConstants.imagesDirName));
    if (!await imageDir.exists()) {
      await imageDir.create(recursive: true);
    }
    return imageDir;
  }

  /// 保存 base64 图片到本地
  static Future<String> saveBase64Image(String base64Data, String filename) async {
    final dir = await getImageDirectory();
    final filePath = p.join(dir.path, filename);
    final file = File(filePath);
    final bytes = base64Decode(base64Data);
    await file.writeAsBytes(bytes);
    return filePath;
  }

  /// 从 URL 下载图片并保存到本地
  static Future<String> downloadAndSaveImage(String url, String filename) async {
    final dir = await getImageDirectory();
    return p.join(dir.path, filename);
  }

  /// 生成唯一文件名
  static String generateFilename() {
    final now = DateTime.now();
    final timestamp = now.millisecondsSinceEpoch;
    return 'nai_$timestamp.png';
  }

  /// 删除本地图片
  static Future<bool> deleteImage(String filePath) async {
    final file = File(filePath);
    if (await file.exists()) {
      await file.delete();
      return true;
    }
    return false;
  }

  /// 从 API 返回的 Markdown 中提取图片 URL
  static String? extractImageUrlFromMarkdown(String markdown) {
    final regex = RegExp(r'!\[image\]\((https?://[^\s)]+)\)');
    final match = regex.firstMatch(markdown);
    return match?.group(1);
  }

  /// 从 URL 提取文件名
  static String extractFilenameFromUrl(String url) {
    final uri = Uri.parse(url);
    final segments = uri.pathSegments;
    if (segments.isNotEmpty) {
      return segments.last;
    }
    return generateFilename();
  }
}
