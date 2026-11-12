# Khidma design: "Atelier"

The owner rejected two earlier looks (blue/white photo app, then a soft-shadow
"AI" style). This is a full replacement. Read this before touching any screen.

## Idea
Khidma is a trade directory for Tunisian craftspeople. The look borrows from a
workshop's paper world: a printed trade register, a carpenter's ledger, a shop
sign. Calm bone paper, warm ink, hairline rules, one clay-red action colour.
Information first, decoration last. It must NOT look AI-generated: no
gradients, no glow, no drop shadows, no glassmorphism, no pill-everything, no
purple/blue/teal, no floating action buttons, no emoji, no "hero" gimmicks.

## Tokens (lib/core/theme)
- Paper `background` #F4EFE6, card `surface` #FFFCF6, sunken `surfaceAlt`
  #EAE2D3, ink #1F1B16, muted ink #6B6257, rules `border` #D9CFBD, control
  outlines #8A8070.
- Terracotta `primary` #B0432A (white text on it). Use it ONLY for the main
  action of a screen, links and the active-tab mark. One terracotta button per
  screen at most.
- Olive #46613E: verified / available / success. Ochre #C98E1F: stars only.
- Dark mode exists (charcoal-brown); always use `Theme.of(context).colorScheme`
  roles, never hard-coded light colours, except on photos.
- Radii: AppRadius.sm 4, md 6, lg 10, xl 14. Mostly 6. No 20+ radii, no
  stadium shapes.
- Type: headings Zilla Slab (`textTheme.headline*`, `titleLarge`), reading and
  controls Lato (`title{Medium,Small}`, `body*`, `label*`). Arabic uses IBM Plex
  Sans Arabic automatically. Never set fontFamily by hand. Western digits.

## Structural rules
- Separate with hairline rules (`Divider`, 1px `outlineVariant` borders) and
  whitespace, not shadows. Cards = flat paper with a 1px rule border.
- Lists look like a register: rows with a small square thumbnail or initials,
  title, one muted line, a trailing chevron or value, a rule between rows.
- Section titles: Zilla Slab `titleLarge`, optionally with a small uppercase
  Lato `labelSmall` "kicker" in muted ink above it (e.g. "N° 01 · SERVICES").
- Key facts as definition rows: label in muted ink on the start side, value in
  ink on the end side, rule underneath (like a receipt / trade licence).
- Buttons: filled terracotta (primary, one per screen), outlined ink
  (secondary), text links in terracotta. Height 52, radius 6.
- Chips: rectangular radius 4, ink outline; selected = ink fill, paper text.
- Badges: small rectangular stamps; verified = olive with a check.
- Photos: the bundled photos in `assets/photos/` (warm documentary style) are
  used small and framed (square thumbnails radius 4-6, or a framed cover with a
  1px border), never full-bleed behind text, never with colour overlays.
- Navigation: a solid ink tab bar (already built in
  `shared/widgets/app_bottom_nav.dart`) with 4 tabs. No centre "+" button.
  Starting a request is a full-width terracotta bar/button inside screens.
- Tab root screens leave 16px bottom padding (the bar is not floating any more).
- Motion: short (150-200ms) fades/sizes only; respect reduced motion.

## Non-negotiables
- Keep every feature, provider, route, text key and semantics label working.
  Existing widget tests must still pass; update a test only when the layout
  change genuinely moves something (scrolling, finder by type), never to
  weaken what it checks.
- RTL: use Directional insets/alignments. Large text (1.5x-2x) must not
  overflow on a 320px-wide phone.
- Contrast: text >= 4.5:1, controls >= 3:1 (the tokens already satisfy this).
