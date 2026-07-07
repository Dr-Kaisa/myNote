/*
 * 文件说明：Android 主 Activity 文件，负责承载 Flutter 页面并处理所有文件访问权限。
 *
 * Flutter 页面运行在 Android 的 Activity 里面。
 * 这个文件主要做两件事：
 * 1. 作为 Flutter 页面在 Android 里的宿主入口。
 * 2. 提供 Dart 侧 FilePermissionService 调用的原生权限方法。
 */
package com.mynote

import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/*
 * Android 主 Activity。
 *
 * FlutterActivity 是 Flutter 官方提供的 Android 页面基类。
 * 继承它以后，Android 打开这个 Activity 时就会加载 Flutter 界面。
 */
class MainActivity : FlutterActivity() {
    /*
     * 所有文件访问权限通信通道名称。
     *
     * 这个字符串必须和 Dart 侧 FilePermissionService 里的 MethodChannel 名称一致。
     * Flutter 和 Android 原生代码就是靠这个名字找到同一条通信通道。
     */
    private val allFilesAccessChannelName = "my_note/all_files_access"

    /*
     * 配置 Flutter 引擎并注册原生权限方法。
     *
     * FlutterEngine 可以理解成 Flutter 页面运行的引擎。
     * 在这里注册 MethodChannel 后，Dart 侧就能调用 hasAllFilesAccess 和 requestAllFilesAccess。
     */
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // MethodChannel 负责接收 Dart 发来的方法名和参数。
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, allFilesAccessChannelName).setMethodCallHandler { call, result ->
            when (call.method) {
                // Dart 调用 hasAllFilesAccess 时，返回当前权限检查结果。
                "hasAllFilesAccess" -> result.success(hasAllFilesAccess())
                "requestAllFilesAccess" -> {
                    // Dart 调用 requestAllFilesAccess 时，打开 Android 系统授权页面。
                    requestAllFilesAccess()
                    result.success(null)
                }
                // 未注册的方法返回 notImplemented，方便 Dart 侧识别调用错误。
                else -> result.notImplemented()
            }
        }
    }

    /*
     * 检查当前应用是否已经拥有所有文件访问权限。
     *
     * Android 11，也就是 API 30 / R，开始引入“所有文件访问权限”管理。
     * 低于 Android 11 的系统不需要走 Environment.isExternalStorageManager。
     */
    private fun hasAllFilesAccess(): Boolean {
        return Build.VERSION.SDK_INT < Build.VERSION_CODES.R || Environment.isExternalStorageManager()
    }

    /*
     * 打开系统所有文件访问权限授权页面。
     *
     * Intent 是 Android 用来打开系统页面或其他 Activity 的请求对象。
     * 这里优先打开当前应用自己的“所有文件访问权限”设置页。
     */
    private fun requestAllFilesAccess() {
        if (hasAllFilesAccess()) {
            // 已经有权限时不再打开设置页。
            return
        }

        // Android 11+ 可以直接打开当前应用对应的授权页面。
        val appSettingsIntent = Intent(
            Settings.ACTION_MANAGE_APP_ALL_FILES_ACCESS_PERMISSION,
            Uri.parse("package:$packageName"),
        )
        appSettingsIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)

        try {
            startActivity(appSettingsIntent)
        } catch (exception: ActivityNotFoundException) {
            // 少数系统没有单应用授权页，就退回到所有文件访问权限列表页。
            val settingsIntent = Intent(Settings.ACTION_MANAGE_ALL_FILES_ACCESS_PERMISSION)
            settingsIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            startActivity(settingsIntent)
        }
    }
}
