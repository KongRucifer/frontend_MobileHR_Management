import 'package:flutter/material.dart';
import '../../core/theme.dart';

/// Slide-to-confirm: the user must DRAG the knob all the way to the right to
/// trigger the action. Releasing before the end snaps it back. The track is
/// grey; a blue fill + knob follow the finger.
class SlideAction extends StatefulWidget {
  final String label;
  final Future<void> Function() onActivate;
  final bool enabled;

  const SlideAction({
    super.key,
    required this.label,
    required this.onActivate,
    this.enabled = true,
  });

  @override
  State<SlideAction> createState() => _SlideActionState();
}

class _SlideActionState extends State<SlideAction> {
  static const double _h = 64, _knob = 52, _pad = 6;

  double _pos = _pad; // left offset of the knob
  double _maxLeft = 0;
  bool _dragging = false;
  bool _busy = false;

  void _onUpdate(DragUpdateDetails d) {
    if (!widget.enabled || _busy) return;
    setState(() {
      _dragging = true;
      _pos = (_pos + d.delta.dx).clamp(_pad, _maxLeft);
    });
  }

  Future<void> _onEnd(DragEndDetails _) async {
    if (!widget.enabled || _busy) return;
    _dragging = false;
    // Reached (near) the end -> confirm; otherwise snap back.
    if (_pos >= _maxLeft - 4 || _pos >= _maxLeft * 0.9) {
      setState(() {
        _pos = _maxLeft;
        _busy = true;
      });
      try {
        await widget.onActivate();
      } finally {
        if (mounted) {
          setState(() {
            _busy = false;
            _pos = _pad; // reset for the next action
          });
        }
      }
    } else {
      setState(() => _pos = _pad);
    }
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.enabled;
    final trackColor = Theme.of(context).colorScheme.onSurface.withValues(
          alpha: 0.10,
        );

    return LayoutBuilder(
      builder: (context, c) {
        _maxLeft = c.maxWidth - _knob - _pad;
        // Once the blue fill reaches the centre, the label turns white.
        final coveredCenter = (_pos + _knob) >= c.maxWidth / 2;
        return GestureDetector(
          onHorizontalDragUpdate: enabled ? _onUpdate : null,
          onHorizontalDragEnd: enabled ? _onEnd : null,
          child: Container(
            height: _h,
            decoration: BoxDecoration(
              color: trackColor,
              borderRadius: BorderRadius.circular(_h / 2),
            ),
            child: Stack(
              children: [
                // Blue fill growing behind the icon as you drag.
                if (enabled)
                  AnimatedPositioned(
                    duration: _dragging
                        ? Duration.zero
                        : const Duration(milliseconds: 260),
                    curve: Curves.easeOut,
                    left: 0,
                    top: 0,
                    bottom: 0,
                    width: _pos + _knob,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: kBrandGradient,
                        borderRadius: BorderRadius.circular(_h / 2),
                      ),
                    ),
                  ),
                // Label: fixed at the centre; turns white once the fill covers it.
                Center(
                  child: Text(
                    widget.label,
                    style: TextStyle(
                      color: coveredCenter
                          ? Colors.white
                          : Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.55),
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                // Knob: a blue circle the same size as the icon.
                AnimatedPositioned(
                  duration:
                      _dragging ? Duration.zero : const Duration(milliseconds: 260),
                  curve: Curves.easeOut,
                  left: enabled ? _pos : _pad,
                  top: _pad,
                  child: Container(
                    width: _knob,
                    height: _knob,
                    decoration: BoxDecoration(
                      gradient: enabled ? kBrandGradient : null,
                      color: enabled ? null : Colors.grey.shade400,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: kBrand.withValues(alpha: 0.35),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: _busy
                        ? const Padding(
                            padding: EdgeInsets.all(15),
                            child: CircularProgressIndicator(
                              strokeWidth: 2.4,
                              valueColor: AlwaysStoppedAnimation(Colors.white),
                            ),
                          )
                        : Icon(
                            enabled ? Icons.keyboard_double_arrow_right : Icons.check,
                            color: Colors.white,
                          ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
