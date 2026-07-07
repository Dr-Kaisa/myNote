/*
 * 文件说明：笔记实体模型文件，定义单条 Markdown 笔记在界面中的基础结构。
 *
 * 这个文件只定义数据，不负责界面，也不负责读写文件。
 * NoteStorageService 从磁盘读取 .md 文件后，会把文件内容整理成 NoteItem，
 * 页面再根据 NoteItem 渲染笔记卡片、编辑区标题和路径信息。
 */

/*
 * 单条笔记实体模型。
 *
 * 可以把 NoteItem 理解成“界面认识的一条笔记”。
 * 它把文件名、目录、标题、摘要、正文、更新时间、标签都放在一个对象里。
 */
class NoteItem {
  /*
   * 构造单条笔记实体。
   *
   * required 表示创建 NoteItem 时必须传入这些字段，避免出现字段缺失的半成品对象。
   */
  const NoteItem({
    required this.id,
    required this.fileName,
    required this.relativePath,
    required this.directoryPath,
    required this.title,
    required this.preview,
    required this.content,
    required this.updatedAt,
    required this.tags,
  });

  /*
   * 笔记唯一标识。
   *
   * 当前使用相对路径作为 id，因为同一个笔记根目录下相对路径不会重复。
   */
  final String id;

  /*
   * 笔记文件名。
   *
   * 只包含文件名本身，例如 “旅行计划.md”，不包含上级目录。
   */
  final String fileName;

  /*
   * 笔记相对于笔记根目录的路径。
   *
   * 例如根目录下是 “旅行计划.md”，文件夹里是 “生活/旅行计划.md”。
   */
  final String relativePath;

  /*
   * 笔记所在目录相对于笔记根目录的路径。
   *
   * 根目录笔记这里是空字符串；文件夹内笔记例如 “生活” 或 “生活/旅行”。
   */
  final String directoryPath;

  /*
   * 笔记标题。
   *
   * 通常来自 Markdown 正文的第一行非空文本。
   */
  final String title;

  /*
   * 笔记摘要。
   *
   * 用于首页卡片展示，通常是去掉 Markdown 语法后的正文开头。
   */
  final String preview;

  /*
   * 笔记正文内容。
   *
   * 这里保存完整 Markdown 文本，会放进编辑器里展示和修改。
   */
  final String content;

  /*
   * 最后更新时间。
   *
   * 来自文件系统的修改时间，用于排序和显示日期。
   */
  final DateTime updatedAt;

  /*
   * 笔记标签集合。
   *
   * 从正文里的 #标签 提取出来，目前保留给后续分类或搜索使用。
   */
  final List<String> tags;

  /*
   * 用于界面展示的相对位置文案。
   *
   * 根目录笔记只显示标题；文件夹里的笔记显示 “文件夹/标题”。
   */
  String get displayPath {
    if (directoryPath.isEmpty) {
      return title;
    }

    return '$directoryPath/$title';
  }

  /*
   * 基于当前实体创建一份更新后的副本。
   *
   * Dart 里的对象通常倾向于不可变：字段都是 final，创建后不直接改。
   * 如果只想改其中一两个字段，就用 copyWith 复制一份新对象。
   */
  NoteItem copyWith({
    String? id,
    String? fileName,
    String? relativePath,
    String? directoryPath,
    String? title,
    String? preview,
    String? content,
    DateTime? updatedAt,
    List<String>? tags,
  }) {
    return NoteItem(
      // 如果调用方传了新值就用新值，否则沿用当前对象原来的值。
      id: id ?? this.id,
      fileName: fileName ?? this.fileName,
      relativePath: relativePath ?? this.relativePath,
      directoryPath: directoryPath ?? this.directoryPath,
      title: title ?? this.title,
      preview: preview ?? this.preview,
      content: content ?? this.content,
      updatedAt: updatedAt ?? this.updatedAt,
      tags: tags ?? this.tags,
    );
  }
}
