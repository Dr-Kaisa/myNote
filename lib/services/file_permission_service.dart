/*
 * 文件说明：文件权限服务文件，负责连接 Android 原生侧检查和请求所有文件访问权限。
 *
 * Flutter/Dart 本身不能直接打开 Android 的“所有文件访问权限”设置页。
 * 所以这里通过 MethodChannel 调用 Android 原生 Kotlin 代码。
 */
import 'dart:io';

import 'package:flutter/services.dart';

/*
 * 文件权限服务。
 *
 * 这个类只做一件事：把 Dart 侧的权限请求转发给 Android 原生侧。
 * 页面组件不直接写平台判断和通道调用，这样界面逻辑会更清楚。
 */
class FilePermissionService {
  /*
   * Android 原生通信通道。
   *
   * MethodChannel 可以理解成 Flutter 和 Android 原生代码之间的一条命名管道。
   * 这里的名字必须和 android/app/src/main/kotlin 里的通道名字保持一致。
   */
  static const MethodChannel _channel = MethodChannel(
    'my_note/all_files_access',
  );

  /*
   * 检查当前平台是否已经具备所有文件访问权限。
   *
   * Android 需要检查 MANAGE_EXTERNAL_STORAGE 这类权限。
   * 非 Android 平台没有这个授权页，所以直接返回 true，让桌面调试不被卡住。
   */
  Future<bool> hasAllFilesAccess() async {
    if (!Platform.isAndroid) {
      return true;
    }

    // invokeMethod 会调用 Android 原生侧同名方法，并等待它返回布尔结果。
    return await _channel.invokeMethod<bool>('hasAllFilesAccess') ?? true;
  }

  /*
   * 打开系统所有文件访问权限授权页面。
   *
   * 这里只负责发起请求；用户是否真的打开权限，需要回到应用后再次检查。
   */
  Future<void> requestAllFilesAccess() async {
    if (!Platform.isAndroid) {
      return;
    }

    // requestAllFilesAccess 是 Android 原生侧暴露出来的方法名。
    await _channel.invokeMethod<void>('requestAllFilesAccess');
  }
}
