/*
 * 文件说明：文件权限服务文件，负责连接 Android 原生侧检查和请求所有文件访问权限。
 */
import 'dart:io';

import 'package:flutter/services.dart';

/*
 * 文件权限服务。
 */
class FilePermissionService {
  /*
   * Android 原生通信通道。
   */
  static const MethodChannel _channel = MethodChannel(
    'my_note/all_files_access',
  );

  /*
   * 检查当前平台是否已经具备所有文件访问权限。
   */
  Future<bool> hasAllFilesAccess() async {
    if (!Platform.isAndroid) {
      return true;
    }

    return await _channel.invokeMethod<bool>('hasAllFilesAccess') ?? true;
  }

  /*
   * 打开系统所有文件访问权限授权页面。
   */
  Future<void> requestAllFilesAccess() async {
    if (!Platform.isAndroid) {
      return;
    }

    await _channel.invokeMethod<void>('requestAllFilesAccess');
  }
}
