import 'package:flutter/material.dart';

import '../../core/format/money.dart';
import '../../core/format/tunisian_phone.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../shared/widgets/aligned_text.dart';
import '../../shared/widgets/app_avatar.dart';
import '../../shared/widgets/app_bottom_nav.dart';
import '../../shared/widgets/app_badge.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/app_chip.dart';
import '../../shared/widgets/app_text_field.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/error_state.dart';
import '../../shared/widgets/khidma_logo.dart';
import '../../shared/widgets/rating_stars.dart';
import '../../shared/widgets/section_header.dart';
import '../../shared/widgets/skeleton.dart';

/// Developer-only catalogue of the shared components (all except AppShell and
/// NotFoundScreen, which are whole-screen wrappers), tokens and states, for
/// visual review in LTR/RTL and light/dark. Sample text is demo data; it is
/// not localized on purpose (it only needs to exercise both scripts).
class GalleryScreen extends StatelessWidget {
  const GalleryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final rtl = Localizations.localeOf(context).languageCode == 'ar';
    final s = _Sample(rtl);
    return Scaffold(
      appBar: AppBar(title: const Text('Design gallery')),
      body: ListView(
        padding: const EdgeInsetsDirectional.all(AppSpacing.gutter),
        children: [
          _Section('Brand', const _BrandSection()),
          _Section('Colors', const _ColorsSection()),
          _Section('Typography', _TypeSection(s)),
          _Section('Buttons', _ButtonsSection(s)),
          _Section('Text fields', _FieldsSection(s)),
          _Section('Chips', _ChipsSection(s)),
          _Section('Cards, rating, avatar, badges', _CardsSection(s)),
          _Section('Navigation and text helpers', const _NavSection()),
          _Section('Loading', const _LoadingSection()),
          _Section('Empty and error states', const _StatesSection()),
          const SizedBox(height: AppSpacing.xxl),
        ],
      ),
    );
  }
}

/// Demo strings that exercise Latin and Arabic text.
class _Sample {
  const _Sample(this.rtl);
  final bool rtl;
  String get name => rtl ? 'كريم بن صالح' : 'Karim Ben Salah';
  String get job => rtl ? 'سبّاك · تونس' : 'Plombier · La Marsa';
  String get action => rtl ? 'إرسال الطلب' : 'Envoyer la demande';
  String get call => rtl ? 'اتصال' : 'Appeler';
  String get whatsapp => rtl ? 'واتساب' : 'WhatsApp';
  String get label => rtl ? 'الاسم الكامل' : 'Nom complet';
  String get hint => rtl ? 'مثال: كريم' : 'Ex. Karim';
  String get error => rtl ? 'هذا الحقل مطلوب' : 'Ce champ est obligatoire';
  String get title => rtl ? 'الأكثر شعبية' : 'Les plus demandés';
  String get seeAll => rtl ? 'عرض الكل' : 'Voir tout';
  List<String> get categories => rtl
      ? ['سباكة', 'كهرباء', 'تكييف', 'ميكانيك', 'دهن']
      : ['Plomberie', 'Électricité', 'Climatisation', 'Mécanique', 'Peinture'];
  String get type => rtl ? 'العنوان الرئيسي' : 'Titre principal';
  String get body => rtl
      ? 'نص عادي يوضح الخدمة المقدمة.'
      : 'Texte courant décrivant le service.';
}

class _Section extends StatelessWidget {
  const _Section(this.title, this.child);
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          child,
        ],
      ),
    );
  }
}

class _BrandSection extends StatelessWidget {
  const _BrandSection();

  @override
  Widget build(BuildContext context) => const Wrap(
    spacing: AppSpacing.xl,
    runSpacing: AppSpacing.lg,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [KhidmaLogo(), KhidmaMarkBadge(size: 72), KhidmaMark(size: 32)],
  );
}

class _ColorsSection extends StatelessWidget {
  const _ColorsSection();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final swatches = <(String, Color)>[
      ('primary', cs.primary),
      ('container', cs.primaryContainer),
      ('saffron', AppColors.saffron),
      ('surface', cs.surface),
      ('control', cs.outline),
      ('hairline', cs.outlineVariant),
      ('ink', cs.onSurface),
      ('muted', cs.onSurfaceVariant),
      ('success', AppBadge.foreground(BadgeTone.success, cs)),
      ('warning', AppBadge.foreground(BadgeTone.warning, cs)),
      ('error', AppBadge.foreground(BadgeTone.error, cs)),
    ];
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        for (final (name, color) in swatches)
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 40,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  border: Border.all(color: cs.outlineVariant),
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(name, style: Theme.of(context).textTheme.labelSmall),
            ],
          ),
      ],
    );
  }
}

class _TypeSection extends StatelessWidget {
  const _TypeSection(this.s);
  final _Sample s;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(s.type, style: t.displaySmall),
        Text(s.type, style: t.headlineMedium),
        Text(s.type, style: t.headlineSmall),
        Text(s.type, style: t.titleLarge),
        Text(s.type, style: t.titleMedium),
        Text(s.type, style: t.titleSmall),
        Text(s.body, style: t.bodyLarge),
        Text(s.body, style: t.bodyMedium),
        Text(s.body, style: t.bodySmall),
        Text(s.label, style: t.labelLarge),
        Text(s.label, style: t.labelMedium),
        Text(s.label, style: t.labelSmall),
      ],
    );
  }
}

class _ButtonsSection extends StatelessWidget {
  const _ButtonsSection(this.s);
  final _Sample s;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppButton(label: s.action, onPressed: () {}),
        const SizedBox(height: AppSpacing.sm),
        AppButton(
          label: s.call,
          onPressed: () {},
          icon: Icons.phone_rounded,
          variant: AppButtonVariant.secondary,
        ),
        const SizedBox(height: AppSpacing.sm),
        AppButton(label: s.action, onPressed: () {}, isLoading: true),
        const SizedBox(height: AppSpacing.sm),
        AppButton(label: s.action, onPressed: null),
        const SizedBox(height: AppSpacing.sm),
        AppButton(
          label: s.action,
          onPressed: () {},
          isLoading: true,
          variant: AppButtonVariant.secondary,
        ),
        const SizedBox(height: AppSpacing.sm),
        AppButton(
          label: s.action,
          onPressed: null,
          variant: AppButtonVariant.secondary,
        ),
        const SizedBox(height: AppSpacing.sm),
        AppButton(
          label: s.action,
          onPressed: null,
          variant: AppButtonVariant.text,
          expand: false,
        ),
        const SizedBox(height: AppSpacing.sm),
        // Button groups use Wrap so they flow to a second line on narrow
        // screens or with large text instead of overflowing.
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            AppButton(
              label: s.call,
              onPressed: () {},
              expand: false,
              icon: Icons.phone_rounded,
            ),
            AppButton(
              label: s.whatsapp,
              onPressed: () {},
              expand: false,
              variant: AppButtonVariant.secondary,
            ),
            AppButton(
              label: s.seeAll,
              onPressed: () {},
              variant: AppButtonVariant.text,
              expand: false,
            ),
          ],
        ),
      ],
    );
  }
}

class _FieldsSection extends StatelessWidget {
  const _FieldsSection(this.s);
  final _Sample s;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AppTextField(label: s.label, hint: s.hint),
        const SizedBox(height: AppSpacing.lg),
        AppTextField(
          label: s.label,
          errorText: s.error,
          prefixIcon: Icons.person_outline_rounded,
        ),
        const SizedBox(height: AppSpacing.lg),
        AppTextField(
          key: const Key('gallery-phone'),
          label: s.rtl ? 'الهاتف' : 'Téléphone',
          hint: TunisianPhone.display('20123456'),
          keyboardType: TextInputType.phone,
          textDirection: TextDirection.ltr,
          prefixIcon: Icons.phone_outlined,
        ),
        const SizedBox(height: AppSpacing.lg),
        AppTextField(
          label: s.rtl ? 'كلمة المرور' : 'Mot de passe',
          obscureText: true,
        ),
        const SizedBox(height: AppSpacing.lg),
        AppTextField(label: s.label, enabled: false),
        const SizedBox(height: AppSpacing.lg),
        AppTextField(
          label: s.rtl ? 'وصف المشكلة' : 'Description du problème',
          helper: s.rtl ? 'أضف تفاصيل مفيدة' : 'Ajoutez des détails utiles',
          maxLines: 3,
        ),
      ],
    );
  }
}

class _ChipsSection extends StatefulWidget {
  const _ChipsSection(this.s);
  final _Sample s;

  @override
  State<_ChipsSection> createState() => _ChipsSectionState();
}

class _ChipsSectionState extends State<_ChipsSection> {
  int _selected = 1;

  @override
  Widget build(BuildContext context) {
    final cats = widget.s.categories;
    return Wrap(
      spacing: AppSpacing.sm,
      children: [
        for (var i = 0; i < cats.length; i++)
          AppChip(
            label: cats[i],
            selected: i == _selected,
            onSelected: (_) => setState(() => _selected = i),
          ),
        AppChip(
          label: widget.s.rtl ? 'متاح الآن' : 'Disponible',
          icon: Icons.bolt_rounded,
          selected: false,
          onSelected: (_) {},
        ),
      ],
    );
  }
}

class _CardsSection extends StatelessWidget {
  const _CardsSection(this.s);
  final _Sample s;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context);
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title: s.title, actionLabel: s.seeAll, onAction: () {}),
        AppCard(
          onTap: () {},
          semanticLabel: '${s.name}, ${s.job}',
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppAvatar(name: s.name, decorative: true, size: 56),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.name,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      s.job,
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: muted),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    const RatingStars(rating: 4.6, reviewCount: 23),
                    const SizedBox(height: AppSpacing.sm),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.xs,
                      children: [
                        AppBadge.verified(context),
                        AppBadge(
                          label: formatTnd(45, locale),
                          icon: Icons.payments_outlined,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        const AppCard(child: RatingStars(rating: 0, reviewCount: 0)),
        const SizedBox(height: AppSpacing.md),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            AppBadge(label: l10n.verified, tone: BadgeTone.success),
            const AppBadge(label: 'Info', tone: BadgeTone.info),
            const AppBadge(label: 'Neutral'),
            const AppBadge(label: 'Warning', tone: BadgeTone.warning),
            const AppBadge(label: 'Error', tone: BadgeTone.error),
          ],
        ),
      ],
    );
  }
}

class _NavSection extends StatelessWidget {
  const _NavSection();

  @override
  Widget build(BuildContext context) {
    final rtl = Localizations.localeOf(context).languageCode == 'ar';
    final labels = rtl
        ? ['الرئيسية', 'طلباتي', 'الرسائل', 'حسابي']
        : ['Accueil', 'Demandes', 'Messages', 'Profil'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: AppBottomNav(
            currentIndex: 1,
            onSelected: (_) {},
            items: [
              NavItem(Icons.home_outlined, Icons.home_rounded, labels[0]),
              NavItem(
                Icons.assignment_outlined,
                Icons.assignment_rounded,
                labels[1],
              ),
              NavItem(
                Icons.chat_bubble_outline_rounded,
                Icons.chat_bubble_rounded,
                labels[2],
              ),
              NavItem(
                Icons.person_outline_rounded,
                Icons.person_rounded,
                labels[3],
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        // A value forced LTR inside an RTL screen still aligns to the start.
        const AlignedText('+216 20 123 456', textDirection: TextDirection.ltr),
        const SizedBox(height: AppSpacing.lg),
        const Row(
          children: [
            AppAvatar(name: 'Karim Ben Salah', size: 40),
            SizedBox(width: AppSpacing.sm),
            AppAvatar(name: 'Meriem', size: 40),
            SizedBox(width: AppSpacing.sm),
            AppAvatar(
              name: 'Sami Gharbi',
              size: 40,
              imageUrl: 'http://localhost:1/missing.png',
            ),
          ],
        ),
      ],
    );
  }
}

class _LoadingSection extends StatelessWidget {
  const _LoadingSection();

  @override
  Widget build(BuildContext context) => const SkeletonGroup(
    child: Row(
      children: [
        Skeleton(height: 56, circle: true),
        SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Skeleton(height: 16, width: 160),
              SizedBox(height: AppSpacing.sm),
              Skeleton(height: 12, width: 100),
            ],
          ),
        ),
      ],
    ),
  );
}

class _StatesSection extends StatelessWidget {
  const _StatesSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(
          height: 240,
          child: EmptyState(
            icon: Icons.search_rounded,
            title: 'Empty',
            body: 'Nothing here yet.',
          ),
        ),
        SizedBox(height: 260, child: ErrorState(onRetry: () {})),
      ],
    );
  }
}
