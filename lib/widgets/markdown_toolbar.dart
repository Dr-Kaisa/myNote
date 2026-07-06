/*
 * 文件说明：Markdown 工具栏组件文件，提供常用的轻量编辑操作入口。
 */
import 'package:flutter/material.dart';

/*
 * 工具栏动作类型。
 */
enum ToolbarActionKey { title, subtitle, bold, list, todo, quote }

/*
 * 工具栏动作数据模型。
 */
class ToolbarActionItem {
  /*
   * 构造工具栏动作项。
   */
  const ToolbarActionItem({required this.key, required this.label});

  /*
   * 动作唯一标识。
   */
  final ToolbarActionKey key;

  /*
   * 按钮展示文案。
   */
  final String label;
}

const List<ToolbarActionItem> toolbarActions = <ToolbarActionItem>[
  ToolbarActionItem(key: ToolbarActionKey.title, label: '标题'),
  ToolbarActionItem(key: ToolbarActionKey.subtitle, label: '小标题'),
  ToolbarActionItem(key: ToolbarActionKey.bold, label: '加粗'),
  ToolbarActionItem(key: ToolbarActionKey.list, label: '列表'),
  ToolbarActionItem(key: ToolbarActionKey.todo, label: '待办'),
  ToolbarActionItem(key: ToolbarActionKey.quote, label: '引用'),
];

/*
 * Markdown 工具栏组件。
 */
class MarkdownToolbar extends StatelessWidget {
  /*
   * 工具栏构造方法。
   */
  const MarkdownToolbar({super.key, required this.onPressedAction});

  /*
   * 工具栏按钮点击回调。
   */
  final ValueChanged<ToolbarActionKey> onPressedAction;

  /*
   * 构建工具栏组件。
   */
  @override
  Widget build(BuildContext context) {
    return Container(
      // 工具栏容器装饰样式
      decoration: const BoxDecoration(
        color: Color(0xFF1C1C1C),
        border: Border(bottom: BorderSide(color: Color(0xFF262626))),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          // 工具栏按钮横向排列样式
          children: toolbarActions.map((ToolbarActionItem action) {
            return Padding(
              padding: const EdgeInsets.only(right: 10),
              child: OutlinedButton(
                onPressed: () {
                  onPressedAction(action.key);
                },
                style: OutlinedButton.styleFrom(
                  // 工具栏按钮外观样式
                  backgroundColor: const Color(0xFF242424),
                  side: const BorderSide(color: Color(0xFF333333)),
                  minimumSize: const Size(0, 34),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  action.label,
                  // 工具栏按钮文字样式
                  style: const TextStyle(
                    color: Color(0xFFE8E8E8),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
