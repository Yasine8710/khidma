# Product

<!-- impeccable:product-schema 1 -->

## Platform

ios

## Stack
Flutter (Dart) app in `app/`, Supabase backend, React admin in `admin/`. iOS is the only target; the owner tests on their own iPhone.

## Users
- **Customers** in Tunisia who need a local tradesperson (plumber, electrician, mechanic, painter...) and want to compare offers before choosing. They use the app on a phone, often in a hurry, in French or Arabic (RTL), sometimes English.
- **Professionals** (tradespeople, small businesses) who want to be found, answer requests with offers and build a reputation.
- **Admins** (separate web app) verify identities and handle reports.

## Product Purpose
Khidma is a Tunisian local-services marketplace. A customer describes a need once, receives offers from nearby professionals, compares them, chats, books and reviews. Success: a customer gets a trustworthy professional quickly; a professional gets real jobs and reviews tied to completed work.

## Positioning
Trust first: verified identities, reviews only from completed bookings, contact numbers revealed only to signed-in members, quotes instead of public price lists.

## Operating Context
Mobile, one-handed, variable network quality. Three languages (FR default, AR with RTL, EN), Western digits everywhere.

## Capabilities and Constraints
Home, search with filters and map, professional profile with portfolio and reviews, favorites, quote requests with photos, offers and comparison, bookings, chat, reviews, notifications settings, professional registration wizard and dashboard, verification, reports, account deletion. Sign in with Apple, push and the App Store release are out of scope for now (paid). All of these functions must survive any redesign.

## Brand Commitments
Name Khidma (خدمة). Blue and white theme (Bleu Sidi Bou). The owner asked for a photo-led, rounded, airy look inspired by the reference image in `Desktop/complexity` and by modern home-services app designs.

## Evidence on Hand
Photography generated for the app (no real customer or professional photos exist yet); demo data is labelled as demo and must never look real.

## Product Principles
1. Trust over decoration: badges, ratings and demo labels stay clear.
2. One obvious next action per screen.
3. Photography and calm white space carry the brand; blue marks what is tappable.
4. Works in FR, AR (RTL) and EN at large text sizes.

## Accessibility & Inclusion
Contrast of text and controls checked in light and dark, 44pt targets, large text, reduced motion, RTL.
