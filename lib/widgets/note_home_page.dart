/*
 * 文件说明：笔记主页组件文件，负责组织笔记列表、编辑区与交互状态。
 */
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:my_note/models/note_item.dart';
import 'package:my_note/services/note_storage_service.dart';
import 'package:my_note/utils/markdown_helper.dart';
import 'package:my_note/widgets/markdown_toolbar.dart';

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
   * 当前选中的笔记。
   */
  NoteItem? _activeNote;

  /*
   * 是否处于数据加载中。
   */
  bool _isLoading = true;

  /*
   * 保存状态文案。
   */
  String _saveStatusText = '正在加载...';

  /*
   * 小屏下是否展示列表区域。
   */
  bool _isCompactListVisible = true;

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
   * 初始化笔记列表，并自动选中第一条笔记。
   */
  Future<void> _initializeNotes() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final List<NoteItem> notes = await _noteStorageService.loadNotes();

      if (!mounted) {
        return;
      }

      setState(() {
        _notes = notes;
        _activeNote = notes.isNotEmpty ? notes.first : null;
        _editorController.text = notes.isNotEmpty ? notes.first.content : '';
        _editorController.selection = TextSelection.collapsed(offset: _editorController.text.length);
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
      _editorController.selection = TextSelection.collapsed(offset: _editorController.text.length);
      _saveStatusText = '已保存';
      if (!isWideLayout) {
        _isCompactListVisible = false;
      }
    });
  }

  /*
   * 创建新的笔记。
   */
  Future<void> _handleCreateNote({required bool isWideLayout}) async {
    try {
      final NoteItem nextNote = await _noteStorageService.createNote();

      if (!mounted) {
        return;
      }

      setState(() {
        _notes = <NoteItem>[nextNote, ..._notes]..sort((NoteItem left, NoteItem right) => right.updatedAt.compareTo(left.updatedAt));
      });

      _activateNote(nextNote, isWideLayout: isWideLayout);
      _editorFocusNode.requestFocus();
    } catch (error) {
      await _showMessageDialog('创建失败', error.toString());
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
      final NoteItem deletingNote = _activeNote!;
      await _noteStorageService.deleteNote(deletingNote.fileName);

      if (!mounted) {
        return;
      }

      final List<NoteItem> remainingNotes = _notes.where((NoteItem item) => item.id != deletingNote.id).toList();

      setState(() {
        _notes = remainingNotes;

        if (remainingNotes.isNotEmpty) {
          _activeNote = remainingNotes.first;
          _editorController.text = remainingNotes.first.content;
          _editorController.selection = TextSelection.collapsed(offset: _editorController.text.length);
          _saveStatusText = '已保存';
          if (!isWideLayout) {
            _isCompactListVisible = false;
          }
        } else {
          _activeNote = null;
          _editorController.clear();
          _saveStatusText = '没有可编辑的笔记';
          _isCompactListVisible = true;
        }
      });
    } catch (error) {
      await _showMessageDialog('删除失败', error.toString());
    }
  }

  /*
   * 选择指定笔记并保存当前编辑内容。
   */
  Future<void> _handleSelectNote(NoteItem note, {required bool isWideLayout}) async {
    if (_activeNote != null && _activeNote!.id != note.id) {
      await _persistActiveNote(_editorController.text);
    }

    if (!mounted) {
      return;
    }

    _activateNote(note, isWideLayout: isWideLayout);
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
      final NoteItem savedNote = await _noteStorageService.saveNoteContent(_activeNote!.fileName, content);

      if (!mounted) {
        return;
      }

      setState(() {
        _activeNote = savedNote;
        _notes = _notes
            .map((NoteItem item) => item.id == savedNote.id ? savedNote : item)
            .toList()
          ..sort((NoteItem left, NoteItem right) => right.updatedAt.compareTo(left.updatedAt));
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
        result = applyLinePrefixSyntax(_editorController.text, selection, '## ');
      case ToolbarActionKey.bold:
        result = applyWrapSyntax(_editorController.text, selection, '**', '**', '加粗内容');
      case ToolbarActionKey.list:
        result = applyLinePrefixSyntax(_editorController.text, selection, '- ');
      case ToolbarActionKey.todo:
        result = applyLinePrefixSyntax(_editorController.text, selection, '- [ ] ');
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
   * 构建单条笔记卡片。
   */
  Widget _buildNoteCard(NoteItem note, {required bool isWideLayout}) {
    final bool isActive = _activeNote?.id == note.id;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () {
          _handleSelectNote(note, isWideLayout: isWideLayout);
        },
        child: Container(
          // 笔记卡片容器样式
          decoration: BoxDecoration(
            color: isActive ? const Color(0xFFFFE9AF) : const Color(0xFFFFF8E8),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isActive ? const Color(0xFFF1C862) : const Color(0xFFF4E1B6),
            ),
          ),
          padding: const EdgeInsets.all(14),
          child: Column(
            // 笔记卡片内容纵向布局样式
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                note.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                // 笔记卡片标题样式
                style: const TextStyle(
                  color: Color(0xFF2B2F38),
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                note.preview,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                // 笔记卡片摘要样式
                style: const TextStyle(
                  color: Color(0xFF5A6071),
                  fontSize: 13,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                formatNoteTime(note.updatedAt),
                // 笔记卡片时间样式
                style: const TextStyle(
                  color: Color(0xFF8A91A4),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /*
   * 构建顶部栏区域。
   */
  Widget _buildTopBar({required bool isWideLayout}) {
    return Container(
      // 顶部栏容器样式
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Color(0xFFE6E8F0)),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        // 顶部栏横向布局样式
        children: <Widget>[
          Expanded(
            child: Row(
              children: <Widget>[
                if (!isWideLayout && !_isCompactListVisible)
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: OutlinedButton(
                      onPressed: () {
                        setState(() {
                          _isCompactListVisible = true;
                        });
                      },
                      style: OutlinedButton.styleFrom(
                        // 顶部返回列表按钮样式
                        minimumSize: const Size(64, 36),
                        side: const BorderSide(color: Color(0xFFD9DDEA)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('列表'),
                    ),
                  ),
                const Expanded(
                  child: Column(
                    // 顶部标题区纵向布局样式
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'myNote',
                        // 顶部标题样式
                        style: TextStyle(
                          color: Color(0xFF1C2333),
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Markdown 笔记原型',
                        // 顶部副标题样式
                        style: TextStyle(
                          color: Color(0xFF81879A),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Row(
            // 顶部操作按钮横向布局样式
            children: <Widget>[
              FilledButton(
                onPressed: () {
                  _handleCreateNote(isWideLayout: isWideLayout);
                },
                style: FilledButton.styleFrom(
                  // 新建按钮样式
                  backgroundColor: const Color(0xFFFFB93A),
                  foregroundColor: const Color(0xFF452B00),
                  minimumSize: const Size(70, 40),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('新建'),
              ),
              const SizedBox(width: 10),
              OutlinedButton(
                onPressed: _activeNote == null
                    ? null
                    : () {
                        _handleDeleteNote(isWideLayout: isWideLayout);
                      },
                style: OutlinedButton.styleFrom(
                  // 删除按钮样式
                  minimumSize: const Size(70, 40),
                  side: const BorderSide(color: Color(0xFFD9DDEA)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('删除'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /*
   * 构建列表面板。
   */
  Widget _buildListPanel({required bool isWideLayout}) {
    return Container(
      // 列表面板容器样式
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE6E8F0)),
      ),
      child: Column(
        // 列表面板纵向布局样式
        children: <Widget>[
          Container(
            // 列表面板头部样式
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Color(0xFFEEF0F6)),
              ),
            ),
            child: Row(
              children: <Widget>[
                const Expanded(
                  child: Text(
                    '全部笔记',
                    // 列表面板标题样式
                    style: TextStyle(
                      color: Color(0xFF1C2333),
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  '${_notes.length} 条',
                  // 列表面板辅助文字样式
                  style: const TextStyle(
                    color: Color(0xFF8A91A4),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(12),
              children: _notes.map((NoteItem note) => _buildNoteCard(note, isWideLayout: isWideLayout)).toList(),
            ),
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
      return Container(
        // 空状态面板样式
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE6E8F0)),
        ),
        child: const Center(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              // 空状态内容纵向布局样式
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Text(
                  '还没有笔记',
                  // 空状态标题样式
                  style: TextStyle(
                    color: Color(0xFF1C2333),
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 10),
                Text(
                  '点击右上角“新建”后，会生成一个新的 .md 文件作为笔记实体。',
                  textAlign: TextAlign.center,
                  // 空状态说明样式
                  style: TextStyle(
                    color: Color(0xFF6B7285),
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      // 编辑面板容器样式
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE6E8F0)),
      ),
      child: Column(
        // 编辑面板纵向布局样式
        children: <Widget>[
          Container(
            // 编辑面板头部样式
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Color(0xFFEEF0F6)),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  _activeNote!.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  // 编辑面板标题样式
                  style: const TextStyle(
                    color: Color(0xFF1C2333),
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${formatNoteTime(_activeNote!.updatedAt)} · $_saveStatusText',
                  // 编辑面板辅助信息样式
                  style: const TextStyle(
                    color: Color(0xFF8A91A4),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          MarkdownToolbar(
            onPressedAction: _handleToolbarAction,
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
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
                  hintStyle: TextStyle(
                    color: Color(0xFFA7AAB7),
                  ),
                  border: InputBorder.none,
                  isCollapsed: true,
                ),
                style: const TextStyle(
                  // 编辑器输入文字样式
                  color: Color(0xFF1F2430),
                  fontSize: 16,
                  height: 1.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /*
   * 构建页面主体内容。
   */
  Widget _buildBody() {
    final double width = MediaQuery.of(context).size.width;
    final bool isWideLayout = width >= 920;

    if (isWideLayout && _isCompactListVisible == false) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _isCompactListVisible = true;
          });
        }
      });
    }

    return Column(
      // 页面主体纵向布局样式
      children: <Widget>[
        _buildTopBar(isWideLayout: isWideLayout),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: isWideLayout
                ? Row(
                    // 宽屏双栏布局样式
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      SizedBox(
                        width: 320,
                        child: _buildListPanel(isWideLayout: isWideLayout),
                      ),
                      const SizedBox(width: 16),
                      Expanded(child: _buildEditorPanel()),
                    ],
                  )
                : _isCompactListVisible
                    ? _buildListPanel(isWideLayout: isWideLayout)
                    : _buildEditorPanel(),
          ),
        ),
      ],
    );
  }

  /*
   * 构建主页组件。
   */
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : SafeArea(
              child: _buildBody(),
            ),
    );
  }
}


