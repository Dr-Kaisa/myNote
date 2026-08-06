/*
 * 文件说明：笔记主页组件文件，负责组织笔记包首页、文件夹视图、选择模式、移动面板与编辑区交互。
 *
 * 这个文件是应用里最主要的页面文件。
 * 不熟 Flutter 时可以先按这个顺序理解：
 * 1. 上半部分是数据结构和状态字段，例如当前有哪些笔记包、当前进了哪个文件夹。
 * 2. 中间部分是事件处理方法，例如点击文件夹、创建笔记、删除笔记。
 * 3. 下半部分是 _build 开头的方法，它们负责把状态渲染成界面。
 *
 * Flutter 里的 Widget 可以理解成界面积木。
 * Row 是横向排列，Column 是纵向排列，Container 是带样式的盒子，
 * Padding 是外边距，Expanded 是把剩余空间分给某个子组件。
 */
import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:my_note/controllers/markdown_editor_controller.dart';
import 'package:my_note/models/note_item.dart';
import 'package:my_note/services/app_cache_service.dart';
import 'package:my_note/services/note_share_service.dart';
import 'package:my_note/services/note_storage_service.dart';
import 'package:my_note/theme/app_theme.dart';
import 'package:my_note/utils/markdown_helper.dart';
import 'package:my_note/widgets/markdown_toolbar.dart';
import 'package:my_note/widgets/wysiwyg_markdown_editor.dart';

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
 * 首页下面的瀑布流里有两种卡片：普通文件夹卡片和笔记包卡片。
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
 * 编辑页右上角操作菜单类型。
 */
enum EditorActionMenuType { more, share }

/*
 * 编辑器分享内容渲染模式。
 */
enum EditorShareRenderMode { none, image, pdf }

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
   * type 决定最终调用普通文件夹卡片还是笔记包卡片构建方法。
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
   * 只有笔记包卡片会有入口文档；普通文件夹卡片这里是 null。
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
  const NoteHomePage({
    required this.isDarkMode,
    required this.onThemeModeChanged,
    super.key,
  });

  /*
   * 当前是否启用暗色模式。
   */
  final bool isDarkMode;

  /*
   * 主题模式切换回调。
   */
  final ValueChanged<bool> onThemeModeChanged;

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
    final ColorScheme colors = Theme.of(context).colorScheme;

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
            color: colors.onSurface,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '设置',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              // 设置页标题文字样式
              style: TextStyle(
                color: colors.onSurface,
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
  Widget _buildEmptyContent(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;

    return Expanded(
      child: Center(
        child: Padding(
          // 设置页空状态外边距样式
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            // 设置页空状态纵向布局样式
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                Icons.settings_rounded,
                // 设置页空状态图标样式
                color: colors.primary,
                size: 58,
              ),
              const SizedBox(height: 14),
              Text(
                '设置',
                textAlign: TextAlign.center,
                // 设置页空状态标题样式
                style: TextStyle(
                  color: colors.onSurface,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '后续设置项会放在这里',
                textAlign: TextAlign.center,
                // 设置页空状态说明样式
                style: TextStyle(
                  color: colors.onSurfaceVariant,
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
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: Column(
          // 设置页根内容纵向布局样式
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _buildHeader(context),
            _buildEmptyContent(context),
          ],
        ),
      ),
    );
  }
}

/*
 * 笔记主页状态对象。
 */
class _NoteHomePageState extends State<NoteHomePage>
    with WidgetsBindingObserver {
  /*
   * 获取当前主题语义颜色。
   */
  ColorScheme get _colors => Theme.of(context).colorScheme;

  /*
   * 按压、拖拽和命中目标时统一使用的卡片缩放比例。
   */
  static const double _dragCardScale = 0.90;

  /*
   * 笔记包文档抽屉侧边入口高度。
   */
  static const double _packageDrawerRailHeight = 48;

  /*
   * 笔记存储服务实例。
   */
  final NoteStorageService _noteStorageService = NoteStorageService();

  /*
   * 笔记系统分享服务实例。
   */
  final NoteShareService _noteShareService = NoteShareService();

  /*
   * 应用缓存服务实例。
   */
  final AppCacheService _appCacheService = AppCacheService();

  /*
   * 编辑器控制器。
   */
  final MarkdownEditorController _editorController = MarkdownEditorController();

  /*
   * 编辑器焦点控制器。
   */
  final FocusNode _editorFocusNode = FocusNode();

  /*
   * 编辑器滚动控制器。
   */
  final ScrollController _editorScrollController = ScrollController();

  /*
   * 更多菜单按钮定位标识。
   */
  final GlobalKey _moreMenuButtonKey = GlobalKey();

  /*
   * 编辑页分享菜单按钮定位标识。
   */
  final GlobalKey _editorShareButtonKey = GlobalKey();

  /*
   * 编辑页更多菜单按钮定位标识。
   */
  final GlobalKey _editorMoreMenuButtonKey = GlobalKey();

  /*
   * 编辑器分页分享截图定位标识。
   */
  final GlobalKey _editorShareCaptureKey = GlobalKey();

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
   * 当前编辑页操作菜单浮层。
   */
  OverlayEntry? _editorActionMenuOverlayEntry;

  /*
   * 更多菜单是否正在执行关闭动画。
   */
  bool _isMoreMenuClosing = false;

  /*
   * 编辑页操作菜单是否正在执行关闭动画。
   */
  bool _isEditorActionMenuClosing = false;

  /*
   * 当前全部笔记包入口文档列表。
   *
   * 每一项代表一个笔记包，不会包含包内其余 Markdown 文档。
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
   * 当前笔记包内的全部 Markdown 文档。
   */
  List<NoteItem> _activePackageNotes = <NoteItem>[];

  /*
   * 包内文档切换抽屉是否展开。
   */
  bool _isPackageDrawerOpen = false;

  /*
   * 笔记包文档抽屉侧边入口的归一化垂直位置。
   */
  final ValueNotifier<double> _packageDrawerRailPosition =
      ValueNotifier<double>(0.5);

  /*
   * 包内文档切换抽屉是否正在重新读取文件。
   */
  bool _isPackageDrawerLoading = false;

  /*
   * 按 Markdown 相对路径记录编辑器滚动位置。
   */
  final Map<String, double> _documentScrollOffsets = <String, double>{};

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
   * 当前笔记详情页已经应用的工具栏动作顺序。
   */
  List<ToolbarActionKey> _toolbarActionKeys = List<ToolbarActionKey>.from(
    defaultToolbarActionKeys,
  );

  /*
   * 工具栏自定义模式控制器，用于返回键优先关闭工具仓库。
   */
  final MarkdownToolbarCustomizationController _toolbarCustomizationController =
      MarkdownToolbarCustomizationController();

  /*
   * 笔记详情页工具仓库是否正在覆盖正文区域。
   */
  bool _isToolbarCustomizing = false;

  /*
   * 是否处于数据加载中。
   */
  bool _isLoading = true;

  /*
   * 是否正在生成或提交系统分享内容。
   */
  bool _isShareOperationInProgress = false;

  /*
   * 当前编辑器分享内容渲染模式。
   */
  EditorShareRenderMode _editorShareRenderMode = EditorShareRenderMode.none;

  /*
   * 延迟保存定时器。
   */
  Timer? _saveTimer;

  /*
   * 当前串行保存任务。
   *
   * 后一次保存会等待前一次完成，避免标题重命名时并发写出重复文件。
   */
  Future<bool> _saveQueue = Future<bool>.value(true);

  /*
   * 保存后发生重命名的笔记路径映射。
   *
   * 队列里的后续保存可以通过旧路径找到上一轮保存生成的新路径。
   */
  final Map<String, NoteItem> _latestSavedNotes = <String, NoteItem>{};

  /*
   * 页面初始化逻辑。
   */
  @override
  void initState() {
    super.initState();
    // 注册应用生命周期监听，在应用切到后台前尽快保存当前编辑内容。
    WidgetsBinding.instance.addObserver(this);
    _initializeNotes();
    _editorController.addListener(_handleEditorTextChanged);
  }

  /*
   * 应用离开前台时立即提交尚未触发的延迟保存。
   */
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      unawaited(_flushPendingEditorSave().then<void>((_) {}));
    }
  }

  /*
   * 页面销毁前释放控制器资源。
   */
  @override
  void dispose() {
    _saveTimer?.cancel();
    if (_activeNote != null &&
        _editorController.markdownText != _activeNote!.content) {
      // 页面销毁时再提交一次当前快照，尽量避免最后 500 毫秒的输入丢失。
      unawaited(
        _queueNoteSave(
          _activeNote!,
          _editorController.markdownText,
        ).then<void>((_) {}),
      );
    }
    WidgetsBinding.instance.removeObserver(this);
    _hideMoreMenu(animate: false);
    _hideEditorActionMenu(animate: false);
    _editorController.removeListener(_handleEditorTextChanged);
    _editorController.dispose();
    _editorFocusNode.dispose();
    _editorScrollController.dispose();
    _packageDrawerRailPosition.dispose();
    super.dispose();
  }

  /*
   * 读取指定笔记包内的全部 Markdown 文档。
   */
  Future<List<NoteItem>> _loadPackageNotes(NoteItem note) async {
    return _noteStorageService.loadPackageNotes(note.packageRelativePath);
  }

  /*
   * 从笔记包文档列表中查找指定相对路径的文档。
   */
  NoteItem? _findPackageNoteByRelativePath(
    List<NoteItem> notes,
    String relativePath,
  ) {
    for (final NoteItem note in notes) {
      if (note.relativePath == relativePath) {
        return note;
      }
    }

    return null;
  }

  /*
   * 记录当前激活文档的编辑滚动位置。
   */
  void _rememberActiveDocumentScrollOffset() {
    if (_activeNote == null || !_editorScrollController.hasClients) {
      return;
    }

    _documentScrollOffsets[_activeNote!.relativePath] =
        _editorScrollController.offset;
  }

  /*
   * 在新文档加载完成后恢复它上一次离开时的滚动位置。
   */
  void _restoreDocumentScrollOffset(NoteItem note) {
    final double targetOffset = _documentScrollOffsets[note.relativePath] ?? 0;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_editorScrollController.hasClients) {
        return;
      }

      final ScrollPosition position = _editorScrollController.position;
      _editorScrollController.jumpTo(
        targetOffset
            .clamp(position.minScrollExtent, position.maxScrollExtent)
            .toDouble(),
      );
    });
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
      final NoteItem? initialEntryNote = notes.isNotEmpty ? notes.first : null;
      final List<NoteItem> initialPackageNotes = initialEntryNote == null
          ? <NoteItem>[]
          : await _loadPackageNotes(initialEntryNote);
      final NoteItem? initialActiveNote = initialEntryNote == null
          ? null
          : _findPackageNoteByRelativePath(
                  initialPackageNotes,
                  initialEntryNote.relativePath,
                ) ??
                initialEntryNote;

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
        _packageDrawerRailPosition.value = appCache.packageDrawerRailPosition;
        _toolbarActionKeys = toolbarActionKeysFromNames(
          appCache.toolbarActionKeys,
        );
        _categoryFolderPaths = _buildCategoryFolderPaths(folderPaths);
        _activeNote = initialActiveNote;
        _activePackageNotes = initialPackageNotes;
        _activeDirectoryPath = '';
        _editorController.loadMarkdown(initialActiveNote?.content ?? '');
        _isLoading = false;
      });
      if (initialActiveNote != null) {
        _restoreDocumentScrollOffset(initialActiveNote);
      }
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
      });

      _showMessageDialog('加载失败', error.toString());
    }
  }

  /*
   * 重新读取笔记与文件夹列表。
   */
  Future<void> _reloadNotes({
    bool keepDirectory = true,
    bool flushEditor = true,
  }) async {
    if (flushEditor && !await _flushPendingEditorSave()) {
      return;
    }

    final List<NoteItem> notes = await _noteStorageService.loadNotes();
    final List<String> folderPaths = await _noteStorageService
        .loadFolderPaths();

    if (!mounted) {
      return;
    }

    final NoteItem? previousActiveNote = _activeNote;
    NoteItem? nextEntryNote;
    if (previousActiveNote != null) {
      for (final NoteItem note in notes) {
        if (note.packageRelativePath ==
            previousActiveNote.packageRelativePath) {
          nextEntryNote = note;
          break;
        }
      }
    }
    nextEntryNote ??= notes.isNotEmpty ? notes.first : null;
    final List<NoteItem> nextPackageNotes = nextEntryNote == null
        ? <NoteItem>[]
        : await _loadPackageNotes(nextEntryNote);
    final NoteItem? nextActiveNote = previousActiveNote == null
        ? nextEntryNote
        : _findPackageNoteByRelativePath(
                nextPackageNotes,
                previousActiveNote.relativePath,
              ) ??
              nextEntryNote;

    if (!mounted) {
      return;
    }

    setState(() {
      _notes = notes;
      _folderPaths = folderPaths;
      _latestSavedNotes.clear();
      _activeNote = nextActiveNote;
      _activePackageNotes = nextPackageNotes;
      if (previousActiveNote?.packageRelativePath !=
          nextActiveNote?.packageRelativePath) {
        _isPackageDrawerOpen = false;
      }
      if (!keepDirectory) {
        _activeDirectoryPath = '';
      }
      if (nextActiveNote != null) {
        _editorController.loadMarkdown(nextActiveNote.content);
      } else {
        _editorController.loadMarkdown('');
      }
    });
    if (nextActiveNote != null) {
      _restoreDocumentScrollOffset(nextActiveNote);
    }
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
                color: _colors.scrim.withValues(alpha: 0.2),
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
      color: _colors.surfaceContainerLowest,
      elevation: 18,
      shadowColor: _colors.shadow.withValues(alpha: 0.2),
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
          Divider(height: 1, color: _colors.outlineVariant),
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
                    color: isSelected ? _colors.tertiary : _colors.onSurface,
                    fontSize: 16,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
              if (isSelected)
                Icon(
                  Icons.check_rounded,
                  // 更多菜单选中图标颜色样式
                  color: _colors.tertiary,
                  size: 22,
                ),
            ],
          ),
        ),
      ),
    );
  }

  /*
   * 隐藏编辑页右上角操作菜单。
   */
  void _hideEditorActionMenu({bool animate = true, VoidCallback? onHidden}) {
    final OverlayEntry? overlayEntry = _editorActionMenuOverlayEntry;
    if (overlayEntry == null) {
      onHidden?.call();
      return;
    }
    if (!animate) {
      overlayEntry.remove();
      _editorActionMenuOverlayEntry = null;
      _isEditorActionMenuClosing = false;
      onHidden?.call();
      return;
    }
    if (_isEditorActionMenuClosing) {
      return;
    }

    _isEditorActionMenuClosing = true;
    overlayEntry.markNeedsBuild();
    Future<void>.delayed(const Duration(milliseconds: 160), () {
      if (_editorActionMenuOverlayEntry != overlayEntry) {
        return;
      }
      overlayEntry.remove();
      _editorActionMenuOverlayEntry = null;
      _isEditorActionMenuClosing = false;
      onHidden?.call();
    });
  }

  /*
   * 展示编辑页右上角操作菜单。
   */
  void _showEditorActionMenu(EditorActionMenuType menuType) {
    if (_editorActionMenuOverlayEntry != null) {
      _hideEditorActionMenu();
      return;
    }

    final GlobalKey buttonKey = menuType == EditorActionMenuType.share
        ? _editorShareButtonKey
        : _editorMoreMenuButtonKey;
    final BuildContext? buttonContext = buttonKey.currentContext;
    if (buttonContext == null) {
      return;
    }

    final RenderBox buttonBox = buttonContext.findRenderObject() as RenderBox;
    final Offset buttonOffset = buttonBox.localToGlobal(Offset.zero);
    final Size screenSize = MediaQuery.of(context).size;
    final double requestedWidth = menuType == EditorActionMenuType.share
        ? 268
        : 224;
    final double menuHeight = menuType == EditorActionMenuType.share
        ? 52 * 4
        : 52 * 4 + 1;
    final double menuWidth = screenSize.width < requestedWidth + 24
        ? screenSize.width - 24
        : requestedWidth;
    final double menuLeft = (buttonOffset.dx + buttonBox.size.width - menuWidth)
        .clamp(12.0, screenSize.width - menuWidth - 12.0)
        .toDouble();
    final double maximumMenuTop = screenSize.height > menuHeight + 24
        ? screenSize.height - menuHeight - 12
        : 12;
    final double menuTop = (buttonOffset.dy + buttonBox.size.height + 4)
        .clamp(12.0, maximumMenuTop)
        .toDouble();

    _isEditorActionMenuClosing = false;
    _editorActionMenuOverlayEntry = OverlayEntry(
      builder: (BuildContext overlayContext) {
        return _buildEditorActionMenuOverlay(
          left: menuLeft,
          top: menuTop,
          width: menuWidth,
          menuType: menuType,
        );
      },
    );
    Overlay.of(context).insert(_editorActionMenuOverlayEntry!);
  }

  /*
   * 处理编辑页操作菜单选项点击。
   */
  void _handleEditorActionMenuSelected(String value) {
    _hideEditorActionMenu(
      onHidden: () {
        if (value == 'settings') {
          _openSettingsPage();
        } else if (value == 'move') {
          unawaited(_showActivePackageMoveSheet());
        } else if (value == 'delete') {
          unawaited(_handleDeleteCurrentDocument());
        } else if (value == 'deleteAll') {
          unawaited(_handleDeleteCurrentPackage());
        } else if (value == 'shareText') {
          unawaited(
            _shareActiveNote(
              (NoteItem note, Rect? origin) =>
                  _noteShareService.shareMarkdownText(note, origin),
            ),
          );
        } else if (value == 'shareFiles') {
          unawaited(
            _shareActiveNote(
              (NoteItem note, Rect? origin) =>
                  _noteShareService.sharePackageFiles(note, origin),
            ),
          );
        } else if (value == 'shareImage') {
          unawaited(
            _shareActiveNote(
              (NoteItem note, Rect? origin) => _noteShareService.shareAsImages(
                note,
                (onPage) => _captureActiveEditorPages(
                  onPage,
                  renderMode: EditorShareRenderMode.image,
                ),
                origin,
              ),
            ),
          );
        } else if (value == 'sharePdf') {
          unawaited(
            _shareActiveNote(
              (NoteItem note, Rect? origin) => _noteShareService.shareAsPdf(
                note,
                (onPage) => _captureActiveEditorPages(
                  onPage,
                  renderMode: EditorShareRenderMode.pdf,
                ),
                origin,
              ),
            ),
          );
        }
      },
    );
  }

  /*
   * 构建编辑页操作菜单浮层。
   */
  Widget _buildEditorActionMenuOverlay({
    required double left,
    required double top,
    required double width,
    required EditorActionMenuType menuType,
  }) {
    return Stack(
      children: <Widget>[
        Positioned.fill(
          child: Listener(
            behavior: HitTestBehavior.translucent,
            onPointerUp: (_) {
              _hideEditorActionMenu();
            },
            onPointerCancel: (_) {
              _hideEditorActionMenu();
            },
            child: TweenAnimationBuilder<double>(
              duration: Duration(
                milliseconds: _isEditorActionMenuClosing ? 160 : 180,
              ),
              curve: _isEditorActionMenuClosing
                  ? Curves.easeInCubic
                  : Curves.easeOutCubic,
              tween: Tween<double>(
                begin: _isEditorActionMenuClosing ? 1 : 0,
                end: _isEditorActionMenuClosing ? 0 : 1,
              ),
              builder: (BuildContext context, double value, Widget? child) {
                return Opacity(opacity: value, child: child);
              },
              child: Container(
                // 编辑页操作菜单外部遮罩背景样式
                color: _colors.scrim.withValues(alpha: 0.2),
              ),
            ),
          ),
        ),
        Positioned(
          left: left,
          top: top,
          width: width,
          child: TweenAnimationBuilder<double>(
            duration: Duration(
              milliseconds: _isEditorActionMenuClosing ? 160 : 180,
            ),
            curve: _isEditorActionMenuClosing
                ? Curves.easeInCubic
                : Curves.easeOutCubic,
            tween: Tween<double>(
              begin: _isEditorActionMenuClosing ? 1 : 0.72,
              end: _isEditorActionMenuClosing ? 0.72 : 1,
            ),
            child: _buildEditorActionMenuPanel(menuType),
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
   * 构建编辑页操作菜单面板。
   */
  Widget _buildEditorActionMenuPanel(EditorActionMenuType menuType) {
    final List<Widget> menuItems = menuType == EditorActionMenuType.more
        ? <Widget>[
            _buildEditorActionMenuItem(label: '设置', value: 'settings'),
            Divider(height: 1, color: _colors.outlineVariant),
            _buildEditorActionMenuItem(label: '移动', value: 'move'),
            _buildEditorActionMenuItem(
              label: '删除',
              value: 'delete',
              isDestructive: true,
            ),
            _buildEditorActionMenuItem(
              label: '删除全部',
              value: 'deleteAll',
              isDestructive: true,
            ),
          ]
        : <Widget>[
            _buildEditorActionMenuItem(label: '以文本形式分享', value: 'shareText'),
            _buildEditorActionMenuItem(
              label: '以文件形式分享（含引用）',
              value: 'shareFiles',
            ),
            _buildEditorActionMenuItem(label: '以图片分享', value: 'shareImage'),
            _buildEditorActionMenuItem(label: '以 PDF 分享', value: 'sharePdf'),
          ];

    return Material(
      // 编辑页操作菜单面板材质样式
      color: _colors.surfaceContainerLowest,
      elevation: 18,
      shadowColor: _colors.shadow.withValues(alpha: 0.2),
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: Column(
        // 编辑页操作菜单选项纵向布局样式
        mainAxisSize: MainAxisSize.min,
        children: menuItems,
      ),
    );
  }

  /*
   * 构建编辑页操作菜单单个选项。
   */
  Widget _buildEditorActionMenuItem({
    required String label,
    required String value,
    bool isDestructive = false,
  }) {
    return InkWell(
      onTap: () {
        _handleEditorActionMenuSelected(value);
      },
      child: SizedBox(
        height: 52,
        child: Padding(
          // 编辑页操作菜单选项内容边距样式
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              // 编辑页操作菜单选项文字样式
              style: TextStyle(
                color: isDestructive ? _colors.error : _colors.onSurface,
                fontSize: 16,
                fontWeight: isDestructive ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
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
      const NoteCategoryItem(id: 'all', label: '全部笔记包', isAllNotes: true),
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
      return '全部笔记包';
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
      await _appCacheService.updateCache(
        (AppCacheData appCache) => AppCacheData(
          folderVisitCounts: Map<String, int>.from(_folderVisitCounts),
          sortMode: _activeSortMode.name,
          viewMode: _activeViewMode.name,
          isDarkMode: appCache.isDarkMode,
          packageDrawerRailPosition: _packageDrawerRailPosition.value,
          toolbarActionKeys: toolbarActionKeyNames(_toolbarActionKeys),
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
   * 获取分享按钮在全局坐标中的矩形区域。
   */
  Rect? _getEditorShareOrigin() {
    final BuildContext? buttonContext = _editorShareButtonKey.currentContext;
    final RenderObject? renderObject = buttonContext?.findRenderObject();
    if (renderObject is! RenderBox) {
      return null;
    }

    return renderObject.localToGlobal(Offset.zero) & renderObject.size;
  }

  /*
   * 将编辑器单次可见区域整理为固定尺寸的 PNG 分页。
   */
  Future<Uint8List> _encodeEditorCapturePage({
    required ui.Image capturedImage,
    required double sourceTop,
    required double visibleHeight,
    required Color backgroundColor,
  }) async {
    final double boundedSourceTop = sourceTop
        .clamp(0.0, capturedImage.height - 1.0)
        .toDouble();
    final double boundedVisibleHeight = visibleHeight
        .clamp(1.0, capturedImage.height - boundedSourceTop)
        .toDouble();
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final ui.Canvas canvas = ui.Canvas(recorder);

    // 分享截图页面背景样式
    canvas.drawColor(backgroundColor, ui.BlendMode.src);
    canvas.drawImageRect(
      capturedImage,
      ui.Rect.fromLTWH(
        0,
        boundedSourceTop,
        capturedImage.width.toDouble(),
        boundedVisibleHeight,
      ),
      ui.Rect.fromLTWH(
        0,
        0,
        capturedImage.width.toDouble(),
        boundedVisibleHeight,
      ),
      ui.Paint(),
    );

    final ui.Picture picture = recorder.endRecording();
    final ui.Image pageImage = await picture.toImage(
      capturedImage.width,
      capturedImage.height,
    );
    picture.dispose();

    try {
      final ByteData? imageData = await pageImage.toByteData(
        format: ui.ImageByteFormat.png,
      );
      if (imageData == null) {
        throw Exception('分享图片生成失败');
      }
      return imageData.buffer.asUint8List(
        imageData.offsetInBytes,
        imageData.lengthInBytes,
      );
    } finally {
      pageImage.dispose();
    }
  }

  /*
   * 更新分享截图使用的临时选区，同时阻止 Quill 重新请求焦点或滚动光标。
   */
  void _updateEditorSelectionForShare(TextSelection selection) {
    final QuillController controller = _editorController.quillController;
    final bool previousIgnoreFocus = controller.ignoreFocusOnTextChange;
    controller.ignoreFocusOnTextChange = true;
    try {
      controller.updateSelection(selection, ChangeSource.local);
    } finally {
      controller.ignoreFocusOnTextChange = previousIgnoreFocus;
    }
    if (mounted) {
      setState(() {
        // 让编辑器使用临时选区重新绘制，截图中不保留用户选择高亮。
      });
    }
  }

  /*
   * 等待键盘退场后的编辑器尺寸连续两帧保持稳定。
   */
  Future<void> _waitForStableEditorShareLayout() async {
    Size? previousBoundarySize;
    double? previousViewportHeight;
    double? previousMaximumOffset;
    int stableFrameCount = 0;

    for (int frameIndex = 0; frameIndex < 30; frameIndex++) {
      await WidgetsBinding.instance.endOfFrame;
      final RenderObject? renderObject = _editorShareCaptureKey.currentContext
          ?.findRenderObject();
      if (renderObject is! RenderRepaintBoundary ||
          !_editorScrollController.hasClients ||
          !_editorScrollController.position.hasContentDimensions) {
        stableFrameCount = 0;
        continue;
      }

      final Size boundarySize = renderObject.size;
      final ScrollPosition position = _editorScrollController.position;
      final bool isStable =
          previousBoundarySize != null &&
          (previousBoundarySize.width - boundarySize.width).abs() < 0.5 &&
          (previousBoundarySize.height - boundarySize.height).abs() < 0.5 &&
          (previousViewportHeight! - position.viewportDimension).abs() < 0.5 &&
          (previousMaximumOffset! - position.maxScrollExtent).abs() < 0.5;
      stableFrameCount = isStable ? stableFrameCount + 1 : 0;
      previousBoundarySize = boundarySize;
      previousViewportHeight = position.viewportDimension;
      previousMaximumOffset = position.maxScrollExtent;
      if (stableFrameCount >= 2) {
        return;
      }
    }

    throw Exception('编辑器布局尚未稳定，暂时无法生成分享图片');
  }

  /*
   * 按当前编辑器视口逐页截取真实排版，并在完成后恢复原滚动位置。
   */
  Future<void> _captureActiveEditorPages(
    Future<void> Function(Uint8List pageBytes, double visibleFraction) onPage, {
    required EditorShareRenderMode renderMode,
  }) async {
    final double pixelRatio = MediaQuery.devicePixelRatioOf(
      context,
    ).clamp(1.5, 2.0).toDouble();
    final Color pageBackgroundColor = renderMode == EditorShareRenderMode.pdf
        ? Colors.transparent
        : _colors.surfaceContainerLow;
    final TextSelection originalSelection =
        _editorController.quillController.selection;
    final double? requestedRestoreOffset = _editorScrollController.hasClients
        ? _editorScrollController.position.pixels
        : null;
    final bool shouldRestoreSelection =
        originalSelection.isValid && !originalSelection.isCollapsed;
    final EditorShareRenderMode previousRenderMode = _editorShareRenderMode;
    double? originalOffset;

    if (previousRenderMode != renderMode) {
      setState(() {
        _editorShareRenderMode = renderMode;
      });
    }
    try {
      if (_isToolbarCustomizing) {
        _toolbarCustomizationController.closeCustomization();
      }
      if (shouldRestoreSelection) {
        _updateEditorSelectionForShare(
          TextSelection.collapsed(offset: originalSelection.extentOffset),
        );
      }
      await _waitForStableEditorShareLayout();
      final RenderObject? initialRenderObject = _editorShareCaptureKey
          .currentContext
          ?.findRenderObject();
      if (initialRenderObject is! RenderRepaintBoundary ||
          !_editorScrollController.hasClients) {
        throw Exception('编辑器尚未准备好，暂时无法生成分享图片');
      }

      final ScrollPosition initialPosition = _editorScrollController.position;
      final Size captureBoundarySize = initialRenderObject.size;
      final double viewportHeight = initialPosition.viewportDimension;
      if (viewportHeight <= 0) {
        throw Exception('编辑器可见区域尺寸无效');
      }

      originalOffset = (requestedRestoreOffset ?? initialPosition.pixels)
          .clamp(
            initialPosition.minScrollExtent,
            initialPosition.maxScrollExtent,
          )
          .toDouble();
      final double contentHeight =
          initialPosition.maxScrollExtent + viewportHeight;
      final double maximumOffset = initialPosition.maxScrollExtent;
      final double paginatedContentHeight = contentHeight > 0.5
          ? contentHeight - 0.5
          : contentHeight;
      final int pageCount = (paginatedContentHeight / viewportHeight).ceil();

      for (int pageIndex = 0; pageIndex < pageCount; pageIndex++) {
        if (!_editorScrollController.hasClients) {
          throw Exception('编辑器已关闭，分享内容生成已停止');
        }

        final ScrollPosition currentPosition = _editorScrollController.position;
        final double requestedOffset = pageIndex * viewportHeight;
        final double actualOffset = requestedOffset
            .clamp(
              currentPosition.minScrollExtent,
              currentPosition.maxScrollExtent,
            )
            .toDouble();
        if ((currentPosition.pixels - actualOffset).abs() > 0.01) {
          _editorScrollController.jumpTo(actualOffset);
        }
        await WidgetsBinding.instance.endOfFrame;

        final RenderObject? renderObject = _editorShareCaptureKey.currentContext
            ?.findRenderObject();
        if (renderObject is! RenderRepaintBoundary) {
          throw Exception('编辑器分享截图区域不可用');
        }
        final ScrollPosition capturePosition = _editorScrollController.position;
        if ((renderObject.size.width - captureBoundarySize.width).abs() >=
                0.5 ||
            (renderObject.size.height - captureBoundarySize.height).abs() >=
                0.5 ||
            (capturePosition.viewportDimension - viewportHeight).abs() >= 0.5 ||
            (capturePosition.maxScrollExtent - maximumOffset).abs() >= 0.5) {
          throw Exception('编辑器尺寸发生变化，请稍后重试分享');
        }

        final ui.Image capturedImage = await renderObject.toImage(
          pixelRatio: pixelRatio,
        );
        try {
          final double remainingHeight = contentHeight - requestedOffset;
          final double visibleHeight = remainingHeight < viewportHeight
              ? remainingHeight
              : viewportHeight;
          await onPage(
            await _encodeEditorCapturePage(
              capturedImage: capturedImage,
              sourceTop: (requestedOffset - actualOffset) * pixelRatio,
              visibleHeight: visibleHeight * pixelRatio,
              backgroundColor: pageBackgroundColor,
            ),
            (visibleHeight / viewportHeight).clamp(0.0, 1.0).toDouble(),
          );
        } finally {
          capturedImage.dispose();
        }
      }
    } finally {
      if (mounted && _editorShareRenderMode != previousRenderMode) {
        setState(() {
          _editorShareRenderMode = previousRenderMode;
        });
        await WidgetsBinding.instance.endOfFrame;
      }
      if (mounted && shouldRestoreSelection) {
        _updateEditorSelectionForShare(originalSelection);
        await WidgetsBinding.instance.endOfFrame;
      }
      if (mounted &&
          originalOffset != null &&
          _editorScrollController.hasClients) {
        final ScrollPosition currentPosition = _editorScrollController.position;
        final double restoredOffset = originalOffset
            .clamp(
              currentPosition.minScrollExtent,
              currentPosition.maxScrollExtent,
            )
            .toDouble();
        if ((currentPosition.pixels - restoredOffset).abs() > 0.01) {
          _editorScrollController.jumpTo(restoredOffset);
          await WidgetsBinding.instance.endOfFrame;
        }
      }
    }
  }

  /*
   * 保存当前文档后执行指定系统分享操作。
   */
  Future<void> _shareActiveNote(
    Future<void> Function(NoteItem note, Rect? origin) shareAction,
  ) async {
    if (_activeNote == null || _isShareOperationInProgress) {
      return;
    }

    final Rect? shareOrigin = _getEditorShareOrigin();
    final Color progressBackgroundColor = _colors.surface;
    final Color progressIndicatorColor = _colors.primary;
    final OverlayEntry progressOverlay = OverlayEntry(
      builder: (BuildContext overlayContext) {
        return Positioned.fill(
          child: AbsorbPointer(
            child: ColoredBox(
              // 分享内容生成期间的遮罩背景样式
              color: progressBackgroundColor,
              child: Center(
                child: CircularProgressIndicator(
                  // 分享内容生成进度指示器样式
                  color: progressIndicatorColor,
                ),
              ),
            ),
          ),
        );
      },
    );
    setState(() {
      _isShareOperationInProgress = true;
    });
    _setEditorInteractionLocked(true);
    Overlay.of(context).insert(progressOverlay);
    try {
      if (!await _flushPendingEditorSave()) {
        return;
      }
      await shareAction(_activeNote!, shareOrigin);
    } catch (error) {
      await _showMessageDialog('分享失败', error.toString());
    } finally {
      progressOverlay.remove();
      _setEditorInteractionLocked(false);
      if (mounted) {
        setState(() {
          _isShareOperationInProgress = false;
        });
      }
    }
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
   * 统计编辑器正文的实际字符数。
   *
   * 空格、用户输入的换行和符号都会计入，只排除 Quill 文档自动维护的末尾结构换行。
   */
  int _getEditorCharacterCount() {
    final String plainText = _editorController.quillController.document
        .toPlainText();
    return plainText.endsWith('\n') ? plainText.length - 1 : plainText.length;
  }

  /*
   * 构建正文上方的最近修改信息文案。
   */
  String _buildEditorMetadataText() {
    final NoteItem note = _activeNote!;
    final DateTime updatedAt = note.updatedAt;

    return '${updatedAt.year}/${updatedAt.month}/${updatedAt.day} '
        '${padNumber(updatedAt.hour)}:${padNumber(updatedAt.minute)} | '
        '${_getEditorCharacterCount()}字 | '
        '${note.directoryPath.isEmpty ? '默认文件夹' : note.directoryPath.split('/').last}';
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
   * 按当前排序方式比较两个笔记包入口文档。
   */
  int _compareNotesBySortMode(NoteItem left, NoteItem right) {
    switch (_activeSortMode) {
      case NoteSortMode.name:
        return _compareNameText(left.packageName, right.packageName);
      case NoteSortMode.createdAt:
        final int createdResult = _compareDateDesc(
          left.createdAt,
          right.createdAt,
        );

        if (createdResult != 0) {
          return createdResult;
        }

        return _compareNameText(left.packageName, right.packageName);
      case NoteSortMode.updatedAt:
        final int updatedResult = _compareDateDesc(
          left.updatedAt,
          right.updatedAt,
        );

        if (updatedResult != 0) {
          return updatedResult;
        }

        return _compareNameText(left.packageName, right.packageName);
    }
  }

  /*
   * 按文件名比较同一个笔记包内的 Markdown 文档。
   */
  int _comparePackageNotesByName(NoteItem left, NoteItem right) {
    return _compareNameText(left.fileName, right.fileName);
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
            title: note.packageName,
            subtitle: note.preview,
            locationText: note.packageRelativePath,
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
            title: note.packageName,
            subtitle: note.preview,
            locationText: note.packageRelativePath,
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
   * 判断当前编辑笔记是否包含在待删除的选择项中。
   */
  bool _isActiveNoteIncludedInSelection() {
    if (_activeNote == null) {
      return false;
    }

    if (_selectedItemIds.contains('note:${_activeNote!.relativePath}')) {
      return true;
    }

    return _getSelectedFolderPaths().any(
      (String folderPath) =>
          _activeNote!.directoryPath == folderPath ||
          _activeNote!.directoryPath.startsWith('$folderPath/'),
    );
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
      // 正文元信息需要随本次内容变化重新统计实际字符数。
    });

    _saveTimer?.cancel();
    final NoteItem noteToSave = _activeNote!;
    final String contentToSave = _editorController.markdownText;
    _saveTimer = Timer(const Duration(milliseconds: 500), () {
      unawaited(_queueNoteSave(noteToSave, contentToSave).then<void>((_) {}));
    });
  }

  /*
   * 取消延迟等待并立即保存当前编辑器快照。
   */
  Future<bool> _flushPendingEditorSave() async {
    _saveTimer?.cancel();
    _saveTimer = null;

    if (_activeNote == null) {
      return _saveQueue;
    }

    return _queueNoteSave(_activeNote!, _editorController.markdownText);
  }

  /*
   * 锁定或恢复编辑器交互，防止文件移动或页面切换期间继续产生新输入。
   */
  void _setEditorInteractionLocked(bool isLocked) {
    _editorController.quillController.readOnly = isLocked;
    if (isLocked) {
      _editorFocusNode.unfocus();
    }
  }

  /*
   * 激活指定笔记，并同步编辑器内容。
   */
  void _activateNote(
    NoteItem note, {
    required bool isWideLayout,
    List<NoteItem>? packageNotes,
    bool closePackageDrawer = true,
  }) {
    setState(() {
      _activeNote = note;
      if (packageNotes != null) {
        _activePackageNotes = packageNotes;
        _notes =
            _notes
                .map(
                  (NoteItem item) =>
                      item.packageRelativePath == note.packageRelativePath
                      ? note
                      : item,
                )
                .toList()
              ..sort(_compareNotesBySortMode);
      }
      _editorController.loadMarkdown(note.content);
      _isPackageDrawerLoading = false;
      if (closePackageDrawer) {
        _isPackageDrawerOpen = false;
      }
      if (!isWideLayout) {
        _isCompactBrowserVisible = false;
      }
    });
    _restoreDocumentScrollOffset(note);
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
    return _isShareOperationInProgress ||
        _editorActionMenuOverlayEntry != null ||
        _isPackageDrawerOpen ||
        _isToolbarCustomizing ||
        _isSelectionMode ||
        (!isWideLayout && !_isCompactBrowserVisible) ||
        _activeDirectoryPath.isNotEmpty;
  }

  /*
   * 处理系统返回键操作。
   */
  void _handleSystemBack({required bool isWideLayout}) {
    if (_isShareOperationInProgress) {
      return;
    }

    if (_editorActionMenuOverlayEntry != null) {
      _hideEditorActionMenu();
      return;
    }

    if (_isPackageDrawerOpen) {
      setState(() {
        _isPackageDrawerOpen = false;
      });
      return;
    }

    if (_isToolbarCustomizing) {
      _toolbarCustomizationController.closeCustomization();
      return;
    }

    if (_isSelectionMode) {
      setState(() {
        _exitSelectionMode();
      });
      return;
    }

    if (!isWideLayout && !_isCompactBrowserVisible) {
      _editorFocusNode.unfocus();
      unawaited(_flushPendingEditorSave().then<void>((_) {}));
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
   * 处理详情页左上角返回按钮，优先退出工具栏自定义模式。
   */
  void _handleEditorBackButton() {
    if (_editorActionMenuOverlayEntry != null) {
      _hideEditorActionMenu();
      return;
    }

    if (_isPackageDrawerOpen) {
      setState(() {
        _isPackageDrawerOpen = false;
      });
      return;
    }

    if (_isToolbarCustomizing) {
      _toolbarCustomizationController.closeCustomization();
      return;
    }

    setState(() {
      _isCompactBrowserVisible = true;
    });
  }

  /*
   * 创建新的笔记。
   */
  Future<void> _handleCreateNote({required bool isWideLayout}) async {
    _setEditorInteractionLocked(true);
    try {
      if (!await _flushPendingEditorSave()) {
        return;
      }
      final String targetDirectoryPath = _activeCategoryId == 'all'
          ? _activeDirectoryPath
          : (_activeNote?.directoryPath ?? '');
      final NoteItem nextNote = await _noteStorageService.createNote(
        directoryPath: targetDirectoryPath,
      );
      final List<NoteItem> packageNotes = await _loadPackageNotes(nextNote);

      if (!mounted) {
        return;
      }

      await _reloadNotes(flushEditor: false);

      setState(() {
        _activeCategoryId = 'all';
        _activeDirectoryPath = nextNote.directoryPath;
      });

      _activateNote(
        nextNote,
        isWideLayout: isWideLayout,
        packageNotes: packageNotes,
      );
      _editorFocusNode.requestFocus();
    } catch (error) {
      await _showMessageDialog('创建失败', error.toString());
    } finally {
      _setEditorInteractionLocked(false);
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

    _setEditorInteractionLocked(true);
    try {
      if (!await _flushPendingEditorSave()) {
        return null;
      }
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
        await _reloadNotes(flushEditor: false);
        setState(() {
          _activeCategoryId = 'all';
          _activeDirectoryPath = parentDirectoryPath;
        });
      }

      return nextFolderPath;
    } catch (error) {
      await _showMessageDialog('创建失败', error.toString());
      return null;
    } finally {
      _setEditorInteractionLocked(false);
    }
  }

  /*
   * 删除当前 Markdown，并在它是最后一篇时删除整个笔记包。
   */
  Future<void> _handleDeleteCurrentDocument() async {
    if (_activeNote == null) {
      return;
    }

    late final NoteItem requestedNote;
    bool hasMultipleDocuments;
    _setEditorInteractionLocked(true);
    try {
      if (!await _flushPendingEditorSave()) {
        return;
      }
      requestedNote = _activeNote!;
      hasMultipleDocuments =
          (await _loadPackageNotes(requestedNote)).length > 1;
    } catch (error) {
      if (mounted) {
        await _showMessageDialog('读取笔记包失败', error.toString());
      }
      return;
    } finally {
      _setEditorInteractionLocked(false);
    }
    if (!mounted) {
      return;
    }
    final bool? shouldDelete = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('删除当前文档'),
          content: Text(
            hasMultipleDocuments
                ? '确定删除「${requestedNote.fileName}」及仅由它引用的资源吗？'
                : '这是笔记包内最后一篇 Markdown，删除后整个笔记包及其资源都会被删除。',
          ),
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
              // 删除确认按钮文字样式
              style: TextButton.styleFrom(foregroundColor: _colors.error),
              child: const Text('删除'),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true ||
        _activeNote?.relativePath != requestedNote.relativePath) {
      return;
    }

    _setEditorInteractionLocked(true);
    try {
      if (!await _flushPendingEditorSave()) {
        return;
      }
      final String deletedRelativePath = _activeNote!.relativePath;
      await _noteStorageService.deletePackageDocument(deletedRelativePath);
      _documentScrollOffsets.remove(deletedRelativePath);
      await _reloadNotes(flushEditor: false);

      if (!mounted) {
        return;
      }

      setState(() {
        if (_notes.isEmpty) {
          _isCompactBrowserVisible = true;
        }
      });
    } catch (error) {
      if (mounted) {
        try {
          await _reloadNotes(flushEditor: false);
        } catch (_) {
          // 删除已部分完成时优先尝试刷新界面，二次读取失败仍由原始错误提示说明。
        }
      }
      await _showMessageDialog('删除失败', error.toString());
    } finally {
      _setEditorInteractionLocked(false);
    }
  }

  /*
   * 删除当前 Markdown 所属的整个笔记包及其中全部资源。
   */
  Future<void> _handleDeleteCurrentPackage() async {
    if (_activeNote == null) {
      return;
    }

    final NoteItem requestedNote = _activeNote!;
    final bool? shouldDelete = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('删除整个笔记包'),
          content: Text(
            '确定删除「${requestedNote.packageName}」中的全部 Markdown 和 assets 吗？',
          ),
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
              // 删除全部确认按钮文字样式
              style: TextButton.styleFrom(foregroundColor: _colors.error),
              child: const Text('删除全部'),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true ||
        _activeNote?.packageRelativePath != requestedNote.packageRelativePath) {
      return;
    }

    _setEditorInteractionLocked(true);
    try {
      _saveTimer?.cancel();
      _saveTimer = null;
      await _saveQueue;
      if (_activeNote?.packageRelativePath !=
          requestedNote.packageRelativePath) {
        return;
      }

      await _noteStorageService.deleteNote(_activeNote!.relativePath);
      _documentScrollOffsets.removeWhere(
        (String relativePath, double _) =>
            relativePath.startsWith('${requestedNote.packageRelativePath}/'),
      );
      await _reloadNotes(flushEditor: false);

      if (!mounted) {
        return;
      }

      setState(() {
        if (_notes.isEmpty) {
          _isCompactBrowserVisible = true;
        }
      });
    } catch (error) {
      if (mounted) {
        try {
          await _reloadNotes(flushEditor: false);
        } catch (_) {
          // 整包删除已部分完成时优先刷新界面，二次读取失败仍保留原始错误。
        }
        await _showMessageDialog('删除失败', error.toString());
      }
    } finally {
      _setEditorInteractionLocked(false);
    }
  }

  /*
   * 选择指定笔记包入口文档并保存当前编辑内容。
   */
  Future<void> _handleSelectNote(
    NoteItem note, {
    required bool isWideLayout,
  }) async {
    if (_isSelectionMode) {
      _toggleSelectedItem('note:${note.relativePath}');
      return;
    }

    if (_activeNote?.relativePath == note.relativePath) {
      if (!isWideLayout && _isCompactBrowserVisible) {
        setState(() {
          _isCompactBrowserVisible = false;
        });
      }
      return;
    }

    _setEditorInteractionLocked(true);
    try {
      if (_activeNote != null &&
          !await _persistActiveNote(_editorController.markdownText)) {
        return;
      }

      _rememberActiveDocumentScrollOffset();
      final List<NoteItem> packageNotes = await _loadPackageNotes(note);
      final NoteItem selectedNote =
          _findPackageNoteByRelativePath(packageNotes, note.relativePath) ??
          note;
      await _noteStorageService.setPackageEntryNote(selectedNote);

      if (!mounted) {
        return;
      }

      _activateNote(
        selectedNote,
        isWideLayout: isWideLayout,
        packageNotes: packageNotes,
      );
    } catch (error) {
      await _showMessageDialog('打开笔记包失败', error.toString());
    } finally {
      _setEditorInteractionLocked(false);
    }
  }

  /*
   * 切换当前笔记包内的指定 Markdown 文档。
   */
  Future<void> _handleSelectPackageNote(NoteItem note) async {
    if (_activeNote?.relativePath == note.relativePath) {
      setState(() {
        _isPackageDrawerOpen = false;
      });
      return;
    }

    _setEditorInteractionLocked(true);
    try {
      if (_activeNote != null &&
          !await _persistActiveNote(_editorController.markdownText)) {
        return;
      }

      _rememberActiveDocumentScrollOffset();
      final List<NoteItem> packageNotes = await _loadPackageNotes(note);
      final NoteItem selectedNote =
          _findPackageNoteByRelativePath(packageNotes, note.relativePath) ??
          note;
      await _noteStorageService.setPackageEntryNote(selectedNote);

      if (!mounted) {
        return;
      }

      _activateNote(
        selectedNote,
        isWideLayout: MediaQuery.of(context).size.width >= 980,
        packageNotes: packageNotes,
      );
    } catch (error) {
      await _showMessageDialog('切换失败', error.toString());
    } finally {
      _setEditorInteractionLocked(false);
    }
  }

  /*
   * 展开或收起当前笔记包的 Markdown 文档切换抽屉。
   */
  Future<void> _togglePackageDrawer() async {
    if (_activeNote == null) {
      return;
    }

    if (_isPackageDrawerOpen) {
      setState(() {
        _isPackageDrawerOpen = false;
      });
      return;
    }

    setState(() {
      _isPackageDrawerOpen = true;
      _isPackageDrawerLoading = true;
    });

    try {
      final NoteItem requestedPackageNote = _activeNote!;
      final List<NoteItem> packageNotes = await _loadPackageNotes(
        requestedPackageNote,
      );
      if (!mounted) {
        return;
      }
      if (_activeNote?.packageRelativePath !=
          requestedPackageNote.packageRelativePath) {
        setState(() {
          _isPackageDrawerLoading = false;
        });
        return;
      }

      setState(() {
        _activePackageNotes = packageNotes;
        _isPackageDrawerLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isPackageDrawerOpen = false;
        _isPackageDrawerLoading = false;
      });
      await _showMessageDialog('读取笔记包失败', error.toString());
    }
  }

  /*
   * 根据垂直拖动距离更新文档抽屉侧边入口位置。
   */
  void _handlePackageDrawerRailDrag(double deltaY, double maximumTop) {
    if (maximumTop <= 0) {
      return;
    }

    _packageDrawerRailPosition.value =
        (_packageDrawerRailPosition.value + deltaY / maximumTop)
            .clamp(0.0, 1.0)
            .toDouble();
  }

  /*
   * 保存文档抽屉侧边入口位置。
   */
  void _savePackageDrawerRailPosition() {
    unawaited(_saveAppCache());
  }

  /*
   * 在当前笔记包内创建并打开新的 Markdown 文档。
   */
  Future<void> _handleCreatePackageNote() async {
    if (_activeNote == null) {
      return;
    }

    _setEditorInteractionLocked(true);
    try {
      if (!await _persistActiveNote(_editorController.markdownText)) {
        return;
      }

      _rememberActiveDocumentScrollOffset();
      final NoteItem newNote = await _noteStorageService.createPackageNote(
        _activeNote!.packageRelativePath,
      );
      final List<NoteItem> packageNotes = await _loadPackageNotes(newNote);
      await _noteStorageService.setPackageEntryNote(newNote);

      if (!mounted) {
        return;
      }

      _activateNote(
        newNote,
        isWideLayout: MediaQuery.of(context).size.width >= 980,
        packageNotes: packageNotes,
      );
      _editorFocusNode.requestFocus();
    } catch (error) {
      await _showMessageDialog('新建文档失败', error.toString());
    } finally {
      _setEditorInteractionLocked(false);
    }
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
    _setEditorInteractionLocked(true);
    try {
      if (!await _flushPendingEditorSave()) {
        return;
      }
      if (sourceItem.type == NoteGridItemType.note) {
        await _noteStorageService.moveNoteToDirectory(
          _getLatestNoteForSave(sourceItem.note!),
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
      await _reloadNotes(flushEditor: false);
    } catch (error) {
      await _showMessageDialog('移动失败', error.toString());
    } finally {
      _setEditorInteractionLocked(false);
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

    _setEditorInteractionLocked(true);
    try {
      if (!await _flushPendingEditorSave()) {
        return;
      }
      final String parentDirectoryPath = _activeCategoryId == 'all'
          ? _activeDirectoryPath
          : '';
      final String nextFolderPath = await _noteStorageService.createFolder(
        parentDirectoryPath,
        folderName,
      );

      await _noteStorageService.moveNoteToDirectory(
        _getLatestNoteForSave(sourceNoteItem.note!),
        nextFolderPath,
      );
      await _noteStorageService.moveNoteToDirectory(
        _getLatestNoteForSave(targetNoteItem.note!),
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
      await _reloadNotes(flushEditor: false);
    } catch (error) {
      await _showMessageDialog('创建失败', error.toString());
    } finally {
      _setEditorInteractionLocked(false);
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
   * keepCurrentDirectory 为 true 时，移动完成后继续停留在当前目录。
   */
  Future<void> _moveSelectedItemsToDirectory(
    String targetDirectoryPath, {
    bool keepCurrentDirectory = false,
  }) async {
    _setEditorInteractionLocked(true);
    try {
      if (!await _flushPendingEditorSave()) {
        return;
      }
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
        if (!keepCurrentDirectory) {
          _activeDirectoryPath = targetDirectoryPath;
        }
      });

      await _reloadNotes(flushEditor: false);
    } catch (error) {
      await _showMessageDialog('移动失败', error.toString());
    } finally {
      _setEditorInteractionLocked(false);
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

    _setEditorInteractionLocked(true);
    try {
      if (_isActiveNoteIncludedInSelection()) {
        _saveTimer?.cancel();
        _saveTimer = null;
        await _saveQueue;
      } else {
        if (!await _flushPendingEditorSave()) {
          return;
        }
      }

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
      await _reloadNotes(flushEditor: false);
    } catch (error) {
      await _showMessageDialog('删除失败', error.toString());
    } finally {
      _setEditorInteractionLocked(false);
    }
  }

  /*
   * 将当前笔记包移动到指定普通文件夹并继续打开当前文档。
   */
  Future<void> _moveActivePackageToDirectory(String targetDirectoryPath) async {
    if (_activeNote == null ||
        _activeNote!.directoryPath == targetDirectoryPath) {
      return;
    }

    _setEditorInteractionLocked(true);
    try {
      if (!await _flushPendingEditorSave()) {
        return;
      }
      final NoteItem movedEntry = await _noteStorageService.moveNoteToDirectory(
        _activeNote!,
        targetDirectoryPath,
      );
      final List<NoteItem> movedPackageNotes = await _loadPackageNotes(
        movedEntry,
      );
      await _reloadNotes(flushEditor: false);

      if (!mounted) {
        return;
      }

      _activateNote(
        _findPackageNoteByRelativePath(
              movedPackageNotes,
              movedEntry.relativePath,
            ) ??
            movedEntry,
        isWideLayout: MediaQuery.of(context).size.width >= 980,
        packageNotes: movedPackageNotes,
      );
      setState(() {
        _activeCategoryId = 'all';
        _activeDirectoryPath = targetDirectoryPath;
        _increaseFolderVisitCount(targetDirectoryPath);
      });
    } catch (error) {
      await _showMessageDialog('移动失败', error.toString());
    } finally {
      _setEditorInteractionLocked(false);
    }
  }

  /*
   * 为当前笔记包打开与首页相同的移动文件夹面板。
   */
  Future<void> _showActivePackageMoveSheet() async {
    if (_activeNote == null) {
      return;
    }

    await _showMoveSheet(packageToMove: _activeNote);
  }

  /*
   * 展示移动目标文件夹面板。
   */
  Future<void> _showMoveSheet({NoteItem? packageToMove}) async {
    if (packageToMove == null && _selectedItemIds.isEmpty) {
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext sheetContext) {
        return _buildMoveSheet(sheetContext, packageToMove: packageToMove);
      },
    );
  }

  /*
   * 保存当前激活笔记内容。
   */
  Future<bool> _persistActiveNote(String content) async {
    _saveTimer?.cancel();
    _saveTimer = null;

    if (_activeNote == null) {
      return _saveQueue;
    }

    return _queueNoteSave(_activeNote!, content);
  }

  /*
   * 把指定笔记快照追加到串行保存队列。
   */
  Future<bool> _queueNoteSave(NoteItem note, String content) {
    _saveQueue = _saveQueue.then((_) => _saveNoteSnapshot(note, content));
    return _saveQueue;
  }

  /*
   * 获取指定笔记在前一次保存重命名后的最新实体。
   */
  NoteItem _getLatestNoteForSave(NoteItem note) {
    return _latestSavedNotes[note.relativePath] ?? note;
  }

  /*
   * 判断指定保存任务是否仍对应当前正在编辑的笔记。
   */
  bool _isActiveSaveTarget(NoteItem requestedNote, NoteItem latestNote) {
    return _activeNote?.relativePath == requestedNote.relativePath ||
        _activeNote?.relativePath == latestNote.relativePath;
  }

  /*
   * 执行单篇笔记快照保存，并只更新仍然匹配的界面状态。
   */
  Future<bool> _saveNoteSnapshot(NoteItem requestedNote, String content) async {
    final NoteItem noteToSave = _getLatestNoteForSave(requestedNote);

    if (content == noteToSave.content) {
      return true;
    }

    try {
      final NoteItem savedNote = (await _noteStorageService.saveNoteContent(
        noteToSave.relativePath,
        content,
      )).copyWith(createdAt: noteToSave.createdAt);

      _latestSavedNotes[requestedNote.relativePath] = savedNote;
      _latestSavedNotes[noteToSave.relativePath] = savedNote;

      if (!mounted) {
        return true;
      }

      final bool shouldUpdateActiveNote = _isActiveSaveTarget(
        requestedNote,
        noteToSave,
      );

      setState(() {
        _notes =
            _notes
                .map(
                  (NoteItem item) =>
                      item.relativePath == requestedNote.relativePath ||
                          item.relativePath == noteToSave.relativePath
                      ? savedNote
                      : item,
                )
                .toList()
              ..sort(_compareNotesBySortMode);
        _activePackageNotes =
            _activePackageNotes
                .map(
                  (NoteItem item) =>
                      item.relativePath == requestedNote.relativePath ||
                          item.relativePath == noteToSave.relativePath
                      ? savedNote
                      : item,
                )
                .toList()
              ..sort(_comparePackageNotesByName);

        final bool wasSelected = _selectedItemIds.remove(
          'note:${requestedNote.relativePath}',
        );
        final bool wasLatestPathSelected = _selectedItemIds.remove(
          'note:${noteToSave.relativePath}',
        );
        if (wasSelected || wasLatestPathSelected) {
          _selectedItemIds.add('note:${savedNote.relativePath}');
        }

        if (shouldUpdateActiveNote) {
          _activeNote = savedNote;
          if (_activeCategoryId != 'all' &&
              !savedNote.tags.contains(_activeCategoryId)) {
            _activeCategoryId = 'all';
          }
        }
      });
      return true;
    } catch (error) {
      if (!mounted) {
        return false;
      }

      try {
        await _showMessageDialog('保存失败', error.toString());
      } catch (_) {
        // 页面正在退出时弹窗可能无法展示，但保存失败结果仍要返回给调用方。
      }
      return false;
    }
  }

  /*
   * 执行 Markdown 工具栏操作。
   */
  void _handleToolbarAction(ToolbarActionKey actionKey) {
    if (_editorController.quillController.readOnly) {
      // 文件切换或移动期间忽略工具栏点击，避免锁定状态下继续修改正文。
      return;
    }

    if (actionKey == ToolbarActionKey.undo) {
      _editorController.quillController.undo();
      _editorFocusNode.requestFocus();
      return;
    }

    if (actionKey == ToolbarActionKey.redo) {
      _editorController.quillController.redo();
      _editorFocusNode.requestFocus();
      return;
    }

    if (actionKey == ToolbarActionKey.insertTable) {
      _insertMarkdownTable();
      return;
    }

    if (actionKey == ToolbarActionKey.codeBlock) {
      unawaited(_insertMarkdownCodeBlock());
      return;
    }

    _toggleEditorAttribute(switch (actionKey) {
      ToolbarActionKey.title => Attribute.h1,
      ToolbarActionKey.subtitle => Attribute.h2,
      ToolbarActionKey.heading3 => Attribute.h3,
      ToolbarActionKey.heading4 => Attribute.h4,
      ToolbarActionKey.heading5 => Attribute.h5,
      ToolbarActionKey.heading6 => Attribute.h6,
      ToolbarActionKey.bold => Attribute.bold,
      ToolbarActionKey.italic => Attribute.italic,
      ToolbarActionKey.strikeThrough => Attribute.strikeThrough,
      ToolbarActionKey.list => Attribute.ul,
      ToolbarActionKey.orderedList => Attribute.ol,
      ToolbarActionKey.checkList => Attribute.unchecked,
      ToolbarActionKey.blockQuote => Attribute.blockQuote,
      ToolbarActionKey.inlineCode => Attribute.inlineCode,
      ToolbarActionKey.codeBlock ||
      ToolbarActionKey.insertTable ||
      ToolbarActionKey.undo ||
      ToolbarActionKey.redo => throw StateError('命令工具已在格式切换前处理'),
    });
  }

  /*
   * 弹出代码块语言输入对话框。
   *
   * 返回 null 表示取消，返回空字符串表示创建不带语言标识的普通代码块。
   */
  Future<String?> _showCodeBlockLanguageDialog() async {
    final TextEditingController languageController = TextEditingController();
    final DialogRoute<String> languageDialogRoute = DialogRoute<String>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('代码块语言'),
          content: TextField(
            controller: languageController,
            autofocus: true,
            autocorrect: false,
            enableSuggestions: false,
            textInputAction: TextInputAction.done,
            // 代码块语言输入框提示样式
            decoration: const InputDecoration(hintText: '例如 java，可留空'),
            onSubmitted: (String value) {
              Navigator.of(dialogContext).pop(value);
            },
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
                Navigator.of(dialogContext).pop(languageController.text);
              },
              child: const Text('确定'),
            ),
          ],
        );
      },
    );

    try {
      final String? language = await Navigator.of(
        context,
        rootNavigator: true,
      ).push(languageDialogRoute);
      // 等待退出动画结束，确保 TextField 已从组件树卸载后再释放输入控制器。
      await languageDialogRoute.completed;
      return language;
    } finally {
      languageController.dispose();
    }
  }

  /*
   * 根据用户输入的语言标识创建当前 Markdown 代码块。
   */
  Future<void> _insertMarkdownCodeBlock() async {
    final String? language = await _showCodeBlockLanguageDialog();
    if (language == null || !mounted) {
      return;
    }

    _editorController.applyCodeBlock(language);
    _editorFocusNode.requestFocus();
  }

  /*
   * 删除当前光标所在的 Markdown 代码块并恢复编辑焦点。
   */
  void _deleteMarkdownCodeBlock() {
    if (_editorController.deleteCodeBlockAtSelection()) {
      _editorFocusNode.requestFocus();
    }
  }

  /*
   * 在当前选区插入一个可保存为 Markdown 的两列表格。
   */
  void _insertMarkdownTable() {
    _editorController.insertMarkdownTable(
      '| 列 1 | 列 2 |\n| --- | --- |\n| 内容 | 内容 |',
    );
    _editorFocusNode.requestFocus();
  }

  /*
   * 接收工具栏新的动作顺序并立即保存到应用缓存。
   */
  void _handleToolbarActionKeysChanged(
    List<ToolbarActionKey> toolbarActionKeys,
  ) {
    setState(() {
      _toolbarActionKeys = List<ToolbarActionKey>.from(toolbarActionKeys);
    });
    unawaited(_saveAppCache());
  }

  /*
   * 同步工具仓库显示状态，仓库打开时隐藏下方笔记正文。
   */
  void _handleToolbarCustomizationChanged(bool isCustomizing) {
    if (_isToolbarCustomizing == isCustomizing) {
      return;
    }

    setState(() {
      _isToolbarCustomizing = isCustomizing;
    });
  }

  /*
   * 切换当前选区的 Quill 格式，并让输入焦点回到编辑器。
   */
  void _toggleEditorAttribute(Attribute<dynamic> attribute) {
    _editorController.quillController
      // 块级格式切换时避免重复请求键盘，减少移动端键盘抖动。
      ..skipRequestKeyboard = !attribute.isInline
      ..formatSelection(
        _editorController.quillController
                    .getSelectionStyle()
                    .attributes[attribute.key]
                    ?.value ==
                attribute.value
            ? Attribute.clone(attribute, null)
            : attribute,
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
              onPressed: _handleEditorBackButton,
              icon: const Icon(Icons.arrow_back_rounded),
              color: _colors.onSurface,
            ),
          Expanded(
            child: Column(
              // 顶部标题区纵向布局样式
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Text(
                      '笔记包',
                      // 顶部标题文字样式
                      style: TextStyle(
                        color: _colors.onSurface,
                        fontSize: 34,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: 4, top: 4),
                      child: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: _colors.onSurface,
                        size: 26,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '${_notes.length} 个笔记包',
                  // 顶部统计文字样式
                  style: TextStyle(
                    color: _colors.onSurfaceVariant,
                    fontSize: 17,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Row(
            // 顶部右侧操作按钮横向布局样式，只占主题、搜索和更多按钮需要的宽度。
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              IconButton(
                tooltip: widget.isDarkMode ? '切换到白天模式' : '切换到暗色模式',
                onPressed: () {
                  widget.onThemeModeChanged(!widget.isDarkMode);
                },
                icon: Icon(
                  widget.isDarkMode
                      ? Icons.light_mode_rounded
                      : Icons.dark_mode_rounded,
                ),
                color: _colors.onSurface,
                iconSize: 22,
                // 主题切换按钮独立背景样式
                style: IconButton.styleFrom(
                  backgroundColor: _colors.surfaceContainerHigh,
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints.tightFor(
                  width: 44,
                  height: 44,
                ),
              ),
              IconButton(
                onPressed: () {
                  _showMessageDialog('搜索', '搜索功能后面再接。');
                },
                icon: const Icon(Icons.search_rounded),
                color: _colors.onSurface,
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
                  color: _colors.onSurface,
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
                      child: SizedBox(
                        // 三个点按钮实际占位样式，用 SizedBox 控制宽高比 constraints 更直接。
                        width: 70,
                        height: 44,
                        child: Align(
                          alignment: Alignment.center,
                          child: Icon(
                            Icons.more_vert_rounded,
                            color: _colors.onSurface,
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
          color: isActive
              ? _colors.surfaceContainerHighest
              : _colors.surfaceContainerLowest,
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
            color: _colors.onSurface,
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
          style: TextStyle(color: _colors.onSurfaceVariant, fontSize: 14),
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
            child: Text(
              '全部笔记包',
              // 根路径文字样式
              style: TextStyle(
                color: _colors.tertiary,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          for (int index = 0; index < segments.length; index++) ...<Widget>[
            Text(
              '/',
              style: TextStyle(
                color: _colors.onSurfaceVariant.withValues(alpha: 0.6),
                fontSize: 14,
              ),
            ),
            GestureDetector(
              onTap: () {
                _handleDirectoryChanged(segments.take(index + 1).join('/'));
              },
              child: Text(
                segments[index],
                // 子路径文字样式
                style: TextStyle(
                  color: _colors.onSurfaceVariant,
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
        color: isSelected ? _colors.primary : _colors.surfaceContainer,
        shape: BoxShape.circle,
        border: Border.all(color: _colors.outlineVariant),
      ),
      child: isSelected
          ? Icon(Icons.check_rounded, color: _colors.onPrimary, size: 20)
          : null,
    );
  }

  /*
   * 构建文件夹图标。
   */
  Widget _buildFolderIcon({double size = 58}) {
    return Icon(Icons.folder_rounded, color: _colors.secondary, size: size);
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
                color: isHoverTarget ? _colors.primary : Colors.transparent,
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
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: _colors.shadow.withValues(alpha: 0.15),
                  blurRadius: 20,
                  offset: Offset(0, 10),
                ),
                BoxShadow(
                  color: _colors.shadow.withValues(alpha: 0.09),
                  blurRadius: 16,
                  offset: Offset(6, 0),
                ),
                BoxShadow(
                  color: _colors.shadow.withValues(alpha: 0.09),
                  blurRadius: 16,
                  offset: Offset(-6, 0),
                ),
                BoxShadow(
                  color: _colors.shadow.withValues(alpha: 0.05),
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
          color: _colors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(18),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: _colors.shadow.withValues(
                alpha: widget.isDarkMode ? 0.28 : 0.06,
              ),
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
                        style: TextStyle(
                          color: _colors.onSurface,
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
                        style: TextStyle(
                          color: _colors.onSurfaceVariant,
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
   * 构建笔记包卡片。
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
        // 笔记包卡片容器样式
        decoration: BoxDecoration(
          color: _colors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(18),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: _colors.shadow.withValues(
                alpha: widget.isDarkMode ? 0.28 : 0.06,
              ),
              blurRadius: 18,
              offset: Offset(0, 8),
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(22, 24, 22, 20),
        child: Stack(
          children: <Widget>[
            Column(
              // 笔记包卡片内容纵向布局样式
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  // 笔记包卡片标题横向布局样式
                  children: <Widget>[
                    Icon(
                      Icons.folder_copy_rounded,
                      color: _colors.secondary,
                      size: 24,
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        item.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        // 笔记包卡片标题样式
                        style: TextStyle(
                          color: _colors.onSurface,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  note.preview,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  // 笔记包入口文档摘要样式
                  style: TextStyle(
                    color: _colors.onSurfaceVariant,
                    fontSize: 16,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _formatNoteCardDate(note.updatedAt),
                  // 笔记包修改日期样式
                  style: TextStyle(
                    color: _colors.onSurfaceVariant.withValues(alpha: 0.75),
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
          color: _colors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(18),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: _colors.shadow.withValues(
                alpha: widget.isDarkMode ? 0.24 : 0.04,
              ),
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
                        style: TextStyle(
                          color: _colors.onSurface,
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
                        style: TextStyle(
                          color: _colors.onSurfaceVariant,
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
   * 构建列表模式下的笔记包行。
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
        // 笔记包列表行容器样式
        decoration: BoxDecoration(
          color: _colors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(18),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: _colors.shadow.withValues(
                alpha: widget.isDarkMode ? 0.24 : 0.04,
              ),
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
                // 笔记包列表文字纵向布局样式
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    // 笔记包列表标题横向布局样式
                    children: <Widget>[
                      Icon(
                        Icons.folder_copy_rounded,
                        color: _colors.secondary,
                        size: 22,
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          // 笔记包列表标题样式
                          style: TextStyle(
                            color: _colors.onSurface,
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    note.preview,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    // 笔记包入口文档摘要样式
                    style: TextStyle(
                      color: _colors.onSurfaceVariant,
                      fontSize: 15,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _formatNoteCardDate(note.updatedAt),
                    // 笔记包修改日期样式
                    style: TextStyle(
                      color: _colors.onSurfaceVariant.withValues(alpha: 0.75),
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
          ? Center(
              child: Text(
                '当前目录还没有内容',
                // 空目录提示样式
                style: TextStyle(color: _colors.onSurfaceVariant, fontSize: 16),
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
          color: _colors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(18),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: _colors.shadow.withValues(
                alpha: widget.isDarkMode ? 0.26 : 0.05,
              ),
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
            Icon(icon, color: _colors.primary, size: 48),
            const Spacer(),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              // 移动目标标题样式
              style: TextStyle(
                color: _colors.onSurface,
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
                style: TextStyle(color: _colors.onSurfaceVariant, fontSize: 14),
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
  Widget _buildMoveSheet(BuildContext sheetContext, {NoteItem? packageToMove}) {
    final List<String> targetFolders = _folderPaths
        .where(
          (String folderPath) => packageToMove == null
              ? _canUseMoveTarget(folderPath)
              : packageToMove.directoryPath != folderPath,
        )
        .toList();
    final List<Widget> targetCards = <Widget>[
      _buildMoveTargetCard(
        icon: Icons.create_new_folder_rounded,
        title: '新建文件夹',
        subtitle: '',
        onTap: () async {
          Navigator.of(sheetContext).pop();
          if (packageToMove == null) {
            await _handleCreateFolder(moveSelectedAfterCreate: true);
          } else {
            final String? folderPath = await _handleCreateFolder();
            if (folderPath != null) {
              await _moveActivePackageToDirectory(folderPath);
            }
          }
        },
      ),
      if (packageToMove?.directoryPath.isNotEmpty ?? _canMoveSelectedItemsOut())
        _buildMoveTargetCard(
          icon: Icons.folder_rounded,
          title: '移出文件夹',
          subtitle: '移动到笔记根目录',
          onTap: () async {
            Navigator.of(sheetContext).pop();
            if (packageToMove == null) {
              await _moveSelectedItemsToDirectory(
                '',
                keepCurrentDirectory: true,
              );
            } else {
              await _moveActivePackageToDirectory('');
            }
          },
        ),
      ...targetFolders.map(
        (String folderPath) => _buildMoveTargetCard(
          icon: Icons.folder_rounded,
          title: folderPath.split('/').last,
          subtitle: '${_getFolderNoteCount(folderPath)}',
          onTap: () async {
            Navigator.of(sheetContext).pop();
            if (packageToMove == null) {
              await _moveSelectedItemsToDirectory(folderPath);
            } else {
              await _moveActivePackageToDirectory(folderPath);
            }
          },
        ),
      ),
    ];

    return DraggableScrollableSheet(
      // 移动面板仅占实际显示高度，让上方遮罩区域可以点击关闭。
      expand: false,
      initialChildSize: 0.48,
      minChildSize: 0.32,
      maxChildSize: 0.82,
      builder: (BuildContext context, ScrollController scrollController) {
        return Container(
          // 移动面板容器样式
          decoration: BoxDecoration(
            color: _colors.surfaceContainerLowest,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(28),
              topRight: Radius.circular(28),
            ),
          ),
          child: Column(
            children: <Widget>[
              const SizedBox(height: 24),
              Text(
                '选择文件夹',
                // 移动面板标题样式
                style: TextStyle(
                  color: _colors.onSurface,
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
        color: _colors.surfaceContainerLowest,
        padding: const EdgeInsets.fromLTRB(28, 14, 28, 24),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: <Widget>[
            _buildActionItem(Icons.lock_outline_rounded, '设为私密', () {
              _showMessageDialog('暂未实现', '私密笔记包后面再接。');
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
          Icon(icon, color: _colors.onSurface, size: 30),
          const SizedBox(height: 6),
          Text(
            label,
            // 底部操作项文字样式
            style: TextStyle(color: _colors.onSurface, fontSize: 14),
          ),
        ],
      ),
    );
  }

  /*
   * 构建编辑区左侧的笔记包文档抽屉把手。
   */
  Widget _buildPackageDrawerRail() {
    return Positioned.fill(
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final double maximumTop =
              constraints.maxHeight > _packageDrawerRailHeight
              ? constraints.maxHeight - _packageDrawerRailHeight
              : 0;

          return Stack(
            // 文档抽屉侧边入口在编辑面板内自适应定位样式
            children: <Widget>[
              Positioned(
                left: 0,
                top: 0,
                height: _packageDrawerRailHeight,
                child: ValueListenableBuilder<double>(
                  valueListenable: _packageDrawerRailPosition,
                  child: IgnorePointer(
                    ignoring: _isPackageDrawerOpen,
                    child: AnimatedOpacity(
                      opacity: _isPackageDrawerOpen ? 0 : 1,
                      duration: const Duration(milliseconds: 160),
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onVerticalDragUpdate: (DragUpdateDetails details) {
                          _handlePackageDrawerRailDrag(
                            details.delta.dy,
                            maximumTop,
                          );
                        },
                        onVerticalDragEnd: (DragEndDetails _) {
                          _savePackageDrawerRailPosition();
                        },
                        onVerticalDragCancel: _savePackageDrawerRailPosition,
                        child: RepaintBoundary(
                          child: Material(
                            // 文档抽屉细条材质样式
                            color: _colors.surfaceContainerHighest,
                            borderRadius: const BorderRadius.horizontal(
                              right: Radius.circular(8),
                            ),
                            child: Tooltip(
                              message: '切换笔记包内文档',
                              child: IconButton(
                                onPressed: () {
                                  _togglePackageDrawer();
                                },
                                icon: const Icon(Icons.article_outlined),
                                color: _colors.onSurface,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  builder:
                      (BuildContext context, double position, Widget? child) {
                        // 拖动时只更新入口的合成位移，避免整张编辑页重新布局。
                        return Transform.translate(
                          offset: Offset(0, maximumTop * position),
                          child: child,
                        );
                      },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /*
   * 构建覆盖编辑区的笔记包 Markdown 文档切换抽屉。
   */
  Widget _buildPackageDrawerOverlay() {
    if (_activeNote == null) {
      return const SizedBox.shrink();
    }

    final double screenWidth = MediaQuery.of(context).size.width;
    final double drawerWidth = screenWidth < 400 ? screenWidth - 32 : 320;

    return Positioned.fill(
      child: IgnorePointer(
        ignoring: !_isPackageDrawerOpen,
        child: Stack(
          children: <Widget>[
            AnimatedOpacity(
              opacity: _isPackageDrawerOpen ? 1 : 0,
              duration: const Duration(milliseconds: 180),
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _isPackageDrawerOpen = false;
                  });
                },
                child: ColoredBox(
                  // 文档抽屉遮罩样式
                  color: _colors.scrim.withValues(alpha: 0.16),
                ),
              ),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: AnimatedSlide(
                offset: _isPackageDrawerOpen
                    ? Offset.zero
                    : const Offset(-1, 0),
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                child: Material(
                  // 文档抽屉面板材质样式
                  color: _colors.surfaceContainerLowest,
                  elevation: 18,
                  child: SizedBox(
                    width: drawerWidth,
                    height: double.infinity,
                    child: Column(
                      // 文档抽屉纵向布局样式
                      children: <Widget>[
                        Padding(
                          // 文档抽屉标题栏边距样式
                          padding: const EdgeInsets.fromLTRB(18, 18, 10, 12),
                          child: Row(
                            // 文档抽屉标题栏横向布局样式
                            children: <Widget>[
                              Icon(
                                Icons.folder_open_rounded,
                                color: _colors.secondary,
                                size: 24,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  // 文档抽屉标题文字纵向布局样式
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Text(
                                      _activeNote!.packageName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      // 文档抽屉笔记包标题样式
                                      style: TextStyle(
                                        color: _colors.onSurface,
                                        fontSize: 18,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${_activePackageNotes.length} 篇 Markdown',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      // 文档抽屉笔记包数量样式
                                      style: TextStyle(
                                        color: _colors.onSurfaceVariant,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Tooltip(
                                message: '新建包内文档',
                                child: IconButton(
                                  onPressed: _isPackageDrawerLoading
                                      ? null
                                      : () {
                                          _handleCreatePackageNote();
                                        },
                                  icon: const Icon(Icons.note_add_outlined),
                                  color: _colors.onSurface,
                                ),
                              ),
                              Tooltip(
                                message: '收起文档列表',
                                child: IconButton(
                                  onPressed: () {
                                    setState(() {
                                      _isPackageDrawerOpen = false;
                                    });
                                  },
                                  icon: const Icon(Icons.chevron_left_rounded),
                                  color: _colors.onSurface,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Divider(height: 1, color: _colors.outlineVariant),
                        Expanded(
                          child: _isPackageDrawerLoading
                              ? Center(
                                  child: CircularProgressIndicator(
                                    color: _colors.primary,
                                  ),
                                )
                              : ListView.separated(
                                  // 文档抽屉列表边距样式
                                  padding: const EdgeInsets.fromLTRB(
                                    10,
                                    10,
                                    10,
                                    18,
                                  ),
                                  itemCount: _activePackageNotes.length,
                                  separatorBuilder:
                                      (BuildContext context, int index) =>
                                          const SizedBox(height: 4),
                                  itemBuilder: (BuildContext context, int index) {
                                    final NoteItem note =
                                        _activePackageNotes[index];
                                    final bool isActive =
                                        note.relativePath ==
                                        _activeNote!.relativePath;

                                    return Material(
                                      // 文档抽屉单项材质样式
                                      color: isActive
                                          ? _colors.primaryContainer
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(6),
                                      child: InkWell(
                                        onTap: () {
                                          _handleSelectPackageNote(note);
                                        },
                                        borderRadius: BorderRadius.circular(6),
                                        child: Padding(
                                          // 文档抽屉单项边距样式
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 10,
                                          ),
                                          child: Row(
                                            // 文档抽屉单项横向布局样式
                                            children: <Widget>[
                                              Icon(
                                                Icons.description_outlined,
                                                color: isActive
                                                    ? _colors.onPrimaryContainer
                                                    : _colors.onSurfaceVariant,
                                                size: 20,
                                              ),
                                              const SizedBox(width: 10),
                                              Expanded(
                                                child: Text(
                                                  note.fileName,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  // 文档抽屉单项文件名样式
                                                  style: TextStyle(
                                                    color: isActive
                                                        ? _colors
                                                              .onPrimaryContainer
                                                        : _colors.onSurface,
                                                    fontSize: 15,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                              ),
                                              if (isActive)
                                                Icon(
                                                  Icons.check_rounded,
                                                  color: _colors
                                                      .onPrimaryContainer,
                                                  size: 20,
                                                ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /*
   * 根据彩色笔图标边界创建多色渐变。
   */
  Shader _createColorPenShader(Rect bounds) {
    return const LinearGradient(
      // 彩色笔图标渐变色样式
      colors: <Color>[
        Color(0xFFFF7043),
        Color(0xFFFFC107),
        Color(0xFF4CAF50),
        Color(0xFF29B6F6),
        Color(0xFF7E57C2),
      ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ).createShader(bounds);
  }

  /*
   * 构建编辑页底部工具栏的单个弹性入口。
   */
  Widget _buildEditorBottomToolbarEntry({
    required Key key,
    required String tooltip,
    required Widget icon,
  }) {
    return Expanded(
      child: Center(
        child: Tooltip(
          message: tooltip,
          child: IconButton(
            key: key,
            // 当前阶段只提供入口样式，暂不接入具体编辑操作。
            onPressed: null,
            // 底部工具栏入口点击区域样式
            style: IconButton.styleFrom(
              foregroundColor: _colors.onSurface,
              disabledForegroundColor: _colors.onSurface,
              fixedSize: const Size.square(48),
              padding: EdgeInsets.zero,
              shape: const CircleBorder(),
            ),
            icon: icon,
          ),
        ),
      ),
    );
  }

  /*
   * 构建会随软键盘上移的编辑页底部工具栏。
   */
  Widget _buildEditorBottomToolbar() {
    return Container(
      key: const ValueKey<String>('editor-bottom-toolbar'),
      // 编辑页底部工具栏背景与顶部分隔线样式
      decoration: BoxDecoration(
        color: _colors.surfaceContainerHigh,
        border: Border(top: BorderSide(color: _colors.outlineVariant)),
      ),
      child: SizedBox(
        // 编辑页底部工具栏固定高度样式
        height: 58,
        child: Row(
          // 四个入口使用弹性横向布局，适配不同屏幕宽度。
          children: <Widget>[
            _buildEditorBottomToolbarEntry(
              key: const ValueKey<String>('editor-bottom-toolbar-color'),
              tooltip: '文字颜色',
              icon: ShaderMask(
                shaderCallback: _createColorPenShader,
                blendMode: BlendMode.srcIn,
                child: const Icon(
                  Icons.colorize_rounded,
                  // 彩色笔图标基础颜色与尺寸样式
                  color: Colors.white,
                  size: 28,
                ),
              ),
            ),
            _buildEditorBottomToolbarEntry(
              key: const ValueKey<String>('editor-bottom-toolbar-undo'),
              tooltip: '撤销',
              icon: const Icon(
                Icons.undo_rounded,
                // 撤销入口图标尺寸样式
                size: 27,
              ),
            ),
            _buildEditorBottomToolbarEntry(
              key: const ValueKey<String>('editor-bottom-toolbar-redo'),
              tooltip: '重做',
              icon: const Icon(
                Icons.redo_rounded,
                // 重做入口图标尺寸样式
                size: 27,
              ),
            ),
            _buildEditorBottomToolbarEntry(
              key: const ValueKey<String>('editor-bottom-toolbar-add'),
              tooltip: '添加',
              icon: const Icon(
                Icons.add_circle_outline_rounded,
                // 添加入口图标尺寸样式
                size: 28,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /*
   * 构建编辑面板。
   */
  Widget _buildEditorPanel() {
    if (_activeNote == null) {
      return Center(
        child: Text(
          '还没有笔记包',
          // 空编辑区文字样式
          style: TextStyle(color: _colors.onSurfaceVariant, fontSize: 18),
        ),
      );
    }

    final bool isRenderingShareContent =
        _editorShareRenderMode != EditorShareRenderMode.none;
    final bool isRenderingPdf =
        _editorShareRenderMode == EditorShareRenderMode.pdf;

    return Container(
      // 编辑面板容器样式
      color: _colors.surfaceContainerLow,
      child: Stack(
        children: <Widget>[
          Column(
            children: <Widget>[
              Padding(
                // 编辑面板标题行独立边距样式
                padding: const EdgeInsets.fromLTRB(0, 14, 4, 0),
                child: Row(
                  // 编辑面板标题行横向布局样式
                  children: <Widget>[
                    IconButton(
                      padding: const EdgeInsets.fromLTRB(22, 0, 22, 0),
                      onPressed: _handleEditorBackButton,
                      icon: SvgPicture.asset(
                        'assets/icon/left_arrow.svg',
                        // 返回按钮 SVG 图标尺寸样式
                        width: 24,
                        height: 24,
                        // 返回按钮 SVG 图标主题颜色样式
                        colorFilter: ColorFilter.mode(
                          _colors.onSurface,
                          BlendMode.srcIn,
                        ),
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      key: _editorShareButtonKey,
                      tooltip: '分享当前文档',
                      onPressed: _isShareOperationInProgress
                          ? null
                          : () {
                              _showEditorActionMenu(EditorActionMenuType.share);
                            },
                      icon: const Icon(Icons.share_outlined),
                      color: _colors.onSurface,
                    ),
                    IconButton(
                      key: _editorMoreMenuButtonKey,
                      tooltip: '更多操作',
                      onPressed: _isShareOperationInProgress
                          ? null
                          : () {
                              _showEditorActionMenu(EditorActionMenuType.more);
                            },
                      icon: const Icon(Icons.more_vert_rounded),
                      color: _colors.onSurface,
                    ),
                  ],
                ),
              ),
              MarkdownToolbar(
                controller: _editorController.quillController,
                focusNode: _editorFocusNode,
                customizationController: _toolbarCustomizationController,
                onPressedAction: _handleToolbarAction,
                initialActionKeys: _toolbarActionKeys,
                onActionKeysChanged: _handleToolbarActionKeysChanged,
                onCustomizationChanged: _handleToolbarCustomizationChanged,
              ),
              Expanded(
                child: RepaintBoundary(
                  key: _editorShareCaptureKey,
                  child: ColoredBox(
                    // PDF 使用透明截图背景，长图与编辑页继续使用当前主题背景。
                    color: isRenderingPdf
                        ? Colors.transparent
                        : _colors.surfaceContainerLow,
                    child: Padding(
                      // 分享成品增加左右留白，普通编辑状态保持原正文边距。
                      padding: isRenderingShareContent
                          ? const EdgeInsets.symmetric(horizontal: 32)
                          : const EdgeInsets.fromLTRB(22, 0, 22, 8),
                      child: _isToolbarCustomizing
                          ? ColoredBox(
                              // 工具仓库显示期间正文区域背景样式
                              color: _colors.surfaceContainerLow,
                            )
                          : Theme(
                              data: isRenderingPdf
                                  ? AppTheme.lightTheme
                                  : Theme.of(context),
                              child: WysiwygMarkdownEditor(
                                controller: _editorController.quillController,
                                focusNode: _editorFocusNode,
                                scrollController: _editorScrollController,
                                metadataText: _buildEditorMetadataText(),
                                onDeleteCodeBlock: _deleteMarkdownCodeBlock,
                              ),
                            ),
                    ),
                  ),
                ),
              ),
              _buildEditorBottomToolbar(),
            ],
          ),
          _buildPackageDrawerRail(),
          _buildPackageDrawerOverlay(),
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
          Container(width: 1, color: _colors.outlineVariant),
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
        backgroundColor: _colors.surface,
        body: Stack(
          // 页面内容与系统底部安全区背景分层布局样式
          children: <Widget>[
            Positioned.fill(
              child: _isLoading
                  ? Center(
                      child: CircularProgressIndicator(color: _colors.primary),
                    )
                  : SafeArea(child: _buildBody()),
            ),
            Positioned(
              // 系统底部手势区背景定位样式
              left: 0,
              right: 0,
              bottom: 0,
              child: SizedBox(
                // 系统底部手势区背景高度样式，键盘弹出后会自动收起。
                height: MediaQuery.paddingOf(context).bottom,
                child: ColoredBox(
                  // 系统底部手势区背景色与编辑工具栏保持一致。
                  color: _colors.surfaceContainerHigh,
                ),
              ),
            ),
          ],
        ),
        floatingActionButton:
            _isSelectionMode || (!isWideLayout && !_isCompactBrowserVisible)
            ? null
            : FloatingActionButton(
                tooltip: '新建笔记包',
                onPressed: () {
                  final double width = MediaQuery.of(context).size.width;
                  _handleCreateNote(isWideLayout: width >= 980);
                },
                backgroundColor: _colors.primary,
                foregroundColor: _colors.onPrimary,
                shape: const CircleBorder(),
                child: const Icon(Icons.add, size: 34),
              ),
      ),
    );
  }
}
