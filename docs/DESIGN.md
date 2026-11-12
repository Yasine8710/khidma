# Khidma design

Approved by the owner on 2026-11-12 from rendered mockups ("violet", Home +
pro profile). Replaces the earlier "Atelier" and "Signal" looks, which were
rejected as over-designed. Read this before touching any screen.

## Idea
Khidma should feel like the service apps people already trust (TaskRabbit,
Fiverr, Upwork, Yassir): calm, clean, familiar, well structured. Nothing
exotic: no poster type, no thick black outlines, no hard shadows, no
gradients, no glow, no emoji. The content (people, their work, prices,
ratings) is the visual interest. Motion is quiet and quick, like a native
app. Real photos of pros' work come later; until then placeholders are soft
tinted tiles with a line icon (never AI images).

## Colour (lib/core/theme/app_colors.dart)
One brand colour, violet `#5B3CC4` (dark mode: `#A493F0`). Background
`#FAF9FC`, cards white, text `#1B1530`, secondary text `#6E6A80`, hairlines
`#ECE9F3`. Soft violet `#EEE9FB` for chips, selected rows, profile header.
Stars `#F5A524`. Category / placeholder tiles use `AppColors.tint(i, b)`,
initials avatars `AppColors.avatar(i)` (white text).
Use `Theme.of(context).colorScheme` roles: `primary` (violet), `onPrimary`,
`primaryContainer`/`onPrimaryContainer` (soft violet + its text), `surface`
(cards), `onSurface`, `onSurfaceVariant` (secondary text), `outlineVariant`
(hairlines/card borders), `surfaceContainerHighest` (inputs, inset blocks),
`tertiary` (stars), `error`. Never hard-code a colour.

## Type (lib/core/theme/app_typography.dart)
The phone's own font for Latin (SF on iPhone, Roboto on Android); Tajawal for
Arabic. Hierarchy comes from size and weight: screen titles `headlineSmall`
or `titleLarge` (bold), section titles `titleMedium`/`titleLarge`, body
`bodyMedium`, meta `bodySmall` in `onSurfaceVariant`. Sentence case; never
force capitals. Western digits everywhere. Prices: "dès 40 DT".

## Shapes
Radii (`AppRadius`): 10 chips/small tiles, 14 inputs/buttons, 18 cards, 24
sheets and hero cards, pill for chips/badges. Cards: white, 1 px
`outlineVariant` border, no shadow (`StickerBox`, `AppCard`); an optional
very soft shadow (`StickerBox(elevated: true)`) only for floating things.
Buttons: filled violet 52 px high, radius 14; secondary = white with hairline.
Avatars are circles. Icons: Material rounded/outlined line icons.

## Layout (from the approved mockup)
- Screen gutter 20. Section title row: title left, "Tout voir" link right.
- **Tab bar** (`AppBottomNav`): 5 tabs, icon + label, active in violet with
  filled icon: Accueil, Explorer, Demandes, Messages, Profil.
- **Home**: location row (label "Votre position" + city with pin, bell button
  on the end), segmented toggle **Artisans | Freelance digital** (violet
  filled thumb that slides), search field with a violet filter button, a
  promo/hero card carousel (violet card, white text, one action, page dots),
  "Catégories" as 4 tinted icon tiles per row, "Pros près de vous" as a
  horizontal list of cards (image area on top with a heart button, initials
  avatar + name + verified badge + trade/years, star rating with count and
  "dès N DT").
- **Pro / freelancer profile**: soft violet header band with back / share /
  heart round buttons, large circular avatar overlapping it, name + verified
  badge, trade · city, pills (Documents vérifiés / Identité vérifiée, response
  time), a 3-column stats card (Note, Avis, Expérience), tabs (Services,
  Réalisations, Avis, À propos), service rows (tinted icon tile, title,
  detail, "dès N DT"), review cards; sticky bottom bar: message button +
  "Demander un devis".
- Lists: cards or grouped rows with hairline separators; settings-style
  grouped lists on Profile.
- Forms: one column, labels above fields, a progress bar for multi-step.
- Empty states: a soft tinted circle with a line icon, a short title, one
  line of help, one button.
- Trades vs digital: trades show documents/experience ("Documents vérifiés",
  "8 ans"); digital freelancers show identity verification only ("Identité
  vérifiée"), skills chips and portfolio.

## Motion (lib/core/motion/motion.dart)
Quiet, quick (150-380 ms), never blocking:
- `StaggerIn(index:)`: content fades and rises 12 px once; lists cascade.
- `Pressable`: tappable cards shrink to 0.97 while pressed, light haptic.
- `CountUp` for stats; `SoftSwitcher` cross-fade + slide for swapped content
  (e.g. Home when the Artisans/Digital toggle changes).
- Toggle thumb slides (`AnimatedAlign`, `Motion.settle`); heart pops on tap;
  hero carousel auto-advances every 5 s (pauses while touched); skeleton
  shimmer while loading; platform page transitions (iOS swipe-back works).
- Every animation checks `Motion.reduced(context)` and shows the final state
  at once. Motion never carries information alone.

## Non-negotiables
- Keep every feature, provider, route, l10n key and semantics label working.
  Existing widget tests must still pass; edit a test only when a layout
  change genuinely moves something.
- RTL: Directional insets/alignments only. Text at 1.5-2x on a 320 px phone
  must not overflow.
- Contrast: text >= 4.5:1, controls >= 3:1 (the tokens satisfy this).
