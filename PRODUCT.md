# Product

<!-- impeccable:product-schema 1 -->

## Platform

web

## Stack

Astro with Markdown content collections (posts, projects). It deploys to GitHub Pages from the public repo `zchristensen-nu.github.io` via the official `withastro/action`. The site is served at `https://zchristensen-nu.github.io/`. Confirmed with Zach in session on 2026-09-29.

## Users

Zach is writing for several audiences at once, all confirmed:
- **Peers and builders.** Engineers, designers and AI tinkerers who want to see how Zach builds things and read his notes.
- **Hiring and collaborators.** People sizing him up for a role, a contract or a project.
- **Colleagues internally.** People at his org who might use or adopt the tools he's built.
- **Zach himself.** A personal archive and thinking space.

No audience wins by default. The site has to work for a quick skim (who is this, what has he made) and for deep reading (a full writeup).

## Product Purpose

A personal library that holds Zach's projects and his writing about them. Each project gets a home with a writeup. Posts explain what he learned building things. Success is a visitor who can grasp who Zach is and what he makes within seconds, and then find it worth staying to read.

## Positioning

The projects and the writing are about the same things. Posts are first-hand accounts of building the tools listed beside them, not a separate blog. Projects and posts link to each other.

## Operating Context

- Content is authored as Markdown files in the repo, and publishing is a push to `main`.
- Many projects begin as internal tools (e.g. claude-feedback, Morning Briefing).
- The library is small now and will grow, so it must look complete with three items and still scale to dozens.

## Capabilities and Constraints

- Two content types: **projects** (title, description, optional link/repo, writeup) and **posts** (title, date, description, optional draft, body). There is an RSS feed for posts.
- The site is public. Writeups of internal projects must not expose confidential details, and the content is Zach's responsibility.
- Static hosting only, with no server runtime.
- **Undecided:** tags, search, comments, analytics and a custom domain. Each can be added later.

## Brand Commitments

- Name: **Zach Christensen**.
- Zach has explicitly said the site should be pushed to the limits of interactivity, motion and design craft. It should be a showpiece, not a template.
- Fifteen visual explorations live in `public/tiles/` as evidence of directions considered, not as a binding visual system.

## Evidence on Hand

- Real projects:
  - **claude-feedback** (`~/Projects/claude-feedback`): a comment-overlay proxy for reviewing local prototypes.
  - **Morning Briefing**: an automated daily news digest.
  - **Style Tiles**: this site's design exploration.
- One post, "Fifteen style tiles before one website" (`src/content/posts/fifteen-style-tiles.md`). Claude drafted it from this session's real work, and Zach still needs to review it. All post copy in the tiles is sample text.
- `claude-feedback` and `morning-briefing` project dates are placeholders until Zach confirms them.
- No portrait, logo, testimonials, metrics or press are on hand. Do not fabricate stats, quotes, counts or endorsements.

## Product Principles

1. **Work first.** The made things and the writing are the content. Chrome supports them and never competes.
2. **Craft is the credential.** The site's own build quality is part of the portfolio.
3. **Small library, complete feel.** Three entries must look intentional rather than empty, and the structure must hold at fifty.
4. **Projects and posts are linked.** Every project points to its writing and every post points to its project.
5. **Easy to publish.** Adding a post is writing a Markdown file. Nothing about the design should make that harder.

## Accessibility & Inclusion

WCAG 2.1 AA. All motion must respect `prefers-reduced-motion`, and the site must be fully keyboard-navigable.
