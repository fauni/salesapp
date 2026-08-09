# SalesApp — Design System (Flutter)

Source of truth for all visual design in the app. Extracted directly from the
approved HTML mockup — every value here is exact, not approximate. When
implementing any screen or widget, match these tokens instead of picking new
colors, sizes, or fonts. If a needed value isn't listed here, ask before
inventing one rather than guessing.

## Fonts

Two Google Fonts, both already used in the mockup:

- **Plus Jakarta Sans** (weights 500, 600, 700, 800) — headings, titles, numbers,
  labels, buttons, anything that needs to read as UI chrome.
- **Inter** (weights 400, 500, 600, 700) — body text, descriptions, input text.

In Flutter: `google_fonts` package, `GoogleFonts.plusJakartaSans()` and
`GoogleFonts.inter()`. Set both in the app's `ThemeData.textTheme` rather than
calling `GoogleFonts.x()` inline everywhere.

## Color tokens

```dart
class AppColors {
  static const sapBlue        = Color(0xFF0064DC);
  static const sapBlueDeep    = Color(0xFF004FB0);
  static const sapBlueTint    = Color(0xFFEAF2FE);

  static const shell1         = Color(0xFF0A1E42); // darkest navy
  static const shell2         = Color(0xFF122B54); // lighter navy, used in gradients with shell1

  static const positive       = Color(0xFF127A45);
  static const positiveBg     = Color(0xFFE7F5EC);
  static const critical       = Color(0xFFA15B00); // "pending" status color
  static const criticalBg     = Color(0xFFFCF1DF);
  static const negative       = Color(0xFFB3261E);
  static const negativeBg     = Color(0xFFFBEBEA);

  static const bgPage         = Color(0xFFF3F5F9);
  static const card           = Color(0xFFFFFFFF);
  static const line           = Color(0xFFE6E9EF);
  static const lineSoft       = Color(0xFFEEF1F5);
  static const cardBorderGhost = Color(0x0B111A2E); // rgba(17,26,46,0.045) — barely-there border on shadowed cards

  static const text1          = Color(0xFF111A2E); // primary text
  static const text2          = Color(0xFF5A6579); // secondary text
  static const text3          = Color(0xFF94A0B2); // tertiary / placeholder text
}
```

**Status color mapping (badges, order state):**
- Pending → `critical` / `criticalBg` (amber, NOT red — pending is a neutral-ish
  waiting state, not an error)
- Approved → `positive` / `positiveBg` (green)
- Rejected → `negative` / `negativeBg` (red)

## Gradients

- **Shell/header gradient** (topbar, drawer, toast, cart pill, FAB, primary buttons
  background context): `linear-gradient(160deg, shell2, shell1)` roughly —
  in Flutter use `LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [shell2, shell1])`.
- **Primary action gradient** (buttons, brand mark, avatars with SAP-blue): `LinearGradient(colors: [sapBlue, sapBlueDeep])`, 135deg (top-left to bottom-right).
- **Avatar gradient** (client/order initials, non-SAP-blue ones): `LinearGradient(colors: [shell2, shell1])`.
- **Login screen background**: light vertical gradient, white (`#FFFFFF`) to `bgPage`
  (`#F3F5F9`), top to bottom. Login is intentionally light, NOT the dark navy used
  elsewhere — this was a deliberate correction, don't revert it.

## Spacing & radius

```dart
class AppRadius {
  static const lg = 16.0;
  static const md = 12.0;
  static const sm = 9.0;
}
```

- Cards, list rows, item rows, client rows: `radius-md` (12).
- Bottom sheet top corners: 22.
- Buttons: 10–11.
- Chips, badges, search pills: fully rounded (`radius: 999` / `StadiumBorder`).
- Screen content padding: 16–18 horizontal, 16 top, ~30 bottom (more if a
  sticky bottom bar or cart pill overlaps content).

## Elevation — shadow, not heavy borders

This is a deliberate design decision from the mockup: cards use **soft shadow
for elevation**, with only a near-invisible border (`cardBorderGhost`, ~4.5%
black) for edge definition — not a hard visible border. Don't use
`Border.all(color: Colors.grey)`-style solid borders on cards; use
`BoxShadow` instead:

```dart
BoxShadow(color: Color(0x0A111A2E), blurRadius: 2, offset: Offset(0, 1)),  // 0 1px 2px rgba(17,26,46,0.04)
BoxShadow(color: Color(0x0D111A2E), blurRadius: 10, offset: Offset(0, 2)), // 0 2px 10px rgba(17,26,46,0.05)
```

Floating elements (cart pill, FAB, bottom sheet) use a stronger shadow:
`0 12px 28px rgba(9,22,53,0.28)`.

**Exception:** `order-card` also has a **3px solid left border in `sapBlue`**
— that's a deliberate accent stripe, not a structural border, keep it on order
cards specifically.

## Interaction / motion

These rules came from a deliberate polish pass — follow them exactly, they're
not arbitrary:

- **Press feedback on every tappable card/row/button:** scale to **0.96** on
  press, never smaller (looks broken) or larger than 0.97 (imperceptible).
  Duration **140ms**, easing `Curves.easeOut`-equivalent (cubic-bezier(.2,0,0,1)).
  In Flutter: wrap tappables in a `GestureDetector`/`InkWell` with an
  `AnimatedScale` (or `AnimatedContainer` scale transform) driven by
  `onTapDown`/`onTapUp`/`onTapCancel`.
- **Screen transitions:** new screen fades in + slides up ~6px, 260ms,
  ease-out. In Flutter this is the default-ish feel of a `FadeTransition` +
  `SlideTransition` combo on route push — don't use the default Material
  slide-from-right unless asked; this app's navigation model isn't a linear
  stack (see Navigation section below).
- **Bottom sheet / drawer:** slide in with `cubic-bezier(.32,.72,0,1)` (a
  slight overshoot/spring feel), ~280ms.

## Navigation pattern — NOT bottom tabs

Important: this app deliberately does **not** use a bottom tab bar. The
pattern is:

- **Side drawer** (hamburger icon, top-left of every top-level screen) for
  main sections: Mis pedidos, Nuevo pedido, Clientes, Perfil, Cerrar sesión.
  Drawer background uses the shell gradient, active item has a left accent
  bar in `sapBlue` and a tinted background.
- **Floating action button** (bottom-right corner, not centered, not in a
  bottom bar) to start a new order from the orders list.
- Sub-screens (client picker, item catalog, order summary, order detail) use
  a **back arrow** in the same top-left slot the hamburger icon occupies on
  top-level screens — same visual slot, different icon/action depending on
  context.
- **Segmented control** (Pendientes / Autorizados / Rechazados), not top
  tabs with underline, for switching order status filters on the home screen.

If asked to add bottom navigation, push back and confirm — it contradicts the
approved design.

## Key components

**Order card:** white surface, soft shadow, 3px `sapBlue` left accent, order
number + client name top row with status badge top-right, divider, then a
3-column meta row (Total / Fecha / Ítems) with uppercase micro-labels.

**Status badge:** pill shape, uppercase text, 10px, bold, tinted background
matching status color (see mapping above).

**Search bar (large variant):** white pill/rounded-rect, 46px tall, leading
search icon, trailing optional action chip (e.g. barcode scan button in
`sapBlueTint` background).

**Category chips:** horizontal scroll row, pill-shaped, white/bordered when
inactive, `shell1` filled with shadow when active.

**Bottom sheet (line-item config):** rounded top corners (22px), drag handle,
header with title + close button, body with a highlighted quantity stepper
block (`sapBlueTint` background), form fields below, sticky footer with a
destructive ghost button + primary filled button.

**Cart pill (floating):** shell-gradient rounded rect, fixed bottom, shows
item count badge + running total + "Ver pedido" chevron affordance — this is
how the item-search screen surfaces the in-progress order without leaving
the search.

**Avatar (client/user initials):** rounded-square (not circle) for order/
client avatars using the shell gradient; the drawer user avatar and any
`sapBlue`-branded avatar use the blue gradient instead.

## Screens to replicate (in priority order matching backend build-out)

1. **Login** — light background (see Gradients), centered brand mark, title +
   subtitle, username/password fields, primary button, geo-captured pill
   (positive-colored) below the button.
2. **Home / Mis pedidos** — drawer nav, segmented control (3 states), list of
   order cards, FAB to start new order.
3. **Order detail** — back nav, status badge, "Datos del pedido" card (date,
   salesperson, payment terms, series, currency), client card, item list,
   totals breakdown (subtotal/discount/total), geolocation row, report
   actions (PDF, share), and a context-dependent action row (Duplicate order
   / Use as base for new order if rejected).
4. **New order — client picker** — large search bar, recent-clients
   horizontal strip, live-filtered result list.
5. **New order — item catalog** — large search bar with scan icon, category
   chips, live-filtered results showing per-item configured state, floating
   cart pill.
6. **Line-item config bottom sheet** — quantity stepper, sales UoM select,
   unit price, discount %, delivery date, line subtotal, remove/save actions.
7. **Order summary/confirmation** — client card, payment terms + series
   selects, itemized list with a "add more items" affordance, sticky total +
   save button.
8. **Profile** — drawer-accessible, user info rows, logout.

## What NOT to do

- Don't introduce a bottom tab bar.
- Don't make the login screen dark — it was deliberately corrected to light.
- Don't replace soft-shadow cards with hard 1-2px visible borders.
- Order lines carry ONLY the sales UoM. The TFE (electronic invoicing) UoM was
  dropped on 2026-08-08 (client decision) — do NOT add a TFE UoM field to the
  line-item flow. This supersedes the earlier mockup; see backend `CLAUDE.md`.
- Don't use a different press-scale value than 0.96, or skip press feedback
  on tappable rows/cards.
