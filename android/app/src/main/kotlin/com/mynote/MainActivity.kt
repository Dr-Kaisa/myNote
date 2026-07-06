/*
 * 文件说明：Android 主 Activity 文件，负责承载 Flutter 页面并处理所有文件访问权限。
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
 */
class MainActivity : FlutterActivity() {
    /*
     * 所有文件访问权限通信通道名称。
     */
    private val allFilesAccessChannelName = "my_note/all_files_access"

    /*
     * 配置 Flutter 引擎并注册原生权限方法。
     */
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, allFilesAccessChannelName).setMethodCallHandler { call, result ->
            when (call.method) {
                "hasAllFilesAccess" -> result.success(hasAllFilesAccess())
                "requestAllFilesAccess" -> {
                    requestAllFilesAccess()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    /*
     * 检查当前应用是否已经拥有所有文件访问权限。
     */
    private fun hasAllFilesAccess(): Boolean {
        return Build.VERSION.SDK_INT < Build.VERSION_CODES.R || Environment.isExternalStorageManager()
    }

    /*
     * 打开系统所有文件访问权限授权页面。
     */
    private fun requestAllFilesAccess() {
        if (hasAllFilesAccess()) {
            return
        }

        val appSettingsIntent = Intent(
            Settings.ACTION_MANAGE_APP_ALL_FILES_ACCESS_PERMISSION,
            Uri.parse("package:$packageName"),
        )
        appSettingsIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)

        try {
            startActivity(appSettingsIntent)
        } catch (exception: ActivityNotFoundException) {
            val settingsIntent = Intent(Settings.ACTION_MANAGE_ALL_FILES_ACCESS_PERMISSION)
            settingsIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            startActivity(settingsIntent)
        }
    }
}
