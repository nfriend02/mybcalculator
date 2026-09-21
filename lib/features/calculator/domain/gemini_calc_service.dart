import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../../shared/config/app_config.dart';
import 'document_text_extractor.dart';

/// Result of an AI / NLP calculation or structured extraction.
class GeminiCalcResult {
  const GeminiCalcResult({
    required this.result,
    required this.expression,
    this.steps = const [],
    this.explanation = '',
    this.source = 'gemini',
    this.extractedText,
  });

  final String result;
  final String expression;
  final List<String> steps;
  final String explanation;
  final String source;
  final String? extractedText;

  String get summary {
    if (steps.isNotEmpty) return steps.join(' → ');
    if (explanation.isNotEmpty) return explanation;
    return expression;
  }
}

/// Attachment sent to Gemini (Vision / PDF / extracted office text).
class GeminiAttachment {
  const GeminiAttachment({
    required this.bytes,
    required this.mimeType,
    required this.fileName,
  });

  final Uint8List bytes;
  final String mimeType;
  final String fileName;
}

/// Calls Gemini for arithmetic calc or structured NL extraction.
class GeminiCalcService {
  GeminiCalcService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const maxInlineBytes = 8 * 1024 * 1024; // 8MB safety cap

  static const _systemPrompt = '''
당신은 한국어 일상 문장·음성 전사·문서·영수증·표 이미지를 정확한 산수로 풀어주는 계산 도우미입니다.
반드시 아래 JSON만 출력하세요. 마크다운/설명 금지.

{
  "expression": "검증 가능한 산술식 (예: 12000*3 + 4500*3)",
  "steps": ["단계1", "단계2"],
  "result": "최종 숫자만 (콤마 없이)",
  "explanation": "한 줄 한국어 요약",
  "extractedText": "파일/이미지에서 읽은 핵심 숫자·문장 요약(없으면 빈 문자열)"
}

규칙:
- 만이천원=12000, 만오천원=15000처럼 한글 금액을 숫자로 변환
- 한/하나/일=1, 두/둘/이=2, 세/셋/삼=3, 네/넷/사=4, 다섯/오=5
- 명/그릇/잔/개 등은 수량을 의미
- 이미지·PDF·표에서 금액/수량을 읽어 합계·평균·차이를 계산
- 나누기/더하기/빼기/곱하기/팁/퍼센트/환율도 반영
- result는 숫자 문자열만 (예: "49500")
''';

  static const _structuredSystemPrompt = '''
당신은 한국어 일상 문장·음성·문서에서 구조화된 정보를 추출하는 도우미입니다.
반드시 아래 JSON만 출력하세요. 마크다운/설명 금지.

{
  "expression": "짧은 요약 또는 원문 핵심",
  "steps": [],
  "result": "요청된 형식의 문자열 (숫자가 아닐 수 있음)",
  "explanation": "한 줄 한국어 요약",
  "extractedText": "파일에서 읽은 핵심 (없으면 빈 문자열)"
}

사용자 프롬프트의 출력 형식을 정확히 따르세요.
''';

  Future<GeminiCalcResult?> calculate(
    String utterance, {
    bool requireNumericResult = true,
  }) async {
    final text = utterance.trim();
    if (text.isEmpty) return null;
    return _dispatch(
      prompt: text,
      requireNumericResult: requireNumericResult,
    );
  }

  /// Image / PDF via Gemini Vision; Office docs via text extract then Gemini.
  Future<GeminiCalcResult?> calculateFromFile({
    required Uint8List bytes,
    required String fileName,
    String? extension,
    String? userHint,
    bool requireNumericResult = true,
  }) async {
    if (bytes.isEmpty) return null;
    if (bytes.length > maxInlineBytes) {
      throw StateError(
        '파일이 너무 큽니다 (최대 ${maxInlineBytes ~/ (1024 * 1024)}MB).',
      );
    }

    final mime = UploadMime.guess(fileName: fileName, extension: extension);
    final hint = (userHint ?? '').trim();
    final prompt = StringBuffer()
      ..writeln('첨부 파일 "$fileName"을(를) 읽고 계산해 주세요.')
      ..writeln('파일에 나온 금액·수량·식을 모두 반영하세요.');
    if (hint.isNotEmpty) {
      prompt.writeln('사용자 추가 요청: $hint');
    }

    if (UploadMime.isVisionNative(mime)) {
      return _dispatch(
        prompt: prompt.toString(),
        attachment: GeminiAttachment(
          bytes: bytes,
          mimeType: mime,
          fileName: fileName,
        ),
        requireNumericResult: requireNumericResult,
      );
    }

    final extracted = DocumentTextExtractor.tryExtract(
      bytes: bytes,
      fileName: fileName,
      extension: extension,
    );
    if (extracted == null || extracted.isEmpty) {
      throw StateError(
        '이 파일에서 텍스트를 읽지 못했어요. PDF·이미지·TXT·DOCX·PPTX를 사용해 주세요.',
      );
    }

    final textPrompt = StringBuffer()
      ..writeln(prompt.toString())
      ..writeln()
      ..writeln('--- 파일에서 추출한 내용 ---')
      ..writeln(extracted);

    final result = await _dispatch(
      prompt: textPrompt.toString(),
      requireNumericResult: requireNumericResult,
    );
    if (result == null) return null;
    return GeminiCalcResult(
      result: result.result,
      expression: result.expression,
      steps: result.steps,
      explanation: result.explanation,
      source: result.source,
      extractedText: extracted,
    );
  }

  Future<GeminiCalcResult?> _dispatch({
    required String prompt,
    GeminiAttachment? attachment,
    bool requireNumericResult = true,
  }) async {
    // Local Flutter web has no Netlify /api — use direct Gemini only.
    if (_isLocalHost) {
      if (!AppConfig.hasGemini) {
        debugPrint(
          'Gemini unavailable on localhost — set GEMINI_API_KEY in .env',
        );
        return null;
      }
      return _viaGeminiDirect(
        prompt,
        attachment: attachment,
        requireNumericResult: requireNumericResult,
      );
    }

    final proxied = await _viaNetlify(
      prompt,
      attachment: attachment,
      requireNumericResult: requireNumericResult,
    );
    if (proxied != null) return proxied;

    if (AppConfig.hasGemini) {
      return _viaGeminiDirect(
        prompt,
        attachment: attachment,
        requireNumericResult: requireNumericResult,
      );
    }
    return null;
  }

  bool get _isLocalHost {
    final host = Uri.base.host;
    return host == 'localhost' ||
        host == '127.0.0.1' ||
        host.isEmpty ||
        host.endsWith('.local');
  }

  Future<GeminiCalcResult?> _viaNetlify(
    String prompt, {
    GeminiAttachment? attachment,
    bool requireNumericResult = true,
  }) async {
    try {
      final uri = Uri.base.replace(path: '${AppConfig.apiPrefix}/calculate');
      final body = <String, dynamic>{
        'prompt': prompt,
        'requireNumericResult': requireNumericResult,
      };
      if (attachment != null) {
        body['file'] = {
          'mimeType': attachment.mimeType,
          'fileName': attachment.fileName,
          'data': base64Encode(attachment.bytes),
        };
      }
      final res = await _client
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 90));
      if (res.statusCode >= 400) {
        debugPrint('calculate proxy ${res.statusCode}: ${res.body}');
        return null;
      }
      final data = jsonDecode(res.body);
      if (data is! Map<String, dynamic>) return null;
      if (data['error'] == true) {
        debugPrint('calculate proxy error: ${data['message']}');
        return null;
      }
      return _fromMap(
        data,
        source: 'api',
        requireNumericResult: requireNumericResult,
      );
    } catch (e) {
      debugPrint('calculate proxy failed: $e');
      return null;
    }
  }

  Future<GeminiCalcResult?> _viaGeminiDirect(
    String prompt, {
    GeminiAttachment? attachment,
    bool requireNumericResult = true,
  }) async {
    final key = AppConfig.geminiApiKey;
    if (key == null) return null;

    final models = <String>{
      AppConfig.geminiModel,
      'gemini-flash-latest',
      'gemini-2.0-flash',
      'gemini-2.5-flash',
    };

    final system =
        requireNumericResult ? _systemPrompt : _structuredSystemPrompt;

    final parts = <Map<String, dynamic>>[
      {'text': '$system\n\n사용자 요청:\n$prompt'},
    ];
    if (attachment != null) {
      parts.add({
        'inline_data': {
          'mime_type': attachment.mimeType,
          'data': base64Encode(attachment.bytes),
        },
      });
    }

    for (final model in models) {
      try {
        final uri = Uri.parse(
          'https://generativelanguage.googleapis.com/v1beta/models/'
          '$model:generateContent?key=$key',
        );
        final res = await _client
            .post(
              uri,
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({
                'contents': [
                  {'role': 'user', 'parts': parts},
                ],
                'generationConfig': {
                  'temperature': 0.1,
                  'responseMimeType': 'application/json',
                },
              }),
            )
            .timeout(const Duration(seconds: 90));

        if (res.statusCode == 404) continue;
        if (res.statusCode >= 400) {
          debugPrint('Gemini $model ${res.statusCode}: ${res.body}');
          continue;
        }

        final body = jsonDecode(res.body) as Map<String, dynamic>;
        final text = _extractText(body);
        if (text == null) continue;
        final parsed = _parseJsonPayload(text);
        if (parsed == null) continue;
        return _fromMap(
          parsed,
          source: attachment != null ? 'gemini-vision' : 'gemini',
          requireNumericResult: requireNumericResult,
        );
      } catch (e) {
        debugPrint('Gemini $model failed: $e');
      }
    }
    return null;
  }

  String? _extractText(Map<String, dynamic> body) {
    final candidates = body['candidates'];
    if (candidates is! List || candidates.isEmpty) return null;
    final content = candidates.first['content'];
    if (content is! Map) return null;
    final parts = content['parts'];
    if (parts is! List || parts.isEmpty) return null;
    final text = parts.first['text'];
    return text is String ? text.trim() : null;
  }

  Map<String, dynamic>? _parseJsonPayload(String raw) {
    var text = raw.trim();
    if (text.startsWith('```')) {
      text = text
          .replaceFirst(RegExp(r'^```(?:json)?\s*', caseSensitive: false), '')
          .replaceFirst(RegExp(r'\s*```$'), '')
          .trim();
    }
    try {
      final decoded = jsonDecode(text);
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {
      final match = RegExp(r'\{[\s\S]*\}').firstMatch(text);
      if (match != null) {
        try {
          final decoded = jsonDecode(match.group(0)!);
          if (decoded is Map<String, dynamic>) return decoded;
        } catch (_) {}
      }
    }
    return null;
  }

  GeminiCalcResult? _fromMap(
    Map<String, dynamic> data, {
    required String source,
    bool requireNumericResult = true,
  }) {
    final result = data['result']?.toString().replaceAll(',', '').trim();
    if (result == null || result.isEmpty) return null;
    if (requireNumericResult && double.tryParse(result) == null) return null;

    final expression = (data['expression']?.toString() ?? result).trim();
    final explanation = data['explanation']?.toString() ?? '';
    final extracted = data['extractedText']?.toString();
    final stepsRaw = data['steps'];
    final steps = <String>[];
    if (stepsRaw is List) {
      for (final s in stepsRaw) {
        final t = s.toString().trim();
        if (t.isNotEmpty) steps.add(t);
      }
    }

    return GeminiCalcResult(
      result: requireNumericResult ? _prettyNumber(result) : result,
      expression: expression,
      steps: steps,
      explanation: explanation,
      source: source,
      extractedText: extracted,
    );
  }

  String _prettyNumber(String raw) {
    final n = double.tryParse(raw);
    if (n == null) return raw;
    if (n == n.roundToDouble()) return n.toInt().toString();
    return n.toStringAsFixed(4).replaceFirst(RegExp(r'\.?0+$'), '');
  }

  void dispose() => _client.close();
}
