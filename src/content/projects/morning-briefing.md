---
title: Morning Briefing
description: An agent that reads a fixed list of outlets every weekday and writes a short, plain news digest before work starts.
date: 2026-08-20
status: active
---

Morning Briefing is a scheduled agent that compiles a daily news digest. It works through the same list of outlets in the same order every morning, follows the stories that are still developing, and writes the briefing in plain prose.

## Why a fixed protocol

The first versions searched freely and produced a different briefing every day: some stories doubled, others vanished between mornings. A fixed outlet-by-outlet protocol made the output boring in the best way. The reader always knows what was checked.

## Format rules

- No bullet points and no bolded summaries. Each item is a short paragraph that reads like a person wrote it.
- Opinion pieces are labeled as opinion.
- A running list of ongoing stories is checked every day, so a story doesn't silently disappear.
