import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:khidma/app.dart';
import 'package:khidma/core/l10n/locale_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Pumps the full app with mock preferences and returns its container.
Future<ProviderContainer> pumpApp(
  WidgetTester tester, {
  Map<String, Object> prefs = const {},
}) async {
  SharedPreferences.setMockInitialValues(prefs);
  final sp = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [sharedPreferencesProvider.overrideWithValue(sp)],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: const KhidmaApp()),
  );
  await tester.pumpAndSettle();
  return container;
}

/// Direction of the visible screen.
TextDirection screenDirection(WidgetTester tester) =>
    Directionality.of(tester.element(find.byType(Scaffold).first));
