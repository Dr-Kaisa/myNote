/*
 * 文件说明：Flutter 应用入口文件，负责启动 myNote 笔记原型。
 *
 * 对 Flutter 不熟时可以先看这个文件：
 * 1. main 方法是程序入口，类似普通程序里的启动函数。
 * 2. MyNoteApp 是整个应用最外层的界面配置。
 * 3. FilePermissionGate 是权限门禁，没权限时先显示授权页，有权限后才显示笔记主页。
 */
import 'package:flutter/material.dart';
import 'package:my_note/services/file_permission_service.dart';
import 'package:my_note/widgets/note_home_page.dart';

/*
 * 应用启动入口方法。
 *
 * runApp 会把一个 Widget 挂到屏幕上。
 * Widget 可以理解成 Flutter 的“界面积木”，整个页面就是很多 Widget 嵌套出来的。
 */
void main() {
  runApp(const MyNoteApp());
}

/*
 * 应用根组件。
 *
 * StatelessWidget 表示这个组件自身不保存会变化的状态。
 * 它只根据 build 方法里写的配置生成界面。
 */
class MyNoteApp extends StatelessWidget {
  /*
   * 根组件构造方法。
   */
  const MyNoteApp({super.key});

  /*
   * 构建应用根节点。
   *
   * build 是 Flutter 组件最核心的方法。
   * Flutter 会调用 build，把这里返回的 Widget 树渲染到屏幕上。
   */
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      // 应用名称，主要给系统或调试工具识别，不一定直接显示在页面上。
      title: 'myNote',
      // 关闭右上角 debug 标识，让调试包界面看起来接近正式应用。
      debugShowCheckedModeBanner: false,
      // ThemeData 是全局主题配置，负责默认颜色、Material 版本等基础样式。
      theme: ThemeData(
        // 从黄色种子色生成一套 Material 颜色。
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFF3B12E)),
        // 全局 Scaffold 默认背景色。
        scaffoldBackgroundColor: const Color(0xFFF5F6FA),
        // 启用 Material 3 风格组件。
        useMaterial3: true,
      ),
      // home 是应用打开后的第一个页面；这里先进入权限门禁，再进入笔记主页。
      home: const FilePermissionGate(child: NoteHomePage()),
    );
  }
}

/*
 * 文件权限门禁组件。
 *
 * StatefulWidget 表示这个组件有会变化的状态。
 * 这里的状态就是“有没有文件权限”“是否正在检查权限”等。
 */
class FilePermissionGate extends StatefulWidget {
  /*
   * 文件权限门禁构造方法。
   */
  const FilePermissionGate({required this.child, super.key});

  /*
   * 已获得权限后展示的页面。
   *
   * Widget 类型表示这里可以传入任意界面组件。
   * 当前传入的是 NoteHomePage，也就是笔记主页。
   */
  final Widget child;

  /*
   * 创建文件权限门禁状态对象。
   *
   * Flutter 会把界面配置类 FilePermissionGate 和真正保存状态的
   * _FilePermissionGateState 分开，方便状态变化时只刷新需要刷新的部分。
   */
  @override
  State<FilePermissionGate> createState() => _FilePermissionGateState();
}

/*
 * 文件权限门禁状态对象。
 *
 * State 里放会变化的数据和处理逻辑。
 * WidgetsBindingObserver 用来监听应用生命周期，比如从系统设置返回应用。
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
   *
   * initState 只会在组件第一次创建时执行一次，适合放初始化逻辑。
   */
  @override
  void initState() {
    super.initState();
    // 注册生命周期监听，这样从系统权限页回到应用时可以重新检查权限。
    WidgetsBinding.instance.addObserver(this);
    // 等第一帧界面准备好后再检查权限，避免初始化阶段直接触发布局相关操作。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAllFilesPermission(requestIfNeeded: true);
    });
  }

  /*
   * 页面销毁前移除权限检查监听。
   *
   * dispose 在组件被移除时执行，用来释放监听、控制器等资源。
   */
  @override
  void dispose() {
    // 移除监听，避免页面销毁后还收到生命周期回调。
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /*
   * 从系统设置回到应用时重新检查权限。
   *
   * AppLifecycleState.resumed 表示应用重新回到前台。
   */
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 用户可能刚在系统设置里打开了权限，所以回到前台时再查一次。
    if (state == AppLifecycleState.resumed && !_hasAllFilesAccess) {
      _checkAllFilesPermission(requestIfNeeded: false);
    }
  }

  /*
   * 检查所有文件访问权限，并在需要时打开系统授权页。
   */
  Future<void> _checkAllFilesPermission({required bool requestIfNeeded}) async {
    // mounted 表示当前 State 还在页面树里；异步代码回来后必须先判断，避免操作已销毁页面。
    if (!mounted) {
      return;
    }

    // setState 会告诉 Flutter：这些状态变了，请重新执行 build 刷新界面。
    setState(() {
      _isCheckingPermission = true;
      _permissionStatusText = '正在检查文件权限...';
    });

    try {
      // 通过服务类调用 Android 原生能力，判断是否已有所有文件访问权限。
      final bool hasPermission = await _filePermissionService
          .hasAllFilesAccess();

      // await 之后页面可能已被关闭，所以再次检查 mounted。
      if (!mounted) {
        return;
      }

      if (hasPermission) {
        // 有权限时允许进入真正的笔记主页。
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
        // 首次进入且缺少权限时，自动打开一次系统授权页。
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

    // 打开系统设置前先更新页面文案，给用户反馈。
    setState(() {
      _isCheckingPermission = true;
      _permissionStatusText = '正在打开系统权限设置...';
    });

    try {
      // 真正打开系统权限页面的逻辑在 FilePermissionService 里。
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
    // 手动点击按钮后也标记已经请求过，避免后续重复自动弹设置页。
    _hasRequestedAllFilesAccess = true;
    await _requestAllFilesPermission();
  }

  /*
   * 构建权限等待页面。
   *
   * Scaffold 是 Flutter 常用的页面骨架，提供背景、主体区域、悬浮按钮等结构。
   * SafeArea 会避开状态栏、刘海和底部导航栏，避免内容被系统 UI 挡住。
   */
  Widget _buildPermissionPage() {
    return Scaffold(
      // 权限页背景色样式
      backgroundColor: const Color(0xFFF6F6F6),
      body: SafeArea(
        child: Center(
          // Center 把里面的授权提示整体放到屏幕中间。
          child: Padding(
            // 权限页内容外边距样式
            padding: const EdgeInsets.all(24),
            child: Column(
              // 权限页内容纵向布局样式
              // Column 表示从上到下排列 children 里的组件。
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
                  // 正在检查时禁用按钮，避免用户连续点击重复打开系统设置。
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
   *
   * 这里是最终分流：有权限显示真正页面，没权限显示授权说明页。
   */
  @override
  Widget build(BuildContext context) {
    if (_hasAllFilesAccess) {
      return widget.child;
    }

    return _buildPermissionPage();
  }
}
