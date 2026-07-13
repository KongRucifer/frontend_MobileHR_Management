import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api.dart';
import '../../core/i18n.dart';
import '../../core/settings.dart';
import '../../core/theme.dart';
import '../../widgets/brand_widgets.dart';
import '../requests/request_widgets.dart';
import '../requests/requests_provider.dart';

/// "Manage Leave" — bottom-nav page: requests this user needs to approve.
class InboxPage extends ConsumerWidget {
  const InboxPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(localeProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(tr('manage_leave', lang)),
        actions: const [NotifBell(), SizedBox(width: 4)],
      ),
      body: const InboxView(),
    );
  }
}

/// Approval inbox body. Combined leave + sick requests this user can act on.
class InboxView extends ConsumerWidget {
  const InboxView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(localeProvider);
    final async = ref.watch(inboxProvider);

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(inboxProvider),
      child: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _empty(context, lang),
        data: (items) {
          if (items.isEmpty) return _empty(context, lang);
          // Actionable first, then the rest.
          final sorted = [...items]..sort((a, b) =>
              (b['actionable'] == true ? 1 : 0) -
              (a['actionable'] == true ? 1 : 0));
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, kNavInset),
            itemCount: sorted.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (_, i) => _InboxCard(sorted[i]),
          );
        },
      ),
    );
  }

  Widget _empty(BuildContext context, String lang) => ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 140),
          Icon(Icons.inbox_rounded,
              size: 56,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.25)),
          const SizedBox(height: 12),
          Center(child: Text(tr('nothing_to_approve', lang))),
        ],
      );
}

class _InboxCard extends ConsumerWidget {
  final Map<String, dynamic> r;
  const _InboxCard(this.r);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(localeProvider);
    final isLeave = r['type'] == 'leave';
    final actionable = r['actionable'] == true;
    final status = (r['status'] ?? 'pending').toString();
    final requester = r['requester'] as Map?;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => DecisionPage(request: r)),
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: actionable ? kBrand.withValues(alpha: 0.5) : Theme.of(context).dividerColor,
            width: actionable ? 1.4 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(isLeave ? Icons.event_busy_rounded : Icons.healing_rounded,
                    size: 18, color: kBrand),
                const SizedBox(width: 8),
                Text(
                  isLeave
                      ? tr('leave', lang)
                      : '${tr('sick', lang)} · ${r['sickType'] ?? ''}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                if (actionable)
                  _Pill(tr('waiting_you', lang), kBrand)
                else
                  statusChip(status, lang),
              ],
            ),
            const SizedBox(height: 8),
            Text((requester?['name'] ?? '—').toString(),
                style: const TextStyle(fontWeight: FontWeight.w600)),
            if (isLeave)
              Text('${prettyDate(r['startDate'])}  →  ${prettyDate(r['endDate'])}',
                  style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.6))),
            if ((r['reason'] ?? '').toString().isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(r['reason'].toString(),
                  maxLines: 2, overflow: TextOverflow.ellipsis),
            ],
          ],
        ),
      ),
    );
  }
}

/// Detail screen with requester info + approve / reject actions.
class DecisionPage extends ConsumerStatefulWidget {
  final Map<String, dynamic> request;
  const DecisionPage({super.key, required this.request});

  @override
  ConsumerState<DecisionPage> createState() => _DecisionPageState();
}

class _DecisionPageState extends ConsumerState<DecisionPage> {
  final _comment = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _decide(bool approve, String lang) async {
    // Rejection must include a reason.
    if (!approve && _comment.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(tr('reject_reason_hint', lang)),
        backgroundColor: Theme.of(context).colorScheme.error,
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }
    setState(() => _busy = true);
    try {
      await RequestsApi.decide(
        type: widget.request['type'].toString(),
        id: widget.request['id'].toString(),
        approve: approve,
        comment: _comment.text.trim(),
      );
      ref.invalidate(inboxProvider);
      ref.invalidate(unreadCountProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(tr('decision_done', lang)),
        backgroundColor: Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
      ));
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(Api.message(e)),
        backgroundColor: Theme.of(context).colorScheme.error,
        behavior: SnackBarBehavior.floating,
      ));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(localeProvider);
    final r = widget.request;
    final isLeave = r['type'] == 'leave';
    final actionable = r['actionable'] == true;
    final requester = r['requester'] as Map?;
    final status = (r['status'] ?? 'pending').toString();

    return Scaffold(
      appBar: AppBar(
        title: Text(isLeave ? tr('leave', lang) : tr('sick', lang)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Requester info
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Theme.of(context).dividerColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(tr('requester', lang),
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.6))),
                    const Spacer(),
                    statusChip(status, lang),
                  ],
                ),
                const SizedBox(height: 8),
                _InfoRow(Icons.person_rounded, (requester?['name'] ?? '—').toString()),
                if ((requester?['phone'] ?? '').toString().isNotEmpty)
                  _InfoRow(Icons.phone_rounded, requester!['phone'].toString()),
                if ((requester?['email'] ?? '').toString().isNotEmpty)
                  _InfoRow(Icons.email_rounded, requester!['email'].toString()),
                if (!isLeave && (r['sickType'] ?? '').toString().isNotEmpty)
                  _InfoRow(Icons.healing_rounded, r['sickType'].toString()),
                if (isLeave)
                  _InfoRow(Icons.date_range_rounded,
                      '${prettyDate(r['startDate'])}  →  ${prettyDate(r['endDate'])}'),
                if ((r['reason'] ?? '').toString().isNotEmpty)
                  _InfoRow(Icons.notes_rounded, r['reason'].toString()),
              ],
            ),
          ),
          const SizedBox(height: 20),
          if (actionable) ...[
            TextField(
              controller: _comment,
              maxLines: 3,
              decoration: InputDecoration(
                hintText:
                    '${tr('comment_optional', lang)} · ${tr('reject_reason_hint', lang)}',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _busy ? null : () => _decide(false, lang),
                    icon: const Icon(Icons.close_rounded),
                    label: Text(tr('reject', lang)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red.shade600,
                      side: BorderSide(color: Colors.red.shade300),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GradientButton(
                    label: tr('approve', lang),
                    loading: _busy,
                    onPressed: () => _decide(true, lang),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoRow(this.icon, this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 17, color: kBrand),
          const SizedBox(width: 10),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String text;
  final Color color;
  const _Pill(this.text, this.color);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(text,
            style: TextStyle(
                color: color, fontWeight: FontWeight.w600, fontSize: 12)),
      );
}
