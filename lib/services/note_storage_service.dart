/*
 * 文件说明：笔记文件存储服务文件，负责将每一条笔记映射为一个独立的 .md 文件。
 *
 * 这个文件不负责界面，只负责和磁盘打交道。
 * 目前的存储规则是：
 * 1. 一条笔记 = 一个 Markdown 文件。
 * 2. 一个文件夹 = 磁盘上的真实文件夹。
 * 3. 界面里显示的 NoteItem 都是从真实文件和文件夹扫描出来的。
 */
import 'dart:io';

import 'package:my_note/models/note_item.dart';
import 'package:my_note/utils/markdown_helper.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

/*
 * 笔记文件存储服务。
 *
 * service 表示“服务类”，页面会调用这里的方法完成加载、保存、移动、删除。
 * 把文件操作集中在这里，可以避免页面代码里到处散落磁盘读写逻辑。
 */
class NoteStorageService {
  /*
   * Android 外部共享存储根目录下的笔记目录。
   *
   * Android 真机上会把笔记保存到 /storage/emulated/0/myNote。
   * 这个目录用户可以用文件管理器看到，方便直接备份或编辑 .md 文件。
   */
  static const String androidExternalNoteDirectoryPath =
      '/storage/emulated/0/myNote';

  /*
   * 获取笔记目录。
   *
   * Android 使用固定公共目录；桌面调试时没有这个目录，所以用应用文档目录兜底。
   * 如果目录不存在，会自动创建。
   */
  Future<Directory> getNoteDirectory() async {
    // Platform.isAndroid 用来判断当前运行平台。
    final Directory noteDirectory = Platform.isAndroid
        ? Directory(androidExternalNoteDirectoryPath)
        : await getDesktopFallbackNoteDirectory();

    // recursive: true 表示父目录不存在时也一起创建。
    if (!await noteDirectory.exists()) {
      await noteDirectory.create(recursive: true);
    }

    return noteDirectory;
  }

  /*
   * 获取非 Android 平台的兜底笔记目录。
   *
   * 这个方法主要方便 Windows/macOS/Linux 调试。
   * getApplicationDocumentsDirectory 会返回当前平台适合存放应用文档的位置。
   */
  Future<Directory> getDesktopFallbackNoteDirectory() async {
    final Directory documentDirectory =
        await getApplicationDocumentsDirectory();
    return Directory('${documentDirectory.path}${Platform.pathSeparator}notes');
  }

  /*
   * 生成新的笔记文件名。
   *
   * 使用时间戳可以降低文件名冲突概率。
   * 这个方法目前保留作兜底，主要创建逻辑已经改为按标题生成文件名。
   */
  String createNoteFileName() {
    return 'note-${DateTime.now().millisecondsSinceEpoch}.md';
  }

  /*
   * 根据文件名获取笔记文件对象。
   *
   * File 对象只是一个“路径引用”，不代表文件一定已经存在。
   */
  Future<File> getNoteFile(String fileName) async {
    final Directory noteDirectory = await getNoteDirectory();
    return File('${noteDirectory.path}${Platform.pathSeparator}$fileName');
  }

  /*
   * 根据相对路径获取笔记文件对象。
   *
   * 界面和业务逻辑统一使用正斜杠 / 保存相对路径；
   * 真正访问磁盘前，再转换成当前系统需要的路径分隔符。
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
   *
   * relativePath 为空字符串时表示笔记根目录。
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
   *
   * 磁盘上的 File 只知道路径和修改时间；
   * NoteItem 是界面更好用的数据结构，里面有标题、摘要、标签、目录等字段。
   */
  Future<NoteItem> createNoteItem(
    File file,
    String content,
    Directory noteDirectory,
  ) async {
    // stat 可以读取文件修改时间等系统信息。
    final FileStat fileStat = await file.stat();
    // 把绝对路径转换成相对笔记根目录的路径，方便跨平台保存和展示。
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
   *
   * 如果笔记目录里没有任何 .md 文件，就创建一条欢迎笔记，避免首页空白。
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
    // 先确保父目录存在，再写入文件内容。
    await file.parent.create(recursive: true);
    // flush: true 表示尽量立刻把内容刷到磁盘，降低异常退出时丢数据的概率。
    await file.writeAsString(welcomeContent, flush: true);
  }

  /*
   * 读取全部笔记列表。
   *
   * 这里会递归扫描笔记根目录下所有 .md 文件，把它们转换成 NoteItem。
   */
  Future<List<NoteItem>> loadNotes() async {
    final Directory noteDirectory = await getNoteDirectory();
    // recursive: true 表示连子文件夹里的笔记也一起扫描。
    List<FileSystemEntity> entities = noteDirectory.listSync(recursive: true);
    List<File> files = entities
        // 只保留文件，排除文件夹。
        .whereType<File>()
        // 只把 Markdown 文件当作笔记。
        .where((File file) => file.path.endsWith('.md'))
        .toList();

    if (files.isEmpty) {
      // 没有任何笔记时创建欢迎笔记，然后重新扫描一次。
      await seedWelcomeNote();
      entities = noteDirectory.listSync(recursive: true);
      files = entities
          .whereType<File>()
          .where((File file) => file.path.endsWith('.md'))
          .toList();
    }

    final List<NoteItem> notes = <NoteItem>[];

    for (final File file in files) {
      // 读取文件正文，再根据正文和文件信息生成 NoteItem。
      final String content = await file.readAsString();
      notes.add(await createNoteItem(file, content, noteDirectory));
    }

    // 首页默认按更新时间倒序显示，最近编辑的排在前面。
    notes.sort(
      (NoteItem left, NoteItem right) =>
          right.updatedAt.compareTo(left.updatedAt),
    );
    return notes;
  }

  /*
   * 读取全部文件夹路径列表。
   *
   * 返回的是相对路径，例如 "工作/计划"，不是绝对磁盘路径。
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
              // 把真实目录路径转换为相对笔记根目录的路径。
              return path
                  .relative(directory.path, from: noteDirectory.path)
                  .replaceAll('\\', '/');
            })
            .where((String relativePath) {
              // 排除根目录自身，只保留用户创建的文件夹。
              return relativePath.isNotEmpty && relativePath != '.';
            })
            .toList()
          ..sort();

    return folderPaths;
  }

  /*
   * 创建一条新的空白笔记。
   *
   * directoryPath 为空时创建在根目录；不为空时创建在指定文件夹里。
   */
  Future<NoteItem> createNote({String directoryPath = ''}) async {
    final Directory noteDirectory = await getNoteDirectory();
    final String content = createInitialNoteContent('新建笔记');
    final String title = extractNoteTitle(content);
    final String relativePath = directoryPath.isEmpty
        ? createFileNameFromTitle(title)
        : '$directoryPath/${createFileNameFromTitle(title)}';
    final File file = await getNoteFile(relativePath);
    // 如果同名文件已存在，生成一个不冲突的新文件路径。
    final File targetFile = await createAvailableFile(file);

    await targetFile.parent.create(recursive: true);
    await targetFile.writeAsString(content, flush: true);
    return createNoteItem(targetFile, content, noteDirectory);
  }

  /*
   * 创建文件夹并返回实际创建的相对路径。
   *
   * 如果目标文件夹已存在，会自动生成 “文件夹-1” 这样的可用名称。
   */
  Future<String> createFolder(
    String parentDirectoryPath,
    String folderName,
  ) async {
    final Directory noteDirectory = await getNoteDirectory();
    // 文件夹名也需要清理非法字符，避免系统拒绝创建。
    final String nextFolderName = sanitizeFileName(folderName);
    final String nextRelativePath = parentDirectoryPath.isEmpty
        ? nextFolderName
        : '$parentDirectoryPath/$nextFolderName';
    final Directory directory = await getDirectoryByRelativePath(
      nextRelativePath,
    );
    final Directory targetDirectory = await createAvailableDirectory(directory);

    await targetDirectory.create(recursive: true);
    // 返回相对路径，页面后续就可以用它进入这个文件夹。
    return path
        .relative(targetDirectory.path, from: noteDirectory.path)
        .replaceAll('\\', '/');
  }

  /*
   * 保存指定笔记的内容。
   *
   * 保存时会重新提取标题；如果标题变了，文件名也跟着改。
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

    // 当 Markdown 第一行标题变化时，文件名也需要同步变化。
    if (fileNameNeedsRename(path.posix.basename(relativePath), nextFileName)) {
      final File renameTargetFile = await getNoteFileByRelativePath(
        nextRelativePath,
      );
      targetFile = await createAvailableFile(
        renameTargetFile,
        preferredSourcePath: file.path,
      );

      if (await file.exists()) {
        // rename 会移动/重命名文件，原路径会消失。
        await file.rename(targetFile.path);
      }
    }

    await targetFile.writeAsString(content, flush: true);
    return createNoteItem(targetFile, content, noteDirectory);
  }

  /*
   * 移动指定笔记到目标文件夹。
   *
   * targetDirectoryPath 为空字符串表示移动到根目录。
   */
  Future<NoteItem> moveNoteToDirectory(
    NoteItem note,
    String targetDirectoryPath,
  ) async {
    if (note.directoryPath == targetDirectoryPath) {
      // 已经在目标目录里就不需要移动。
      return note;
    }

    final Directory noteDirectory = await getNoteDirectory();
    final File sourceFile = await getNoteFileByRelativePath(note.relativePath);
    final Directory targetDirectory = await getDirectoryByRelativePath(
      targetDirectoryPath,
    );

    await targetDirectory.create(recursive: true);

    // 目标目录里如果有同名文件，自动生成不冲突的文件名。
    final File targetFile = await createAvailableFile(
      File('${targetDirectory.path}${Platform.pathSeparator}${note.fileName}'),
      preferredSourcePath: sourceFile.path,
    );
    final File movedFile = await sourceFile.rename(targetFile.path);
    return createNoteItem(movedFile, note.content, noteDirectory);
  }

  /*
   * 移动指定文件夹到目标父文件夹。
   *
   * 这里移动的是整个目录，目录里的子文件夹和笔记会一起移动。
   */
  Future<String> moveFolderToDirectory(
    String sourceDirectoryPath,
    String targetParentDirectoryPath,
  ) async {
    // 先算出当前文件夹原来的父目录，用来判断是否真的需要移动。
    final String currentParentDirectoryPath = sourceDirectoryPath.contains('/')
        ? sourceDirectoryPath.substring(0, sourceDirectoryPath.lastIndexOf('/'))
        : '';

    if (sourceDirectoryPath.isEmpty ||
        sourceDirectoryPath == targetParentDirectoryPath ||
        currentParentDirectoryPath == targetParentDirectoryPath) {
      // 根目录不能移动；移动到自己或原父目录也等于没变化。
      return sourceDirectoryPath;
    }

    if (targetParentDirectoryPath.startsWith('$sourceDirectoryPath/')) {
      // 防止把文件夹移动到自己的子文件夹里，这会造成目录递归嵌套错误。
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

    // 如果目标位置已有同名文件夹，生成一个不冲突的目录名。
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
   *
   * 这里只删除单个 .md 文件，不会删除它所在的文件夹。
   */
  Future<void> deleteNote(String relativePath) async {
    final File file = await getNoteFileByRelativePath(relativePath);

    if (await file.exists()) {
      await file.delete();
    }
  }

  /*
   * 删除指定文件夹及其内部内容。
   *
   * recursive: true 会连同内部所有笔记和子文件夹一起删除。
   */
  Future<void> deleteFolder(String relativePath) async {
    final Directory directory = await getDirectoryByRelativePath(relativePath);

    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  }

  /*
   * 为目标文件生成不冲突的实际文件路径。
   *
   * 例如目标是 “计划.md”，但它已经存在，就尝试 “计划-1.md”“计划-2.md”。
   */
  Future<File> createAvailableFile(
    File targetFile, {
    String? preferredSourcePath,
  }) async {
    if (!await targetFile.exists() || targetFile.path == preferredSourcePath) {
      // 文件不存在，或者目标就是原文件时，可以直接使用。
      return targetFile;
    }

    final String directoryPath = targetFile.parent.path;
    final String baseName = path.basenameWithoutExtension(targetFile.path);
    final String extension = path.extension(targetFile.path);
    int index = 1;

    while (true) {
      // 循环尝试带编号的文件名，直到找到一个不存在的路径。
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
   *
   * 逻辑和 createAvailableFile 类似，只是处理对象从 File 换成 Directory。
   */
  Future<Directory> createAvailableDirectory(
    Directory targetDirectory, {
    String? preferredSourcePath,
  }) async {
    if (!await targetDirectory.exists() ||
        targetDirectory.path == preferredSourcePath) {
      // 文件夹不存在，或者目标就是原文件夹时，可以直接使用。
      return targetDirectory;
    }

    final String parentPath = targetDirectory.parent.path;
    final String baseName = path.basename(targetDirectory.path);
    int index = 1;

    while (true) {
      // 循环尝试带编号的文件夹名，直到找到一个不存在的路径。
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
   *
   * 目前规则很直接：当前文件名和新标题生成的文件名不同，就需要重命名。
   */
  bool fileNameNeedsRename(String currentFileName, String nextFileName) {
    return currentFileName != nextFileName;
  }
}
