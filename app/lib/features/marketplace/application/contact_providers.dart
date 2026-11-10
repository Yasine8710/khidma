import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../auth/application/auth_providers.dart';
import '../domain/marketplace_domain.dart';
import 'marketplace_providers.dart';

/// Opens a link in another app (phone dialer, WhatsApp). Returns false when
/// nothing could handle it. Replaced in tests.
final urlOpenerProvider = Provider<Future<bool> Function(Uri)>(
  (ref) =>
      (uri) => launchUrl(uri, mode: LaunchMode.externalApplication),
);

sealed class ContactState {
  const ContactState();
}

class ContactHidden extends ContactState {
  const ContactHidden();
}

class ContactLoading extends ContactState {
  const ContactLoading();
}

class ContactRevealed extends ContactState {
  const ContactRevealed(this.phone);
  final String phone;
}

class ContactFailed extends ContactState {
  const ContactFailed(this.failure);
  final MarketplaceFailure failure;
}

/// The revealed number of one professional. Kept only while the profile screen
/// is open (auto-disposed): a number is never cached beyond the visit.
final contactProvider = NotifierProvider.autoDispose
    .family<ContactController, ContactState, String>(ContactController.new);

class ContactController extends Notifier<ContactState> {
  ContactController(this.professionalId);
  final String professionalId;

  /// The account the number was asked for. A different account (or none)
  /// starts again from hidden, and an answer for the old one is dropped.
  String? _account() => ref.read(currentUserProvider)?.id;

  @override
  ContactState build() {
    ref.watch(currentUserProvider.select((u) => u?.id));
    return const ContactHidden();
  }

  Future<void> reveal() async {
    if (state is ContactLoading) return;
    final account = _account();
    state = const ContactLoading();
    ContactState result;
    try {
      final phone = await ref
          .read(marketplaceRepositoryProvider)
          .revealContact(professionalId);
      result = ContactRevealed(phone);
    } on MarketplaceError catch (e) {
      result = ContactFailed(e.failure);
    } catch (_) {
      result = const ContactFailed(MarketplaceFailure.unknown);
    }
    // Left the screen, or signed out / switched account meanwhile.
    if (!ref.mounted || _account() != account) return;
    state = result;
  }
}
