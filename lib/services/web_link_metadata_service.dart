/*
 * 文件说明：网页链接元数据服务文件，负责读取网页 HTML 并提取适合作为链接文字的站点名称。
 *
 * 网络或解析失败时统一返回空结果，调用方会继续保留原始 URL，不影响用户编辑。
 */
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;

/*
 * 站点名称异步加载方法类型，供编辑控制器注入离线测试实现。
 */
typedef WebLinkSiteNameLoader = Future<String?> Function(String url);

/*
 * 网页正文异步加载方法类型，供元数据解析测试注入内存 HTML。
 */
typedef WebLinkPageLoader = Future<String?> Function(Uri uri);

/*
 * 网页链接元数据服务。
 */
class WebLinkMetadataService {
  /*
   * 构造网页链接元数据服务。
   */
  WebLinkMetadataService({WebLinkPageLoader? pageLoader})
    : _pageLoader = pageLoader ?? _loadWebPage;

  /*
   * 单次网络连接允许等待的最长时间。
   */
  static const Duration _connectionTimeout = Duration(seconds: 3);

  /*
   * 单次请求或响应读取允许等待的最长时间。
   */
  static const Duration _requestTimeout = Duration(seconds: 5);

  /*
   * 包含解析、跳转和正文读取在内的整次抓取最长时间。
   */
  static const Duration _totalLoadTimeout = Duration(seconds: 6);

  /*
   * 网页正文允许读取的最大字节数，避免异常页面占用过多内存。
   */
  static const int _maximumBodyBytes = 256 * 1024;

  /*
   * 跳转响应正文允许丢弃的最大字节数。
   */
  static const int _maximumRedirectBodyBytes = 32 * 1024;

  /*
   * 自动跟随跳转时允许的最大次数。
   */
  static const int _maximumRedirectCount = 3;

  /*
   * 可继续跟随的 HTTP 跳转状态码。
   */
  static const Set<int> _redirectStatusCodes = <int>{301, 302, 303, 307, 308};

  /*
   * 实际加载网页正文的方法。
   */
  final WebLinkPageLoader _pageLoader;

  /*
   * 访问网址并按站点名称、应用名称、页面标题的顺序读取链接显示文字。
   */
  Future<String?> loadSiteName(String url) async {
    if (url.trim() != url || url.contains(RegExp(r'\s'))) {
      return null;
    }

    final Uri? uri = Uri.tryParse(url);
    if (!_canLoadUri(uri)) {
      return null;
    }

    try {
      final String? pageSource = await _pageLoader(uri!);
      if (pageSource == null) {
        return null;
      }

      return _findSiteName(html_parser.parse(pageSource));
    } catch (_) {
      // 网页访问、字符解码或 HTML 解析异常时保留原始 URL。
      return null;
    }
  }

  /*
   * 判断网址是否允许由自动元数据请求访问。
   */
  static bool _canLoadUri(Uri? uri) {
    if (uri == null ||
        !uri.hasAuthority ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        (uri.scheme != 'http' && uri.scheme != 'https')) {
      return false;
    }

    return !_isBlockedHost(uri.host);
  }

  /*
   * 判断主机名是否明显指向本机或私有网络，避免粘贴链接时自动访问本地服务。
   */
  static bool _isBlockedHost(String host) {
    final String normalizedHost = host.toLowerCase().replaceFirst(
      RegExp(r'\.$'),
      '',
    );
    if (normalizedHost == 'localhost' ||
        normalizedHost.endsWith('.localhost')) {
      return true;
    }

    final InternetAddress? address = InternetAddress.tryParse(normalizedHost);
    if (address == null) {
      return false;
    }

    final List<int> bytes = address.rawAddress;
    if (address.type == InternetAddressType.IPv4) {
      return _isBlockedIpv4(bytes);
    }

    if (bytes.every((int byte) => byte == 0) ||
        (bytes.take(15).every((int byte) => byte == 0) && bytes.last == 1) ||
        (bytes[0] & 0xFE) == 0xFC ||
        (bytes[0] == 0xFE && (bytes[1] & 0xC0) == 0x80) ||
        bytes[0] == 0xFF) {
      return true;
    }

    final bool isIpv4Mapped =
        bytes.take(10).every((int byte) => byte == 0) &&
        bytes[10] == 0xFF &&
        bytes[11] == 0xFF;
    return isIpv4Mapped && _isBlockedIpv4(bytes.sublist(12));
  }

  /*
   * 判断 IPv4 地址是否属于本机、私有、链路本地或共享地址范围。
   */
  static bool _isBlockedIpv4(List<int> bytes) {
    return bytes[0] == 0 ||
        bytes[0] == 10 ||
        bytes[0] == 127 ||
        (bytes[0] == 100 && bytes[1] >= 64 && bytes[1] <= 127) ||
        (bytes[0] == 169 && bytes[1] == 254) ||
        (bytes[0] == 172 && bytes[1] >= 16 && bytes[1] <= 31) ||
        (bytes[0] == 192 && bytes[1] == 168) ||
        (bytes[0] == 198 && bytes[1] >= 18 && bytes[1] <= 19) ||
        bytes[0] >= 224;
  }

  /*
   * 解析域名并确认所有地址都不属于本机或私有网络。
   */
  static Future<bool> _resolvesOnlyToPublicAddresses(String host) async {
    try {
      final List<InternetAddress> addresses = await InternetAddress.lookup(
        host,
      ).timeout(_connectionTimeout);
      return addresses.isNotEmpty &&
          addresses.every(
            (InternetAddress address) => !_isBlockedHost(address.address),
          );
    } catch (_) {
      return false;
    }
  }

  /*
   * 从 HTML 文档中查找第一个有效的站点名称。
   */
  static String? _findSiteName(Document document) {
    final List<String?> candidates = <String?>[
      _readMetaContent(
        document,
        attributeName: 'property',
        attributeValue: 'og:site_name',
      ),
      _readMetaContent(
        document,
        attributeName: 'name',
        attributeValue: 'application-name',
      ),
      document.querySelector('title')?.text,
    ];

    for (final String? candidate in candidates) {
      final String? normalizedName = _normalizeSiteName(candidate);
      if (normalizedName != null) {
        return normalizedName;
      }
    }

    return null;
  }

  /*
   * 忽略属性值大小写读取指定 meta 标签的 content 内容。
   */
  static String? _readMetaContent(
    Document document, {
    required String attributeName,
    required String attributeValue,
  }) {
    for (final Element element in document.getElementsByTagName('meta')) {
      if ((element.attributes[attributeName] ?? '').trim().toLowerCase() ==
          attributeValue) {
        return element.attributes['content'];
      }
    }

    return null;
  }

  /*
   * 合并站点名称中的连续空白，并过滤空内容和异常长标题。
   */
  static String? _normalizeSiteName(String? siteName) {
    final String normalizedName = (siteName ?? '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (normalizedName.isEmpty || normalizedName.runes.length > 100) {
      return null;
    }

    return normalizedName;
  }

  /*
   * 使用系统 HTTP 客户端加载网页源码，并限制超时、跳转次数与响应大小。
   */
  static Future<String?> _loadWebPage(Uri uri) async {
    final HttpClient client = HttpClient()
      ..connectionTimeout = _connectionTimeout
      ..autoUncompress = true;

    try {
      return await _loadWebPageWithClient(
        client,
        uri,
      ).timeout(_totalLoadTimeout);
    } catch (_) {
      // 连接失败、超时或响应异常时由调用方继续显示原始 URL。
    } finally {
      client.close(force: true);
    }

    return null;
  }

  /*
   * 使用同一个 HTTP 客户端执行域名校验、有限跳转和网页正文读取。
   */
  static Future<String?> _loadWebPageWithClient(
    HttpClient client,
    Uri uri,
  ) async {
    Uri currentUri = uri;
    for (
      int redirectCount = 0;
      redirectCount <= _maximumRedirectCount;
      redirectCount += 1
    ) {
      if (!_canLoadUri(currentUri) ||
          !await _resolvesOnlyToPublicAddresses(currentUri.host)) {
        return null;
      }

      final HttpClientRequest request = await client
          .getUrl(currentUri)
          .timeout(_requestTimeout);
      request
        ..followRedirects = false
        ..headers.set(HttpHeaders.userAgentHeader, 'myNote/1.0 link-metadata')
        ..headers.set(
          HttpHeaders.acceptHeader,
          'text/html,application/xhtml+xml',
        );
      final HttpClientResponse response = await request.close().timeout(
        _requestTimeout,
      );

      if (_redirectStatusCodes.contains(response.statusCode)) {
        final String? location = response.headers.value(
          HttpHeaders.locationHeader,
        );
        if (!await _discardRedirectResponse(response) ||
            location == null ||
            redirectCount == _maximumRedirectCount) {
          return null;
        }

        currentUri = currentUri.resolve(location);
        continue;
      }

      return _readHtmlResponse(response);
    }

    return null;
  }

  /*
   * 在固定大小内丢弃跳转响应正文，超限时立即停止后续访问。
   */
  static Future<bool> _discardRedirectResponse(
    HttpClientResponse response,
  ) async {
    int byteCount = 0;
    await for (final List<int> chunk in response.timeout(_requestTimeout)) {
      byteCount += chunk.length;
      if (byteCount > _maximumRedirectBodyBytes) {
        return false;
      }
    }

    return true;
  }

  /*
   * 校验网页响应类型和字符集，并在大小限制内解码 HTML。
   */
  static Future<String?> _readHtmlResponse(HttpClientResponse response) async {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      return null;
    }

    final ContentType? contentType = response.headers.contentType;
    final String mimeType = contentType?.mimeType.toLowerCase() ?? '';
    if (mimeType.isNotEmpty &&
        mimeType != 'text/html' &&
        mimeType != 'application/xhtml+xml') {
      return null;
    }

    final String charset = contentType?.charset?.toLowerCase() ?? 'utf-8';
    if (charset != 'utf-8' &&
        charset != 'utf8' &&
        charset != 'us-ascii' &&
        charset != 'ascii') {
      return null;
    }

    if (response.contentLength > _maximumBodyBytes) {
      return null;
    }

    final BytesBuilder bodyBytes = BytesBuilder(copy: false);
    await for (final List<int> chunk in response.timeout(_requestTimeout)) {
      if (bodyBytes.length + chunk.length > _maximumBodyBytes) {
        return null;
      }
      bodyBytes.add(chunk);
    }

    return utf8.decode(bodyBytes.takeBytes());
  }
}
