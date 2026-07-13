import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/i18n.dart';
import '../../core/settings.dart';
import '../../core/theme.dart';
import 'request_widgets.dart';

/// Node visual state on the vertical timeline.
enum _NodeState { done, current, future, rejected }

class _Node {
  final String title;
  final List<String> lines;
  final _NodeState state;
  _Node(this.title, this.lines, this.state);
}

/// Beautiful step-by-step approval progress for a single leave request.
class LeaveDetailPage extends ConsumerWidget {
  final Map<String, dynamic> request;
  const LeaveDetailPage({super.key, required this.request});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(localeProvider);
    final r = request;
    final status = (r['status'] ?? 'pending').toString();
    final currentStep = (r['currentStep'] ?? 1) as int;
    final steps = ((r['steps'] as List?) ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

    final nodes = _buildNodes(r, steps, status, currentStep, lang);

    return Scaffold(
      appBar: AppBar(title: Text(tr('detail', lang))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, kNavInset),
        children: [
          _summaryCard(context, lang, r, status),
          const SizedBox(height: 22),
          Text(
            tr('approval_progress', lang),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 14),
          for (int i = 0; i < nodes.length; i++)
            _TimelineTile(
              index: i,
              node: nodes[i],
              isLast: i == nodes.length - 1,
            ),
          if (status == 'pending') ...[
            const SizedBox(height: 8),
            _estimateRow(context, lang, r),
          ],
        ],
      ),
    );
  }

  List<_Node> _buildNodes(
    Map<String, dynamic> r,
    List<Map<String, dynamic>> steps,
    String status,
    int currentStep,
    String lang,
  ) {
    final requester = r['requester'] as Map?;
    final nodes = <_Node>[
      // Node 0: the submission itself — always complete.
      _Node(
        tr('request_submitted', lang),
        [
          _fmtDateTime(r['createdAt']),
          '${tr('submitted_by', lang)}: ${requester?['name'] ?? '—'}',
        ],
        _NodeState.done,
      ),
    ];

    for (final s in steps) {
      final sStatus = (s['status'] ?? 'pending').toString();
      final order = (s['stepOrder'] ?? 0) as int;
      final name = (s['approver']?['name'] ?? '—').toString();
      _NodeState state;
      final lines = <String>[];
      if (sStatus == 'approved') {
        state = _NodeState.done;
        lines.add('✓ ${tr('approved_on', lang)} · ${_fmtDateTime(s['decidedAt'])}');
      } else if (sStatus == 'rejected') {
        state = _NodeState.rejected;
        lines.add('✕ ${tr('rejected_on', lang)} · ${_fmtDateTime(s['decidedAt'])}');
      } else if (status == 'pending' && order == currentStep) {
        state = _NodeState.current;
        lines.add(tr('waiting_signature', lang));
      } else {
        state = _NodeState.future;
        lines.add(tr('pending_previous', lang));
      }
      nodes.add(_Node(name, lines, state));
    }
    return nodes;
  }

  Widget _summaryCard(
    BuildContext context,
    String lang,
    Map<String, dynamic> r,
    String status,
  ) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: kBrandGradient,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: kBrand.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.event_busy_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text(
                tr('leave', lang),
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 16),
              ),
              const Spacer(),
              _lightChip(tr('st_$status', lang)),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              const Icon(Icons.date_range_rounded, color: Colors.white70, size: 16),
              const SizedBox(width: 8),
              Text(
                '${prettyDate(r['startDate'])}  →  ${prettyDate(r['endDate'])}',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          if ((r['reason'] ?? '').toString().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              r['reason'].toString(),
              style: const TextStyle(color: Colors.white, height: 1.35),
            ),
          ],
        ],
      ),
    );
  }

  Widget _lightChip(String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.25),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(text,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12)),
      );

  Widget _estimateRow(BuildContext context, String lang, Map<String, dynamic> r) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.schedule_rounded,
              size: 16,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)),
          const SizedBox(width: 8),
          Text(
            '${tr('estimated_completion', lang)}: ',
            style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
          ),
          Text(
            _fmtDate(r['endDate']),
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  static String _fmtDateTime(dynamic iso) {
    if (iso == null) return '';
    final d = DateTime.tryParse(iso.toString());
    return d == null ? iso.toString() : DateFormat('dd/MM/yyyy - HH:mm').format(d);
  }

  static String _fmtDate(dynamic iso) {
    if (iso == null) return '--';
    final d = DateTime.tryParse(iso.toString());
    return d == null ? iso.toString() : DateFormat('dd/MM/yyyy').format(d);
  }
}

// ===================== timeline tile =====================
class _TimelineTile extends StatelessWidget {
  final int index;
  final _Node node;
  final bool isLast;
  const _TimelineTile({
    required this.index,
    required this.node,
    required this.isLast,
  });

  Color get _color {
    switch (node.state) {
      case _NodeState.done:
        return const Color(0xFF16A34A); // green
      case _NodeState.current:
        return const Color(0xFFF39C12); // orange
      case _NodeState.rejected:
        return const Color(0xFFDC2626); // red
      case _NodeState.future:
        return const Color(0xFFB6C0CC); // grey
    }
  }

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    // Connector below this node reflects whether it is complete.
    final belowSolid = node.state == _NodeState.done;
    final belowColor = node.state == _NodeState.done
        ? const Color(0xFF16A34A)
        : node.state == _NodeState.current
            ? const Color(0xFFF39C12)
            : const Color(0xFFB6C0CC);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ---- left rail: node + connector ----
          SizedBox(
            width: 40,
            child: Column(
              children: [
                _node(),
                if (!isLast)
                  Expanded(
                    child: _Connector(color: belowColor, dashed: !belowSolid),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          // ---- right content ----
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 22, top: 2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${index + 1}. ${node.title}',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                  const SizedBox(height: 4),
                  for (final line in node.lines)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        line,
                        style: TextStyle(
                          fontSize: 12.5,
                          height: 1.3,
                          color: node.state == _NodeState.current
                              ? _color
                              : onSurface.withValues(alpha: 0.6),
                          fontWeight: node.state == _NodeState.current
                              ? FontWeight.w600
                              : FontWeight.w400,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _node() {
    final c = _color;
    Widget inner;
    switch (node.state) {
      case _NodeState.done:
        inner = const Icon(Icons.check_rounded, color: Colors.white, size: 18);
        break;
      case _NodeState.rejected:
        inner = const Icon(Icons.close_rounded, color: Colors.white, size: 18);
        break;
      case _NodeState.current:
        inner = const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(
            strokeWidth: 2.4,
            valueColor: AlwaysStoppedAnimation(Colors.white),
          ),
        );
        break;
      case _NodeState.future:
        inner = const SizedBox.shrink();
        break;
    }
    final filled = node.state != _NodeState.future;
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        color: filled ? c : Colors.transparent,
        shape: BoxShape.circle,
        border: Border.all(color: c, width: filled ? 0 : 2.5),
        boxShadow: node.state == _NodeState.current
            ? [BoxShadow(color: c.withValues(alpha: 0.4), blurRadius: 8, spreadRadius: 1)]
            : null,
      ),
      alignment: Alignment.center,
      child: inner,
    );
  }
}

/// Vertical connector line — solid or dashed. Uses CustomPaint (NOT
/// LayoutBuilder) so it is safe inside the IntrinsicHeight timeline row.
class _Connector extends StatelessWidget {
  final Color color;
  final bool dashed;
  const _Connector({required this.color, required this.dashed});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _LinePainter(color: color, dashed: dashed),
      child: const SizedBox.expand(),
    );
  }
}

class _LinePainter extends CustomPainter {
  final Color color;
  final bool dashed;
  _LinePainter({required this.color, required this.dashed});

  @override
  void paint(Canvas canvas, Size size) {
    final x = size.width / 2;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    if (!dashed) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
      return;
    }
    const dash = 5.0, gap = 4.0;
    double y = 0;
    while (y < size.height) {
      final end = (y + dash).clamp(0.0, size.height);
      canvas.drawLine(Offset(x, y), Offset(x, end), paint);
      y += dash + gap;
    }
  }

  @override
  bool shouldRepaint(_LinePainter old) =>
      old.color != color || old.dashed != dashed;
}
