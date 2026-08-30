import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:customer/core/theme/app_theme.dart';
import 'package:customer/features/merchants/presentation/category_chip.dart';

void main() {
  testWidgets('invokes onTap when tapped', (tester) async {
    var tapped = false;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(body: CategoryChip(label: 'Bakery', selected: false, onTap: () => tapped = true)),
      ),
    );
    await tester.tap(find.byType(CategoryChip));

    expect(tapped, isTrue);
  });

  testWidgets('shows a check icon only when selected', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(body: CategoryChip(label: 'Bakery', selected: true, onTap: () {})),
      ),
    );

    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
  });

  testWidgets('does not show a check icon when not selected', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(body: CategoryChip(label: 'Bakery', selected: false, onTap: () {})),
      ),
    );

    expect(find.byIcon(Icons.check_rounded), findsNothing);
  });
}
