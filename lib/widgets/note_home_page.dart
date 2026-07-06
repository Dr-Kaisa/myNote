/*
 * 文件说明：笔记主页组件文件，负责组织笔记首页、文件夹视图、选择模式、移动面板与编辑区交互。
 */
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:my_note/models/note_item.dart';
import 'package:my_note/services/note_storage_service.dart';
import 'package:my_note/utils/markdown_helper.dart';
import 'package:my_note/widgets/markdown_toolbar.dart';

/*
 * 首页分类项数据模型。
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
   */
  final String id;

  /*
   * 分类显示文案。
   */
  final String label;

  /*
   * 是否为“全部笔记”分类。
   */
  final bool isAllNotes;
}

/*
 * 首页网格项类型。
 */
enum NoteGridItemType { folder, note }

/*
 * 首页网格项数据模型。
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
   */
  final String id;

  /*
   * 网格项类型。
   */
  final NoteGridItemType type;

  /*
   * 网格项主标题。
   */
  final String title;

  /*
   * 网格项辅助内容。
   */
  final String subtitle;

  /*
   * 网格项相对位置信息。
   */
  final String locationText;

  /*
   * 关联的笔记对象。
   */
  final NoteItem? note;

  /*
   * 文件夹下的笔记数量。
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
 * 笔记主页状态对象。
 */
class _NoteHomePageState extends State<NoteHomePage> {
  /*
   * 笔记存储服务实例。
   */
  final NoteStorageService _noteStorageService = NoteStorageService();

  /*
   * 编辑器控制器。
   */
  final TextEditingController _editorController = TextEditingController();

  /*
   * 编辑器焦点控制器。
   */
  final FocusNode _editorFocusNode = FocusNode();

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
      final List<NoteItem> notes = await _noteStorageService.loadNotes();
      final List<String> folderPaths = await _noteStorageService
          .loadFolderPaths();

      if (!mounted) {
        return;
      }

      setState(() {
        _notes = notes;
        _folderPaths = folderPaths;
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
   * 获取首页分类集合。
   */
  List<NoteCategoryItem> _buildCategories() {
    final Set<String> tags = <String>{};

    for (final NoteItem note in _notes) {
      tags.addAll(note.tags);
    }

    final List<String> sortedTags = tags.toList()..sort();

    return <NoteCategoryItem>[
      const NoteCategoryItem(id: 'all', label: '笔记', isAllNotes: true),
      ...sortedTags.map(
        (String tag) =>
            NoteCategoryItem(id: tag, label: tag, isAllNotes: false),
      ),
    ];
  }

  /*
   * 获取当前分类下展示的笔记列表。
   */
  List<NoteItem> _getVisibleNotes() {
    if (_activeCategoryId == 'all') {
      return _notes;
    }

    return _notes
        .where((NoteItem note) => note.tags.contains(_activeCategoryId))
        .toList();
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

    return directories.toList()..sort();
  }

  /*
   * 获取指定目录下的直接笔记集合。
   */
  List<NoteItem> _getDirectNotes(List<NoteItem> notes, String directoryPath) {
    return notes
        .where((NoteItem note) => note.directoryPath == directoryPath)
        .toList()
      ..sort(
        (NoteItem left, NoteItem right) =>
            right.updatedAt.compareTo(left.updatedAt),
      );
  }

  /*
   * 获取文件夹下的笔记总数。
   */
  int _getFolderNoteCount(String folderPath) {
    return _notes
        .where(
          (NoteItem note) =>
              note.directoryPath == folderPath ||
              note.directoryPath.startsWith('$folderPath/'),
        )
        .length;
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
        items.add(
          NoteGridItem(
            id: 'folder:$nextPath',
            type: NoteGridItemType.folder,
            title: directoryName,
            subtitle: '${_getFolderNoteCount(nextPath)}',
            locationText: nextPath,
            noteCount: _getFolderNoteCount(nextPath),
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

    return visibleNotes
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
        .toList()
      ..sort((NoteGridItem left, NoteGridItem right) {
        final DateTime leftTime =
            left.note?.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final DateTime rightTime =
            right.note?.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return rightTime.compareTo(leftTime);
      });
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
      _activeCategoryId = categoryId;
      _activeDirectoryPath = '';
      _exitSelectionMode();
    });
  }

  /*
   * 切换当前目录。
   */
  void _handleDirectoryChanged(String directoryPath) {
    setState(() {
      _activeDirectoryPath = directoryPath;
      _exitSelectionMode();
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
   * 进入选择模式。
   */
  void _enterSelectionMode(String itemId) {
    setState(() {
      _isSelectionMode = true;
      _selectedItemIds = <String>{itemId};
    });
  }

  /*
   * 退出选择模式。
   */
  void _exitSelectionMode() {
    _isSelectionMode = false;
    _selectedItemIds = <String>{};
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
      _isSelectionMode = nextSelectedItemIds.isNotEmpty;
    });
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
      final NoteItem savedNote = await _noteStorageService.saveNoteContent(
        _activeNote!.relativePath,
        content,
      );

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
              ..sort(
                (NoteItem left, NoteItem right) =>
                    right.updatedAt.compareTo(left.updatedAt),
              );

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
    final List<NoteCategoryItem> categories = _buildCategories();

    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 22, 28, 0),
      child: Row(
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
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: categories.map((NoteCategoryItem category) {
                  final bool isActive = _activeCategoryId == category.id;
                  return GestureDetector(
                    onTap: () {
                      _handleCategoryChanged(category.id);
                    },
                    child: Padding(
                      padding: const EdgeInsets.only(right: 26),
                      child: Row(
                        children: <Widget>[
                          Text(
                            category.isAllNotes ? '笔记' : category.label,
                            // 顶部分类文字样式
                            style: TextStyle(
                              color: isActive
                                  ? const Color(0xFF111111)
                                  : const Color(0xFF9A9A9A),
                              fontSize: 34,
                              fontWeight: isActive
                                  ? FontWeight.w800
                                  : FontWeight.w500,
                            ),
                          ),
                          if (category.isAllNotes)
                            const Padding(
                              padding: EdgeInsets.only(left: 4, top: 4),
                              child: Icon(
                                Icons.keyboard_arrow_down_rounded,
                                color: Color(0xFF111111),
                                size: 26,
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded, color: Color(0xFF1F1F1F)),
            onSelected: (String value) {
              if (value == 'note') {
                _handleCreateNote(isWideLayout: isWideLayout);
              }
              if (value == 'folder') {
                _handleCreateFolder();
              }
            },
            itemBuilder: (BuildContext menuContext) {
              return const <PopupMenuEntry<String>>[
                PopupMenuItem<String>(value: 'note', child: Text('新建笔记')),
                PopupMenuItem<String>(value: 'folder', child: Text('新建文件夹')),
              ];
            },
          ),
        ],
      ),
    );
  }

  /*
   * 构建选择模式顶部栏区域。
   */
  Widget _buildSelectionTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              IconButton(
                onPressed: () {
                  setState(_exitSelectionMode);
                },
                icon: const Icon(Icons.close_rounded),
                color: const Color(0xFF222222),
                iconSize: 34,
              ),
              const Spacer(),
              IconButton(
                onPressed: _selectAllVisibleItems,
                icon: const Icon(Icons.checklist_rounded),
                color: const Color(0xFF222222),
                iconSize: 30,
              ),
            ],
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Text(
              '已选择${_selectedItemIds.length}项',
              // 选择模式标题样式
              style: const TextStyle(
                color: Color(0xFF222222),
                fontSize: 36,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /*
   * 构建搜索栏。
   */
  Widget _buildSearchBar() {
    if (_isSelectionMode) {
      return const SizedBox(height: 20);
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 28, 28, 0),
      child: Container(
        height: 60,
        decoration: BoxDecoration(
          // 搜索栏容器样式
          color: const Color(0xFFEDEDED),
          borderRadius: BorderRadius.circular(30),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 22),
        child: const Row(
          children: <Widget>[
            Icon(Icons.search_rounded, color: Color(0xFF8F8F8F), size: 26),
            SizedBox(width: 14),
            Text(
              '搜索笔记',
              // 搜索栏占位文字样式
              style: TextStyle(color: Color(0xFF9B9B9B), fontSize: 18),
            ),
          ],
        ),
      ),
    );
  }

  /*
   * 构建统计条。
   */
  Widget _buildSummaryBar() {
    if (_isSelectionMode) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 16, 28, 0),
      child: Container(
        height: 60,
        decoration: BoxDecoration(
          // 统计条容器样式
          color: const Color(0xFFEDEDED),
          borderRadius: BorderRadius.circular(18),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Text(
                '${_notes.length} 条笔记，${_folderPaths.length} 个文件夹',
                // 统计条主文字样式
                style: const TextStyle(
                  color: Color(0xFF555555),
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const Text(
              '本地 Markdown',
              // 统计条辅助文字样式
              style: TextStyle(color: Color(0xFF9A9A9A), fontSize: 15),
            ),
          ],
        ),
      ),
    );
  }

  /*
   * 构建目录路径栏。
   */
  Widget _buildPathBar() {
    if (_activeCategoryId != 'all') {
      return Padding(
        padding: const EdgeInsets.fromLTRB(30, 14, 30, 0),
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
      padding: const EdgeInsets.fromLTRB(30, 14, 30, 0),
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
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        // 选择圆点容器样式
        color: isSelected ? const Color(0xFFFFC000) : const Color(0xFFF3F3F3),
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFFE1E1E1)),
      ),
      child: isSelected
          ? const Icon(Icons.check_rounded, color: Colors.white, size: 22)
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
    const double horizontalPadding = 56;
    const double itemSpacing = 14;
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
   * 构建文件夹卡片。
   */
  Widget _buildFolderCard(NoteGridItem item) {
    final bool isSelected = _selectedItemIds.contains(item.id);

    return GestureDetector(
      onTap: () {
        if (_isSelectionMode) {
          _toggleSelectedItem(item.id);
          return;
        }

        _handleDirectoryChanged(item.locationText);
      },
      onLongPress: () {
        _enterSelectionMode(item.id);
      },
      child: Container(
        // 文件夹卡片容器样式
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: Color(0x0F000000),
              blurRadius: 18,
              offset: Offset(0, 8),
            ),
          ],
        ),
        padding: const EdgeInsets.all(22),
        child: Row(
          children: <Widget>[
            _buildFolderIcon(),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                // 文件夹文字纵向布局样式
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    // 文件夹标题样式
                    style: const TextStyle(
                      color: Color(0xFF111111),
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.subtitle,
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
            if (_isSelectionMode) _buildSelectionCircle(isSelected),
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
      onTap: () {
        _handleSelectNote(note, isWideLayout: isWideLayout);
      },
      onLongPress: () {
        _enterSelectionMode(item.id);
      },
      child: Container(
        // 笔记卡片容器样式
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
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
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  // 笔记卡片标题样式
                  style: const TextStyle(
                    color: Color(0xFF111111),
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: Text(
                    note.preview,
                    maxLines: 5,
                    overflow: TextOverflow.ellipsis,
                    // 笔记卡片摘要样式
                    style: const TextStyle(
                      color: Color(0xFF666666),
                      fontSize: 18,
                      height: 1.5,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '${note.updatedAt.month}月${note.updatedAt.day}日',
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
   * 构建首页网格视图。
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
          : LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final double itemWidth = _getBrowserItemWidth(
                  availableWidth: constraints.maxWidth,
                  isWideLayout: isWideLayout,
                );

                return SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    28,
                    _isSelectionMode ? 0 : 18,
                    28,
                    _isSelectionMode ? 100 : 108,
                  ),
                  child: Wrap(
                    // 首页网格自适应换行布局样式
                    spacing: 14,
                    runSpacing: 14,
                    children: gridItems.map((NoteGridItem item) {
                      return SizedBox(
                        width: itemWidth,
                        height: _getBrowserItemHeight(
                          item: item,
                          itemWidth: itemWidth,
                          isWideLayout: isWideLayout,
                        ),
                        child: item.type == NoteGridItemType.folder
                            ? _buildFolderCard(item)
                            : _buildNoteCard(item, isWideLayout: isWideLayout),
                      );
                    }).toList(),
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
      children: <Widget>[
        Column(
          // 首页内容纵向布局样式
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _isSelectionMode
                ? _buildSelectionTopBar()
                : _buildNormalTopBar(isWideLayout: isWideLayout),
            _buildSearchBar(),
            _buildSummaryBar(),
            _buildPathBar(),
            _buildBrowserPanel(isWideLayout: isWideLayout),
          ],
        ),
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
        backgroundColor: const Color(0xFFF6F6F6),
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
