/*
 * 文件说明：验证新建子文档的空标题、重名序号及首次输入后的命名行为。
 */
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_note/controllers/markdown_editor_controller.dart';
import 'package:my_note/services/note_storage_service.dart';

/*
 * 将存储操作限制在独立的临时测试目录。
 */
class _TestStorage extends NoteStorageService {
  // 初始化测试使用的根目录。
  _TestStorage(this.root);

  final Directory root;

  // 返回临时目录，避免访问真实笔记。
  @override
  Future<Directory> getNoteDirectory() async => root;
}

/*
 * 注册新建子文档的完整保存流程测试。
 */
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // 验证空标题能编辑为一级标题，且保存及重新加载不会丢失默认名称。
  test('新建子文档保留空一级标题并使用下划线序号', () async {
    final Directory root = await Directory.systemTemp.createTemp('new_note_');
    final _TestStorage storage = _TestStorage(root);
    try {
      final entry = await storage.createNotePackage(
        directoryPath: '',
        packageName: '测试包',
        content: '# 入口\n',
      );
      for (int index = 1; index <= 3; index++) {
        final note = await storage.createPackageNote(entry.packageRelativePath);
        final String name = index == 1 ? '新建文档' : '新建文档_$index';
        expect(note.fileName, '$name.md');
        expect(note.title, name);
        final controller = MarkdownEditorController(
          initialMarkdown: note.content,
        );
        try {
          expect(controller.quillController.document.toPlainText(), '\n');
          expect(controller.quillController.document.toDelta().toJson(), [
            {
              'insert': '\n',
              'attributes': {'header': 1},
            },
          ]);
          final saved = await storage.saveNoteContent(
            note.relativePath,
            controller.markdownText,
          );
          expect(saved.fileName, note.fileName);
          expect(saved.title, name);
          // 实际键入后应生成一级标题，验证用户能够直接填写标题。
          controller.quillController.replaceText(
            0,
            0,
            '用户输入',
            const TextSelection.collapsed(offset: 4),
          );
          await Future<void>.delayed(Duration.zero);
          expect(controller.markdownText.trim(), '# 用户输入');
        } finally {
          controller.dispose();
        }
      }
      final renamed = await storage.saveNoteContent(
        '${entry.packageRelativePath}/新建文档_3.md',
        '# 用户标题\n',
      );
      expect(renamed.fileName, '用户标题.md');
    } finally {
      await root.delete(recursive: true);
    }
  });
}
