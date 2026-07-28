/*
 * 文件说明：Markdown 所见即所得编辑控制器测试文件，验证标题、列表和文本同步行为。
 */
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markdown_quill/markdown_quill.dart';
import 'package:my_note/controllers/markdown_editor_controller.dart';
import 'package:my_note/theme/app_theme.dart';
import 'package:my_note/utils/markdown_helper.dart';
import 'package:my_note/widgets/markdown_toolbar.dart';
import 'package:my_note/widgets/wysiwyg_markdown_editor.dart';

/*
 * 在自定义模式下直接把一个工具拖到指定目标位置。
 */
Future<void> dragToolbarAction(
  WidgetTester tester, {
  required Finder source,
  Finder? target,
  Offset? targetPosition,
}) async {
  assert(target != null || targetPosition != null);
  final TestGesture gesture = await tester.startGesture(
    tester.getCenter(source),
  );
  await tester.pump();
  await gesture.moveTo(targetPosition ?? tester.getCenter(target!));
  await tester.pump(const Duration(milliseconds: 100));
  await gesture.up();
  // 自定义模式会持续播放图标抖动，因此只推进落位和飞回动画所需时长。
  await tester.pump(const Duration(milliseconds: 350));
}

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
   * 验证选中文字后切换加粗会只修改当前选区。
   */
  test('选区加粗会同步生成 Markdown', () async {
    final MarkdownEditorController controller = MarkdownEditorController(
      initialMarkdown: '重点文字\n',
    );
    addTearDown(controller.dispose);

    controller.quillController.updateSelection(
      const TextSelection(baseOffset: 0, extentOffset: 2),
      ChangeSource.local,
    );
    controller.quillController.formatSelection(Attribute.bold);
    await Future<void>.delayed(Duration.zero);

    expect(controller.markdownText, startsWith('**重点**文字'));
  });

  /*
   * 验证插入的表格嵌入可以完整回写为 Markdown 表格。
   */
  test('表格嵌入可以往返保存为 Markdown', () async {
    final MarkdownEditorController controller = MarkdownEditorController(
      initialMarkdown: '前半后半\n',
    );
    addTearDown(controller.dispose);

    controller.quillController.updateSelection(
      const TextSelection.collapsed(offset: 2),
      ChangeSource.local,
    );
    controller.insertMarkdownTable('| 列 1 | 列 2 |\n| --- | --- |\n| 内容 | 内容 |');
    await Future<void>.delayed(Duration.zero);

    final String savedMarkdown = controller.markdownText;
    expect(savedMarkdown, contains('前半\n'));
    expect(controller.markdownText, contains('| 列 1 | 列 2 |'));
    expect(controller.markdownText, contains('| 内容 | 内容 |'));
    expect(savedMarkdown, contains('\n后半'));
    expect(
      controller.quillController.document.toDelta().toJson(),
      contains(
        isA<Map<String, dynamic>>().having(
          (Map<String, dynamic> operation) => operation['insert'],
          '表格嵌入',
          <String, dynamic>{
            EmbeddableTable.tableType:
                '| 列 1 | 列 2 |\n| --- | --- |\n| 内容 | 内容 |',
          },
        ),
      ),
    );

    final MarkdownEditorController reloadedController =
        MarkdownEditorController(initialMarkdown: savedMarkdown);
    addTearDown(reloadedController.dispose);
    expect(
      reloadedController.quillController.document.toDelta().toJson(),
      contains(
        isA<Map<String, dynamic>>().having(
          (Map<String, dynamic> operation) => operation['insert'],
          '重新载入的表格嵌入',
          isA<Map<String, dynamic>>().having(
            (Map<String, dynamic> insert) => insert.keys.single,
            '表格类型',
            EmbeddableTable.tableType,
          ),
        ),
      ),
    );

    controller.quillController.undo();
    await Future<void>.delayed(Duration.zero);
    expect(controller.quillController.document.toPlainText(), '前半后半\n');
    expect(controller.markdownText.trimRight(), '前半后半');
  });

  /*
   * 验证缓存工具名称会过滤未知项、已移除工具、重复项并限制为最多七项。
   */
  test('缓存工具顺序可以安全恢复', () {
    expect(
      toolbarActions.map((ToolbarActionItem action) => action.key),
      <ToolbarActionKey>[
        ToolbarActionKey.title,
        ToolbarActionKey.subtitle,
        ToolbarActionKey.heading3,
        ToolbarActionKey.heading4,
        ToolbarActionKey.heading5,
        ToolbarActionKey.heading6,
        ToolbarActionKey.bold,
        ToolbarActionKey.italic,
        ToolbarActionKey.list,
        ToolbarActionKey.orderedList,
      ],
    );
    expect(toolbarActionKeysFromNames(null), defaultToolbarActionKeys);
    expect(toolbarActionKeysFromNames(const <String>[]), isEmpty);
    expect(
      toolbarActionKeysFromNames(const <String>[
        'bold',
        'unknown',
        'bold',
        'heading6',
        'italic',
        'strikeThrough',
        'checkList',
        'blockQuote',
        'codeBlock',
      ]),
      <ToolbarActionKey>[
        ToolbarActionKey.bold,
        ToolbarActionKey.heading6,
        ToolbarActionKey.italic,
      ],
    );
    expect(
      toolbarActionKeyNames(const <ToolbarActionKey>[
        ToolbarActionKey.bold,
        ToolbarActionKey.insertTable,
        ToolbarActionKey.orderedList,
      ]),
      <String>['bold', 'orderedList'],
    );
    expect(
      toolbarActionKeysFromNames(const <String>['undo', 'redo']),
      defaultToolbarActionKeys,
    );
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
    tester.view.physicalSize = const Size(320, 360);
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
      findsNWidgets(defaultToolbarActionKeys.length),
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
      findsNWidgets(defaultToolbarActionKeys.length),
    );
    expect(tester.widget<Text>(find.text('H1')).style?.color, colors.onSurface);
  });

  /*
   * 验证切走编辑页导致失焦后，会清除 H5 工具的常亮视觉状态。
   */
  testWidgets('编辑器失焦会清除标题工具常亮状态', (WidgetTester tester) async {
    final MarkdownEditorController controller = MarkdownEditorController(
      initialMarkdown: '##### 五级标题\n',
    );
    final FocusNode focusNode = FocusNode();
    addTearDown(controller.dispose);
    addTearDown(focusNode.dispose);
    controller.quillController.updateSelection(
      const TextSelection.collapsed(offset: 1),
      ChangeSource.local,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: Focus(
            focusNode: focusNode,
            child: MarkdownToolbar(
              controller: controller.quillController,
              focusNode: focusNode,
              initialActionKeys: const <ToolbarActionKey>[
                ToolbarActionKey.heading5,
              ],
              onPressedAction: (ToolbarActionKey actionKey) {},
            ),
          ),
        ),
      ),
    );

    focusNode.requestFocus();
    await tester.pump();
    final Finder heading5Action = find.byKey(
      const ValueKey<String>('toolbar-active-heading5'),
    );
    expect(
      tester.widget<Material>(heading5Action).color,
      AppTheme.lightTheme.colorScheme.primary,
    );

    focusNode.unfocus();
    await tester.pump();

    expect(
      tester.widget<Material>(heading5Action).color,
      AppTheme.lightTheme.colorScheme.surfaceContainerHigh,
    );
    expect(controller.markdownText, '##### 五级标题\n');
    expect(
      controller.quillController.getSelectionStyle().attributes,
      containsPair(Attribute.header.key, Attribute.h5),
    );
  });

  /*
   * 验证 H6 和加粗工具作为已应用工具时可以回传对应动作。
   */
  testWidgets('新增格式工具可以回传 H6 和加粗动作', (WidgetTester tester) async {
    final MarkdownEditorController controller = MarkdownEditorController();
    addTearDown(controller.dispose);
    final List<ToolbarActionKey> pressedActions = <ToolbarActionKey>[];

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: MarkdownToolbar(
            controller: controller.quillController,
            initialActionKeys: const <ToolbarActionKey>[
              ToolbarActionKey.heading6,
              ToolbarActionKey.bold,
            ],
            onPressedAction: (ToolbarActionKey actionKey) {
              // 记录新增工具回传动作，供后续断言验证。
              pressedActions.add(actionKey);
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('H6'));
    await tester.tap(find.byIcon(Icons.format_bold_rounded));

    expect(pressedActions, <ToolbarActionKey>[
      ToolbarActionKey.heading6,
      ToolbarActionKey.bold,
    ]);
  });

  /*
   * 验证长按已应用工具后会展开全部工具仓库。
   */
  testWidgets('长按工具会进入自定义模式并展开仓库', (WidgetTester tester) async {
    final MarkdownEditorController controller = MarkdownEditorController();
    final MarkdownToolbarCustomizationController customizationController =
        MarkdownToolbarCustomizationController();
    addTearDown(controller.dispose);
    bool isCustomizing = false;
    tester.view.physicalSize = const Size(320, 360);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: StatefulBuilder(
            builder: (BuildContext context, StateSetter setHostState) {
              return Column(
                children: <Widget>[
                  MarkdownToolbar(
                    controller: controller.quillController,
                    customizationController: customizationController,
                    onPressedAction: (ToolbarActionKey actionKey) {},
                    onCustomizationChanged: (bool value) {
                      // 同步仓库浮层状态并切换测试正文可见性。
                      setHostState(() {
                        isCustomizing = value;
                      });
                    },
                  ),
                  Expanded(
                    child: isCustomizing
                        ? const SizedBox.expand()
                        : const Center(child: Text('笔记正文内容')),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey<String>('toolbar-repository')),
      findsNothing,
    );
    expect(find.text('笔记正文内容'), findsOneWidget);
    final Finder pressedAction = find.byKey(
      const ValueKey<String>('toolbar-active-title'),
    );
    final Offset originalCenter = tester.getCenter(pressedAction);
    final TestGesture gesture = await tester.startGesture(originalCenter);
    await tester.pump(const Duration(milliseconds: 600));

    // 长按成立后原工具继续留在原位置，只有后续移动才会带动浮层预览。
    expect(
      tester
          .getSize(
            find.byKey(const ValueKey<String>('toolbar-gap-indicator-0')),
          )
          .width,
      10,
    );
    expect(tester.getCenter(pressedAction), originalCenter);
    await gesture.up();
    await tester.pump(const Duration(milliseconds: 300));

    expect(isCustomizing, isTrue);
    expect(find.text('笔记正文内容'), findsNothing);
    expect(find.text('全部工具'), findsNothing);
    expect(find.byType(Divider), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('toolbar-repository-heading6')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('toolbar-repository-bold')),
      findsOneWidget,
    );
    final Finder firstRepositoryAction = find.byKey(
      const ValueKey<String>('toolbar-repository-heading6'),
    );
    final double firstRowTop = tester.getTopLeft(firstRepositoryAction).dy;
    for (final String actionName in <String>['bold', 'italic']) {
      expect(
        tester
            .getTopLeft(
              find.byKey(ValueKey<String>('toolbar-repository-$actionName')),
            )
            .dy,
        firstRowTop,
      );
    }
    expect(
      find.byKey(const ValueKey<String>('toolbar-repository-strikeThrough')),
      findsNothing,
    );
    expect(tester.getSize(firstRepositoryAction).height, 42);
    expect(tester.getSize(firstRepositoryAction).width, 42);
    expect(tester.getSize(pressedAction).height, 36);

    final Finder repositoryPressedAction = find.byKey(
      const ValueKey<String>('toolbar-repository-bold'),
    );
    final Offset repositoryOriginalCenter = tester.getCenter(
      repositoryPressedAction,
    );
    final Size repositoryOriginalSize = tester.getSize(repositoryPressedAction);
    final Size appliedActionSize = tester.getSize(pressedAction);
    final TestGesture repositoryGesture = await tester.startGesture(
      repositoryOriginalCenter + const Offset(12, 0),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 40));

    // 触碰后立即以工具自身中心收缩，不受手指实际触碰位置影响。
    expect(
      (tester.getCenter(repositoryPressedAction) - repositoryOriginalCenter)
          .distance,
      lessThan(0.01),
    );
    expect(
      tester.getSize(repositoryPressedAction).width,
      lessThan(repositoryOriginalSize.width),
    );
    await tester.pump(const Duration(milliseconds: 50));

    expect(tester.getSize(repositoryPressedAction), appliedActionSize);
    expect(
      find.byKey(const ValueKey<String>('toolbar-drag-feedback-bold')),
      findsNothing,
    );

    const Offset dragOffset = Offset(18, 10);
    await repositoryGesture.moveBy(dragOffset);
    await tester.pump();
    final Finder dragFeedback = find.byKey(
      const ValueKey<String>('toolbar-drag-feedback-bold'),
    );
    expect(dragFeedback, findsOneWidget);
    expect(
      (tester.getCenter(dragFeedback) - (repositoryOriginalCenter + dragOffset))
          .distance,
      lessThan(0.01),
    );
    expect(
      tester
          .widget<Opacity>(
            find.byKey(
              const ValueKey<String>('toolbar-drag-origin-repository-bold'),
            ),
          )
          .opacity,
      0,
    );
    await repositoryGesture.up();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(pressedAction);
    await tester.pump(const Duration(milliseconds: 300));
    expect(isCustomizing, isTrue);
    expect(
      find.byKey(const ValueKey<String>('toolbar-repository')),
      findsOneWidget,
    );

    customizationController.closeCustomization();
    await tester.pump(const Duration(milliseconds: 300));
    expect(isCustomizing, isFalse);
    expect(find.text('笔记正文内容'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('toolbar-repository')),
      findsNothing,
    );
  });

  /*
   * 验证从仓库工具间隙竖滑可以滚动查看下方工具。
   */
  testWidgets('工具仓库可以从工具间隙竖向滚动', (WidgetTester tester) async {
    final MarkdownEditorController controller = MarkdownEditorController();
    addTearDown(controller.dispose);
    tester.view.physicalSize = const Size(320, 140);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: MarkdownToolbar(
            controller: controller.quillController,
            initialActionKeys: const <ToolbarActionKey>[],
            onPressedAction: (ToolbarActionKey actionKey) {},
          ),
        ),
      ),
    );

    await tester.tap(
      find.byKey(const ValueKey<String>('toolbar-empty-customize')),
    );
    await tester.pump(const Duration(milliseconds: 300));
    final Finder firstRepositoryAction = find.byKey(
      const ValueKey<String>('toolbar-repository-title'),
    );
    final double originalTop = tester.getTopLeft(firstRepositoryAction).dy;
    final ScrollableState repositoryScrollState = tester.state<ScrollableState>(
      find.descendant(
        of: find.byKey(const ValueKey<String>('toolbar-repository')),
        matching: find.byType(Scrollable),
      ),
    );
    expect(
      tester
          .getSize(find.byKey(const ValueKey<String>('toolbar-repository')))
          .height,
      lessThan(140),
    );
    expect(repositoryScrollState.position.maxScrollExtent, greaterThan(0));

    final Rect firstActionRect = tester.getRect(firstRepositoryAction);
    final Rect secondActionRect = tester.getRect(
      find.byKey(const ValueKey<String>('toolbar-repository-subtitle')),
    );
    await tester.flingFrom(
      Offset(
        (firstActionRect.right + secondActionRect.left) / 2,
        firstActionRect.center.dy,
      ),
      const Offset(0, -100),
      2000,
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(repositoryScrollState.position.pixels, greaterThan(0));
    expect(tester.getTopLeft(firstRepositoryAction).dy, lessThan(originalTop));
  });

  /*
   * 验证仓库工具可以插入两个已应用工具之间并保存新顺序。
   */
  testWidgets('仓库工具可以拖入上栏插槽', (WidgetTester tester) async {
    final MarkdownEditorController controller = MarkdownEditorController();
    addTearDown(controller.dispose);
    List<ToolbarActionKey>? changedActionKeys;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: MarkdownToolbar(
            controller: controller.quillController,
            initialActionKeys: const <ToolbarActionKey>[
              ToolbarActionKey.title,
              ToolbarActionKey.subtitle,
            ],
            onPressedAction: (ToolbarActionKey actionKey) {},
            onActionKeysChanged: (List<ToolbarActionKey> actionKeys) {
              // 记录拖动完成后的工具顺序，供后续断言验证。
              changedActionKeys = actionKeys;
            },
          ),
        ),
      ),
    );

    await tester.longPress(
      find.byKey(const ValueKey<String>('toolbar-active-title')),
    );
    await tester.pump(const Duration(milliseconds: 300));
    final Rect subtitleRect = tester.getRect(
      find.byKey(const ValueKey<String>('toolbar-active-subtitle')),
    );
    await dragToolbarAction(
      tester,
      source: find.byKey(const ValueKey<String>('toolbar-repository-bold')),
      targetPosition: Offset(subtitleRect.left + 2, subtitleRect.center.dy),
    );

    expect(changedActionKeys, <ToolbarActionKey>[
      ToolbarActionKey.title,
      ToolbarActionKey.bold,
      ToolbarActionKey.subtitle,
    ]);
  });

  /*
   * 验证上栏只有一个工具时，最左和最右边缘都可以吸附仓库工具。
   */
  testWidgets('单工具栏左右边缘可以吸附仓库工具', (WidgetTester tester) async {
    final MarkdownEditorController controller = MarkdownEditorController();
    addTearDown(controller.dispose);
    List<ToolbarActionKey>? changedActionKeys;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: MarkdownToolbar(
            controller: controller.quillController,
            initialActionKeys: const <ToolbarActionKey>[ToolbarActionKey.title],
            onPressedAction: (ToolbarActionKey actionKey) {},
            onActionKeysChanged: (List<ToolbarActionKey> actionKeys) {
              // 记录单工具栏插入后的顺序，供后续断言验证。
              changedActionKeys = actionKeys;
            },
          ),
        ),
      ),
    );

    await tester.longPress(
      find.byKey(const ValueKey<String>('toolbar-active-title')),
    );
    await tester.pump(const Duration(milliseconds: 300));
    final Finder titleAction = find.byKey(
      const ValueKey<String>('toolbar-active-title'),
    );
    final Finder leadingGapIndicator = find.byKey(
      const ValueKey<String>('toolbar-gap-indicator-0'),
    );
    final Offset originalTitleCenter = tester.getCenter(titleAction);
    expect(tester.getSize(leadingGapIndicator).width, 10);

    final TestGesture gesture = await tester.startGesture(
      tester.getCenter(
        find.byKey(const ValueKey<String>('toolbar-repository-bold')),
      ),
    );
    await tester.pump();
    final Rect toolbarEdgeRect = tester.getRect(
      find.byKey(const ValueKey<String>('toolbar-edge-drop-target')),
    );
    await gesture.moveTo(
      Offset(toolbarEdgeRect.left + 1, toolbarEdgeRect.top + 1),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(tester.getSize(leadingGapIndicator).width, 28);
    expect(
      tester.getCenter(titleAction).dx,
      greaterThan(originalTitleCenter.dx),
    );
    final BoxDecoration gapDecoration =
        tester.widget<AnimatedContainer>(leadingGapIndicator).decoration
            as BoxDecoration;
    expect(gapDecoration.color, Colors.transparent);
    expect((gapDecoration.border! as Border).top.color, Colors.transparent);

    final Offset dropFeedbackCenter = tester.getCenter(
      find.byKey(const ValueKey<String>('toolbar-drag-feedback-bold')),
    );
    await gesture.up();
    await tester.pump();
    await tester.pump();

    final Finder landingFeedback = find.byKey(
      const ValueKey<String>('toolbar-landing-feedback-bold'),
    );
    final Finder landingDestination = find.byKey(
      const ValueKey<String>('toolbar-landing-destination-bold'),
    );
    expect(landingFeedback, findsOneWidget);
    expect(tester.widget<Opacity>(landingDestination).opacity, 0);
    final Offset landingStartCenter = tester.getCenter(landingFeedback);
    final Offset landingEndCenter = tester.getCenter(
      find.byKey(const ValueKey<String>('toolbar-active-bold')),
    );
    expect((landingStartCenter - dropFeedbackCenter).distance, lessThan(0.01));

    await tester.pump(const Duration(milliseconds: 110));
    expect(
      (tester.getCenter(landingFeedback) - landingEndCenter).distance,
      lessThan((landingStartCenter - landingEndCenter).distance),
    );
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pump();

    expect(landingFeedback, findsNothing);
    expect(tester.widget<Opacity>(landingDestination).opacity, 1);

    expect(changedActionKeys, <ToolbarActionKey>[
      ToolbarActionKey.bold,
      ToolbarActionKey.title,
    ]);

    await dragToolbarAction(
      tester,
      source: find.byKey(const ValueKey<String>('toolbar-repository-italic')),
      targetPosition: Offset(
        toolbarEdgeRect.right - 1,
        toolbarEdgeRect.top + 1,
      ),
    );

    expect(changedActionKeys, <ToolbarActionKey>[
      ToolbarActionKey.bold,
      ToolbarActionKey.title,
      ToolbarActionKey.italic,
    ]);
  });

  /*
   * 验证进入自定义模式后已应用工具可以直接调整顺序。
   */
  testWidgets('已应用工具可以在上栏直接重排', (WidgetTester tester) async {
    final MarkdownEditorController controller = MarkdownEditorController();
    addTearDown(controller.dispose);
    List<ToolbarActionKey>? changedActionKeys;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: MarkdownToolbar(
            controller: controller.quillController,
            initialActionKeys: const <ToolbarActionKey>[
              ToolbarActionKey.title,
              ToolbarActionKey.subtitle,
              ToolbarActionKey.heading3,
            ],
            onPressedAction: (ToolbarActionKey actionKey) {},
            onActionKeysChanged: (List<ToolbarActionKey> actionKeys) {
              // 记录上栏重排后的工具顺序，供后续断言验证。
              changedActionKeys = actionKeys;
            },
          ),
        ),
      ),
    );

    await tester.longPress(
      find.byKey(const ValueKey<String>('toolbar-active-title')),
    );
    await tester.pump(const Duration(milliseconds: 300));
    await dragToolbarAction(
      tester,
      source: find.byKey(const ValueKey<String>('toolbar-active-heading3')),
      target: find.byKey(const ValueKey<String>('toolbar-gap-1')),
    );

    expect(changedActionKeys, <ToolbarActionKey>[
      ToolbarActionKey.title,
      ToolbarActionKey.heading3,
      ToolbarActionKey.subtitle,
    ]);
  });

  /*
   * 验证已应用工具拖回仓库后工具栏可以少于七项。
   */
  testWidgets('已应用工具可以拖回仓库移除', (WidgetTester tester) async {
    final MarkdownEditorController controller = MarkdownEditorController();
    addTearDown(controller.dispose);
    List<ToolbarActionKey>? changedActionKeys;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: MarkdownToolbar(
            controller: controller.quillController,
            initialActionKeys: const <ToolbarActionKey>[
              ToolbarActionKey.title,
              ToolbarActionKey.subtitle,
            ],
            onPressedAction: (ToolbarActionKey actionKey) {},
            onActionKeysChanged: (List<ToolbarActionKey> actionKeys) {
              // 记录工具移回仓库后的剩余顺序，供后续断言验证。
              changedActionKeys = actionKeys;
            },
          ),
        ),
      ),
    );

    final Finder draggedAction = find.byKey(
      const ValueKey<String>('toolbar-active-subtitle'),
    );
    final Offset originalCenter = tester.getCenter(draggedAction);
    final TestGesture gesture = await tester.startGesture(originalCenter);
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(milliseconds: 300));

    // 第一次长按展开仓库后继续沿用当前手势，用户无需松手再拖一次。
    expect(tester.getCenter(draggedAction), originalCenter);
    expect(
      tester
          .widget<Opacity>(
            find.byKey(
              const ValueKey<String>('toolbar-drag-origin-applied-subtitle'),
            ),
          )
          .opacity,
      0,
    );
    final Finder repository = find.byKey(
      const ValueKey<String>('toolbar-repository'),
    );
    final Finder repositorySurface = find.byKey(
      const ValueKey<String>('toolbar-repository-surface'),
    );
    final Finder stationaryRepositoryAction = find.byKey(
      const ValueKey<String>('toolbar-repository-bold'),
    );
    final Rect originalRepositoryRect = tester.getRect(repository);
    final Rect originalRepositoryActionRect = tester.getRect(
      stationaryRepositoryAction,
    );
    await gesture.moveTo(
      Offset(
        originalRepositoryActionRect.left + 2,
        originalRepositoryActionRect.center.dy,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    // 上栏工具接触仓库时，下方不显示边框，工具保持尺寸并横向让出位置。
    expect(
      (tester.widget<DecoratedBox>(repositorySurface).decoration
              as BoxDecoration)
          .border,
      isNull,
    );
    expect(tester.getRect(repository), originalRepositoryRect);
    expect(
      tester.getSize(stationaryRepositoryAction).width,
      closeTo(originalRepositoryActionRect.width, 0.01),
    );
    expect(
      tester.getSize(stationaryRepositoryAction).height,
      closeTo(originalRepositoryActionRect.height, 0.01),
    );
    expect(
      tester.getCenter(stationaryRepositoryAction).dx,
      greaterThan(originalRepositoryActionRect.center.dx),
    );
    await gesture.up();
    await tester.pump(const Duration(milliseconds: 350));

    expect(changedActionKeys, <ToolbarActionKey>[ToolbarActionKey.title]);
    expect(
      find.byKey(const ValueKey<String>('toolbar-repository-subtitle')),
      findsOneWidget,
    );
  });

  /*
   * 验证已满七项时仓库工具不能插入插槽并显示容量提示。
   */
  testWidgets('七项工具栏会阻止仓库工具继续插入', (WidgetTester tester) async {
    final MarkdownEditorController controller = MarkdownEditorController();
    addTearDown(controller.dispose);
    List<ToolbarActionKey>? changedActionKeys;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: MarkdownToolbar(
            controller: controller.quillController,
            onPressedAction: (ToolbarActionKey actionKey) {},
            onActionKeysChanged: (List<ToolbarActionKey> actionKeys) {
              // 记录意外发生的顺序变化，确保满容量时保持原样。
              changedActionKeys = actionKeys;
            },
          ),
        ),
      ),
    );

    await tester.longPress(
      find.byKey(const ValueKey<String>('toolbar-active-title')),
    );
    await tester.pump(const Duration(milliseconds: 300));
    await dragToolbarAction(
      tester,
      source: find.byKey(const ValueKey<String>('toolbar-repository-bold')),
      target: find.byKey(const ValueKey<String>('toolbar-gap-1')),
    );

    expect(find.text('请先移除一个工具'), findsOneWidget);
    expect(changedActionKeys, isNull);
  });

  /*
   * 验证仓库工具落在图标中部时会替换目标并让原工具回到仓库。
   */
  testWidgets('工具落在图标中部会直接替换目标', (WidgetTester tester) async {
    final MarkdownEditorController controller = MarkdownEditorController();
    addTearDown(controller.dispose);
    List<ToolbarActionKey>? changedActionKeys;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: MarkdownToolbar(
            controller: controller.quillController,
            onPressedAction: (ToolbarActionKey actionKey) {},
            onActionKeysChanged: (List<ToolbarActionKey> actionKeys) {
              // 记录替换后的工具顺序，供后续断言验证。
              changedActionKeys = actionKeys;
            },
          ),
        ),
      ),
    );

    await tester.longPress(
      find.byKey(const ValueKey<String>('toolbar-active-title')),
    );
    await tester.pump(const Duration(milliseconds: 300));
    final Finder replacementTarget = find.byKey(
      const ValueKey<String>('toolbar-active-heading3'),
    );
    final TestGesture gesture = await tester.startGesture(
      tester.getCenter(
        find.byKey(const ValueKey<String>('toolbar-repository-bold')),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await gesture.moveTo(tester.getCenter(replacementTarget));
    await tester.pump(const Duration(milliseconds: 100));

    expect(
      ((tester
                          .widget<AnimatedContainer>(
                            find.byKey(
                              const ValueKey<String>(
                                'toolbar-replacement-heading3',
                              ),
                            ),
                          )
                          .decoration
                      as BoxDecoration)
                  .border
              as Border)
          .top
          .color,
      AppTheme.lightTheme.colorScheme.primary,
    );
    await gesture.up();
    await tester.pump(const Duration(milliseconds: 350));

    expect(changedActionKeys, contains(ToolbarActionKey.bold));
    expect(changedActionKeys, isNot(contains(ToolbarActionKey.heading3)));
    expect(changedActionKeys, hasLength(maximumToolbarActionCount));
    expect(
      find.byKey(const ValueKey<String>('toolbar-repository-heading3')),
      findsOneWidget,
    );
  });

  /*
   * 验证靠后的保留工具飞回仓库前会先滚动到仓库可见区域。
   */
  testWidgets('移除靠后工具时仓库会显示飞回终点', (WidgetTester tester) async {
    final MarkdownEditorController controller = MarkdownEditorController();
    addTearDown(controller.dispose);
    tester.view.physicalSize = const Size(320, 360);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: MarkdownToolbar(
            controller: controller.quillController,
            initialActionKeys: const <ToolbarActionKey>[
              ToolbarActionKey.heading6,
            ],
            onPressedAction: (ToolbarActionKey actionKey) {},
          ),
        ),
      ),
    );

    await tester.longPress(
      find.byKey(const ValueKey<String>('toolbar-active-heading6')),
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byTooltip('移除六级标题'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    final Rect repositoryRect = tester.getRect(
      find.byKey(const ValueKey<String>('toolbar-repository')),
    );
    final Rect returnedActionRect = tester.getRect(
      find.byKey(const ValueKey<String>('toolbar-repository-heading6')),
    );
    expect(repositoryRect.overlaps(returnedActionRect), isTrue);
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
