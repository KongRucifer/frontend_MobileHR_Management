import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api.dart';
import '../../core/i18n.dart';
import '../../core/settings.dart';
import '../../core/theme.dart';
import '../auth/auth_provider.dart';

/// The logged-in employee's own record (for display + editing).
final myEmployeeProvider =
    FutureProvider.autoDispose<Map<String, dynamic>?>((ref) async {
  final user = ref.watch(authProvider).user;
  if (user?.employeeId == null) return null;
  final res = await Api.dio.get('/employees/${user!.employeeId}');
  return Map<String, dynamic>.from(res.data);
});

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  void _toast(BuildContext context, String msg, {required bool ok}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor:
          ok ? Colors.green.shade600 : Theme.of(context).colorScheme.error,
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(localeProvider);
    final user = ref.watch(authProvider).user;
    final isDark = ref.watch(themeModeProvider) == ThemeMode.dark;
    final empAsync = ref.watch(myEmployeeProvider);
    final emp = empAsync.value;

    final name = emp != null
        ? '${emp['firstName'] ?? ''} ${emp['lastName'] ?? ''}'.trim()
        : (user?.username ?? user?.email ?? '');

    return Scaffold(
      appBar: AppBar(title: Text(tr('profile', lang))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: kBrandGradient,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.white.withValues(alpha: 0.25),
                  child: Text(
                    (user?.email.substring(0, 1) ?? '?').toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name.isEmpty ? tr('employee', lang) : name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        user?.email ?? '',
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          if (emp != null) ...[
            _info(context, Icons.badge_outlined, tr('employee', lang),
                emp['employeeCode']?.toString() ?? '-'),
            _info(context, Icons.phone_outlined, tr('phone', lang),
                emp['phone']?.toString() ?? '-'),
            _info(context, Icons.cake_outlined, tr('birth_date', lang),
                (emp['birthDate']?.toString() ?? '-').split('T').first),
          ],

          const SizedBox(height: 8),
          _actionTile(
            context,
            icon: Icons.edit_outlined,
            title: tr('edit_profile', lang),
            onTap: emp == null
                ? null
                : () => _openEdit(context, ref, lang, emp),
          ),
          _actionTile(
            context,
            icon: Icons.lock_outline,
            title: tr('change_password', lang),
            onTap: () => _openChangePassword(context, ref, lang),
          ),

          const SizedBox(height: 12),
          _tile(
            context,
            icon: Icons.dark_mode_outlined,
            title: tr('theme', lang),
            trailing: Switch(
              value: isDark,
              onChanged: (_) => ref.read(themeModeProvider.notifier).toggle(),
            ),
          ),
          _tile(
            context,
            icon: Icons.translate,
            title: tr('language', lang),
            trailing: SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'lo', label: Text('ລາວ')),
                ButtonSegment(value: 'en', label: Text('EN')),
              ],
              selected: {lang},
              onSelectionChanged: (s) =>
                  ref.read(localeProvider.notifier).set(s.first),
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.tonalIcon(
            onPressed: () => ref.read(authProvider.notifier).logout(),
            icon: const Icon(Icons.logout),
            label: Text(tr('logout', lang)),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
              backgroundColor:
                  Theme.of(context).colorScheme.error.withValues(alpha: 0.12),
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
          ),
        ],
      ),
    );
  }

  // ---- Edit profile sheet ----
  void _openEdit(BuildContext context, WidgetRef ref, String lang,
      Map<String, dynamic> emp) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _EditProfileSheet(
        lang: lang,
        emp: emp,
        onDone: () {
          ref.invalidate(myEmployeeProvider);
          _toast(context, tr('saved', lang), ok: true);
        },
        onError: (m) => _toast(context, m, ok: false),
      ),
    );
  }

  void _openChangePassword(BuildContext context, WidgetRef ref, String lang) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _ChangePasswordSheet(
        lang: lang,
        onDone: () => _toast(context, tr('password_changed', lang), ok: true),
        onError: (m) => _toast(context, m, ok: false),
      ),
    );
  }

  Widget _info(BuildContext context, IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: kBrand),
          const SizedBox(width: 12),
          Text(label,
              style: TextStyle(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.6))),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    VoidCallback? onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 14,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: ListTile(
        leading: Icon(icon, color: kBrand),
        title: Text(
          title,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
        trailing: Icon(
          Icons.chevron_right,
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
        ),
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  Widget _tile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required Widget trailing,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 14,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, color: kBrand),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                color:
                    Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ),
          trailing,
        ],
      ),
    );
  }
}

// ---------------- Edit profile sheet ----------------
class _EditProfileSheet extends StatefulWidget {
  final String lang;
  final Map<String, dynamic> emp;
  final VoidCallback onDone;
  final void Function(String) onError;
  const _EditProfileSheet({
    required this.lang,
    required this.emp,
    required this.onDone,
    required this.onError,
  });

  @override
  State<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<_EditProfileSheet> {
  late final TextEditingController _first =
      TextEditingController(text: widget.emp['firstName']?.toString() ?? '');
  late final TextEditingController _last =
      TextEditingController(text: widget.emp['lastName']?.toString() ?? '');
  late final TextEditingController _phone =
      TextEditingController(text: widget.emp['phone']?.toString() ?? '');
  late DateTime? _birth = DateTime.tryParse(
      (widget.emp['birthDate']?.toString() ?? '').split('T').first);
  bool _loading = false;

  @override
  void dispose() {
    _first.dispose();
    _last.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _loading = true);
    try {
      await Api.dio.patch('/auth/profile', data: {
        'firstName': _first.text.trim(),
        'lastName': _last.text.trim(),
        'phone': _phone.text.trim(),
        if (_birth != null)
          'birthDate':
              '${_birth!.year.toString().padLeft(4, '0')}-${_birth!.month.toString().padLeft(2, '0')}-${_birth!.day.toString().padLeft(2, '0')}',
      });
      if (mounted) Navigator.pop(context);
      widget.onDone();
    } catch (e) {
      widget.onError(Api.message(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = widget.lang;
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 4,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(tr('edit_profile', lang),
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          _f(_first, tr('first_name', lang)),
          const SizedBox(height: 12),
          _f(_last, tr('last_name', lang)),
          const SizedBox(height: 12),
          _f(_phone, tr('phone', lang), keyboard: TextInputType.phone),
          const SizedBox(height: 12),
          InkWell(
            onTap: () async {
              final now = DateTime.now();
              final d = await showDatePicker(
                context: context,
                initialDate: _birth ?? DateTime(now.year - 20),
                firstDate: DateTime(1950),
                lastDate: now,
              );
              if (d != null) setState(() => _birth = d);
            },
            child: InputDecorator(
              decoration: _dec(tr('birth_date', lang)),
              child: Text(_birth == null
                  ? tr('select_date', lang)
                  : '${_birth!.day.toString().padLeft(2, '0')}/${_birth!.month.toString().padLeft(2, '0')}/${_birth!.year}'),
            ),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _loading ? null : _save,
            style: FilledButton.styleFrom(
              backgroundColor: kBrand,
              minimumSize: const Size.fromHeight(50),
            ),
            child: Text(_loading ? tr('saving', lang) : tr('save', lang)),
          ),
        ],
      ),
    );
  }

  InputDecoration _dec(String label) => InputDecoration(
        labelText: label,
        border:
            OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      );

  Widget _f(TextEditingController c, String label, {TextInputType? keyboard}) =>
      TextField(controller: c, keyboardType: keyboard, decoration: _dec(label));
}

// ---------------- Change password sheet ----------------
class _ChangePasswordSheet extends StatefulWidget {
  final String lang;
  final VoidCallback onDone;
  final void Function(String) onError;
  const _ChangePasswordSheet({
    required this.lang,
    required this.onDone,
    required this.onError,
  });

  @override
  State<_ChangePasswordSheet> createState() => _ChangePasswordSheetState();
}

class _ChangePasswordSheetState extends State<_ChangePasswordSheet> {
  final _current = TextEditingController();
  final _new = TextEditingController();
  final _confirm = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _current.dispose();
    _new.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final lang = widget.lang;
    if (_new.text.length < 8) {
      widget.onError(tr('password_short', lang));
      return;
    }
    if (_new.text != _confirm.text) {
      widget.onError(tr('password_mismatch', lang));
      return;
    }
    setState(() => _loading = true);
    try {
      await Api.dio.patch('/auth/password', data: {
        'currentPassword': _current.text,
        'newPassword': _new.text,
      });
      if (mounted) Navigator.pop(context);
      widget.onDone();
    } catch (e) {
      widget.onError(Api.message(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = widget.lang;
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 4,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(tr('change_password', lang),
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          _f(_current, tr('current_password', lang)),
          const SizedBox(height: 12),
          _f(_new, tr('new_password', lang)),
          const SizedBox(height: 12),
          _f(_confirm, tr('confirm_password', lang)),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _loading ? null : _save,
            style: FilledButton.styleFrom(
              backgroundColor: kBrand,
              minimumSize: const Size.fromHeight(50),
            ),
            child: Text(_loading ? tr('saving', lang) : tr('save', lang)),
          ),
        ],
      ),
    );
  }

  Widget _f(TextEditingController c, String label) => TextField(
        controller: c,
        obscureText: true,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
}
