# Khidma design: "Signal"

Full replacement of every earlier look (blue/white photo app, "Atelier" paper
and terracotta). Read this before touching any screen.

## Idea
Khidma is a street full of workshops and studios. The look is **workshop
signage**: tall condensed capitals, flat colour fields, hard black ink, chunky
blocks with a hard offset "sticker" shadow. It is loud, physical and in
constant, springy motion. It must not look AI-generated: no gradients, no
blur or glow, no pastel, no soft rounded cards, no glassmorphism, no stock
photos, no emoji. Placeholder imagery is typographic or geometric (big
glyph tiles, flat shapes); the owner will supply real photos later.

Pinterest research (Nov 2026) confirmed the direction: the best structural
references were bold, hard-outlined "sticker" UIs (yellow and black), poster
typography, swipe-card hiring flows, and apps where every control is a chunky
physical block that reacts to the finger.

## Two worlds
The app has two sections, each with its own loud colour; switching recolours
everything (a colour flood from the tapped switch, see `AppShell`).
- **Métiers / Trades** (plumber, electrician...): signage **yellow** `#F5C400`
  with ink text.
- **Digital** (web, mobile, design, video, marketing...): **zellij green**
  `#0B6B4D` with white text.
Everything else is ink `#0E0E0E`, paper white, ground `#EDEDE8`. Dark mode
exists (near-black ground, light ink, green lifts to `#30C48D`).
Colours come from `Theme.of(context).colorScheme` only:
`primaryContainer`/`onPrimaryContainer` = the world colour and its text,
`primary` = ink, `surface` = paper, `onSurface` = ink, `outlineVariant` =
hairline grey, `secondary` = the other world's colour. Never hard-code a
colour (except ink/white on a photo). Yellow is never used as text.

## Type (lib/core/theme/app_typography.dart)
Latin: **Anton** (single weight, tall condensed capitals) for display and
headings, **Barlow** for reading and controls. Arabic: **Lalezar** (display,
single weight) and **Tajawal**. Use the `textTheme` styles; never set a
fontFamily by hand. Anton has one weight: do not bold it. In Latin, set
display text in capitals with `AppTypography.display(locale, text)`.
Western digits everywhere. Make headlines BIG (30-64 px) and short.

## Blocks
- Radii are tiny (`AppRadius` 2-6). Borders are heavy: `AppInk.border` = 2 px
  in ink. The signature block is `StickerBox` (`lib/core/motion/motion.dart`):
  ink border + hard offset shadow (4 px, falls to the end side, flips in RTL).
- Buttons: `AppButton` (already sticker + press-sink). One loud primary per
  screen. Chips are rectangular with ink borders; selected = world colour.
- Separate with ink rules and flat colour fields, never soft shadows.
- Key facts as ruled rows or big stat blocks (Anton numerals with `CountUp`).

## Motion (lib/core/motion/motion.dart) - one vocabulary
- **Slam**: elements arrive fast with a springy overshoot (`Motion.slam`,
  140-420 ms). They do not drift or fade slowly.
- **Press-sink**: every tappable block sinks into its shadow while pressed
  (`Pressable`, built into `AppButton`), with a light haptic.
- **Stagger**: lists/grids enter once as a quick cascade (`StaggerIn(index:)`).
- **Count-up** for numbers (`CountUp`), **SlamSwitcher** for swapping content,
  `SpringTo` for gesture release (swipe cards, sheets).
- **World flood**: switching world floods the screen with the new colour.
- Page transitions are the platform ones (iOS swipe-back must keep working).
- **Reduce Motion**: every animation must check `Motion.reduced(context)` and
  show the final state at once. Motion never blocks input and never carries
  information alone.

## Structure
- Tab bar = the **dock** (`AppBottomNav`): four blocks, the active one grows
  and is flooded with the world colour. 4 tabs: Accueil, Demandes, Messages,
  Profil. No floating buttons.
- **Home** is a launcher: the world switch on top (two huge blocks MÉTIERS /
  DIGITAL), a giant question, the search block, one loud "quote" block, then
  chunky category tiles and pro/freelancer cards.
- Detail pages open with a **colour header block** with the name in giant
  Anton and a sticker avatar overlapping its edge, with a sticky action bar.
- Forms are stepped: a big step number (01/05), one question per block.
- Empty states are typographic: a giant word and a glyph tile, no photos.

## Non-negotiables
- Keep every feature, provider, route, text key and semantics label working.
  Existing widget tests must still pass; edit a test only when a layout
  change genuinely moves something (needs scrolling, finder by type).
- RTL: Directional insets/alignments only. Text at 1.5-2x on a 320 px phone
  must not overflow (Anton is condensed: leave room for Arabic).
- Contrast: text >= 4.5:1, controls >= 3:1 (the tokens satisfy this; yellow
  only ever carries ink).
