/*
 * 文件说明：笔记文件存储服务文件，负责将每一条笔记映射为一个独立的 .md 文件。
 */
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:my_note/models/note_item.dart';
import 'package:my_note/utils/markdown_helper.dart';

/*
 * 笔记文件存储服务。
 */
class NoteStorageService {
  /*
   * 获取笔记目录。
   */
  Future<Directory> getNoteDirectory() async {
    final Directory documentDirectory = await getApplicationDocumentsDirectory();
    final Directory noteDirectory = Directory('${documentDirectory.path}${Platform.pathSeparator}notes');

    if (!await noteDirectory.exists()) {
      await noteDirectory.create(recursive: true);
    }

    return noteDirectory;
  }

  /*
   * 生成新的笔记文件名。
   */
  String createNoteFileName() {
    return 'note-${DateTime.now().millisecondsSinceEpoch}.md';
  }

  /*
   * 根据文件名获取笔记文件对象。
   */
  Future<File> getNoteFile(String fileName) async {
    final Directory noteDirectory = await getNoteDirectory();
    return File('${noteDirectory.path}${Platform.pathSeparator}$fileName');
  }

  /*
   * 根据文件内容和文件信息构建界面所需的笔记实体。
   */
  Future<NoteItem> createNoteItem(File file, String content) async {
    final FileStat fileStat = await file.stat();

    return NoteItem(
      id: file.uri.pathSegments.isNotEmpty ? file.uri.pathSegments.last : file.path,
      fileName: file.uri.pathSegments.isNotEmpty ? file.uri.pathSegments.last : file.path.split(Platform.pathSeparator).last,
      title: extractNoteTitle(content),
      preview: extractNotePreview(content),
      content: content,
      updatedAt: fileStat.modified,
    );
  }

  /*
   * 在首次进入时写入一条欢迎笔记。
   */
  Future<void> seedWelcomeNote() async {
    final String welcomeContent = <String>[
      '# 欢迎使用 myNote',
      '',
      '这是一个基于 Flutter 的 Markdown 笔记原型。',
      '',
      '- 每一条笔记都会保存成一个独立的 `.md` 文件',
      '- 支持标题、加粗、列表、待办、引用等基础编辑操作',
      '- 你后续可以继续扩展标签、搜索、同步和附件能力',
      '',
      '> 现在就可以直接修改这条笔记内容。',
    ].join('\n');

    final File file = await getNoteFile(createNoteFileName());
    await file.writeAsString(welcomeContent, flush: true);
  }

  /*
   * 读取全部笔记列表。
   */
  Future<List<NoteItem>> loadNotes() async {
    final Directory noteDirectory = await getNoteDirectory();
    List<FileSystemEntity> entities = noteDirectory.listSync();
    List<File> files = entities.whereType<File>().where((File file) => file.path.endsWith('.md')).toList();

    if (files.isEmpty) {
      await seedWelcomeNote();
      entities = noteDirectory.listSync();
      files = entities.whereType<File>().where((File file) => file.path.endsWith('.md')).toList();
    }

    final List<NoteItem> notes = <NoteItem>[];

    for (final File file in files) {
      final String content = await file.readAsString();
      notes.add(await createNoteItem(file, content));
    }

    notes.sort((NoteItem left, NoteItem right) => right.updatedAt.compareTo(left.updatedAt));
    return notes;
  }

  /*
   * 创建一条新的空白笔记。
   */
  Future<NoteItem> createNote() async {
    final String fileName = createNoteFileName();
    final File file = await getNoteFile(fileName);
    final String content = createInitialNoteContent('新建笔记');

    await file.writeAsString(content, flush: true);
    return createNoteItem(file, content);
  }

  /*
   * 保存指定笔记的内容。
   */
  Future<NoteItem> saveNoteContent(String fileName, String content) async {
    final File file = await getNoteFile(fileName);
    await file.writeAsString(content, flush: true);
    return createNoteItem(file, content);
  }

  /*
   * 删除指定笔记文件。
   */
  Future<void> deleteNote(String fileName) async {
    final File file = await getNoteFile(fileName);

    if (await file.exists()) {
      await file.delete();
    }
  }
}


