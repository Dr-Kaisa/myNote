/*
 * 文件说明：Markdown 文本处理工具文件，负责标题提取、摘要生成和基础编辑操作。
 */
import 'package:flutter/services.dart';

/*
 * Markdown 编辑结果模型。
 */
class MarkdownEditResult {
  /*
   * 构造 Markdown 编辑结果。
   */
  const MarkdownEditResult({
    required this.text,
    required this.selection,
  });

  /*
   * 编辑后的文本内容。
   */
  final String text;

  /*
   * 编辑后的光标选区。
   */
  final TextSelection selection;
}

/*
 * 补齐两位数字。
 */
String padNumber(int value) {
  return value.toString().padLeft(2, '0');
}

/*
 * 去掉 Markdown 标记，得到适合展示的纯文本。
 */
String stripMarkdownSyntax(String content) {
  return content
      .replaceAll(RegExp(r'^#{1,6}\s+', multiLine: true), '')
      .replaceAll(RegExp(r'^\s*[-*]\s+\[.\]\s+', multiLine: true), '')
      .replaceAll(RegExp(r'^\s*[-*]\s+', multiLine: true), '')
      .replaceAll(RegExp(r'^>\s+', multiLine: true), '')
      .replaceAll(RegExp(r'\*\*(.*?)\*\*'), r'$1')
      .replaceAll(RegExp(r'`(.*?)`'), r'$1')
      .trim();
}

/*
 * 生成新建笔记的默认内容。
 */
String createInitialNoteContent(String title) {
  return '# $title\n\n在这里记录今天的想法。\n';
}

/*
 * 从 Markdown 内容中提取标题文本。
 */
String extractNoteTitle(String content) {
  final List<String> lines = content.split('\n');

  for (final String line in lines) {
    final String cleanedLine = stripMarkdownSyntax(line).trim();
    if (cleanedLine.isNotEmpty) {
      return cleanedLine;
    }
  }

  return '未命名笔记';
}

/*
 * 从 Markdown 内容中提取摘要文本。
 */
String extractNotePreview(String content) {
  final String plainText = stripMarkdownSyntax(content).replaceAll(RegExp(r'\n+'), ' ').trim();

  if (plainText.isEmpty) {
    return '点击进入后开始记录内容';
  }

  return plainText.length > 72 ? plainText.substring(0, 72) : plainText;
}

/*
 * 将时间格式化为列表和编辑区展示文案。
 */
String formatNoteTime(DateTime value) {
  return '${padNumber(value.month)}-${padNumber(value.day)} ${padNumber(value.hour)}:${padNumber(value.minute)}';
}

/*
 * 计算当前选择范围所在行的起止位置。
 */
({int lineStart, int lineEnd}) getLineRange(String text, TextSelection selection) {
  final int safeStart = selection.start < 0 ? 0 : selection.start;
  final int safeEnd = selection.end < 0 ? safeStart : selection.end;
  final int lineStart = text.lastIndexOf('\n', safeStart > 0 ? safeStart - 1 : 0);
  final int lineEnd = text.indexOf('\n', safeEnd);

  return (
    lineStart: lineStart == -1 ? 0 : lineStart + 1,
    lineEnd: lineEnd == -1 ? text.length : lineEnd,
  );
}

/*
 * 为当前选区包裹前后 Markdown 标记。
 */
MarkdownEditResult applyWrapSyntax(
  String text,
  TextSelection selection,
  String prefix,
  String suffix,
  String placeholder,
) {
  final String selectedText = selection.isValid ? text.substring(selection.start, selection.end) : '';
  final String targetText = selectedText.isEmpty ? placeholder : selectedText;
  final int start = selection.isValid ? selection.start : text.length;
  final int end = selection.isValid ? selection.end : text.length;
  final String nextText = text.substring(0, start) + prefix + targetText + suffix + text.substring(end);
  final int nextSelectionStart = start + prefix.length;
  final int nextSelectionEnd = nextSelectionStart + targetText.length;

  return MarkdownEditResult(
    text: nextText,
    selection: TextSelection(baseOffset: nextSelectionStart, extentOffset: nextSelectionEnd),
  );
}

/*
 * 为当前单行或多行统一添加 Markdown 行前缀。
 */
MarkdownEditResult applyLinePrefixSyntax(
  String text,
  TextSelection selection,
  String prefix,
) {
  final ({int lineStart, int lineEnd}) lineRange = getLineRange(text, selection);
  final String selectedBlock = text.substring(lineRange.lineStart, lineRange.lineEnd);
  final List<String> lines = selectedBlock.split('\n');
  final String nextBlock = lines.map((String line) => '$prefix$line').join('\n');
  final String nextText = text.substring(0, lineRange.lineStart) + nextBlock + text.substring(lineRange.lineEnd);
  final int nextStart = selection.start + prefix.length;
  final int nextEnd = selection.end + prefix.length * lines.length;

  return MarkdownEditResult(
    text: nextText,
    selection: TextSelection(baseOffset: nextStart, extentOffset: nextEnd),
  );
}


