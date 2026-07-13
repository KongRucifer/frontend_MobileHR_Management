import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/i18n.dart';
import '../../core/settings.dart';
import '../../core/theme.dart';
import 'leave_detail_page.dart';
import 'request_widgets.dart';
import 'requests_provider.dart';

/// Three tabs by status: "ລໍຖ້າ" (pending), "ອານຸມັດແລ້ວ" (approved),
/// "ຖືກປະຕິເສດ" (rejected). Tap a leave item to see the approval timeline.
class MyRequestsPage extends ConsumerStatefulWidget {
  const MyRequestsPage({super.key});

  @override
  ConsumerState<MyRequestsPage> createState() => _MyRequestsPageState();
}

class _MyRequestsPageState extends ConsumerState<MyRequestsPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tab = TabController(length: 3, vsync: this);

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(localeProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(tr('my_requests', lang)),
        actions: const [NotifBell(), SizedBox(width: 4)],
        bottom: whiteTabBar(
          controller: _tab,
          tabs: [
            Tab(text: tr('st_pending', lang)),
            Tab(text: tr('st_approved', lang)),
            Tab(text: tr('st_rejected', lang)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: const [
          _RequestList(status: 'pending'),
          _RequestList(status: 'approved'),
          _RequestList(status: 'rejected'),
        ],
      ),
    );
  }
}

/// Filtered list of the requester's own leave + sick requests by [status].
class _RequestList extends ConsumerWidget {
  final String status;
  const _RequestList({required this.status});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(localeProvider);
    final leaveAsync = ref.watch(myLeaveProvider);
    final sickAsync = ref.watch(mySickProvider);

    final loading = leaveAsync.isLoading || sickAsync.isLoading;
    final all = <Map<String, dynamic>>[
      ...(leaveAsync.value ?? []),
      ...(sickAsync.value ?? []),
    ]..sort((a, b) => (b['createdAt'] ?? '')
        .toString()
        .compareTo((a['createdAt'] ?? '').toString()));

    final items = all
        .where((r) => (r['status'] ?? 'pending').toString() == status)
        .toList();

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(myLeaveProvider);
        ref.invalidate(mySickProvider);
      },
      child: loading && all.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : items.isEmpty
              ? ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    const SizedBox(height: 120),
                    Center(child: Text(tr('no_requests', lang))),
                  ],
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, kNavInset),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 14),
                  itemBuilder: (_, i) => _RequestCard(items[i], lang),
                ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  final Map<String, dynamic> r;
  final String lang;
  const _RequestCard(this.r, this.lang);

  @override
  Widget build(BuildContext context) {
    final isLeave = r['type'] == 'leave';
    final status = (r['status'] ?? 'pending').toString();
    final muted =
        Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6);

    final card = Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: kCardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isLeave ? Icons.event_busy_rounded : Icons.healing_rounded,
                size: 18,
                color: kBrand,
              ),
              const SizedBox(width: 8),
              Text(
                isLeave
                    ? tr('leave', lang)
                    : '${tr('sick', lang)} · ${r['sickType'] ?? ''}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              statusChip(status, lang),
            ],
          ),
          const SizedBox(height: 8),
          if (isLeave)
            Text(
              '${prettyDate(r['startDate'])}  →  ${prettyDate(r['endDate'])}',
              style: TextStyle(fontSize: 12, color: muted),
            ),
          // Sick: show the single chosen approver so the requester knows who to wait for.
          if (!isLeave && (r['approver']?['name'] ?? '').toString().isNotEmpty) ...[
            const SizedBox(height: 2),
            Row(
              children: [
                Icon(Icons.person_outline_rounded, size: 14, color: muted),
                const SizedBox(width: 4),
                Text('${tr('approver', lang)}: ${r['approver']['name']}',
                    style: TextStyle(fontSize: 12, color: muted)),
              ],
            ),
          ],
          if ((r['reason'] ?? '').toString().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(r['reason'].toString(),
                maxLines: 2, overflow: TextOverflow.ellipsis),
          ],
          // Leave items open the timeline; show an affordance.
          if (isLeave) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Text(
                  tr('view_detail', lang),
                  style: const TextStyle(
                      color: kBrand, fontWeight: FontWeight.w600, fontSize: 13),
                ),
                const Icon(Icons.chevron_right_rounded, color: kBrand, size: 20),
              ],
            ),
          ],
        ],
      ),
    );

    if (!isLeave) return card;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => LeaveDetailPage(request: r)),
      ),
      child: card,
    );
  }
}
