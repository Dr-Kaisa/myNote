/*
 * 文件说明：笔记包存储服务文件，负责识别普通文件夹、笔记包和包内 Markdown 文档。
 *
 * 这个文件不负责界面，只负责和磁盘打交道。
 * 当前存储规则是：
 * 1. 带有 .mynote.json 的文件夹才是笔记包。
 * 2. 笔记包内直接子级的 .md 文件是可编辑文档。
 * 3. 首次插入本地图片时才创建 assets，包内全部 Markdown 文档共享它。
 * 4. 没有 .mynote.json 的文件夹是普通分类文件夹。
 */
import 'dart:convert';
import 'dart:io';

import 'package:html/parser.dart' as html_parser;
import 'package:markdown/markdown.dart' as markdown;
import 'package:my_note/models/note_item.dart';
import 'package:my_note/utils/markdown_helper.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

/*
 * 关于弹窗使用的文档时间和笔记包磁盘统计信息。
 */
typedef NoteInformation = ({
  DateTime documentCreatedAt,
  bool documentCreatedAtEstimated,
  DateTime documentUpdatedAt,
  DateTime packageCreatedAt,
  bool packageCreatedAtEstimated,
  DateTime packageUpdatedAt,
  int fileCount,
  int documentCount,
  int totalBytes,
});

/*
 * 笔记包存储服务。
 *
 * 页面调用这里的方法加载、保存、移动和删除笔记包及其 Markdown 文档。
 */
class NoteStorageService {
  /*
   * Android 外部共享存储根目录下的笔记目录。
   */
  static const String androidExternalNoteDirectoryPath =
      '/storage/emulated/0/myNote';

  /*
   * 笔记包元数据文件名。
   */
  static const String packageMetadataFileName = '.mynote.json';

  /*
   * 笔记包共享资源文件夹名称。
   */
  static const String packageAssetsDirectoryName = 'assets';

  /*
   * 笔记包元数据类型标识。
   */
  static const String packageMetadataKind = 'note-package';

  /*
   * 当前笔记包元数据结构版本。
   */
  static const int packageMetadataSchema = 1;

  /*
   * 获取笔记根目录。
   *
   * Android 使用固定公共目录；桌面调试时使用应用文档目录下的 notes。
   */
  Future<Directory> getNoteDirectory() async {
    final Directory noteDirectory = Platform.isAndroid
        ? Directory(androidExternalNoteDirectoryPath)
        : await getDesktopFallbackNoteDirectory();

    if (!await noteDirectory.exists()) {
      // recursive: true 表示父目录不存在时也一起创建。
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
   * 根据相对路径获取文件对象。
   *
   * 界面统一使用正斜杠保存相对路径，真正访问磁盘前再转换分隔符。
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
   * 读取指定文件夹中的笔记包元数据。
   *
   * 文件不存在、JSON 损坏或类型不匹配时返回 null，调用方会把它当作普通文件夹。
   */
  Future<Map<String, dynamic>?> readPackageMetadata(
    Directory packageDirectory,
  ) async {
    final File metadataFile = File(
      '${packageDirectory.path}${Platform.pathSeparator}$packageMetadataFileName',
    );

    if (!await metadataFile.exists()) {
      return null;
    }

    try {
      final Object? decodedMetadata = jsonDecode(
        await metadataFile.readAsString(),
      );
      if (decodedMetadata is! Map<String, dynamic> ||
          decodedMetadata['kind'] != packageMetadataKind ||
          decodedMetadata['schema'] != packageMetadataSchema) {
        return null;
      }

      return decodedMetadata;
    } catch (error) {
      // 元数据损坏时不猜测目录类型，避免把普通文件夹误识别为笔记包。
      return null;
    }
  }

  /*
   * 判断指定文件夹是否是有效笔记包。
   */
  Future<bool> isNotePackageDirectory(Directory directory) async {
    return await readPackageMetadata(directory) != null;
  }

  /*
   * 写入笔记包元数据。
   *
   * entry 保存包的默认 Markdown 文件名，路径始终相对于笔记包根目录。
   */
  Future<void> writePackageMetadata(
    Directory packageDirectory,
    String entryFileName, {
    String? createdDocumentName,
  }) async {
    final Map<String, dynamic>? previous = await readPackageMetadata(
      packageDirectory,
    );
    final Map<String, dynamic> metadata =
        previous ??
        <String, dynamic>{
          'schema': packageMetadataSchema,
          'kind': packageMetadataKind,
          'createdAt': DateTime.now().toUtc().toIso8601String(),
          'createdAtEstimated': false,
        };
    // 旧笔记在切换入口前先保留可用的历史时间，避免本次元数据写入影响估算。
    if (DateTime.tryParse(metadata['createdAt']?.toString() ?? '') == null) {
      metadata['createdAt'] = (await File(
        path.join(packageDirectory.path, packageMetadataFileName),
      ).stat()).modified.toUtc().toIso8601String();
      metadata['createdAtEstimated'] = true;
    }
    metadata['entry'] = path.posix.basename(
      entryFileName.replaceAll('\\', '/'),
    );
    if (createdDocumentName != null) {
      final Map<String, dynamic> documents = Map<String, dynamic>.from(
        metadata['documents'] is Map ? metadata['documents'] as Map : {},
      );
      documents[createdDocumentName] = <String, dynamic>{
        'createdAt': DateTime.now().toUtc().toIso8601String(),
        'createdAtEstimated': false,
      };
      metadata['documents'] = documents;
    }
    await _savePackageMetadata(packageDirectory, metadata);
  }

  /*
   * 以 UTF-8 保存完整元数据，保留创建时间及未来扩展字段。
   */
  Future<void> _savePackageMetadata(
    Directory directory,
    Map<String, dynamic> metadata,
  ) async {
    await File(
      path.join(directory.path, packageMetadataFileName),
    ).writeAsString(
      '${const JsonEncoder.withIndent('  ').convert(metadata)}\n',
      encoding: utf8,
      flush: true,
    );
  }

  /*
   * 补录旧笔记的创建时间；文件修改时间仅作估算，一经记录不随保存变化。
   */
  Future<Map<String, dynamic>> _ensureCreationTimes(
    Directory directory,
    File document,
  ) async {
    final Map<String, dynamic>? metadata = await readPackageMetadata(directory);
    if (metadata == null) {
      throw Exception('当前 Markdown 不属于有效笔记包');
    }
    bool changed = false;
    if (DateTime.tryParse(metadata['createdAt']?.toString() ?? '') == null) {
      metadata['createdAt'] = (await File(
        path.join(directory.path, packageMetadataFileName),
      ).stat()).modified.toUtc().toIso8601String();
      metadata['createdAtEstimated'] = true;
      changed = true;
    }
    final Map<String, dynamic> documents = Map<String, dynamic>.from(
      metadata['documents'] is Map ? metadata['documents'] as Map : {},
    );
    final String name = path.basename(document.path);
    if (documents[name] is! Map ||
        DateTime.tryParse(documents[name]['createdAt']?.toString() ?? '') ==
            null) {
      documents[name] = <String, dynamic>{
        'createdAt': (await document.stat()).modified.toUtc().toIso8601String(),
        'createdAtEstimated': true,
      };
      metadata['documents'] = documents;
      changed = true;
    }
    if (changed) {
      await _savePackageMetadata(directory, metadata);
    }
    return metadata;
  }

  /*
   * 读取当前文档时间并递归统计笔记包文件，符号链接不计入以避免越界和重复。
   */
  Future<NoteInformation> getNoteInformation(NoteItem note) async {
    final Directory directory = await getDirectoryByRelativePath(
      note.packageRelativePath,
    );
    final File document = await getNoteFileByRelativePath(note.relativePath);
    final Map<String, dynamic> metadata = await _ensureCreationTimes(
      directory,
      document,
    );
    final Map documentMetadata = metadata['documents'][note.fileName] as Map;
    final FileStat documentStat = await document.stat();
    DateTime updatedAt = documentStat.modified;
    int fileCount = 0;
    int documentCount = 0;
    int totalBytes = 0;
    await for (final FileSystemEntity entity in directory.list(
      recursive: true,
      followLinks: false,
    )) {
      if (entity is! File) {
        continue;
      }
      final FileStat stat = await entity.stat();
      fileCount += 1;
      totalBytes += stat.size;
      if (path.extension(entity.path).toLowerCase() == '.md' &&
          path.equals(entity.parent.path, directory.path)) {
        documentCount += 1;
      }
      // 元数据补录和切换入口不视为笔记内容修改。
      if (!path.equals(
            entity.path,
            path.join(directory.path, packageMetadataFileName),
          ) &&
          stat.modified.isAfter(updatedAt)) {
        updatedAt = stat.modified;
      }
    }
    return (
      documentCreatedAt: DateTime.parse(
        documentMetadata['createdAt'] as String,
      ).toLocal(),
      documentCreatedAtEstimated:
          documentMetadata['createdAtEstimated'] == true,
      documentUpdatedAt: documentStat.modified.toLocal(),
      packageCreatedAt: DateTime.parse(
        metadata['createdAt'] as String,
      ).toLocal(),
      packageCreatedAtEstimated: metadata['createdAtEstimated'] == true,
      packageUpdatedAt: updatedAt.toLocal(),
      fileCount: fileCount,
      documentCount: documentCount,
      totalBytes: totalBytes,
    );
  }

  /*
   * 根据 Markdown 文件构建界面所需的文档实体。
   */
  Future<NoteItem> createNoteItem(
    File file,
    String content,
    Directory noteDirectory,
    Directory packageDirectory,
  ) async {
    final Map<String, dynamic> metadata = await _ensureCreationTimes(
      packageDirectory,
      file,
    );
    final FileStat fileStat = await file.stat();
    final String relativePath = path
        .relative(file.path, from: noteDirectory.path)
        .replaceAll('\\', '/');
    final String packageRelativePath = path
        .relative(packageDirectory.path, from: noteDirectory.path)
        .replaceAll('\\', '/');
    final String parentDirectoryPath = path.posix.dirname(packageRelativePath);

    return NoteItem(
      id: relativePath,
      fileName: path.posix.basename(relativePath),
      relativePath: relativePath,
      packageRelativePath: packageRelativePath,
      packageName: path.posix.basename(packageRelativePath),
      directoryPath: parentDirectoryPath == '.' ? '' : parentDirectoryPath,
      // 空白文档使用实际文件名，避免新建时显示为“未命名笔记”。
      title: stripMarkdownSyntax(content).isEmpty
          ? path.basenameWithoutExtension(file.path)
          : extractNoteTitle(content),
      preview: extractNotePreview(content),
      content: content,
      createdAt: DateTime.parse(
        metadata['documents'][path.basename(file.path)]['createdAt'] as String,
      ).toLocal(),
      updatedAt: fileStat.modified,
      tags: extractNoteTags(content),
    );
  }

  /*
   * 递归收集指定普通文件夹下的笔记包目录。
   *
   * 遇到笔记包后停止向内递归，因此 assets 和其他包内目录不会进入应用目录树。
   */
  Future<void> collectPackageDirectories(
    Directory currentDirectory,
    List<Directory> packageDirectories,
  ) async {
    final List<FileSystemEntity> entities =
        currentDirectory.listSync(followLinks: false)..sort(
          (FileSystemEntity left, FileSystemEntity right) =>
              left.path.compareTo(right.path),
        );

    for (final Directory directory in entities.whereType<Directory>()) {
      if (await isNotePackageDirectory(directory)) {
        packageDirectories.add(directory);
        continue;
      }

      await collectPackageDirectories(directory, packageDirectories);
    }
  }

  /*
   * 读取全部有效笔记包目录。
   */
  Future<List<Directory>> loadPackageDirectories() async {
    final Directory noteDirectory = await getNoteDirectory();
    final List<Directory> packageDirectories = <Directory>[];

    await collectPackageDirectories(noteDirectory, packageDirectories);
    return packageDirectories;
  }

  /*
   * 读取指定笔记包内直接子级的全部 Markdown 文档。
   */
  Future<List<NoteItem>> loadPackageNotes(String packageRelativePath) async {
    final Directory noteDirectory = await getNoteDirectory();
    final Directory packageDirectory = await getDirectoryByRelativePath(
      packageRelativePath,
    );

    if (await readPackageMetadata(packageDirectory) == null) {
      throw Exception('目标文件夹不是有效笔记包');
    }

    return loadPackageNotesFromDirectory(packageDirectory, noteDirectory);
  }

  /*
   * 从真实笔记包目录读取全部 Markdown 文档。
   */
  Future<List<NoteItem>> loadPackageNotesFromDirectory(
    Directory packageDirectory,
    Directory noteDirectory,
  ) async {
    final List<File> markdownFiles =
        packageDirectory
            .listSync(followLinks: false)
            .whereType<File>()
            .where((File file) => file.path.toLowerCase().endsWith('.md'))
            .toList()
          ..sort(
            (File left, File right) => path
                .basename(left.path)
                .toLowerCase()
                .compareTo(path.basename(right.path).toLowerCase()),
          );
    final List<NoteItem> documents = <NoteItem>[];

    for (final File file in markdownFiles) {
      final String content = await file.readAsString();
      documents.add(
        await createNoteItem(file, content, noteDirectory, packageDirectory),
      );
    }

    return documents;
  }

  /*
   * 从笔记包文档列表中确定默认入口文档。
   *
   * 元数据中的 entry 无效时按文件名排序取第一篇，并修复元数据。
   */
  Future<NoteItem?> resolvePackageEntryNote(
    Directory packageDirectory,
    List<NoteItem> documents,
  ) async {
    if (documents.isEmpty) {
      return null;
    }

    final Map<String, dynamic>? metadata = await readPackageMetadata(
      packageDirectory,
    );
    final String? entryFileName = metadata?['entry'] is String
        ? path.posix.basename(metadata!['entry'] as String)
        : null;

    for (final NoteItem document in documents) {
      if (document.fileName == entryFileName) {
        return document;
      }
    }

    await writePackageMetadata(packageDirectory, documents.first.fileName);
    return documents.first;
  }

  /*
   * 创建首次启动时使用的欢迎笔记包。
   */
  Future<void> seedWelcomeNote() async {
    final String welcomeContent = <String>[
      '# 欢迎使用 myNote',
      '',
      '这是一个基于 Flutter 的 Markdown 笔记原型。',
      '',
      '- 每一个笔记包都可以包含多篇 Markdown 文档',
      '- 同一个笔记包内的文档共享 assets 文件夹',
      '- 普通文件夹继续用于整理不同笔记包',
      '',
      '> 现在就可以直接修改这篇文档。',
    ].join('\n');

    await createNotePackage(
      directoryPath: '',
      packageName: '欢迎使用 myNote',
      content: welcomeContent,
    );
  }

  /*
   * 读取首页需要展示的笔记包入口文档。
   *
   * 每个有效笔记包只返回一篇默认入口文档，包内其他文档由编辑区抽屉加载。
   */
  Future<List<NoteItem>> loadNotes() async {
    final Directory noteDirectory = await getNoteDirectory();
    List<Directory> packageDirectories = await loadPackageDirectories();
    final List<NoteItem> entryNotes = <NoteItem>[];

    for (final Directory packageDirectory in packageDirectories) {
      final List<NoteItem> documents = await loadPackageNotesFromDirectory(
        packageDirectory,
        noteDirectory,
      );
      final NoteItem? entryNote = await resolvePackageEntryNote(
        packageDirectory,
        documents,
      );
      if (entryNote != null) {
        entryNotes.add(entryNote);
      }
    }

    if (entryNotes.isEmpty) {
      await seedWelcomeNote();
      packageDirectories = await loadPackageDirectories();

      for (final Directory packageDirectory in packageDirectories) {
        final List<NoteItem> documents = await loadPackageNotesFromDirectory(
          packageDirectory,
          noteDirectory,
        );
        final NoteItem? entryNote = await resolvePackageEntryNote(
          packageDirectory,
          documents,
        );
        if (entryNote != null) {
          entryNotes.add(entryNote);
        }
      }
    }

    entryNotes.sort(
      (NoteItem left, NoteItem right) =>
          right.updatedAt.compareTo(left.updatedAt),
    );
    return entryNotes;
  }

  /*
   * 递归收集普通分类文件夹路径。
   *
   * 笔记包及其内部目录不会加入结果，因此 assets 对应用保持隐藏。
   */
  Future<void> collectFolderPaths(
    Directory currentDirectory,
    Directory noteDirectory,
    List<String> folderPaths,
  ) async {
    final List<FileSystemEntity> entities =
        currentDirectory.listSync(followLinks: false)..sort(
          (FileSystemEntity left, FileSystemEntity right) =>
              left.path.compareTo(right.path),
        );

    for (final Directory directory in entities.whereType<Directory>()) {
      if (await isNotePackageDirectory(directory)) {
        continue;
      }

      folderPaths.add(
        path
            .relative(directory.path, from: noteDirectory.path)
            .replaceAll('\\', '/'),
      );
      await collectFolderPaths(directory, noteDirectory, folderPaths);
    }
  }

  /*
   * 读取全部普通分类文件夹路径。
   */
  Future<List<String>> loadFolderPaths() async {
    final Directory noteDirectory = await getNoteDirectory();
    final List<String> folderPaths = <String>[];

    await collectFolderPaths(noteDirectory, noteDirectory, folderPaths);
    folderPaths.sort();
    return folderPaths;
  }

  /*
   * 创建一条新的空白笔记包及其入口文档。
   */
  Future<NoteItem> createNote({String directoryPath = ''}) async {
    final String content = createInitialNoteContent('新建笔记');
    return createNotePackage(
      directoryPath: directoryPath,
      packageName: extractNoteTitle(content),
      content: content,
    );
  }

  /*
   * 在指定普通文件夹内创建笔记包。
   */
  Future<NoteItem> createNotePackage({
    required String directoryPath,
    required String packageName,
    required String content,
  }) async {
    final Directory noteDirectory = await getNoteDirectory();
    final Directory parentDirectory = await getDirectoryByRelativePath(
      directoryPath,
    );

    if (await isNotePackageDirectory(parentDirectory)) {
      throw Exception('不能在另一个笔记包内创建笔记包');
    }

    final Directory packageDirectory = await createAvailableDirectory(
      Directory(
        '${parentDirectory.path}${Platform.pathSeparator}${sanitizeFileName(packageName)}',
      ),
    );
    final String documentFileName = createFileNameFromTitle(
      extractNoteTitle(content),
    );
    final File documentFile = File(
      '${packageDirectory.path}${Platform.pathSeparator}$documentFileName',
    );

    await packageDirectory.create(recursive: true);
    await documentFile.writeAsString(content, flush: true);
    // 元数据最后写入，只有结构完整的文件夹才会被应用识别为笔记包。
    await writePackageMetadata(
      packageDirectory,
      documentFileName,
      createdDocumentName: documentFileName,
    );

    return createNoteItem(
      documentFile,
      content,
      noteDirectory,
      packageDirectory,
    );
  }

  /*
   * 在指定普通文件夹内创建子文件夹并返回实际相对路径。
   */
  Future<String> createFolder(
    String parentDirectoryPath,
    String folderName,
  ) async {
    final Directory noteDirectory = await getNoteDirectory();
    final Directory parentDirectory = await getDirectoryByRelativePath(
      parentDirectoryPath,
    );

    if (await isNotePackageDirectory(parentDirectory)) {
      throw Exception('不能在笔记包内部创建普通文件夹');
    }

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
   * 在指定笔记包内创建新的 Markdown 文档。
   */
  Future<NoteItem> createPackageNote(String packageRelativePath) async {
    final Directory noteDirectory = await getNoteDirectory();
    final Directory packageDirectory = await getDirectoryByRelativePath(
      packageRelativePath,
    );

    if (await readPackageMetadata(packageDirectory) == null) {
      throw Exception('目标文件夹不是有效笔记包');
    }

    // 只保留空的一级标题结构，不预填标题文字或正文。
    const String content = '# \n';
    final File targetFile = await createAvailableFile(
      File('${packageDirectory.path}${Platform.pathSeparator}新建文档.md'),
      useUnderscoreSuffix: true,
    );

    await targetFile.writeAsString(content, encoding: utf8, flush: true);
    await writePackageMetadata(
      packageDirectory,
      (await readPackageMetadata(packageDirectory))!['entry'] as String,
      createdDocumentName: path.basename(targetFile.path),
    );
    return createNoteItem(targetFile, content, noteDirectory, packageDirectory);
  }

  /*
   * 将指定 Markdown 设置为所属笔记包的默认入口文档。
   */
  Future<void> setPackageEntryNote(NoteItem note) async {
    final Directory packageDirectory = await getDirectoryByRelativePath(
      note.packageRelativePath,
    );
    final File documentFile = await getNoteFileByRelativePath(
      note.relativePath,
    );

    if (await readPackageMetadata(packageDirectory) == null ||
        documentFile.parent.path != packageDirectory.path ||
        !await documentFile.exists()) {
      throw Exception('目标 Markdown 不属于有效笔记包');
    }

    await writePackageMetadata(packageDirectory, note.fileName);
  }

  /*
   * 保存指定 Markdown 文档内容。
   *
   * 标题变化时只重命名当前 Markdown；笔记包目录与共享 assets 不受影响。
   */
  Future<NoteItem> saveNoteContent(String relativePath, String content) async {
    final Directory noteDirectory = await getNoteDirectory();
    final File file = await getNoteFileByRelativePath(relativePath);
    final Directory packageDirectory = file.parent;
    final Map<String, dynamic> metadata = await _ensureCreationTimes(
      packageDirectory,
      file,
    );

    // 尚未输入内容时保留新建名称及序号，避免自动保存改变空文档名称。
    final String nextFileName = stripMarkdownSyntax(content).isEmpty
        ? path.basename(file.path)
        : createFileNameFromTitle(extractNoteTitle(content));
    File targetFile = file;

    if (fileNameNeedsRename(path.basename(file.path), nextFileName)) {
      targetFile = await createAvailableFile(
        File('${packageDirectory.path}${Platform.pathSeparator}$nextFileName'),
        preferredSourcePath: file.path,
      );

      if (await file.exists()) {
        targetFile = await file.rename(targetFile.path);
      }
    }

    await targetFile.writeAsString(content, flush: true);
    if (path.basename(targetFile.path) != path.basename(file.path)) {
      final Map<String, dynamic> documents = Map<String, dynamic>.from(
        metadata['documents'] as Map,
      );
      documents[path.basename(targetFile.path)] = documents.remove(
        path.basename(file.path),
      );
      metadata['documents'] = documents;
      if (metadata['entry'] == path.basename(file.path)) {
        metadata['entry'] = path.basename(targetFile.path);
      }
      await _savePackageMetadata(packageDirectory, metadata);
    }

    return createNoteItem(targetFile, content, noteDirectory, packageDirectory);
  }

  /*
   * 移动指定笔记包到目标普通文件夹。
   *
   * 传入的 NoteItem 只用于定位所属笔记包，实际移动的是整个包目录。
   */
  Future<NoteItem> moveNoteToDirectory(
    NoteItem note,
    String targetDirectoryPath,
  ) async {
    if (note.directoryPath == targetDirectoryPath) {
      return note;
    }

    final Directory noteDirectory = await getNoteDirectory();
    final Directory sourcePackageDirectory = await getDirectoryByRelativePath(
      note.packageRelativePath,
    );
    final Directory targetParentDirectory = await getDirectoryByRelativePath(
      targetDirectoryPath,
    );

    if (await readPackageMetadata(sourcePackageDirectory) == null) {
      throw Exception('当前条目不属于有效笔记包');
    }
    if (await isNotePackageDirectory(targetParentDirectory)) {
      throw Exception('笔记包不能移动到另一个笔记包内部');
    }

    await targetParentDirectory.create(recursive: true);
    final Directory targetPackageDirectory = await createAvailableDirectory(
      Directory(
        '${targetParentDirectory.path}${Platform.pathSeparator}${path.basename(sourcePackageDirectory.path)}',
      ),
      preferredSourcePath: sourcePackageDirectory.path,
    );
    final Directory movedPackageDirectory = await sourcePackageDirectory.rename(
      targetPackageDirectory.path,
    );
    final List<NoteItem> movedDocuments = await loadPackageNotesFromDirectory(
      movedPackageDirectory,
      noteDirectory,
    );
    final NoteItem? entryNote = await resolvePackageEntryNote(
      movedPackageDirectory,
      movedDocuments,
    );

    if (entryNote == null) {
      throw Exception('笔记包内没有可打开的 Markdown 文档');
    }

    return entryNote;
  }

  /*
   * 移动指定普通文件夹到目标父文件夹。
   *
   * 文件夹内的普通子文件夹和笔记包会一起移动。
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

    if (await isNotePackageDirectory(sourceDirectory)) {
      throw Exception('笔记包必须使用笔记包移动操作');
    }
    if (await isNotePackageDirectory(targetParentDirectory)) {
      throw Exception('普通文件夹不能移动到笔记包内部');
    }

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
   * 从 Markdown AST 与原始 HTML 中递归收集本地资源引用。
   */
  void _collectMarkdownResourceSources(
    markdown.Node node,
    Set<String> resourceSources,
  ) {
    if (node is markdown.Element) {
      if (node.tag == 'pre' || node.tag == 'code') {
        return;
      }
      if (node.tag == 'img' && node.attributes['src'] != null) {
        resourceSources.add(node.attributes['src']!);
      } else if (node.tag == 'a' && node.attributes['href'] != null) {
        resourceSources.add(node.attributes['href']!);
      }

      for (final markdown.Node child
          in node.children ?? const <markdown.Node>[]) {
        _collectMarkdownResourceSources(child, resourceSources);
      }
    } else if (node is markdown.Text && node.text.contains('<')) {
      _collectHtmlResourceSources(node.text, resourceSources);
    }
  }

  /*
   * 从 Markdown AST 中确认过的原始 HTML 片段收集本地资源引用。
   */
  void _collectHtmlResourceSources(
    String htmlText,
    Set<String> resourceSources,
  ) {
    for (final element
        in html_parser
            .parseFragment(htmlText)
            .querySelectorAll('img[src], a[href]')) {
      final String? source = element.localName == 'img'
          ? element.attributes['src']
          : element.attributes['href'];
      if (source != null) {
        resourceSources.add(source);
      }
    }
  }

  /*
   * 将资源引用解析为笔记包 assets 内部的规范化真实路径。
   */
  String? _resolvePackageResourcePath(
    String resourceSource,
    File documentFile,
    Directory assetsDirectory,
  ) {
    final Uri? resourceUri = Uri.tryParse(resourceSource.trim());
    if (resourceUri == null ||
        resourceUri.hasScheme ||
        resourceUri.hasAuthority ||
        resourceUri.path.isEmpty) {
      return null;
    }

    String decodedPath;
    try {
      decodedPath = Uri.decodeComponent(
        resourceUri.path,
      ).replaceAll('\\', Platform.pathSeparator);
    } on FormatException {
      return null;
    }
    decodedPath = decodedPath.replaceAll('/', Platform.pathSeparator);
    if (path.isAbsolute(decodedPath)) {
      return null;
    }

    final String resolvedPath = path.normalize(
      path.join(documentFile.parent.path, decodedPath),
    );
    final String comparableAssetsPath = _getComparableFileSystemPath(
      assetsDirectory.path,
    );
    final String comparableResolvedPath = _getComparableFileSystemPath(
      resolvedPath,
    );
    if (!comparableResolvedPath.startsWith(
      '$comparableAssetsPath${Platform.pathSeparator}',
    )) {
      return null;
    }

    return comparableResolvedPath;
  }

  /*
   * 获取适合当前文件系统进行集合比较的规范化路径。
   */
  String _getComparableFileSystemPath(String fileSystemPath) {
    final String normalizedPath = path.normalize(fileSystemPath);
    return Platform.isWindows ? normalizedPath.toLowerCase() : normalizedPath;
  }

  /*
   * 收集单篇 Markdown 指向笔记包 assets 的全部文件路径。
   */
  Set<String> _collectPackageResourcePaths(
    NoteItem note,
    File documentFile,
    Directory assetsDirectory,
  ) {
    final Set<String> resourceSources = <String>{};
    final markdown.Document markdownDocument = markdown.Document(
      encodeHtml: false,
      extensionSet: markdown.ExtensionSet.gitHubFlavored,
    );

    for (final markdown.Node node in markdownDocument.parse(note.content)) {
      _collectMarkdownResourceSources(node, resourceSources);
    }

    return resourceSources
        .map(
          (String source) => _resolvePackageResourcePath(
            source,
            documentFile,
            assetsDirectory,
          ),
        )
        .whereType<String>()
        .toSet();
  }

  /*
   * 递归删除资源清理后已经为空的 assets 子目录和根目录。
   */
  Future<void> _deleteEmptyAssetDirectories(Directory directory) async {
    if (!await directory.exists()) {
      return;
    }

    for (final Directory childDirectory
        in directory.listSync(followLinks: false).whereType<Directory>()) {
      await _deleteEmptyAssetDirectories(childDirectory);
    }
    if (await directory.list(followLinks: false).isEmpty) {
      await directory.delete();
    }
  }

  /*
   * 删除笔记包内当前 Markdown，并清理仅由它引用的 assets 资源。
   *
   * 删除最后一篇 Markdown 时直接删除整个笔记包，避免留下无法打开的空包。
   */
  Future<NoteItem?> deletePackageDocument(String relativePath) async {
    final Directory noteDirectory = await getNoteDirectory();
    final File documentFile = await getNoteFileByRelativePath(relativePath);
    final Directory packageDirectory = documentFile.parent;
    final Map<String, dynamic>? metadata = await readPackageMetadata(
      packageDirectory,
    );

    if (metadata == null || !await documentFile.exists()) {
      throw Exception('当前 Markdown 不属于有效笔记包');
    }

    final List<NoteItem> packageNotes = await loadPackageNotesFromDirectory(
      packageDirectory,
      noteDirectory,
    );
    NoteItem? currentNote;
    for (final NoteItem note in packageNotes) {
      if (note.relativePath == relativePath) {
        currentNote = note;
        break;
      }
    }
    if (currentNote == null) {
      throw Exception('当前 Markdown 文件不存在');
    }
    if (packageNotes.length == 1) {
      await packageDirectory.delete(recursive: true);
      return null;
    }

    final Directory assetsDirectory = Directory(
      path.join(packageDirectory.path, packageAssetsDirectoryName),
    );
    final Set<String> currentResourcePaths = _collectPackageResourcePaths(
      currentNote,
      documentFile,
      assetsDirectory,
    );
    final Set<String> remainingResourcePaths = <String>{};
    final NoteItem nextEntryNote = packageNotes.firstWhere(
      (NoteItem note) => note.relativePath != relativePath,
    );

    for (final NoteItem note in packageNotes) {
      if (note.relativePath == relativePath) {
        continue;
      }
      remainingResourcePaths.addAll(
        _collectPackageResourcePaths(
          note,
          await getNoteFileByRelativePath(note.relativePath),
          assetsDirectory,
        ),
      );
    }

    if (metadata['entry'] == currentNote.fileName) {
      await writePackageMetadata(packageDirectory, nextEntryNote.fileName);
    }
    await documentFile.delete();
    final Map<String, dynamic> remainingMetadata = (await readPackageMetadata(
      packageDirectory,
    ))!;
    if (remainingMetadata['documents'] is Map) {
      (remainingMetadata['documents'] as Map).remove(currentNote.fileName);
      await _savePackageMetadata(packageDirectory, remainingMetadata);
    }

    for (final String resourcePath in currentResourcePaths.difference(
      remainingResourcePaths,
    )) {
      final File resourceFile = File(resourcePath);
      if (await resourceFile.exists()) {
        await resourceFile.delete();
      }
    }
    await _deleteEmptyAssetDirectories(assetsDirectory);
    return nextEntryNote;
  }

  /*
   * 删除指定 Markdown 所属的整个笔记包。
   */
  Future<void> deleteNote(String relativePath) async {
    final File documentFile = await getNoteFileByRelativePath(relativePath);
    final Directory packageDirectory = documentFile.parent;

    if (await readPackageMetadata(packageDirectory) == null) {
      throw Exception('当前 Markdown 不属于有效笔记包');
    }

    await packageDirectory.delete(recursive: true);
  }

  /*
   * 删除指定普通文件夹及其内部内容。
   */
  Future<void> deleteFolder(String relativePath) async {
    final Directory directory = await getDirectoryByRelativePath(relativePath);

    if (await directory.exists()) {
      if (await isNotePackageDirectory(directory)) {
        throw Exception('笔记包必须使用笔记包删除操作');
      }
      await directory.delete(recursive: true);
    }
  }

  /*
   * 为目标文件生成不冲突的实际文件路径。
   */
  Future<File> createAvailableFile(
    File targetFile, {
    String? preferredSourcePath,
    bool useUnderscoreSuffix = false,
  }) async {
    if (!await targetFile.exists() || targetFile.path == preferredSourcePath) {
      return targetFile;
    }

    final String directoryPath = targetFile.parent.path;
    final String baseName = path.basenameWithoutExtension(targetFile.path);
    final String extension = path.extension(targetFile.path);
    // 新建子文档采用从 2 开始的下划线序号，其他操作维持原有命名规则。
    int index = useUnderscoreSuffix ? 2 : 1;

    while (true) {
      final File candidateFile = File(
        '$directoryPath${Platform.pathSeparator}$baseName${useUnderscoreSuffix ? '_$index' : '-$index'}$extension',
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
   * 判断当前 Markdown 文件名是否需要按标题重命名。
   */
  bool fileNameNeedsRename(String currentFileName, String nextFileName) {
    return currentFileName != nextFileName;
  }
}
