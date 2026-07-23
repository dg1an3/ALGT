---
title: Pascal samples
layout: default
parent: Components
nav_order: 8
---

# Pascal samples

The Pascal/Lazarus corpus that feeds the Object Pascal simulator and the MUZAQ
modernization demo — spanning a modern round-trip target and a large legacy
archive.

**Location:** [`pascal_samples/`](https://github.com/DLaneAtElekta/ALGT/tree/main/pascal_samples)
· **Language:** Object Pascal / Turbo Pascal / Modula-2

| Directory | Contents |
|---|---|
| `modern-lazarus/` | `HelloMUZAQ.{pas,lfm}` — the round-trip target for the Lazarus → Prolog → Elixir pipeline |
| `legacy/` | ~404 Turbo Pascal / Modula-2 files (1985–1995) used as port and parser stress-test corpus |

## Role

The modern Lazarus sample is the smallest end-to-end demonstration of the
[MUZAQ modernization]({{ site.baseurl }}/architecture.html#the-muzaq-modernization-story):
a `TForm` that can be parsed into a labeled transition system and re-realized as
an actor. The legacy archive exercises the
[Pascal simulator's]({{ site.baseurl }}/components/simulators.html) parser
against decades of real-world dialect variation, and supplies the port targets
that appear under [`clarion_projects/`]({{ site.baseurl }}/components/clarion-projects.html)
(the `radar-*`, `ssm-fuel`, `quickdraw-*`, `penbeam-*`, `dh-*`, and
`brimstone-*` ports).
