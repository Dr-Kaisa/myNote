/*
 * 文件说明：Markdown 文本处理工具文件，负责标题提取、摘要生成和基础编辑操作。
 *
 * 这个文件不负责界面，只负责处理字符串。
 * 页面里用户输入的是 Markdown 文本，这里把它转换成标题、摘要、标签、文件名，
 * 也负责在用户点工具栏按钮时修改选中的文本。
 */
import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;

/*
 * Markdown 编辑结果模型。
 *
 * 工具栏修改文本时，不只要返回新文本，还要返回新的光标位置。
 * 所以这里用一个对象同时保存 text 和 selection。
 */
class MarkdownEditResult {
  /*
   * 构造 Markdown 编辑结果。
   */
  const MarkdownEditResult({required this.text, required this.selection});

  /*
   * 编辑后的文本内容。
   *
   * 这是用户点按钮后应该放回输入框里的完整 Markdown 文本。
   */
  final String text;

  /*
   * 编辑后的光标选区。
   *
   * TextSelection 是 Flutter 文本框用来描述光标或选中文字范围的对象。
   */
  final TextSelection selection;
}

/*
 * 补齐两位数字。
 *
 * 例如 7 会变成 07，方便把时间显示成 07-06 这种固定宽度格式。
 */
String padNumber(int value) {
  return value.toString().padLeft(2, '0');
}

/*
 * 去掉 Markdown 标记，得到适合展示的纯文本。
 *
 * 首页卡片不需要显示 #、-、** 这类 Markdown 符号，所以先把这些语法符号清掉。
 * RegExp 是正则表达式，用来匹配一类文本格式。
 */
String stripMarkdownSyntax(String content) {
  return content
      // 去掉 Markdown 标题开头的 #，例如 "# 标题" 变成 "标题"。
      .replaceAll(RegExp(r'^#{1,6}\s+', multiLine: true), '')
      // 去掉待办列表前缀，例如 "- [ ] 事项" 变成 "事项"。
      .replaceAll(RegExp(r'^\s*[-*]\s+\[.\]\s+', multiLine: true), '')
      // 去掉有序列表前缀，例如 "1. 内容" 变成 "内容"。
      .replaceAll(RegExp(r'^\s*\d+\.\s+', multiLine: true), '')
      // 去掉普通列表前缀，例如 "- 内容" 变成 "内容"。
      .replaceAll(RegExp(r'^\s*[-*]\s+', multiLine: true), '')
      // 去掉引用符号，例如 "> 引用" 变成 "引用"。
      .replaceAll(RegExp(r'^>\s+', multiLine: true), '')
      // 去掉加粗符号，例如 "**重点**" 变成 "重点"。
      .replaceAll(RegExp(r'\*\*(.*?)\*\*'), r'$1')
      // 去掉行内代码反引号，例如 "`code`" 变成 "code"。
      .replaceAll(RegExp(r'`(.*?)`'), r'$1')
      // 去掉首尾空白，避免标题或摘要前后出现多余空格。
      .trim();
}

/*
 * 生成新建笔记的默认内容。
 *
 * 新建笔记本质上就是新建一个 .md 文件，这里先给它放入一个标题和一句提示。
 */
String createInitialNoteContent(String title) {
  return '# $title\n\n在这里记录今天的想法。\n';
}

/*
 * 从 Markdown 内容中提取标题文本。
 *
 * 规则：从上到下找第一行非空内容，去掉 Markdown 符号后作为标题。
 * 如果整篇都是空的，就显示“未命名笔记”。
 */
String extractNoteTitle(String content) {
  // Markdown 文本按换行切成多行，逐行查找可用标题。
  final List<String> lines = content.split('\n');

  for (final String line in lines) {
    // 每行先去掉 Markdown 符号，再去掉首尾空格。
    final String cleanedLine = stripMarkdownSyntax(line).trim();
    if (cleanedLine.isNotEmpty) {
      return cleanedLine;
    }
  }

  return '未命名笔记';
}

/*
 * 从 Markdown 内容中提取摘要文本。
 *
 * 摘要用于首页笔记卡片，只取纯文本的前 72 个字符。
 */
String extractNotePreview(String content) {
  // 先去掉 Markdown 符号，再把多个换行压成一个空格，让摘要显示成单段文字。
  final String plainText = stripMarkdownSyntax(
    content,
  ).replaceAll(RegExp(r'\n+'), ' ').trim();

  if (plainText.isEmpty) {
    return '点击进入后开始记录内容';
  }

  // 摘要过长时截断，防止卡片文字撑爆布局。
  return plainText.length > 72 ? plainText.substring(0, 72) : plainText;
}

/*
 * 从 Markdown 内容中提取标签列表。
 *
 * 标签格式是 #标签，例如“今天 #生活”会提取出“生活”。
 */
List<String> extractNoteTags(String content) {
  // 支持英文、数字、下划线、短横线和中文标签。
  final RegExp tagRegExp = RegExp(r'(^|\s)#([A-Za-z0-9_\-\u4e00-\u9fa5]+)');
  // Set 用来自动去重，避免同一个标签重复出现。
  final Set<String> tags = <String>{};

  for (final RegExpMatch match in tagRegExp.allMatches(content)) {
    // group(2) 对应正则里第二个括号，也就是真正的标签名。
    final String? tag = match.group(2);
    if (tag != null && tag.isNotEmpty) {
      tags.add(tag);
    }
  }

  return tags.toList()..sort();
}

/*
 * 将标题转换为适合保存为文件名的文本。
 *
 * Windows 和 Android 文件名不能包含 \ / : * ? " < > | 这些字符，所以要替换掉。
 */
String sanitizeFileName(String value) {
  final String sanitizedValue = value
      // 把非法文件名字符替换成空格。
      .replaceAll(RegExp(r'[\\/:*?"<>|]'), ' ')
      // 把连续空白压成一个空格，避免文件名很乱。
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  if (sanitizedValue.isEmpty) {
    return '未命名笔记';
  }

  // 文件名太长会影响可读性，也可能碰到系统路径长度限制，所以截短到 60 字符。
  return sanitizedValue.length > 60
      ? sanitizedValue.substring(0, 60).trim()
      : sanitizedValue;
}

/*
 * 基于标题生成 Markdown 文件名。
 *
 * 所有笔记都保存为 .md 文件，所以这里只要在安全标题后面追加扩展名。
 */
String createFileNameFromTitle(String title) {
  return '${sanitizeFileName(title)}.md';
}

/*
 * 从相对路径中提取目录部分。
 *
 * 例如 "工作/计划.md" 会得到 "工作"；
 * 根目录里的 "计划.md" 会得到空字符串。
 */
String extractDirectoryPath(String relativePath) {
  // 统一把 Windows 的反斜杠转成正斜杠，方便后续用 posix 规则处理。
  final String normalizedPath = relativePath.replaceAll('\\', '/');
  final String directoryPath = path.posix.dirname(normalizedPath);
  return directoryPath == '.' ? '' : directoryPath;
}

/*
 * 将时间格式化为列表和编辑区展示文案。
 *
 * 只显示月、日、小时、分钟，避免首页卡片里时间文字过长。
 */
String formatNoteTime(DateTime value) {
  return '${padNumber(value.month)}-${padNumber(value.day)} ${padNumber(value.hour)}:${padNumber(value.minute)}';
}

/*
 * 计算当前选择范围所在行的起止位置。
 *
 * 工具栏里的“列表”“待办”“引用”是按整行处理的。
 * 即使用户只选中一行中间几个字，也要找到这一整行的开始和结束位置。
 */
({int lineStart, int lineEnd}) getLineRange(
  String text,
  TextSelection selection,
) {
  // 有时没有有效选区，Flutter 会给 -1；这里把它兜底成安全位置。
  final int safeStart = selection.start < 0 ? 0 : selection.start;
  final int safeEnd = selection.end < 0 ? safeStart : selection.end;
  // 往前找上一个换行符，它后面就是当前行开头。
  final int lineStart = text.lastIndexOf(
    '\n',
    safeStart > 0 ? safeStart - 1 : 0,
  );
  // 往后找下一个换行符，它前面就是当前行结尾。
  final int lineEnd = text.indexOf('\n', safeEnd);

  return (
    lineStart: lineStart == -1 ? 0 : lineStart + 1,
    lineEnd: lineEnd == -1 ? text.length : lineEnd,
  );
}

/*
 * 为当前选区包裹前后 Markdown 标记。
 *
 * 例如加粗会把“文字”变成“**文字**”。
 * 如果用户没有选中文字，就插入 placeholder，并把 placeholder 选中方便直接输入覆盖。
 */
MarkdownEditResult applyWrapSyntax(
  String text,
  TextSelection selection,
  String prefix,
  String suffix,
  String placeholder,
) {
  // selection.isValid 表示当前光标选区是可用的。
  final String selectedText = selection.isValid
      ? text.substring(selection.start, selection.end)
      : '';
  // 没有选中文字时使用占位文字。
  final String targetText = selectedText.isEmpty ? placeholder : selectedText;
  // 有选区时替换选区；没有选区时插入到文本末尾。
  final int start = selection.isValid ? selection.start : text.length;
  final int end = selection.isValid ? selection.end : text.length;
  // 拼出新文本：选区前文本 + 前缀 + 目标文字 + 后缀 + 选区后文本。
  final String nextText =
      text.substring(0, start) +
      prefix +
      targetText +
      suffix +
      text.substring(end);
  // 新光标选区放在 Markdown 标记内部，方便用户继续编辑目标文字。
  final int nextSelectionStart = start + prefix.length;
  final int nextSelectionEnd = nextSelectionStart + targetText.length;

  return MarkdownEditResult(
    text: nextText,
    selection: TextSelection(
      baseOffset: nextSelectionStart,
      extentOffset: nextSelectionEnd,
    ),
  );
}

/*
 * 为当前单行或多行统一添加 Markdown 行前缀。
 *
 * 例如列表会把每一行前面加上 "- "；
 * 待办会加上 "- [ ] "；引用会加上 "> "。
 */
MarkdownEditResult applyLinePrefixSyntax(
  String text,
  TextSelection selection,
  String prefix,
) {
  // 先找出当前选区覆盖的完整行范围。
  final ({int lineStart, int lineEnd}) lineRange = getLineRange(
    text,
    selection,
  );
  // 截取被处理的整段文本。
  final String selectedBlock = text.substring(
    lineRange.lineStart,
    lineRange.lineEnd,
  );
  // 多行时逐行添加前缀。
  final List<String> lines = selectedBlock.split('\n');
  final String nextBlock = lines
      .map((String line) => '$prefix$line')
      .join('\n');
  // 把处理后的段落拼回原文本。
  final String nextText =
      text.substring(0, lineRange.lineStart) +
      nextBlock +
      text.substring(lineRange.lineEnd);
  // 因为前面插入了前缀，所以光标选区也要向后移动。
  final int nextStart = selection.start + prefix.length;
  final int nextEnd = selection.end + prefix.length * lines.length;

  return MarkdownEditResult(
    text: nextText,
    selection: TextSelection(baseOffset: nextStart, extentOffset: nextEnd),
  );
}
