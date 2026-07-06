/*
 * 文件说明：Flutter 应用入口文件，负责启动 myNote 笔记原型。
 */
import 'package:flutter/material.dart';
import 'package:my_note/services/file_permission_service.dart';
import 'package:my_note/widgets/note_home_page.dart';

/*
 * 应用启动入口方法。
 */
void main() {
  runApp(const MyNoteApp());
}

/*
 * 应用根组件。
 */
class MyNoteApp extends StatelessWidget {
  /*
   * 根组件构造方法。
   */
  const MyNoteApp({super.key});

  /*
   * 构建应用根节点。
   */
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'myNote',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFF3B12E)),
        scaffoldBackgroundColor: const Color(0xFFF5F6FA),
        useMaterial3: true,
      ),
      home: const FilePermissionGate(child: NoteHomePage()),
    );
  }
}

/*
 * 文件权限门禁组件。
 */
class FilePermissionGate extends StatefulWidget {
  /*
   * 文件权限门禁构造方法。
   */
  const FilePermissionGate({required this.child, super.key});

  /*
   * 已获得权限后展示的页面。
   */
  final Widget child;

  /*
   * 创建文件权限门禁状态对象。
   */
  @override
  State<FilePermissionGate> createState() => _FilePermissionGateState();
}

/*
 * 文件权限门禁状态对象。
 */
class _FilePermissionGateState extends State<FilePermissionGate>
    with WidgetsBindingObserver {
  /*
   * 文件权限服务实例。
   */
  final FilePermissionService _filePermissionService = FilePermissionService();

  /*
   * 是否已经具备所有文件访问权限。
   */
  bool _hasAllFilesAccess = false;

  /*
   * 是否正在检查或打开权限设置。
   */
  bool _isCheckingPermission = true;

  /*
   * 是否已经自动打开过一次权限设置。
   */
  bool _hasRequestedAllFilesAccess = false;

  /*
   * 当前权限状态提示。
   */
  String _permissionStatusText = '正在检查文件权限...';

  /*
   * 初始化权限检查监听。
   */
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAllFilesPermission(requestIfNeeded: true);
    });
  }

  /*
   * 页面销毁前移除权限检查监听。
   */
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /*
   * 从系统设置回到应用时重新检查权限。
   */
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_hasAllFilesAccess) {
      _checkAllFilesPermission(requestIfNeeded: false);
    }
  }

  /*
   * 检查所有文件访问权限，并在需要时打开系统授权页。
   */
  Future<void> _checkAllFilesPermission({required bool requestIfNeeded}) async {
    if (!mounted) {
      return;
    }

    setState(() {
      _isCheckingPermission = true;
      _permissionStatusText = '正在检查文件权限...';
    });

    try {
      final bool hasPermission = await _filePermissionService
          .hasAllFilesAccess();

      if (!mounted) {
        return;
      }

      if (hasPermission) {
        setState(() {
          _hasAllFilesAccess = true;
          _isCheckingPermission = false;
          _permissionStatusText = '已获得文件权限';
        });
        return;
      }

      setState(() {
        _hasAllFilesAccess = false;
        _isCheckingPermission = false;
        _permissionStatusText = '需要授权后才能访问 myNote 文件夹';
      });

      if (requestIfNeeded && !_hasRequestedAllFilesAccess) {
        _hasRequestedAllFilesAccess = true;
        await _requestAllFilesPermission();
      }
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _hasAllFilesAccess = false;
        _isCheckingPermission = false;
        _permissionStatusText = '权限检查失败，请重试';
      });
    }
  }

  /*
   * 打开系统所有文件访问权限授权页。
   */
  Future<void> _requestAllFilesPermission() async {
    if (!mounted) {
      return;
    }

    setState(() {
      _isCheckingPermission = true;
      _permissionStatusText = '正在打开系统权限设置...';
    });

    try {
      await _filePermissionService.requestAllFilesAccess();
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isCheckingPermission = false;
        _permissionStatusText = '无法打开权限设置，请重试';
      });
      return;
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _isCheckingPermission = false;
      _permissionStatusText = '请在系统设置中开启所有文件访问权限';
    });
  }

  /*
   * 处理手动授权按钮点击。
   */
  Future<void> _handlePermissionButtonPressed() async {
    _hasRequestedAllFilesAccess = true;
    await _requestAllFilesPermission();
  }

  /*
   * 构建权限等待页面。
   */
  Widget _buildPermissionPage() {
    return Scaffold(
      // 权限页背景色样式
      backgroundColor: const Color(0xFFF6F6F6),
      body: SafeArea(
        child: Center(
          child: Padding(
            // 权限页内容外边距样式
            padding: const EdgeInsets.all(24),
            child: Column(
              // 权限页内容纵向布局样式
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Icon(
                  Icons.folder_open_rounded,
                  // 权限页图标颜色样式
                  color: Color(0xFFFFC000),
                  size: 72,
                ),
                const SizedBox(height: 18),
                const Text(
                  '需要所有文件权限',
                  textAlign: TextAlign.center,
                  // 权限页标题文字样式
                  style: TextStyle(
                    color: Color(0xFF111111),
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  _permissionStatusText,
                  textAlign: TextAlign.center,
                  // 权限页状态文字样式
                  style: const TextStyle(
                    color: Color(0xFF666666),
                    fontSize: 15,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _isCheckingPermission
                      ? null
                      : _handlePermissionButtonPressed,
                  // 权限页授权按钮样式
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFC000),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 28,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                  ),
                  child: Text(_isCheckingPermission ? '正在检查...' : '去授权'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /*
   * 构建文件权限门禁页面。
   */
  @override
  Widget build(BuildContext context) {
    if (_hasAllFilesAccess) {
      return widget.child;
    }

    return _buildPermissionPage();
  }
}
