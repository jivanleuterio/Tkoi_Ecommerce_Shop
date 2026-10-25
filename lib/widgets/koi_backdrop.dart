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

  const TkoiBrandMark({super.key, this.size = 64});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Image.asset(
        'assets/images/tkoi_logo.png',
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
        semanticLabel: 'Tkoi koi logo',
      ),
    );
  }
}

class TkoiWordmark extends StatelessWidget {
  final double height;
  final bool light;

  const TkoiWordmark({super.key, this.height = 46, this.light = false});

  @override
  Widget build(BuildContext context) {
    final darkColor = light ? Colors.white : AppColors.sumi;
    final accentColor = light ? AppColors.gold : AppColors.koiOrange;
    final waterColor = light ? AppColors.aqua : AppColors.pondBlue;

    return Semantics(
      label: 'Tkoi',
      image: true,
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            TkoiBrandMark(size: height),
            SizedBox(width: height * .02),
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: 'k',
                    style: TextStyle(color: darkColor),
                  ),
                  TextSpan(
                    text: 'o',
                    style: TextStyle(color: accentColor),
                  ),
                  TextSpan(
                    text: 'i',
                    style: TextStyle(color: waterColor),
                  ),
                ],
              ),
              maxLines: 1,
              style: TextStyle(
                fontSize: height * .72,
                height: 1,
                fontWeight: FontWeight.w900,
                letterSpacing: -height * .055,
              ),
            ),
          ],
        ),
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
