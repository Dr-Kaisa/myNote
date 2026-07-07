/*
 * 文件说明：应用缓存服务文件，负责保存首页偏好、使用次数等非笔记正文数据。
 *
 * 这个文件只负责读写应用自己的缓存 JSON。
 * 笔记内容仍然由 NoteStorageService 保存成 Markdown 文件。
 * 后续如果要同步到云端，可以把这里的缓存结构作为同步数据来源。
 */
import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/*
 * 应用缓存数据模型。
 *
 * 当前包含首页常用状态：文件夹访问次数、排序方式和视图模式。
 */
class AppCacheData {
  /*
   * 构造应用缓存数据。
   */
  const AppCacheData({
    required this.folderVisitCounts,
    required this.sortMode,
    required this.viewMode,
  });

  /*
   * 默认缓存数据。
   */
  factory AppCacheData.defaults() {
    return const AppCacheData(
      folderVisitCounts: <String, int>{},
      sortMode: 'updatedAt',
      viewMode: 'grid',
    );
  }

  /*
   * 从 JSON 对象创建缓存数据。
   */
  factory AppCacheData.fromJson(Map<String, dynamic> json) {
    final Object? rawFolderVisitCounts = json['folderVisitCounts'];
    final Map<String, int> folderVisitCounts = <String, int>{};

    if (rawFolderVisitCounts is Map) {
      for (final MapEntry<dynamic, dynamic> entry
          in rawFolderVisitCounts.entries) {
        final dynamic value = entry.value;

        if (entry.key is String && value is num) {
          folderVisitCounts[entry.key as String] = value.toInt();
        }
      }
    }

    return AppCacheData(
      folderVisitCounts: folderVisitCounts,
      sortMode: json['sortMode'] is String
          ? json['sortMode'] as String
          : 'updatedAt',
      viewMode: json['viewMode'] is String
          ? json['viewMode'] as String
          : 'grid',
    );
  }

  /*
   * 文件夹访问次数。
   */
  final Map<String, int> folderVisitCounts;

  /*
   * 首页排序方式名称。
   */
  final String sortMode;

  /*
   * 首页视图模式名称。
   */
  final String viewMode;

  /*
   * 转换为 JSON 对象。
   */
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'folderVisitCounts': folderVisitCounts,
      'sortMode': sortMode,
      'viewMode': viewMode,
    };
  }
}

/*
 * 应用缓存服务。
 *
 * 使用应用文档目录下的 JSON 文件保存轻量配置，避免把偏好写进笔记正文目录。
 */
class AppCacheService {
  /*
   * 缓存文件名。
   */
  static const String cacheFileName = 'my_note_app_cache.json';

  /*
   * 获取缓存文件对象。
   */
  Future<File> getCacheFile() async {
    final Directory documentDirectory =
        await getApplicationDocumentsDirectory();
    return File(
      '${documentDirectory.path}${Platform.pathSeparator}$cacheFileName',
    );
  }

  /*
   * 读取应用缓存。
   */
  Future<AppCacheData> loadCache() async {
    try {
      final File cacheFile = await getCacheFile();

      if (!await cacheFile.exists()) {
        return AppCacheData.defaults();
      }

      final String content = await cacheFile.readAsString();
      final Object? jsonObject = jsonDecode(content);

      if (jsonObject is Map<String, dynamic>) {
        return AppCacheData.fromJson(jsonObject);
      }

      return AppCacheData.defaults();
    } catch (error) {
      return AppCacheData.defaults();
    }
  }

  /*
   * 保存应用缓存。
   */
  Future<void> saveCache(AppCacheData cacheData) async {
    final File cacheFile = await getCacheFile();

    if (!await cacheFile.parent.exists()) {
      await cacheFile.parent.create(recursive: true);
    }

    const JsonEncoder encoder = JsonEncoder.withIndent('  ');
    await cacheFile.writeAsString(
      encoder.convert(cacheData.toJson()),
      flush: true,
    );
  }
}
