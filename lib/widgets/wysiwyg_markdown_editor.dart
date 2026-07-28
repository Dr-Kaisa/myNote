/*
 * 文件说明：所见即所得 Markdown 编辑器组件文件，负责展示可直接排版编辑的正文区域。
 *
 * 标题、列表和正文会按最终效果显示，Markdown 符号不会直接暴露在编辑界面中。
 */
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:markdown/markdown.dart' as markdown;
import 'package:markdown_quill/markdown_quill.dart';

/*
 * Markdown 表格嵌入内容渲染组件。
 *
 * 表格内容通过 Markdown AST 读取，编辑器中以只读网格展示，列数较多时可以横向滚动。
 */
class _MarkdownTableEmbedBuilder extends EmbedBuilder {
  /*
   * 构造 Markdown 表格嵌入内容渲染组件。
   */
  const _MarkdownTableEmbedBuilder();

  /*
   * 表格嵌入内容标识。
   */
  @override
  String get key => EmbeddableTable.tableType;

  /*
   * 使用 GitHub Flavored Markdown 规则解析表格根节点。
   */
  markdown.Element? _parseTable(String markdownText) {
    try {
      for (final markdown.Node node in markdown.Document(
        encodeHtml: false,
        extensionSet: markdown.ExtensionSet.gitHubFlavored,
      ).parse(markdownText)) {
        if (node is markdown.Element && node.tag == 'table') {
          return node;
        }
      }
    } catch (_) {
      // 表格数据异常时交给基础回退组件展示原始内容，避免编辑器无法打开。
    }

    return null;
  }

  /*
   * 从 Markdown 表格 AST 中收集表头和表体行。
   */
  List<List<markdown.Element>> _readRows(markdown.Element table) {
    final List<List<markdown.Element>> rows = <List<markdown.Element>>[];

    for (final markdown.Node sectionNode
        in table.children ?? const <markdown.Node>[]) {
      if (sectionNode is! markdown.Element) {
        continue;
      }

      for (final markdown.Node rowNode
          in sectionNode.children ?? const <markdown.Node>[]) {
        if (rowNode is! markdown.Element || rowNode.tag != 'tr') {
          continue;
        }

        rows.add(
          (rowNode.children ?? const <markdown.Node>[])
              .whereType<markdown.Element>()
              .where(
                (markdown.Element cell) => cell.tag == 'th' || cell.tag == 'td',
              )
              .toList(growable: false),
        );
      }
    }

    return rows;
  }

  /*
   * 根据 Markdown 单元格对齐属性换算文字对齐方式。
   */
  TextAlign _readTextAlign(markdown.Element? cell) {
    return switch (cell?.attributes['align']) {
      'center' => TextAlign.center,
      'right' => TextAlign.right,
      _ => TextAlign.left,
    };
  }

  /*
   * 构建一个只读表格单元格。
   */
  Widget _buildCell({
    required markdown.Element? cell,
    required double width,
    required bool isLastColumn,
    required bool isLastRow,
    required ColorScheme colors,
  }) {
    final bool isHeader = cell?.tag == 'th';

    return Container(
      // 表格单元格宽度与最小高度样式
      width: width,
      constraints: const BoxConstraints(minHeight: 44),
      // 表格单元格内边距样式
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      // 表格单元格背景与分隔线样式
      decoration: BoxDecoration(
        color: isHeader ? colors.surfaceContainer : colors.surface,
        border: Border(
          right: isLastColumn
              ? BorderSide.none
              : BorderSide(color: colors.outlineVariant),
          bottom: isLastRow
              ? BorderSide.none
              : BorderSide(color: colors.outlineVariant),
        ),
      ),
      child: Text(
        cell?.textContent ?? '',
        textAlign: _readTextAlign(cell),
        // 表格单元格文字样式
        style: TextStyle(
          color: colors.onSurface,
          fontSize: 14,
          fontWeight: isHeader ? FontWeight.w700 : FontWeight.w400,
          height: 1.4,
          letterSpacing: 0,
        ),
      ),
    );
  }

  /*
   * 构建一行等高的表格单元格。
   */
  Widget _buildRow({
    required List<markdown.Element> cells,
    required int columnCount,
    required double cellWidth,
    required bool isLastRow,
    required ColorScheme colors,
  }) {
    return IntrinsicHeight(
      child: Row(
        // 表格行交叉轴拉伸样式
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: List<Widget>.generate(
          columnCount,
          (int columnIndex) => _buildCell(
            cell: columnIndex < cells.length ? cells[columnIndex] : null,
            width: cellWidth,
            isLastColumn: columnIndex == columnCount - 1,
            isLastRow: isLastRow,
            colors: colors,
          ),
          growable: false,
        ),
      ),
    );
  }

  /*
   * 构建只读 Markdown 表格网格。
   */
  @override
  Widget build(BuildContext context, EmbedContext embedContext) {
    final markdown.Element? table = _parseTable(
      embedContext.node.value.data.toString(),
    );
    if (table == null) {
      return const _MarkdownEmbedFallbackBuilder().build(context, embedContext);
    }

    final List<List<markdown.Element>> rows = _readRows(table);
    final int columnCount = rows.fold<int>(
      0,
      (int count, List<markdown.Element> row) =>
          row.length > count ? row.length : count,
    );
    if (columnCount == 0) {
      return const _MarkdownEmbedFallbackBuilder().build(context, embedContext);
    }

    return Padding(
      // Markdown 表格垂直间距样式
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final double availableWidth = constraints.maxWidth.isFinite
              ? constraints.maxWidth
              : columnCount * 112;
          final double dividedWidth = availableWidth / columnCount;
          final double cellWidth = dividedWidth < 112 ? 112 : dividedWidth;

          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Container(
              // Markdown 表格整体宽度样式
              width: cellWidth * columnCount,
              // Markdown 表格外框与圆角样式
              decoration: BoxDecoration(
                border: Border.all(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
                borderRadius: BorderRadius.circular(6),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                // Markdown 表格纵向布局样式
                mainAxisSize: MainAxisSize.min,
                children: List<Widget>.generate(
                  rows.length,
                  (int rowIndex) => _buildRow(
                    cells: rows[rowIndex],
                    columnCount: columnCount,
                    cellWidth: cellWidth,
                    isLastRow: rowIndex == rows.length - 1,
                    colors: Theme.of(context).colorScheme,
                  ),
                  growable: false,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

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
    this.metadataText,
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
   * 正文顶部随内容滚动的元信息文案。
   */
  final String? metadataText;

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
   * 按指定内边距构建使用原生滚动优化的 Quill 正文编辑区域。
   */
  Widget _buildQuillEditor(BuildContext context, EdgeInsets padding) {
    return QuillEditor(
      controller: controller,
      focusNode: focusNode,
      scrollController: scrollController,
      config: QuillEditorConfig(
        expands: true,
        scrollable: true,
        placeholder: '在这里记录今天的想法',
        // 编辑器正文内边距样式
        padding: padding,
        // 编辑器标题、列表和正文排版样式
        customStyles: _buildEditorStyles(Theme.of(context).colorScheme),
        // 列表圆点和序号按中文正文的视觉中心进行垂直校正。
        // Quill 暂时把自定义列表前导接口标记为实验接口，此处仅做局部使用。
        // ignore: experimental_member_use
        customLeadingBlockBuilder: _buildAlignedListLeading,
        // Markdown 表格使用只读网格组件展示。
        embedBuilders: const <EmbedBuilder>[_MarkdownTableEmbedBuilder()],
        // 未配置专用组件的旧 Markdown 内容使用安全回退展示。
        unknownEmbedBuilder: const _MarkdownEmbedFallbackBuilder(),
      ),
    );
  }

  /*
   * 构建所见即所得正文编辑区域。
   */
  @override
  Widget build(BuildContext context) {
    if (metadataText == null) {
      return _buildQuillEditor(context, const EdgeInsets.fromLTRB(0, 6, 0, 24));
    }

    return ClipRect(
      // 信息行与正文共用编辑区域裁剪图层样式
      clipBehavior: Clip.hardEdge,
      child: Stack(
        // 编辑器与信息行使用同一可用区域样式
        fit: StackFit.expand,
        children: <Widget>[
          _buildQuillEditor(context, const EdgeInsets.fromLTRB(0, 28, 0, 24)),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: AnimatedBuilder(
              animation: scrollController,
              child: IgnorePointer(
                child: Padding(
                  // 正文元信息紧凑顶部间距样式
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    metadataText!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    // 正文元信息文字样式
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 13,
                      height: 1.4,
                      letterSpacing: 0,
                    ),
                  ),
                ),
              ),
              builder: (BuildContext context, Widget? child) {
                // 信息行只跟随正文滚动偏移移动，不触发正文重新布局。
                return Transform.translate(
                  offset: Offset(
                    0,
                    scrollController.hasClients ? -scrollController.offset : 0,
                  ),
                  child: child,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
