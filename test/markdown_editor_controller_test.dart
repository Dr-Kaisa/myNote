/*
 * 文件说明：Markdown 所见即所得编辑控制器测试文件，验证标题、列表和文本同步行为。
 */
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_note/controllers/markdown_editor_controller.dart';
import 'package:my_note/theme/app_theme.dart';
import 'package:my_note/utils/markdown_helper.dart';
import 'package:my_note/widgets/markdown_toolbar.dart';
import 'package:my_note/widgets/wysiwyg_markdown_editor.dart';

/*
 * 注册 Markdown 所见即所得编辑控制器相关测试。
 */
void main() {
  /*
   * 验证 Markdown 的 H1 到 H6 与两类列表能正确转换成富文本块格式。
   */
  test('Markdown 标题与列表可以转换为所见即所得格式', () {
    final MarkdownEditorController controller = MarkdownEditorController(
      initialMarkdown: '''
# 一级
## 二级
### 三级
#### 四级
##### 五级
###### 六级

* 无序列表

1. 有序列表
''',
    );
    addTearDown(controller.dispose);

    expect(
      controller.quillController.document.toDelta().toJson(),
      containsAll(<Map<String, dynamic>>[
        <String, dynamic>{
          'insert': '\n',
          'attributes': <String, dynamic>{'header': 1},
        },
        <String, dynamic>{
          'insert': '\n',
          'attributes': <String, dynamic>{'header': 2},
        },
        <String, dynamic>{
          'insert': '\n',
          'attributes': <String, dynamic>{'header': 3},
        },
        <String, dynamic>{
          'insert': '\n',
          'attributes': <String, dynamic>{'header': 4},
        },
        <String, dynamic>{
          'insert': '\n',
          'attributes': <String, dynamic>{'header': 5},
        },
        <String, dynamic>{
          'insert': '\n',
          'attributes': <String, dynamic>{'header': 6},
        },
        <String, dynamic>{
          'insert': '\n',
          'attributes': <String, dynamic>{'list': 'bullet'},
        },
        <String, dynamic>{
          'insert': '\n',
          'attributes': <String, dynamic>{'list': 'ordered'},
        },
      ]),
    );
  });

  /*
   * 验证富文本格式变化后会重新生成 Markdown，并通知自动保存监听。
   */
  test('富文本格式变化会同步生成 Markdown', () async {
    final MarkdownEditorController controller = MarkdownEditorController(
      initialMarkdown: '# 标题\n',
    );
    addTearDown(controller.dispose);
    int changeCount = 0;
    controller.addListener(() {
      changeCount += 1;
    });

    controller.quillController.updateSelection(
      const TextSelection(baseOffset: 0, extentOffset: 2),
      ChangeSource.local,
    );
    controller.quillController.formatSelection(Attribute.h5);
    await Future<void>.delayed(Duration.zero);

    expect(controller.markdownText, startsWith('##### 标题'));
    expect(changeCount, 1);
  });

  /*
   * 验证切换笔记只是替换编辑内容，不会被识别成一次用户输入。
   */
  test('加载另一篇 Markdown 不会触发自动保存通知', () async {
    final MarkdownEditorController controller = MarkdownEditorController(
      initialMarkdown: '# 第一篇\n',
    );
    addTearDown(controller.dispose);
    int changeCount = 0;
    controller.addListener(() {
      changeCount += 1;
    });

    controller.loadMarkdown('## 第二篇\n');
    await Future<void>.delayed(Duration.zero);

    expect(controller.markdownText, '## 第二篇\n');
    expect(changeCount, 0);

    controller.quillController.updateSelection(
      const TextSelection(baseOffset: 0, extentOffset: 3),
      ChangeSource.local,
    );
    controller.quillController.formatSelection(Attribute.h3);
    await Future<void>.delayed(Duration.zero);

    expect(controller.markdownText, startsWith('### 第二篇'));
    expect(changeCount, 1);
  });

  /*
   * 验证普通标点和标签在富文本回写后不会被多余反斜杠破坏。
   */
  test('普通标点和标签可以原样回写 Markdown', () async {
    final MarkdownEditorController controller = MarkdownEditorController(
      initialMarkdown: 'Hello! #标签\n',
    );
    addTearDown(controller.dispose);

    controller.quillController.replaceText(
      controller.quillController.document.length - 1,
      0,
      '。',
      TextSelection.collapsed(
        offset: controller.quillController.document.length,
      ),
    );
    await Future<void>.delayed(Duration.zero);

    expect(controller.markdownText, contains('Hello! #标签。'));
    expect(controller.markdownText, isNot(contains(r'\#标签')));
    expect(extractNoteTags(controller.markdownText), contains('标签'));
  });

  /*
   * 验证窄屏工具栏展示 H1 到 H5 与两类列表图标，并能回传点击动作。
   */
  testWidgets('编辑工具栏包含标题和列表快捷入口', (WidgetTester tester) async {
    final MarkdownEditorController controller = MarkdownEditorController();
    addTearDown(controller.dispose);
    ToolbarActionKey? pressedAction;
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: MarkdownToolbar(
            controller: controller.quillController,
            onPressedAction: (ToolbarActionKey actionKey) {
              // 记录工具栏回传动作，供后续断言验证。
              pressedAction = actionKey;
            },
          ),
        ),
      ),
    );

    expect(find.text('H1'), findsOneWidget);
    expect(find.text('H2'), findsOneWidget);
    expect(find.text('H3'), findsOneWidget);
    expect(find.text('H4'), findsOneWidget);
    expect(find.text('H5'), findsOneWidget);
    expect(find.byIcon(Icons.format_list_bulleted_rounded), findsOneWidget);
    expect(find.byIcon(Icons.format_list_numbered_rounded), findsOneWidget);
    expect(find.byIcon(Icons.format_bold_rounded), findsNothing);
    expect(find.byIcon(Icons.check_box_outlined), findsNothing);
    expect(find.byIcon(Icons.format_quote_rounded), findsNothing);
    // 验证工具栏使用正文背景色，不再显示独立深色栏。
    expect(
      find.byWidgetPredicate(
        (Widget widget) =>
            widget is Container &&
            widget.decoration is BoxDecoration &&
            (widget.decoration! as BoxDecoration).color ==
                const Color(0xFFF6F6F6),
      ),
      findsOneWidget,
    );
    // 验证每个未选中的编辑按钮都有独立浅灰背景。
    expect(
      find.byWidgetPredicate(
        (Widget widget) =>
            widget is Material && widget.color == const Color(0xFFE8E8E8),
      ),
      findsNWidgets(toolbarActions.length),
    );

    await tester.tap(find.text('H5'));
    expect(pressedAction, ToolbarActionKey.heading5);

    pressedAction = null;
    controller.quillController.readOnly = true;
    await tester.tap(find.text('H4'));
    expect(pressedAction, isNull);
  });

  /*
   * 验证编辑工具栏会跟随暗色主题切换背景、按钮和文字颜色。
   */
  testWidgets('编辑工具栏支持暗色主题', (WidgetTester tester) async {
    final MarkdownEditorController controller = MarkdownEditorController();
    addTearDown(controller.dispose);
    final ColorScheme colors = AppTheme.darkTheme.colorScheme;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(
          body: MarkdownToolbar(
            controller: controller.quillController,
            onPressedAction: (ToolbarActionKey actionKey) {},
          ),
        ),
      ),
    );

    // 验证工具栏背景与暗色编辑主体保持一致。
    expect(
      find.byWidgetPredicate(
        (Widget widget) =>
            widget is Container &&
            widget.decoration is BoxDecoration &&
            (widget.decoration! as BoxDecoration).color ==
                colors.surfaceContainerLow,
      ),
      findsOneWidget,
    );
    // 验证每个未选中的按钮使用暗色独立背景。
    expect(
      find.byWidgetPredicate(
        (Widget widget) =>
            widget is Material && widget.color == colors.surfaceContainerHigh,
      ),
      findsNWidgets(toolbarActions.length),
    );
    expect(tester.widget<Text>(find.text('H1')).style?.color, colors.onSurface);
  });

  /*
   * 验证带图片语法的旧笔记可以安全打开，不会因缺少专用渲染器而崩溃。
   */
  testWidgets('旧 Markdown 图片可以使用安全回退样式展示', (WidgetTester tester) async {
    final MarkdownEditorController controller = MarkdownEditorController(
      initialMarkdown: '![图片](https://example.com/image.png)\n',
    );
    final FocusNode focusNode = FocusNode();
    final ScrollController scrollController = ScrollController();
    addTearDown(controller.dispose);
    addTearDown(focusNode.dispose);
    addTearDown(scrollController.dispose);

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates:
            FlutterQuillLocalizations.localizationsDelegates,
        supportedLocales: FlutterQuillLocalizations.supportedLocales,
        home: Scaffold(
          body: SizedBox(
            height: 320,
            child: WysiwygMarkdownEditor(
              controller: controller.quillController,
              focusNode: focusNode,
              scrollController: scrollController,
            ),
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.image_outlined), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  /*
   * 验证无序圆点、有序编号分别向下校正并与列表正文视觉对齐。
   */
  testWidgets('列表标记和正文视觉位置保持对齐', (WidgetTester tester) async {
    final MarkdownEditorController controller = MarkdownEditorController(
      initialMarkdown: '* 无序列表\n\n1. 有序列表\n',
    );
    final FocusNode focusNode = FocusNode();
    final ScrollController scrollController = ScrollController();
    addTearDown(controller.dispose);
    addTearDown(focusNode.dispose);
    addTearDown(scrollController.dispose);

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates:
            FlutterQuillLocalizations.localizationsDelegates,
        supportedLocales: FlutterQuillLocalizations.supportedLocales,
        home: Scaffold(
          body: SizedBox(
            height: 320,
            child: WysiwygMarkdownEditor(
              controller: controller.quillController,
              focusNode: focusNode,
              scrollController: scrollController,
            ),
          ),
        ),
      ),
    );

    expect(find.text('•'), findsOneWidget);
    expect(find.text('1.'), findsOneWidget);
    expect(find.text('无序列表', findRichText: true), findsOneWidget);
    expect(find.text('有序列表', findRichText: true), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('•')).dy,
      closeTo(
        tester.getTopLeft(find.text('无序列表', findRichText: true)).dy + 3,
        0.5,
      ),
    );
    expect(
      tester.getTopLeft(find.text('1.')).dy,
      closeTo(
        tester.getTopLeft(find.text('有序列表', findRichText: true)).dy + 3,
        0.5,
      ),
    );
    expect(
      tester.getSize(find.text('•')).height,
      closeTo(
        tester.getSize(find.text('无序列表', findRichText: true)).height,
        0.5,
      ),
    );
    expect(
      tester.getSize(find.text('1.')).height,
      closeTo(
        tester.getSize(find.text('有序列表', findRichText: true)).height,
        0.5,
      ),
    );
  });

  /*
   * 验证首页标题和摘要不会保留有序列表编号。
   */
  test('纯文本提取会去掉有序列表编号', () {
    expect(stripMarkdownSyntax('1. 第一项\n2. 第二项'), '第一项\n第二项');
  });
}
