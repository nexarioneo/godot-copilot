# MATERIAL3.md — Material 3 Design Reference

Consolidated reference data for **Material 3 (M3)** and **M3 Expressive** (May 2025),
compiled as the foundation for Godot Copilot's own UI component library.

This document is a data sheet: tokens, measurements, color values, and specs, with
source notes. It is not the visual design of the plugin itself — the plugin design
built on top of this data is described in `docs/DESIGN.md`.

- Compiled: 2026-10-17
- Base version: Material 3 web/system tokens v0.192 (Material Web / `material-color-utilities`)
- Additions: M3 Expressive (Google I/O 2025): springs, size axes, shape morph, emphasized type
- Value markers: numbers marked *(verify)* were not present in fetched page text
  (image-only in the spec) and must be confirmed from an implementation source at build time.

---

## 1. Sources

| Source | Used for |
| --- | --- |
| https://m3.material.io (stylesheet, foundations, components) | Role definitions, component specs, state layers, accessibility |
| https://m3.material.io/styles/typography/type-scale-tokens | Type scale, emphasized styles, language line heights |
| https://m3.material.io/styles/shape | Corner radius scale (incl. 2025 additions) |
| https://m3.material.io/styles/elevation | Elevation levels, tonal-surface guidance |
| https://m3.material.io/styles/motion | Durations, easings, spring tokens |
| https://m3.material.io/blog/tone-based-surface-color-m3 | Tone-based surfaces (surface-tint deprecation) |
| https://github.com/material-components/material-web (`tokens/`, v0.192) | Exact hex values, role-to-tone mapping, component token defaults |
| https://github.com/androidx/androidx (`compose/material3/tokens`) | Compose implementation defaults (snackbar, etc.) |
| https://github.com/material-foundation/material-color-utilities | Dynamic color (HCT) reference implementation |
| https://fonts.google.com (Roboto, Roboto Flex, Material Symbols) | Typefaces and icon set |

License notes: Material 3 spec data and the token repositories above are published by
Google under Apache-2.0; Roboto is Apache-2.0, Material Symbols are Apache-2.0.

---

## 2. Design tokens and naming

Material uses a two-tier token system:

| Tier | Prefix | Meaning |
| --- | --- | --- |
| Reference | `md.ref.*` | Raw values (palette tones, typeface names, durations) |
| System | `md.sys.*` | Semantic roles consumed by components (colors, typescale, shape, motion) |
| Component | `md.comp.*` | Per-component tokens that reference system tokens |

Token groups relevant here:

- `md.sys.color.*` — color roles (see §3)
- `md.sys.typescale.*` — 15 baseline + 15 emphasized type styles (see §4)
- `md.sys.shape.corner.*` — corner radius scale (see §5)
- `md.sys.elevation.*` — 6 elevation levels (see §6)
- `md.sys.motion.duration.*`, `md.sys.motion.easing.*`, `md.sys.motion.spring.*` (see §7)
- `md.sys.state.*` — state layer opacities (see §8)

Rule used by every M3 component: **components reference system tokens, never raw
values**. Godot Copilot keeps this rule with its own names (planned:
`CopilotMd3Tokens` constants consumed by components in `src/ui/md3/`).

---

## 3. Color

### 3.1 Concepts

- **Key color / seed**: one source color (e.g., brand color) from which all palettes
  are generated.
- **Tonal palettes**: each palette has 13+ tones (0 = black, 100 = white) with a
  shared hue and chroma; tone is perceptual lightness (L*).
- **HCT color space**: the dynamic-color algorithm converts the seed through
  HCT (CAM16 hue + chroma, L* tone) and picks fixed tones per role.
- **Light and dark schemes**: the same roles exist in both; dark roles reference
  different tones of the same palettes.
- **Contrast levels**: standard, medium, and high; higher contrast shifts tones
  away from the background until the contrast targets are met.

### 3.2 Reference palettes (baseline, M3 v0.192)

Values are the baseline "purple" scheme shipped by Material Theme Builder.

| Tone | Primary | Secondary | Tertiary | Error |
| --- | --- | --- | --- | --- |
| 0 | #000000 | #000000 | #000000 | #000000 |
| 10 | #21005d | #1d192b | #31111d | #410e0b |
| 20 | #381e72 | #332d41 | #492532 | #601410 |
| 30 | #4f378b | #4a4458 | #633b48 | #8c1d18 |
| 40 | #6750a4 | #625b71 | #7d5260 | #b3261e |
| 50 | #7f67be | #7a7289 | #986977 | #dc362e |
| 60 | #9a82db | #958da5 | #b58392 | #e46962 |
| 70 | #b69df8 | #b0a7c0 | #d29dac | #ec928e |
| 80 | #d0bcff | #ccc2dc | #efb8c8 | #f2b8b5 |
| 90 | #eaddff | #e8def8 | #ffd8e4 | #f9dedc |
| 95 | #f6edff | #f6edff | #ffecf1 | #fceeee |
| 99 | #fffbfe | #fffbfe | #fffbfa | #fffbf9 |
| 100 | #ffffff | #ffffff | #ffffff | #ffffff |

Neutral and neutral-variant palettes carry the extra tones used by surfaces:

| Tone | Neutral | Neutral-variant |
| --- | --- | --- |
| 0 | #000000 | #000000 |
| 4 | #0f0d13 | — |
| 6 | #141218 | — |
| 10 | #1d1b20 | #1d1a22 |
| 12 | #211f26 | — |
| 17 | #2b2930 | — |
| 20 | #322f35 | #322f37 |
| 22 | #36343b | — |
| 24 | #3b383e | — |
| 30 | #48464c | #49454f |
| 40 | #605d64 | #605d66 |
| 50 | #79767d | #79747e |
| 60 | #938f96 | #938f99 |
| 70 | #aea9b1 | #aea9b4 |
| 80 | #cac5cd | #cac4d0 |
| 87 | #ded8e1 | — |
| 90 | #e6e0e9 | #e7e0ec |
| 92 | #ece6f0 | — |
| 94 | #f3edf7 | — |
| 95 | #f5eff7 | #f5eefa |
| 96 | #f7f2fa | — |
| 98 | #fef7ff | — |
| 99 | #fffbff | #fffbfe |
| 100 | #ffffff | #ffffff |

### 3.3 Color roles — light scheme (baseline)

| Role | Tone | Hex | Role | Tone | Hex |
| --- | --- | --- | --- | --- | --- |
| primary | 40 | #6750a4 | surface | 98 | #fef7ff |
| on-primary | 100 | #ffffff | on-surface | 10 | #1d1b20 |
| primary-container | 90 | #eaddff | surface-variant | 90 | #e7e0ec |
| on-primary-container | 10 | #21005d | on-surface-variant | 30 | #49454f |
| secondary | 40 | #625b71 | outline | 50 | #79747e |
| on-secondary | 100 | #ffffff | outline-variant | 80 | #cac4d0 |
| secondary-container | 90 | #e8def8 | surface-dim | 87 | #ded8e1 |
| on-secondary-container | 10 | #1d192b | surface-bright | 98 | #fef7ff |
| tertiary | 40 | #7d5260 | surface-container-lowest | 100 | #ffffff |
| on-tertiary | 100 | #ffffff | surface-container-low | 96 | #f7f2fa |
| tertiary-container | 90 | #ffd8e4 | surface-container | 94 | #f3edf7 |
| on-tertiary-container | 10 | #31111d | surface-container-high | 92 | #ece6f0 |
| error | 40 | #b3261e | surface-container-highest | 90 | #e6e0e9 |
| on-error | 100 | #ffffff | inverse-surface | 20 | #322f35 |
| error-container | 90 | #f9dedc | inverse-on-surface | 95 | #f5eff7 |
| on-error-container | 10 | #410e0b | inverse-primary | 80 | #d0bcff |
| background | 98 | #fef7ff | surface-tint (deprecated) | 40 | #6750a4 |
| on-background | 10 | #1d1b20 | shadow / scrim | 0 | #000000 |

### 3.4 Color roles — dark scheme (baseline)

| Role | Tone | Hex | Role | Tone | Hex |
| --- | --- | --- | --- | --- | --- |
| primary | 80 | #d0bcff | surface | 6 | #141218 |
| on-primary | 20 | #381e72 | on-surface | 90 | #e6e0e9 |
| primary-container | 30 | #4f378b | surface-variant | 30 | #49454f |
| on-primary-container | 90 | #eaddff | on-surface-variant | 80 | #cac4d0 |
| secondary | 80 | #ccc2dc | outline | 60 | #938f99 |
| on-secondary | 20 | #332d41 | outline-variant | 30 | #49454f |
| secondary-container | 30 | #4a4458 | surface-dim | 6 | #141218 |
| on-secondary-container | 90 | #e8def8 | surface-bright | 24 | #3b383e |
| tertiary | 80 | #efb8c8 | surface-container-lowest | 4 | #0f0d13 |
| on-tertiary | 20 | #492532 | surface-container-low | 10 | #1d1b20 |
| tertiary-container | 30 | #633b48 | surface-container | 12 | #211f26 |
| on-tertiary-container | 90 | #ffd8e4 | surface-container-high | 17 | #2b2930 |
| error | 80 | #f2b8b5 | surface-container-highest | 22 | #36343b |
| on-error | 20 | #601410 | inverse-surface | 90 | #e6e0e9 |
| error-container | 30 | #8c1d18 | inverse-on-surface | 20 | #322f35 |
| on-error-container | 90 | #f9dedc | inverse-primary | 40 | #6750a4 |
| background | 6 | #141218 | surface-tint (deprecated) | 80 | #d0bcff |
| on-background | 90 | #e6e0e9 | shadow / scrim | 0 | #000000 |

### 3.5 Fixed colors (identical in light and dark)

| Role | Hex | Role | Hex |
| --- | --- | --- | --- |
| primary-fixed | #eaddff | secondary-fixed | #e8def8 |
| primary-fixed-dim | #d0bcff | secondary-fixed-dim | #ccc2dc |
| on-primary-fixed | #21005d | on-secondary-fixed | #1d192b |
| on-primary-fixed-variant | #4f378b | on-secondary-fixed-variant | #4a4458 |
| tertiary-fixed | #ffd8e4 | on-tertiary-fixed | #31111d |
| tertiary-fixed-dim | #efb8c8 | on-tertiary-fixed-variant | #633b48 |

### 3.6 Usage rules

- **Roles are semantic, not decorative.** Use `primary` for the strongest actions,
  `secondary`/`tertiary` for less prominent ones, `error` for destructive states.
- **Container roles are fills.** Never use `*-container` for text or icons; pair
  each fill with its `on-*` companion.
- **Surface hierarchy** (tone-based, no tint): `surface` for backgrounds,
  `surface-container-lowest` to `surface-container-highest` for containment at
  increasing emphasis. `surface-tint` is deprecated.
  Recommended mapping: cards low emphasis → `surface-container-low`; dialogs and
  menus → `surface-container-high`; filled text fields → `surface-container-highest`.
- **`outline`** for important boundaries (text field outlines); **`outline-variant`**
  for decorative separation (dividers, card outlines).
- **Inverse roles** (`inverse-surface` / `inverse-on-surface` / `inverse-primary`)
  are for elements that must contrast against the current surface: snackbars,
  tooltips, selected states.
- **Fixed roles** keep the same tone in both themes (media overlays, content that
  must not change); they may fail contrast requirements — use with care.
- **`scrim`** for modal dimming (32% opacity recommended on dialogs), `shadow`
  for shadows.
- Role pairs are designed for at least **3:1** contrast; text pairs for 4.5:1
  (see §10).
- **Custom roles** (success, warning, info) are not part of M3; if needed, define
  them as extension tokens with the same tone discipline (fill + on + container).

---

## 4. Typography

### 4.1 Baseline type scale (15 styles)

| Role | Size | Token | Size (px) | Line height (px) | Weight | Tracking (px) |
| --- | --- | --- | --- | --- | --- | --- |
| Display | Large | `typescale-display-large` | 57 | 64 | 400 | -0.25 |
| Display | Medium | `typescale-display-medium` | 45 | 52 | 400 | 0 |
| Display | Small | `typescale-display-small` | 36 | 44 | 400 | 0 |
| Headline | Large | `typescale-headline-large` | 32 | 40 | 400 | 0 |
| Headline | Medium | `typescale-headline-medium` | 28 | 36 | 400 | 0 |
| Headline | Small | `typescale-headline-small` | 24 | 32 | 400 | 0 |
| Title | Large | `typescale-title-large` | 22 | 28 | 400 | 0 |
| Title | Medium | `typescale-title-medium` | 16 | 24 | 500 | +0.15 |
| Title | Small | `typescale-title-small` | 14 | 20 | 500 | +0.1 |
| Body | Large | `typescale-body-large` | 16 | 24 | 400 | +0.5 |
| Body | Medium | `typescale-body-medium` | 14 | 20 | 400 | +0.25 |
| Body | Small | `typescale-body-small` | 12 | 16 | 400 | +0.4 |
| Label | Large | `typescale-label-large` | 14 | 20 | 500 | +0.1 |
| Label | Medium | `typescale-label-medium` | 12 | 16 | 500 | +0.5 |
| Label | Small | `typescale-label-small` | 11 | 16 | 500 | +0.5 |

### 4.2 Emphasized type styles (M3 Expressive)

30 styles total: 15 baseline + 15 emphasized. Emphasized styles use heavier weight
(for variable fonts: the weight axis) and are used for selected states, unread
content, and key moments. Baseline and emphasized styles are designed to be used
together.

| Role | Size | Weight | Tracking (px) |
| --- | --- | --- | --- |
| Display | Large / Medium / Small | 400 | -0.25 / 0 / 0 |
| Headline | Large / Medium / Small | 400 | 0 / 0 / 0 |
| Title | Large / Medium / Small | 500 | 0 / +0.15 / +0.1 |
| Body | Large / Medium / Small | 500 | +0.5 / +0.25 / +0.4 |
| Label | Large / Medium / Small | 500 | +0.1 / +0.5 / +0.5 |

Sizes and line heights are identical to the baseline table above; the difference is
weight (and minor tracking adjustments where the family supports them). *(verify the
exact emphasized weights against the current Figma kit; implementations ship the
baseline set first)*

### 4.3 Font families

| Font | Role | Notes |
| --- | --- | --- |
| Roboto | Default M3 typeface | Static and variable versions; 3,300+ glyphs |
| Roboto Flex | Expressive customization | Variable axes; used by M3 for adaptive line heights |
| Roboto Serif | Editorial/reading | Comfortable long-form reading |
| Roboto Mono | Code/monospace | For technical content |

Line heights can adapt to language script height:

| Category | Increase | Example scripts |
| --- | --- | --- |
| Small | baseline | Latin |
| Medium | ~7% | Arabic, Bengali, Chinese, Hindi, Japanese, Korean, Thai |
| Large | ~30% | Burmese, Telugu |
| Extra large | ~100% | Nastaliq |

### 4.4 Usage mapping (component → type role)

| Component | Role |
| --- | --- |
| Buttons (all sizes) | label-large |
| Chips | label-large |
| Tabs | title-small *(per Compose implementation)* |
| Dialogs: title | headline-small |
| Dialogs: body | body-medium |
| Dialogs: action buttons | label-large |
| Lists: primary label | body-large |
| Lists: supporting text | body-medium |
| Lists: overline | label-small |
| List: trailing text | label-small |
| Menus: items | label-large |
| Text fields: input | body-large |
| Text fields: label (floating) | body-small *(verify)* |
| Text fields: supporting/error text | body-small |
| Snackbar: text | body-medium |
| Snackbar: action | label-large |
| Tooltips (plain) | label-medium *(verify)*; M3 page marked typography as image-only |
| Badges (large) | label-small |
| Top app bar: title (small) | title-large |

Readability minimums: body text 12px, labels 11px. Keep line-height ratios:
~1.2 for headline styles, 1.4-1.5 for body text.

---

## 5. Shape

### 5.1 Corner radius scale (2025 version, 10 levels)

| Token | Value | Notes |
| --- | --- | --- |
| `corner-none` | 0dp | |
| `corner-extra-small` | 4dp | |
| `corner-small` | 8dp | |
| `corner-medium` | 12dp | |
| `corner-large` | 16dp | |
| `corner-large-increased` | 20dp | Added May 2025 |
| `corner-extra-large` | 28dp | |
| `corner-extra-large-increased` | 32dp | Added May 2025 |
| `corner-extra-extra-large` | 48dp | Added May 2025 |
| `corner-full` | fully rounded | Pill/circle; previously expressed as 50% of size |

Notes:

- Directional variants exist (top/start/end), e.g., `extra-small-top` 4dp,
  `large-top` 16dp — used by menus, tabs, sheets, and split buttons.
- **Optical roundness rule**: inner radius = outer radius − padding
  (e.g., 48dp outer − 14dp padding = 34dp inner).
- Shape morphing (Expressive): components animate between corner values; buttons
  morph when pressed/selected (§9.1).
- "Cut" corner shapes exist in the Expressive shape library (35 shapes) but are
  not expressible with plain corner radii; skip for now.

### 5.2 Component default shapes

| Component | Shape |
| --- | --- |
| Buttons (round) | full |
| Buttons (square, Expressive) | XS/S 12dp, M 16dp, L/XL 28dp |
| Button pressed morph | XS/S 8dp, M 12dp, L/XL 16dp |
| Icon buttons | full (round) or same scale as buttons (square) |
| FAB (regular / small / large) | 16dp / 12dp / 28dp |
| Cards | 12dp |
| Dialogs (basic / full-screen) | 28dp / 0dp |
| Text fields (filled) | top corners 4dp, bottom 0 |
| Text fields (outlined) | 4dp |
| Menus | 4dp (baseline); directional inner corners for Expressive |
| Chips | 8dp |
| Snackbar | 4dp |
| Tooltip (plain / rich) | 4dp / 4dp *(verify rich)* |
| List items (baseline / Expressive selected) | 0dp / 16dp outer + 4dp inner |
| Tabs active indicator | 3dp tall, top corners fully rounded, 2dp inset; secondary tabs 2dp tall |
| Checkbox | 2dp |
| Badge (small / large) | full / 8dp |
| Segmented buttons | full (pill), 1dp outline |
| Sliders (Expressive sizes XS→XL) | 8 / 8 / 12 / 16 / 28dp |

---

## 6. Elevation

| Level | dp | Typical use |
| --- | --- | --- |
| 0 | 0dp | Flat surfaces; filled/tonal/outlined/text buttons, outlined cards |
| 1 | 1dp | Elevated buttons/cards/chips, modal drawer |
| 2 | 3dp | Scrolled app bar, menus, navigation bar, toolbar |
| 3 | 6dp | FAB (resting), dialogs, date/time pickers, snackbar |
| 4 | 8dp | Hover/raised interactive states (e.g., FAB hover, dragged list item) |
| 5 | 12dp | Only transient states (hover, dragged) |

Guidance:

- Elevation orders components relative to each other; it is not decoration.
- **Surface tint is deprecated.** Depth is expressed with tone-based surface
  containers (light: containers get slightly darker/lighter; dark: containers get
  lighter). Combine with shadows only for raised elements.
- Hover/focus usually raise elevation by one level.
- Godot approximation (proposed, tune visually): `StyleBoxFlat` shadow
  offset-y ≈ 1, 2, 3, 4, 6 px and shadow_size (blur) ≈ 2, 4, 8, 12, 18 px for
  levels 1-5, shadow color black at 12-20% alpha. In dark theme, rely mainly on
  the next surface-container tone plus a soft shadow.

---

## 7. Motion

### 7.1 Durations

| Token | Value | Token | Value |
| --- | --- | --- | --- |
| `short1` | 50ms | `medium1` | 250ms |
| `short2` | 100ms | `medium2` | 300ms |
| `short3` | 150ms | `medium3` | 350ms |
| `short4` | 200ms | `medium4` | 400ms |
| `long1` | 450ms | `extra-long1` | 700ms |
| `long2` | 500ms | `extra-long2` | 800ms |
| `long3` | 550ms | `extra-long3` | 900ms |
| `long4` | 600ms | `extra-long4` | 1000ms |

### 7.2 Easings (legacy set, still valid)

| Name | cubic-bezier | Usage |
| --- | --- | --- |
| Emphasized | Android PathInterpolator `M 0,0 C 0.05,0 0.133,0.06 0.167,0.4 C 0.208,0.82 0.25,1 1,1`; web fallback = standard | Most transitions that begin and end on screen |
| Emphasized decelerate | `(0.05, 0.7, 0.1, 1.0)` | Elements entering the screen |
| Emphasized accelerate | `(0.3, 0.0, 0.8, 0.15)` | Elements exiting permanently |
| Standard | `(0.2, 0.0, 0.0, 1.0)` | Small utility transitions; fallback for emphasized |
| Standard decelerate | `(0.0, 0.0, 0.0, 1.0)` | Entering (standard set) |
| Standard accelerate | `(0.3, 0.0, 1.0, 1.0)` | Exiting (standard set) |

Recommended pairs: emphasized 500ms; emphasized-decelerate 400ms (enter);
emphasized-accelerate 200ms (exit); standard 300ms; standard-decelerate 250ms;
standard-accelerate 200ms. Selection controls use 200ms standard.

### 7.3 Springs (M3 Expressive, May 2025)

Token shape: `md.sys.motion.spring.{fast|default|slow}.{spatial|effects}`.
The scheme (expressive/standard) is selected per product, not per token.
Spatial springs animate position/size/rotation/corner radius and may overshoot;
effects springs animate color/opacity and never overshoot.

| Scheme | Token | Curve (cubic-bezier) | Duration |
| --- | --- | --- | --- |
| Expressive | fast spatial | (0.42, 1.67, 0.21, 0.90) | 350ms |
| Expressive | default spatial | (0.38, 1.21, 0.22, 1.00) | 500ms |
| Expressive | slow spatial | (0.39, 1.29, 0.35, 0.98) | 650ms |
| Expressive | fast effects | (0.31, 0.94, 0.34, 1.00) | 150ms |
| Expressive | default effects | (0.34, 0.80, 0.34, 1.00) | 200ms |
| Expressive | slow effects | (0.34, 0.88, 0.34, 1.00) | 300ms |
| Standard | fast spatial | (0.27, 1.06, 0.18, 1.00) | 350ms |
| Standard | default spatial | (0.27, 1.06, 0.18, 1.00) | 500ms |
| Standard | slow spatial | (0.27, 1.06, 0.18, 1.00) | 750ms |
| Standard | fast effects | (0.31, 0.94, 0.34, 1.00) | 150ms |
| Standard | default effects | (0.34, 0.80, 0.34, 1.00) | 200ms |
| Standard | slow effects | (0.34, 0.88, 0.34, 1.00) | 300ms |

Compose spring parameters (damping ratio / stiffness):

| Scheme | Spatial fast / default / slow | Effects fast / default / slow |
| --- | --- | --- |
| Expressive | 0.6/800, 0.8/380, 0.8/200 | 1.0/3800, 1.0/1600, 1.0/800 |
| Standard | 0.9/1400, 0.9/700, 0.9/300 | 1.0/3800, 1.0/1600, 1.0/800 |

Godot implementation notes: durations are milliseconds. For curves, expose a small
cubic-bezier sampler (sample each easing into a `Curve`, then drive values with
`Tween.tween_method` using the sampled value). For springs, either approximate
with the curves above (web-compatible path) or solve a damped oscillator per frame
for true overshoot.

---

## 8. Interaction states

### 8.1 State layers

| State | Opacity |
| --- | --- |
| Hover | 8% (0.08) |
| Focus | 10% (0.10) |
| Pressed | 10% (0.10) |
| Dragged | 16% (0.16) |

- State layer color = component content color (`on-*` role of the container).
- Only one state layer visible at a time; focus + hover combine by showing focus.
- Old material-web tokens (`v0.192`) still list focus/pressed as 0.12; the current
  M3 spec and Compose (`v0.210`) use 0.10. **Use 0.08 / 0.10 / 0.10 / 0.16.**
- State layer shape follows the component shape; sizes: 40dp layer on a 48dp target
  (icon buttons).

### 8.2 Disabled

| Element | Opacity |
| --- | --- |
| Content (text/icon) | 38% (0.38) |
| Container | 12% (0.12) |

Disabled components do not show hover/focus/pressed layers, are not focusable, and
are exempt from contrast requirements.

### 8.3 Targets and focus

| Item | Value |
| --- | --- |
| Minimum touch target | 48x48dp |
| Minimum pointer (mouse) target | 44x44dp |
| Target spacing | ≥ 8dp |
| Focus indicator | Visible ring on keyboard focus (Godot: 2px outline in primary color with offset; M3 leaves exact thickness to platforms) |

---

## 9. Component specifications

All measurements are dp. "Colors" lists roles as container / content.

### 9.1 Buttons

Variants: **elevated, filled (default), tonal, outlined, text**; Expressive adds
toggle (selection) mode, five sizes, and square shape.

Baseline sizes: height 40dp (default "small"), fully rounded, icon 18dp,
label-large.

Expressive size axis:

| Size | Height | Notes |
| --- | --- | --- |
| XS | 32dp | Target area must still be ≥ 48x48dp |
| S (default) | 40dp | Padding 16dp (24dp is legacy / not recommended) |
| M | 48dp | |
| L | 56dp | |
| XL | 96dp | |

Corner sizes (Expressive):

| | XS | S | M | L | XL |
| --- | --- | --- | --- | --- | --- |
| Round | full | full | full | full | full |
| Square | 12 | 12 | 16 | 28 | 28 |
| Pressed morph | 8 | 8 | 12 | 16 | 16 |

Color mapping:

| Style | Container | Content |
| --- | --- | --- |
| Elevated | surface-container-low (+ elevation 1) | primary |
| Filled | primary | on-primary |
| Tonal | secondary-container | on-secondary-container |
| Outlined | transparent + 1dp outline | primary |
| Text | transparent | primary |

State summary (filled): hover/focus/pressed state layer = on-primary at §8.1
opacities; disabled container 12%, content 38%. Outlined hover outline = outline;
focus outline = primary; pressed outline = outline. Elevation: elevated button
level 1 default, 0 disabled; filled/tonal/outlined/text level 0.

Material Web token defaults (baseline S): height 40px; padding 24px (16px with
leading icon: 16/24; trailing icon: 24/16); text button padding 12px; icon 18px;
label-large.

### 9.2 Icon buttons

Variants: filled (default), tonal, outlined, standard; default and toggle modes.
Baseline container 40x40dp, icon 24dp; Expressive adds sizes XS, S, M, L, XL and
narrow/wide widths, plus square shapes with the same corner scale as buttons
(XS/S 12, M 16, L/XL 28; pressed 8/12/16). XS and S need ≥ 48x48dp target areas.

| Style | Default (unselected) | Toggle selected |
| --- | --- | --- |
| Filled | primary / on-primary | primary / on-primary |
| Tonal | secondary-container / on-secondary-container | secondary / on-secondary |
| Outlined | outline variant + on-surface-variant | inverse-surface / inverse-on-surface |
| Standard | on-surface-variant | primary |

State layers: hover 8%, focus 10%, pressed 10% (§8.1).

### 9.3 FAB

| Element | Value |
| --- | --- |
| Sizes | regular 56dp; small 40dp (deprecated); medium 80dp (Expressive); large 96dp |
| Corner | regular 16dp; small 12dp; large 28dp |
| Icon | 24dp (large: 36dp) |
| Colors | primary-container / on-primary-container (default); secondary- and tertiary-container variants; Expressive adds primary/secondary/tertiary |
| Elevation | level 3 resting; hover level 4; pressed level 3; state layer 8/10/10% |
| Rule | State layer color equals the icon color |

### 9.4 Segmented buttons

| Element | Value |
| --- | --- |
| Container height | 40dp (density step removes 4dp) |
| Outline | 1dp |
| Padding | min 12dp left/right; 8dp between elements |
| Shape | full (pill) |
| Colors | outline, on-surface; selected segment: secondary-container / on-secondary-container |
| Target | 48dp |

### 9.5 Chips

All variants: height 32dp, corner 8dp, icon 18dp, label-large, 8dp between
elements, 16dp horizontal padding without icon, 8dp with icon.

| Variant | Colors | Notes |
| --- | --- | --- |
| Assist | on-surface + outline (+ optional surface-container-low) | Leading icon or avatar |
| Filter | on-surface-variant + outline-variant; selected: secondary-container / on-secondary-container | Checkmark when selected |
| Input | on-surface-variant; avatar 24dp (radius 12); close icon target ≥ 48dp | |
| Suggestion | on-surface-variant + outline | |

States: enabled, disabled, hover, focus, pressed, dragged (selected/unselected).

### 9.6 Text fields

Two variants, both 56dp container height, target 56dp.

| Attribute | Filled | Outlined |
| --- | --- | --- |
| Container | surface-container-highest, bottom indicator 1dp on-surface-variant | outline 1dp |
| Focus indicator | primary, 2dp (filled) | primary, 2dp (outlined) |
| Label (resting/populated) | on-surface-variant; floats to top | on-surface-variant; floats into border gap |
| Input text | on-surface, body-large | on-surface, body-large |
| Caret | primary | primary |
| Supporting text | on-surface-variant, body-small, 4dp top padding | same |
| Padding | 16dp L/R without icons; 12dp with icons; 8dp top/bottom | 16dp L/R without icons; 12dp with icons |
| Icon/text gap | 16dp | 16dp |
| Label offset (populated) | — | 4dp L/R |

Error state: error color for indicator/label/caret/supporting text.

### 9.7 Cards

| Variant | Container | Elevation | Border |
| --- | --- | --- | --- |
| Elevated | surface-container-low | 1 | none |
| Filled | surface-container-highest | 0 | none |
| Outlined | surface | 0 | 1dp outline-variant |

Corner 12dp, padding 16dp *(core values; full spec table not captured)*.

### 9.8 Dialogs

Basic dialog:

| Element | Value |
| --- | --- |
| Width | min 280dp, max 560dp |
| Container | surface-container-high, corner 28dp, level 3 |
| Padding | 24dp (all sides) |
| Gap title→body | 16dp; icon→title 16dp; body→actions 24dp |
| Icon | 24dp, secondary, optional, centered |
| Title | headline-small, on-surface, start-aligned (centered with icon) |
| Body | body-medium, on-surface-variant |
| Actions | text buttons (primary), label-large, 8dp between, aligned end |
| Scrim | scrim color at ~32% |

Full-screen dialog: full container width (max 560dp), corner 0, header 56dp,
bottom action bar 56dp, padding 24dp top/left/right, 8dp between elements.

### 9.9 Lists

| Attribute | Value |
| --- | --- |
| Item heights | 1-line 56dp, 2-line 72dp, 3-line 88dp |
| Label | body-large, on-surface, left padding 16dp |
| Supporting text | body-medium, on-surface-variant |
| Overline | label-small, on-surface-variant |
| Leading/trailing icons | 24dp, on-surface-variant |
| Leading/trailing padding | 16dp |
| Divider | 1dp outline-variant; full width or inset 16dp left / 24dp right |
| Target | 48dp per slot |
| Selected trailing icon | primary |
| Expressive item | corner 16dp outer / 4dp inner; selected 16dp |

List states use state layers on-surface (hover 8%, focus 10%, pressed 10%);
dragged items raise to level 4; disabled label opacity 30% (list), icons 38%.

### 9.10 Menus

| Attribute | Value |
| --- | --- |
| Container | surface-container, level 2, corner 4dp, min 112dp / max 280dp width |
| Vertical padding | 8dp (list), item height 48dp |
| Item padding | 12dp between elements / 12dp left-right |
| Icons | 24dp leading/trailing |
| Divider | 8dp top/bottom padding, 1dp tall |
| Label | label-large, on-surface |
| State layer | on-surface 8% |
| Disabled | 38% content |

Baseline item colors: label on-surface; supporting on-surface-variant; selected
state uses surface-container-highest (or tertiary-container in Expressive vibrant
menus). Expressive vertical menus introduce corner/width updates *(not captured in
text)*.

### 9.11 Tabs

| Attribute | Value |
| --- | --- |
| Height | 48dp (label only), 64dp (icon + label) |
| Divider | 1dp, outline-variant, inside the container |
| Primary active indicator | 3dp tall, top fully rounded, 2dp inset each side, min length 24dp; primary |
| Secondary active indicator | pill behind label+icon, 2dp-tall indicator base *(per page)* |
| Icon | 24dp; gap to text 8dp; badge gap 4dp |
| Colors (primary tabs) | active: primary label/indicator; inactive: on-surface-variant; surface background |
| Colors (secondary tabs) | active container: on-surface; inactive: on-surface-variant |
| Target | 48dp |

### 9.12 Switch

| Element | Value |
| --- | --- |
| Track | 52x32dp, corner full, 2dp outline |
| Handle | 16dp unselected (24dp with icon), 24dp selected, 28dp pressed; corner full |
| State layer | 40dp circle; target 48dp |
| Icon | 16dp (optional, on selected or both states) |
| Colors | track off: surface-container-highest + outline border; track on: primary; handle on: on-primary, icon on-primary-container |

### 9.13 Checkbox

| Element | Value |
| --- | --- |
| Container | 18dp, corner 2dp, 2dp border |
| Checkmark | 18dp, on-primary |
| State layer | 40dp, target 48dp |
| Colors | checked: primary / on-primary; unchecked border: on-surface-variant; error variant: error / on-error |
| Label | on-surface (unchanged in all states) |

### 9.14 Radio button

| Element | Value |
| --- | --- |
| Radio icon | 20dp |
| State layer | 40dp; target 48dp |
| Colors | selected: primary; unselected: on-surface-variant |
| Label | on-surface |

### 9.15 Sliders

Baseline: track 4dp, handle ≈ 20dp *(verify)*, primary active track with
secondary-container inactive track, value indicator (level 3, corner 4dp).

Expressive sizes:

| Size | Handle height | Track height | Track corner | Icon (inset) |
| --- | --- | --- | --- | --- |
| XS | 44dp | 16dp | 8dp | none |
| S | 44dp | 24dp | 8dp | none |
| M | 52dp | 40dp | 12dp | 24dp |
| L | 68dp | 56dp | 16dp | 24dp |
| XL | 108dp | 96dp | 28dp | 32dp |

Value indicator label: 44dp container, 48dp min width; colors inverse-surface /
inverse-on-surface; label-large.

### 9.16 Progress indicators

| Element | Value |
| --- | --- |
| Linear track | 4dp thick, 4dp edge inset; active indicator primary; track secondary-container; stop indicator primary |
| Circular | 4dp stroke, ≈ 40dp diameter *(verify)*; rotated 4dp gap between arcs |
| Wavy/expressive variants | thickness and waveform configurable (values image-only) |

### 9.17 Snackbar

| Element | Value |
| --- | --- |
| Height | 48dp single line, 68dp two lines |
| Container | inverse-surface, corner 4dp, level 3, padding 16dp |
| Supporting text | body-medium, inverse-on-surface |
| Action | label-large, inverse-primary, text button |
| Icon (close) | 24dp, inverse-on-surface |

### 9.18 Tooltips

Plain tooltip: container height 24dp, 8dp padding, corner 4dp *(verify)*,
inverse-surface container, inverse-on-surface text, label-medium *(verify)*.

Rich tooltip: padding top/bottom 12dp/8dp, left/right 16dp; on-surface-variant
subhead/supporting; surface-container background; primary text buttons (up to 2).

### 9.19 Badges

| Element | Value |
| --- | --- |
| Small badge | 6dp dot, 3dp corner radius (effectively full) |
| Large badge | 16dp height (one digit), up to 34dp wide; 8dp corner |
| Offsets | small 6x6dp, large 14x12dp from icon corner |
| Colors | error / on-error (error container options exist) |
| Label | label-small |

### 9.20 Dividers

| Element | Value |
| --- | --- |
| Thickness | 1dp *(verify; standard)* |
| Colors | outline-variant |
| Inset | full width, or 16dp left (inset) / 16dp both (middle-inset) |
| Margins | 4dp to supporting text; 8dp right/bottom in some layouts |

### 9.21 Top app bars

| Variant | Height | Title |
| --- | --- | --- |
| Small | 64dp *(verify)* | title-large, on-surface |
| Medium | 112dp *(verify)* | headline-small, on-surface |
| Large | 152dp *(verify)* | headline-medium, on-surface |

Colors: surface; on-scroll → surface-container; leading/trailing icon buttons;
expressive variants add search bars and flexible (shrinking) bars.

---

## 10. Accessibility

| Item | Requirement |
| --- | --- |
| Touch target | 48x48dp minimum |
| Mouse target | 44x44dp minimum |
| Target spacing | ≥ 8dp |
| Contrast: small text | ≥ 4.5:1 |
| Contrast: large text | ≥ 3:1 (large = 18pt regular / 14pt bold and up) |
| Contrast: UI/graphics | ≥ 3:1 for essential boundaries (container vs background, icons) |
| Contrast: role pairs | M3 role pairs are designed for ≥ 3:1 |
| Disabled | Exempt from contrast requirements |
| Focus | Visible keyboard focus ring; never remove without replacement |
| Motion | Provide reduce-motion behavior (skip/shorter animations) where feasible |
| Color | Never use color as the only indicator (pair with icon/text/shape) |

---

## 11. Iconography

Material Symbols (Apache-2.0) is the M3 icon set.

| Item | Value |
| --- | --- |
| Styles | Outlined (2dp stroke, dense UIs), Rounded (matches M3 geometry), Sharp |
| FILL axis | 0 (outline) to 1 (filled); animate for selected states |
| Weight axis | 100-700; regular 400; avoid < 200 at 24dp |
| Grade axis | -50 to 200; -25 for light-on-dark; positive for emphasis |
| Optical size axis | 20-48; default 24; 20 for dense desktop, 40-48 for hero actions |
| Defaults | opsz 24, weight 400, grade 0, fill 0 |
| Sizes in components | 24dp standard; 18-20dp inside buttons/chips; 16dp inside switches |

---

## 12. Dynamic color

How Material generates a scheme from a seed color (baseline algorithm):

1. Convert the seed to HCT and derive hue and chroma.
2. Build six tonal palettes: primary, secondary (lower chroma), tertiary
   (complementary hue), neutral, neutral-variant, error (fixed red hue by default).
3. Map fixed tones of those palettes to the ~40 color roles for light and dark.
4. Optional contrast level (standard / medium / high) shifts tones until contrast
   targets are met.

Algorithm variants (Material Theme Builder choices): Tonal Spot (default),
Vibrant, Expressive, Content, Fidelity, Rainbow, Fruit Salad, Neutral, Monochrome.

Reference implementation: `material-color-utilities` (Java/TypeScript/C++/Swift,
Apache-2.0) — contains HCT, palette generation, and scheme mapping.

Godot plan: start with the two baseline schemes from §3 as static constants
(deterministic, no runtime cost). Keep the color system abstracted behind a
scheme object so a seed-based generator can be added later (either a GDScript
port of the tone-mapping step or a precomputed set of alternative schemes).

---

## 13. Godot Copilot implementation mapping (concept)

### 13.1 Approach

The plugin moves from "follow the Godot editor theme" to **its own design system**:

- All widgets are **standalone components derived from built-in Godot controls**
  (e.g., `extends Button`, `extends PanelContainer`), living in `src/ui/md3/`.
- Components are **self-contained**: they compute their own StyleBoxes, fonts,
  colors, and state layers from the scheme; they never depend on the editor theme.
- The scheme is injected once per UI tree (dock, dialogs) and can switch between
  light and dark.

### 13.2 Planned modules

| Module | Class | Responsibility |
| --- | --- | --- |
| Tokens | `CopilotMd3Tokens` | Constants: palettes, role maps (light/dark), type scale, shape, elevation, states, motion values |
| Scheme | `CopilotMd3Scheme` | Resolves role strings to Colors; light()/dark() builders; role usage helpers |
| Typography | (part of tokens) | Type style helper: size, weight, tracking, line height per style name |
| Motion | `CopilotMd3Motion` | Durations, easings, spring curves, cubic-bezier sampler, `Tween` helpers |
| State layer | `CopilotMd3StateLayer` | ColorRect-based overlay driving hover/focus/pressed/dragged opacities |
| Icons | `CopilotMd3Icons` | Bundled Material Symbols SVGs (curated subset) with editor-icon fallback |

### 13.3 Component inventory (M3 → Godot)

| M3 component | Base control | Planned class |
| --- | --- | --- |
| Filled/tonal/outlined/text/elevated button | `Button` | `CopilotMd3Button` (variant + size + toggle properties) |
| Icon button | `Button` | `CopilotMd3IconButton` |
| Segmented buttons | `Button` + `HBoxContainer` | `CopilotMd3SegmentedButtons` |
| Chip | `Button` | `CopilotMd3Chip` |
| Text field (filled/outlined) | `VBoxContainer` + `LineEdit` | `CopilotMd3TextField` (label, supporting text, error) |
| Card / surface | `PanelContainer` | `CopilotMd3Card` (elevated/filled/outlined) |
| Dialog | `AcceptDialog` | `CopilotMd3Dialog` base (28dp radius, 24dp padding, headline-small title, text-button actions) |
| List item | `Button` | `CopilotMd3ListItem` (1/2/3-line, leading/trailing) |
| Menu | `PopupMenu` (restyled) | `CopilotMd3Menu` helper: 48dp items, 4dp corner, 8dp vertical padding |
| Tabs (primary) | custom + `MarginContainer` | `CopilotMd3TabBar` (3dp indicator, 48/64dp heights) |
| Switch | `CheckButton` (custom draw) | `CopilotMd3Switch` (52x32 track, animated 16→24 handle) |
| Checkbox | `CheckBox` (custom draw) | `CopilotMd3Checkbox` (18dp, 2dp corner) |
| Radio | `CheckBox` group (custom draw) | `CopilotMd3Radio` (20dp) |
| Slider | `HSlider` (restyled) | `CopilotMd3Slider` |
| Progress (linear) | `ProgressBar` (restyled) | `CopilotMd3LinearProgress` |
| Progress (circular) | `Control` (custom draw) | `CopilotMd3CircularProgress` |
| Snackbar | `PanelContainer` overlay | `CopilotMd3Snackbar` + host |
| Tooltip | `PopupPanel` | `CopilotMd3Tooltip` (plain style) |
| Badge | `Control` | `CopilotMd3Badge` |
| Divider | `HSeparator`/`Control` | `CopilotMd3Divider` |

### 13.4 Mapping rules

- **Elevation**: `StyleBoxFlat` (shadow approximations from §6; dark theme uses
  surface-container tones as primary depth cue).
- **State layers**: overlay `ColorRect` (mouse filter ignore) above the component
  background, color = content role, alpha per §8.1; no ripple needed for a desktop
  editor (optional focus ring via `_draw`).
- **Motion**: `create_tween()` with the durations from §7.1; custom curves sampled
  from §7.2/7.3; respect a reduce-motion setting if the editor offers one.
- **Fonts**: decide between bundling Roboto (Apache-2.0, authentic M3) or starting
  from the editor font with M3 metrics — see open decisions.
- **Sizing**: M3 dp treated as px (desktop); no global scale factor in the first
  rollout (density control reserved for later).
- **Light/dark**: detect from the editor theme's base color brightness, with a
  manual override in plugin settings.
- **Custom semantic roles**: success/warning/info are extension tokens (fill +
  on + container), clearly separated from M3 roles.

### 13.5 Chat-specific patterns

| Element | M3 mapping |
| --- | --- |
| User message | `primary-container` bubble, corner 16dp with 4dp bottom-end |
| Assistant message | `surface-container-high` card, corner 16dp, on-surface text |
| Tool row | `surface-container-low` card, outline-variant border, label-medium title |
| Permission card | elevated card (level 1), 28dp tertiary icon badge, filter-chip scope options, text + tonal + filled actions |
| Status bar | label-small, state dot + text, status colors from extension roles |
| Composer | surface-container-highest pill, full corner (24dp when multiline), filled send + tonal stop icon buttons |

---

## 14. Known gaps to verify at implementation time

1. Emphasized type weights (verify against current Figma kit / Roboto Flex axes).
2. Expressive button paddings for M/L/XL; expressive icon button size numbers.
3. Plain tooltip corner radius and typography; rich tooltip corner radius.
4. Circular progress default diameter; slider handle size (baseline).
5. Cards, top app bars, full-screen dialogs: complete measurement tables.
6. Menus: Expressive vertical menu updated measurements.
7. Elevation shadow render values (our `StyleBoxFlat` approximations need visual
   tuning in the editor).
8. Roboto subset to bundle (weights, license file placement).

---

## 15. Document status

This file is reference data only. The plugin's visual design (how these tokens are
applied to the dock, chat view, dialogs, and cards) is specified in
`docs/DESIGN.md` once the component library exists.
