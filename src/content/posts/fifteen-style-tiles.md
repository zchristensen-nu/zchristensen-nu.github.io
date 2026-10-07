---
title: Fifteen style tiles before one website
description: I built every direction I was curious about as a working page, then picked the quietest one.
date: 2026-10-06
project: style-tiles
---

When I started this site I had a list of looks I wanted to try: early-2000s operating systems, Swiss posters, a museum, a newspaper, a streaming service. Describing them in a doc felt pointless. A direction you can't click is a direction you can't judge.

So I built them. Each [style tile](/projects/style-tiles/) is a single HTML file with its own typography, palette, textures and components, and each one is pushed as far as the idea would go. The Windows tile boots and has a working Start menu. The newspaper has a mini crossword you can actually solve. The streaming tile asks who's watching.

## What building them taught me

**Costumes are fun for a minute.** The era tiles were the most delightful to click through and the fastest to stop clicking. A site I'll keep adding to for years can't depend on a joke staying funny.

**The content decides.** Every tile was filled with the same three projects and three post titles. The directions that made those entries easy to scan and pleasant to read held up. The ones that made you work to find them didn't, however good they looked.

**The quiet option is still a design decision.** I chose the standard shape for a personal site: a name, a short intro, and a list. All of the effort goes into making that list feel right. Hover a row and a single highlight follows you down the page. Filter by type and the rows slide into place. Open an entry and its title carries over into the next page.

## Bugs found along the way

One tile wouldn't load through my [comment proxy](/projects/claude-feedback/). Its sample code contained the literal text `</body>`, and the proxy injected its overlay at the first match, inside a JavaScript string. The fix belongs in the proxy, which should match the last `</body>`, not the first.

The tiles are still online if you want to [click around](/tiles/).
