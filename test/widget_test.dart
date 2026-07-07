/*
 * 文件说明：基础组件测试文件，用于验证应用根组件能够正常渲染。
 *
 * test 目录里的文件不会打包进正式应用，只在开发时用于自动化验证。
 * 这个测试属于 Flutter 组件测试：它会把 Widget 放进测试环境里渲染，然后检查界面。
 */
import 'package:flutter_test/flutter_test.dart';
import 'package:my_note/main.dart';

/*
 * 组件测试入口方法。
 *
 * 测试文件里的 main 不是应用启动入口，而是测试运行器的入口。
 * flutter test 会执行这里注册的所有测试用例。
 */
void main() {
  /*
   * 验证应用根组件可以正常挂载。
   *
   * testWidgets 用来测试 Flutter 组件。
   * WidgetTester 可以理解成测试里的“虚拟用户”和“虚拟屏幕”。
   */
  testWidgets('应用根组件可以正常渲染', (WidgetTester tester) async {
    // pumpWidget 会把 MyNoteApp 放进测试环境并触发一次渲染。
    await tester.pumpWidget(const MyNoteApp());
    // expect 是断言：如果找不到指定文字，测试就会失败。
    expect(find.text('myNote'), findsOneWidget);
  });
}
