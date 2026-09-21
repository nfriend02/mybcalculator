import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../app/theme/app_theme.dart';
import '../../features/schedule/model/schedule_controller.dart';
import '../../shared/ui/widgets/paged_list_view.dart';

class SchedulePage extends StatefulWidget {
  const SchedulePage({super.key});

  @override
  State<SchedulePage> createState() => _SchedulePageState();
}

class _SchedulePageState extends State<SchedulePage> {
  final _title = TextEditingController();

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ScheduleController>();
    final fmt = DateFormat('yyyy-MM-dd HH:mm');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('일정 관리', style: GoogleFonts.fredoka(fontSize: 28)),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _title,
                decoration: InputDecoration(
                  hintText: '새 일정 제목',
                  filled: true,
                  fillColor: AppTheme.mint.withValues(alpha: 0.4),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: () async {
                if (_title.text.trim().isEmpty) return;
                await controller.add(
                  _title.text.trim(),
                  DateTime.now().add(const Duration(hours: 1)),
                );
                _title.clear();
              },
              child: const Text('추가'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Expanded(
          child: PagedListView(
            items: controller.items,
            emptyMessage: '일정이 비어 있어요',
            itemBuilder: (context, item, index) {
              return ListTile(
                tileColor: Colors.white.withValues(alpha: 0.8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                leading: CircleAvatar(
                  backgroundColor: AppTheme.lavender,
                  child: Text('${index + 1}'),
                ),
                title: Text(item.title),
                subtitle: Text(fmt.format(item.when)),
              );
            },
          ),
        ),
      ],
    );
  }
}
