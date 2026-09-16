/*
 * 文件说明：验证文件分享的真实压缩内容、准备完成时机和系统分享异常传递。
 */
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_note/models/note_item.dart';
import 'package:my_note/services/note_share_service.dart';
import 'package:my_note/services/note_storage_service.dart';

/*
 * 使用测试目录提供笔记包，避免访问用户的真实笔记。
 */
class _TestNoteStorageService extends NoteStorageService {
  /*
   * 保存本次测试使用的笔记目录。
   */
  _TestNoteStorageService(this.directory);

  final Directory directory;

  /*
   * 将笔记包路径解析到测试目录。
   */
  @override
  Future<Directory> getDirectoryByRelativePath(String relativePath) async {
    return directory;
  }
}

/*
 * 注册文件分享回归测试。
 */
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const MethodChannel pathChannel = MethodChannel(
    'plugins.flutter.io/path_provider',
  );
  const MethodChannel shareChannel = MethodChannel(
    'dev.fluttercommunity.plus/share',
  );
  late Directory root;
  late Directory package;
  late NoteItem note;

  // 每个测试建立独立的中文笔记包及引用资源，并模拟系统临时目录。
  setUp(() async {
    root = await Directory.systemTemp.createTemp('my_note_share_test_');
    package = await Directory('${root.path}/测试笔记包').create();
    await File(
      '${package.path}/正文.md',
    ).writeAsString('# 标题\n![图片](assets/图片.bin)', encoding: utf8);
    await Directory('${package.path}/assets').create();
    await File('${package.path}/assets/图片.bin').writeAsBytes([1, 2, 3, 255]);
    note = NoteItem(
      id: '正文',
      fileName: '正文.md',
      relativePath: '测试笔记包/正文.md',
      packageRelativePath: '测试笔记包',
      packageName: '测试笔记包',
      directoryPath: '',
      title: '标题',
      preview: '',
      content: '',
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
      tags: const [],
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          pathChannel,
          (MethodCall call) async => root.path,
        );
  });

  // 清除模拟通道并删除本次测试创建的临时文件。
  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(shareChannel, null);
    await root.delete(recursive: true);
  });

  // 验证压缩包包含正文和引用，且无需等系统分享结束即可撤下生成提示。
  test('文件生成后先通知页面，再等待系统分享结果', () async {
    bool prepared = false;
    final Completer<void> requested = Completer<void>();
    final Completer<String> systemResult = Completer<String>();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(shareChannel, (MethodCall call) async {
          expect(prepared, isTrue);
          final String zipPath =
              (call.arguments['paths'] as List).single as String;
          final Archive archive = ZipDecoder().decodeBytes(
            await File(zipPath).readAsBytes(),
          );
          expect(
            utf8.decode(archive.findFile('测试笔记包/正文.md')!.content),
            '# 标题\n![图片](assets/图片.bin)',
          );
          expect(archive.findFile('测试笔记包/assets/图片.bin')!.content, [
            1,
            2,
            3,
            255,
          ]);
          requested.complete();
          return systemResult.future;
        });
    final Future<void> sharing =
        NoteShareService(
          noteStorageService: _TestNoteStorageService(package),
        ).sharePackageFiles(
          note,
          null,
          onPrepared: () {
            prepared = true;
          },
        );
    try {
      await requested.future.timeout(const Duration(seconds: 10));
      expect(prepared, isTrue);
    } finally {
      systemResult.complete('dev.fluttercommunity.plus/share/dismissed');
      await sharing;
    }
  });

  // 系统通道失败时应抛出原始异常，交由页面移除遮罩并展示错误。
  test('系统分享异常正常返回给页面', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(shareChannel, (MethodCall call) async {
          throw PlatformException(code: 'share_failed', message: '测试分享失败');
        });
    await expectLater(
      NoteShareService(
        noteStorageService: _TestNoteStorageService(package),
      ).sharePackageFiles(note, null),
      throwsA(isA<PlatformException>()),
    );
  });
}
