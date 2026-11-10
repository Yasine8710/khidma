import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/locale_controller.dart';

const _prefsKey = 'onboardingSeen';

final onboardingSeenProvider = NotifierProvider<OnboardingController, bool>(
  OnboardingController.new,
);

/// Whether the user has finished (or skipped) onboarding. Stored locally;
/// a failed write only means onboarding shows again next launch.
class OnboardingController extends Notifier<bool> {
  @override
  bool build() =>
      ref.read(sharedPreferencesProvider).getBool(_prefsKey) ?? false;

  Future<bool> complete() async {
    state = true;
    try {
      return await ref.read(sharedPreferencesProvider).setBool(_prefsKey, true);
    } catch (_) {
      return false;
    }
  }
}
