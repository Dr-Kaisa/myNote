/*
 * 文件说明：笔记实体模型文件，定义单条 Markdown 笔记在界面中的基础结构。
 */

/*
 * 单条笔记实体模型。
 */
class NoteItem {
  /*
   * 构造单条笔记实体。
   */
  const NoteItem({
    required this.id,
    required this.fileName,
    required this.title,
    required this.preview,
    required this.content,
    required this.updatedAt,
  });

  /*
   * 笔记唯一标识。
   */
  final String id;

  /*
   * 笔记文件名。
   */
  final String fileName;

  /*
   * 笔记标题。
   */
  final String title;

  /*
   * 笔记摘要。
   */
  final String preview;

  /*
   * 笔记正文内容。
   */
  final String content;

  /*
   * 最后更新时间。
   */
  final DateTime updatedAt;

  /*
   * 基于当前实体创建一份更新后的副本。
   */
  NoteItem copyWith({
    String? id,
    String? fileName,
    String? title,
    String? preview,
    String? content,
    DateTime? updatedAt,
  }) {
    return NoteItem(
      id: id ?? this.id,
      fileName: fileName ?? this.fileName,
      title: title ?? this.title,
      preview: preview ?? this.preview,
      content: content ?? this.content,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}


