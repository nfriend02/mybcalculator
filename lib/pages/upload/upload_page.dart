import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../app/theme/app_theme.dart';
import '../../shared/config/app_config.dart';
import '../../shared/services/firestore_service.dart';
import '../../shared/services/storage_service.dart';
import '../../shared/ui/widgets/paged_list_view.dart';

/// Upload example page — portfolio checklist + Firebase Storage/Firestore.
///
/// Class name `UploadPage` matches the requested UploadPage example.
class UploadPage extends StatefulWidget {
  const UploadPage({super.key, required this.firebaseReady});

  final bool firebaseReady;

  @override
  State<UploadPage> createState() => _UploadPageState();
}

class _UploadPageState extends State<UploadPage> {
  final _uploads = <_UploadRow>[];
  bool _busy = false;
  String? _status;

  Future<void> _pickAndUpload() async {
    if (!widget.firebaseReady) {
      setState(() {
        _status = 'Firebase가 설정되지 않아 데모 업로드만 기록합니다.';
      });
    }

    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['png', 'jpg', 'jpeg', 'webp', 'pdf', 'txt'],
    );
    if (files.isEmpty) return;

    final file = files.first;
    final bytes = await file.readAsBytes();

    setState(() {
      _busy = true;
      _status = '업로드 중…';
    });

    try {
      String url;
      var docId = DateTime.now().millisecondsSinceEpoch.toString();
      final ext = file.name.contains('.')
          ? file.name.split('.').last
          : null;

      if (widget.firebaseReady) {
        final storage = StorageService();
        url = await storage.uploadBytes(
          folder: 'uploads',
          fileName: file.name,
          bytes: bytes,
          contentType: _contentType(ext),
        );

        final fs = FirestoreService();
        final ref = await fs.create(
          collectionPath: 'uploads',
          data: {
            'fileName': file.name,
            'url': url,
            'size': bytes.length,
            'meta': AppConfig.uploadChecklistMeta(),
          },
        );
        docId = ref.id;
      } else {
        url = 'demo://local/${file.name}';
      }

      setState(() {
        _uploads.insert(
          0,
          _UploadRow(
            id: docId,
            name: file.name,
            url: url,
            size: bytes.length,
          ),
        );
        _status = '업로드 완료: ${file.name}';
      });
    } catch (e) {
      setState(() => _status = '업로드 실패: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _contentType(String? ext) {
    return switch (ext?.toLowerCase()) {
      'png' => 'image/png',
      'jpg' || 'jpeg' => 'image/jpeg',
      'webp' => 'image/webp',
      'pdf' => 'application/pdf',
      'txt' => 'text/plain',
      _ => 'application/octet-stream',
    };
  }

  @override
  Widget build(BuildContext context) {
    final meta = AppConfig.uploadChecklistMeta();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '업로드 · 포트폴리오 체크리스트',
          style: GoogleFonts.fredoka(fontSize: 26),
        ),
        const SizedBox(height: 12),
        _ChecklistCard(meta: meta, firebaseReady: widget.firebaseReady),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _busy ? null : _pickAndUpload,
          icon: const Icon(Icons.cloud_upload_rounded),
          label: Text(_busy ? '업로드 중…' : '파일 선택 후 업로드'),
        ),
        if (_status != null) ...[
          const SizedBox(height: 8),
          Text(
            _status!,
            style: GoogleFonts.nunito(
              color: AppTheme.ink.withValues(alpha: 0.6),
            ),
          ),
        ],
        const SizedBox(height: 16),
        Text(
          '업로드 목록 (페이지당 10개)',
          style: GoogleFonts.fredoka(fontSize: 18),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: PagedListView<_UploadRow>(
            items: _uploads,
            emptyMessage: '아직 업로드한 파일이 없어요',
            itemBuilder: (context, item, index) {
              return ListTile(
                tileColor: Colors.white.withValues(alpha: 0.85),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                leading: CircleAvatar(
                  backgroundColor: AppTheme.sky,
                  child: Text('${index + 1}'),
                ),
                title: Text(item.name),
                subtitle: Text(
                  '${item.size} bytes\n${item.url}',
                  maxLines: 2,
                ),
                isThreeLine: true,
              );
            },
          ),
        ),
      ],
    );
  }
}

class _UploadRow {
  const _UploadRow({
    required this.id,
    required this.name,
    required this.url,
    required this.size,
  });

  final String id;
  final String name;
  final String url;
  final int size;
}

class _ChecklistCard extends StatelessWidget {
  const _ChecklistCard({
    required this.meta,
    required this.firebaseReady,
  });

  final Map<String, String> meta;
  final bool firebaseReady;

  @override
  Widget build(BuildContext context) {
    final checks = <(String, bool)>[
      ('Github branch URL', (meta['githubBranchUrl'] ?? '').isNotEmpty),
      ('아이콘 이미지 공개', (meta['iconUrl'] ?? '').isNotEmpty),
      ('설명 200자 이내', (meta['description'] ?? '').length <= 200),
      ('제작자 이름/팀명', (meta['author'] ?? '').isNotEmpty),
      ('Firebase 연결', firebaseReady),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.lavender.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            meta['title'] ?? 'App',
            style: GoogleFonts.fredoka(fontSize: 20),
          ),
          const SizedBox(height: 4),
          Text(
            meta['description'] ?? '',
            style: GoogleFonts.nunito(fontSize: 13),
          ),
          const SizedBox(height: 12),
          for (final c in checks)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  Icon(
                    c.$2 ? Icons.check_circle : Icons.radio_button_unchecked,
                    size: 18,
                    color: c.$2
                        ? Colors.green
                        : AppTheme.ink.withValues(alpha: 0.35),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Text(c.$1, style: GoogleFonts.nunito())),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
