/*
 * 文件说明：应用主题测试文件，验证亮暗配色和旧缓存主题字段兼容行为。
 */
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_note/services/app_cache_service.dart';
import 'package:my_note/theme/app_theme.dart';

/*
 * 使用临时目录读写缓存的测试服务。
 */
class _TemporaryAppCacheService extends AppCacheService {
  /*
   * 构造临时缓存服务。
   */
  _TemporaryAppCacheService(this.directory);

  /*
   * 当前测试独享的临时目录。
   */
  final Directory directory;

  /*
   * 返回临时目录中的缓存文件，避免依赖平台文档目录插件。
   */
  @override
  Future<File> getCacheFile() async {
    return File(
      '${directory.path}${Platform.pathSeparator}${AppCacheService.cacheFileName}',
    );
  }
}

/*
 * 注册应用主题与缓存兼容相关测试。
 */
void main() {
  /*
   * 验证白天与暗色主题使用不同亮度和表面颜色。
   */
  test('应用提供完整的白天与暗色主题', () {
    expect(AppTheme.lightTheme.brightness, Brightness.light);
    expect(AppTheme.darkTheme.brightness, Brightness.dark);
    expect(
      AppTheme.lightTheme.colorScheme.surface,
      isNot(AppTheme.darkTheme.colorScheme.surface),
    );
    expect(
      AppTheme.lightTheme.colorScheme.onSurface,
      isNot(AppTheme.darkTheme.colorScheme.onSurface),
    );
  });

  /*
   * 验证旧缓存没有主题字段时仍然默认使用白天模式。
   */
  test('旧缓存默认使用白天模式', () {
    final AppCacheData cacheData = AppCacheData.fromJson(<String, dynamic>{
      'folderVisitCounts': <String, int>{},
      'sortMode': 'updatedAt',
      'viewMode': 'grid',
    });

    expect(cacheData.isDarkMode, isFalse);
    expect(cacheData.toolbarActionKeys, isNull);
  });

  /*
   * 验证暗色模式选择会写入缓存 JSON。
   */
  test('暗色模式选择可以写入缓存', () {
    const AppCacheData cacheData = AppCacheData(
      folderVisitCounts: <String, int>{},
      sortMode: 'updatedAt',
      viewMode: 'grid',
      isDarkMode: true,
    );

    expect(cacheData.toJson()['isDarkMode'], isTrue);
  });

  /*
   * 验证工具栏操作顺序会按照原顺序写入缓存 JSON。
   */
  test('工具栏操作顺序可以写入缓存', () {
    const AppCacheData cacheData = AppCacheData(
      folderVisitCounts: <String, int>{},
      sortMode: 'updatedAt',
      viewMode: 'grid',
      isDarkMode: false,
      toolbarActionKeys: <String>['bold', 'heading6', 'insertTable'],
    );

    expect(cacheData.toJson()['toolbarActionKeys'], <String>[
      'bold',
      'heading6',
      'insertTable',
    ]);
  });

  /*
   * 验证显式空工具栏操作列表在读取和写入后仍然保持为空。
   */
  test('工具栏空操作列表可以保留', () {
    final AppCacheData cacheData = AppCacheData.fromJson(<String, dynamic>{
      'folderVisitCounts': <String, int>{},
      'sortMode': 'updatedAt',
      'viewMode': 'grid',
      'isDarkMode': false,
      'toolbarActionKeys': <String>[],
    });

    expect(cacheData.toolbarActionKeys, isEmpty);
    expect(cacheData.toJson()['toolbarActionKeys'], isEmpty);
  });

  /*
   * 验证主题与工具栏同时保存时会串行合并，不会互相覆盖新值。
   */
  test('并发缓存更新会保留主题和工具栏最新值', () async {
    final Directory directory = await Directory.systemTemp.createTemp(
      'my_note_cache_test_',
    );
    addTearDown(() async {
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    });
    final AppCacheService themeService = _TemporaryAppCacheService(directory);
    final AppCacheService toolbarService = _TemporaryAppCacheService(directory);
    await themeService.saveCache(AppCacheData.defaults());

    final Future<void> themeUpdate = themeService.updateCache(
      (AppCacheData cacheData) => AppCacheData(
        folderVisitCounts: cacheData.folderVisitCounts,
        sortMode: cacheData.sortMode,
        viewMode: cacheData.viewMode,
        isDarkMode: true,
        toolbarActionKeys: cacheData.toolbarActionKeys,
      ),
    );
    final Future<void> toolbarUpdate = toolbarService.updateCache(
      (AppCacheData cacheData) => AppCacheData(
        folderVisitCounts: cacheData.folderVisitCounts,
        sortMode: cacheData.sortMode,
        viewMode: cacheData.viewMode,
        isDarkMode: cacheData.isDarkMode,
        toolbarActionKeys: const <String>['bold', 'insertTable'],
      ),
    );
    await Future.wait(<Future<void>>[themeUpdate, toolbarUpdate]);

    final AppCacheData savedCache = await themeService.loadCache();
    expect(savedCache.isDarkMode, isTrue);
    expect(savedCache.toolbarActionKeys, <String>['bold', 'insertTable']);
  });
}
