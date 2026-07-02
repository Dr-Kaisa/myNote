/*
 * 文件说明：基础组件测试文件，用于验证应用根组件能够正常渲染。
 */
import 'package:flutter_test/flutter_test.dart';
import 'package:my_note/main.dart';

/*
 * 组件测试入口方法。
 */
void main() {
  /*
   * 验证应用根组件可以正常挂载。
   */
  testWidgets('应用根组件可以正常渲染', (WidgetTester tester) async {
    await tester.pumpWidget(const MyNoteApp());
    expect(find.text('myNote'), findsOneWidget);
  });
}


