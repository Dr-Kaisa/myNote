/*
 * 文件说明：笔记文档实体模型文件，定义笔记包内单条 Markdown 文档的基础结构。
 *
 * 这个文件只定义数据，不负责界面，也不负责读写文件。
 * NoteStorageService 从笔记包内读取 .md 文件后，会把文件内容整理成 NoteItem，
 * 页面再根据 NoteItem 渲染笔记包入口、编辑区标题和文档切换列表。
 */

/*
 * 单条 Markdown 文档实体模型。
 *
 * 可以把 NoteItem 理解成“笔记包里的一个文档”。
 * 它把笔记包、文件名、目录、标题、摘要、正文、更新时间、标签都放在一个对象里。
 */
class NoteItem {
  /*
   * 构造单条 Markdown 文档实体。
   *
   * required 表示创建 NoteItem 时必须传入这些字段，避免出现字段缺失的半成品对象。
   */
  const NoteItem({
    required this.id,
    required this.fileName,
    required this.relativePath,
    required this.packageRelativePath,
    required this.packageName,
    required this.directoryPath,
    required this.title,
    required this.preview,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
    required this.tags,
  });

  /*
   * Markdown 文档唯一标识。
   *
   * 当前使用相对路径作为 id，因为同一个笔记根目录下相对路径不会重复。
   */
  final String id;

  /*
   * Markdown 文档文件名。
   *
   * 只包含文件名本身，例如 “旅行计划.md”，不包含上级目录。
   */
  final String fileName;

  /*
   * Markdown 文档相对于笔记根目录的路径。
   *
   * 例如 “前端/3.JS/JS.md”。
   */
  final String relativePath;

  /*
   * 所属笔记包相对于笔记根目录的路径。
   *
   * 例如 “前端/3.JS”。
   */
  final String packageRelativePath;

  /*
   * 所属笔记包名称。
   *
   * 例如 “3.JS”。笔记包名称与包内 Markdown 文件名不要求相同。
   */
  final String packageName;

  /*
   * 笔记包父目录相对于笔记根目录的路径。
   *
   * 根目录下的笔记包这里是空字符串；“前端/3.JS” 的父目录是 “前端”。
   */
  final String directoryPath;

  /*
   * Markdown 文档标题。
   *
   * 通常来自 Markdown 正文的第一行非空文本。
   */
  final String title;

  /*
   * Markdown 文档摘要。
   *
   * 用于首页卡片展示，通常是去掉 Markdown 语法后的正文开头。
   */
  final String preview;

  /*
   * Markdown 文档正文内容。
   *
   * 这里保存完整 Markdown 文本，会放进编辑器里展示和修改。
   */
  final String content;

  /*
   * 创建时间。
   *
   * 来自文件系统可用的创建或状态变更时间，用于首页按创建时间排序。
   */
  final DateTime createdAt;

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
   * 基于当前实体创建一份更新后的副本。
   *
   * Dart 里的对象通常倾向于不可变：字段都是 final，创建后不直接改。
   * 如果只想改其中一两个字段，就用 copyWith 复制一份新对象。
   */
  NoteItem copyWith({
    String? id,
    String? fileName,
    String? relativePath,
    String? packageRelativePath,
    String? packageName,
    String? directoryPath,
    String? title,
    String? preview,
    String? content,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<String>? tags,
  }) {
    return NoteItem(
      // 如果调用方传了新值就用新值，否则沿用当前对象原来的值。
      id: id ?? this.id,
      fileName: fileName ?? this.fileName,
      relativePath: relativePath ?? this.relativePath,
      packageRelativePath: packageRelativePath ?? this.packageRelativePath,
      packageName: packageName ?? this.packageName,
      directoryPath: directoryPath ?? this.directoryPath,
      title: title ?? this.title,
      preview: preview ?? this.preview,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      tags: tags ?? this.tags,
    );
  }
}
