/*
 * 文件说明：网页链接元数据服务测试文件，验证站点名称解析顺序与网址访问限制。
 */
import 'package:flutter_test/flutter_test.dart';
import 'package:my_note/services/web_link_metadata_service.dart';

/*
 * 注册网页链接元数据服务相关测试。
 */
void main() {
  /*
   * 验证站点名称元数据优先于应用名称和页面标题，并会整理多余空白。
   */
  test('优先读取网页声明的站点名称', () async {
    final WebLinkMetadataService service = WebLinkMetadataService(
      pageLoader: (Uri uri) async => '''
        <html>
          <head>
            <meta PROPERTY="OG:SITE_NAME" content="  示例   站点  ">
            <meta name="application-name" content="备用应用名">
            <title>备用标题</title>
          </head>
        </html>
      ''',
    );

    expect(await service.loadSiteName('https://example.com/note'), '示例 站点');
  });

  /*
   * 验证没有专用元数据时可以从 DeepSeek 页面标题读取站点名称。
   */
  test('缺少站点元数据时读取页面标题', () async {
    final WebLinkMetadataService service = WebLinkMetadataService(
      pageLoader: (Uri uri) async => '''
        <!doctype html>
        <html><head><title>DeepSeek</title></head></html>
      ''',
    );

    expect(
      await service.loadSiteName('https://chat.deepseek.com/'),
      'DeepSeek',
    );
  });

  /*
   * 验证非法协议和本地地址不会触发自动网页访问。
   */
  test('拒绝非网页协议和本地地址', () async {
    int loadCount = 0;
    final WebLinkMetadataService service = WebLinkMetadataService(
      pageLoader: (Uri uri) async {
        loadCount += 1;
        return '<title>不应读取</title>';
      },
    );

    expect(await service.loadSiteName('file:///tmp/note.md'), isNull);
    expect(await service.loadSiteName('http://127.0.0.1/'), isNull);
    expect(await service.loadSiteName('http://localhost/'), isNull);
    expect(
      await service.loadSiteName('https://example.com/ two-links'),
      isNull,
    );
    expect(loadCount, 0);
  });

  /*
   * 验证空标题和异常长标题都会回退为原始网址显示。
   */
  test('过滤空标题和异常长标题', () async {
    final WebLinkMetadataService emptyTitleService = WebLinkMetadataService(
      pageLoader: (Uri uri) async => '<title>   </title>',
    );
    final WebLinkMetadataService longTitleService = WebLinkMetadataService(
      pageLoader: (Uri uri) async =>
          '<title>${List<String>.filled(101, '站').join()}</title>',
    );

    expect(
      await emptyTitleService.loadSiteName('https://example.com/'),
      isNull,
    );
    expect(await longTitleService.loadSiteName('https://example.com/'), isNull);
  });
}
