---
title: claude-feedback
description: A local proxy that lets me leave pinned comments on any prototype, then hands them to Claude to fix.
date: 2026-09-14
status: active
---

Reviewing a prototype usually means a screenshot in a chat thread and a sentence like "this feels off." By the time someone acts on it, the page has changed and the screenshot points at nothing.

claude-feedback puts the comments on the page itself. It runs on `localhost:4599` and proxies any local dev server by port:

```
http://localhost:4599/<port>/<path>
```

Every proxied page gets a small overlay. Click anywhere, leave a note, and the overlay saves the comment with the page URL, the element position, and a screenshot of exactly what I was looking at.

## The loop

The comments live in one JSON file. When I tell Claude to address my feedback, it reads the unresolved comments for the prototype it is working on, looks at each screenshot, makes the fix, and marks the comment resolved. The review conversation happens where the work is, not in a separate thread.

## What it taught me

- **Inject before the last `</body>`, not the first.** A page that contains the text `</body>` inside its own JavaScript will happily swallow the overlay script mid-string. I found that one the hard way while reviewing the [style tiles](/projects/style-tiles/) for this site.
- **Screenshots beat selectors.** Element selectors drift as the page changes; a picture of what I saw stays true.
