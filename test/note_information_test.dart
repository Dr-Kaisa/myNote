/*
 * 文件说明：验证创建时间持久保存、旧笔记补录以及关于页的磁盘统计。
 */
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_note/models/note_item.dart';
import 'package:my_note/services/note_storage_service.dart';

/*
 * 将存储操作限制到测试目录。
 */
class _TestStorage extends NoteStorageService {
  /*
   * 保存测试根目录。
   */
  _TestStorage(this.root);

  final Directory root;

  /*
   * 返回隔离的笔记根目录。
   */
  @override
  Future<Directory> getNoteDirectory() async => root;
}

/*
 * 注册创建时间与笔记信息回归测试。
 */
void main() {
  late Directory root;
  late _TestStorage storage;

  // 每项测试使用独立目录，避免读写用户笔记。
  setUp(() async {
    root = await Directory.systemTemp.createTemp('my_note_information_');
    storage = _TestStorage(root);
  });

  // 清理本次测试创建的目录。
  tearDown(() async {
    await root.delete(recursive: true);
  });

  // 修改内容、重命名、切换入口和移动后，重新读取仍保留原始创建时间。
  test('创建时间在重命名、切换文档、移动和重新加载后保持不变', () async {
    NoteItem note = await storage.createNote();
    final DateTime createdAt = note.createdAt;
    final NoteInformation original = await storage.getNoteInformation(note);
    expect(original.documentCreatedAtEstimated, isFalse);
    expect(original.packageCreatedAtEstimated, isFalse);
    note = await storage.saveNoteContent(note.relativePath, '# 改名后的笔记\n正文');
    expect(note.createdAt, createdAt);
    final NoteItem second = await storage.createPackageNote(
      note.packageRelativePath,
    );
    await storage.setPackageEntryNote(second);
    final NoteItem renamedSecond = await storage.saveNoteContent(
      second.relativePath,
      '# 第二篇改名\n正文',
    );
    expect(renamedSecond.createdAt, second.createdAt);
    await storage.setPackageEntryNote(note);
    note = await storage.moveNoteToDirectory(note, '归档');
    final NoteItem loaded = (await _TestStorage(root).loadPackageNotes(
      note.packageRelativePath,
    )).firstWhere((NoteItem item) => item.fileName == note.fileName);
    expect(loaded.createdAt, createdAt);
    final NoteInformation info = await storage.getNoteInformation(loaded);
    expect(info.packageCreatedAt, original.packageCreatedAt);
    expect(info.documentCreatedAt, original.documentCreatedAt);
  });

  // 旧笔记只补录一次估算时间，修改和重新加载不能覆盖补录值及未知字段。
  test('旧笔记补录创建时间并保留额外元数据', () async {
    final Directory directory = await Directory('${root.path}/旧笔记').create();
    final File file = File('${directory.path}/正文.md');
    await file.writeAsString('# 正文', encoding: utf8);
    final DateTime historical = DateTime(2020, 3, 4, 12);
    await file.setLastModified(historical);
    await File('${directory.path}/.mynote.json').writeAsString(
      jsonEncode({
        'schema': 1,
        'kind': 'note-package',
        'entry': '正文.md',
        'extra': '保留我',
      }),
      encoding: utf8,
    );
    NoteItem note = (await storage.loadPackageNotes('旧笔记')).single;
    expect(note.createdAt, historical);
    expect(
      (await storage.getNoteInformation(note)).documentCreatedAtEstimated,
      isTrue,
    );
    expect(
      (await storage.getNoteInformation(note)).packageCreatedAtEstimated,
      isTrue,
    );
    note = await storage.saveNoteContent(note.relativePath, '# 新标题\n新增正文');
    await storage.setPackageEntryNote(note);
    expect(
      (await _TestStorage(root).loadPackageNotes('旧笔记')).single.createdAt,
      historical,
    );
    expect((await storage.readPackageMetadata(directory))!['extra'], '保留我');
  });

  // 统计包括文档、嵌套资源和元数据，但文件夹不计入；元数据修改不影响内容修改时间。
  test('文件数量、总大小和包内最近修改时间准确', () async {
    final NoteItem note = await storage.createNote();
    await storage.createPackageNote(note.packageRelativePath);
    final Directory directory = await storage.getDirectoryByRelativePath(
      note.packageRelativePath,
    );
    final Directory assets = await Directory(
      '${directory.path}/assets/sub',
    ).create(recursive: true);
    final File resource = File('${assets.path}/图片.bin');
    await resource.writeAsBytes([1, 2, 3, 255]);
    final DateTime modified = DateTime(2040, 1, 2);
    await resource.setLastModified(modified);
    final NoteInformation info = await storage.getNoteInformation(note);
    expect(info.documentCount, 2);
    expect(info.fileCount, 4);
    int expectedBytes = 0;
    await for (final FileSystemEntity entity in directory.list(
      recursive: true,
    )) {
      if (entity is File) expectedBytes += await entity.length();
    }
    expect(info.totalBytes, expectedBytes);
    expect(info.packageUpdatedAt, modified);
  });

  // 删除再创建同名文档时不能继承旧的创建时间或估算标记。
  test('删除文档清理其创建时间记录', () async {
    final NoteItem note = await storage.createNote();
    final NoteItem second = await storage.createPackageNote(
      note.packageRelativePath,
    );
    await storage.deletePackageDocument(second.relativePath);
    final Directory directory = await storage.getDirectoryByRelativePath(
      note.packageRelativePath,
    );
    expect(
      (await storage.readPackageMetadata(directory))!['documents'],
      isNot(contains(second.fileName)),
    );
    final NoteItem replacement = await storage.createPackageNote(
      note.packageRelativePath,
    );
    expect(replacement.fileName, second.fileName);
    expect(
      (await storage.getNoteInformation(
        replacement,
      )).documentCreatedAtEstimated,
      isFalse,
    );
  });
}
