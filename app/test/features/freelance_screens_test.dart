
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:khidma/features/auth/application/auth_providers.dart';
import 'package:khidma/features/auth/domain/auth_domain.dart';
import 'package:khidma/features/freelance/application/freelance_providers.dart';
import 'package:khidma/features/freelance/domain/freelance_domain.dart';
import 'package:khidma/features/freelance/presentation/digital_screen.dart';
import 'package:khidma/features/freelance/presentation/freelance_manage_screen.dart';
import 'package:khidma/features/freelance/presentation/freelancer_screen.dart';
import 'package:khidma/features/marketplace/application/contact_providers.dart';
import 'package:khidma/features/marketplace/domain/marketplace_domain.dart';
import 'package:khidma/features/portfolio/application/portfolio_providers.dart';
import 'package:khidma/features/portfolio/domain/portfolio_domain.dart';
import 'package:khidma/shared/widgets/app_button.dart';
import 'package:khidma/shared/widgets/app_chip.dart';

import '../support/fake_auth_repository.dart';
import '../support/fake_freelance.dart';
import '../support/fake_portfolio.dart';
import '../test_helpers.dart';

const _ali = AuthUser(id: 'u1', email: 'ali@example.tn');

const _amine = FreelancerSummary(
  id: 'f1',
  name: 'Amine Test',
  headline: 'Développeur web React',
  categoryId: 1,
  bio: 'Je construis des sites et des applications web.',
  skills: ['React', 'Node.js'],
  languages: ['Français', 'Arabe'],
  yearsExperience: 6,
  startingPriceMillimes: 300000,
  priceUnit: PriceUnit.project,
  verification: Verification.verified,
  rating: 4.5,
  reviewCount: 2,
);

const _salma = FreelancerSummary(
  id: 'f2',
  name: 'Salma Design',
  headline: 'Designer UI/UX',
  categoryId: 3,
  startingPriceMillimes: 40000,
  priceUnit: PriceUnit.hour,
  verification: Verification.verified,
);

const _verifiedMe = MyFreelancer(
  name: 'Amine Test',
  headline: 'Développeur web React',
  bio: 'Je construis des sites et des applications web.',
  categoryId: 1,
  verification: Verification.verified,
);

final _token = 'ab' * 32;

Future<List<(MethodCall, Object?)>> _hostClipboard(WidgetTester tester) async {
  final calls = <(MethodCall, Object?)>[];
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (call) async {
      calls.add((call, call.arguments));
      return null;
    },
  );
  addTearDown(
    () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    ),
  );
  return calls;
}

void main() {
  setUpAll(loadAppFonts);

  Future<void> host(
    WidgetTester tester,
    Widget screen, {
    required FakeFreelanceRepository repo,
    AuthUser? user = _ali,
    String lang = 'fr',
    Size size = const Size(800, 3000),
    double scale = 1,
    List<Override> overrides = const [],
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    tester.platformDispatcher.textScaleFactorTestValue = scale;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          freelanceRepositoryProvider.overrideWithValue(repo),
          authRepositoryProvider.overrideWithValue(
            FakeAuthRepository(signedIn: user),
          ),
          ...overrides,
        ],
        child: bareApp(screen, lang: lang),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('public list', () {
    testWidgets('shows freelancers as rows with price, stamp and category', (
      tester,
    ) async {
      final repo = FakeFreelanceRepository(freelancers: [_amine, _salma]);
      await host(tester, const DigitalScreen(), repo: repo);
      expect(find.text('Services digitaux'), findsOneWidget);
      expect(find.text('Amine Test'), findsOneWidget);
      expect(find.text('Développeur web React'), findsOneWidget);
      expect(find.text('à partir de 300 DT / projet'), findsOneWidget);
      expect(find.text('à partir de 40 DT / heure'), findsOneWidget);
      expect(find.text('Vérifié'), findsNWidgets(2));
      // The trade shows under the name (also a chip with the same label).
      expect(find.text('Développement web'), findsNWidgets(2));
      expect(find.text("Pas encore d'avis"), findsOneWidget);
    });

    testWidgets('a category chip filters, "Toutes" clears it', (tester) async {
      final repo = FakeFreelanceRepository(freelancers: [_amine, _salma]);
      await host(tester, const DigitalScreen(), repo: repo);
      await tester.tap(
        find.widgetWithText(AppChip, 'Design graphique et UI/UX'),
      );
      await tester.pumpAndSettle();
      expect(repo.queries.last.categoryId, 3);
      expect(find.text('Amine Test'), findsNothing);
      expect(find.text('Salma Design'), findsOneWidget);
      await tester.tap(find.widgetWithText(AppChip, 'Toutes'));
      await tester.pumpAndSettle();
      expect(repo.queries.last.categoryId, isNull);
      expect(find.text('Amine Test'), findsOneWidget);
    });

    testWidgets('typing searches after a short pause', (tester) async {
      final repo = FakeFreelanceRepository(freelancers: [_amine, _salma]);
      await host(tester, const DigitalScreen(), repo: repo);
      await tester.enterText(find.byType(TextField), 'salma');
      await tester.pump(const Duration(milliseconds: 100));
      expect(repo.queries.last.text, isNull, reason: 'still waiting');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(repo.queries.last.text, 'salma');
      expect(find.text('Amine Test'), findsNothing);
    });

    testWidgets('no result and failure are said plainly', (tester) async {
      final repo = FakeFreelanceRepository();
      await host(tester, const DigitalScreen(), repo: repo);
      expect(find.text('Aucun freelance trouvé'), findsOneWidget);

      final failing = FakeFreelanceRepository()
        ..failNext = FreelanceFailure.network;
      await host(tester, const DigitalScreen(), repo: failing);
      expect(
        find.text('Impossible de charger les freelances.'),
        findsOneWidget,
      );
      expect(find.text('Réessayer'), findsOneWidget);
    });
  });

  group('public page', () {
    FakeFreelanceRepository repo0() => FakeFreelanceRepository(
      freelancers: [_amine],
      items: const [
        FreelancePortfolioItem(
          id: 'p1',
          kind: PortfolioKind.image,
          title: 'Boutique en ligne',
          url: 'https://example.invalid/p1.jpg',
        ),
        FreelancePortfolioItem(
          id: 'p2',
          kind: PortfolioKind.videoLink,
          title: 'Présentation vidéo',
          url: 'https://youtu.be/dQw4w9WgXcQ',
        ),
        FreelancePortfolioItem(
          id: 'p3',
          kind: PortfolioKind.link,
          title: 'Site client',
          url: 'https://example.com/',
        ),
      ],
      testimonials: [
        const Testimonial(
          id: 't1',
          authorName: 'Sami K.',
          projectTitle: 'Site vitrine',
          rating: 5,
          body: 'Travail soigné et livré à temps.',
        ),
      ],
    );

    testWidgets('header, facts, skills, about', (tester) async {
      await host(tester, const FreelancerScreen(id: 'f1'), repo: repo0());
      expect(find.text('Amine Test'), findsOneWidget);
      expect(find.text('Développeur web React'), findsOneWidget);
      expect(find.text('Vérifié'), findsOneWidget);
      expect(find.text('Disponible'), findsOneWidget);
      expect(find.text('à partir de 300 DT / projet'), findsOneWidget);
      expect(find.text("6 ans d'expérience"), findsOneWidget);
      expect(find.text('Français, Arabe'), findsOneWidget);
      expect(find.text('React'), findsOneWidget);
      expect(find.text('Node.js'), findsOneWidget);
      expect(find.textContaining('Je construis des sites'), findsOneWidget);
    });

    testWidgets('testimonials are labelled and explained', (tester) async {
      await host(tester, const FreelancerScreen(id: 'f1'), repo: repo0());
      expect(find.text('TÉMOIGNAGE CLIENT'), findsOneWidget);
      expect(find.text('Témoignages clients'), findsOneWidget);
      expect(find.textContaining('invités par le freelance'), findsOneWidget);
      expect(find.textContaining('avis vérifiés'), findsOneWidget);
      expect(find.text('Travail soigné et livré à temps.'), findsOneWidget);
      expect(find.textContaining('Sami K.'), findsOneWidget);
      expect(find.text('Projet : Site vitrine'), findsOneWidget);
    });

    testWidgets('links open outside the app, photos open large', (
      tester,
    ) async {
      final opened = <Uri>[];
      await host(
        tester,
        const FreelancerScreen(id: 'f1'),
        repo: repo0(),
        overrides: [
          urlOpenerProvider.overrideWithValue((u) async {
            opened.add(u);
            return true;
          }),
        ],
      );
      await tester.tap(find.text('Présentation vidéo'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Site client'));
      await tester.pumpAndSettle();
      expect(opened, [
        Uri.parse('https://youtu.be/dQw4w9WgXcQ'),
        Uri.parse('https://example.com/'),
      ]);
      await tester.tap(find.text('Boutique en ligne'));
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsOneWidget);
      expect(opened.length, 2, reason: 'a photo is not opened outside');
      await tester.tap(find.byTooltip('Fermer'));
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsNothing);
    });

    testWidgets('an opener that fails says so', (tester) async {
      await host(
        tester,
        const FreelancerScreen(id: 'f1'),
        repo: repo0(),
        overrides: [urlOpenerProvider.overrideWithValue((u) async => false)],
      );
      await tester.tap(find.text('Site client'));
      await tester.pumpAndSettle();
      expect(find.text('Impossible d’ouvrir l’application.'), findsOneWidget);
    });

    testWidgets('contact is revealed only on request', (tester) async {
      final repo = repo0();
      await host(tester, const FreelancerScreen(id: 'f1'), repo: repo);
      expect(repo.reveals, 0);
      expect(find.text('20 123 456'), findsNothing);
      await tester.tap(find.text('Afficher le contact'));
      await tester.pumpAndSettle();
      expect(repo.reveals, 1);
      expect(find.textContaining('20 123 456'), findsOneWidget);
      expect(find.text('Appeler'), findsOneWidget);
    });

    testWidgets('signed out: asked to sign in, nothing revealed', (
      tester,
    ) async {
      final repo = repo0();
      await host(
        tester,
        const FreelancerScreen(id: 'f1'),
        repo: repo,
        user: null,
      );
      expect(find.text('Connectez-vous pour voir le contact'), findsOneWidget);
      expect(find.text('Afficher le contact'), findsNothing);
      expect(repo.reveals, 0);
    });

    testWidgets('a rate limit is explained', (tester) async {
      final repo = repo0()..failNext = null;
      await host(tester, const FreelancerScreen(id: 'f1'), repo: repo);
      repo.failNext = FreelanceFailure.rateLimited;
      await tester.tap(find.text('Afficher le contact'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Trop de numéros'), findsOneWidget);
    });

    testWidgets('report buttons exist for the page and each testimonial', (
      tester,
    ) async {
      await host(tester, const FreelancerScreen(id: 'f1'), repo: repo0());
      expect(find.byTooltip('Signaler'), findsNWidgets(2));
    });

    testWidgets('an unknown freelancer shows not found', (tester) async {
      await host(
        tester,
        const FreelancerScreen(id: 'nope'),
        repo: FakeFreelanceRepository(),
      );
      expect(find.text('Freelance introuvable'), findsOneWidget);
    });
  });

  group('owner screen', () {
    testWidgets('not a freelancer yet: explains and offers to become one', (
      tester,
    ) async {
      final repo = FakeFreelanceRepository();
      await host(tester, const FreelanceManageScreen(), repo: repo);
      expect(find.text('Proposez vos services digitaux'), findsOneWidget);
      await tester.tap(find.text('Devenir freelance'));
      await tester.pumpAndSettle();
      expect(repo.becomeCalls, 1);
      expect(find.text('Ma page'), findsOneWidget);
    });

    testWidgets('not verified: cannot publish, and is told why', (
      tester,
    ) async {
      final repo = FakeFreelanceRepository(me: const MyFreelancer());
      await host(tester, const FreelanceManageScreen(), repo: repo);
      final tile = tester.widget<SwitchListTile>(find.byType(SwitchListTile));
      expect(tile.onChanged, isNull);
      expect(tile.value, isFalse);
      expect(find.textContaining('bloquée'), findsOneWidget);
      expect(find.text('Identité pas encore vérifiée.'), findsOneWidget);
      expect(find.text('Faire vérifier mon profil'), findsOneWidget);
      await tester.tap(find.byType(SwitchListTile), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(repo.publishCalls, isEmpty);
    });

    testWidgets('verified: publishing saves the page first, then publishes', (
      tester,
    ) async {
      final repo = FakeFreelanceRepository(me: _verifiedMe);
      await host(tester, const FreelanceManageScreen(), repo: repo);
      expect(find.text('Vérifié'), findsOneWidget);
      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();
      expect(repo.saved, hasLength(1));
      expect(repo.publishCalls, [true]);
      expect(
        tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
        isTrue,
      );
    });

    testWidgets('the form checks lengths before saving', (tester) async {
      final repo = FakeFreelanceRepository(me: _verifiedMe);
      await host(tester, const FreelanceManageScreen(), repo: repo);
      await tester.enterText(find.byType(TextField).at(0), 'A');
      await tester.tap(find.text('Enregistrer'));
      await tester.pumpAndSettle();
      expect(find.text('2 à 80 caractères.'), findsOneWidget);
      expect(repo.saved, isEmpty);
    });

    testWidgets('saving sends skills and price in the right shape', (
      tester,
    ) async {
      final repo = FakeFreelanceRepository(me: _verifiedMe);
      await host(tester, const FreelanceManageScreen(), repo: repo);
      final fields = find.byType(TextField);
      // name, headline, bio, skills, languages, years, price
      await tester.enterText(fields.at(3), 'React, Figma, react');
      await tester.enterText(fields.at(5), '4');
      await tester.enterText(fields.at(6), '250,5');
      await tester.tap(find.text('Enregistrer'));
      await tester.pumpAndSettle();
      final s = repo.saved.single;
      expect(s.skills, ['React', 'Figma']);
      expect(s.yearsExperience, 4);
      expect(s.startingPriceMillimes, 250500);
      expect(find.text('Page enregistrée.'), findsOneWidget);
    });

    testWidgets('a refused publication is explained', (tester) async {
      final repo = FakeFreelanceRepository(me: _verifiedMe);
      await host(tester, const FreelanceManageScreen(), repo: repo);
      repo.failNext = FreelanceFailure.incomplete;
      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('numéro de téléphone de contact'),
        findsOneWidget,
      );
      expect(
        tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
        isFalse,
      );
    });

    testWidgets('add a link: invalid addresses are refused on the spot', (
      tester,
    ) async {
      final repo = FakeFreelanceRepository(me: _verifiedMe);
      await host(tester, const FreelanceManageScreen(), repo: repo);
      await tester.tap(find.text('Ajouter une vidéo en ligne'));
      await tester.pumpAndSettle();
      final sheet = find.descendant(
        of: find.byType(BottomSheet),
        matching: find.byType(TextField),
      );
      await tester.enterText(sheet.at(0), 'Ma démo');
      await tester.enterText(sheet.at(2), 'https://evil.com/x');
      await tester.tap(
        find.descendant(
          of: find.byType(BottomSheet),
          matching: find.text('Ajouter'),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Lien https YouTube ou Vimeo uniquement.'),
        findsOneWidget,
      );
      expect(repo.links, isEmpty);
      await tester.enterText(sheet.at(2), 'https://youtu.be/dQw4w9WgXcQ');
      await tester.tap(
        find.descendant(
          of: find.byType(BottomSheet),
          matching: find.text('Ajouter'),
        ),
      );
      await tester.pumpAndSettle();
      expect(repo.links.single.kind, PortfolioKind.videoLink);
      expect(repo.links.single.title, 'Ma démo');
      expect(find.text('Ma démo'), findsOneWidget);
      expect(find.text('1 sur 24 réalisations'), findsOneWidget);
    });

    testWidgets(
      'add a photo: title first, then the picker, then it is listed',
      (tester) async {
        final repo = FakeFreelanceRepository(me: _verifiedMe);
        final picker = FakePhotoPicker(Uint8List.fromList([1, 2, 3]));
        await host(
          tester,
          const FreelanceManageScreen(),
          repo: repo,
          overrides: [
            photoPickerProvider.overrideWithValue(picker),
            photoPreparerProvider.overrideWithValue(
              (b) async => PreparedPhoto(bytes: b, width: 1, height: 1),
            ),
          ],
        );
        await tester.tap(find.text('Ajouter une photo'));
        await tester.pumpAndSettle();
        // Title too short: nothing is picked.
        await tester.tap(find.text('Choisir le fichier'));
        await tester.pumpAndSettle();
        expect(picker.picks, 0);
        expect(find.text('2 à 100 caractères.'), findsOneWidget);
        await tester.enterText(
          find
              .descendant(
                of: find.byType(BottomSheet),
                matching: find.byType(TextField),
              )
              .first,
          'Maquette',
        );
        await tester.tap(find.text('Choisir le fichier'));
        await tester.pumpAndSettle();
        expect(picker.picks, 1);
        expect(repo.photos.single.$2, 'Maquette');
        expect(find.text('Maquette'), findsOneWidget);
      },
    );

    testWidgets('a clip in the wrong format says so', (tester) async {
      final repo = FakeFreelanceRepository(me: _verifiedMe);
      final clips = FakeClipPicker()..fail = FreelanceFailure.unsupportedFormat;
      await host(
        tester,
        const FreelanceManageScreen(),
        repo: repo,
        overrides: [clipPickerProvider.overrideWithValue(clips)],
      );
      await tester.tap(find.textContaining('Ajouter un clip'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find
            .descendant(
              of: find.byType(BottomSheet),
              matching: find.byType(TextField),
            )
            .first,
        'Mon clip',
      );
      await tester.tap(find.text('Choisir le fichier'));
      await tester.pumpAndSettle();
      expect(find.textContaining('mp4 ou webm'), findsOneWidget);
      expect(repo.clips, isEmpty);
    });

    testWidgets('the 24 item limit is shown and add is disabled', (
      tester,
    ) async {
      final repo = FakeFreelanceRepository(
        me: _verifiedMe,
        items: [
          for (var i = 0; i < 24; i++)
            FreelancePortfolioItem(
              id: 'i$i',
              kind: PortfolioKind.link,
              title: 'Lien $i',
              url: 'https://example.com/$i',
            ),
        ],
      );
      await host(
        tester,
        const FreelanceManageScreen(),
        repo: repo,
        size: const Size(800, 6000),
      );
      expect(find.text('24 sur 24 réalisations'), findsOneWidget);
      expect(find.text('Limite de 24 réalisations atteinte.'), findsOneWidget);
      final add = tester.widget<AppButton>(
        find.widgetWithText(AppButton, 'Ajouter un lien'),
      );
      expect(add.onPressed, isNull);
    });

    testWidgets('edit and delete an item', (tester) async {
      final repo = FakeFreelanceRepository(
        me: _verifiedMe,
        items: const [
          FreelancePortfolioItem(
            id: 'i1',
            kind: PortfolioKind.link,
            title: 'Ancien titre',
            url: 'https://example.com/',
          ),
        ],
      );
      await host(tester, const FreelanceManageScreen(), repo: repo);
      await tester.tap(find.byTooltip('Modifier: Ancien titre'));
      await tester.pumpAndSettle();
      final title = find
          .descendant(
            of: find.byType(BottomSheet),
            matching: find.byType(TextField),
          )
          .first;
      await tester.enterText(title, 'Nouveau titre');
      await tester.tap(
        find.descendant(
          of: find.byType(BottomSheet),
          matching: find.text('Enregistrer'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Nouveau titre'), findsOneWidget);
      await tester.tap(find.byTooltip('Supprimer: Nouveau titre'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Supprimer'),
        ),
      );
      await tester.pumpAndSettle();
      expect(repo.removed, ['i1']);
      expect(find.text('Aucune réalisation pour le moment.'), findsOneWidget);
    });

    testWidgets('invite creation shows the link once, with copy and share', (
      tester,
    ) async {
      final clip = await _hostClipboard(tester);
      final opened = <Uri>[];
      final repo = FakeFreelanceRepository(me: _verifiedMe);
      await host(
        tester,
        const FreelanceManageScreen(),
        repo: repo,
        size: const Size(800, 4000),
        overrides: [
          testimonialBaseUrlProvider.overrideWithValue('https://t.example.tn'),
          urlOpenerProvider.overrideWithValue((u) async {
            opened.add(u);
            return true;
          }),
        ],
      );
      expect(find.text('Aucune invitation pour le moment.'), findsOneWidget);
      await tester.enterText(
        find
            .descendant(
              of: find.widgetWithText(Column, 'Invitations de témoignage'),
              matching: find.byType(TextField),
            )
            .first,
        'Sami',
      );
      await tester.tap(find.text('Créer un lien d’invitation'));
      await tester.pumpAndSettle();
      expect(find.text('https://t.example.tn/t/$_token'), findsOneWidget);
      expect(find.text('Sami'), findsOneWidget, reason: 'listed by its label');
      expect(find.textContaining('En attente'), findsOneWidget);

      await tester.tap(find.text('Copier le lien'));
      await tester.pumpAndSettle();
      final set = clip.where((c) => c.$1.method == 'Clipboard.setData');
      expect(
        set.single.$2.toString(),
        contains('https://t.example.tn/t/$_token'),
      );
      expect(find.text('Lien copié.'), findsOneWidget);

      await tester.tap(find.text('Partager par WhatsApp'));
      await tester.pumpAndSettle();
      expect(opened.single.host, 'wa.me');
      expect(opened.single.queryParameters['text'], contains('/t/$_token'));
    });

    testWidgets('without a configured address, no link is made', (
      tester,
    ) async {
      final repo = FakeFreelanceRepository(me: _verifiedMe);
      await host(
        tester,
        const FreelanceManageScreen(),
        repo: repo,
        size: const Size(800, 4000),
      );
      expect(find.textContaining('pas encore configurés'), findsOneWidget);
      expect(find.text('Créer un lien d’invitation'), findsNothing);
    });

    testWidgets('invites show their state and can be revoked', (tester) async {
      final now = DateTime.now();
      final repo = FakeFreelanceRepository(
        me: _verifiedMe,
        invites: [
          TestimonialInvite(
            id: 'a',
            label: 'Ouverte',
            expiresAt: now.add(const Duration(days: 5)),
            createdAt: now,
          ),
          TestimonialInvite(
            id: 'b',
            label: 'Utilisée',
            expiresAt: now.add(const Duration(days: 5)),
            usedAt: now,
            createdAt: now,
          ),
          TestimonialInvite(
            id: 'c',
            label: 'Vieille',
            expiresAt: now.subtract(const Duration(days: 1)),
            createdAt: now,
          ),
        ],
      );
      await host(
        tester,
        const FreelanceManageScreen(),
        repo: repo,
        size: const Size(800, 4000),
      );
      expect(find.textContaining('En attente ·'), findsOneWidget);
      expect(find.textContaining('Utilisée ·'), findsOneWidget);
      expect(find.textContaining('Expirée ·'), findsOneWidget);
      await tester.tap(find.byTooltip('Révoquer: Ouverte'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Révoquer'),
        ),
      );
      await tester.pumpAndSettle();
      expect(repo.revoked, ['a']);
      expect(find.text('Ouverte'), findsNothing);
    });
  });

  group('small phone, large text and Arabic', () {
    const phone = Size(320, 640);

    Future<void> noOverflow(
      WidgetTester tester,
      Widget screen,
      FakeFreelanceRepository repo, {
      String lang = 'fr',
      List<Override> overrides = const [],
    }) async {
      await host(
        tester,
        screen,
        repo: repo,
        size: phone,
        scale: 2,
        lang: lang,
        overrides: overrides,
      );
      expect(tester.takeException(), isNull);
    }

    FakeFreelanceRepository full() => FakeFreelanceRepository(
      me: _verifiedMe,
      freelancers: [_amine, _salma],
      items: const [
        FreelancePortfolioItem(
          id: 'p1',
          kind: PortfolioKind.link,
          title: 'Un titre de réalisation assez long pour passer à la ligne',
          url: 'https://example.com/',
        ),
      ],
      testimonials: const [
        Testimonial(
          id: 't1',
          authorName: 'Un client avec un nom assez long',
          projectTitle: 'Un projet au titre vraiment très long aussi',
          rating: 4,
          body: 'Un témoignage plutôt long pour vérifier le retour à la ligne.',
        ),
      ],
      invites: [
        TestimonialInvite(
          id: 'a',
          label: 'Une invitation avec un libellé assez long',
          expiresAt: DateTime.now().add(const Duration(days: 3)),
          createdAt: DateTime.now(),
        ),
      ],
    );

    testWidgets('list', (tester) async {
      await noOverflow(tester, const DigitalScreen(), full());
    });
    testWidgets('page', (tester) async {
      await noOverflow(tester, const FreelancerScreen(id: 'f1'), full());
    });
    testWidgets('owner', (tester) async {
      await noOverflow(
        tester,
        const FreelanceManageScreen(),
        full(),
        overrides: [
          testimonialBaseUrlProvider.overrideWithValue('https://t.example.tn'),
        ],
      );
    });
    testWidgets('owner, not a freelancer', (tester) async {
      await noOverflow(
        tester,
        const FreelanceManageScreen(),
        FakeFreelanceRepository(),
      );
    });

    testWidgets('Arabic list: right to left, no overflow', (tester) async {
      await noOverflow(tester, const DigitalScreen(), full(), lang: 'ar');
      expect(screenDirection(tester), TextDirection.rtl);
      expect(find.text('الخدمات الرقمية'), findsOneWidget);
    });

    testWidgets('Arabic page: right to left, no overflow', (tester) async {
      await noOverflow(
        tester,
        const FreelancerScreen(id: 'f1'),
        full(),
        lang: 'ar',
      );
      expect(screenDirection(tester), TextDirection.rtl);
    });

    testWidgets('Arabic owner: right to left, no overflow', (tester) async {
      await noOverflow(
        tester,
        const FreelanceManageScreen(),
        full(),
        lang: 'ar',
        overrides: [
          testimonialBaseUrlProvider.overrideWithValue('https://t.example.tn'),
        ],
      );
      expect(screenDirection(tester), TextDirection.rtl);
    });
  });
}
