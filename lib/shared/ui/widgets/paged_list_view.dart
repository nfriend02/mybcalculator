import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../config/breakpoints.dart';
import '../../../app/theme/app_theme.dart';

/// Page-unit navigation: 10 items per page with clickable page controls.
class PagedListView<T> extends StatefulWidget {
  const PagedListView({
    super.key,
    required this.items,
    required this.itemBuilder,
    this.pageSize = PaginationRules.pageSize,
    this.emptyMessage = '아직 항목이 없어요',
    this.shrinkWrap = false,
  });

  final List<T> items;
  final Widget Function(BuildContext context, T item, int index) itemBuilder;
  final int pageSize;
  final String emptyMessage;

  /// When true, sizes to children (for nesting inside a parent scroll view).
  final bool shrinkWrap;

  @override
  State<PagedListView<T>> createState() => _PagedListViewState<T>();
}

class _PagedListViewState<T> extends State<PagedListView<T>> {
  int _page = 0;

  int get _pageCount {
    if (widget.items.isEmpty) return 1;
    return (widget.items.length / widget.pageSize).ceil();
  }

  List<T> get _pageItems {
    final start = _page * widget.pageSize;
    final end = (start + widget.pageSize).clamp(0, widget.items.length);
    if (start >= widget.items.length) return const [];
    return widget.items.sublist(start, end);
  }

  @override
  void didUpdateWidget(covariant PagedListView<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.items.length != oldWidget.items.length) {
      _page = 0;
    } else if (_page >= _pageCount) {
      _page = _pageCount - 1;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 28),
        child: Center(
          child: Text(
            widget.emptyMessage,
            style: GoogleFonts.nunito(color: AppTheme.ink.withValues(alpha: 0.5)),
          ),
        ),
      );
    }

    final list = ListView.separated(
      shrinkWrap: widget.shrinkWrap,
      physics: widget.shrinkWrap
          ? const NeverScrollableScrollPhysics()
          : null,
      itemCount: _pageItems.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final globalIndex = _page * widget.pageSize + i;
        return widget.itemBuilder(context, _pageItems[i], globalIndex);
      },
    );

    final controls = _PageControls(
      page: _page,
      pageCount: _pageCount,
      onChanged: (p) => setState(() => _page = p),
    );

    if (widget.shrinkWrap) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          list,
          const SizedBox(height: 12),
          controls,
        ],
      );
    }

    return Column(
      children: [
        Expanded(child: list),
        const SizedBox(height: 12),
        controls,
      ],
    );
  }
}

class _PageControls extends StatelessWidget {
  const _PageControls({
    required this.page,
    required this.pageCount,
    required this.onChanged,
  });

  final int page;
  final int pageCount;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        IconButton(
          onPressed: page > 0 ? () => onChanged(page - 1) : null,
          icon: const Icon(Icons.chevron_left_rounded),
          tooltip: '이전 페이지',
        ),
        for (var i = 0; i < pageCount; i++)
          InkWell(
            onTap: () => onChanged(i),
            borderRadius: BorderRadius.circular(10),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: i == page
                    ? AppTheme.coral
                    : AppTheme.lavender.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${i + 1}',
                style: GoogleFonts.nunito(
                  fontWeight: FontWeight.w800,
                  color: i == page ? Colors.white : AppTheme.ink,
                ),
              ),
            ),
          ),
        IconButton(
          onPressed:
              page < pageCount - 1 ? () => onChanged(page + 1) : null,
          icon: const Icon(Icons.chevron_right_rounded),
          tooltip: '다음 페이지',
        ),
      ],
    );
  }
}
