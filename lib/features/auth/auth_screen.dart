import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api.dart';
import '../../core/i18n.dart';
import '../../core/settings.dart';
import '../../widgets/brand_widgets.dart';
import 'auth_provider.dart';
import 'lookup_provider.dart';

/// Live availability state for the email / username sign-up fields.
enum _Avail { idle, invalid, checking, available, taken }

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  bool showRegister = false;
  bool loading = false;

  final firstName = TextEditingController();
  final lastName = TextEditingController();
  final username = TextEditingController();
  final phone = TextEditingController();
  final email = TextEditingController();
  final password = TextEditingController();
  final confirmPassword = TextEditingController();
  final _scroll = ScrollController();
  // Inner scroll for the register field box (shows ~4 fields, scrolls the rest).
  final _formScroll = ScrollController();
  DateTime? birthDate;
  String? departmentId;
  String? positionId;

  /// Password fields whose text is currently revealed (eye toggle).
  final Set<TextEditingController> _visiblePw = {};

  // Live availability status for email / username (register mode only).
  _Avail _emailStatus = _Avail.idle;
  _Avail _usernameStatus = _Avail.idle;
  Timer? _emailTimer;
  Timer? _usernameTimer;

  @override
  void initState() {
    super.initState();
    email.addListener(_onEmailChanged);
    username.addListener(_onUsernameChanged);
  }

  @override
  void dispose() {
    _emailTimer?.cancel();
    _usernameTimer?.cancel();
    firstName.dispose();
    lastName.dispose();
    username.dispose();
    phone.dispose();
    email.dispose();
    password.dispose();
    confirmPassword.dispose();
    _scroll.dispose();
    _formScroll.dispose();
    super.dispose();
  }

  // ---- Live email / username availability (debounced 500ms) ----
  void _setEmailStatus(_Avail s) {
    if (mounted && _emailStatus != s) setState(() => _emailStatus = s);
  }

  void _setUsernameStatus(_Avail s) {
    if (mounted && _usernameStatus != s) setState(() => _usernameStatus = s);
  }

  void _onEmailChanged() {
    if (!showRegister) return;
    _emailTimer?.cancel();
    final value = email.text.trim();
    if (value.isEmpty) {
      _setEmailStatus(_Avail.idle);
      return;
    }
    if (!RegExp(r'^\S+@\S+\.\S+$').hasMatch(value)) {
      _setEmailStatus(_Avail.invalid);
      return;
    }
    _setEmailStatus(_Avail.checking);
    _emailTimer =
        Timer(const Duration(milliseconds: 500), () => _checkEmail(value));
  }

  void _onUsernameChanged() {
    if (!showRegister) return;
    _usernameTimer?.cancel();
    final value = username.text.trim();
    if (value.length < 3) {
      _setUsernameStatus(_Avail.idle);
      return;
    }
    _setUsernameStatus(_Avail.checking);
    _usernameTimer =
        Timer(const Duration(milliseconds: 500), () => _checkUsername(value));
  }

  Future<void> _checkEmail(String value) async {
    try {
      final res = await Api.dio
          .get('/auth/availability', queryParameters: {'email': value});
      final data = res.data;
      final available = data is Map && data['emailAvailable'] == true;
      // Ignore if the field changed while the request was in flight.
      if (!mounted || email.text.trim() != value) return;
      _setEmailStatus(available ? _Avail.available : _Avail.taken);
    } catch (_) {
      _setEmailStatus(_Avail.idle);
    }
  }

  Future<void> _checkUsername(String value) async {
    try {
      final res = await Api.dio
          .get('/auth/availability', queryParameters: {'username': value});
      final data = res.data;
      final available = data is Map && data['usernameAvailable'] == true;
      if (!mounted || username.text.trim() != value) return;
      _setUsernameStatus(available ? _Avail.available : _Avail.taken);
    } catch (_) {
      _setUsernameStatus(_Avail.idle);
    }
  }

  Future<void> _submit(String lang) async {
    // Username is the login identifier — required in both modes.
    if (username.text.trim().length < 3) {
      _error(tr('username_required', lang));
      return;
    }
    // Register validations: email/username availability, password rules.
    if (showRegister && _emailStatus == _Avail.invalid) {
      _error(tr('invalid_email', lang));
      return;
    }
    if (showRegister && _emailStatus == _Avail.taken) {
      _error(tr('email_taken', lang));
      return;
    }
    if (showRegister && _usernameStatus == _Avail.taken) {
      _error(tr('username_taken', lang));
      return;
    }
    if (showRegister && password.text.length < 8) {
      _error(tr('password_short', lang));
      return;
    }
    if (showRegister && password.text != confirmPassword.text) {
      _error(tr('password_mismatch', lang));
      return;
    }
    setState(() => loading = true);
    try {
      final auth = ref.read(authProvider.notifier);
      if (showRegister) {
        await auth.register(
          firstName: firstName.text.trim(),
          lastName: lastName.text.trim(),
          email: email.text.trim(),
          password: password.text,
          username: username.text.trim(),
          phone: phone.text.trim(),
          birthDate: birthDate == null
              ? null
              : '${birthDate!.year.toString().padLeft(4, '0')}-'
                  '${birthDate!.month.toString().padLeft(2, '0')}-'
                  '${birthDate!.day.toString().padLeft(2, '0')}',
          departmentId: departmentId,
          positionId: positionId,
        );
      } else {
        await auth.login(username.text.trim(), password.text);
      }
      // On success, AuthGate swaps to the main shell automatically.
    } catch (e) {
      _error(Api.message(e));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  /// Red, bilingual error toast.
  void _error(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Theme.of(context).colorScheme.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(localeProvider);
    final depsAsync = ref.watch(departmentsProvider);
    final posAsync = ref.watch(positionsProvider);
    return Scaffold(
          body: SafeArea(
            child: Column(
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: TopToggles(),
                  ),
                ),
                Expanded(
                  child: Scrollbar(
                    controller: _scroll,
                    thumbVisibility: false,
                    child: Center(
                    child: SingleChildScrollView(
                      controller: _scroll,
                      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                      child: BrandLayeredCard(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Center(
                              child: Image.asset(
                                Theme.of(context).brightness == Brightness.dark
                                    ? 'assets/images/dark-removebg-preview.png'
                                    : 'assets/images/light-removebg-preview.png',
                                height: 88,
                                fit: BoxFit.contain,
                              ),
                            ),
                            const SizedBox(height: 6),
                            // Wordmark under the logo (login + register).
                            const Center(child: BrandWordmark(scale: 0.85)),
                            const SizedBox(height: 10),
                            Center(
                              child: Text(
                                showRegister
                                    ? tr('sign_up', lang)
                                    : tr('welcome', lang),
                                style: TextStyle(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withValues(alpha: 0.6),
                                ),
                              ),
                            ),
                            const SizedBox(height: 22),
                            if (showRegister)
                              // All inputs live in a fixed-height scroll box:
                              // ~4 fields show, the rest scrolls inside it.
                              _registerFieldsBox(lang, depsAsync, posAsync)
                            else ...[
                              // Login is by username (not email).
                              _field(tr('username', lang), username),
                              const SizedBox(height: 14),
                              _field(tr('password', lang), password,
                                  obscure: true),
                            ],
                            const SizedBox(height: 22),
                            GradientButton(
                                label: loading
                                    ? (showRegister
                                        ? tr('registering', lang)
                                        : tr('logging_in', lang))
                                    : (showRegister
                                        ? tr('register', lang)
                                        : tr('login', lang)),
                                loading: loading,
                                onPressed: () => _submit(lang),
                              ),
                            const SizedBox(height: 16),
                            Center(
                              child: GestureDetector(
                                onTap: () {
                                  setState(() {
                                    showRegister = !showRegister;
                                    _emailStatus = _Avail.idle;
                                    _usernameStatus = _Avail.idle;
                                  });
                                  // Re-evaluate current input when entering register.
                                  if (showRegister) {
                                    _onEmailChanged();
                                    _onUsernameChanged();
                                  }
                                },
                                child: Text.rich(
                                  TextSpan(
                                    text: showRegister
                                        ? '${tr('have_account', lang)} '
                                        : '${tr('no_account', lang)} ',
                                    style: TextStyle(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface
                                          .withValues(alpha: 0.7),
                                    ),
                                    children: [
                                      TextSpan(
                                        text: showRegister
                                            ? tr('sign_in', lang)
                                            : tr('sign_up', lang),
                                        style: const TextStyle(
                                          color: Color(0xFF2EACEB),
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                ),
              ),
            ],
          ),
        ),
    );
  }

  /// Fixed-height scroll box holding every register input. About 4 fields are
  /// visible; the rest scroll inside (its own scrollbar). The header and the
  /// action button stay pinned outside this box.
  Widget _registerFieldsBox(
    String lang,
    AsyncValue<List<Map<String, dynamic>>> depsAsync,
    AsyncValue<List<Map<String, dynamic>>> posAsync,
  ) {
    final boxHeight =
        (MediaQuery.of(context).size.height * 0.42).clamp(260.0, 380.0);
    return SizedBox(
      height: boxHeight,
      child: Scrollbar(
        controller: _formScroll,
        thumbVisibility: true,
        child: SingleChildScrollView(
          controller: _formScroll,
          // Room on the right so the scrollbar doesn't overlap the fields.
          padding: const EdgeInsets.only(right: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _field(tr('first_name', lang), firstName),
              const SizedBox(height: 14),
              _field(tr('last_name', lang), lastName),
              const SizedBox(height: 14),
              _field(
                tr('username', lang),
                username,
                footer: _availHint(_usernameStatus, lang, isEmail: false),
              ),
              const SizedBox(height: 14),
              _field(
                tr('phone', lang),
                phone,
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 14),
              _dateField(lang),
              const SizedBox(height: 6),
              depsAsync.maybeWhen(
                data: (deps) => _lineSelect(
                  tr('department', lang),
                  _nameOf(deps, departmentId),
                  () async {
                    final id = await _pickFromSheet(
                        lang, tr('department', lang), deps);
                    if (id != null) {
                      setState(() {
                        departmentId = id;
                        positionId = null;
                      });
                    }
                  },
                ),
                orElse: () => const SizedBox.shrink(),
              ),
              const SizedBox(height: 6),
              posAsync.maybeWhen(
                data: (pos) {
                  final filtered = departmentId == null
                      ? pos
                      : pos
                          .where((p) => p['departmentId'] == departmentId)
                          .toList();
                  return _lineSelect(
                    tr('position', lang),
                    _nameOf(pos, positionId),
                    () async {
                      final id = await _pickFromSheet(
                          lang, tr('position', lang), filtered);
                      if (id != null) {
                        setState(() {
                          positionId = id;
                          final match = pos.firstWhere(
                            (x) => x['id'] == id,
                            orElse: () => <String, dynamic>{},
                          );
                          if (match['departmentId'] != null) {
                            departmentId = match['departmentId'] as String;
                          }
                        });
                      }
                    },
                  );
                },
                orElse: () => const SizedBox.shrink(),
              ),
              const SizedBox(height: 14),
              _field(
                tr('email', lang),
                email,
                keyboardType: TextInputType.emailAddress,
                footer: _availHint(_emailStatus, lang, isEmail: true),
              ),
              const SizedBox(height: 14),
              _field(tr('password', lang), password, obscure: true),
              const SizedBox(height: 14),
              _field(tr('confirm_password', lang), confirmPassword,
                  obscure: true),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(
    String label,
    TextEditingController controller, {
    bool obscure = false,
    TextInputType? keyboardType,
    Widget? footer,
  }) {
    final grey = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.35);
    // Password fields get an eye toggle; visibility is tracked per controller.
    final show = _visiblePw.contains(controller);
    final field = TextField(
      controller: controller,
      obscureText: obscure && !show,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        suffixIcon: !obscure
            ? null
            : IconButton(
                icon: Icon(
                  show
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  size: 20,
                  color: grey,
                ),
                onPressed: () => setState(() {
                  if (show) {
                    _visiblePw.remove(controller);
                  } else {
                    _visiblePw.add(controller);
                  }
                }),
              ),
        suffixIconConstraints: const BoxConstraints(minWidth: 40),
        labelText: label,
        // Underline style: label sits above the line (grey), turns blue on focus.
        floatingLabelBehavior: FloatingLabelBehavior.always,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 8),
        enabledBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: grey),
        ),
        focusedBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: Color(0xFF2EACEB), width: 2),
        ),
      ),
    );
    if (footer == null) return field;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [field, footer],
    );
  }

  /// Inline availability feedback shown under the email / username fields.
  Widget _availHint(_Avail status, String lang, {required bool isEmail}) {
    if (status == _Avail.idle) return const SizedBox.shrink();

    final grey = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6);
    if (status == _Avail.checking) {
      return Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Row(
          children: [
            const SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 6),
            Text(tr('checking', lang),
                style: TextStyle(fontSize: 12, color: grey)),
          ],
        ),
      );
    }

    late final Color color;
    late final IconData icon;
    late final String text;
    if (status == _Avail.invalid) {
      color = Colors.red.shade600;
      icon = Icons.error_outline;
      text = tr('invalid_email', lang);
    } else if (status == _Avail.taken) {
      color = Colors.red.shade600;
      icon = Icons.close;
      text = tr(isEmail ? 'email_taken' : 'username_taken', lang);
    } else {
      color = Colors.green.shade600;
      icon = Icons.check;
      text = tr(isEmail ? 'email_available' : 'username_available', lang);
    }
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Text(text, style: TextStyle(fontSize: 12, color: color)),
          ),
        ],
      ),
    );
  }

  /// Finds an item's name by id (for showing the selected label).
  String? _nameOf(List<Map<String, dynamic>> items, String? id) {
    if (id == null) return null;
    final m = items.firstWhere(
      (x) => x['id'] == id,
      orElse: () => <String, dynamic>{},
    );
    return m['name']?.toString();
  }

  /// Underline-style field that opens a searchable picker on tap.
  Widget _lineSelect(String label, String? valueText, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const UnderlineInputBorder(),
          enabledBorder: UnderlineInputBorder(
            borderSide: BorderSide(color: Theme.of(context).dividerColor),
          ),
          focusedBorder: const UnderlineInputBorder(
            borderSide: BorderSide(color: Color(0xFF2EACEB), width: 2),
          ),
          suffixIcon: const Icon(Icons.arrow_drop_down),
        ),
        child: Text(
          valueText ?? '',
          style: TextStyle(
            color: valueText == null ? Theme.of(context).hintColor : null,
          ),
        ),
      ),
    );
  }

  /// Bottom sheet with a search box + filtered list. Returns the picked id.
  Future<String?> _pickFromSheet(
    String lang,
    String title,
    List<Map<String, dynamic>> items,
  ) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        String q = '';
        return StatefulBuilder(
          builder: (ctx, setSheet) {
            final filtered = items
                .where((it) => (it['name']?.toString() ?? '')
                    .toLowerCase()
                    .contains(q.toLowerCase()))
                .toList();
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom,
              ),
              child: SizedBox(
                height: MediaQuery.of(ctx).size.height * 0.6,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: Text(title,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 16)),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: TextField(
                        autofocus: true,
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.search),
                          hintText: tr('search', lang),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onChanged: (v) => setSheet(() => q = v),
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        itemCount: filtered.length,
                        itemBuilder: (_, i) => ListTile(
                          title: Text(filtered[i]['name']?.toString() ?? ''),
                          onTap: () =>
                              Navigator.pop(ctx, filtered[i]['id'] as String),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// Tappable field that opens a date picker for the birth date.
  Widget _dateField(String lang) {
    final text = birthDate == null
        ? tr('select_date', lang)
        : '${birthDate!.day.toString().padLeft(2, '0')}/'
            '${birthDate!.month.toString().padLeft(2, '0')}/'
            '${birthDate!.year}';
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () async {
        final now = DateTime.now();
        final picked = await showDatePicker(
          context: context,
          initialDate: birthDate ?? DateTime(now.year - 20),
          firstDate: DateTime(1950),
          lastDate: now,
          builder: (context, child) => Theme(
            data: Theme.of(context).copyWith(
              colorScheme: Theme.of(context)
                  .colorScheme
                  .copyWith(primary: const Color(0xFF2EACEB)),
            ),
            child: child!,
          ),
        );
        if (picked != null) setState(() => birthDate = picked);
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: tr('birth_date', lang),
          floatingLabelBehavior: FloatingLabelBehavior.always,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 8),
          prefixIcon: const Icon(Icons.cake_outlined, color: Color(0xFF2EACEB)),
          prefixIconConstraints: const BoxConstraints(minWidth: 32),
          enabledBorder: UnderlineInputBorder(
            borderSide: BorderSide(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.35),
            ),
          ),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: birthDate == null
                ? Theme.of(context).hintColor
                : Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ),
    );
  }
}
