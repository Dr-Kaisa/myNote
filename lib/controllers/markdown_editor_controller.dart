/*
 * 文件说明：所见即所得编辑控制器文件，负责在 Markdown 文本与 Quill 富文本文档之间转换。
 *
 * 页面和存储层继续使用 Markdown 字符串，编辑器内部使用 Quill 文档。
 * 这个控制器把两种格式的转换集中在一起，避免页面直接处理 Delta 数据。
 */
import 'dart:async';

import 'package:flutter/foundation.dart' show mapEquals;
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_quill/quill_delta.dart';
import 'package:markdown/markdown.dart' as markdown;
import 'package:markdown_quill/markdown_quill.dart';
import 'package:my_note/services/web_link_metadata_service.dart';
import 'package:my_note/utils/markdown_code_helper.dart';

/*
 * 等待站点名称返回的粘贴链接记录。
 */
class _PendingWebLink {
  /*
   * 构造等待处理的粘贴链接记录。
   */
  _PendingWebLink({
    required this.startOffset,
    required this.endOffset,
    required this.url,
    required this.documentVersion,
    required this.document,
  });

  /*
   * 链接文字在当前文档中的起始位置。
   */
  int startOffset;

  /*
   * 链接文字在当前文档中的结束位置。
   */
  int endOffset;

  /*
   * 用户粘贴的原始网址。
   */
  final String url;

  /*
   * 发起请求时的文档版本。
   */
  final int documentVersion;

  /*
   * 发起请求时实际编辑的文档对象。
   */
  final Document document;
}

/*
 * Markdown 所见即所得编辑控制器。
 *
 * ChangeNotifier 只在用户真正修改文档内容时通知页面，移动光标不会触发自动保存。
 */
class MarkdownEditorController extends ChangeNotifier {
  /*
   * 构造 Markdown 所见即所得编辑控制器。
   */
  MarkdownEditorController({
    String initialMarkdown = '',
    WebLinkSiteNameLoader? siteNameLoader,
  }) : _siteNameLoader =
           siteNameLoader ?? WebLinkMetadataService().loadSiteName,
       _markdownToDelta = MarkdownToDelta(
         markdownDocument: markdown.Document(
           encodeHtml: false,
           extensionSet: markdown.ExtensionSet.gitHubFlavored,
           blockSyntaxes: <markdown.BlockSyntax>[const EmbeddableTableSyntax()],
         ),
         customElementToEmbeddable: <String, ElementToEmbeddableConvertor>{
           EmbeddableTable.tableType: EmbeddableTable.fromMdSyntax,
         },
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
         customEmbedHandlers: <String, EmbedToMarkdown>{
           EmbeddableTable.tableType: EmbeddableTable.toMdSyntax,
         },
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
   * 根据网址异步读取站点名称的方法。
   */
  final WebLinkSiteNameLoader _siteNameLoader;

  /*
   * Quill 编辑器实际使用的控制器。
   */
  late final QuillController quillController;

  /*
   * 当前文档变化订阅。
   */
  StreamSubscription<DocChange>? _documentChangeSubscription;

  /*
   * 当前仍在等待站点名称的粘贴链接集合。
   */
  final List<_PendingWebLink> _pendingWebLinks = <_PendingWebLink>[];

  /*
   * 当前编辑文档版本，用于阻止旧网页请求修改新打开的笔记。
   */
  int _documentVersion = 0;

  /*
   * 已提前换算等待链接位置、尚未由监听器消费的自动替换次数。
   */
  int _pretransformedAutomaticChangeCount = 0;

  /*
   * 控制器是否已经释放。
   */
  bool _isDisposed = false;

  /*
   * 当前与富文本文档同步的 Markdown 文本。
   */
  String _markdown;

  /*
   * 获取当前 Markdown 文本。
   */
  String get markdownText => _markdown;

  /*
   * 把当前行或选区设置为指定语言的 Markdown 代码块。
   *
   * 空语言会移除围栏代码的语言标识，非空语言统一保存为小写。
   */
  void applyCodeBlock(String language) {
    final String normalizedLanguage = normalizeMarkdownCodeLanguage(language);

    quillController.formatSelection(Attribute.codeBlock);
    quillController.formatSelection(
      MarkdownCodeBlockLanguageAttribute(
        normalizedLanguage.isEmpty ? null : normalizedLanguage,
      ),
    );
  }

  /*
   * 使用新的 Markdown 文本替换编辑器内容。
   *
   * 这个方法用于加载或切换笔记，不会通知页面执行自动保存。
   */
  void loadMarkdown(String markdownText) {
    final Document previousDocument = quillController.document;

    _documentVersion += 1;
    _pendingWebLinks.clear();
    _pretransformedAutomaticChangeCount = 0;
    quillController.document = _createDocument(markdownText);
    _documentChangeSubscription?.cancel();
    _markdown = markdownText;
    quillController.moveCursorToEnd();
    previousDocument.close();
    _listenToDocumentChanges();
  }

  /*
   * 在当前选区插入独占一行的 Markdown 表格嵌入。
   *
   * 自定义表格嵌入不会由 Quill 自动补齐块级换行，因此这里使用同一次 Delta 事务
   * 插入必要的前置换行、表格和后置换行，保证段落中间插入后仍可重新载入且一次撤销。
   */
  void insertMarkdownTable(String tableMarkdown) {
    final TextSelection selection = quillController.selection;
    final String documentText = quillController.document.toPlainText();
    final int maximumIndex = quillController.document.length - 1;
    final int insertionIndex = selection.start < 0
        ? 0
        : selection.start > maximumIndex
        ? maximumIndex
        : selection.start;
    final int requestedEnd = selection.isValid ? selection.end : insertionIndex;
    final int selectionEnd = requestedEnd < insertionIndex
        ? insertionIndex
        : requestedEnd > maximumIndex
        ? maximumIndex
        : requestedEnd;
    final int replacementLength = selectionEnd - insertionIndex;
    final bool needsLeadingNewLine =
        insertionIndex > 0 && documentText[insertionIndex - 1] != '\n';
    final Delta change = Delta();

    if (insertionIndex > 0) {
      change.retain(insertionIndex);
    }
    if (needsLeadingNewLine) {
      change.insert('\n');
    }
    change
      ..insert(EmbeddableTable(tableMarkdown).toJson())
      ..insert('\n');
    if (replacementLength > 0) {
      change.delete(replacementLength);
    }

    quillController.compose(change, selection, ChangeSource.local);
    quillController.updateSelection(
      TextSelection.collapsed(
        offset: insertionIndex + (needsLeadingNewLine ? 1 : 0) + 2,
      ),
      ChangeSource.local,
    );
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
   * 跟随本次文档增删换算仍在等待的链接位置。
   */
  void _updatePendingWebLinkPositions(Delta change) {
    for (final _PendingWebLink pendingLink in _pendingWebLinks) {
      pendingLink.startOffset = change.transformPosition(
        pendingLink.startOffset,
        force: true,
      );
      pendingLink.endOffset = change.transformPosition(
        pendingLink.endOffset,
        force: false,
      );
    }
  }

  /*
   * 识别一次性插入的完整 http 或 https 网址，并开始加载站点名称。
   */
  void _handlePastedWebLinks(DocChange change) {
    if (change.source != ChangeSource.local) {
      return;
    }

    int documentOffset = 0;
    for (final Operation operation in change.change.toList()) {
      if (operation.isRetain) {
        documentOffset += operation.length ?? 0;
        continue;
      }

      if (!operation.isInsert) {
        continue;
      }

      if (operation.data is String) {
        final String insertedText = operation.data! as String;
        final String pastedUrl = insertedText.trim();
        final Uri? uri = Uri.tryParse(pastedUrl);
        if (pastedUrl.length > 1 &&
            !pastedUrl.contains(RegExp(r'\s')) &&
            uri != null &&
            uri.hasAuthority &&
            uri.host.isNotEmpty &&
            (uri.scheme.toLowerCase() == 'http' ||
                uri.scheme.toLowerCase() == 'https')) {
          final int startOffset =
              documentOffset + insertedText.indexOf(pastedUrl);
          final _PendingWebLink pendingLink = _PendingWebLink(
            startOffset: startOffset,
            endOffset: startOffset + pastedUrl.length,
            url: pastedUrl,
            documentVersion: _documentVersion,
            document: quillController.document,
          );
          _pendingWebLinks.add(pendingLink);

          if (!_isPendingWebLinkTextUnchanged(pendingLink)) {
            _pendingWebLinks.remove(pendingLink);
          } else if (_isPendingWebLinkInCodeContext(pendingLink)) {
            _pendingWebLinks.remove(pendingLink);
            if (_hasExpectedLinkAttribute(pendingLink)) {
              quillController.formatText(
                pendingLink.startOffset,
                pendingLink.url.length,
                Attribute.link,
              );
            }
          } else {
            if (!_hasExpectedLinkAttribute(pendingLink)) {
              quillController.formatText(
                pendingLink.startOffset,
                pendingLink.url.length,
                LinkAttribute(pendingLink.url),
              );
            }
            unawaited(_loadAndApplySiteName(pendingLink));
          }
        }

        documentOffset += insertedText.length;
      } else {
        documentOffset += operation.length ?? 0;
      }
    }
  }

  /*
   * 判断等待处理的链接仍属于原文档，并且对应范围仍是用户粘贴的原始网址。
   */
  bool _isPendingWebLinkTextUnchanged(_PendingWebLink pendingLink) {
    if (_isDisposed ||
        pendingLink.documentVersion != _documentVersion ||
        !identical(pendingLink.document, quillController.document) ||
        pendingLink.startOffset < 0 ||
        pendingLink.endOffset > quillController.document.length - 1 ||
        pendingLink.endOffset - pendingLink.startOffset !=
            pendingLink.url.length) {
      return false;
    }

    return quillController.document.getPlainText(
          pendingLink.startOffset,
          pendingLink.url.length,
        ) ==
        pendingLink.url;
  }

  /*
   * 判断网址是否位于代码块或行内代码中，代码字面量不参与站点名称替换。
   */
  bool _isPendingWebLinkInCodeContext(_PendingWebLink pendingLink) {
    final Style linkStyle = quillController.document.collectStyle(
      pendingLink.startOffset,
      pendingLink.url.length,
    );
    return linkStyle.attributes.containsKey(Attribute.codeBlock.key) ||
        linkStyle.attributes.containsKey(Attribute.inlineCode.key);
  }

  /*
   * 判断原始网址范围是否完整使用了正确的链接地址属性。
   */
  bool _hasExpectedLinkAttribute(_PendingWebLink pendingLink) {
    return quillController.document
            .collectStyle(pendingLink.startOffset, pendingLink.url.length)
            .attributes[Attribute.link.key]
            ?.value ==
        pendingLink.url;
  }

  /*
   * 判断等待处理的链接文字和链接地址都未被用户修改。
   */
  bool _isPendingWebLinkUnchanged(_PendingWebLink pendingLink) {
    return _isPendingWebLinkTextUnchanged(pendingLink) &&
        _hasExpectedLinkAttribute(pendingLink);
  }

  /*
   * 读取网址范围内统一使用的行内格式，局部格式不一致时取消自动改名。
   */
  Map<String, dynamic>? _readUniformInlineAttributes(
    _PendingWebLink pendingLink,
  ) {
    Map<String, dynamic>? uniformAttributes;
    for (final Operation operation
        in quillController.document
            .toDelta()
            .slice(pendingLink.startOffset, pendingLink.endOffset)
            .toList()) {
      final Map<String, dynamic> inlineAttributes = <String, dynamic>{};
      for (final MapEntry<String, dynamic> entry
          in (operation.attributes ?? <String, dynamic>{}).entries) {
        if (Attribute.fromKeyValue(entry.key, entry.value)?.scope ==
                AttributeScope.inline &&
            entry.key != Attribute.link.key) {
          inlineAttributes[entry.key] = entry.value;
        }
      }

      if (uniformAttributes == null) {
        uniformAttributes = inlineAttributes;
      } else if (!mapEquals(uniformAttributes, inlineAttributes)) {
        return null;
      }
    }

    return <String, dynamic>{
      ...?uniformAttributes,
      Attribute.link.key: pendingLink.url,
    };
  }

  /*
   * 等待站点名称返回，并仅在原链接保持不变时替换显示文字。
   */
  Future<void> _loadAndApplySiteName(_PendingWebLink pendingLink) async {
    String? loadedSiteName;
    try {
      loadedSiteName = await _siteNameLoader(pendingLink.url);
    } catch (_) {
      // 自定义加载方法异常时同样保留原始 URL。
    }

    if (!_pendingWebLinks.remove(pendingLink)) {
      return;
    }

    final String siteName = (loadedSiteName ?? '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (siteName.isEmpty ||
        siteName.runes.length > 100 ||
        siteName == pendingLink.url ||
        !_isPendingWebLinkUnchanged(pendingLink)) {
      return;
    }
    if (_isPendingWebLinkInCodeContext(pendingLink)) {
      quillController.formatText(
        pendingLink.startOffset,
        pendingLink.url.length,
        Attribute.link,
      );
      return;
    }
    final Map<String, dynamic>? replacementAttributes =
        _readUniformInlineAttributes(pendingLink);
    if (replacementAttributes == null) {
      return;
    }

    final Delta replacement = Delta();
    if (pendingLink.startOffset > 0) {
      replacement.retain(pendingLink.startOffset);
    }
    replacement
      ..insert(siteName, replacementAttributes)
      ..delete(pendingLink.url.length);

    _updatePendingWebLinkPositions(replacement);
    _pretransformedAutomaticChangeCount += 1;
    quillController.compose(
      replacement,
      quillController.selection,
      ChangeSource.silent,
    );
  }

  /*
   * 把用户修改后的 Quill 文档同步为 Markdown，并通知页面保存。
   */
  void _handleDocumentChanged(DocChange change) {
    if (change.source == ChangeSource.silent &&
        _pretransformedAutomaticChangeCount > 0) {
      _pretransformedAutomaticChangeCount -= 1;
    } else {
      _updatePendingWebLinkPositions(change.change);
    }

    _markdown = _deltaToMarkdown.convert(quillController.document.toDelta());
    notifyListeners();
    _handlePastedWebLinks(change);
  }

  /*
   * 释放文档订阅与 Quill 控制器。
   */
  @override
  void dispose() {
    _isDisposed = true;
    _documentVersion += 1;
    _pendingWebLinks.clear();
    _documentChangeSubscription?.cancel();
    quillController.dispose();
    super.dispose();
  }
}
