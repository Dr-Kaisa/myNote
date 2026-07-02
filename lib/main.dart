/*
 * 文件说明：Flutter 应用入口文件，负责启动 myNote 笔记原型。
 */
import 'package:flutter/material.dart';
import 'package:my_note/widgets/note_home_page.dart';

/*
 * 应用启动入口方法。
 */
void main() {
  runApp(const MyNoteApp());
}

/*
 * 应用根组件。
 */
class MyNoteApp extends StatelessWidget {
  /*
   * 根组件构造方法。
   */
  const MyNoteApp({super.key});

  /*
   * 构建应用根节点。
   */
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'myNote',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFF3B12E)),
        scaffoldBackgroundColor: const Color(0xFFF5F6FA),
        useMaterial3: true,
      ),
      home: const NoteHomePage(),
    );
  }
}


