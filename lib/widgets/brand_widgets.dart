import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/settings.dart';
import '../core/theme.dart';

/// White (surface) card wrapped in a bright #2EACEB gradient border — mirrors
/// the web-admin login look.
class BrandBorderCard extends StatelessWidget {
  final Widget child;
  const BrandBorderCard({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        gradient: kBrandGradient,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: kBrand.withValues(alpha: 0.25),
            blurRadius: 30,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(25),
        ),
        child: child,
      ),
    );
  }
}

/// White (surface) card with a #2EACEB gradient layer that peeks out at the
/// top + upper sides and fades away around the vertical center — mirrors the
/// web-admin login card.
class BrandLayeredCard extends StatelessWidget {
  final Widget child;
  const BrandLayeredCard({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final surface = Theme.of(context).colorScheme.surface;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Gradient back layer: top half only, peeking above + on the sides.
        Positioned(
          top: -12,
          left: -8,
          right: -8,
          bottom: 0,
          child: Align(
            alignment: Alignment.topCenter,
            child: FractionallySizedBox(
              heightFactor: 0.5,
              widthFactor: 1,
              child: Container(
                decoration: BoxDecoration(
                  gradient: kBrandGradient,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: kBrand.withValues(alpha: 0.28),
                      blurRadius: 26,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        // White (surface) card on top — no border, shadow only.
        Container(
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(26),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: child,
        ),
      ],
    );
  }
}

/// Full-width gradient button with a loading state.
class GradientButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  const GradientButton({
    super.key,
    required this.label,
    this.onPressed,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;
    return Opacity(
      opacity: enabled ? 1 : 0.6,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: enabled ? onPressed : null,
          child: Container(
            height: 52,
            decoration: BoxDecoration(
              gradient: kBrandGradient,
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: loading
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      valueColor: AlwaysStoppedAnimation(Colors.white),
                    ),
                  )
                : Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

/// Brand square logo tile with initials.
class BrandLogo extends StatelessWidget {
  final double size;
  const BrandLogo({super.key, this.size = 56});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: size,
      width: size,
      decoration: BoxDecoration(
        gradient: kBrandGradient,
        borderRadius: BorderRadius.circular(size * 0.28),
      ),
      alignment: Alignment.center,
      child: Text(
        'HR',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: size * 0.34,
        ),
      ),
    );
  }
}

/// The wordmark that sits UNDER the logo image:
///
///     HR MANAGEMENT
///   — PEOPLE. CULTURE. SUCCESS. —
///
/// Written as text (the logo image itself is untouched). The navy reads well on
/// white but vanishes on a dark background, so the colours flip in dark mode.
class BrandWordmark extends StatelessWidget {
  /// Scales the whole wordmark (1 = default, e.g. 0.85 for tighter spots).
  final double scale;
  const BrandWordmark({super.key, this.scale = 1});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final hrColor = dark ? const Color(0xFFEAF2FB) : const Color(0xFF16264A);
    final mgColor = dark ? const Color(0xFF9DBBDD) : const Color(0xFF2E5C8A);
    final tagColor = dark ? const Color(0xFF6FB6E8) : const Color(0xFF2E6DA4);
    final ruleColor = tagColor.withValues(alpha: 0.45);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // "HR" heavy + dark, "MANAGEMENT" lighter — as on the brand sheet.
        Text.rich(
          TextSpan(children: [
            TextSpan(
              text: 'HR',
              style: TextStyle(
                color: hrColor,
                fontWeight: FontWeight.w800,
                fontSize: 26 * scale,
                letterSpacing: 0.5,
              ),
            ),
            TextSpan(
              text: ' MANAGEMENT',
              style: TextStyle(
                color: mgColor,
                fontWeight: FontWeight.w500,
                fontSize: 26 * scale,
                letterSpacing: 0.5,
              ),
            ),
          ]),
        ),
        SizedBox(height: 7 * scale),
        // Tagline flanked by short rules.
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 20 * scale, height: 1, color: ruleColor),
            SizedBox(width: 8 * scale),
            Text(
              'PEOPLE. CULTURE. SUCCESS.',
              style: TextStyle(
                color: tagColor,
                fontSize: 9 * scale,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.5 * scale,
              ),
            ),
            SizedBox(width: 8 * scale),
            Container(width: 20 * scale, height: 1, color: ruleColor),
          ],
        ),
      ],
    );
  }
}

/// Language (LO/EN) + dark-mode toggles, used on the auth screen.
class TopToggles extends ConsumerWidget {
  const TopToggles({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(localeProvider);
    final isDark = ref.watch(themeModeProvider) == ThemeMode.dark;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _pill(
          context,
          children: [
            _langBtn(context, ref, 'lo', 'ລາວ', lang == 'lo'),
            _langBtn(context, ref, 'en', 'EN', lang == 'en'),
          ],
        ),
        const SizedBox(width: 8),
        IconButton(
          onPressed: () => ref.read(themeModeProvider.notifier).toggle(),
          icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode_outlined),
          style: IconButton.styleFrom(
            side: BorderSide(color: Theme.of(context).dividerColor),
          ),
        ),
      ],
    );
  }

  Widget _pill(BuildContext context, {required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: children),
    );
  }

  Widget _langBtn(
    BuildContext context,
    WidgetRef ref,
    String code,
    String label,
    bool active,
  ) {
    return GestureDetector(
      onTap: () => ref.read(localeProvider.notifier).set(code),
      child: Container(
        width: 44,
        padding: const EdgeInsets.symmetric(vertical: 5),
        decoration: BoxDecoration(
          gradient: active ? kBrandGradient : null,
          borderRadius: BorderRadius.circular(999),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: active
                ? Colors.white
                : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
      ),
    );
  }
}
