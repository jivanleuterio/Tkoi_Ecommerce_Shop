import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact =
            constraints.hasBoundedHeight && constraints.maxHeight < 300;
        final iconSize = compact ? 68.0 : 92.0;
        final content = Padding(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 16 : 32,
            vertical: compact ? 12 : 32,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: iconSize,
                height: iconSize,
                decoration: const BoxDecoration(
                  gradient: AppColors.waterGradient,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: compact ? 34 : 44, color: Colors.white),
              ),
              SizedBox(height: compact ? 12 : 20),
              Text(
                title,
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              SizedBox(height: compact ? 4 : 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 340),
                child: Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.softGray),
                ),
              ),
              if (action != null) ...[
                SizedBox(height: compact ? 12 : 20),
                action!,
              ],
            ],
          ),
        );

        // Full-page and fixed-height parents can become shorter on small
        // phones or with large accessibility text. Allow only the empty state
        // to scroll instead of showing a RenderFlex overflow stripe.
        return Center(
          child: constraints.hasBoundedHeight
              ? SingleChildScrollView(
                  primary: false,
                  physics: const ClampingScrollPhysics(),
                  child: content,
                )
              : content,
        );
      },
    );
  }
}
