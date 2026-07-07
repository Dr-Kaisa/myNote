/*
 * 文件说明：Markdown 工具栏组件文件，提供常用的轻量编辑操作入口。
 *
 * 这个文件只负责“工具栏长什么样”和“点了哪个按钮”。
 * 真正把文字变成标题、加粗、列表的逻辑在 note_home_page.dart 和 markdown_helper.dart 里。
 */
import 'package:flutter/material.dart';

/*
 * 工具栏动作类型。
 *
 * enum 是一组固定选项。
 * 这里用它表示工具栏支持哪些操作，避免到处写容易拼错的字符串。
 */
enum ToolbarActionKey {
  // 插入一级标题 Markdown 语法。
  title,

  // 插入二级标题 Markdown 语法。
  subtitle,

  // 给选中文字加粗。
  bold,

  // 把当前行变成列表项。
  list,

  // 把当前行变成待办项。
  todo,

  // 把当前行变成引用块。
  quote,
}

/*
 * 工具栏动作数据模型。
 *
 * 这个类把“内部动作 key”和“按钮显示文案”绑在一起。
 * 比如 key 是 ToolbarActionKey.bold，按钮上显示的文字是“加粗”。
 */
class ToolbarActionItem {
  /*
   * 构造工具栏动作项。
   */
  const ToolbarActionItem({required this.key, required this.label});

  /*
   * 动作唯一标识。
   *
   * 页面根据这个 key 判断用户点的是标题、加粗还是列表。
   */
  final ToolbarActionKey key;

  /*
   * 按钮展示文案。
   *
   * label 是用户能看见的文字。
   */
  final String label;
}

/*
 * 工具栏按钮配置列表。
 *
 * MarkdownToolbar 会遍历这个列表，为每一项生成一个按钮。
 * 想增删工具栏按钮时，通常先改这里。
 */
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
 *
 * StatelessWidget 表示这个组件自己不保存状态。
 * 它只根据 toolbarActions 和外部传进来的 onPressedAction 生成界面。
 */
class MarkdownToolbar extends StatelessWidget {
  /*
   * 工具栏构造方法。
   */
  const MarkdownToolbar({super.key, required this.onPressedAction});

  /*
   * 工具栏按钮点击回调。
   *
   * ValueChanged<ToolbarActionKey> 可以理解成一个函数：
   * 当用户点击按钮时，把对应的 ToolbarActionKey 传回父组件。
   */
  final ValueChanged<ToolbarActionKey> onPressedAction;

  /*
   * 构建工具栏组件。
   *
   * build 返回的 Widget 树就是工具栏最终显示的结构。
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
        // 工具栏按钮可能超出屏幕宽度，所以允许横向滚动。
        scrollDirection: Axis.horizontal,
        child: Row(
          // 工具栏按钮横向排列样式
          // map 会把每一个 ToolbarActionItem 转换成一个按钮 Widget。
          children: toolbarActions.map((ToolbarActionItem action) {
            return Padding(
              // 每个按钮右边留 10 像素，让按钮之间不要贴在一起。
              padding: const EdgeInsets.only(right: 10),
              child: OutlinedButton(
                onPressed: () {
                  // 点击按钮时，把当前按钮代表的动作交给父组件处理。
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
                  // 按钮上显示“标题”“加粗”“列表”等文字。
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
