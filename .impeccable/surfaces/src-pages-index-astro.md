---
version: 1
slug: "src-pages-index-astro"
primary_target: "src/pages/index.astro"
related_targets: ["src/pages/projects","src/pages/writing"]
---

# Home / Library

Scope: the home page, which is the unified library, plus the project and post templates it links to. Mode: Experience on the home page, Read on post and project pages.

Audience: peers, hiring, internal colleagues, and Zach himself. Job: work out who Zach is and what he's made in seconds, then open an entry. Content: three real projects and one real post to start, and the design must hold at fifty entries. Constraint: no invented stats, quotes or counts.

Chosen: the category standard, the classic builder portfolio executed at full craft. The quality bar is rauno.me, emilkowal.ski and paco.me. Zach steered away from gimmick over content and from anything too corporate.

## Direction contract

THESIS: A quiet, typographic personal library where the list itself is the hero. One column, one unified list of made things and writing, every row cross-linked. It refuses the card-grid dev-portfolio hero with skill badges and big CTAs.

OWN-WORLD: Neutral ink on near-white with a matching dark mode, and one accent used only for focus, the active filter and links on hover. Schibsted Grotesk for UI and headings, Source Serif 4 for reading prose, Fragment Mono only for dates and code (Geist was replaced after the detector flagged it as overused). The accent marks the active filter, focus, and link hover. Hairline separators, no cards, and a single sliding hover highlight shared by every list row.

STORY: The visitor reads one sentence of who Zach is, scans a dated library of projects and posts, filters it by type, and opens an entry. Each entry links sideways to its counterpart (project to its writing, writing to its project).

FIRST VIEWPORT: Top-left, the name in Schibsted Grotesk at about 15px weight 500, with a one-line role below it (open: awaiting Zach's wording; not rendered until supplied). Under that, a two-sentence intro paragraph at reading size with inline links. Then the Library heading row with All / Projects / Writing filter tabs on the right and a sliding indicator. The list begins inside the first viewport: rows of month and year (mono, tabular; shown at every width), title, type, and a muted one-line description. There is no hero image and no CTA button; the primary action is clicking a row.

FORM: Category standard (canon), chosen over the roll. Seed key 3bfa8c80. Signature interaction: a spring-damped highlight that glides between list rows on hover and keyboard focus. Filtering reflows the rows with a FLIP animation. Pages cross-fade via view transitions, and the clicked row's title morphs into the page title.

FINISH: unreviewed and undocumented is unfinished; this build ends with the finish review, the verdict, DESIGN.md, and every shipping raster carrying its provenance
