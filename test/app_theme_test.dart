/*
 * 文件说明：应用主题测试文件，验证亮暗配色和旧缓存主题字段兼容行为。
 */
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_note/services/app_cache_service.dart';
import 'package:my_note/theme/app_theme.dart';

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
}
