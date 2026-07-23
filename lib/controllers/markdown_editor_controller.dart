/*
 * 文件说明：所见即所得编辑控制器文件，负责在 Markdown 文本与 Quill 富文本文档之间转换。
 *
 * 页面和存储层继续使用 Markdown 字符串，编辑器内部使用 Quill 文档。
 * 这个控制器把两种格式的转换集中在一起，避免页面直接处理 Delta 数据。
 */
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_quill/quill_delta.dart';
import 'package:markdown/markdown.dart' as markdown;
import 'package:markdown_quill/markdown_quill.dart';

/*
 * Markdown 所见即所得编辑控制器。
 *
 * ChangeNotifier 只在用户真正修改文档内容时通知页面，移动光标不会触发自动保存。
 */
class MarkdownEditorController extends ChangeNotifier {
  /*
   * 构造 Markdown 所见即所得编辑控制器。
   */
  MarkdownEditorController({String initialMarkdown = ''})
    : _markdownToDelta = MarkdownToDelta(
        markdownDocument: markdown.Document(
          encodeHtml: false,
          extensionSet: markdown.ExtensionSet.gitHubFlavored,
        ),
        customElementToBlockAttribute:
            <String, List<Attribute<dynamic>> Function(markdown.Element)>{
              'h4': (_) => <Attribute<dynamic>>[
                const HeaderAttribute(level: 4),
              ],
              'h5': (_) => <Attribute<dynamic>>[
                const HeaderAttribute(level: 5),
              ],
              'h6': (_) => <Attribute<dynamic>>[
                const HeaderAttribute(level: 6),
              ],
            },
      ),
      _deltaToMarkdown = DeltaToMarkdown(
        customContentHandler: DeltaToMarkdown.escapeSpecialCharactersRelaxed,
      ),
      _markdown = initialMarkdown {
    quillController = QuillController(
      document: _createDocument(initialMarkdown),
      selection: const TextSelection.collapsed(offset: 0),
    );
    quillController.moveCursorToEnd();
    _listenToDocumentChanges();
  }

  /*
   * Markdown 转 Quill Delta 转换器。
   */
  final MarkdownToDelta _markdownToDelta;

  /*
   * Quill Delta 转 Markdown 转换器。
   */
  final DeltaToMarkdown _deltaToMarkdown;

  /*
   * Quill 编辑器实际使用的控制器。
   */
  late final QuillController quillController;

  /*
   * 当前文档变化订阅。
   */
  StreamSubscription<DocChange>? _documentChangeSubscription;

  /*
   * 当前与富文本文档同步的 Markdown 文本。
   */
  String _markdown;

  /*
   * 获取当前 Markdown 文本。
   */
  String get markdownText => _markdown;

  /*
   * 使用新的 Markdown 文本替换编辑器内容。
   *
   * 这个方法用于加载或切换笔记，不会通知页面执行自动保存。
   */
  void loadMarkdown(String markdownText) {
    final Document previousDocument = quillController.document;

    quillController.document = _createDocument(markdownText);
    _documentChangeSubscription?.cancel();
    _markdown = markdownText;
    quillController.moveCursorToEnd();
    previousDocument.close();
    _listenToDocumentChanges();
  }

  /*
   * 把 Markdown 文本转换成可编辑的 Quill 文档。
   */
  Document _createDocument(String markdownText) {
    if (markdownText.trim().isEmpty) {
      return Document();
    }

    try {
      return Document.fromDelta(_markdownToDelta.convert(markdownText));
    } catch (error) {
      // 转换器无法识别个别旧内容时回退为纯文本，保证这篇笔记仍然可以打开和编辑。
      return _createPlainTextDocument(markdownText);
    }
  }

  /*
   * 创建保留原始内容的纯文本 Quill 文档。
   */
  Document _createPlainTextDocument(String markdownText) {
    final Delta plainTextDelta = Delta()..insert(markdownText);

    if (!markdownText.endsWith('\n')) {
      plainTextDelta.insert('\n');
    }

    return Document.fromDelta(plainTextDelta);
  }

  /*
   * 监听当前 Quill 文档的实际内容变化。
   */
  void _listenToDocumentChanges() {
    _documentChangeSubscription = quillController.changes.listen(
      _handleDocumentChanged,
    );
  }

  /*
   * 把用户修改后的 Quill 文档同步为 Markdown，并通知页面保存。
   */
  void _handleDocumentChanged(DocChange _) {
    _markdown = _deltaToMarkdown.convert(quillController.document.toDelta());
    notifyListeners();
  }

  /*
   * 释放文档订阅与 Quill 控制器。
   */
  @override
  void dispose() {
    _documentChangeSubscription?.cancel();
    quillController.dispose();
    super.dispose();
  }
}
