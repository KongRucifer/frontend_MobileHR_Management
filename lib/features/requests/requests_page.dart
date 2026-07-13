import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api.dart';
import '../../core/i18n.dart';
import '../../core/settings.dart';
import '../../core/theme.dart';
import '../../widgets/brand_widgets.dart';
import 'request_widgets.dart';
import 'requests_provider.dart';

class RequestsPage extends ConsumerStatefulWidget {
  const RequestsPage({super.key});

  @override
  ConsumerState<RequestsPage> createState() => _RequestsPageState();
}

class _RequestsPageState extends ConsumerState<RequestsPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tab = TabController(length: 2, vsync: this);

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
        title: Text(tr('requests', lang)),
        actions: const [
          NotifBell(),
          SizedBox(width: 4),
        ],
        bottom: whiteTabBar(
          controller: _tab,
          tabs: [
            Tab(text: tr('leave', lang)),
            Tab(text: tr('sick', lang)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: const [_LeaveForm(), _SickForm()],
      ),
    );
  }
}

// ======================= LEAVE FORM =======================
class _LeaveForm extends ConsumerStatefulWidget {
  const _LeaveForm();

  @override
  ConsumerState<_LeaveForm> createState() => _LeaveFormState();
}

class _LeaveFormState extends ConsumerState<_LeaveForm> {
  final _reason = TextEditingController();
  DateTime? _start;
  DateTime? _end;
  bool _busy = false;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<DateTime?> _pick(DateTime? initial) => showDatePicker(
        context: context,
        initialDate: initial ?? DateTime.now(),
        firstDate: DateTime.now().subtract(const Duration(days: 1)),
        lastDate: DateTime.now().add(const Duration(days: 365)),
      );

  Future<void> _submit(String lang) async {
    if (_reason.text.trim().isEmpty) {
      _toast(tr('reason_required', lang), false);
      return;
    }
    if (_start == null || _end == null) {
      _toast(tr('pick_required', lang), false);
      return;
    }
    final ok = await _confirm(context, lang);
    if (ok != true) return;
    setState(() => _busy = true);
    try {
      await RequestsApi.createLeave(
        reason: _reason.text.trim(),
        startDate: ymd(_start!),
        endDate: ymd(_end!),
      );
      ref.invalidate(myLeaveProvider);
      if (!mounted) return;
      _reason.clear();
      setState(() {
        _start = null;
        _end = null;
      });
      _toast(tr('request_sent', lang), true);
    } catch (e) {
      _toast(Api.message(e), false);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _toast(String m, bool ok) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(m),
      backgroundColor:
          ok ? Colors.green.shade600 : Theme.of(context).colorScheme.error,
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(localeProvider);
    final chainAsync = ref.watch(leaveChainProvider);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, kNavInset),
      children: [
        // Date range
        Row(
          children: [
            Expanded(
              child: _DateField(
                label: tr('start_date', lang),
                value: _start,
                onTap: () async {
                  final d = await _pick(_start);
                  if (d != null) setState(() => _start = d);
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _DateField(
                label: tr('end_date', lang),
                value: _end,
                onTap: () async {
                  final d = await _pick(_end ?? _start);
                  if (d != null) setState(() => _end = d);
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        _Label(tr('reason', lang)),
        const SizedBox(height: 6),
        TextField(
          controller: _reason,
          maxLines: 4,
          decoration: _boxInput(context, tr('reason_hint', lang)),
        ),
        const SizedBox(height: 22),
        // Read-only approver chain (employee does NOT choose).
        _Label(tr('approvers_in_order', lang)),
        const SizedBox(height: 8),
        chainAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(12),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => Text(tr('no_chain_yet', lang)),
          data: (chain) {
            if (chain.isEmpty) {
              return _MutedNote(tr('no_chain_yet', lang));
            }
            return Column(
              children: [
                for (final s in chain)
                  _ChainRow(
                    step: (s['stepOrder'] ?? 0) as int,
                    name: (s['approver']?['name'] ?? '—').toString(),
                    phone: s['approver']?['phone']?.toString(),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 26),
        GradientButton(
          label: tr('submit_request', lang),
          loading: _busy,
          onPressed: () => _submit(lang),
        ),
      ],
    );
  }
}

// ======================= SICK FORM =======================
class _SickForm extends ConsumerStatefulWidget {
  const _SickForm();

  @override
  ConsumerState<_SickForm> createState() => _SickFormState();
}

class _SickFormState extends ConsumerState<_SickForm> {
  final _reason = TextEditingController();
  final _search = TextEditingController();
  String? _typeId;
  String? _approverUserId;
  bool _busy = false;

  @override
  void dispose() {
    _reason.dispose();
    _search.dispose();
    super.dispose();
  }

  Future<void> _submit(String lang) async {
    if (_typeId == null) {
      _toast(tr('pick_required', lang), false);
      return;
    }
    if (_reason.text.trim().isEmpty) {
      _toast(tr('reason_required', lang), false);
      return;
    }
    if (_approverUserId == null) {
      _toast(tr('pick_required', lang), false);
      return;
    }
    final ok = await _confirm(context, lang);
    if (ok != true) return;
    setState(() => _busy = true);
    try {
      await RequestsApi.createSick(
        sickTypeId: _typeId!,
        approverUserId: _approverUserId!,
        reason: _reason.text.trim(),
      );
      ref.invalidate(mySickProvider);
      if (!mounted) return;
      _reason.clear();
      _search.clear();
      setState(() {
        _typeId = null;
        _approverUserId = null;
      });
      _toast(tr('request_sent', lang), true);
    } catch (e) {
      _toast(Api.message(e), false);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _toast(String m, bool ok) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(m),
      backgroundColor:
          ok ? Colors.green.shade600 : Theme.of(context).colorScheme.error,
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(localeProvider);
    final typesAsync = ref.watch(sickTypesProvider);
    final poolAsync = ref.watch(sickPoolProvider);
    final query = _search.text.trim().toLowerCase();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, kNavInset),
      children: [
        _Label(tr('sick_type', lang)),
        const SizedBox(height: 8),
        typesAsync.when(
          loading: () => const LinearProgressIndicator(),
          error: (e, _) => Text(Api.message(e)),
          data: (types) => Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final t in types)
                _ChoiceChip(
                  label: (t['name'] ?? '').toString(),
                  selected: _typeId == t['id'],
                  onTap: () => setState(() => _typeId = t['id'].toString()),
                ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _Label(tr('reason', lang)),
        const SizedBox(height: 6),
        TextField(
          controller: _reason,
          maxLines: 3,
          decoration: _boxInput(context, tr('reason_hint', lang)),
        ),
        const SizedBox(height: 20),
        _Label(tr('choose_approver', lang)),
        const SizedBox(height: 8),
        TextField(
          controller: _search,
          onChanged: (_) => setState(() {}),
          decoration: _boxInput(context, tr('search_name_phone', lang)).copyWith(
            prefixIcon: const Icon(Icons.search_rounded, size: 20),
          ),
        ),
        const SizedBox(height: 10),
        poolAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(12),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => Text(Api.message(e)),
          data: (pool) {
            final filtered = pool.where((p) {
              if (query.isEmpty) return true;
              final n = (p['approver']?['name'] ?? '').toString().toLowerCase();
              final ph = (p['approver']?['phone'] ?? '').toString().toLowerCase();
              return n.contains(query) || ph.contains(query);
            }).toList();
            if (filtered.isEmpty) return _MutedNote(tr('no_chain_yet', lang));
            return Column(
              children: [
                for (final p in filtered)
                  _ApproverPickRow(
                    name: (p['approver']?['name'] ?? '—').toString(),
                    phone: p['approver']?['phone']?.toString(),
                    selected: _approverUserId == p['approverUserId'],
                    onTap: () => setState(
                        () => _approverUserId = p['approverUserId'].toString()),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 26),
        GradientButton(
          label: tr('submit_request', lang),
          loading: _busy,
          onPressed: () => _submit(lang),
        ),
      ],
    );
  }
}

// ======================= shared bits =======================
Future<bool?> _confirm(BuildContext context, String lang) => showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('confirm_submit_title', lang)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(tr('cancel', lang)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: kBrand),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(tr('confirm', lang)),
          ),
        ],
      ),
    );

InputDecoration _boxInput(BuildContext context, String hint) {
  final border = OutlineInputBorder(
    borderRadius: BorderRadius.circular(14),
    borderSide: BorderSide(color: Theme.of(context).dividerColor),
  );
  return InputDecoration(
    hintText: hint,
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    border: border,
    enabledBorder: border,
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: kBrand, width: 1.6),
    ),
  );
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);
  @override
  Widget build(BuildContext context) => Text(
        text,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 13,
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
        ),
      );
}

class _MutedNote extends StatelessWidget {
  final String text;
  const _MutedNote(this.text);
  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          text,
          style: TextStyle(
            color:
                Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
      );
}

class _DateField extends StatelessWidget {
  final String label;
  final DateTime? value;
  final VoidCallback onTap;
  const _DateField({required this.label, required this.value, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Label(label),
        const SizedBox(height: 6),
        InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Theme.of(context).dividerColor),
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_today_rounded, size: 16, color: kBrand),
                const SizedBox(width: 8),
                Text(value == null ? '--' : ymd(value!)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ChainRow extends StatelessWidget {
  final int step;
  final String name;
  final String? phone;
  const _ChainRow({required this.step, required this.name, this.phone});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: kCardShadow,
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: kBrand.withValues(alpha: 0.12),
            child: Text('$step',
                style: const TextStyle(
                    color: kBrand, fontWeight: FontWeight.bold, fontSize: 13)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
                if (phone != null && phone!.isNotEmpty)
                  Text(phone!,
                      style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.55))),
              ],
            ),
          ),
          Icon(Icons.arrow_downward_rounded,
              size: 16,
              color:
                  Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3)),
        ],
      ),
    );
  }
}

class _ApproverPickRow extends StatelessWidget {
  final String name;
  final String? phone;
  final bool selected;
  final VoidCallback onTap;
  const _ApproverPickRow({
    required this.name,
    required this.phone,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? kBrand.withValues(alpha: 0.08) : null,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? kBrand : Theme.of(context).dividerColor,
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              selected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_unchecked_rounded,
              color: selected
                  ? kBrand
                  : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  if (phone != null && phone!.isNotEmpty)
                    Text(phone!,
                        style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.55))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChoiceChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _ChoiceChip(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? kBrand : null,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? kBrand : Theme.of(context).dividerColor,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected
                ? Colors.white
                : Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}
