# Khidma design

Approved by the owner on 2026-11-13 from rendered mockups and videos
("1 noir & blanc"). Replaces "Atelier", "Signal" and the violet look, all
rejected (violet read as AI-made). Read this before touching any screen.

## Idea
Khidma should feel like the service apps people already trust (TaskRabbit,
Fiverr, Upwork, Yassir): calm, clean, familiar, well structured. Nothing
exotic: no poster type, no thick black outlines, no hard shadows, no
gradients, no glow, no emoji. The content (people, their work, prices,
ratings) is the visual interest. Motion is quiet and quick, like a native
app. Real photos of pros' work come later; until then placeholders are soft
tinted tiles with a line icon (never AI images).

## Colour (lib/core/theme/app_colors.dart)
Black and white, like Uber/Bolt. Actions, the active tab and hero cards are
black `#141414` with white text (dark mode: inverted, `#F2F2F2` with black
text). Background and cards white, text `#141414`, secondary text `#6B6B6B`,
hairlines `#EAEAEA`, soft grey `#F2F2F2` for chips, the segmented-control
track, selected rows and the profile header band. Category / placeholder
tiles are one quiet grey (`AppColors.tint`); icons carry the meaning.
Colour comes only from content: initials avatars `AppColors.avatar(i)`,
stars `#E8A317`, the green verified tick `AppColors.success`, status pills.
Section links ("Tout voir") are grey or black, never coloured.
Use `Theme.of(context).colorScheme` roles: `primary` (black), `onPrimary`,
`primaryContainer`/`onPrimaryContainer` (soft grey + ink), `surface`,
`onSurface`, `onSurfaceVariant`, `outlineVariant`, `surfaceContainerHighest`,
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
Buttons: filled black 52 px high, radius 14; secondary = white with hairline.
Avatars are circles. Icons: Material rounded/outlined line icons.

## Layout (from the approved mockup)
- Screen gutter 20. Section title row: title left, "Tout voir" link right.
- **Tab bar** (`AppBottomNav`): 5 tabs, icon + label, active in black, bold,
  with a filled icon: Accueil, Explorer, Demandes, Messages, Profil.
- **Home**: location row (label "Votre position" + city with pin, bell button
  on the end), segmented toggle **Artisans | Freelance digital** (white thumb
  sliding on a soft grey track), search field with a black filter button, a
  promo/hero card carousel (black card, white text, one action, page dots),
  "Catégories" as 4 grey icon tiles per row, "Pros près de vous" as a
  horizontal list of cards (image area on top with a heart button, initials
  avatar + name + verified badge + trade/years, star rating with count and
  "dès N DT").
- **Pro / freelancer profile**: soft grey header band with back / share /
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

## First screen (onboarding)
A single welcome screen, no slides: logo top-start, language button
top-end (globe + current language, opens a sheet FR / العربية / EN),
three rows of service chips and pro chips scrolling slowly in alternate
directions (fading at the edges), the headline "Trouvez un [word] près de
chez vous." where the word rotates (plombier, électricien, développeur,
designer, menuisier), one line of subtitle, a trust line (no invented
numbers), then "Commencer" (enters the app) and "J'ai déjà un compte"
(login). Elements fade up in a short cascade on open.

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
