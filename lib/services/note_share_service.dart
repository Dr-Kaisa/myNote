/*
 * 文件说明：笔记分享服务文件，负责生成文本、笔记包、图片和 PDF 分享内容并调用系统分享面板。
 *
 * 文本分享直接发送当前 Markdown；文件分享将整个笔记包压缩为 ZIP；
 * 图片将编辑页真实排版的分页截图拼为一张长图；PDF 则逐页写入白色纸张。
 */
import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:archive/archive_io.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as image_lib;
import 'package:my_note/models/note_item.dart';
import 'package:my_note/services/note_storage_service.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

/*
 * 编辑器分页截图回调类型。
 *
 * 长图会收集压缩后的分页数据交给 Isolate 拼接，PDF 则逐页直接写入文档。
 */
typedef NoteSharePageCapture =
    Future<void> Function(
      Future<void> Function(Uint8List pageBytes, double visibleFraction) onPage,
    );

/*
 * 单页分享截图数据。
 */
typedef _CapturedSharePage = ({Uint8List bytes, double visibleFraction});

/*
 * 在独立 Isolate 中把分页截图无缝拼接为单张长图。
 *
 * 极长正文会按比例缩小，控制最终图片高度与像素总量，避免内存占用失控。
 */
Uint8List _buildLongShareImage(List<_CapturedSharePage> pages) {
  if (pages.isEmpty) {
    throw Exception('没有可分享的图片内容');
  }

  final image_lib.Image? firstPageImage = image_lib.decodePng(
    pages.first.bytes,
  );
  if (firstPageImage == null) {
    throw Exception('分享图片解码失败');
  }

  final int sourceWidth = firstPageImage.width;
  final int sourceHeight = firstPageImage.height;
  final List<int> visibleSourceHeights = pages
      .map(
        (_CapturedSharePage page) => (sourceHeight * page.visibleFraction)
            .round()
            .clamp(1, sourceHeight)
            .toInt(),
      )
      .toList(growable: false);
  final int lastPageIndex = pages.length - 1;
  final image_lib.Image? lastPageImage = lastPageIndex == 0
      ? firstPageImage
      : image_lib.decodePng(pages.last.bytes);
  if (lastPageImage == null ||
      lastPageImage.width != sourceWidth ||
      lastPageImage.height != sourceHeight) {
    throw Exception('分享分页图片尺寸不一致');
  }

  final backgroundColor = firstPageImage.getPixel(0, 0);
  int lastContentBottom = 1;
  findLastContentRow:
  for (int row = visibleSourceHeights[lastPageIndex] - 1; row >= 0; row--) {
    for (int column = 0; column < sourceWidth; column++) {
      final pixel = lastPageImage.getPixel(column, row);
      if ((pixel.r - backgroundColor.r).abs() > 2 ||
          (pixel.g - backgroundColor.g).abs() > 2 ||
          (pixel.b - backgroundColor.b).abs() > 2 ||
          (pixel.a - backgroundColor.a).abs() > 2) {
        lastContentBottom = row + 1;
        break findLastContentRow;
      }
    }
  }
  visibleSourceHeights[lastPageIndex] = math.min(
    visibleSourceHeights[lastPageIndex],
    lastContentBottom,
  );
  final int totalSourceHeight = visibleSourceHeights.fold<int>(
    0,
    (int total, int height) => total + height,
  );
  const int maximumContentHeight = 29000;
  const int maximumPixelCount = 30000000;
  double outputScale = 1;
  if (totalSourceHeight > maximumContentHeight) {
    outputScale = maximumContentHeight / totalSourceHeight;
  }
  final double pixelLimitedScale = math.sqrt(
    maximumPixelCount / (sourceWidth * totalSourceHeight),
  );
  if (pixelLimitedScale < outputScale) {
    outputScale = pixelLimitedScale;
  }

  final int outputWidth = math.max(1, (sourceWidth * outputScale).round());
  final List<int> visibleOutputHeights = visibleSourceHeights
      .map(
        (int height) =>
            math.max(1, (height * outputWidth / sourceWidth).round()),
      )
      .toList(growable: false);
  final int verticalPadding = math.max(8, (outputWidth * 0.055).round());
  final int outputHeight =
      visibleOutputHeights.fold<int>(
        0,
        (int total, int height) => total + height,
      ) +
      verticalPadding * 2;
  final image_lib.Image longImage = image_lib.Image(
    width: outputWidth,
    height: outputHeight,
    numChannels: 4,
  );
  image_lib.fill(longImage, color: backgroundColor);

  int outputTop = verticalPadding;
  for (int pageIndex = 0; pageIndex < pages.length; pageIndex++) {
    final image_lib.Image? pageImage = pageIndex == 0
        ? firstPageImage
        : pageIndex == lastPageIndex
        ? lastPageImage
        : image_lib.decodePng(pages[pageIndex].bytes);
    if (pageImage == null ||
        pageImage.width != sourceWidth ||
        pageImage.height != sourceHeight) {
      throw Exception('分享分页图片尺寸不一致');
    }

    image_lib.compositeImage(
      longImage,
      pageImage,
      dstY: outputTop,
      dstW: outputWidth,
      dstH: visibleOutputHeights[pageIndex],
      srcW: sourceWidth,
      srcH: visibleSourceHeights[pageIndex],
      blend: image_lib.BlendMode.direct,
    );
    outputTop += visibleOutputHeights[pageIndex];
  }

  return image_lib.encodePng(longImage, level: 6);
}

/*
 * 笔记分享服务。
 */
class NoteShareService {
  /*
   * 构造笔记分享服务。
   */
  NoteShareService({NoteStorageService? noteStorageService})
    : _noteStorageService = noteStorageService ?? NoteStorageService();

  /*
   * 笔记存储服务实例。
   */
  final NoteStorageService _noteStorageService;

  /*
   * 以系统纯文本形式分享当前 Markdown。
   */
  Future<void> shareMarkdownText(
    NoteItem note,
    Rect? sharePositionOrigin,
  ) async {
    await SharePlus.instance.share(
      ShareParams(
        text: note.content.isEmpty ? ' ' : note.content,
        title: '分享 ${note.fileName}',
        subject: note.fileName,
        sharePositionOrigin: sharePositionOrigin,
      ),
    );
  }

  /*
   * 将整个笔记包压缩为 ZIP 后交给系统分享面板。
   */
  Future<void> sharePackageFiles(
    NoteItem note,
    Rect? sharePositionOrigin,
  ) async {
    final Directory packageDirectory = await _noteStorageService
        .getDirectoryByRelativePath(note.packageRelativePath);
    final Directory exportDirectory = await _createExportDirectory();
    final File zipFile = File(
      path.join(
        exportDirectory.path,
        '${_sanitizeFileName(note.packageName)}.zip',
      ),
    );
    final String packageDirectoryPath = packageDirectory.path;
    final String zipFilePath = zipFile.path;
    await Isolate.run(() {
      final ZipFileEncoder encoder = ZipFileEncoder();
      encoder.create(zipFilePath);
      try {
        encoder.addDirectorySync(
          Directory(packageDirectoryPath),
          includeDirName: true,
          followLinks: false,
        );
      } finally {
        encoder.closeSync();
      }
    });

    await SharePlus.instance.share(
      ShareParams(
        files: <XFile>[XFile(zipFile.path, mimeType: 'application/zip')],
        title: '分享 ${note.packageName}',
        subject: note.packageName,
        sharePositionOrigin: sharePositionOrigin,
      ),
    );
  }

  /*
   * 将编辑器真实渲染的分页截图拼成一张长图后交给系统分享面板。
   */
  Future<void> shareAsImages(
    NoteItem note,
    NoteSharePageCapture capturePages,
    Rect? sharePositionOrigin,
  ) async {
    final Directory exportDirectory = await _createExportDirectory();
    final String baseName = _sanitizeFileName(
      path.basenameWithoutExtension(note.fileName),
    );
    final List<_CapturedSharePage> capturedPages = <_CapturedSharePage>[];

    await capturePages((Uint8List pageBytes, double visibleFraction) async {
      capturedPages.add((bytes: pageBytes, visibleFraction: visibleFraction));
    });
    final File imageFile = File(
      path.join(exportDirectory.path, '$baseName.png'),
    );
    await imageFile.writeAsBytes(
      await Isolate.run(() => _buildLongShareImage(capturedPages)),
      flush: true,
    );

    await SharePlus.instance.share(
      ShareParams(
        files: <XFile>[XFile(imageFile.path, mimeType: 'image/png')],
        title: '以图片分享 ${note.fileName}',
        subject: note.fileName,
        sharePositionOrigin: sharePositionOrigin,
      ),
    );
  }

  /*
   * 将编辑器真实渲染的分页图片合成为 PDF 后交给系统分享面板。
   */
  Future<void> shareAsPdf(
    NoteItem note,
    NoteSharePageCapture capturePages,
    Rect? sharePositionOrigin,
  ) async {
    final pw.Document document = pw.Document();
    int pageCount = 0;

    await capturePages((Uint8List pageBytes, double _) async {
      pageCount += 1;
      final pw.MemoryImage pageImage = pw.MemoryImage(pageBytes);
      document.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: pw.EdgeInsets.zero,
          build: (pw.Context context) {
            return pw.Container(
              // PDF 页面留白与图片等比居中样式
              padding: const pw.EdgeInsets.all(24),
              alignment: pw.Alignment.center,
              child: pw.Image(pageImage, fit: pw.BoxFit.contain),
            );
          },
        ),
      );
    });

    if (pageCount == 0) {
      throw Exception('没有可分享的 PDF 内容');
    }

    final Directory exportDirectory = await _createExportDirectory();
    final File pdfFile = File(
      path.join(
        exportDirectory.path,
        '${_sanitizeFileName(path.basenameWithoutExtension(note.fileName))}.pdf',
      ),
    );
    await pdfFile.writeAsBytes(
      await document.save(enableEventLoopBalancing: true),
      flush: true,
    );

    await SharePlus.instance.share(
      ShareParams(
        files: <XFile>[XFile(pdfFile.path, mimeType: 'application/pdf')],
        title: '以 PDF 分享 ${note.fileName}',
        subject: note.fileName,
        sharePositionOrigin: sharePositionOrigin,
      ),
    );
  }

  /*
   * 在系统临时目录内创建本次分享使用的独立目录。
   */
  Future<Directory> _createExportDirectory() async {
    final Directory exportRootDirectory = Directory(
      path.join((await getTemporaryDirectory()).path, 'my_note_share'),
    );
    await exportRootDirectory.create(recursive: true);
    await _deleteExpiredExportDirectories(exportRootDirectory);
    final Directory exportDirectory = Directory(
      path.join(
        exportRootDirectory.path,
        DateTime.now().microsecondsSinceEpoch.toString(),
      ),
    );
    await exportDirectory.create(recursive: true);
    return exportDirectory;
  }

  /*
   * 删除一天前生成的分享缓存，避免 ZIP、PNG 和 PDF 长期累积。
   */
  Future<void> _deleteExpiredExportDirectories(
    Directory exportRootDirectory,
  ) async {
    final DateTime expirationTime = DateTime.now().subtract(
      const Duration(days: 1),
    );

    await for (final FileSystemEntity entity in exportRootDirectory.list(
      followLinks: false,
    )) {
      try {
        if ((await entity.stat()).modified.isBefore(expirationTime)) {
          await entity.delete(recursive: true);
        }
      } catch (_) {
        // 单个缓存无法读取或删除时继续分享，缓存清理不能阻断用户操作。
      }
    }
  }

  /*
   * 清理文件名中不适用于常见文件系统的字符。
   */
  String _sanitizeFileName(String value) {
    final String sanitizedValue = value
        .replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]'), '_')
        .trim();
    return sanitizedValue.isEmpty ? '笔记' : sanitizedValue;
  }
}
