/*
 * 文件说明：应用全局主题文件，统一定义白天与暗色模式的页面、文字、卡片和控件颜色。
 */
import 'package:flutter/material.dart';

/*
 * 应用主题配置。
 *
 * 页面通过 ColorScheme 的语义颜色读取样式，切换模式时无需分别维护每个组件状态。
 */
class AppTheme {
  /*
   * 应用品牌强调色。
   */
  static const Color _brandYellow = Color(0xFFFFC000);

  /*
   * 获取白天模式主题。
   */
  static ThemeData get lightTheme => _buildTheme(Brightness.light);

  /*
   * 获取暗色模式主题。
   */
  static ThemeData get darkTheme => _buildTheme(Brightness.dark);

  /*
   * 根据亮度构建完整应用主题。
   */
  static ThemeData _buildTheme(Brightness brightness) {
    final bool isDark = brightness == Brightness.dark;
    final ColorScheme colorScheme =
        ColorScheme.fromSeed(
          seedColor: _brandYellow,
          brightness: brightness,
        ).copyWith(
          // 品牌强调色样式
          primary: _brandYellow,
          onPrimary: const Color(0xFF171717),
          secondary: const Color(0xFFFFD43B),
          onSecondary: const Color(0xFF171717),
          tertiary: isDark ? _brandYellow : const Color(0xFF8A6500),
          onTertiary: isDark
              ? const Color(0xFF171717)
              : const Color(0xFFFFFFFF),
          // 页面与卡片层级背景样式
          surface: isDark ? const Color(0xFF121212) : const Color(0xFFF0F1F3),
          surfaceContainerLowest: isDark
              ? const Color(0xFF181818)
              : const Color(0xFFFFFFFF),
          surfaceContainerLow: isDark
              ? const Color(0xFF1B1B1B)
              : const Color(0xFFF6F6F6),
          surfaceContainer: isDark
              ? const Color(0xFF202020)
              : const Color(0xFFF3F3F3),
          surfaceContainerHigh: isDark
              ? const Color(0xFF292929)
              : const Color(0xFFE8E8E8),
          surfaceContainerHighest: isDark
              ? const Color(0xFF333333)
              : const Color(0xFFDFE0E2),
          // 正文、辅助文字与边框样式
          onSurface: isDark ? const Color(0xFFF2F2F2) : const Color(0xFF111111),
          onSurfaceVariant: isDark
              ? const Color(0xFFA8A8A8)
              : const Color(0xFF666666),
          outline: isDark ? const Color(0xFF4A4A4A) : const Color(0xFFD8D8D8),
          outlineVariant: isDark
              ? const Color(0xFF343434)
              : const Color(0xFFE1E1E1),
          // 反色界面与阴影样式
          inverseSurface: isDark
              ? const Color(0xFFF2F2F2)
              : const Color(0xFF202020),
          onInverseSurface: isDark
              ? const Color(0xFF202020)
              : const Color(0xFFF2F2F2),
          inversePrimary: _brandYellow,
          shadow: Colors.black,
          scrim: Colors.black,
        );

    return ThemeData(
      // 全局基础主题样式
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colorScheme.surface,
      canvasColor: colorScheme.surface,
      cardColor: colorScheme.surfaceContainerLowest,
      dividerColor: colorScheme.outlineVariant,
      iconTheme: IconThemeData(color: colorScheme.onSurface),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: _brandYellow,
        selectionColor: _brandYellow.withValues(alpha: 0.28),
        selectionHandleColor: _brandYellow,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colorScheme.surfaceContainerLowest,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colorScheme.surfaceContainerLowest,
        modalBackgroundColor: colorScheme.surfaceContainerLowest,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: _brandYellow,
        foregroundColor: Color(0xFF171717),
      ),
      useMaterial3: true,
    );
  }
}
