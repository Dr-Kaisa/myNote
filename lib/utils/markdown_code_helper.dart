/*
 * 文件说明：Markdown 代码块辅助文件，负责规范化语言标识并定义语言属性。
 */
import 'package:flutter_quill/flutter_quill.dart';

/*
 * Markdown 代码块语言属性标识，与 markdown_quill 的围栏代码语言属性保持一致。
 */
const String markdownCodeBlockLanguageAttributeKey = 'x-md-codeblock-lang';

/*
 * 规范化 Markdown 代码块语言标识。
 *
 * 去掉首尾空白并统一转成小写，让 JaVa、javA 和 java 使用同一种高亮规则。
 */
String normalizeMarkdownCodeLanguage(String language) {
  return language.trim().toLowerCase();
}

/*
 * 可通过 Quill 块级格式操作写入的 Markdown 代码块语言属性。
 */
class MarkdownCodeBlockLanguageAttribute extends Attribute<String?> {
  /*
   * 构造 Markdown 代码块语言属性，null 表示移除语言标识。
   */
  const MarkdownCodeBlockLanguageAttribute(String? value)
    : super(markdownCodeBlockLanguageAttributeKey, AttributeScope.block, value);
}
