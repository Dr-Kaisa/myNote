/*
 * 文件说明：笔记主页组件文件，负责组织笔记首页、文件夹视图、选择模式、移动面板与编辑区交互。
 *
 * 这个文件是应用里最主要的页面文件。
 * 不熟 Flutter 时可以先按这个顺序理解：
 * 1. 上半部分是数据结构和状态字段，例如当前有哪些笔记、当前进了哪个文件夹。
 * 2. 中间部分是事件处理方法，例如点击文件夹、创建笔记、删除笔记。
 * 3. 下半部分是 _build 开头的方法，它们负责把状态渲染成界面。
 *
 * Flutter 里的 Widget 可以理解成界面积木。
 * Row 是横向排列，Column 是纵向排列，Container 是带样式的盒子，
 * Padding 是外边距，Expanded 是把剩余空间分给某个子组件。
 */
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:my_note/models/note_item.dart';
import 'package:my_note/services/app_cache_service.dart';
import 'package:my_note/services/note_storage_service.dart';
import 'package:my_note/utils/markdown_helper.dart';
import 'package:my_note/widgets/markdown_toolbar.dart';

/*
 * 首页分类项数据模型。
 *
 * 分类栏就是页面上方那排胶囊按钮。
 * 一个 NoteCategoryItem 代表其中一个按钮，比如“全部笔记”或某个常访问文件夹。
 */
class NoteCategoryItem {
  /*
   * 构造首页分类项。
   */
  const NoteCategoryItem({
    required this.id,
    required this.label,
    required this.isAllNotes,
  });

  /*
   * 分类唯一标识。
   *
   * “全部笔记”的 id 是 all；文件夹分类的 id 是文件夹相对路径。
   */
  final String id;

  /*
   * 分类显示文案。
   *
   * 这是按钮上用户能看到的文字。
   */
  final String label;

  /*
   * 是否为“全部笔记”分类。
   *
   * 这个字段用来区分根分类和文件夹分类，因为它们的选中判断不一样。
   */
  final bool isAllNotes;
}

/*
 * 首页网格项类型。
 *
 * 首页下面的瀑布流里有两种卡片：文件夹卡片和笔记卡片。
 */
enum NoteGridItemType { folder, note }

/*
 * 首页排序方式。
 *
 * 右上角更多菜单会切换这个值，首页文件夹和笔记都根据它重新排序。
 */
enum NoteSortMode { name, createdAt, updatedAt }

/*
 * 首页视图模式。
 *
 * 宫格模式用于卡片瀑布流；列表模式用于更紧凑地浏览笔记和文件夹。
 */
enum NoteViewMode { grid, list }

/*
 * 首页网格项数据模型。
 *
 * NoteGridItem 是给首页瀑布流用的数据。
 * 它把文件夹和笔记统一成一种结构，方便 _buildBrowserPanel 统一排列。
 */
class NoteGridItem {
  /*
   * 构造首页网格项。
   */
  const NoteGridItem({
    required this.id,
    required this.type,
    required this.title,
    required this.subtitle,
    required this.locationText,
    this.note,
    this.noteCount = 0,
  });

  /*
   * 网格项唯一标识。
   *
   * 文件夹一般是 folder:路径，笔记一般是 note:路径，用前缀区分类型。
   */
  final String id;

  /*
   * 网格项类型。
   *
   * type 决定最终调用 _buildFolderCard 还是 _buildNoteCard。
   */
  final NoteGridItemType type;

  /*
   * 网格项主标题。
   *
   * 文件夹时是文件夹名；笔记时是笔记标题。
   */
  final String title;

  /*
   * 网格项辅助内容。
   *
   * 文件夹时通常是数量；笔记时通常是摘要。
   */
  final String subtitle;

  /*
   * 网格项相对位置信息。
   *
   * 文件夹时是文件夹路径；笔记时是显示路径。
   */
  final String locationText;

  /*
   * 关联的笔记对象。
   *
   * 只有笔记卡片会有 note；文件夹卡片这里是 null。
   */
  final NoteItem? note;

  /*
   * 文件夹下的笔记数量。
   *
   * 只有文件夹卡片会用它显示数量。
   */
  final int noteCount;
}

/*
 * 笔记主页组件。
 */
class NoteHomePage extends StatefulWidget {
  /*
   * 笔记主页构造方法。
   */
  const NoteHomePage({super.key});

  /*
   * 创建笔记主页状态对象。
   */
  @override
  State<NoteHomePage> createState() => _NoteHomePageState();
}

/*
 * 笔记设置页面。
 *
 * 当前先提供设置页入口和基础页面结构，后续具体设置项可以继续放在这里。
 */
class NoteSettingsPage extends StatelessWidget {
  /*
   * 笔记设置页面构造方法。
   */
  const NoteSettingsPage({super.key});

  /*
   * 构建设置页标题栏。
   */
  Widget _buildHeader(BuildContext context) {
    return Padding(
      // 设置页标题栏外边距样式
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
      child: Row(
        // 设置页标题栏横向布局样式
        children: <Widget>[
          IconButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            icon: const Icon(Icons.arrow_back_rounded),
            color: const Color(0xFF111111),
          ),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              '设置',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              // 设置页标题文字样式
              style: TextStyle(
                color: Color(0xFF111111),
                fontSize: 28,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /*
   * 构建设置页空状态内容。
   */
  Widget _buildEmptyContent() {
    return Expanded(
      child: Center(
        child: Padding(
          // 设置页空状态外边距样式
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            // 设置页空状态纵向布局样式
            mainAxisSize: MainAxisSize.min,
            children: const <Widget>[
              Icon(
                Icons.settings_rounded,
                // 设置页空状态图标样式
                color: Color(0xFFFFC000),
                size: 58,
              ),
              SizedBox(height: 14),
              Text(
                '设置',
                textAlign: TextAlign.center,
                // 设置页空状态标题样式
                style: TextStyle(
                  color: Color(0xFF222222),
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 8),
              Text(
                '后续设置项会放在这里',
                textAlign: TextAlign.center,
                // 设置页空状态说明样式
                style: TextStyle(
                  color: Color(0xFF777777),
                  fontSize: 15,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /*
   * 构建设置页面。
   */
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 设置页背景色样式
      backgroundColor: const Color(0xFFF0F1F3),
      body: SafeArea(
        child: Column(
          // 设置页根内容纵向布局样式
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[_buildHeader(context), _buildEmptyContent()],
        ),
      ),
    );
  }
}

/*
 * 笔记主页状态对象。
 */
class _NoteHomePageState extends State<NoteHomePage> {
  /*
   * 按压、拖拽和命中目标时统一使用的卡片缩放比例。
   */
  static const double _dragCardScale = 0.90;

  /*
   * 笔记存储服务实例。
   */
  final NoteStorageService _noteStorageService = NoteStorageService();

  /*
   * 应用缓存服务实例。
   */
  final AppCacheService _appCacheService = AppCacheService();

  /*
   * 编辑器控制器。
   */
  final TextEditingController _editorController = TextEditingController();

  /*
   * 编辑器焦点控制器。
   */
  final FocusNode _editorFocusNode = FocusNode();

  /*
   * 更多菜单按钮定位标识。
   */
  final GlobalKey _moreMenuButtonKey = GlobalKey();

  /*
   * 首页面板定位标识。
   */
  final GlobalKey _homePanelKey = GlobalKey();

  /*
   * 浏览项定位标识集合。
   */
  final Map<String, GlobalKey> _browserItemKeys = <String, GlobalKey>{};

  /*
   * 当前更多菜单浮层。
   */
  OverlayEntry? _moreMenuOverlayEntry;

  /*
   * 更多菜单是否正在执行关闭动画。
   */
  bool _isMoreMenuClosing = false;

  /*
   * 当前全部笔记列表。
   */
  List<NoteItem> _notes = <NoteItem>[];

  /*
   * 当前全部文件夹路径列表。
   */
  List<String> _folderPaths = <String>[];

  /*
   * 当前选中的笔记。
   */
  NoteItem? _activeNote;

  /*
   * 当前选中的分类标识。
   */
  String _activeCategoryId = 'all';

  /*
   * 当前处于打开状态的目录路径。
   */
  String _activeDirectoryPath = '';

  /*
   * 是否处于选择模式。
   */
  bool _isSelectionMode = false;

  /*
   * 小屏下是否展示浏览区域。
   */
  bool _isCompactBrowserVisible = true;

  /*
   * 当前选中的网格项标识集合。
   */
  Set<String> _selectedItemIds = <String>{};

  /*
   * 当前处于按压状态的浏览项标识。
   */
  String? _pressedBrowserItemId;

  /*
   * 当前正在拖动的浏览项。
   */
  NoteGridItem? _draggingBrowserItem;

  /*
   * 当前拖动预览在首页面板内的位置。
   */
  Offset? _dragPreviewLocalTopLeft;

  /*
   * 当前手指在拖动预览内部的按压偏移。
   */
  Offset? _dragPointerOffset;

  /*
   * 当前拖动预览尺寸。
   */
  Size _dragPreviewSize = Size.zero;

  /*
   * 当前拖动命中的目标浏览项标识。
   */
  String? _dragHoverItemId;

  /*
   * 当前会话内的文件夹访问次数。
   */
  final Map<String, int> _folderVisitCounts = <String, int>{};

  /*
   * 当前会话固定的分类栏文件夹排序。
   */
  List<String> _categoryFolderPaths = <String>[];

  /*
   * 当前首页排序方式。
   */
  NoteSortMode _activeSortMode = NoteSortMode.updatedAt;

  /*
   * 当前首页视图模式。
   */
  NoteViewMode _activeViewMode = NoteViewMode.grid;

  /*
   * 是否处于数据加载中。
   */
  bool _isLoading = true;

  /*
   * 保存状态文案。
   */
  String _saveStatusText = '正在加载...';

  /*
   * 延迟保存定时器。
   */
  Timer? _saveTimer;

  /*
   * 页面初始化逻辑。
   */
  @override
  void initState() {
    super.initState();
    _initializeNotes();
    _editorController.addListener(_handleEditorTextChanged);
  }

  /*
   * 页面销毁前释放控制器资源。
   */
  @override
  void dispose() {
    _saveTimer?.cancel();
    _hideMoreMenu(animate: false);
    _editorController.removeListener(_handleEditorTextChanged);
    _editorController.dispose();
    _editorFocusNode.dispose();
    super.dispose();
  }

  /*
   * 初始化笔记与文件夹列表。
   */
  Future<void> _initializeNotes() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final AppCacheData appCache = await _appCacheService.loadCache();
      final List<NoteItem> notes = await _noteStorageService.loadNotes();
      final List<String> folderPaths = await _noteStorageService
          .loadFolderPaths();

      if (!mounted) {
        return;
      }

      setState(() {
        _notes = notes;
        _folderPaths = folderPaths;
        _folderVisitCounts
          ..clear()
          ..addAll(appCache.folderVisitCounts);
        _activeSortMode = _getSortModeFromCache(appCache.sortMode);
        _activeViewMode = _getViewModeFromCache(appCache.viewMode);
        _categoryFolderPaths = _buildCategoryFolderPaths(folderPaths);
        _activeNote = notes.isNotEmpty ? notes.first : null;
        _activeDirectoryPath = '';
        _editorController.text = notes.isNotEmpty ? notes.first.content : '';
        _editorController.selection = TextSelection.collapsed(
          offset: _editorController.text.length,
        );
        _saveStatusText = notes.isNotEmpty ? '已保存' : '没有可编辑的笔记';
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _saveStatusText = '加载失败';
        _isLoading = false;
      });

      _showMessageDialog('加载失败', error.toString());
    }
  }

  /*
   * 重新读取笔记与文件夹列表。
   */
  Future<void> _reloadNotes({bool keepDirectory = true}) async {
    final List<NoteItem> notes = await _noteStorageService.loadNotes();
    final List<String> folderPaths = await _noteStorageService
        .loadFolderPaths();

    if (!mounted) {
      return;
    }

    final NoteItem? nextActiveNote = _activeNote == null
        ? (notes.isNotEmpty ? notes.first : null)
        : notes.cast<NoteItem?>().firstWhere(
            (NoteItem? note) => note?.relativePath == _activeNote!.relativePath,
            orElse: () => notes.isNotEmpty ? notes.first : null,
          );

    setState(() {
      _notes = notes;
      _folderPaths = folderPaths;
      _activeNote = nextActiveNote;
      if (!keepDirectory) {
        _activeDirectoryPath = '';
      }
      if (nextActiveNote != null) {
        _editorController.text = nextActiveNote.content;
        _editorController.selection = TextSelection.collapsed(
          offset: _editorController.text.length,
        );
      } else {
        _editorController.clear();
      }
    });
  }

  /*
   * 展示通用消息弹窗。
   */
  Future<void> _showMessageDialog(String title, String message) async {
    await showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: const Text('确定'),
            ),
          ],
        );
      },
    );
  }

  /*
   * 隐藏更多菜单浮层。
   */
  void _hideMoreMenu({bool animate = true, VoidCallback? onHidden}) {
    final OverlayEntry? overlayEntry = _moreMenuOverlayEntry;

    if (overlayEntry == null) {
      onHidden?.call();
      return;
    }

    if (!animate) {
      overlayEntry.remove();
      _moreMenuOverlayEntry = null;
      _isMoreMenuClosing = false;
      onHidden?.call();
      return;
    }

    if (_isMoreMenuClosing) {
      return;
    }

    _isMoreMenuClosing = true;
    overlayEntry.markNeedsBuild();

    Future<void>.delayed(const Duration(milliseconds: 160), () {
      if (_moreMenuOverlayEntry != overlayEntry) {
        return;
      }

      overlayEntry.remove();
      _moreMenuOverlayEntry = null;
      _isMoreMenuClosing = false;
      onHidden?.call();
    });
  }

  /*
   * 展示右上角更多菜单。
   */
  void _showMoreMenu({required bool isWideLayout}) {
    if (_moreMenuOverlayEntry != null) {
      _hideMoreMenu();
      return;
    }

    final BuildContext? buttonContext = _moreMenuButtonKey.currentContext;

    if (buttonContext == null) {
      return;
    }

    final RenderBox buttonBox = buttonContext.findRenderObject() as RenderBox;
    final Offset buttonOffset = buttonBox.localToGlobal(Offset.zero);
    final Size buttonSize = buttonBox.size;
    final Size screenSize = MediaQuery.of(context).size;
    final double menuWidth = screenSize.width < 248
        ? screenSize.width - 24
        : 224;
    // 菜单右侧对齐下方笔记内容右边缘，而不是贴到顶部栏最右侧。
    final double menuRight = buttonOffset.dx + buttonSize.width - 28;
    final double menuLeft = (menuRight - menuWidth)
        .clamp(12.0, screenSize.width - menuWidth - 12.0)
        .toDouble();
    final double menuTop = (buttonOffset.dy + buttonSize.height + 8)
        .clamp(12.0, screenSize.height - 12.0)
        .toDouble();

    _isMoreMenuClosing = false;
    _moreMenuOverlayEntry = OverlayEntry(
      builder: (BuildContext overlayContext) {
        return _buildMoreMenuOverlay(
          left: menuLeft,
          top: menuTop,
          width: menuWidth,
          isWideLayout: isWideLayout,
        );
      },
    );

    Overlay.of(context).insert(_moreMenuOverlayEntry!);
  }

  /*
   * 处理更多菜单选项点击。
   */
  void _handleMoreMenuSelected(String value, {required bool isWideLayout}) {
    _hideMoreMenu(
      onHidden: () {
        if (value == 'viewMode') {
          _handleViewModeChanged();
        } else if (value == 'settings') {
          _openSettingsPage();
        } else if (value == 'sortName') {
          _handleSortModeChanged(NoteSortMode.name);
        } else if (value == 'sortCreatedAt') {
          _handleSortModeChanged(NoteSortMode.createdAt);
        } else if (value == 'sortUpdatedAt') {
          _handleSortModeChanged(NoteSortMode.updatedAt);
        }
      },
    );
  }

  /*
   * 构建更多菜单浮层。
   */
  Widget _buildMoreMenuOverlay({
    required double left,
    required double top,
    required double width,
    required bool isWideLayout,
  }) {
    return Stack(
      children: <Widget>[
        Positioned.fill(
          child: Listener(
            behavior: HitTestBehavior.translucent,
            onPointerUp: (_) {
              _hideMoreMenu();
            },
            onPointerCancel: (_) {
              _hideMoreMenu();
            },
            child: TweenAnimationBuilder<double>(
              duration: Duration(milliseconds: _isMoreMenuClosing ? 160 : 180),
              curve: _isMoreMenuClosing
                  ? Curves.easeInCubic
                  : Curves.easeOutCubic,
              tween: Tween<double>(
                begin: _isMoreMenuClosing ? 1 : 0,
                end: _isMoreMenuClosing ? 0 : 1,
              ),
              builder: (BuildContext context, double value, Widget? child) {
                return Opacity(opacity: value, child: child);
              },
              child: Container(
                // 更多菜单外部遮罩背景样式。
                color: const Color(0x33000000),
              ),
            ),
          ),
        ),
        Positioned(
          left: left,
          top: top,
          width: width,
          child: TweenAnimationBuilder<double>(
            duration: Duration(milliseconds: _isMoreMenuClosing ? 160 : 180),
            curve: _isMoreMenuClosing
                ? Curves.easeInCubic
                : Curves.easeOutCubic,
            tween: Tween<double>(
              begin: _isMoreMenuClosing ? 1 : 0.72,
              end: _isMoreMenuClosing ? 0.72 : 1,
            ),
            child: _buildMoreMenuPanel(isWideLayout: isWideLayout),
            builder: (BuildContext context, double value, Widget? child) {
              return Opacity(
                opacity: ((value - 0.72) / 0.28).clamp(0.0, 1.0).toDouble(),
                child: Transform.scale(
                  scale: value,
                  alignment: Alignment.topRight,
                  child: child,
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  /*
   * 构建更多菜单面板。
   */
  Widget _buildMoreMenuPanel({required bool isWideLayout}) {
    return Material(
      // 更多菜单面板材质样式
      color: Colors.white,
      elevation: 18,
      shadowColor: const Color(0x33000000),
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: Column(
        // 更多菜单选项纵向布局样式
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _buildMoreMenuItem(
            label: _getOppositeViewModeLabel(),
            value: 'viewMode',
            isWideLayout: isWideLayout,
          ),
          _buildMoreMenuItem(
            label: '设置',
            value: 'settings',
            isWideLayout: isWideLayout,
          ),
          const Divider(height: 1, color: Color(0xFFEAEAEA)),
          _buildMoreMenuItem(
            label: '按名称排序',
            value: 'sortName',
            isSelected: _activeSortMode == NoteSortMode.name,
            isWideLayout: isWideLayout,
          ),
          _buildMoreMenuItem(
            label: '按创建时间排序',
            value: 'sortCreatedAt',
            isSelected: _activeSortMode == NoteSortMode.createdAt,
            isWideLayout: isWideLayout,
          ),
          _buildMoreMenuItem(
            label: '按修改时间排序',
            value: 'sortUpdatedAt',
            isSelected: _activeSortMode == NoteSortMode.updatedAt,
            isWideLayout: isWideLayout,
          ),
        ],
      ),
    );
  }

  /*
   * 构建更多菜单单个选项。
   */
  Widget _buildMoreMenuItem({
    required String label,
    required String value,
    required bool isWideLayout,
    bool isSelected = false,
  }) {
    return InkWell(
      onTap: () {
        _handleMoreMenuSelected(value, isWideLayout: isWideLayout);
      },
      child: SizedBox(
        height: 52,
        child: Padding(
          // 更多菜单选项内容边距样式
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Row(
            // 更多菜单选项横向布局样式
            children: <Widget>[
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  // 更多菜单选项文字样式
                  style: TextStyle(
                    color: isSelected
                        ? const Color(0xFFB88900)
                        : const Color(0xFF222222),
                    fontSize: 16,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
              if (isSelected)
                const Icon(
                  Icons.check_rounded,
                  // 更多菜单选中图标颜色样式
                  color: Color(0xFFB88900),
                  size: 22,
                ),
            ],
          ),
        ),
      ),
    );
  }

  /*
   * 获取首页分类集合。
   */
  List<NoteCategoryItem> _buildCategories() {
    return <NoteCategoryItem>[
      const NoteCategoryItem(id: 'all', label: '全部笔记', isAllNotes: true),
      ..._categoryFolderPaths
          .where(_folderPaths.contains)
          .take(8)
          .map(
            (String folderPath) => NoteCategoryItem(
              id: folderPath,
              label: _getFolderDisplayName(folderPath),
              isAllNotes: false,
            ),
          ),
    ];
  }

  /*
   * 根据当前缓存热度生成分类栏文件夹排序。
   */
  List<String> _buildCategoryFolderPaths(List<String> folderPaths) {
    return folderPaths.toList()..sort((String left, String right) {
      final int heatResult = _getFolderHeat(
        right,
      ).compareTo(_getFolderHeat(left));

      if (heatResult != 0) {
        return heatResult;
      }

      return left.compareTo(right);
    });
  }

  /*
   * 获取当前分类下展示的笔记列表。
   */
  List<NoteItem> _getVisibleNotes() {
    return _notes;
  }

  /*
   * 获取文件夹分类显示名称。
   */
  String _getFolderDisplayName(String folderPath) {
    if (folderPath.isEmpty) {
      return '全部笔记';
    }

    final String folderName = folderPath.split('/').last;

    if (folderName.length <= 9) {
      return folderName;
    }

    return '${folderName.substring(0, 9)}...';
  }

  /*
   * 获取排序方式显示文案。
   */
  String _getSortModeLabel(NoteSortMode sortMode) {
    switch (sortMode) {
      case NoteSortMode.name:
        return '按名称排序';
      case NoteSortMode.createdAt:
        return '按创建时间排序';
      case NoteSortMode.updatedAt:
        return '按修改时间排序';
    }
  }

  /*
   * 根据缓存值获取排序方式。
   */
  NoteSortMode _getSortModeFromCache(String sortMode) {
    for (final NoteSortMode value in NoteSortMode.values) {
      if (value.name == sortMode) {
        return value;
      }
    }

    return NoteSortMode.updatedAt;
  }

  /*
   * 根据缓存值获取视图模式。
   */
  NoteViewMode _getViewModeFromCache(String viewMode) {
    for (final NoteViewMode value in NoteViewMode.values) {
      if (value.name == viewMode) {
        return value;
      }
    }

    return NoteViewMode.grid;
  }

  /*
   * 保存当前应用缓存。
   */
  Future<void> _saveAppCache() async {
    try {
      await _appCacheService.saveCache(
        AppCacheData(
          folderVisitCounts: Map<String, int>.from(_folderVisitCounts),
          sortMode: _activeSortMode.name,
          viewMode: _activeViewMode.name,
        ),
      );
    } catch (error) {
      // 缓存失败不影响笔记读写，后续操作会继续尝试保存。
    }
  }

  /*
   * 获取菜单里需要展示的相反视图模式文案。
   */
  String _getOppositeViewModeLabel() {
    switch (_activeViewMode) {
      case NoteViewMode.grid:
        return '列表模式';
      case NoteViewMode.list:
        return '宫格模式';
    }
  }

  /*
   * 切换首页排序方式。
   */
  void _handleSortModeChanged(NoteSortMode sortMode) {
    if (_activeSortMode == sortMode) {
      return;
    }

    setState(() {
      _activeSortMode = sortMode;
    });
    unawaited(_saveAppCache());
  }

  /*
   * 切换首页视图模式。
   */
  void _handleViewModeChanged() {
    setState(() {
      _activeViewMode = _activeViewMode == NoteViewMode.grid
          ? NoteViewMode.list
          : NoteViewMode.grid;
    });
    unawaited(_saveAppCache());
  }

  /*
   * 打开设置页面。
   */
  void _openSettingsPage() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext routeContext) {
          return const NoteSettingsPage();
        },
      ),
    );
  }

  /*
   * 比较两个名称文本。
   */
  int _compareNameText(String left, String right) {
    final int lowerResult = left.toLowerCase().compareTo(right.toLowerCase());

    if (lowerResult != 0) {
      return lowerResult;
    }

    return left.compareTo(right);
  }

  /*
   * 按时间倒序比较两个时间值。
   */
  int _compareDateDesc(DateTime left, DateTime right) {
    return right.compareTo(left);
  }

  /*
   * 格式化首页笔记卡片日期。
   */
  String _formatNoteCardDate(DateTime dateTime) {
    return '${dateTime.year}/${dateTime.month}/${dateTime.day}';
  }

  /*
   * 构造直接子目录的完整相对路径。
   */
  String _buildChildDirectoryPath(
    String directoryPath,
    String childDirectoryName,
  ) {
    if (directoryPath.isEmpty) {
      return childDirectoryName;
    }

    return '$directoryPath/$childDirectoryName';
  }

  /*
   * 获取文件夹内部的全部笔记。
   */
  Iterable<NoteItem> _getFolderNotes(String folderPath) {
    return _notes.where(
      (NoteItem note) =>
          note.directoryPath == folderPath ||
          note.directoryPath.startsWith('$folderPath/'),
    );
  }

  /*
   * 获取文件夹创建时间排序使用的时间值。
   */
  DateTime _getFolderCreatedAt(String folderPath) {
    DateTime? createdAt;

    for (final NoteItem note in _getFolderNotes(folderPath)) {
      if (createdAt == null || note.createdAt.isBefore(createdAt)) {
        createdAt = note.createdAt;
      }
    }

    return createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
  }

  /*
   * 获取文件夹修改时间排序使用的时间值。
   */
  DateTime _getFolderUpdatedAt(String folderPath) {
    DateTime? updatedAt;

    for (final NoteItem note in _getFolderNotes(folderPath)) {
      if (updatedAt == null || note.updatedAt.isAfter(updatedAt)) {
        updatedAt = note.updatedAt;
      }
    }

    return updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
  }

  /*
   * 按当前排序方式比较两个直接子目录。
   */
  int _compareDirectoryNamesBySortMode(
    String leftName,
    String rightName,
    String parentDirectoryPath,
  ) {
    switch (_activeSortMode) {
      case NoteSortMode.name:
        return _compareNameText(leftName, rightName);
      case NoteSortMode.createdAt:
        final int createdResult = _compareDateDesc(
          _getFolderCreatedAt(
            _buildChildDirectoryPath(parentDirectoryPath, leftName),
          ),
          _getFolderCreatedAt(
            _buildChildDirectoryPath(parentDirectoryPath, rightName),
          ),
        );

        if (createdResult != 0) {
          return createdResult;
        }

        return _compareNameText(leftName, rightName);
      case NoteSortMode.updatedAt:
        final int updatedResult = _compareDateDesc(
          _getFolderUpdatedAt(
            _buildChildDirectoryPath(parentDirectoryPath, leftName),
          ),
          _getFolderUpdatedAt(
            _buildChildDirectoryPath(parentDirectoryPath, rightName),
          ),
        );

        if (updatedResult != 0) {
          return updatedResult;
        }

        return _compareNameText(leftName, rightName);
    }
  }

  /*
   * 按当前排序方式比较两条笔记。
   */
  int _compareNotesBySortMode(NoteItem left, NoteItem right) {
    switch (_activeSortMode) {
      case NoteSortMode.name:
        return _compareNameText(left.title, right.title);
      case NoteSortMode.createdAt:
        final int createdResult = _compareDateDesc(
          left.createdAt,
          right.createdAt,
        );

        if (createdResult != 0) {
          return createdResult;
        }

        return _compareNameText(left.title, right.title);
      case NoteSortMode.updatedAt:
        final int updatedResult = _compareDateDesc(
          left.updatedAt,
          right.updatedAt,
        );

        if (updatedResult != 0) {
          return updatedResult;
        }

        return _compareNameText(left.title, right.title);
    }
  }

  /*
   * 获取文件夹热度值。
   */
  int _getFolderHeat(String folderPath) {
    return (_folderVisitCounts[folderPath] ?? 0) * 1000 +
        _getFolderNoteCount(folderPath);
  }

  /*
   * 增加文件夹访问热度。
   */
  void _increaseFolderVisitCount(String folderPath) {
    if (folderPath.isEmpty) {
      return;
    }

    _folderVisitCounts[folderPath] = (_folderVisitCounts[folderPath] ?? 0) + 1;
    unawaited(_saveAppCache());
  }

  /*
   * 获取当前目录的面包屑路径集合。
   */
  List<String> _getActiveDirectorySegments() {
    if (_activeDirectoryPath.isEmpty) {
      return <String>[];
    }

    return _activeDirectoryPath
        .split('/')
        .where((String value) => value.isNotEmpty)
        .toList();
  }

  /*
   * 获取指定目录下的直接子目录集合。
   */
  List<String> _getDirectChildDirectories(String directoryPath) {
    final Set<String> directories = <String>{};
    final List<String> sourcePaths = <String>[
      ..._folderPaths,
      ..._notes
          .map((NoteItem note) => note.directoryPath)
          .where((String value) => value.isNotEmpty),
    ];

    for (final String folderPath in sourcePaths) {
      if (directoryPath.isEmpty) {
        directories.add(folderPath.split('/').first);
        continue;
      }

      if (!folderPath.startsWith('$directoryPath/')) {
        continue;
      }

      final String remainingPath = folderPath.substring(
        directoryPath.length + 1,
      );
      if (remainingPath.isNotEmpty) {
        directories.add(remainingPath.split('/').first);
      }
    }

    return directories.toList()..sort(
      (String left, String right) =>
          _compareDirectoryNamesBySortMode(left, right, directoryPath),
    );
  }

  /*
   * 获取指定目录下的直接笔记集合。
   */
  List<NoteItem> _getDirectNotes(List<NoteItem> notes, String directoryPath) {
    return notes
        .where((NoteItem note) => note.directoryPath == directoryPath)
        .toList()
      ..sort(_compareNotesBySortMode);
  }

  /*
   * 获取文件夹下的笔记总数。
   */
  int _getFolderNoteCount(String folderPath) {
    return _getFolderNotes(folderPath).length;
  }

  /*
   * 获取首页网格项集合。
   */
  List<NoteGridItem> _buildGridItems() {
    final List<NoteItem> visibleNotes = _getVisibleNotes();

    if (_activeCategoryId == 'all') {
      final List<String> childDirectories = _getDirectChildDirectories(
        _activeDirectoryPath,
      );
      final List<NoteItem> directNotes = _getDirectNotes(
        visibleNotes,
        _activeDirectoryPath,
      );
      final List<NoteGridItem> items = <NoteGridItem>[];

      for (final String directoryName in childDirectories) {
        final String nextPath = _activeDirectoryPath.isEmpty
            ? directoryName
            : '$_activeDirectoryPath/$directoryName';
        final int noteCount = _getFolderNoteCount(nextPath);
        items.add(
          NoteGridItem(
            id: 'folder:$nextPath',
            type: NoteGridItemType.folder,
            title: directoryName,
            subtitle: '$noteCount',
            locationText: nextPath,
            noteCount: noteCount,
          ),
        );
      }

      for (final NoteItem note in directNotes) {
        items.add(
          NoteGridItem(
            id: 'note:${note.relativePath}',
            type: NoteGridItemType.note,
            title: note.title,
            subtitle: note.preview,
            locationText: note.displayPath,
            note: note,
          ),
        );
      }

      return items;
    }

    return (visibleNotes.toList()..sort(_compareNotesBySortMode))
        .map(
          (NoteItem note) => NoteGridItem(
            id: 'note:${note.relativePath}',
            type: NoteGridItemType.note,
            title: note.title,
            subtitle: note.preview,
            locationText: note.displayPath,
            note: note,
          ),
        )
        .toList();
  }

  /*
   * 获取已选择的笔记集合。
   */
  List<NoteItem> _getSelectedNotes() {
    return _notes
        .where(
          (NoteItem note) =>
              _selectedItemIds.contains('note:${note.relativePath}'),
        )
        .toList();
  }

  /*
   * 获取已选择的文件夹路径集合。
   */
  List<String> _getSelectedFolderPaths() {
    return _selectedItemIds
        .where((String id) => id.startsWith('folder:'))
        .map((String id) => id.substring('folder:'.length))
        .toList();
  }

  /*
   * 获取文件夹的父级目录路径。
   */
  String _getParentDirectoryPath(String folderPath) {
    if (!folderPath.contains('/')) {
      return '';
    }

    return folderPath.substring(0, folderPath.lastIndexOf('/'));
  }

  /*
   * 判断当前选择项是否可以移出文件夹。
   */
  bool _canMoveSelectedItemsOut() {
    final List<NoteItem> selectedNotes = _getSelectedNotes();
    final List<String> selectedFolderPaths = _getSelectedFolderPaths();

    if (selectedNotes.isEmpty && selectedFolderPaths.isEmpty) {
      return false;
    }

    return selectedNotes.any(
          (NoteItem note) => note.directoryPath.isNotEmpty,
        ) ||
        selectedFolderPaths.any(
          (String folderPath) => folderPath.contains('/'),
        );
  }

  /*
   * 判断目标文件夹是否可以作为移动目标。
   */
  bool _canUseMoveTarget(String targetDirectoryPath) {
    for (final NoteItem note in _getSelectedNotes()) {
      if (note.directoryPath == targetDirectoryPath) {
        return false;
      }
    }

    for (final String folderPath in _getSelectedFolderPaths()) {
      if (folderPath == targetDirectoryPath ||
          _getParentDirectoryPath(folderPath) == targetDirectoryPath ||
          targetDirectoryPath.startsWith('$folderPath/')) {
        return false;
      }
    }

    return true;
  }

  /*
   * 处理编辑器文本变化，并触发延迟保存。
   */
  void _handleEditorTextChanged() {
    if (_activeNote == null) {
      return;
    }

    setState(() {
      _saveStatusText = '编辑中...';
    });

    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 500), () {
      _persistActiveNote(_editorController.text);
    });
  }

  /*
   * 激活指定笔记，并同步编辑器内容。
   */
  void _activateNote(NoteItem note, {required bool isWideLayout}) {
    setState(() {
      _activeNote = note;
      _editorController.text = note.content;
      _editorController.selection = TextSelection.collapsed(
        offset: _editorController.text.length,
      );
      _saveStatusText = '已保存';
      if (!isWideLayout) {
        _isCompactBrowserVisible = false;
      }
    });
  }

  /*
   * 切换首页分类。
   */
  void _handleCategoryChanged(String categoryId) {
    setState(() {
      _activeCategoryId = 'all';
      _activeDirectoryPath = categoryId == 'all' ? '' : categoryId;
      _increaseFolderVisitCount(_activeDirectoryPath);
    });
  }

  /*
   * 切换当前目录。
   */
  void _handleDirectoryChanged(String directoryPath) {
    setState(() {
      _activeDirectoryPath = directoryPath;
      _increaseFolderVisitCount(directoryPath);
    });
  }

  /*
   * 判断系统返回键是否需要由当前页面处理。
   */
  bool _canHandleSystemBack({required bool isWideLayout}) {
    return _isSelectionMode ||
        (!isWideLayout && !_isCompactBrowserVisible) ||
        _activeDirectoryPath.isNotEmpty;
  }

  /*
   * 处理系统返回键操作。
   */
  void _handleSystemBack({required bool isWideLayout}) {
    if (_isSelectionMode) {
      setState(() {
        _exitSelectionMode();
      });
      return;
    }

    if (!isWideLayout && !_isCompactBrowserVisible) {
      setState(() {
        _isCompactBrowserVisible = true;
      });
      return;
    }

    if (_activeDirectoryPath.isNotEmpty) {
      _handleDirectoryChanged(_getParentDirectoryPath(_activeDirectoryPath));
    }
  }

  /*
   * 创建新的笔记。
   */
  Future<void> _handleCreateNote({required bool isWideLayout}) async {
    try {
      final String targetDirectoryPath = _activeCategoryId == 'all'
          ? _activeDirectoryPath
          : (_activeNote?.directoryPath ?? '');
      final NoteItem nextNote = await _noteStorageService.createNote(
        directoryPath: targetDirectoryPath,
      );

      if (!mounted) {
        return;
      }

      await _reloadNotes();

      setState(() {
        _activeCategoryId = 'all';
        _activeDirectoryPath = nextNote.directoryPath;
      });

      _activateNote(nextNote, isWideLayout: isWideLayout);
      _editorFocusNode.requestFocus();
    } catch (error) {
      await _showMessageDialog('创建失败', error.toString());
    }
  }

  /*
   * 弹出新建文件夹输入框。
   */
  Future<String?> _showCreateFolderDialog() async {
    final TextEditingController folderNameController = TextEditingController(
      text: '新建文件夹',
    );

    return showDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('新建文件夹'),
          content: TextField(
            controller: folderNameController,
            autofocus: true,
            decoration: const InputDecoration(hintText: '输入文件夹名称'),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(
                  dialogContext,
                ).pop(folderNameController.text.trim());
              },
              child: const Text('创建'),
            ),
          ],
        );
      },
    );
  }

  /*
   * 创建当前目录下的新文件夹。
   */
  Future<String?> _handleCreateFolder({
    bool moveSelectedAfterCreate = false,
  }) async {
    final String? folderName = await _showCreateFolderDialog();

    if (folderName == null || folderName.isEmpty) {
      return null;
    }

    try {
      final String parentDirectoryPath = _activeCategoryId == 'all'
          ? _activeDirectoryPath
          : '';
      final String nextFolderPath = await _noteStorageService.createFolder(
        parentDirectoryPath,
        folderName,
      );

      if (moveSelectedAfterCreate) {
        await _moveSelectedItemsToDirectory(nextFolderPath);
      } else {
        await _reloadNotes();
        setState(() {
          _activeCategoryId = 'all';
          _activeDirectoryPath = parentDirectoryPath;
        });
      }

      return nextFolderPath;
    } catch (error) {
      await _showMessageDialog('创建失败', error.toString());
      return null;
    }
  }

  /*
   * 删除当前选中的笔记。
   */
  Future<void> _handleDeleteNote({required bool isWideLayout}) async {
    if (_activeNote == null) {
      return;
    }

    final bool? shouldDelete = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('删除笔记'),
          content: Text('确定删除「${_activeNote!.title}」吗？'),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              child: const Text('删除'),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true) {
      return;
    }

    try {
      await _noteStorageService.deleteNote(_activeNote!.relativePath);
      await _reloadNotes();

      if (!mounted) {
        return;
      }

      setState(() {
        _saveStatusText = _activeNote == null ? '没有可编辑的笔记' : '已保存';
        if (_notes.isEmpty) {
          _isCompactBrowserVisible = true;
        }
      });
    } catch (error) {
      await _showMessageDialog('删除失败', error.toString());
    }
  }

  /*
   * 选择指定笔记并保存当前编辑内容。
   */
  Future<void> _handleSelectNote(
    NoteItem note, {
    required bool isWideLayout,
  }) async {
    if (_isSelectionMode) {
      _toggleSelectedItem('note:${note.relativePath}');
      return;
    }

    if (_activeNote != null && _activeNote!.relativePath != note.relativePath) {
      await _persistActiveNote(_editorController.text);
    }

    if (!mounted) {
      return;
    }

    _activateNote(note, isWideLayout: isWideLayout);
  }

  /*
   * 退出选择模式。
   */
  void _exitSelectionMode() {
    _isSelectionMode = false;
    _selectedItemIds = <String>{};
    _pressedBrowserItemId = null;
    _draggingBrowserItem = null;
    _dragPreviewLocalTopLeft = null;
    _dragPointerOffset = null;
    _dragPreviewSize = Size.zero;
    _dragHoverItemId = null;
  }

  /*
   * 切换网格项选择状态。
   */
  void _toggleSelectedItem(String itemId) {
    setState(() {
      final Set<String> nextSelectedItemIds = <String>{..._selectedItemIds};

      if (nextSelectedItemIds.contains(itemId)) {
        nextSelectedItemIds.remove(itemId);
      } else {
        nextSelectedItemIds.add(itemId);
      }

      _selectedItemIds = nextSelectedItemIds;
    });
  }

  /*
   * 开始按压浏览项。
   */
  void _startPressingBrowserItem(String itemId) {
    if (_draggingBrowserItem != null || _pressedBrowserItemId == itemId) {
      return;
    }

    setState(() {
      _pressedBrowserItemId = itemId;
    });
  }

  /*
   * 结束按压浏览项。
   */
  void _finishPressingBrowserItem(String itemId) {
    if (_draggingBrowserItem?.id == itemId) {
      return;
    }

    if (_pressedBrowserItemId != itemId) {
      return;
    }

    setState(() {
      _pressedBrowserItemId = null;
    });
  }

  /*
   * 获取浏览项定位标识。
   */
  GlobalKey _getBrowserItemKey(String itemId) {
    return _browserItemKeys.putIfAbsent(itemId, GlobalKey.new);
  }

  /*
   * 将全局坐标转换为首页面板内坐标。
   */
  Offset _getHomePanelLocalPosition(Offset globalPosition) {
    final BuildContext? homePanelContext = _homePanelKey.currentContext;

    if (homePanelContext == null) {
      return globalPosition;
    }

    final RenderObject? renderObject = homePanelContext.findRenderObject();

    if (renderObject is! RenderBox) {
      return globalPosition;
    }

    return renderObject.globalToLocal(globalPosition);
  }

  /*
   * 获取浏览项中心点在首页面板内的位置。
   */
  Offset? _getBrowserItemCenterInHomePanel(String itemId) {
    final BuildContext? itemContext = _browserItemKeys[itemId]?.currentContext;
    final BuildContext? homePanelContext = _homePanelKey.currentContext;

    if (itemContext == null || homePanelContext == null) {
      return null;
    }

    final RenderObject? itemRenderObject = itemContext.findRenderObject();
    final RenderObject? homePanelRenderObject = homePanelContext
        .findRenderObject();

    if (itemRenderObject is! RenderBox || homePanelRenderObject is! RenderBox) {
      return null;
    }

    final Offset globalCenter = itemRenderObject.localToGlobal(
      itemRenderObject.size.center(Offset.zero),
    );
    return homePanelRenderObject.globalToLocal(globalCenter);
  }

  /*
   * 根据拖动矩形查找当前命中的浏览项。
   */
  String? _findDragHoverItemId(Rect dragRect) {
    for (final String itemId in _browserItemKeys.keys) {
      if (itemId == _draggingBrowserItem?.id) {
        continue;
      }

      final Offset? itemCenter = _getBrowserItemCenterInHomePanel(itemId);

      if (itemCenter != null && dragRect.contains(itemCenter)) {
        return itemId;
      }
    }

    return null;
  }

  /*
   * 根据拖拽预览位置获取缩放后的实际命中矩形。
   */
  Rect _getScaledDragRect(Offset previewTopLeft, Size previewSize) {
    return Rect.fromCenter(
      center: previewTopLeft + previewSize.center(Offset.zero),
      width: previewSize.width * _dragCardScale,
      height: previewSize.height * _dragCardScale,
    );
  }

  /*
   * 开始拖动浏览项。
   */
  void _startDraggingBrowserItem(NoteGridItem item, Offset globalPosition) {
    final BuildContext? itemContext = _getBrowserItemKey(
      item.id,
    ).currentContext;
    Size itemSize = const Size(180, 140);
    Offset? itemTopLeft;

    if (itemContext != null) {
      final RenderObject? itemRenderObject = itemContext.findRenderObject();

      if (itemRenderObject is RenderBox) {
        itemSize = itemRenderObject.size;
        itemTopLeft = _getHomePanelLocalPosition(
          itemRenderObject.localToGlobal(Offset.zero),
        );
      }
    }

    final Offset localPosition = _getHomePanelLocalPosition(globalPosition);
    final Offset pointerOffset = itemTopLeft == null
        ? itemSize.center(Offset.zero)
        : localPosition - itemTopLeft;
    final Offset previewTopLeft = itemTopLeft ?? localPosition - pointerOffset;
    final Rect dragRect = _getScaledDragRect(previewTopLeft, itemSize);

    setState(() {
      _isSelectionMode = true;
      _selectedItemIds = <String>{item.id};
      _pressedBrowserItemId = item.id;
      _draggingBrowserItem = item;
      _dragPreviewSize = itemSize;
      _dragPreviewLocalTopLeft = previewTopLeft;
      _dragPointerOffset = pointerOffset;
      _dragHoverItemId = _findDragHoverItemId(dragRect);
    });
  }

  /*
   * 更新拖动浏览项位置。
   */
  void _updateDraggingBrowserItem(Offset globalPosition) {
    if (_draggingBrowserItem == null || _dragPreviewSize == Size.zero) {
      return;
    }

    final Offset localPosition = _getHomePanelLocalPosition(globalPosition);
    final Offset previewTopLeft =
        localPosition -
        (_dragPointerOffset ?? _dragPreviewSize.center(Offset.zero));
    final Rect dragRect = _getScaledDragRect(previewTopLeft, _dragPreviewSize);

    setState(() {
      _dragPreviewLocalTopLeft = previewTopLeft;
      _dragHoverItemId = _findDragHoverItemId(dragRect);
    });
  }

  /*
   * 结束拖动浏览项。
   */
  Future<void> _finishDraggingBrowserItem({bool performDrop = true}) async {
    final NoteGridItem? sourceItem = _draggingBrowserItem;
    final String? targetItemId = _dragHoverItemId;
    NoteGridItem? targetItem;

    if (sourceItem == null) {
      return;
    }

    if (performDrop && targetItemId != null) {
      for (final NoteGridItem item in _buildGridItems()) {
        if (item.id == targetItemId) {
          targetItem = item;
          break;
        }
      }
    }

    setState(() {
      _pressedBrowserItemId = null;
      _draggingBrowserItem = null;
      _dragPreviewLocalTopLeft = null;
      _dragPointerOffset = null;
      _dragPreviewSize = Size.zero;
      _dragHoverItemId = null;
    });

    if (!performDrop || targetItem == null) {
      return;
    }

    if (targetItem.type == NoteGridItemType.folder) {
      await _moveDraggedItemToFolder(sourceItem, targetItem);
      return;
    }

    if (sourceItem.type == NoteGridItemType.note) {
      await _createFolderForDraggedNotes(sourceItem, targetItem);
    }
  }

  /*
   * 将拖动项移动到目标文件夹。
   */
  Future<void> _moveDraggedItemToFolder(
    NoteGridItem sourceItem,
    NoteGridItem targetFolderItem,
  ) async {
    try {
      if (sourceItem.type == NoteGridItemType.note) {
        await _noteStorageService.moveNoteToDirectory(
          sourceItem.note!,
          targetFolderItem.locationText,
        );
      } else {
        await _noteStorageService.moveFolderToDirectory(
          sourceItem.locationText,
          targetFolderItem.locationText,
        );
      }

      if (!mounted) {
        return;
      }

      setState(_exitSelectionMode);
      await _reloadNotes();
    } catch (error) {
      await _showMessageDialog('移动失败', error.toString());
    }
  }

  /*
   * 为两条拖拽合并的笔记创建文件夹并完成移动。
   */
  Future<void> _createFolderForDraggedNotes(
    NoteGridItem sourceNoteItem,
    NoteGridItem targetNoteItem,
  ) async {
    final String? folderName = await _showCreateFolderDialog();

    if (folderName == null || folderName.isEmpty) {
      return;
    }

    try {
      final String parentDirectoryPath = _activeCategoryId == 'all'
          ? _activeDirectoryPath
          : '';
      final String nextFolderPath = await _noteStorageService.createFolder(
        parentDirectoryPath,
        folderName,
      );

      await _noteStorageService.moveNoteToDirectory(
        sourceNoteItem.note!,
        nextFolderPath,
      );
      await _noteStorageService.moveNoteToDirectory(
        targetNoteItem.note!,
        nextFolderPath,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _exitSelectionMode();
        _activeCategoryId = 'all';
        _activeDirectoryPath = parentDirectoryPath;
      });
      await _reloadNotes();
    } catch (error) {
      await _showMessageDialog('创建失败', error.toString());
    }
  }

  /*
   * 全选当前可见的网格项。
   */
  void _selectAllVisibleItems() {
    setState(() {
      _selectedItemIds = _buildGridItems()
          .map((NoteGridItem item) => item.id)
          .toSet();
      _isSelectionMode = _selectedItemIds.isNotEmpty;
    });
  }

  /*
   * 移动当前选择项到目标文件夹。
   */
  Future<void> _moveSelectedItemsToDirectory(String targetDirectoryPath) async {
    try {
      for (final NoteItem note in _getSelectedNotes()) {
        await _noteStorageService.moveNoteToDirectory(
          note,
          targetDirectoryPath,
        );
      }

      for (final String folderPath in _getSelectedFolderPaths()) {
        await _noteStorageService.moveFolderToDirectory(
          folderPath,
          targetDirectoryPath,
        );
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _exitSelectionMode();
        _activeDirectoryPath = targetDirectoryPath;
      });

      await _reloadNotes();
    } catch (error) {
      await _showMessageDialog('移动失败', error.toString());
    }
  }

  /*
   * 删除当前选择的笔记和文件夹。
   */
  Future<void> _deleteSelectedItems() async {
    if (_selectedItemIds.isEmpty) {
      return;
    }

    final bool? shouldDelete = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('删除所选内容'),
          content: Text('确定删除已选择的 ${_selectedItemIds.length} 项吗？'),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              child: const Text('删除'),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true) {
      return;
    }

    try {
      for (final NoteItem note in _getSelectedNotes()) {
        await _noteStorageService.deleteNote(note.relativePath);
      }

      for (final String folderPath in _getSelectedFolderPaths()) {
        await _noteStorageService.deleteFolder(folderPath);
      }

      if (!mounted) {
        return;
      }

      setState(_exitSelectionMode);
      await _reloadNotes();
    } catch (error) {
      await _showMessageDialog('删除失败', error.toString());
    }
  }

  /*
   * 展示移动目标文件夹面板。
   */
  Future<void> _showMoveSheet() async {
    if (_selectedItemIds.isEmpty) {
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext sheetContext) {
        return _buildMoveSheet(sheetContext);
      },
    );
  }

  /*
   * 保存当前激活笔记内容。
   */
  Future<void> _persistActiveNote(String content) async {
    if (_activeNote == null) {
      return;
    }

    if (content == _activeNote!.content) {
      if (mounted) {
        setState(() {
          _saveStatusText = '已保存';
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        _saveStatusText = '保存中...';
      });
    }

    try {
      final String previousNotePath = _activeNote!.relativePath;
      final NoteItem savedNote = (await _noteStorageService.saveNoteContent(
        _activeNote!.relativePath,
        content,
      )).copyWith(createdAt: _activeNote!.createdAt);

      if (!mounted) {
        return;
      }

      setState(() {
        _activeNote = savedNote;
        _notes =
            _notes
                .map(
                  (NoteItem item) =>
                      item.relativePath == previousNotePath ? savedNote : item,
                )
                .toList()
              ..sort(_compareNotesBySortMode);

        if (_activeCategoryId != 'all' &&
            !savedNote.tags.contains(_activeCategoryId)) {
          _activeCategoryId = 'all';
        }

        _saveStatusText = '已保存';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _saveStatusText = '保存失败';
      });

      await _showMessageDialog('保存失败', error.toString());
    }
  }

  /*
   * 执行 Markdown 工具栏操作。
   */
  void _handleToolbarAction(ToolbarActionKey actionKey) {
    final TextSelection selection = _editorController.selection;
    MarkdownEditResult result = MarkdownEditResult(
      text: _editorController.text,
      selection: selection,
    );

    switch (actionKey) {
      case ToolbarActionKey.title:
        result = applyLinePrefixSyntax(_editorController.text, selection, '# ');
      case ToolbarActionKey.subtitle:
        result = applyLinePrefixSyntax(
          _editorController.text,
          selection,
          '## ',
        );
      case ToolbarActionKey.bold:
        result = applyWrapSyntax(
          _editorController.text,
          selection,
          '**',
          '**',
          '加粗内容',
        );
      case ToolbarActionKey.list:
        result = applyLinePrefixSyntax(_editorController.text, selection, '- ');
      case ToolbarActionKey.todo:
        result = applyLinePrefixSyntax(
          _editorController.text,
          selection,
          '- [ ] ',
        );
      case ToolbarActionKey.quote:
        result = applyLinePrefixSyntax(_editorController.text, selection, '> ');
    }

    _editorController.value = TextEditingValue(
      text: result.text,
      selection: result.selection,
    );
    _editorFocusNode.requestFocus();
  }

  /*
   * 构建普通顶部栏区域。
   */
  Widget _buildNormalTopBar({required bool isWideLayout}) {
    return Padding(
      // 顶部栏独立控制外边距样式，方便和下方内容使用不同的水平间距。
      padding: const EdgeInsets.fromLTRB(28, 22, 0, 0),
      child: Row(
        // 顶部标题栏横向布局样式
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (!isWideLayout && !_isCompactBrowserVisible)
            IconButton(
              onPressed: () {
                setState(() {
                  _isCompactBrowserVisible = true;
                });
              },
              icon: const Icon(Icons.arrow_back_rounded),
              color: const Color(0xFF202020),
            ),
          Expanded(
            child: Column(
              // 顶部标题区纵向布局样式
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Row(
                  children: <Widget>[
                    Text(
                      '笔记',
                      // 顶部标题文字样式
                      style: TextStyle(
                        color: Color(0xFF111111),
                        fontSize: 34,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.only(left: 4, top: 4),
                      child: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: Color(0xFF111111),
                        size: 26,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '${_notes.length}篇笔记',
                  // 顶部统计文字样式
                  style: const TextStyle(
                    color: Color(0xFF666666),
                    fontSize: 17,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Row(
            // 顶部右侧操作按钮横向布局样式，只占搜索和更多按钮本身需要的宽度。
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              IconButton(
                onPressed: () {
                  _showMessageDialog('搜索', '搜索功能后面再接。');
                },
                icon: const Icon(Icons.search_rounded),
                color: const Color(0xFF111111),
                iconSize: 30,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints.tightFor(
                  width: 84,
                  height: 44,
                ),
              ),
              if (_isSelectionMode)
                IconButton(
                  onPressed: _selectAllVisibleItems,
                  icon: const Icon(Icons.checklist_rounded),
                  color: const Color(0xFF222222),
                  iconSize: 30,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints.tightFor(
                    width: 70,
                    height: 44,
                  ),
                )
              else
                Container(
                  key: _moreMenuButtonKey,
                  child: Tooltip(
                    message: '更多操作，${_getSortModeLabel(_activeSortMode)}',
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        _showMoreMenu(isWideLayout: isWideLayout);
                      },
                      child: const SizedBox(
                        // 三个点按钮实际占位样式，用 SizedBox 控制宽高比 constraints 更直接。
                        width: 70,
                        height: 44,
                        child: Align(
                          alignment: Alignment.center,
                          child: Icon(
                            Icons.more_vert_rounded,
                            color: Color(0xFF1F1F1F),
                            size: 22,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  /*
   * 构建首页上方的分类标签栏。
   *
   * 这里负责展示“全部笔记”和常访问文件夹这一排横向滑动标签。
   * 每一个标签本身的圆角、背景色和文字样式由 _buildCategoryPill 负责。
   * 当前方法只负责决定标签栏是否显示、显示哪些标签，以及它们如何横向排列。
   */
  Widget _buildCategoryBar() {
    // 从当前笔记和文件夹数据中生成分类列表，通常包含“全部笔记”和常访问文件夹。
    final List<NoteCategoryItem> categories = _buildCategories();

    return Padding(
      // 分类栏只保留上方间距，左右对齐交给首页根容器统一控制。
      padding: const EdgeInsets.only(top: 28),
      child: SizedBox(
        // 固定分类栏高度，防止标签内容或字体变化导致首页布局上下跳动。
        height: 48,
        child: ListView.separated(
          // 分类栏横向滚动布局样式
          // 横向滚动用于容纳多个常访问文件夹，窄屏时不会把标签挤压变形。
          scrollDirection: Axis.horizontal,
          // 右侧不再单独补边距，末尾对齐交给首页根容器统一控制。
          padding: EdgeInsets.zero,
          // 列表项数量完全由 categories 决定，避免手写额外项导致索引错位。
          itemCount: categories.length,
          // 每两个分类标签之间固定 10 像素间距，保持图二那种胶囊按钮间隔。
          separatorBuilder: (BuildContext context, int index) {
            return const SizedBox(width: 10);
          },
          // 按索引把分类数据转换为可点击的分类按钮。
          itemBuilder: (BuildContext context, int index) {
            // 当前要渲染的分类数据，里面包含 id、显示文字，以及是否是“全部笔记”。
            final NoteCategoryItem category = categories[index];
            // 判断当前分类是否处于选中状态，用来控制 _buildCategoryPill 的背景色。
            final bool isActive = category.isAllNotes
                // “全部笔记”选中条件：当前没有进入任何文件夹目录。
                ? _activeDirectoryPath.isEmpty
                // 文件夹分类选中条件：当前目录路径等于该分类的文件夹路径。
                : _activeDirectoryPath == category.id;

            // 构建单个分类按钮，点击行为和具体样式都收在 _buildCategoryPill 里。
            return _buildCategoryPill(category: category, isActive: isActive);
          },
        ),
      ),
    );
  }

  /*
   * 构建分类栏文字按钮。
   */
  Widget _buildCategoryPill({
    required NoteCategoryItem category,
    required bool isActive,
  }) {
    return GestureDetector(
      onTap: () {
        _handleCategoryChanged(category.id);
      },
      child: Container(
        decoration: BoxDecoration(
          // 分类文字按钮容器样式
          color: isActive ? const Color(0xFFdfe0e2) : Colors.white,
          borderRadius: BorderRadius.circular(15),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        alignment: Alignment.center,
        child: Text(
          category.label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          // 分类文字按钮文本样式
          style: TextStyle(
            color: const Color(0xFF111111),
            fontSize: 16,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  /*
   * 构建搜索栏。
   */
  Widget _buildSearchBar() {
    return const SizedBox.shrink();
  }

  /*
   * 构建统计条。
   */
  Widget _buildSummaryBar() {
    if (_isSelectionMode) {
      return const SizedBox.shrink();
    }

    return const SizedBox.shrink();
  }

  /*
   * 构建目录路径栏。
   */
  Widget _buildPathBar() {
    if (_activeCategoryId != 'all') {
      return Padding(
        // 标签路径栏只保留上方间距，左右对齐交给首页根容器统一控制。
        padding: const EdgeInsets.only(top: 14),
        child: Text(
          '#$_activeCategoryId',
          // 标签路径栏样式
          style: const TextStyle(color: Color(0xFF888888), fontSize: 14),
        ),
      );
    }

    final List<String> segments = _getActiveDirectorySegments();

    if (segments.isEmpty) {
      return const SizedBox(height: 12);
    }

    return Padding(
      // 面包屑路径栏只保留上方间距，左右对齐交给首页根容器统一控制。
      padding: const EdgeInsets.only(top: 14),
      child: Wrap(
        // 路径栏流式布局样式
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        runSpacing: 8,
        children: <Widget>[
          GestureDetector(
            onTap: () {
              _handleDirectoryChanged('');
            },
            child: const Text(
              '全部笔记',
              // 根路径文字样式
              style: TextStyle(
                color: Color(0xFFFFB800),
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          for (int index = 0; index < segments.length; index++) ...<Widget>[
            const Text(
              '/',
              style: TextStyle(color: Color(0xFFBBBBBB), fontSize: 14),
            ),
            GestureDetector(
              onTap: () {
                _handleDirectoryChanged(segments.take(index + 1).join('/'));
              },
              child: Text(
                segments[index],
                // 子路径文字样式
                style: const TextStyle(
                  color: Color(0xFF555555),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /*
   * 构建选择圆点。
   */
  Widget _buildSelectionCircle(bool isSelected) {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        // 选择圆点容器样式
        color: isSelected ? const Color(0xFFFFC000) : const Color(0xFFF3F3F3),
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFFE1E1E1)),
      ),
      child: isSelected
          ? const Icon(Icons.check_rounded, color: Colors.white, size: 20)
          : null,
    );
  }

  /*
   * 构建文件夹图标。
   */
  Widget _buildFolderIcon({double size = 58}) {
    return Icon(
      Icons.folder_rounded,
      color: const Color(0xFFFFD43B),
      size: size,
    );
  }

  /*
   * 构建浏览项动画外壳。
   */
  Widget _buildBrowserItemShell({
    required NoteGridItem item,
    required Widget child,
    double borderRadius = 18,
  }) {
    final bool isHoverTarget = _dragHoverItemId == item.id;
    final bool isDraggingItem = _draggingBrowserItem?.id == item.id;
    final bool isPressedItem = _pressedBrowserItemId == item.id;

    return SizedBox(
      key: _getBrowserItemKey(item.id),
      child: AnimatedOpacity(
        opacity: isDraggingItem ? 0 : 1,
        duration: const Duration(milliseconds: 90),
        curve: Curves.easeOutCubic,
        child: AnimatedScale(
          scale: isPressedItem
              ? _dragCardScale
              : (isHoverTarget ? _dragCardScale : 1),
          alignment: Alignment.center,
          duration: Duration(milliseconds: isPressedItem ? 80 : 140),
          curve: Curves.easeOutCubic,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            curve: Curves.easeOutCubic,
            foregroundDecoration: BoxDecoration(
              borderRadius: BorderRadius.circular(borderRadius),
              border: Border.all(
                color: isHoverTarget
                    ? const Color(0xFFFFC000)
                    : Colors.transparent,
                width: 3,
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }

  /*
   * 构建拖动中的文件夹预览。
   */
  Widget _buildDraggingFolderPreview(NoteGridItem item) {
    return _activeViewMode == NoteViewMode.list
        ? _buildFolderListRow(item)
        : _buildFolderCard(item);
  }

  /*
   * 构建拖动中的笔记预览。
   */
  Widget _buildDraggingNotePreview(NoteGridItem item) {
    return _activeViewMode == NoteViewMode.list
        ? _buildNoteListRow(
            item,
            isWideLayout: MediaQuery.of(context).size.width >= 980,
          )
        : _buildNoteCard(
            item,
            isWideLayout: MediaQuery.of(context).size.width >= 980,
          );
  }

  /*
   * 构建拖动中的浏览项预览。
   */
  Widget _buildDraggingBrowserPreview() {
    final NoteGridItem? item = _draggingBrowserItem;
    final Offset? topLeft = _dragPreviewLocalTopLeft;

    if (item == null || topLeft == null || _dragPreviewSize == Size.zero) {
      return const SizedBox.shrink();
    }

    return Positioned(
      left: topLeft.dx,
      top: topLeft.dy,
      width: _dragPreviewSize.width,
      child: IgnorePointer(
        child: Transform.scale(
          scale: _dragCardScale,
          alignment: Alignment.center,
          child: DecoratedBox(
            decoration: BoxDecoration(
              // 拖动预览四向阴影样式，下方最深、左右一致、上方最浅。
              borderRadius: BorderRadius.circular(18),
              boxShadow: const <BoxShadow>[
                BoxShadow(
                  color: Color(0x26000000),
                  blurRadius: 20,
                  offset: Offset(0, 10),
                ),
                BoxShadow(
                  color: Color(0x18000000),
                  blurRadius: 16,
                  offset: Offset(6, 0),
                ),
                BoxShadow(
                  color: Color(0x18000000),
                  blurRadius: 16,
                  offset: Offset(-6, 0),
                ),
                BoxShadow(
                  color: Color(0x0C000000),
                  blurRadius: 11,
                  offset: Offset(0, -4),
                ),
              ],
            ),
            child: item.type == NoteGridItemType.folder
                ? _buildDraggingFolderPreview(item)
                : _buildDraggingNotePreview(item),
          ),
        ),
      ),
    );
  }

  /*
   * 获取首页浏览区列数。
   */
  int _getBrowserColumnCount({required bool isWideLayout}) {
    return isWideLayout ? 3 : 2;
  }

  /*
   * 获取首页浏览区单项宽度。
   */
  double _getBrowserItemWidth({
    required double availableWidth,
    required bool isWideLayout,
  }) {
    // 首页根容器已经统一处理左右边距，这里只需要扣掉列间距。
    const double horizontalPadding = 0;
    const double itemSpacing = 10;
    final int columnCount = _getBrowserColumnCount(isWideLayout: isWideLayout);

    return (availableWidth -
            horizontalPadding -
            itemSpacing * (columnCount - 1)) /
        columnCount;
  }

  /*
   * 获取首页浏览区单项高度。
   */
  double _getBrowserItemHeight({
    required NoteGridItem item,
    required double itemWidth,
    required bool isWideLayout,
  }) {
    if (item.type == NoteGridItemType.folder) {
      return isWideLayout ? 118 : 104;
    }

    return itemWidth / (isWideLayout ? 1.08 : 0.82);
  }

  /*
   * 按当前最短列分配首页浏览区卡片。
   */
  List<List<NoteGridItem>> _buildBrowserColumns({
    required List<NoteGridItem> items,
    required double itemWidth,
    required bool isWideLayout,
  }) {
    final int columnCount = _getBrowserColumnCount(isWideLayout: isWideLayout);
    final List<List<NoteGridItem>> columns = List<List<NoteGridItem>>.generate(
      columnCount,
      (_) => <NoteGridItem>[],
    );
    final List<double> columnHeights = List<double>.filled(columnCount, 0);

    for (final NoteGridItem item in items) {
      int shortestColumnIndex = 0;

      for (int index = 1; index < columnHeights.length; index += 1) {
        if (columnHeights[index] < columnHeights[shortestColumnIndex]) {
          shortestColumnIndex = index;
        }
      }

      columns[shortestColumnIndex].add(item);
      columnHeights[shortestColumnIndex] +=
          _getBrowserItemHeight(
            item: item,
            itemWidth: itemWidth,
            isWideLayout: isWideLayout,
          ) +
          (columns[shortestColumnIndex].length > 1 ? 14 : 0);
    }

    return columns;
  }

  /*
   * 构建文件夹卡片。
   */
  Widget _buildFolderCard(NoteGridItem item) {
    final bool isSelected = _selectedItemIds.contains(item.id);
    final String folderTitle = item.title.isNotEmpty
        ? item.title
        : item.locationText.split('/').last;

    return GestureDetector(
      onTapDown: (_) {
        _startPressingBrowserItem(item.id);
      },
      onTapUp: (_) {
        _finishPressingBrowserItem(item.id);
      },
      onTapCancel: () {
        _finishPressingBrowserItem(item.id);
      },
      onTap: () {
        if (_isSelectionMode) {
          _toggleSelectedItem(item.id);
          return;
        }

        _handleDirectoryChanged(item.locationText);
      },
      onLongPressStart: (LongPressStartDetails details) {
        _startDraggingBrowserItem(item, details.globalPosition);
      },
      onLongPressMoveUpdate: (LongPressMoveUpdateDetails details) {
        _updateDraggingBrowserItem(details.globalPosition);
      },
      onLongPressEnd: (_) {
        _finishDraggingBrowserItem();
      },
      onLongPressCancel: () {
        _finishDraggingBrowserItem(performDrop: false);
      },
      child: Container(
        // 文件夹卡片容器样式
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: Color(0x0F000000),
              blurRadius: 18,
              offset: Offset(0, 8),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
        child: Stack(
          children: <Widget>[
            Row(
              children: <Widget>[
                _buildFolderIcon(size: 52),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    // 文件夹文字纵向布局样式
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        folderTitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        // 文件夹标题样式
                        style: const TextStyle(
                          color: Color(0xFF111111),
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${item.noteCount}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        // 文件夹数量样式
                        style: const TextStyle(
                          color: Color(0xFF888888),
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (_isSelectionMode)
              Positioned(
                right: 0,
                bottom: 0,
                child: _buildSelectionCircle(isSelected),
              ),
          ],
        ),
      ),
    );
  }

  /*
   * 构建笔记卡片。
   */
  Widget _buildNoteCard(NoteGridItem item, {required bool isWideLayout}) {
    final NoteItem note = item.note!;
    final bool isSelected = _selectedItemIds.contains(item.id);

    return GestureDetector(
      onTapDown: (_) {
        _startPressingBrowserItem(item.id);
      },
      onTapUp: (_) {
        _finishPressingBrowserItem(item.id);
      },
      onTapCancel: () {
        _finishPressingBrowserItem(item.id);
      },
      onTap: () {
        _handleSelectNote(note, isWideLayout: isWideLayout);
      },
      onLongPressStart: (LongPressStartDetails details) {
        _startDraggingBrowserItem(item, details.globalPosition);
      },
      onLongPressMoveUpdate: (LongPressMoveUpdateDetails details) {
        _updateDraggingBrowserItem(details.globalPosition);
      },
      onLongPressEnd: (_) {
        _finishDraggingBrowserItem();
      },
      onLongPressCancel: () {
        _finishDraggingBrowserItem(performDrop: false);
      },
      child: Container(
        // 笔记卡片容器样式
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: Color(0x0F000000),
              blurRadius: 18,
              offset: Offset(0, 8),
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(22, 24, 22, 20),
        child: Stack(
          children: <Widget>[
            Column(
              // 笔记卡片内容纵向布局样式
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  note.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  // 笔记卡片标题样式
                  style: const TextStyle(
                    color: Color(0xFF111111),
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  note.preview,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  // 笔记卡片摘要样式
                  style: const TextStyle(
                    color: Color(0xFF666666),
                    fontSize: 16,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _formatNoteCardDate(note.updatedAt),
                  // 笔记卡片日期样式
                  style: const TextStyle(
                    color: Color(0xFF9B9B9B),
                    fontSize: 15,
                  ),
                ),
              ],
            ),
            if (_isSelectionMode)
              Positioned(
                right: 0,
                bottom: 0,
                child: _buildSelectionCircle(isSelected),
              ),
          ],
        ),
      ),
    );
  }

  /*
   * 构建列表模式下的文件夹行。
   */
  Widget _buildFolderListRow(NoteGridItem item) {
    final bool isSelected = _selectedItemIds.contains(item.id);
    final String folderTitle = item.title.isNotEmpty
        ? item.title
        : item.locationText.split('/').last;

    return GestureDetector(
      onTapDown: (_) {
        _startPressingBrowserItem(item.id);
      },
      onTapUp: (_) {
        _finishPressingBrowserItem(item.id);
      },
      onTapCancel: () {
        _finishPressingBrowserItem(item.id);
      },
      onTap: () {
        if (_isSelectionMode) {
          _toggleSelectedItem(item.id);
          return;
        }

        _handleDirectoryChanged(item.locationText);
      },
      onLongPressStart: (LongPressStartDetails details) {
        _startDraggingBrowserItem(item, details.globalPosition);
      },
      onLongPressMoveUpdate: (LongPressMoveUpdateDetails details) {
        _updateDraggingBrowserItem(details.globalPosition);
      },
      onLongPressEnd: (_) {
        _finishDraggingBrowserItem();
      },
      onLongPressCancel: () {
        _finishDraggingBrowserItem(performDrop: false);
      },
      child: Container(
        // 文件夹列表行容器样式
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: Color(0x0A000000),
              blurRadius: 14,
              offset: Offset(0, 6),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        child: Stack(
          children: <Widget>[
            Row(
              // 文件夹列表行横向布局样式
              children: <Widget>[
                _buildFolderIcon(size: 44),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    // 文件夹列表文字纵向布局样式
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        folderTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        // 文件夹列表标题样式
                        style: const TextStyle(
                          color: Color(0xFF111111),
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${item.noteCount}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        // 文件夹列表数量样式
                        style: const TextStyle(
                          color: Color(0xFF888888),
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (_isSelectionMode)
              Positioned(
                right: 0,
                bottom: 0,
                child: _buildSelectionCircle(isSelected),
              ),
          ],
        ),
      ),
    );
  }

  /*
   * 构建列表模式下的笔记行。
   */
  Widget _buildNoteListRow(NoteGridItem item, {required bool isWideLayout}) {
    final NoteItem note = item.note!;
    final bool isSelected = _selectedItemIds.contains(item.id);

    return GestureDetector(
      onTapDown: (_) {
        _startPressingBrowserItem(item.id);
      },
      onTapUp: (_) {
        _finishPressingBrowserItem(item.id);
      },
      onTapCancel: () {
        _finishPressingBrowserItem(item.id);
      },
      onTap: () {
        _handleSelectNote(note, isWideLayout: isWideLayout);
      },
      onLongPressStart: (LongPressStartDetails details) {
        _startDraggingBrowserItem(item, details.globalPosition);
      },
      onLongPressMoveUpdate: (LongPressMoveUpdateDetails details) {
        _updateDraggingBrowserItem(details.globalPosition);
      },
      onLongPressEnd: (_) {
        _finishDraggingBrowserItem();
      },
      onLongPressCancel: () {
        _finishDraggingBrowserItem(performDrop: false);
      },
      child: Container(
        // 笔记列表行容器样式
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: Color(0x0A000000),
              blurRadius: 14,
              offset: Offset(0, 6),
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
        child: Stack(
          children: <Widget>[
            SizedBox(
              width: double.infinity,
              child: Column(
                // 笔记列表文字纵向布局样式
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    note.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    // 笔记列表标题样式
                    style: const TextStyle(
                      color: Color(0xFF111111),
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    note.preview,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    // 笔记列表摘要样式
                    style: const TextStyle(
                      color: Color(0xFF666666),
                      fontSize: 15,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _formatNoteCardDate(note.updatedAt),
                    // 笔记列表日期样式
                    style: const TextStyle(
                      color: Color(0xFF9B9B9B),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            if (_isSelectionMode)
              Positioned(
                right: 0,
                bottom: 0,
                child: _buildSelectionCircle(isSelected),
              ),
          ],
        ),
      ),
    );
  }

  /*
   * 构建首页列表视图。
   */
  Widget _buildBrowserListView({
    required List<NoteGridItem> items,
    required bool isWideLayout,
  }) {
    return ListView.separated(
      padding: EdgeInsets.fromLTRB(0, 18, 0, 108),
      itemCount: items.length,
      separatorBuilder: (BuildContext context, int index) {
        return const SizedBox(height: 12);
      },
      itemBuilder: (BuildContext context, int index) {
        final NoteGridItem item = items[index];

        if (item.type == NoteGridItemType.folder) {
          return _buildBrowserItemShell(
            item: item,
            borderRadius: 18,
            child: _buildFolderListRow(item),
          );
        }

        return _buildBrowserItemShell(
          item: item,
          borderRadius: 18,
          child: _buildNoteListRow(item, isWideLayout: isWideLayout),
        );
      },
    );
  }

  /*
   * 构建首页浏览视图。
   */
  Widget _buildBrowserPanel({required bool isWideLayout}) {
    final List<NoteGridItem> gridItems = _buildGridItems();

    return Expanded(
      child: gridItems.isEmpty
          ? const Center(
              child: Text(
                '当前目录还没有内容',
                // 空目录提示样式
                style: TextStyle(color: Color(0xFF888888), fontSize: 16),
              ),
            )
          : _activeViewMode == NoteViewMode.list
          ? _buildBrowserListView(items: gridItems, isWideLayout: isWideLayout)
          : LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final double itemWidth = _getBrowserItemWidth(
                  availableWidth: constraints.maxWidth,
                  isWideLayout: isWideLayout,
                );
                final List<List<NoteGridItem>> columns = _buildBrowserColumns(
                  items: gridItems,
                  itemWidth: itemWidth,
                  isWideLayout: isWideLayout,
                );

                return SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(0, 18, 0, 108),
                  child: Row(
                    // 首页瀑布流横向分列布局样式
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      for (
                        int columnIndex = 0;
                        columnIndex < columns.length;
                        columnIndex += 1
                      ) ...<Widget>[
                        SizedBox(
                          width: itemWidth,
                          child: Column(
                            // 首页瀑布流纵向贴合布局样式
                            children: <Widget>[
                              for (
                                int itemIndex = 0;
                                itemIndex < columns[columnIndex].length;
                                itemIndex += 1
                              ) ...<Widget>[
                                if (itemIndex > 0) const SizedBox(height: 14),
                                _buildBrowserItemShell(
                                  item: columns[columnIndex][itemIndex],
                                  child:
                                      columns[columnIndex][itemIndex].type ==
                                          NoteGridItemType.folder
                                      ? _buildFolderCard(
                                          columns[columnIndex][itemIndex],
                                        )
                                      : _buildNoteCard(
                                          columns[columnIndex][itemIndex],
                                          isWideLayout: isWideLayout,
                                        ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        if (columnIndex < columns.length - 1)
                          const SizedBox(width: 8),
                      ],
                    ],
                  ),
                );
              },
            ),
    );
  }

  /*
   * 构建移动面板选项卡片。
   */
  Widget _buildMoveTargetCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        // 移动目标卡片容器样式
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: Color(0x0D000000),
              blurRadius: 18,
              offset: Offset(0, 8),
            ),
          ],
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          // 移动目标卡片内容纵向布局样式
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(icon, color: const Color(0xFFFFC000), size: 48),
            const Spacer(),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              // 移动目标标题样式
              style: const TextStyle(
                color: Color(0xFF111111),
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (subtitle.isNotEmpty) ...<Widget>[
              const SizedBox(height: 6),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                // 移动目标辅助文字样式
                style: const TextStyle(color: Color(0xFF8C8C8C), fontSize: 14),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /*
   * 构建移动目标文件夹面板。
   */
  Widget _buildMoveSheet(BuildContext sheetContext) {
    final List<String> targetFolders = _folderPaths
        .where(_canUseMoveTarget)
        .toList();
    final List<Widget> targetCards = <Widget>[
      _buildMoveTargetCard(
        icon: Icons.create_new_folder_rounded,
        title: '新建文件夹',
        subtitle: '',
        onTap: () async {
          Navigator.of(sheetContext).pop();
          await _handleCreateFolder(moveSelectedAfterCreate: true);
        },
      ),
      if (_canMoveSelectedItemsOut())
        _buildMoveTargetCard(
          icon: Icons.folder_rounded,
          title: '移出文件夹',
          subtitle: '移动到全部笔记根目录',
          onTap: () async {
            Navigator.of(sheetContext).pop();
            await _moveSelectedItemsToDirectory('');
          },
        ),
      ...targetFolders.map(
        (String folderPath) => _buildMoveTargetCard(
          icon: Icons.folder_rounded,
          title: folderPath.split('/').last,
          subtitle: '${_getFolderNoteCount(folderPath)}',
          onTap: () async {
            Navigator.of(sheetContext).pop();
            await _moveSelectedItemsToDirectory(folderPath);
          },
        ),
      ),
    ];

    return DraggableScrollableSheet(
      initialChildSize: 0.48,
      minChildSize: 0.32,
      maxChildSize: 0.82,
      builder: (BuildContext context, ScrollController scrollController) {
        return Container(
          // 移动面板容器样式
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(28),
              topRight: Radius.circular(28),
            ),
          ),
          child: Column(
            children: <Widget>[
              const SizedBox(height: 24),
              const Text(
                '选择文件夹',
                // 移动面板标题样式
                style: TextStyle(
                  color: Color(0xFF111111),
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 22),
              Expanded(
                child: GridView.count(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(28, 0, 28, 28),
                  crossAxisCount: 2,
                  crossAxisSpacing: 18,
                  mainAxisSpacing: 18,
                  childAspectRatio: 0.86,
                  children: targetCards,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /*
   * 构建选择模式底部操作栏。
   */
  Widget _buildSelectionActionBar() {
    if (!_isSelectionMode) {
      return const SizedBox.shrink();
    }

    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        // 选择模式底部操作栏样式
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(28, 14, 28, 24),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: <Widget>[
            _buildActionItem(Icons.lock_outline_rounded, '设为私密', () {
              _showMessageDialog('暂未实现', '私密笔记后面再接。');
            }),
            _buildActionItem(Icons.vertical_align_top_rounded, '置顶', () {
              _showMessageDialog('暂未实现', '置顶排序后面再接。');
            }),
            _buildActionItem(Icons.delete_outline_rounded, '删除', () {
              _deleteSelectedItems();
            }),
            _buildActionItem(Icons.folder_rounded, '移动到', () {
              _showMoveSheet();
            }),
          ],
        ),
      ),
    );
  }

  /*
   * 构建底部操作项。
   */
  Widget _buildActionItem(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        // 底部操作项纵向布局样式
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, color: const Color(0xFF111111), size: 30),
          const SizedBox(height: 6),
          Text(
            label,
            // 底部操作项文字样式
            style: const TextStyle(color: Color(0xFF333333), fontSize: 14),
          ),
        ],
      ),
    );
  }

  /*
   * 构建编辑面板。
   */
  Widget _buildEditorPanel() {
    if (_activeNote == null) {
      return const Center(
        child: Text(
          '还没有笔记',
          // 空编辑区文字样式
          style: TextStyle(color: Color(0xFF555555), fontSize: 18),
        ),
      );
    }

    return Container(
      // 编辑面板容器样式
      color: const Color(0xFFF6F6F6),
      child: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 18, 22, 12),
            child: Row(
              children: <Widget>[
                IconButton(
                  onPressed: () {
                    setState(() {
                      _isCompactBrowserVisible = true;
                    });
                  },
                  icon: const Icon(Icons.arrow_back_rounded),
                  color: const Color(0xFF222222),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        _activeNote!.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        // 编辑面板标题样式
                        style: const TextStyle(
                          color: Color(0xFF111111),
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_activeNote!.displayPath} · ${formatNoteTime(_activeNote!.updatedAt)} · $_saveStatusText',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        // 编辑面板辅助信息样式
                        style: const TextStyle(
                          color: Color(0xFF8C8C8C),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () {
                    final double width = MediaQuery.of(context).size.width;
                    _handleDeleteNote(isWideLayout: width >= 980);
                  },
                  icon: const Icon(Icons.delete_outline_rounded),
                  color: const Color(0xFF222222),
                ),
              ],
            ),
          ),
          MarkdownToolbar(onPressedAction: _handleToolbarAction),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 18, 22, 22),
              child: TextField(
                controller: _editorController,
                focusNode: _editorFocusNode,
                expands: true,
                maxLines: null,
                minLines: null,
                textAlignVertical: TextAlignVertical.top,
                keyboardType: TextInputType.multiline,
                decoration: const InputDecoration(
                  // 编辑器输入框装饰样式
                  hintText: '在这里输入 Markdown 笔记内容',
                  hintStyle: TextStyle(color: Color(0xFFAAAAAA)),
                  border: InputBorder.none,
                  isCollapsed: true,
                ),
                style: const TextStyle(
                  // 编辑器输入文字样式
                  color: Color(0xFF222222),
                  fontSize: 17,
                  height: 1.6,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /*
   * 构建首页浏览内容。
   */
  Widget _buildHomePanel({required bool isWideLayout}) {
    return Stack(
      key: _homePanelKey,
      children: <Widget>[
        Column(
          // 首页内容纵向布局样式，顶部栏和下方内容分开控制边距。
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _buildNormalTopBar(isWideLayout: isWideLayout),
            Expanded(
              child: Padding(
                // 首页下方根容器左右边距样式，只控制分类栏、路径栏和卡片列表。
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Column(
                  // 首页下方内容纵向布局样式
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    _buildSearchBar(),
                    _buildSummaryBar(),
                    _buildCategoryBar(),
                    _buildPathBar(),
                    _buildBrowserPanel(isWideLayout: isWideLayout),
                  ],
                ),
              ),
            ),
          ],
        ),
        _buildDraggingBrowserPreview(),
        _buildSelectionActionBar(),
      ],
    );
  }

  /*
   * 构建页面主体内容。
   */
  Widget _buildBody() {
    final double width = MediaQuery.of(context).size.width;
    final bool isWideLayout = width >= 980;

    if (isWideLayout && !_isCompactBrowserVisible) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _isCompactBrowserVisible = true;
          });
        }
      });
    }

    if (isWideLayout) {
      return Row(
        // 宽屏双栏布局样式
        children: <Widget>[
          Expanded(
            flex: 12,
            child: _buildHomePanel(isWideLayout: isWideLayout),
          ),
          Container(width: 1, color: const Color(0xFFE7E7E7)),
          Expanded(flex: 10, child: _buildEditorPanel()),
        ],
      );
    }

    return _isCompactBrowserVisible
        ? _buildHomePanel(isWideLayout: isWideLayout)
        : _buildEditorPanel();
  }

  /*
   * 构建主页组件。
   */
  @override
  Widget build(BuildContext context) {
    final bool isWideLayout = MediaQuery.of(context).size.width >= 980;

    return PopScope<void>(
      canPop: !_canHandleSystemBack(isWideLayout: isWideLayout),
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (didPop) {
          return;
        }

        _handleSystemBack(isWideLayout: isWideLayout);
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF0F1F3),
        body: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xFFFFC000)),
              )
            : SafeArea(child: _buildBody()),
        floatingActionButton: _isSelectionMode
            ? null
            : FloatingActionButton(
                onPressed: () {
                  final double width = MediaQuery.of(context).size.width;
                  _handleCreateNote(isWideLayout: width >= 980);
                },
                backgroundColor: const Color(0xFFFFC000),
                foregroundColor: Colors.white,
                shape: const CircleBorder(),
                child: const Icon(Icons.add, size: 34),
              ),
      ),
    );
  }
}
