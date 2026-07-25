/*
 * 文件说明：Markdown 工具栏组件文件，提供常用的轻量编辑操作入口。
 *
 * 这个文件只负责“工具栏长什么样”和“点了哪个按钮”。
 * 真正把文字变成标题和列表的逻辑在 note_home_page.dart 和编辑控制器文件里。
 */
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';

/*
 * 工具栏动作类型。
 *
 * enum 是一组固定选项。
 * 这里用它表示工具栏支持哪些操作，避免到处写容易拼错的字符串。
 */
enum ToolbarActionKey {
  // 设置一级标题格式。
  title,

  // 设置二级标题格式。
  subtitle,

  // 设置三级标题格式。
  heading3,

  // 设置四级标题格式。
  heading4,

  // 设置五级标题格式。
  heading5,

  // 设置六级标题格式。
  heading6,

  // 切换选中文字的加粗格式。
  bold,

  // 切换选中文字的斜体格式。
  italic,

  // 切换选中文字的删除线格式。
  strikeThrough,

  // 把当前行变成无序列表项。
  list,

  // 把当前行变成有序列表项。
  orderedList,

  // 把当前行变成待办列表项。
  checkList,

  // 把当前行变成引用块。
  blockQuote,

  // 把当前行变成代码块。
  codeBlock,

  // 切换选中文字的行内代码格式。
  inlineCode,

  // 在当前光标位置插入表格。
  insertTable,

  // 撤销最近一次编辑。
  undo,

  // 重做最近一次撤销的编辑。
  redo,
}

/*
 * 工具拖动来源。
 *
 * 已应用工具和仓库工具落在同一位置时具有不同处理方式，
 * 因此拖动数据需要记录工具最初来自哪一个区域。
 */
enum _ToolbarActionSource {
  // 工具来自上方已应用工具栏。
  applied,

  // 工具来自下方全部工具仓库。
  repository,
}

/*
 * 工具栏动作数据模型。
 *
 * 这个类把内部动作 key、辅助文案和对应图标绑在一起。
 * 比如 key 是 ToolbarActionKey.list，按钮使用无序列表图标并显示对应提示。
 */
class ToolbarActionItem {
  /*
   * 构造工具栏动作项。
   */
  const ToolbarActionItem({
    required this.key,
    required this.label,
    this.icon,
    this.symbol,
  });

  /*
   * 动作唯一标识。
   *
   * 页面根据这个 key 判断用户点的是哪一级标题或哪一种列表。
   */
  final ToolbarActionKey key;

  /*
   * 按钮辅助文案。
   *
   * label 用于图标按钮的悬停提示和无障碍说明。
   */
  final String label;

  /*
   * Material 图标数据。
   *
   * 无序列表和有序列表使用系统熟悉的图标。
   */
  final IconData? icon;

  /*
   * 标题级别符号。
   *
   * Material 没有 H1 到 H5 的独立图标，所以使用紧凑字形表达层级。
   */
  final String? symbol;
}

/*
 * 工具栏按钮配置列表。
 *
 * MarkdownToolbar 会遍历这个列表，为每一项生成一个按钮。
 * 想增删工具栏按钮时，通常先改这里。
 */
const List<ToolbarActionItem> toolbarActions = <ToolbarActionItem>[
  ToolbarActionItem(key: ToolbarActionKey.title, label: '一级标题', symbol: 'H1'),
  ToolbarActionItem(
    key: ToolbarActionKey.subtitle,
    label: '二级标题',
    symbol: 'H2',
  ),
  ToolbarActionItem(
    key: ToolbarActionKey.heading3,
    label: '三级标题',
    symbol: 'H3',
  ),
  ToolbarActionItem(
    key: ToolbarActionKey.heading4,
    label: '四级标题',
    symbol: 'H4',
  ),
  ToolbarActionItem(
    key: ToolbarActionKey.heading5,
    label: '五级标题',
    symbol: 'H5',
  ),
  ToolbarActionItem(
    key: ToolbarActionKey.heading6,
    label: '六级标题',
    symbol: 'H6',
  ),
  ToolbarActionItem(
    key: ToolbarActionKey.bold,
    label: '加粗',
    icon: Icons.format_bold_rounded,
  ),
  ToolbarActionItem(
    key: ToolbarActionKey.italic,
    label: '斜体',
    icon: Icons.format_italic_rounded,
  ),
  ToolbarActionItem(
    key: ToolbarActionKey.strikeThrough,
    label: '删除线',
    icon: Icons.strikethrough_s_rounded,
  ),
  ToolbarActionItem(
    key: ToolbarActionKey.list,
    label: '无序列表',
    icon: Icons.format_list_bulleted_rounded,
  ),
  ToolbarActionItem(
    key: ToolbarActionKey.orderedList,
    label: '有序列表',
    icon: Icons.format_list_numbered_rounded,
  ),
  ToolbarActionItem(
    key: ToolbarActionKey.checkList,
    label: '待办列表',
    icon: Icons.check_box_outlined,
  ),
  ToolbarActionItem(
    key: ToolbarActionKey.blockQuote,
    label: '引用',
    icon: Icons.format_quote_rounded,
  ),
  ToolbarActionItem(
    key: ToolbarActionKey.codeBlock,
    label: '代码块',
    icon: Icons.data_object_rounded,
  ),
  ToolbarActionItem(
    key: ToolbarActionKey.inlineCode,
    label: '行内代码',
    icon: Icons.code_rounded,
  ),
  ToolbarActionItem(
    key: ToolbarActionKey.insertTable,
    label: '插入表格',
    icon: Icons.table_chart_outlined,
  ),
  ToolbarActionItem(
    key: ToolbarActionKey.undo,
    label: '撤销',
    icon: Icons.undo_rounded,
  ),
  ToolbarActionItem(
    key: ToolbarActionKey.redo,
    label: '重做',
    icon: Icons.redo_rounded,
  ),
];

/*
 * 工具栏允许应用的最大工具数量。
 */
const int maximumToolbarActionCount = 7;

/*
 * 首次使用和旧缓存缺少配置时采用的默认工具顺序。
 */
const List<ToolbarActionKey> defaultToolbarActionKeys = <ToolbarActionKey>[
  ToolbarActionKey.title,
  ToolbarActionKey.subtitle,
  ToolbarActionKey.heading3,
  ToolbarActionKey.heading4,
  ToolbarActionKey.heading5,
  ToolbarActionKey.list,
  ToolbarActionKey.orderedList,
];

/*
 * 根据动作标识查找完整工具配置。
 */
ToolbarActionItem toolbarActionForKey(ToolbarActionKey actionKey) {
  return toolbarActions.firstWhere(
    (ToolbarActionItem action) => action.key == actionKey,
  );
}

/*
 * 将缓存中的动作名称转换为有效工具列表。
 *
 * null 表示旧缓存还没有工具栏字段，此时恢复默认七项；显式空列表则原样保留，
 * 让用户可以把工具栏清空后再通过添加按钮重新打开工具仓库。
 */
List<ToolbarActionKey> toolbarActionKeysFromNames(Iterable<String>? names) {
  if (names == null) {
    return List<ToolbarActionKey>.from(defaultToolbarActionKeys);
  }

  final List<String> cachedNames = names.toList(growable: false);
  final List<ToolbarActionKey> result = <ToolbarActionKey>[];

  for (final String name in cachedNames) {
    for (final ToolbarActionKey actionKey in ToolbarActionKey.values) {
      if (actionKey.name == name && !result.contains(actionKey)) {
        result.add(actionKey);
        break;
      }
    }

    if (result.length == maximumToolbarActionCount) {
      break;
    }
  }

  if (cachedNames.isNotEmpty && result.isEmpty) {
    // 缓存内容全部失效时恢复默认值，避免损坏数据让工具栏永久不可用。
    return List<ToolbarActionKey>.from(defaultToolbarActionKeys);
  }

  return result;
}

/*
 * 将工具动作转换为可稳定写入缓存的枚举名称。
 */
List<String> toolbarActionKeyNames(Iterable<ToolbarActionKey> actionKeys) {
  return actionKeys
      .map((ToolbarActionKey actionKey) => actionKey.name)
      .toList();
}

/*
 * 工具栏拖动数据。
 */
class _ToolbarDragData {
  /*
   * 构造工具栏拖动数据。
   */
  const _ToolbarDragData({required this.actionKey, required this.source});

  /*
   * 当前拖动的工具标识。
   */
  final ToolbarActionKey actionKey;

  /*
   * 当前工具的拖动来源。
   */
  final _ToolbarActionSource source;
}

/*
 * Markdown 工具栏组件。
 *
 * 组件保存当前工具顺序和自定义交互状态，父页面只负责执行编辑动作与持久化结果。
 */
class MarkdownToolbar extends StatefulWidget {
  /*
   * 工具栏构造方法。
   */
  const MarkdownToolbar({
    required this.controller,
    required this.onPressedAction,
    this.initialActionKeys = defaultToolbarActionKeys,
    this.onActionKeysChanged,
    this.onCustomizationChanged,
    super.key,
  });

  /*
   * 当前所见即所得编辑器控制器。
   *
   * 工具栏根据当前光标所在位置读取格式，并展示按钮选中状态。
   */
  final QuillController controller;

  /*
   * 工具栏按钮点击回调。
   *
   * ValueChanged<ToolbarActionKey> 可以理解成一个函数：
   * 当用户点击按钮时，把对应的 ToolbarActionKey 传回父组件。
   */
  final ValueChanged<ToolbarActionKey> onPressedAction;

  /*
   * 首次创建组件时需要展示的工具顺序。
   */
  final List<ToolbarActionKey> initialActionKeys;

  /*
   * 工具顺序或数量改变后的回调。
   */
  final ValueChanged<List<ToolbarActionKey>>? onActionKeysChanged;

  /*
   * 工具仓库打开状态改变后的回调。
   */
  final ValueChanged<bool>? onCustomizationChanged;

  /*
   * 创建工具栏可变状态。
   */
  @override
  State<MarkdownToolbar> createState() => _MarkdownToolbarState();
}

/*
 * Markdown 工具栏状态对象。
 */
class _MarkdownToolbarState extends State<MarkdownToolbar>
    with SingleTickerProviderStateMixin {
  /*
   * 工具栏按钮固定高度。
   */
  static const double _toolbarButtonHeight = 40;

  /*
   * 插槽、仓库和飞行动画的统一时长。
   */
  static const Duration _toolbarAnimationDuration = Duration(milliseconds: 220);

  /*
   * 当前已经应用到上方工具栏的动作顺序。
   */
  late List<ToolbarActionKey> _appliedActionKeys;

  /*
   * 当前工具仓库使用的完整工具顺序。
   */
  late List<ToolbarActionKey> _repositoryActionOrder;

  /*
   * 已应用工具定位标识集合，用于计算飞回动画起点。
   */
  final Map<ToolbarActionKey, GlobalKey> _appliedActionKeysMap =
      <ToolbarActionKey, GlobalKey>{};

  /*
   * 仓库工具定位标识集合，用于计算飞回动画终点。
   */
  final Map<ToolbarActionKey, GlobalKey> _repositoryActionKeysMap =
      <ToolbarActionKey, GlobalKey>{};

  /*
   * 当前仍在播放的工具飞行动画浮层。
   */
  final List<OverlayEntry> _flyingActionEntries = <OverlayEntry>[];

  /*
   * 当前正在从松手位置移动到上栏最终位置的工具。
   */
  final Set<ToolbarActionKey> _landingActionKeys = <ToolbarActionKey>{};

  /*
   * 工具仓库独立浮层控制器。
   */
  final OverlayPortalController _repositoryOverlayController =
      OverlayPortalController();

  /*
   * 上方工具栏和仓库浮层之间的定位关联。
   */
  final LayerLink _repositoryLayerLink = LayerLink();

  /*
   * 空工具栏入口定位标识，用于没有已应用工具时计算仓库浮层高度。
   */
  final GlobalKey _emptyToolbarActionKey = GlobalKey();

  /*
   * 已应用图标抖动动画控制器。
   */
  late final AnimationController _shakeController;

  /*
   * 是否正在自定义工具栏。
   */
  bool _isCustomizing = false;

  /*
   * 当前被手指按住并等待拖动的仓库工具。
   */
  ToolbarActionKey? _pressedRepositoryActionKey;

  /*
   * 当前被拖动工具悬停的上栏插入位置。
   */
  int? _hoveredToolbarInsertionIndex;

  /*
   * 当前悬停在上栏插入位置的拖动数据。
   */
  _ToolbarDragData? _hoveredToolbarDragData;

  /*
   * 当前上栏工具准备放入仓库的位置。
   */
  int? _hoveredRepositoryInsertionIndex;

  /*
   * 最近一次从上方已应用工具采集到的实际尺寸。
   */
  Size _appliedActionSize = const Size(36, 36);

  /*
   * 工具仓库浮层从工具栏底部到页面底部的实际高度。
   */
  double _repositoryOverlayHeight = 0;

  /*
   * 初始化工具顺序与抖动动画。
   */
  @override
  void initState() {
    super.initState();
    _appliedActionKeys = _normalizeActionKeys(widget.initialActionKeys);
    _repositoryActionOrder = toolbarActions
        .map((ToolbarActionItem action) => action.key)
        .toList(growable: true);
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
  }

  /*
   * 父组件传入新的工具顺序时同步本地状态。
   */
  @override
  void didUpdateWidget(covariant MarkdownToolbar oldWidget) {
    super.didUpdateWidget(oldWidget);
    final List<ToolbarActionKey> nextActionKeys = _normalizeActionKeys(
      widget.initialActionKeys,
    );

    if (!_isCustomizing && !_areActionKeysEqual(nextActionKeys)) {
      _appliedActionKeys = nextActionKeys;
    }
  }

  /*
   * 释放抖动控制器和仍在播放的浮层动画。
   */
  @override
  void dispose() {
    _shakeController.dispose();
    for (final OverlayEntry entry in _flyingActionEntries) {
      entry.remove();
    }
    _flyingActionEntries.clear();
    super.dispose();
  }

  /*
   * 去重并限制外部传入的工具数量。
   */
  List<ToolbarActionKey> _normalizeActionKeys(
    Iterable<ToolbarActionKey> actionKeys,
  ) {
    final List<ToolbarActionKey> result = <ToolbarActionKey>[];

    for (final ToolbarActionKey actionKey in actionKeys) {
      if (!result.contains(actionKey)) {
        result.add(actionKey);
      }

      if (result.length == maximumToolbarActionCount) {
        break;
      }
    }

    return result;
  }

  /*
   * 判断外部工具顺序是否与本地状态完全相同。
   */
  bool _areActionKeysEqual(List<ToolbarActionKey> actionKeys) {
    if (actionKeys.length != _appliedActionKeys.length) {
      return false;
    }

    for (int index = 0; index < actionKeys.length; index++) {
      if (actionKeys[index] != _appliedActionKeys[index]) {
        return false;
      }
    }

    return true;
  }

  /*
   * 获取指定已应用工具的稳定定位标识。
   */
  GlobalKey _getAppliedActionKey(ToolbarActionKey actionKey) {
    return _appliedActionKeysMap.putIfAbsent(actionKey, GlobalKey.new);
  }

  /*
   * 获取指定仓库工具的稳定定位标识。
   */
  GlobalKey _getRepositoryActionKey(ToolbarActionKey actionKey) {
    return _repositoryActionKeysMap.putIfAbsent(actionKey, GlobalKey.new);
  }

  /*
   * 采集已应用工具的实际尺寸，供仓库按压态和拖动反馈复用。
   */
  void _captureAppliedActionSize() {
    if (_appliedActionKeys.isNotEmpty) {
      final Rect? appliedActionRect = _getGlobalRect(
        _getAppliedActionKey(_appliedActionKeys.first),
      );
      if (appliedActionRect != null) {
        _appliedActionSize = appliedActionRect.size;
      }
    }
  }

  /*
   * 获取最近采集的已应用工具尺寸，避免构建时读取正在替换的节点。
   */
  Size _getAppliedActionSize() {
    return _appliedActionSize;
  }

  /*
   * 手指触碰仓库工具时立即进入以自身中心收缩的按压状态。
   */
  void _startPressingRepositoryAction(ToolbarActionKey actionKey) {
    if (_pressedRepositoryActionKey == actionKey) {
      return;
    }

    _captureAppliedActionSize();
    setState(() {
      _pressedRepositoryActionKey = actionKey;
    });
  }

  /*
   * 手指松开、取消触碰或结束拖动时恢复仓库工具原始尺寸。
   */
  void _finishPressingRepositoryAction(ToolbarActionKey actionKey) {
    if (_pressedRepositoryActionKey != actionKey) {
      return;
    }

    setState(() {
      _pressedRepositoryActionKey = null;
    });
  }

  /*
   * 结束工具拖动并清除上下区域残留的悬停状态。
   */
  void _finishActionDrag(ToolbarActionKey actionKey) {
    final bool shouldClearPressedAction =
        _pressedRepositoryActionKey == actionKey;
    if (!shouldClearPressedAction &&
        _hoveredToolbarInsertionIndex == null &&
        _hoveredToolbarDragData == null &&
        _hoveredRepositoryInsertionIndex == null) {
      return;
    }

    setState(() {
      if (shouldClearPressedAction) {
        _pressedRepositoryActionKey = null;
      }
      _hoveredToolbarInsertionIndex = null;
      _hoveredToolbarDragData = null;
      _hoveredRepositoryInsertionIndex = null;
    });
  }

  /*
   * 更新上栏当前插入或替换悬停位置。
   */
  void _setToolbarDropHover({
    required _ToolbarDragData dragData,
    required int? insertionIndex,
  }) {
    if (_hoveredToolbarInsertionIndex == insertionIndex &&
        _hoveredToolbarDragData == dragData) {
      return;
    }

    setState(() {
      _hoveredToolbarInsertionIndex = insertionIndex;
      _hoveredToolbarDragData = dragData;
    });
  }

  /*
   * 清除上栏插入和替换悬停状态。
   */
  void _clearToolbarDropHover() {
    if (_hoveredToolbarInsertionIndex == null &&
        _hoveredToolbarDragData == null) {
      return;
    }

    setState(() {
      _hoveredToolbarInsertionIndex = null;
      _hoveredToolbarDragData = null;
    });
  }

  /*
   * 根据工具横向位置判断应插入左侧、替换中部还是插入右侧。
   */
  int? _getToolbarInsertionIndexForPosition(
    ToolbarActionKey actionKey,
    int actionIndex,
    Offset globalPosition,
  ) {
    final Rect? actionRect = _getGlobalRect(_getAppliedActionKey(actionKey));
    if (actionRect == null || actionRect.width <= 0) {
      return null;
    }

    final double horizontalProgress =
        (globalPosition.dx - actionRect.left) / actionRect.width;
    if (horizontalProgress < 0.4) {
      return actionIndex;
    }
    if (horizontalProgress > 0.6) {
      return actionIndex + 1;
    }
    return null;
  }

  /*
   * 将拖动反馈左上角坐标转换为实际用于落点判断的反馈中心坐标。
   */
  Offset _getDragFeedbackCenter(Offset feedbackTopLeft) {
    return feedbackTopLeft + _getAppliedActionSize().center(Offset.zero);
  }

  /*
   * 根据拖动反馈左上角坐标获取其全局矩形。
   */
  Rect _getDragFeedbackGlobalRect(Offset feedbackTopLeft) {
    return feedbackTopLeft & _getAppliedActionSize();
  }

  /*
   * 更新上栏工具准备放入仓库的位置。
   */
  void _setRepositoryDropHover(int? insertionIndex) {
    if (_hoveredRepositoryInsertionIndex == insertionIndex) {
      return;
    }

    setState(() {
      _hoveredRepositoryInsertionIndex = insertionIndex;
    });
  }

  /*
   * 根据仓库工具横向中点判断新工具应放在其左侧还是右侧。
   */
  int _getRepositoryInsertionIndexForPosition(
    ToolbarActionKey actionKey,
    int actionIndex,
    Offset globalPosition,
  ) {
    final Rect? actionRect = _getGlobalRect(_getRepositoryActionKey(actionKey));
    if (actionRect == null || globalPosition.dx < actionRect.center.dx) {
      return actionIndex;
    }
    return actionIndex + 1;
  }

  /*
   * 让拖动反馈在开始时以源工具中心为中心，避免跳到手指触发点。
   */
  Offset _centeredDragAnchorStrategy(
    Draggable<Object> draggable,
    BuildContext context,
    Offset globalPosition,
  ) {
    final RenderObject? renderObject = context.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) {
      return childDragAnchorStrategy(draggable, context, globalPosition);
    }

    final Offset sourceGlobalCenter = renderObject.localToGlobal(
      renderObject.size.center(Offset.zero),
    );
    final Offset feedbackTopLeft =
        sourceGlobalCenter - _getAppliedActionSize().center(Offset.zero);
    return globalPosition - feedbackTopLeft;
  }

  /*
   * 开始工具栏自定义模式并播放已应用图标抖动动画。
   */
  void _enterCustomizationMode() {
    if (_isCustomizing || widget.controller.readOnly) {
      return;
    }

    FocusScope.of(context).unfocus();
    _captureAppliedActionSize();
    setState(() {
      _isCustomizing = true;
      _repositoryOverlayHeight = _calculateRepositoryOverlayHeight();
    });
    _repositoryOverlayController.show();
    widget.onCustomizationChanged?.call(true);
    _shakeController.repeat(reverse: true);
  }

  /*
   * 完成工具栏自定义并停止图标抖动。
   */
  void _leaveCustomizationMode() {
    if (!_isCustomizing) {
      return;
    }

    _shakeController
      ..stop()
      ..value = 0;
    setState(() {
      _isCustomizing = false;
      _hoveredToolbarInsertionIndex = null;
      _hoveredToolbarDragData = null;
      _hoveredRepositoryInsertionIndex = null;
      _repositoryOverlayHeight = 0;
    });
    _repositoryOverlayController.hide();
    widget.onCustomizationChanged?.call(false);
  }

  /*
   * 更新已应用工具并通知父页面持久化。
   */
  void _setAppliedActionKeys(
    List<ToolbarActionKey> actionKeys, {
    ToolbarActionKey? landingActionKey,
  }) {
    setState(() {
      if (landingActionKey != null) {
        _landingActionKeys.add(landingActionKey);
      }
      _appliedActionKeys = _normalizeActionKeys(actionKeys);
    });
    widget.onActionKeysChanged?.call(
      List<ToolbarActionKey>.unmodifiable(_appliedActionKeys),
    );
  }

  /*
   * 显示工具栏自定义过程中的短提示。
   */
  void _showToolbarMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(milliseconds: 1500),
        ),
      );
  }

  /*
   * 把工具放入指定插槽，仓库工具达到七项上限时保持原状并提示。
   */
  void _insertDraggedAction(
    _ToolbarDragData dragData,
    int insertionIndex, {
    Rect? landingStartGlobalRect,
  }) {
    final List<ToolbarActionKey> nextActionKeys = List<ToolbarActionKey>.from(
      _appliedActionKeys,
    );

    if (dragData.source == _ToolbarActionSource.repository) {
      if (nextActionKeys.length >= maximumToolbarActionCount) {
        _showToolbarMessage('请先移除一个工具');
        return;
      }

      final int safeIndex = insertionIndex < 0
          ? 0
          : insertionIndex > nextActionKeys.length
          ? nextActionKeys.length
          : insertionIndex;
      nextActionKeys.insert(safeIndex, dragData.actionKey);
      _setAppliedActionKeys(
        nextActionKeys,
        landingActionKey: landingStartGlobalRect == null
            ? null
            : dragData.actionKey,
      );
      _animateActionToApplied(dragData.actionKey, landingStartGlobalRect);
      return;
    }

    final int previousIndex = nextActionKeys.indexOf(dragData.actionKey);
    if (previousIndex < 0) {
      return;
    }

    nextActionKeys.removeAt(previousIndex);
    int adjustedIndex = insertionIndex;
    if (previousIndex < insertionIndex) {
      adjustedIndex -= 1;
    }
    final int safeIndex = adjustedIndex < 0
        ? 0
        : adjustedIndex > nextActionKeys.length
        ? nextActionKeys.length
        : adjustedIndex;
    nextActionKeys.insert(safeIndex, dragData.actionKey);
    _setAppliedActionKeys(
      nextActionKeys,
      landingActionKey: landingStartGlobalRect == null
          ? null
          : dragData.actionKey,
    );
    _animateActionToApplied(dragData.actionKey, landingStartGlobalRect);
  }

  /*
   * 把拖动工具放到目标工具中部，并让被替换工具飞回仓库。
   */
  void _replaceDraggedAction(
    _ToolbarDragData dragData,
    ToolbarActionKey targetActionKey, {
    Rect? landingStartGlobalRect,
  }) {
    if (dragData.actionKey == targetActionKey) {
      return;
    }

    final Rect? replacedActionRect = _getGlobalRect(
      _getAppliedActionKey(targetActionKey),
    );
    final List<ToolbarActionKey> nextActionKeys = List<ToolbarActionKey>.from(
      _appliedActionKeys,
    );

    if (dragData.source == _ToolbarActionSource.applied) {
      nextActionKeys.remove(dragData.actionKey);
    }

    final int targetIndex = nextActionKeys.indexOf(targetActionKey);
    if (targetIndex < 0) {
      return;
    }

    nextActionKeys[targetIndex] = dragData.actionKey;
    _setAppliedActionKeys(
      nextActionKeys,
      landingActionKey: landingStartGlobalRect == null
          ? null
          : dragData.actionKey,
    );
    _animateActionToApplied(dragData.actionKey, landingStartGlobalRect);
    _animateActionToRepository(targetActionKey, replacedActionRect);
  }

  /*
   * 从上方工具栏移除指定工具并播放飞回仓库动画。
   */
  void _removeAppliedAction(ToolbarActionKey actionKey) {
    if (!_appliedActionKeys.contains(actionKey)) {
      return;
    }

    final Rect? actionRect = _getGlobalRect(_getAppliedActionKey(actionKey));
    final List<ToolbarActionKey> nextActionKeys = List<ToolbarActionKey>.from(
      _appliedActionKeys,
    )..remove(actionKey);
    _setAppliedActionKeys(nextActionKeys);
    _animateActionToRepository(actionKey, actionRect);
  }

  /*
   * 按指定仓库位置移除上栏工具，并保留用户放入仓库时选择的顺序。
   */
  void _placeAppliedActionInRepository(
    _ToolbarDragData dragData,
    int insertionIndex,
  ) {
    final List<ToolbarActionKey> repositoryActionKeys = _getRepositoryActions()
        .map((ToolbarActionItem action) => action.key)
        .toList(growable: false);
    final List<ToolbarActionKey> nextRepositoryOrder =
        List<ToolbarActionKey>.from(_repositoryActionOrder)
          ..remove(dragData.actionKey);

    if (repositoryActionKeys.isEmpty) {
      nextRepositoryOrder.add(dragData.actionKey);
    } else if (insertionIndex >= repositoryActionKeys.length) {
      final int lastActionIndex = nextRepositoryOrder.indexOf(
        repositoryActionKeys.last,
      );
      nextRepositoryOrder.insert(lastActionIndex + 1, dragData.actionKey);
    } else {
      final int targetActionIndex = nextRepositoryOrder.indexOf(
        repositoryActionKeys[insertionIndex],
      );
      nextRepositoryOrder.insert(targetActionIndex, dragData.actionKey);
    }

    _repositoryActionOrder = nextRepositoryOrder;
    _setRepositoryDropHover(null);
    _removeAppliedAction(dragData.actionKey);
  }

  /*
   * 处理已应用工具拖到下方仓库的移除操作。
   */
  void _handleRepositoryDrop(_ToolbarDragData dragData) {
    _setRepositoryDropHover(null);
    if (dragData.source == _ToolbarActionSource.applied) {
      _removeAppliedAction(dragData.actionKey);
    }
  }

  /*
   * 获取定位标识对应组件的全局矩形。
   */
  Rect? _getGlobalRect(GlobalKey actionKey) {
    final BuildContext? actionContext = actionKey.currentContext;
    final RenderObject? renderObject = actionContext?.findRenderObject();

    if (renderObject is! RenderBox || !renderObject.hasSize) {
      return null;
    }

    return renderObject.localToGlobal(Offset.zero) & renderObject.size;
  }

  /*
   * 把全局矩形转换为根浮层使用的局部矩形。
   */
  Rect _convertGlobalRectToOverlay(Rect globalRect, RenderBox overlayBox) {
    return Rect.fromPoints(
      overlayBox.globalToLocal(globalRect.topLeft),
      overlayBox.globalToLocal(globalRect.bottomRight),
    );
  }

  /*
   * 完成工具落位动画并显示上栏中的真实工具。
   */
  void _finishLandingAction(ToolbarActionKey actionKey) {
    if (!mounted || !_landingActionKeys.contains(actionKey)) {
      return;
    }

    setState(() {
      _landingActionKeys.remove(actionKey);
    });
  }

  /*
   * 让松手后的工具从拖动反馈位置平滑移动到上栏最终位置。
   */
  void _animateActionToApplied(
    ToolbarActionKey actionKey,
    Rect? startGlobalRect,
  ) {
    if (startGlobalRect == null) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      final Rect? endGlobalRect = _getGlobalRect(
        _getAppliedActionKey(actionKey),
      );
      final OverlayState? overlay = Overlay.maybeOf(context, rootOverlay: true);
      final RenderObject? overlayRenderObject = overlay?.context
          .findRenderObject();
      if (endGlobalRect == null ||
          overlay == null ||
          overlayRenderObject is! RenderBox) {
        _finishLandingAction(actionKey);
        return;
      }

      final Rect startRect = _convertGlobalRectToOverlay(
        startGlobalRect,
        overlayRenderObject,
      );
      final Rect endRect = _convertGlobalRectToOverlay(
        endGlobalRect,
        overlayRenderObject,
      );
      late final OverlayEntry landingEntry;
      landingEntry = OverlayEntry(
        builder: (BuildContext overlayContext) {
          return TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: 1),
            duration: _toolbarAnimationDuration,
            onEnd: () {
              _removeFlyingActionEntry(landingEntry);
              _finishLandingAction(actionKey);
            },
            builder: (BuildContext context, double value, Widget? child) {
              final Rect currentRect = Rect.lerp(
                startRect,
                endRect,
                Curves.easeInOutCubic.transform(value),
              )!;
              return Positioned.fromRect(rect: currentRect, child: child!);
            },
            child: _buildLandingAction(
              toolbarActionForKey(actionKey),
              Theme.of(overlayContext).colorScheme,
            ),
          );
        },
      );
      _flyingActionEntries.add(landingEntry);
      overlay.insert(landingEntry);
    });
  }

  /*
   * 在替换或移除后让工具从上栏平滑飞向仓库中的新位置。
   */
  void _animateActionToRepository(
    ToolbarActionKey actionKey,
    Rect? startGlobalRect,
  ) {
    if (startGlobalRect == null) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || !_isCustomizing) {
        return;
      }

      final BuildContext? repositoryActionContext = _getRepositoryActionKey(
        actionKey,
      ).currentContext;
      if (repositoryActionContext == null) {
        return;
      }

      // 靠后的仓库工具先滚入可见区域，飞回轨迹不会穿过仓库边界落到屏外。
      await Scrollable.ensureVisible(
        repositoryActionContext,
        alignment: 0.5,
        duration: _toolbarAnimationDuration,
        curve: Curves.easeOutCubic,
      );
      if (!mounted || !_isCustomizing) {
        return;
      }

      final Rect? endGlobalRect = _getGlobalRect(
        _getRepositoryActionKey(actionKey),
      );
      final OverlayState? overlay = Overlay.maybeOf(context, rootOverlay: true);
      final RenderObject? overlayRenderObject = overlay?.context
          .findRenderObject();

      if (endGlobalRect == null ||
          overlay == null ||
          overlayRenderObject is! RenderBox) {
        return;
      }

      final Rect startRect = _convertGlobalRectToOverlay(
        startGlobalRect,
        overlayRenderObject,
      );
      final Rect endRect = _convertGlobalRectToOverlay(
        endGlobalRect,
        overlayRenderObject,
      );
      late final OverlayEntry flyingEntry;
      flyingEntry = OverlayEntry(
        builder: (BuildContext overlayContext) {
          return TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: 1),
            duration: _toolbarAnimationDuration,
            onEnd: () {
              _removeFlyingActionEntry(flyingEntry);
            },
            builder: (BuildContext context, double value, Widget? child) {
              final double curvedValue = Curves.easeInOutCubic.transform(value);
              final Rect currentRect = Rect.lerp(
                startRect,
                endRect,
                curvedValue,
              )!;

              return Positioned.fromRect(
                rect: currentRect,
                child: Opacity(opacity: 1 - (value * 0.12), child: child),
              );
            },
            child: _buildFlyingAction(
              toolbarActionForKey(actionKey),
              Theme.of(overlayContext).colorScheme,
            ),
          );
        },
      );
      _flyingActionEntries.add(flyingEntry);
      overlay.insert(flyingEntry);
    });
  }

  /*
   * 移除已经播放完成的工具飞行动画浮层。
   */
  void _removeFlyingActionEntry(OverlayEntry entry) {
    entry.remove();
    _flyingActionEntries.remove(entry);
  }

  /*
   * 判断指定工具栏动作在当前选区是否处于启用状态。
   */
  bool _isActionActive(ToolbarActionKey actionKey) {
    final Map<String, Attribute> attributes = widget.controller
        .getSelectionStyle()
        .attributes;

    switch (actionKey) {
      case ToolbarActionKey.title:
        return attributes[Attribute.header.key] == Attribute.h1;
      case ToolbarActionKey.subtitle:
        return attributes[Attribute.header.key] == Attribute.h2;
      case ToolbarActionKey.heading3:
        return attributes[Attribute.header.key] == Attribute.h3;
      case ToolbarActionKey.heading4:
        return attributes[Attribute.header.key] == Attribute.h4;
      case ToolbarActionKey.heading5:
        return attributes[Attribute.header.key] == Attribute.h5;
      case ToolbarActionKey.heading6:
        return attributes[Attribute.header.key] == Attribute.h6;
      case ToolbarActionKey.bold:
        return attributes[Attribute.bold.key] == Attribute.bold;
      case ToolbarActionKey.italic:
        return attributes[Attribute.italic.key] == Attribute.italic;
      case ToolbarActionKey.strikeThrough:
        return attributes[Attribute.strikeThrough.key] ==
            Attribute.strikeThrough;
      case ToolbarActionKey.list:
        return attributes[Attribute.list.key] == Attribute.ul;
      case ToolbarActionKey.orderedList:
        return attributes[Attribute.list.key] == Attribute.ol;
      case ToolbarActionKey.checkList:
        return attributes[Attribute.list.key] == Attribute.checked ||
            attributes[Attribute.list.key] == Attribute.unchecked;
      case ToolbarActionKey.blockQuote:
        return attributes[Attribute.blockQuote.key] == Attribute.blockQuote;
      case ToolbarActionKey.codeBlock:
        return attributes[Attribute.codeBlock.key] == Attribute.codeBlock;
      case ToolbarActionKey.inlineCode:
        return attributes[Attribute.inlineCode.key] == Attribute.inlineCode;
      case ToolbarActionKey.insertTable:
      case ToolbarActionKey.undo:
      case ToolbarActionKey.redo:
        return false;
    }
  }

  /*
   * 判断命令工具当前是否可以执行。
   */
  bool _isActionEnabled(ToolbarActionKey actionKey) {
    if (widget.controller.readOnly) {
      return false;
    }

    switch (actionKey) {
      case ToolbarActionKey.undo:
        return widget.controller.hasUndo;
      case ToolbarActionKey.redo:
        return widget.controller.hasRedo;
      case ToolbarActionKey.title:
      case ToolbarActionKey.subtitle:
      case ToolbarActionKey.heading3:
      case ToolbarActionKey.heading4:
      case ToolbarActionKey.heading5:
      case ToolbarActionKey.heading6:
      case ToolbarActionKey.bold:
      case ToolbarActionKey.italic:
      case ToolbarActionKey.strikeThrough:
      case ToolbarActionKey.list:
      case ToolbarActionKey.orderedList:
      case ToolbarActionKey.checkList:
      case ToolbarActionKey.blockQuote:
      case ToolbarActionKey.codeBlock:
      case ToolbarActionKey.inlineCode:
      case ToolbarActionKey.insertTable:
        return true;
    }
  }

  /*
   * 执行普通工具点击并拦截只读或不可用命令。
   */
  void _handleActionPressed(ToolbarActionKey actionKey) {
    if (_isCustomizing) {
      _leaveCustomizationMode();
      return;
    }

    if (!_isActionEnabled(actionKey)) {
      return;
    }

    widget.onPressedAction(actionKey);
  }

  /*
   * 构建单个工具栏动作图标。
   */
  Widget _buildActionIcon(
    ToolbarActionItem action, {
    required Color color,
    double size = 21,
  }) {
    if (action.icon != null) {
      return Icon(
        action.icon,
        // 工具栏动作图标颜色样式
        color: color,
        size: size,
      );
    }

    return Text(
      action.symbol ?? '',
      // 工具栏标题级别图标文字样式
      style: TextStyle(
        color: color,
        fontSize: size - 6,
        fontWeight: FontWeight.w700,
        letterSpacing: 0,
      ),
    );
  }

  /*
   * 构建用于跟随手指移动的工具预览。
   */
  Widget _buildDragFeedback(ToolbarActionItem action, ColorScheme colors) {
    final Size appliedActionSize = _getAppliedActionSize();
    return Material(
      key: ValueKey<String>('toolbar-drag-feedback-${action.key.name}'),
      // 拖动预览背景样式
      color: colors.primaryContainer,
      elevation: 8,
      shadowColor: colors.shadow.withValues(alpha: 0.28),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      child: SizedBox(
        // 拖动预览尺寸样式，与工具放入上栏后的实际尺寸保持一致。
        width: appliedActionSize.width,
        height: appliedActionSize.height,
        child: Center(
          child: _buildActionIcon(action, color: colors.onPrimaryContainer),
        ),
      ),
    );
  }

  /*
   * 构建替换后飞回仓库的静态工具外观。
   */
  Widget _buildFlyingAction(ToolbarActionItem action, ColorScheme colors) {
    return Material(
      // 飞回工具背景样式
      color: colors.surfaceContainerHigh,
      elevation: 6,
      shadowColor: colors.shadow.withValues(alpha: 0.22),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      child: Center(
        child: _buildActionIcon(action, color: colors.onSurface, size: 21),
      ),
    );
  }

  /*
   * 构建从松手位置移动到上栏最终位置的工具外观。
   */
  Widget _buildLandingAction(ToolbarActionItem action, ColorScheme colors) {
    return Material(
      key: ValueKey<String>('toolbar-landing-feedback-${action.key.name}'),
      // 工具落位动画背景样式，与拖动反馈保持一致。
      color: colors.primaryContainer,
      elevation: 8,
      shadowColor: colors.shadow.withValues(alpha: 0.28),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      child: Center(
        child: _buildActionIcon(action, color: colors.onPrimaryContainer),
      ),
    );
  }

  /*
   * 构建上方已应用工具的按钮表面。
   */
  Widget _buildAppliedActionSurface(
    ToolbarActionItem action,
    ColorScheme colors,
  ) {
    final bool isActive = _isActionActive(action.key);
    final bool isEnabled = _isActionEnabled(action.key);
    final Color foregroundColor = !isEnabled
        ? colors.onSurface.withValues(alpha: 0.38)
        : isActive
        ? colors.onPrimary
        : colors.onSurface;

    return Tooltip(
      message: action.label,
      triggerMode: TooltipTriggerMode.manual,
      child: Material(
        key: ValueKey<String>('toolbar-active-${action.key.name}'),
        // 已应用工具按钮背景样式
        color: isActive ? colors.primary : colors.surfaceContainerHigh,
        shape: RoundedRectangleBorder(
          side: BorderSide(
            // 已应用工具按钮边框样式
            color: isActive ? colors.primary : colors.outline,
          ),
          borderRadius: BorderRadius.circular(6),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: isEnabled ? () => _handleActionPressed(action.key) : null,
          child: SizedBox(
            // 已应用工具按钮固定高度样式，宽度由外层 Expanded 弹性分配。
            width: double.infinity,
            height: _toolbarButtonHeight,
            child: Center(
              child: _buildActionIcon(action, color: foregroundColor),
            ),
          ),
        ),
      ),
    );
  }

  /*
   * 构建自定义状态下工具右上角的移除按钮。
   */
  Widget _buildRemoveActionButton(
    ToolbarActionKey actionKey,
    ColorScheme colors,
  ) {
    return Positioned(
      top: -5,
      right: -5,
      child: Tooltip(
        message: '移除${toolbarActionForKey(actionKey).label}',
        child: Material(
          // 工具移除按钮背景样式
          color: colors.error,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: () => _removeAppliedAction(actionKey),
            child: SizedBox(
              width: 18,
              height: 18,
              child: Icon(
                Icons.remove_rounded,
                // 工具移除按钮图标样式
                color: colors.onError,
                size: 14,
              ),
            ),
          ),
        ),
      ),
    );
  }

  /*
   * 构建符合当前模式的工具拖动入口。
   *
   * 普通状态需要长按进入自定义模式；进入后上栏与仓库工具都可以直接拖动。
   */
  Widget _buildActionDraggable({
    required _ToolbarDragData dragData,
    required ToolbarActionItem action,
    required ColorScheme colors,
    required Widget child,
  }) {
    final Widget longPressDraggable = LongPressDraggable<_ToolbarDragData>(
      data: dragData,
      dragAnchorStrategy: _centeredDragAnchorStrategy,
      hapticFeedbackOnStart: true,
      delay: kLongPressTimeout,
      maxSimultaneousDrags: widget.controller.readOnly ? 0 : 1,
      onDragStarted: _enterCustomizationMode,
      onDragEnd: (DraggableDetails details) {
        _finishActionDrag(action.key);
      },
      feedback: _buildDragFeedback(action, colors),
      childWhenDragging: Opacity(
        key: ValueKey<String>(
          'toolbar-drag-origin-${dragData.source.name}-${action.key.name}',
        ),
        // 拖动源占位透明度样式，保留布局但不在原地显示残影。
        opacity: 0,
        child: child,
      ),
      child: child,
    );

    return Draggable<_ToolbarDragData>(
      data: dragData,
      dragAnchorStrategy: _centeredDragAnchorStrategy,
      maxSimultaneousDrags: _isCustomizing && !widget.controller.readOnly
          ? 1
          : 0,
      onDragEnd: (DraggableDetails details) {
        _finishActionDrag(action.key);
      },
      feedback: _buildDragFeedback(action, colors),
      childWhenDragging: Opacity(
        key: ValueKey<String>(
          'toolbar-drag-origin-${dragData.source.name}-${action.key.name}',
        ),
        // 拖动源占位透明度样式，保留布局但不在原地显示残影。
        opacity: 0,
        child: child,
      ),
      child: longPressDraggable,
    );
  }

  /*
   * 构建带抖动、拖动和移除能力的已应用工具。
   */
  Widget _buildAppliedAction(
    ToolbarActionKey actionKey,
    int index,
    ColorScheme colors,
  ) {
    final ToolbarActionItem action = toolbarActionForKey(actionKey);
    final Widget actionSurface = Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        _buildAppliedActionSurface(action, colors),
        if (_isCustomizing) _buildRemoveActionButton(actionKey, colors),
      ],
    );
    final Widget shakingAction = AnimatedBuilder(
      animation: _shakeController,
      child: actionSurface,
      builder: (BuildContext context, Widget? child) {
        final double direction = index.isEven ? 1 : -1;
        final double angle = _isCustomizing
            ? ((_shakeController.value * 2) - 1) * 0.025 * direction
            : 0;
        return Transform.rotate(angle: angle, child: child);
      },
    );
    final Widget landingAwareAction = Opacity(
      key: ValueKey<String>('toolbar-landing-destination-${actionKey.name}'),
      // 工具落位期间目标位置透明度样式，避免与移动浮层重叠闪烁。
      opacity: _landingActionKeys.contains(actionKey) ? 0 : 1,
      child: shakingAction,
    );

    return KeyedSubtree(
      key: _getAppliedActionKey(actionKey),
      child: _buildActionDraggable(
        dragData: _ToolbarDragData(
          actionKey: actionKey,
          source: _ToolbarActionSource.applied,
        ),
        action: action,
        colors: colors,
        child: landingAwareAction,
      ),
    );
  }

  /*
   * 构建工具中部替换目标。
   */
  Widget _buildReplacementTarget(
    ToolbarActionKey actionKey,
    int index,
    ColorScheme colors,
  ) {
    return DragTarget<_ToolbarDragData>(
      onWillAcceptWithDetails: (DragTargetDetails<_ToolbarDragData> details) {
        return _isCustomizing && details.data.actionKey != actionKey;
      },
      onMove: (DragTargetDetails<_ToolbarDragData> details) {
        if (!_isCustomizing || details.data.actionKey == actionKey) {
          return;
        }
        final int? insertionIndex = _getToolbarInsertionIndexForPosition(
          actionKey,
          index,
          _getDragFeedbackCenter(details.offset),
        );
        if (insertionIndex == null) {
          return;
        }
        _setToolbarDropHover(
          dragData: details.data,
          insertionIndex: insertionIndex,
        );
      },
      onLeave: (_ToolbarDragData? dragData) {
        _clearToolbarDropHover();
      },
      onAcceptWithDetails: (DragTargetDetails<_ToolbarDragData> details) {
        final int? insertionIndex = _getToolbarInsertionIndexForPosition(
          actionKey,
          index,
          _getDragFeedbackCenter(details.offset),
        );
        _clearToolbarDropHover();
        if (insertionIndex == null) {
          _replaceDraggedAction(
            details.data,
            actionKey,
            landingStartGlobalRect: _getDragFeedbackGlobalRect(details.offset),
          );
          return;
        }
        _insertDraggedAction(
          details.data,
          insertionIndex,
          landingStartGlobalRect: _getDragFeedbackGlobalRect(details.offset),
        );
      },
      builder:
          (
            BuildContext context,
            List<_ToolbarDragData?> candidateData,
            List<dynamic> rejectedData,
          ) {
            final bool isHovered = candidateData.isNotEmpty;
            return AnimatedContainer(
              key: ValueKey<String>('toolbar-replacement-${actionKey.name}'),
              duration: _toolbarAnimationDuration,
              // 工具中部替换目标装饰样式
              decoration: BoxDecoration(
                border: Border.all(
                  color: isHovered ? colors.primary : Colors.transparent,
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(7),
              ),
              padding: const EdgeInsets.all(2),
              child: _buildAppliedAction(actionKey, index, colors),
            );
          },
    );
  }

  /*
   * 判断当前插槽悬停工具是否因为七项上限而不能插入。
   */
  bool _isInsertionAtCapacity(_ToolbarDragData? dragData) {
    return dragData?.source == _ToolbarActionSource.repository &&
        _appliedActionKeys.length >= maximumToolbarActionCount;
  }

  /*
   * 判断拖动工具是否可以进入指定上栏插槽。
   */
  bool _canInsertDraggedActionAt(
    _ToolbarDragData dragData,
    int insertionIndex,
  ) {
    if (!_isCustomizing) {
      return false;
    }

    if (dragData.source == _ToolbarActionSource.applied) {
      final int sourceIndex = _appliedActionKeys.indexOf(dragData.actionKey);
      if (sourceIndex == insertionIndex || sourceIndex + 1 == insertionIndex) {
        return false;
      }
    }

    return true;
  }

  /*
   * 构建两个已应用工具之间的插入目标。
   */
  Widget _buildInsertionTarget(
    int insertionIndex,
    ColorScheme colors, {
    bool fillsRemainingSpace = false,
  }) {
    return DragTarget<_ToolbarDragData>(
      key: ValueKey<String>('toolbar-gap-$insertionIndex'),
      onWillAcceptWithDetails: (DragTargetDetails<_ToolbarDragData> details) {
        return _canInsertDraggedActionAt(details.data, insertionIndex);
      },
      onMove: (DragTargetDetails<_ToolbarDragData> details) {
        if (!_canInsertDraggedActionAt(details.data, insertionIndex)) {
          return;
        }
        _setToolbarDropHover(
          dragData: details.data,
          insertionIndex: insertionIndex,
        );
      },
      onLeave: (_ToolbarDragData? dragData) {
        if (_hoveredToolbarInsertionIndex == insertionIndex) {
          _clearToolbarDropHover();
        }
      },
      onAcceptWithDetails: (DragTargetDetails<_ToolbarDragData> details) {
        _clearToolbarDropHover();
        _insertDraggedAction(
          details.data,
          insertionIndex,
          landingStartGlobalRect: _getDragFeedbackGlobalRect(details.offset),
        );
      },
      builder:
          (
            BuildContext context,
            List<_ToolbarDragData?> candidateData,
            List<dynamic> rejectedData,
          ) {
            final bool isHovered =
                _hoveredToolbarInsertionIndex == insertionIndex &&
                _hoveredToolbarDragData != null;
            final _ToolbarDragData? hoveredDragData = isHovered
                ? _hoveredToolbarDragData
                : candidateData.isNotEmpty
                ? candidateData.first
                : null;
            final bool isAtCapacity = _isInsertionAtCapacity(hoveredDragData);
            final bool isOnlyTarget = _appliedActionKeys.isEmpty;
            final Widget insertionIndicator = AnimatedContainer(
              key: ValueKey<String>('toolbar-gap-indicator-$insertionIndex'),
              duration: _toolbarAnimationDuration,
              width: isOnlyTarget
                  ? 42
                  : isHovered && !isAtCapacity
                  ? 28
                  : isHovered
                  ? 14
                  : 10,
              height: _toolbarButtonHeight,
              // 工具插槽装饰样式，悬停时只展开空间，不显示黄色占位框。
              decoration: BoxDecoration(
                color: isHovered && isAtCapacity
                    ? colors.errorContainer
                    : Colors.transparent,
                border: Border.all(
                  color: isOnlyTarget
                      ? colors.outline
                      : isHovered && isAtCapacity
                      ? colors.error
                      : Colors.transparent,
                ),
                borderRadius: BorderRadius.circular(6),
              ),
              child: isOnlyTarget
                  ? Icon(
                      Icons.add_rounded,
                      // 空工具栏插槽图标样式
                      color: isHovered
                          ? colors.primary
                          : colors.onSurfaceVariant,
                      size: 20,
                    )
                  : null,
            );
            if (!fillsRemainingSpace) {
              return insertionIndicator;
            }

            return Align(
              // 剩余空间插入提示靠左布局样式，整块空白区域都可接收拖动。
              alignment: Alignment.centerLeft,
              child: insertionIndicator,
            );
          },
    );
  }

  /*
   * 构建空工具栏重新打开自定义仓库的入口。
   */
  Widget _buildEmptyToolbarButton(ColorScheme colors) {
    return KeyedSubtree(
      key: _emptyToolbarActionKey,
      child: Tooltip(
        message: '自定义工具栏',
        child: IconButton(
          key: const ValueKey<String>('toolbar-empty-customize'),
          onPressed: _enterCustomizationMode,
          icon: const Icon(Icons.add_circle_outline_rounded),
          // 空工具栏入口图标颜色样式
          color: colors.onSurfaceVariant,
        ),
      ),
    );
  }

  /*
   * 构建上方已应用工具栏的弹性横向布局。
   */
  Widget _buildAppliedToolbar(ColorScheme colors) {
    if (_appliedActionKeys.isEmpty && !_isCustomizing) {
      return Row(
        // 空工具栏入口横向布局样式
        children: <Widget>[
          SizedBox(width: 48, child: _buildEmptyToolbarButton(colors)),
          const Expanded(child: SizedBox.shrink()),
        ],
      );
    }

    final int emptySlotCount =
        maximumToolbarActionCount - _appliedActionKeys.length;
    final List<Widget> children = <Widget>[];
    for (int index = 0; index <= _appliedActionKeys.length; index++) {
      final bool fillsTrailingSpace =
          index == _appliedActionKeys.length && emptySlotCount > 0;
      if (_isCustomizing) {
        final Widget insertionTarget = _buildInsertionTarget(
          index,
          colors,
          fillsRemainingSpace: fillsTrailingSpace,
        );
        children.add(
          fillsTrailingSpace
              ? Expanded(flex: emptySlotCount, child: insertionTarget)
              : insertionTarget,
        );
      } else {
        if (fillsTrailingSpace) {
          children.add(
            Expanded(
              flex: emptySlotCount,
              child: Align(
                // 普通状态末尾插槽靠左布局样式，与自定义状态保持一致。
                alignment: Alignment.centerLeft,
                child: const SizedBox(width: 10, height: _toolbarButtonHeight),
              ),
            ),
          );
        } else {
          // 普通状态预留与自定义状态一致的插槽宽度，长按成立时图标不会横向跳动。
          children.add(const SizedBox(width: 10));
        }
      }

      if (index < _appliedActionKeys.length) {
        children.add(
          Expanded(
            child: _buildReplacementTarget(
              _appliedActionKeys[index],
              index,
              colors,
            ),
          ),
        );
      }
    }

    return Row(
      // 已应用工具使用七份弹性宽度，较少工具时保留右侧空位避免按钮被拉宽。
      children: children,
    );
  }

  /*
   * 获取当前尚未应用的仓库工具。
   */
  List<ToolbarActionItem> _getRepositoryActions() {
    return _repositoryActionOrder
        .where(
          (ToolbarActionKey actionKey) =>
              !_appliedActionKeys.contains(actionKey),
        )
        .map(toolbarActionForKey)
        .toList(growable: false);
  }

  /*
   * 构建仓库中的单个可拖动工具。
   */
  Widget _buildRepositoryAction(ToolbarActionItem action, ColorScheme colors) {
    final Size appliedActionSize = _getAppliedActionSize();
    final bool isPressed = _pressedRepositoryActionKey == action.key;
    final Widget actionTile = SizedBox(
      height: 42,
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          return Listener(
            onPointerDown: (PointerDownEvent event) {
              _startPressingRepositoryAction(action.key);
            },
            onPointerUp: (PointerUpEvent event) {
              _finishPressingRepositoryAction(action.key);
            },
            onPointerCancel: (PointerCancelEvent event) {
              _finishPressingRepositoryAction(action.key);
            },
            child: Center(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 80),
                curve: Curves.easeOutCubic,
                // 仓库工具按压尺寸样式，以固定槽位中心收缩到上栏工具尺寸。
                width: isPressed
                    ? appliedActionSize.width
                    : constraints.maxWidth,
                height: isPressed ? appliedActionSize.height : 42,
                child: Tooltip(
                  message: action.label,
                  triggerMode: TooltipTriggerMode.manual,
                  child: Material(
                    key: ValueKey<String>(
                      'toolbar-repository-${action.key.name}',
                    ),
                    // 仓库工具背景样式，与上方工具按钮保持一致并略微增大。
                    color: colors.surfaceContainerHigh,
                    shape: RoundedRectangleBorder(
                      side: BorderSide(color: colors.outline),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Center(
                      child: _buildActionIcon(
                        action,
                        color: colors.onSurface,
                        size: 21,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );

    return KeyedSubtree(
      key: _getRepositoryActionKey(action.key),
      child: _buildActionDraggable(
        dragData: _ToolbarDragData(
          actionKey: action.key,
          source: _ToolbarActionSource.repository,
        ),
        action: action,
        colors: colors,
        child: actionTile,
      ),
    );
  }

  /*
   * 构建仓库工具的放入目标，并按左右半区选择插入位置。
   */
  Widget _buildRepositoryDropZone(
    ToolbarActionItem action,
    int actionIndex,
    ColorScheme colors,
  ) {
    return DragTarget<_ToolbarDragData>(
      onWillAcceptWithDetails: (DragTargetDetails<_ToolbarDragData> details) {
        return details.data.source == _ToolbarActionSource.applied;
      },
      onMove: (DragTargetDetails<_ToolbarDragData> details) {
        _setRepositoryDropHover(
          _getRepositoryInsertionIndexForPosition(
            action.key,
            actionIndex,
            _getDragFeedbackCenter(details.offset),
          ),
        );
      },
      onLeave: (_ToolbarDragData? dragData) {
        if (_hoveredRepositoryInsertionIndex == actionIndex ||
            _hoveredRepositoryInsertionIndex == actionIndex + 1) {
          _setRepositoryDropHover(null);
        }
      },
      onAcceptWithDetails: (DragTargetDetails<_ToolbarDragData> details) {
        _placeAppliedActionInRepository(
          details.data,
          _getRepositoryInsertionIndexForPosition(
            action.key,
            actionIndex,
            _getDragFeedbackCenter(details.offset),
          ),
        );
      },
      builder:
          (
            BuildContext context,
            List<_ToolbarDragData?> candidateData,
            List<dynamic> rejectedData,
          ) {
            return _buildRepositoryAction(action, colors);
          },
    );
  }

  /*
   * 计算仓库工具让出插入位置时的横向位移，保持工具自身尺寸不变。
   */
  Offset _getRepositoryActionSlideOffset(int actionIndex, int columnCount) {
    final int? insertionIndex = _hoveredRepositoryInsertionIndex;
    if (insertionIndex == null) {
      return Offset.zero;
    }

    final int rowStartIndex = (actionIndex ~/ columnCount) * columnCount;
    final int rowEndIndex = rowStartIndex + columnCount;
    if (insertionIndex < rowStartIndex || insertionIndex > rowEndIndex) {
      return Offset.zero;
    }

    return actionIndex < insertionIndex
        ? const Offset(-0.08, 0)
        : const Offset(0.08, 0);
  }

  /*
   * 按指定列数把仓库工具拆成多行弹性布局。
   */
  Widget _buildRepositoryRows(
    List<ToolbarActionItem> actions,
    int columnCount,
    ColorScheme colors,
  ) {
    final List<Widget> rows = <Widget>[];

    for (
      int startIndex = 0;
      startIndex < actions.length;
      startIndex += columnCount
    ) {
      final List<Widget> rowChildren = <Widget>[];
      for (int columnIndex = 0; columnIndex < columnCount; columnIndex++) {
        final int actionIndex = startIndex + columnIndex;
        rowChildren.add(
          Expanded(
            child: Padding(
              // 仓库工具之间的弹性间距样式
              padding: const EdgeInsets.all(3),
              child: actionIndex < actions.length
                  ? AnimatedSlide(
                      // 仓库插入让位样式，仅横向移动且不改变工具尺寸。
                      offset: _getRepositoryActionSlideOffset(
                        actionIndex,
                        columnCount,
                      ),
                      duration: _toolbarAnimationDuration,
                      curve: Curves.easeOutCubic,
                      child: _buildRepositoryDropZone(
                        actions[actionIndex],
                        actionIndex,
                        colors,
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ),
        );
      }
      rows.add(
        Row(
          // 单行仓库工具等宽弹性布局样式
          children: rowChildren,
        ),
      );
    }

    return Column(
      // 仓库工具多行纵向布局样式
      children: rows,
    );
  }

  /*
   * 构建下方全部工具仓库内容。
   */
  Widget _buildRepositoryContent(ColorScheme colors) {
    final List<ToolbarActionItem> repositoryActions = _getRepositoryActions();

    return Column(
      // 工具仓库分割线与工具列表纵向布局样式
      children: <Widget>[
        Divider(height: 1, thickness: 1, color: colors.outlineVariant),
        Expanded(
          child: repositoryActions.isEmpty
              ? const SizedBox.expand()
              : LayoutBuilder(
                  builder: (BuildContext context, BoxConstraints constraints) {
                    final int columnCount = constraints.maxWidth >= 300 ? 5 : 4;
                    return SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: _buildRepositoryRows(
                        repositoryActions,
                        columnCount,
                        colors,
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  /*
   * 构建可接收已应用工具的下方仓库面板。
   */
  Widget _buildRepositoryPanel(ColorScheme colors) {
    return DragTarget<_ToolbarDragData>(
      key: const ValueKey<String>('toolbar-repository'),
      onWillAcceptWithDetails: (DragTargetDetails<_ToolbarDragData> details) {
        return details.data.source == _ToolbarActionSource.applied;
      },
      onLeave: (_ToolbarDragData? dragData) {
        _setRepositoryDropHover(null);
      },
      onAcceptWithDetails: (DragTargetDetails<_ToolbarDragData> details) {
        _handleRepositoryDrop(details.data);
      },
      builder:
          (
            BuildContext context,
            List<_ToolbarDragData?> candidateData,
            List<dynamic> rejectedData,
          ) {
            return SizedBox.expand(
              // 工具仓库面板固定尺寸样式，接收上栏工具时不发生缩放。
              child: DecoratedBox(
                key: const ValueKey<String>('toolbar-repository-surface'),
                // 工具仓库面板固定背景样式，接收上栏工具时不显示边框。
                decoration: BoxDecoration(color: colors.surfaceContainerLow),
                child: Padding(
                  // 工具仓库内容边距样式
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                  child: _buildRepositoryContent(colors),
                ),
              ),
            );
          },
    );
  }

  /*
   * 根据工具栏全局位置计算仓库浮层可以使用的剩余高度。
   */
  double _calculateRepositoryOverlayHeight() {
    final Rect? toolbarContentRect = _getGlobalRect(
      _appliedActionKeys.isEmpty
          ? _emptyToolbarActionKey
          : _getAppliedActionKey(_appliedActionKeys.first),
    );
    if (toolbarContentRect == null) {
      return _repositoryOverlayHeight;
    }

    final MediaQueryData mediaQuery = MediaQuery.of(context);
    final double availableHeight =
        mediaQuery.size.height -
        toolbarContentRect.bottom -
        10 -
        mediaQuery.padding.bottom -
        mediaQuery.viewInsets.bottom;
    return availableHeight < 0 ? 0 : availableHeight;
  }

  /*
   * 在本帧布局完成后同步仓库浮层高度，适配键盘和窗口尺寸变化。
   */
  void _scheduleRepositoryOverlayHeightUpdate() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_isCustomizing) {
        return;
      }

      final double nextHeight = _calculateRepositoryOverlayHeight();
      if ((nextHeight - _repositoryOverlayHeight).abs() < 0.5) {
        return;
      }

      setState(() {
        _repositoryOverlayHeight = nextHeight;
      });
    });
  }

  /*
   * 构建从上方工具栏底部延伸到页面底部的仓库独立浮层。
   */
  Widget _buildRepositoryOverlay(ColorScheme colors, double toolbarWidth) {
    return CompositedTransformFollower(
      link: _repositoryLayerLink,
      showWhenUnlinked: false,
      targetAnchor: Alignment.bottomLeft,
      followerAnchor: Alignment.topLeft,
      child: Align(
        // 仓库浮层在 Overlay 的全屏约束内保持工具栏宽度和剩余区域高度。
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: toolbarWidth,
          height: _repositoryOverlayHeight,
          child: ClipRect(child: _buildRepositoryPanel(colors)),
        ),
      ),
    );
  }

  /*
   * 构建工具栏组件。
   *
   * build 返回的 Widget 树就是工具栏最终显示的结构。
   */
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (BuildContext context, Widget? child) {
        final ColorScheme colors = Theme.of(context).colorScheme;
        if (_isCustomizing) {
          _scheduleRepositoryOverlayHeightUpdate();
        }

        return LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            return OverlayPortal(
              controller: _repositoryOverlayController,
              overlayChildBuilder: (BuildContext overlayContext) {
                return _buildRepositoryOverlay(colors, constraints.maxWidth);
              },
              child: CompositedTransformTarget(
                link: _repositoryLayerLink,
                child: Container(
                  // 工具栏容器装饰样式
                  decoration: BoxDecoration(
                    // 工具栏与编辑主体使用相同背景色，视觉上保持连续。
                    color: colors.surfaceContainerLow,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 0,
                    vertical: 8,
                  ),
                  child: SizedBox(
                    height: 44,
                    child: _buildAppliedToolbar(colors),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
