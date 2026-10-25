import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tkoi_shop/widgets/empty_state.dart';

void main() {
  testWidgets('compact empty state does not overflow with large text', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: const Align(
              alignment: Alignment.topCenter,
              child: SizedBox(
                height: 180,
                width: 360,
                child: EmptyState(
                  icon: Icons.history_rounded,
                  title: 'No withdrawals yet',
                  message: 'Your requests and their status will appear here.',
                ),
              ),
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('No withdrawals yet'), findsOneWidget);
  });
}
