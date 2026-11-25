---
name: Clinical Precision
colors:
  surface: '#faf8ff'
  surface-dim: '#d2d9f4'
  surface-bright: '#faf8ff'
  surface-container-lowest: '#ffffff'
  surface-container-low: '#f2f3ff'
  surface-container: '#eaedff'
  surface-container-high: '#e2e7ff'
  surface-container-highest: '#dae2fd'
  on-surface: '#131b2e'
  on-surface-variant: '#3f4945'
  inverse-surface: '#283044'
  inverse-on-surface: '#eef0ff'
  outline: '#6f7975'
  outline-variant: '#bec9c4'
  surface-tint: '#076b59'
  primary: '#005445'
  on-primary: '#ffffff'
  primary-container: '#0f6e5c'
  on-primary-container: '#9bedd6'
  inverse-primary: '#84d6c0'
  secondary: '#006398'
  on-secondary: '#ffffff'
  secondary-container: '#5bb8fe'
  on-secondary-container: '#00476e'
  tertiary: '#3b4b60'
  on-tertiary: '#ffffff'
  tertiary-container: '#536379'
  on-tertiary-container: '#cfdffa'
  error: '#ba1a1a'
  on-error: '#ffffff'
  error-container: '#ffdad6'
  on-error-container: '#93000a'
  primary-fixed: '#a0f2db'
  primary-fixed-dim: '#84d6c0'
  on-primary-fixed: '#002019'
  on-primary-fixed-variant: '#005142'
  secondary-fixed: '#cce5ff'
  secondary-fixed-dim: '#93ccff'
  on-secondary-fixed: '#001d31'
  on-secondary-fixed-variant: '#004b73'
  tertiary-fixed: '#d3e4fe'
  tertiary-fixed-dim: '#b7c8e1'
  on-tertiary-fixed: '#0b1c30'
  on-tertiary-fixed-variant: '#38485d'
  background: '#faf8ff'
  on-background: '#131b2e'
  surface-variant: '#dae2fd'
typography:
  display-lg:
    fontFamily: Plus Jakarta Sans
    fontSize: 36px
    fontWeight: '700'
    lineHeight: 44px
    letterSpacing: -0.02em
  display-lg-mobile:
    fontFamily: Plus Jakarta Sans
    fontSize: 28px
    fontWeight: '700'
    lineHeight: 36px
    letterSpacing: -0.01em
  headline-xl:
    fontFamily: Plus Jakarta Sans
    fontSize: 28px
    fontWeight: '600'
    lineHeight: 36px
    letterSpacing: -0.02em
  headline-xl-mobile:
    fontFamily: Plus Jakarta Sans
    fontSize: 22px
    fontWeight: '600'
    lineHeight: 30px
    letterSpacing: -0.01em
  headline-lg:
    fontFamily: Plus Jakarta Sans
    fontSize: 20px
    fontWeight: '600'
    lineHeight: 28px
    letterSpacing: -0.01em
  headline-md:
    fontFamily: Plus Jakarta Sans
    fontSize: 16px
    fontWeight: '600'
    lineHeight: 24px
    letterSpacing: 0em
  body-lg:
    fontFamily: Inter
    fontSize: 16px
    fontWeight: '400'
    lineHeight: 24px
  body-md:
    fontFamily: Inter
    fontSize: 14px
    fontWeight: '400'
    lineHeight: 20px
  body-sm:
    fontFamily: Inter
    fontSize: 12px
    fontWeight: '400'
    lineHeight: 18px
  label-lg:
    fontFamily: Inter
    fontSize: 14px
    fontWeight: '500'
    lineHeight: 20px
  label-md:
    fontFamily: Inter
    fontSize: 12px
    fontWeight: '600'
    lineHeight: 16px
    letterSpacing: 0.02em
  label-sm:
    fontFamily: Inter
    fontSize: 10px
    fontWeight: '700'
    lineHeight: 14px
    letterSpacing: 0.04em
  data-mono:
    fontFamily: Inter
    fontSize: 13px
    fontWeight: '500'
    lineHeight: 18px
rounded:
  sm: 0.25rem
  DEFAULT: 0.5rem
  md: 0.75rem
  lg: 1rem
  xl: 1.5rem
  full: 9999px
spacing:
  gutter: 1rem
  gutter-mobile: 0.75rem
  gutter-desktop: 1.5rem
  margin: 1rem
  margin-tablet: 1.5rem
  margin-desktop: 2rem
  space-xs: 0.25rem
  space-sm: 0.5rem
  space-md: 1rem
  space-lg: 1.5rem
  space-xl: 2rem
  space-2xl: 3rem
---

## Brand & Style

This design system serves high-stakes hospital pharmacy environments where cognitive load must remain minimal, precision is non-negotiable, and clinical trust is paramount. Pharmacists, pharmacy technicians, and floor nurses use this interface under time-sensitive, safety-critical conditions—verifying drug interactions, tracking regulated lot numbers, managing unit doses, and acknowledging emergency dispensing queues.

The visual style blends **Corporate / Modern** clinical discipline with contemporary product refinement:
- **Atmosphere:** Sterile yet approachable; crisp, composed, and deliberate. High legibility dominates every interaction.
- **Cognitive Clarity:** Dense drug inventories, dosage equations, and lot tracking numbers are organized with uncompromising typographic rhythm and zero visual ambiguity.
- **Trust & Accountability:** Interfaces prioritize validation states, definitive status tokens, and clear audit-trail semantics over decorative flourishes.

## Colors

The palette establishes an immediate medical identity centered around deep clinical teal, anchored by an ultra-clean slate neutral tier and rigorous functional alert values.

### Palette Architecture
- **Primary (`#0f6e5c`):** Deep Pharmacy Teal. Communicates pharmacological authority, sterility, and institutional grounding. Applied to global actions, active navigation anchors, primary confirmation triggers, and authoritative brand cues.
- **Secondary (`#0284c7`):** Clinical Cyan / Dispensing Blue. Used for secondary analytical callouts, order flow progression, batch routing, and informational badges.
- **Tertiary (`#64748b`):** Muted Slate. Governs structural metadata, table header taxonomy, field labels, and secondary interactive borders.
- **Neutral Canvas & Surfaces:**
  - Base background: `#f8fafc` (Slate 50) on desktop; alternating `#f1f5f9` (Slate 100) on viewports for nested grouping.
  - Card & sheet surfaces: `#ffffff` strictly, offering pristine contrast against soft slate backdrops.
  - High-emphasis text: `#0f172a` (Slate 900) for uncompromised readability of medicine formulations and lot IDs.
  - Medium-emphasis text: `#334155` (Slate 700).
  - Low-emphasis / Placeholder: `#94a3b8` (Slate 400).
- **Clinical Status Matrix:**
  - **Success / Verified (`#10b981`):** Stock in good order, prescription approved, dose matched. Paired with soft tint `#ecfdf5`.
  - **Warning / Action Needed (`#f59e0b`):** Near-expiry threshold, reorder point hit, refrigeration deviation caution. Paired with tint `#fffbeb`.
  - **Critical / Danger (`#ef4444`):** Batch recall, expired medication, interaction contraindication, dosage discrepancy. Paired with tint `#fef2f2`.

## Typography

The type system relies on **Plus Jakarta Sans** for structural headlines, providing modern geometric clarity with warm humanist touches that prevent the UI from feeling cold. **Inter** handles all body copy, forms, table content, and clinical labeling due to its neutral structure and high legibility at micro scales.

### Tabular Numbers & Data Precision
All instances of numeric dosages (`250 mg`), inventory counts (`1,420 units`), lot numbers (`#L-99402`), and expiry dates (`2026-11-30`) must use tabular figures (`font-variant-numeric: tabular-nums`). This guarantees strict vertical alignment across comparative drug inventory tables and prescription lists.

## Layout & Spacing

This design system is built mobile-first to support hand-held barcode scanner terminals, clinical tablet rounds, and full dual-monitor dispensary workstations.

### Grid System & Breakpoints
- **Mobile (< 640px):** Single-column fluid stack. Outer margins are `1rem`, internal gutters are `0.75rem`. Action bars are pinned to bottom safe areas to enable one-thumb triage and verification.
- **Tablet (640px – 1024px):** 6-column to 8-column layout with `1.5rem` margins. Split master-detail views emerge (e.g., incoming prescription feed on the left, formulation verification on the right).
- **Desktop (> 1024px):** 12-column responsive fluid grid with maximum container width constrained to `1600px` for ultra-wide pharmacy monitors. Margins scale to `2rem`.

### Spacing Philosophy
Spacing follows a strict 4px base increment. Data tables use tight vertical rhythm (`space-xs` to `space-sm`) to maximize visible drug rows without compromising touch-target heights (minimum 44px on all touchable elements). Card containers utilize `space-lg` internally to breathe separation between high-density sub-modules.

## Elevation & Depth

To maintain a pristine clinical aesthetic, the design system minimizes heavy, muddy drop shadows in favor of **tonal layering paired with razor-sharp borders**. Depth communicates hierarchy and immediacy without visual clutter.

- **Level 0 (Base Layer):** Neutral canvas tinted `#f8fafc`. Flat, receded, quiet.
- **Level 1 (Card & Module Layer):** Pure `#ffffff` surface bounded by a crisp 1px perimeter outline (`#e2e8f0`). Backed by a subtle diffuse ambient shadow: `0 1px 3px 0 rgba(15, 23, 42, 0.04), 0 1px 2px -1px rgba(15, 23, 42, 0.04)`.
- **Level 2 (Hover, Active Rows & Floating Trays):** Pure `#ffffff` with enhanced outline (`#cbd5e1`) and elevation: `0 4px 6px -1px rgba(15, 23, 42, 0.06), 0 2px 4px -2px rgba(15, 23, 42, 0.04)`.
- **Level 3 (Modals, Barcode Scanner Overlays, Prescription Drawers):** `#ffffff` with high-emphasis outline (`#94a3b8`) and elevated depth: `0 20px 25px -5px rgba(15, 23, 42, 0.08), 0 8px 10px -6px rgba(15, 23, 42, 0.04)`. Backed by backdrop blur overlay: `rgba(15, 23, 42, 0.45)` with `backdrop-filter: blur(4px)`.

## Shapes

The geometric architecture balances soft accessibility with technical precision. 

- **Cards and Data Panels:** Use `rounded-xl` (1rem / 16px) or `rounded-2xl` (1.5rem / 24px) on major diagnostic surfaces. This softens dense clinical arrays and creates distinct visual grouping.
- **Interactive Controls (Inputs, Buttons, Dropdowns):** Fixed at `rounded-md` (0.375rem / 6px) to maintain a crisp, surgical feel that differentiates interactive modules from structural containers.
- **Badges, Status Chips & Pill Counters:** Fully curved (`rounded-full` / 9999px) to distinctly contrast with squared grid records.

## Components

### Buttons
- **Primary:** Solid `#0f6e5c` with white typography. Hover: `#0b5346`. Active: `#083d34`. Subtle inner top highlight border (`rgba(255,255,255,0.15)`) for tactile presence. Minimum height: 44px on mobile, 40px on desktop.
- **Secondary:** White background with 1px border in `#cbd5e1`, text in `#0f172a`. Hover: `#f8fafc` background, border `#94a3b8`.
- **Danger (Recall/Reject):** Solid `#ef4444` background with white text, or 1px `#ef4444` border with `#fef2f2` background for secondary destructive actions.

### Status Badges & Chips
- Designed with 100% semantic clarity for rapid scanning:
  - **In Stock / Validated:** Background `#ecfdf5`, border `#a7f3d0`, text `#065f46`, adorned with a solid 6px dot indicator `#10b981`.
  - **Expiring Soon / Low Threshold:** Background `#fffbeb`, border `#fde68a`, text `#92400e`, adorned with a 6px dot indicator `#f59e0b`.
  - **Expired / Recalled Batch:** Background `#fef2f2`, border `#fecaca`, text `#991b1b`, adorned with a 6px pulsing dot indicator `#ef4444`.
- Dimensions: Compact height (24px), horizontal padding (8px), font `label-md` or `label-sm`.

### Input Fields & Search Bars
- Background `#ffffff`, border 1px `#cbd5e1`, text `#0f172a`, placeholder `#94a3b8`.
- Focus state: 1px border `#0f6e5c` with a high-visibility clinical focus ring `box-shadow: 0 0 0 3px rgba(15, 110, 92, 0.15)`.
- Medication barcode scan inputs include an integrated trailing keyboard shortcut badge and camera icon trigger.

### Checkboxes & Radio Buttons
- 20px x 20px touch target minimum with 44px hit-box envelope.
- Inactive: `#ffffff` filled with 1.5px `#94a3b8` border.
- Active: Filled `#0f6e5c` with crisp white check mark icon. Double verification confirmation switches adopt bold emerald-to-red toggle states for high-risk approvals.

### Cards & Data Panels
- Surface: `#ffffff` surrounded by 1px `#e2e8f0` stroke and `rounded-xl` corners.
- Header section features 16px vertical padding, separated by a 1px `#f1f5f9` dividing rule.
- Critical drug warnings within cards use an inset left border: 4px solid status color (`#ef4444` or `#f59e0b`).

### Specialized Pharmacy Components
- **Dosage Verification Bar:** High-contrast step progress indicator that locks interaction until each dosage unit check is verified.
- **Lot / Expiry Badge:** Monospace badge pairing lot number with expiration countdown (e.g., `LOT-8819A · 14d left`).
- **Hazard Warning Tag:** Distinct diamond icon tag for hazardous, controlled substance (C-II to C-V), or refrigerated items (2°C–8°C).