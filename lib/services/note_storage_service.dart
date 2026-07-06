/*
 * 文件说明：笔记文件存储服务文件，负责将每一条笔记映射为一个独立的 .md 文件。
 */
import 'dart:io';

import 'package:my_note/models/note_item.dart';
import 'package:my_note/utils/markdown_helper.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

/*
 * 笔记文件存储服务。
 */
class NoteStorageService {
  /*
   * Android 外部共享存储根目录下的笔记目录。
   */
  static const String androidExternalNoteDirectoryPath =
      '/storage/emulated/0/myNote';

  /*
   * 获取笔记目录。
   */
  Future<Directory> getNoteDirectory() async {
    final Directory noteDirectory = Platform.isAndroid
        ? Directory(androidExternalNoteDirectoryPath)
        : await getDesktopFallbackNoteDirectory();

    if (!await noteDirectory.exists()) {
      await noteDirectory.create(recursive: true);
    }

    return noteDirectory;
  }

  /*
   * 获取非 Android 平台的兜底笔记目录。
   */
  Future<Directory> getDesktopFallbackNoteDirectory() async {
    final Directory documentDirectory =
        await getApplicationDocumentsDirectory();
    return Directory('${documentDirectory.path}${Platform.pathSeparator}notes');
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
   * 根据相对路径获取笔记文件对象。
   */
  Future<File> getNoteFileByRelativePath(String relativePath) async {
    final Directory noteDirectory = await getNoteDirectory();
    final String normalizedRelativePath = relativePath.replaceAll(
      '/',
      Platform.pathSeparator,
    );
    return File(
      '${noteDirectory.path}${Platform.pathSeparator}$normalizedRelativePath',
    );
  }

  /*
   * 根据相对路径获取文件夹对象。
   */
  Future<Directory> getDirectoryByRelativePath(String relativePath) async {
    final Directory noteDirectory = await getNoteDirectory();

    if (relativePath.isEmpty) {
      return noteDirectory;
    }

    final String normalizedRelativePath = relativePath.replaceAll(
      '/',
      Platform.pathSeparator,
    );
    return Directory(
      '${noteDirectory.path}${Platform.pathSeparator}$normalizedRelativePath',
    );
  }

  /*
   * 根据文件内容和文件信息构建界面所需的笔记实体。
   */
  Future<NoteItem> createNoteItem(
    File file,
    String content,
    Directory noteDirectory,
  ) async {
    final FileStat fileStat = await file.stat();
    final String relativePath = path
        .relative(file.path, from: noteDirectory.path)
        .replaceAll('\\', '/');

    return NoteItem(
      id: relativePath,
      fileName: path.posix.basename(relativePath),
      relativePath: relativePath,
      directoryPath: extractDirectoryPath(relativePath),
      title: extractNoteTitle(content),
      preview: extractNotePreview(content),
      content: content,
      updatedAt: fileStat.modified,
      tags: extractNoteTags(content),
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

    final File file = await getNoteFile(
      createFileNameFromTitle(extractNoteTitle(welcomeContent)),
    );
    await file.parent.create(recursive: true);
    await file.writeAsString(welcomeContent, flush: true);
  }

  /*
   * 读取全部笔记列表。
   */
  Future<List<NoteItem>> loadNotes() async {
    final Directory noteDirectory = await getNoteDirectory();
    List<FileSystemEntity> entities = noteDirectory.listSync(recursive: true);
    List<File> files = entities
        .whereType<File>()
        .where((File file) => file.path.endsWith('.md'))
        .toList();

    if (files.isEmpty) {
      await seedWelcomeNote();
      entities = noteDirectory.listSync(recursive: true);
      files = entities
          .whereType<File>()
          .where((File file) => file.path.endsWith('.md'))
          .toList();
    }

    final List<NoteItem> notes = <NoteItem>[];

    for (final File file in files) {
      final String content = await file.readAsString();
      notes.add(await createNoteItem(file, content, noteDirectory));
    }

    notes.sort(
      (NoteItem left, NoteItem right) =>
          right.updatedAt.compareTo(left.updatedAt),
    );
    return notes;
  }

  /*
   * 读取全部文件夹路径列表。
   */
  Future<List<String>> loadFolderPaths() async {
    final Directory noteDirectory = await getNoteDirectory();
    final List<FileSystemEntity> entities = noteDirectory.listSync(
      recursive: true,
    );
    final List<String> folderPaths =
        entities
            .whereType<Directory>()
            .map((Directory directory) {
              return path
                  .relative(directory.path, from: noteDirectory.path)
                  .replaceAll('\\', '/');
            })
            .where((String relativePath) {
              return relativePath.isNotEmpty && relativePath != '.';
            })
            .toList()
          ..sort();

    return folderPaths;
  }

  /*
   * 创建一条新的空白笔记。
   */
  Future<NoteItem> createNote({String directoryPath = ''}) async {
    final Directory noteDirectory = await getNoteDirectory();
    final String content = createInitialNoteContent('新建笔记');
    final String title = extractNoteTitle(content);
    final String relativePath = directoryPath.isEmpty
        ? createFileNameFromTitle(title)
        : '$directoryPath/${createFileNameFromTitle(title)}';
    final File file = await getNoteFile(relativePath);
    final File targetFile = await createAvailableFile(file);

    await targetFile.parent.create(recursive: true);
    await targetFile.writeAsString(content, flush: true);
    return createNoteItem(targetFile, content, noteDirectory);
  }

  /*
   * 创建文件夹并返回实际创建的相对路径。
   */
  Future<String> createFolder(
    String parentDirectoryPath,
    String folderName,
  ) async {
    final Directory noteDirectory = await getNoteDirectory();
    final String nextFolderName = sanitizeFileName(folderName);
    final String nextRelativePath = parentDirectoryPath.isEmpty
        ? nextFolderName
        : '$parentDirectoryPath/$nextFolderName';
    final Directory directory = await getDirectoryByRelativePath(
      nextRelativePath,
    );
    final Directory targetDirectory = await createAvailableDirectory(directory);

    await targetDirectory.create(recursive: true);
    return path
        .relative(targetDirectory.path, from: noteDirectory.path)
        .replaceAll('\\', '/');
  }

  /*
   * 保存指定笔记的内容。
   */
  Future<NoteItem> saveNoteContent(String relativePath, String content) async {
    final Directory noteDirectory = await getNoteDirectory();
    final File file = await getNoteFileByRelativePath(relativePath);
    final String nextTitle = extractNoteTitle(content);
    final String nextFileName = createFileNameFromTitle(nextTitle);
    final String directoryPath = extractDirectoryPath(relativePath);
    final String nextRelativePath = directoryPath.isEmpty
        ? nextFileName
        : '$directoryPath/$nextFileName';
    File targetFile = file;

    if (fileNameNeedsRename(path.posix.basename(relativePath), nextFileName)) {
      final File renameTargetFile = await getNoteFileByRelativePath(
        nextRelativePath,
      );
      targetFile = await createAvailableFile(
        renameTargetFile,
        preferredSourcePath: file.path,
      );

      if (await file.exists()) {
        await file.rename(targetFile.path);
      }
    }

    await targetFile.writeAsString(content, flush: true);
    return createNoteItem(targetFile, content, noteDirectory);
  }

  /*
   * 移动指定笔记到目标文件夹。
   */
  Future<NoteItem> moveNoteToDirectory(
    NoteItem note,
    String targetDirectoryPath,
  ) async {
    if (note.directoryPath == targetDirectoryPath) {
      return note;
    }

    final Directory noteDirectory = await getNoteDirectory();
    final File sourceFile = await getNoteFileByRelativePath(note.relativePath);
    final Directory targetDirectory = await getDirectoryByRelativePath(
      targetDirectoryPath,
    );

    await targetDirectory.create(recursive: true);

    final File targetFile = await createAvailableFile(
      File('${targetDirectory.path}${Platform.pathSeparator}${note.fileName}'),
      preferredSourcePath: sourceFile.path,
    );
    final File movedFile = await sourceFile.rename(targetFile.path);
    return createNoteItem(movedFile, note.content, noteDirectory);
  }

  /*
   * 移动指定文件夹到目标父文件夹。
   */
  Future<String> moveFolderToDirectory(
    String sourceDirectoryPath,
    String targetParentDirectoryPath,
  ) async {
    final String currentParentDirectoryPath = sourceDirectoryPath.contains('/')
        ? sourceDirectoryPath.substring(0, sourceDirectoryPath.lastIndexOf('/'))
        : '';

    if (sourceDirectoryPath.isEmpty ||
        sourceDirectoryPath == targetParentDirectoryPath ||
        currentParentDirectoryPath == targetParentDirectoryPath) {
      return sourceDirectoryPath;
    }

    if (targetParentDirectoryPath.startsWith('$sourceDirectoryPath/')) {
      throw Exception('不能把文件夹移动到它自己的子文件夹里');
    }

    final Directory noteDirectory = await getNoteDirectory();
    final Directory sourceDirectory = await getDirectoryByRelativePath(
      sourceDirectoryPath,
    );
    final Directory targetParentDirectory = await getDirectoryByRelativePath(
      targetParentDirectoryPath,
    );
    final String folderName = path.posix.basename(sourceDirectoryPath);

    await targetParentDirectory.create(recursive: true);

    final Directory targetDirectory = await createAvailableDirectory(
      Directory(
        '${targetParentDirectory.path}${Platform.pathSeparator}$folderName',
      ),
      preferredSourcePath: sourceDirectory.path,
    );
    final Directory movedDirectory = await sourceDirectory.rename(
      targetDirectory.path,
    );
    return path
        .relative(movedDirectory.path, from: noteDirectory.path)
        .replaceAll('\\', '/');
  }

  /*
   * 删除指定笔记文件。
   */
  Future<void> deleteNote(String relativePath) async {
    final File file = await getNoteFileByRelativePath(relativePath);

    if (await file.exists()) {
      await file.delete();
    }
  }

  /*
   * 删除指定文件夹及其内部内容。
   */
  Future<void> deleteFolder(String relativePath) async {
    final Directory directory = await getDirectoryByRelativePath(relativePath);

    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  }

  /*
   * 为目标文件生成不冲突的实际文件路径。
   */
  Future<File> createAvailableFile(
    File targetFile, {
    String? preferredSourcePath,
  }) async {
    if (!await targetFile.exists() || targetFile.path == preferredSourcePath) {
      return targetFile;
    }

    final String directoryPath = targetFile.parent.path;
    final String baseName = path.basenameWithoutExtension(targetFile.path);
    final String extension = path.extension(targetFile.path);
    int index = 1;

    while (true) {
      final File candidateFile = File(
        '$directoryPath${Platform.pathSeparator}$baseName-$index$extension',
      );
      if (!await candidateFile.exists() ||
          candidateFile.path == preferredSourcePath) {
        return candidateFile;
      }
      index += 1;
    }
  }

  /*
   * 为目标文件夹生成不冲突的实际文件夹路径。
   */
  Future<Directory> createAvailableDirectory(
    Directory targetDirectory, {
    String? preferredSourcePath,
  }) async {
    if (!await targetDirectory.exists() ||
        targetDirectory.path == preferredSourcePath) {
      return targetDirectory;
    }

    final String parentPath = targetDirectory.parent.path;
    final String baseName = path.basename(targetDirectory.path);
    int index = 1;

    while (true) {
      final Directory candidateDirectory = Directory(
        '$parentPath${Platform.pathSeparator}$baseName-$index',
      );
      if (!await candidateDirectory.exists() ||
          candidateDirectory.path == preferredSourcePath) {
        return candidateDirectory;
      }
      index += 1;
    }
  }

  /*
   * 判断文件名是否需要按标题进行重命名。
   */
  bool fileNameNeedsRename(String currentFileName, String nextFileName) {
    return currentFileName != nextFileName;
  }
}
