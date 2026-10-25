import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../utils/formatters.dart';

class ErrorView extends StatelessWidget {
  final Object error;
  final VoidCallback? onRetry;

  const ErrorView({super.key, required this.error, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact =
            constraints.hasBoundedHeight && constraints.maxHeight < 300;
        final content = Padding(
          padding: EdgeInsets.all(compact ? 12 : 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: compact ? 64 : 88,
                height: compact ? 64 : 88,
                decoration: BoxDecoration(
                  color: AppColors.vermilion.withValues(alpha: .09),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.cloud_off_rounded,
                  size: compact ? 32 : 42,
                  color: AppColors.vermilion,
                ),
              ),
              SizedBox(height: compact ? 10 : 16),
              Text(
                'Something went off course',
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              SizedBox(height: compact ? 4 : 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 360),
                child: Text(
                  friendlyError(error),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.softGray),
                ),
              ),
              if (onRetry != null) ...[
                SizedBox(height: compact ? 10 : 16),
                OutlinedButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Try again'),
                ),
              ],
            ],
          ),
        );
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
