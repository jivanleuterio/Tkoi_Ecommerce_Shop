import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class KoiBackdrop extends StatelessWidget {
  final Widget child;
  final bool dark;

  const KoiBackdrop({super.key, required this.child, this.dark = false});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: dark ? AppColors.waterGradient : AppColors.creamGradient,
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            right: -70,
            top: -45,
            child: _Spot(
              size: 210,
              color: AppColors.koiOrange.withValues(alpha: dark ? .22 : .12),
            ),
          ),
          Positioned(
            left: -80,
            bottom: 60,
            child: _Spot(
              size: 190,
              color: AppColors.aqua.withValues(alpha: dark ? .14 : .11),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class _Spot extends StatelessWidget {
  final double size;
  final Color color;

  const _Spot({required this.size, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );
}

class TkoiBrandMark extends StatelessWidget {
  final double size;
  final bool light;

  const TkoiBrandMark({super.key, this.size = 64, this.light = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: AppColors.koiGradient,
        shape: BoxShape.circle,
        boxShadow: AppColors.softShadow,
        border: Border.all(
          color: light ? Colors.white.withValues(alpha: .5) : Colors.white,
          width: 3,
        ),
      ),
      child: Icon(
        Icons.set_meal_rounded,
        color: Colors.white,
        size: size * .55,
      ),
    );
  }
}

class TkoiSectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? action;

  const TkoiSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
              ],
            ],
          ),
        ),
        ?action,
      ],
    );
  }
}

class TkoiFormCard extends StatelessWidget {
  final Widget child;

  const TkoiFormCard({super.key, required this.child});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(AppSpacing.lg),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(AppRadii.large),
      boxShadow: AppColors.softShadow,
    ),
    child: child,
  );
}
