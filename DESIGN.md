---
name: Zach Christensen
description: A quiet, typographic personal library of projects and the writing about them.
colors:
  paper: "#fcfcfb"
  ink: "#141517"
  muted: "#53575e"
  faint: "#686c73"
  rule: "#e6e7e9"
  hover-wash: "#f0f1f2"
  accent: "#2f4fd6"
  code-bg: "#f4f4f5"
  selection: "#dfe5fb"
  paper-dark: "#0e0f11"
  ink-dark: "#ececee"
  muted-dark: "#9b9fa6"
  faint-dark: "#80848c"
  rule-dark: "#222428"
  hover-wash-dark: "#18191c"
  accent-dark: "#8ea2ff"
  code-bg-dark: "#16171a"
  selection-dark: "#26305c"
typography:
  display:
    fontFamily: "'Schibsted Grotesk', ui-sans-serif, system-ui, sans-serif"
    fontSize: "clamp(1.625rem, 4vw, 2rem)"
    fontWeight: 600
    lineHeight: 1.15
    letterSpacing: "-0.03em"
  headline:
    fontFamily: "'Schibsted Grotesk', ui-sans-serif, system-ui, sans-serif"
    fontSize: "1.3125rem"
    fontWeight: 600
    lineHeight: 1.3
    letterSpacing: "-0.02em"
  title:
    fontFamily: "'Schibsted Grotesk', ui-sans-serif, system-ui, sans-serif"
    fontSize: "0.9375rem"
    fontWeight: 500
    lineHeight: 1.6
    letterSpacing: "-0.01em"
  lede:
    fontFamily: "'Schibsted Grotesk', ui-sans-serif, system-ui, sans-serif"
    fontSize: "1.0625rem"
    fontWeight: 400
    lineHeight: 1.55
  body:
    fontFamily: "'Schibsted Grotesk', ui-sans-serif, system-ui, sans-serif"
    fontSize: "0.9375rem"
    fontWeight: 400
    lineHeight: 1.6
  body-small:
    fontFamily: "'Schibsted Grotesk', ui-sans-serif, system-ui, sans-serif"
    fontSize: "0.875rem"
    fontWeight: 400
    lineHeight: 1.5
  prose:
    fontFamily: "'Source Serif 4', ui-serif, Georgia, serif"
    fontSize: "1.1875rem"
    fontWeight: 400
    lineHeight: 1.65
  label:
    fontFamily: "'Schibsted Grotesk', ui-sans-serif, system-ui, sans-serif"
    fontSize: "0.8125rem"
    fontWeight: 400
  mono:
    fontFamily: "'Fragment Mono', ui-monospace, 'SF Mono', Menlo, monospace"
    fontSize: "0.75rem"
    fontWeight: 400
    fontFeature: "tnum"
rounded:
  focus: "4px"
  code-inline: "5px"
  skip: "6px"
  row: "10px"
  pill: "999px"
spacing:
  column: "40rem"
  gutter: "clamp(1.25rem, 5vw, 2rem)"
  row-x: "0.75rem"
  row-y: "0.8rem"
  masthead: "2.75rem"
  library-top: "3.5rem"
  related-top: "4rem"
  footer-top: "5rem"
components:
  library-row:
    textColor: "{colors.ink}"
    rounded: "{rounded.row}"
    padding: "0.8rem 0.75rem"
  library-row-hover:
    backgroundColor: "{colors.hover-wash}"
    rounded: "{rounded.row}"
  filter-tab:
    textColor: "{colors.muted}"
    typography: "{typography.label}"
    rounded: "{rounded.pill}"
    padding: "0.3rem 0.65rem"
  filter-tab-hover:
    textColor: "{colors.ink}"
  filter-tab-active:
    backgroundColor: "color-mix(in srgb, #2f4fd6 11%, #fcfcfb)"
    textColor: "{colors.accent}"
    rounded: "{rounded.pill}"
  related-row:
    textColor: "{colors.ink}"
    rounded: "{rounded.row}"
    padding: "0.7rem 0.75rem"
  related-row-hover:
    backgroundColor: "{colors.hover-wash}"
  code-inline:
    backgroundColor: "{colors.code-bg}"
    textColor: "{colors.ink}"
    rounded: "{rounded.code-inline}"
    padding: "0.1em 0.35em"
  code-block:
    backgroundColor: "{colors.code-bg}"
    rounded: "{rounded.row}"
    padding: "1rem 1.15rem"
  skip-link:
    backgroundColor: "{colors.ink}"
    textColor: "{colors.paper}"
    rounded: "{rounded.skip}"
    padding: "0.5rem 0.75rem"
---

# Design System: Zach Christensen

## Overview

**Creative North Star: "The Quiet Library"**

One narrow column of type on near-white paper (near-black in dark mode), where the list of made things and writing is the hero. Nothing is boxed. Entries are separated by whitespace and the occasional hairline, and the only surface that ever appears behind a row is a soft grey wash that glides to it on hover or keyboard focus. The craft lives in motion and typesetting rather than ornament: a spring-damped highlight, a filter indicator that slides as a clip-path, rows that reflow with FLIP when filtered, and an entry title that morphs into the page heading across a view transition.

The system has three typographic voices with fixed jobs: a grotesk for everything you navigate, a serif for everything you read at length, and a mono for dates, counts and code. Colour is almost entirely neutral. A single blue accent appears only where the visitor's attention or state is: focus, the active filter, and links on hover in reading text and entry meta.

Density is low but not empty. Three entries must read as a deliberate library and fifty must still scan, so the row structure (date, title with one-line description, type) carries the page instead of imagery. There is no hero image, no card grid and no call-to-action button.

**Key Characteristics:**
- Single 40rem column, left-aligned, generous top padding.
- Neutral ink on paper, with a full matching dark mode via `prefers-color-scheme`.
- One accent, used for state and focus only.
- Hairline rules and whitespace instead of containers; flat, no shadows.
- One shared spring highlight for the library list; motion that always yields to `prefers-reduced-motion`.

## Colors

A cool, nearly achromatic neutral ramp with one saturated blue that changes lightness between modes to keep contrast.

### Primary
- **Library Blue** (accent; `accent-dark` in dark mode): focus outlines (2px, 3px offset), the active filter tab's text and 11% tinted pill, link hover in intro and prose, link hover in entry meta (Open, Source). Also drives `accent-color` and `caret-color`.

### Neutral
- **Paper** (paper / paper-dark): the page background, and the base the accent tint is mixed into.
- **Ink** (ink / ink-dark): names, titles, headings, inline links at rest in the intro, the skip link's fill, the blockquote's left rule.
- **Muted Graphite** (muted / muted-dark): secondary text: intro paragraph, entry ledes, row descriptions, inactive filters, footer, back link, blockquote text.
- **Faint Graphite** (faint / faint-dark): tertiary metadata only: row dates, row type labels, filter counts, entry meta, list markers.
- **Hairline** (rule / rule-dark): 1px separators under the library bar, above Related and the footer; resting link underline colour; code borders; scrollbar thumb.
- **Hover Wash** (hover-wash / hover-wash-dark): the gliding row highlight and the Related row hover fill.
- **Code Tint** (code-bg / code-bg-dark): inline code and code block backgrounds.
- **Selection Blue** (selection / selection-dark): text selection background, with ink text.

### Named Rules
**The One Accent Rule.** Library Blue marks state and attention only: focus, the active filter, and link hover in reading text and entry meta. Chrome links (footer, back link, filter tabs) hover to Ink, not to the accent. No accent fills, no accent headings.

**The Paired Mode Rule.** Every colour token has a dark counterpart and every new surface must read in both. Dark mode is not an inversion; the accent lifts to a lighter blue (`accent-dark`) to hold contrast.

## Typography

**Display Font:** Schibsted Grotesk (with ui-sans-serif, system-ui, sans-serif)
**Body Font:** Schibsted Grotesk for UI; Source Serif 4 (with ui-serif, Georgia, serif) for long-form prose
**Label/Mono Font:** Fragment Mono (with ui-monospace, SF Mono, Menlo, monospace)

**Character:** A crisp, slightly tight grotesk sets the interface at a modest 15px, a warm optical-sized serif takes over once you are reading, and a narrow mono quietly timestamps everything.

### Hierarchy
- **Display** (600, clamp(1.625rem, 4vw, 2rem), 1.15, -0.03em): entry page titles only; the morph target for the row title.
- **Headline** (600, 1.3125rem, 1.3, -0.02em): section headings inside prose, set in the grotesk even though the body is serif.
- **Title** (500, 0.9375rem, -0.01em): the name in the masthead, row titles, the Library and Related headings. Hierarchy here comes from weight, not size.
- **Lede** (400, 1.0625rem, 1.55 to 1.6, Muted): the home intro and entry descriptions, capped at 34rem.
- **Body** (400, 0.9375rem, 1.6): base UI text.
- **Body small** (400, 0.875rem, 1.5, Muted): row and related descriptions.
- **Prose** (Source Serif 4, 400, 1.1875rem / 1.125rem under 34rem, 1.65, optical sizing on): post and project bodies. Paragraph spacing 1.1em; bold at 600.
- **Label** (400, 0.8125rem): filter tabs, entry meta row, footer.
- **Mono** (400, 0.75rem, tabular numerals, Faint): dates and counts; code at 0.8em inline and 0.8125rem / 1.7 in blocks.

### Named Rules
**The Three Voices Rule.** Grotesk for anything you navigate, serif only inside `.prose`, mono only for dates, counts, code and the draft marker. Never set UI chrome in the serif or prose in the grotesk.

**The Weight-Not-Size Rule.** Inside the column, headings above a list (Library, Related) are the same size as body text and differ only by weight 500 and -0.01em tracking. Only entry titles and prose sections step up in size.

## Layout

A single centred column, max width 40rem plus a fluid gutter (clamp(1.25rem, 5vw, 2rem)) on each side, with top padding clamp(3rem, 10vh, 6.5rem) and 4rem at the bottom. Everything is left-aligned. Vertical rhythm is set by a small set of section gaps: 2.75rem below the masthead and entry header, 3.5rem above the library, 4rem above Related, 5rem above the footer.

Library rows are a three-column grid (4.25rem date, flexible title and description, auto type label) with 1rem column gap and 0.8rem / 0.75rem padding. The list bleeds 0.75rem into the gutter on each side so row text aligns with the column edge while the hover wash extends past it. When consecutive rows share a month, the repeated date is hidden.

One breakpoint, 34rem: the library bar stacks with the filters under the heading, rows drop to two columns with the date on its own line above the title (repeated dates removed entirely), and prose drops to 1.125rem.

**The Single Column Rule.** Every page lives in the one 40rem column. No sidebars, no multi-column grids, no full-bleed sections.

## Elevation & Depth

Fully flat. There are no box shadows anywhere in the build. Depth is conveyed by a tonal wash (Hover Wash) that appears behind a row on hover or focus, the 11% accent-tinted pill behind the active filter, and 1px hairlines. Layering is temporal rather than spatial: things glide, fade and morph instead of lifting.

**The Flat Paper Rule.** Surfaces never cast shadows. Any emphasis is a tonal fill with a 10px radius that appears only in response to state.

## Shapes

Corners are soft and few. Row highlights, Related row fills and code blocks share a 10px radius; inline code is 5px, the skip link 6px, the focus outline 4px. The filter indicator and tabs are full pills (999px). Borders are 1px hairlines in Hairline, used for separators and code only; the single exception is the blockquote, which carries a 1px Ink rule on its left. Icons are small inline SVG strokes at 1.5px with round caps, sized 0.85em to sit on the text baseline. The favicon is an 8px-radius Ink square with a round-capped Z stroke in Paper, flipping in dark mode.

## Components

### Library list (signature)
The home page's hero: one unified, dated list of projects and writing.
- **Row:** date (Mono, Faint), title (Title weight, Ink) over a one-line description (Body small, Muted), type label (0.75rem, Faint, lifting to Muted on hover/focus). No borders between rows.
- **Shared glide:** a single absolutely positioned Hover Wash element (10px radius) moves between rows on pointer enter and keyboard focus, driven by a damped spring (stiffness 420, damping 34) on translateY and height. It fades in and out at 220ms. With reduced motion it jumps without animating.
- **Focus:** the global 2px accent outline, inset by 2px so it sits inside the row.
- **Title morph:** each row title shares a view-transition name with the entry page's Display title.

### Filter tabs
- **Style:** All / Projects / Writing as Label-size pill buttons (0.3rem / 0.65rem padding), Muted at rest and Ink on hover, each followed by a Mono count in Faint.
- **Active:** Library Blue text, count at 70% opacity, over a pill of 11% accent mixed into Paper.
- **Indicator:** one background element clipped with `clip-path: inset(... round 999px)` to the active button and transitioned over 380ms. Uses `aria-pressed`, and the active state is mirrored to `?filter=` in the URL so intro links and shared links open pre-filtered.
- **Reflow:** filtering animates surviving rows from their old position (FLIP, 460ms); newly shown rows enter from 6px below with a 3px blur over 420ms. All on the system ease-out.

### Entry header
Display title, a Muted lede capped at 34rem, then a Label-size meta row in Faint with dates in Mono. Meta links (Open, Source) carry a small arrow SVG, sit in Muted and hover to Library Blue.

### Related list
"Writing about this project" or "The project", introduced by a hairline and a Title-weight heading. Rows are a two-column grid (title, mono date) over a description, 10px radius, with Hover Wash fading in over 200ms.

### Navigation
- **Masthead:** the name at Title weight; on inner pages it becomes a Muted back link with a chevron that nudges 2px left on hover and turns Ink.
- **Undecided:** the direction contract promises a one-line role under the name; it is not rendered and waits on Zach's wording. No style is set for it yet.
- **Footer:** a hairline, then Label-size Muted links (GitHub, RSS, Style tiles) without underlines, hovering to Ink.
- **Links in text:** inherit colour with a 1px underline in Hairline at 0.22em offset; underline goes to currentColor on hover, and in intro and prose the text turns Library Blue. Intro links sit in Ink with a Faint underline against the Muted paragraph.
- **Skip link:** Ink pill-ish block (6px) with Paper text, revealed on focus.

### Code
Inline code in Fragment Mono at 0.8em on Code Tint with a Hairline border and 5px radius. Blocks are 0.8125rem / 1.7 with 1rem / 1.15rem padding, 10px radius and a Hairline border; Shiki dark colours apply in dark mode.

## Do's and Don'ts

### Do:
- **Do** keep every page in the single 40rem column with the clamp(1.25rem, 5vw, 2rem) gutter.
- **Do** route any new list of entries through the shared glide pattern (one Hover Wash element, 10px radius, spring stiffness 420 / damping 34) rather than per-row hover fills.
- **Do** use the ease-out curve cubic-bezier(0.16, 1, 0.3, 1) for transitions, and gate every animation on `prefers-reduced-motion`.
- **Do** set dates and counts in Fragment Mono with tabular numerals.
- **Do** give every new colour a dark-mode counterpart and check both modes.
- **Do** separate sections with 1px Hairline rules and whitespace.

### Don't:
- **Don't** wrap entries in bordered or shadowed cards, or build a card grid; the only fill behind a row is the state-driven Hover Wash.
- **Don't** use box shadows; the system is flat.
- **Don't** spend Library Blue on fills, headings, decoration or chrome-link hover; it is for focus, the active filter and link hover in reading text and entry meta.
- **Don't** set prose in the grotesk or UI in the serif, and don't use Fragment Mono for headings or body text.
- **Don't** add a hero image or a call-to-action button to the home page; clicking a row is the primary action.
- **Don't** lighten Faint Graphite or Muted Graphite. Both are tuned to pass WCAG AA (4.5:1 or better) on Paper and on the Hover Wash in both modes; Faint is #686c73 / #80848c and Muted is #53575e.
