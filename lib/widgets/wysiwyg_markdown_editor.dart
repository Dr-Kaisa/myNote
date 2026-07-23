/*
 * 文件说明：所见即所得 Markdown 编辑器组件文件，负责展示可直接排版编辑的正文区域。
 *
 * 标题、列表和正文会按最终效果显示，Markdown 符号不会直接暴露在编辑界面中。
 */
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';

/*
 * 暂未提供专用渲染器的 Markdown 嵌入内容回退组件。
 *
 * 横线直接显示分隔线，图片等内容显示类型图标和原始地址，避免旧笔记打开时崩溃。
 */
class _MarkdownEmbedFallbackBuilder extends EmbedBuilder {
  /*
   * 构造 Markdown 嵌入内容回退组件。
   */
  const _MarkdownEmbedFallbackBuilder();

  /*
   * 回退组件标识。
   */
  @override
  String get key => 'markdown-fallback';

  /*
   * 构建横线、图片或其他嵌入内容的基础展示。
   */
  @override
  Widget build(BuildContext context, EmbedContext embedContext) {
    final ColorScheme colors = Theme.of(context).colorScheme;

    if (embedContext.node.value.type == 'divider') {
      return Padding(
        // Markdown 横线垂直间距样式
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Divider(height: 1, color: colors.outlineVariant),
      );
    }

    return Container(
      // Markdown 嵌入内容容器内边距样式
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      // Markdown 嵌入内容容器装饰样式
      decoration: BoxDecoration(
        color: colors.surfaceContainer,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        // Markdown 嵌入内容横向布局样式
        children: <Widget>[
          Icon(
            embedContext.node.value.type == BlockEmbed.imageType
                ? Icons.image_outlined
                : Icons.insert_drive_file_outlined,
            // Markdown 嵌入内容图标样式
            color: colors.onSurfaceVariant,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              embedContext.node.value.data.toString(),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              // Markdown 嵌入内容地址文字样式
              style: TextStyle(
                color: colors.onSurfaceVariant,
                fontSize: 13,
                height: 1.4,
                letterSpacing: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/*
 * 所见即所得 Markdown 编辑器组件。
 */
class WysiwygMarkdownEditor extends StatelessWidget {
  /*
   * 构造所见即所得 Markdown 编辑器。
   */
  const WysiwygMarkdownEditor({
    required this.controller,
    required this.focusNode,
    required this.scrollController,
    super.key,
  });

  /*
   * 编辑器富文本控制器。
   */
  final QuillController controller;

  /*
   * 编辑器焦点控制器。
   */
  final FocusNode focusNode;

  /*
   * 编辑器滚动控制器。
   */
  final ScrollController scrollController;

  /*
   * 创建标题或正文的块级文字样式。
   */
  DefaultTextBlockStyle _buildTextBlockStyle({
    required double fontSize,
    required FontWeight fontWeight,
    required double topSpacing,
    required double bottomSpacing,
    required Color color,
    double height = 1.5,
  }) {
    return DefaultTextBlockStyle(
      // 编辑器块级文字样式
      TextStyle(
        color: color,
        fontSize: fontSize,
        fontWeight: fontWeight,
        height: height,
        letterSpacing: 0,
        decoration: TextDecoration.none,
      ),
      HorizontalSpacing.zero,
      VerticalSpacing(topSpacing, bottomSpacing),
      VerticalSpacing.zero,
      null,
    );
  }

  /*
   * 创建有序列表与无序列表的块级样式。
   */
  DefaultListBlockStyle _buildListBlockStyle(Color textColor) {
    return DefaultListBlockStyle(
      // 编辑器列表文字样式
      TextStyle(
        color: textColor,
        fontSize: 17,
        height: 1.6,
        letterSpacing: 0,
        decoration: TextDecoration.none,
      ),
      HorizontalSpacing.zero,
      VerticalSpacing.zero,
      const VerticalSpacing(0, 4),
      null,
      null,
    );
  }

  /*
   * 构建编辑器各级标题、正文和列表样式。
   */
  DefaultStyles _buildEditorStyles(ColorScheme colors) {
    return DefaultStyles(
      // 一级标题样式
      h1: _buildTextBlockStyle(
        fontSize: 30,
        fontWeight: FontWeight.w800,
        topSpacing: 10,
        bottomSpacing: 8,
        color: colors.onSurface,
      ),
      // 二级标题样式
      h2: _buildTextBlockStyle(
        fontSize: 26,
        fontWeight: FontWeight.w700,
        topSpacing: 8,
        bottomSpacing: 6,
        color: colors.onSurface,
      ),
      // 三级标题样式
      h3: _buildTextBlockStyle(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        topSpacing: 7,
        bottomSpacing: 5,
        color: colors.onSurface,
      ),
      // 四级标题样式
      h4: _buildTextBlockStyle(
        fontSize: 19,
        fontWeight: FontWeight.w700,
        topSpacing: 6,
        bottomSpacing: 4,
        color: colors.onSurface,
      ),
      // 五级标题样式
      h5: _buildTextBlockStyle(
        fontSize: 17,
        fontWeight: FontWeight.w700,
        topSpacing: 5,
        bottomSpacing: 3,
        color: colors.onSurface,
      ),
      // 六级标题兼容样式
      h6: _buildTextBlockStyle(
        fontSize: 17,
        fontWeight: FontWeight.w600,
        topSpacing: 4,
        bottomSpacing: 2,
        color: colors.onSurface,
      ),
      // 正文段落样式
      paragraph: _buildTextBlockStyle(
        fontSize: 17,
        fontWeight: FontWeight.w400,
        topSpacing: 0,
        bottomSpacing: 0,
        color: colors.onSurface,
      ),
      // 编辑器列表样式
      lists: _buildListBlockStyle(colors.onSurface),
      // 列表圆点和数字样式，与列表正文保持相同基线
      leading: _buildTextBlockStyle(
        fontSize: 17,
        fontWeight: FontWeight.w400,
        topSpacing: 0,
        bottomSpacing: 0,
        color: colors.onSurface,
        height: 1.6,
      ),
      // 编辑器加粗文字样式
      bold: const TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0),
      // 编辑器链接文字样式
      link: TextStyle(
        color: colors.primary,
        decoration: TextDecoration.underline,
        letterSpacing: 0,
      ),
      // 编辑器占位文字样式
      placeHolder: _buildTextBlockStyle(
        fontSize: 17,
        fontWeight: FontWeight.w400,
        topSpacing: 0,
        bottomSpacing: 0,
        color: colors.onSurfaceVariant.withValues(alpha: 0.75),
      ),
    );
  }

  /*
   * 构建与列表正文视觉居中的圆点或序号。
   *
   * Quill 只按组件顶部排列列表标记，圆点和数字字形会比中文正文略高，
   * 因此统一向下校正 3 像素，同时保留内置的列表宽度与编号计算逻辑。
   */
  Widget? _buildAlignedListLeading(Node node, LeadingConfig config) {
    if (config.attribute == Attribute.ul) {
      return Transform.translate(
        offset: const Offset(0, 3),
        child: QuillBulletPoint(
          style: config.style!,
          width: config.width!,
          padding: config.padding!,
        ),
      );
    }

    if (config.attribute == Attribute.ol) {
      return Transform.translate(
        offset: const Offset(0, 3),
        child: QuillNumberPoint(
          index: config.getIndexNumberByIndent!,
          indentLevelCounts: config.indentLevelCounts,
          count: config.count,
          style: config.style!,
          attrs: config.attrs,
          width: config.width!,
          padding: config.padding!,
        ),
      );
    }

    return null;
  }

  /*
   * 构建所见即所得正文编辑区域。
   */
  @override
  Widget build(BuildContext context) {
    return QuillEditor(
      controller: controller,
      focusNode: focusNode,
      scrollController: scrollController,
      config: QuillEditorConfig(
        expands: true,
        scrollable: true,
        placeholder: '在这里记录今天的想法',
        // 编辑器正文内边距样式
        padding: const EdgeInsets.fromLTRB(22, 18, 22, 22),
        // 编辑器标题、列表和正文排版样式
        customStyles: _buildEditorStyles(Theme.of(context).colorScheme),
        // 列表圆点和序号按中文正文的视觉中心进行垂直校正。
        // Quill 暂时把自定义列表前导接口标记为实验接口，此处仅做局部使用。
        // ignore: experimental_member_use
        customLeadingBlockBuilder: _buildAlignedListLeading,
        // 未配置专用组件的旧 Markdown 内容使用安全回退展示。
        unknownEmbedBuilder: const _MarkdownEmbedFallbackBuilder(),
      ),
    );
  }
}
