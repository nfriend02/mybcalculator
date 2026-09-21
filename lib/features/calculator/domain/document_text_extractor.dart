import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

/// Extracts plain text from common office / text uploads for Gemini calc.
class DocumentTextExtractor {
  static const maxChars = 12000;

  static String? tryExtract({
    required Uint8List bytes,
    required String fileName,
    String? extension,
  }) {
    final ext = (extension ?? _extOf(fileName)).toLowerCase();
    try {
      return switch (ext) {
        'txt' || 'md' || 'csv' || 'json' || 'log' || 'tsv' =>
          _plain(bytes),
        'docx' => _fromDocx(bytes),
        'pptx' => _fromPptx(bytes),
        'doc' || 'ppt' || 'xls' || 'xlsx' =>
          // Legacy binary / xlsx — best-effort UTF-8 scrape.
          _plain(bytes, allowBinaryScrape: true),
        _ => null,
      };
    } catch (e) {
      return null;
    }
  }

  static String _extOf(String name) {
    final i = name.lastIndexOf('.');
    if (i < 0) return '';
    return name.substring(i + 1);
  }

  static String? _plain(Uint8List bytes, {bool allowBinaryScrape = false}) {
    final text = utf8.decode(bytes, allowMalformed: true).trim();
    if (text.isNotEmpty && !_looksMostlyBinary(text)) {
      return _clip(text);
    }
    if (!allowBinaryScrape) return null;
    final scraped = String.fromCharCodes(
      bytes.where((b) => b == 9 || b == 10 || b == 13 || (b >= 32 && b < 127)),
    ).replaceAll(RegExp(r'\s+'), ' ').trim();
    if (scraped.length < 8) return null;
    return _clip(scraped);
  }

  static bool _looksMostlyBinary(String text) {
    if (text.isEmpty) return true;
    var bad = 0;
    final sample = text.length > 400 ? text.substring(0, 400) : text;
    for (final c in sample.codeUnits) {
      if (c == 0) bad += 3;
      if (c < 9) bad++;
    }
    return bad > sample.length * 0.08;
  }

  static String? _fromDocx(Uint8List bytes) {
    final archive = ZipDecoder().decodeBytes(bytes, verify: false);
    final file = archive.findFile('word/document.xml');
    if (file == null) return null;
    final xml = utf8.decode(file.content as List<int>, allowMalformed: true);
    return _clip(_xmlToText(xml));
  }

  static String? _fromPptx(Uint8List bytes) {
    final archive = ZipDecoder().decodeBytes(bytes, verify: false);
    final buf = StringBuffer();
    final slides = archive.files
        .where((f) =>
            f.name.startsWith('ppt/slides/slide') && f.name.endsWith('.xml'))
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    for (final slide in slides) {
      final xml = utf8.decode(slide.content as List<int>, allowMalformed: true);
      final t = _xmlToText(xml);
      if (t.isNotEmpty) buf.writeln(t);
    }
    final text = buf.toString().trim();
    if (text.isEmpty) return null;
    return _clip(text);
  }

  static String _xmlToText(String xml) {
    return xml
        .replaceAll(RegExp(r'</w:p>'), '\n')
        .replaceAll(RegExp(r'</a:p>'), '\n')
        .replaceAll(RegExp(r'<[^>]+>'), ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll(RegExp(r'[ \t]+'), ' ')
        .replaceAll(RegExp(r'\n{2,}'), '\n')
        .trim();
  }

  static String _clip(String text) {
    if (text.length <= maxChars) return text;
    return '${text.substring(0, maxChars)}\n…(이하 생략)';
  }
}

/// MIME helpers for Gemini inline / document uploads.
class UploadMime {
  static String guess({required String fileName, String? extension}) {
    final ext = (extension ?? _ext(fileName)).toLowerCase();
    return switch (ext) {
      'png' => 'image/png',
      'jpg' || 'jpeg' => 'image/jpeg',
      'webp' => 'image/webp',
      'gif' => 'image/gif',
      'heic' => 'image/heic',
      'heif' => 'image/heif',
      'bmp' => 'image/bmp',
      'pdf' => 'application/pdf',
      'txt' => 'text/plain',
      'md' => 'text/markdown',
      'csv' => 'text/csv',
      'json' => 'application/json',
      'docx' =>
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      'pptx' =>
        'application/vnd.openxmlformats-officedocument.presentationml.presentation',
      'doc' => 'application/msword',
      'ppt' => 'application/vnd.ms-powerpoint',
      _ => 'application/octet-stream',
    };
  }

  static bool isVisionNative(String mime) =>
      mime.startsWith('image/') || mime == 'application/pdf';

  static String _ext(String name) {
    final i = name.lastIndexOf('.');
    if (i < 0) return '';
    return name.substring(i + 1);
  }
}
