import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class SellerSalesPoint {
  final String label;
  final int revenueCentavos;
  final int orderCount;

  const SellerSalesPoint({
    required this.label,
    required this.revenueCentavos,
    required this.orderCount,
  });
}

class SellerSalesChart extends StatelessWidget {
  final List<SellerSalesPoint> points;

  const SellerSalesChart({super.key, required this.points});

  @override
  Widget build(BuildContext context) {
    final maxRevenue = points.fold<int>(
      0,
      (value, point) => math.max(value, point.revenueCentavos),
    );
    return Semantics(
      label: 'Sales chart for ${points.length} days',
      child: SizedBox(
        height: 170,
        child: CustomPaint(
          painter: _SalesPainter(points: points, maxRevenue: maxRevenue),
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var index = 0; index < points.length; index++)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 142),
                      child: Text(
                        points.length <= 7 ||
                                index == 0 ||
                                index == points.length - 1 ||
                                index % 5 == 0
                            ? points[index].label
                            : '',
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SalesPainter extends CustomPainter {
  final List<SellerSalesPoint> points;
  final int maxRevenue;

  const _SalesPainter({required this.points, required this.maxRevenue});

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;
    final baseline = size.height - 30;
    final chartHeight = baseline - 12;
    final slot = size.width / points.length;
    final barWidth = math.min(22.0, slot * .55);
    final grid = Paint()
      ..color = AppColors.softGray.withValues(alpha: .14)
      ..strokeWidth = 1;
    for (var index = 0; index <= 3; index++) {
      final y = 12 + (chartHeight * index / 3);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    final barPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: [AppColors.pondBlue, AppColors.aqua],
      ).createShader(Rect.fromLTWH(0, 12, size.width, chartHeight));
    final orderPaint = Paint()..color = AppColors.koiOrange;
    final maxOrders = points.fold<int>(
      0,
      (value, point) => math.max(value, point.orderCount),
    );
    for (var index = 0; index < points.length; index++) {
      final point = points[index];
      final ratio = maxRevenue == 0 ? 0.0 : point.revenueCentavos / maxRevenue;
      final height = chartHeight * ratio;
      final center = slot * index + slot / 2;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            center - barWidth / 2,
            baseline - height,
            barWidth,
            height,
          ),
          const Radius.circular(8),
        ),
        barPaint,
      );
      if (point.orderCount > 0) {
        final orderRatio = maxOrders == 0 ? 0.0 : point.orderCount / maxOrders;
        canvas.drawCircle(
          Offset(center, baseline - chartHeight * orderRatio),
          4,
          orderPaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SalesPainter oldDelegate) =>
      oldDelegate.points != points || oldDelegate.maxRevenue != maxRevenue;
}
