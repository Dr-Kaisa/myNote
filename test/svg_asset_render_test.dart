/*
 * 文件说明：自定义 SVG 图标资源测试文件，验证应用资源可以被 Flutter 正常解析和渲染。
 */
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

/*
 * 注册自定义 SVG 图标资源相关测试。
 */
void main() {
  /*
   * 验证左上角返回图标资源能够正常加载且不会产生渲染异常。
   */
  testWidgets('左上角返回 SVG 图标可以正常渲染', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SvgPicture.asset(
              'assets/icon/left_arrow.svg',
              // 测试图标尺寸样式
              width: 24,
              height: 24,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SvgPicture), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
