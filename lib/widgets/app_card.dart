import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/app_colors.dart';

class AppCard extends StatefulWidget {
  const AppCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(16),
    this.radius = 20,
    this.floating = false,
    this.color,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final double radius;
  final bool floating;
  final Color? color;

  @override
  State<AppCard> createState() => _AppCardState();
}

class _AppCardState extends State<AppCard> {
  var _pressed = false;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: widget.onTap == null
          ? null
          : (_) => setState(() => _pressed = true),
      onTapCancel: widget.onTap == null
          ? null
          : () => setState(() => _pressed = false),
      onTapUp: widget.onTap == null
          ? null
          : (_) {
              setState(() => _pressed = false);
              HapticFeedback.selectionClick();
              widget.onTap?.call();
            },
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1,
        duration: const Duration(milliseconds: 110),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: widget.padding,
          decoration: BoxDecoration(
            color: widget.color ?? Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(widget.radius),
            border: Border.all(
              color: dark
                  ? Colors.white.withValues(alpha: 0.08)
                  : AppColors.border.withValues(alpha: 0.7),
            ),
            boxShadow: widget.floating || _pressed
                ? (dark ? const <BoxShadow>[] : AppColors.floatingShadow)
                : (dark ? const <BoxShadow>[] : AppColors.softShadow),
          ),
          child: widget.child,
        ),
      ),
    );
  }
}
