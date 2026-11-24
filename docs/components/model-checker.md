---
title: Model checker
layout: default
parent: Components
nav_order: 5
---

# Model checker

Verifies interleaved concurrent operations to identify race conditions. This is
the component that makes the [MUZAQ]({{ site.baseurl }}/architecture.html#the-muzaq-modernization-story)
concurrency argument concrete: given the labels produced by multiple forms, it
explores their interleavings and flags orderings that violate safety
properties.

**Location:** [`model_checker/`](https://github.com/dg1an3/ALGT/tree/main/model_checker)
· **Language:** SWI-Prolog

## Files

- `model_checker.pl` — the checker itself
- `README.md` — usage notes

## Usage

```prolog
swipl -s model_checker/model_checker.pl

?- valid(sequence([capture_image -> img1, update_contour -> img1])).
```

## Why interleavings matter

Traditional UI testing cannot enumerate what happens when several users work in
several forms simultaneously. But once each form's observable actions are
reified as **labels** — GUI events plus SQL transaction-log entries — the set of
"what could happen concurrently" becomes finite and *checkable*. The model
checker explores those interleavings the same way it already handles
imaging-pipeline ordering bugs.

This is **Layer 5 — concurrent safety** in the
[eight-layer stack]({{ site.baseurl }}/architecture.html#the-eight-layer-mddt-stack).

## Related

- [Architecture → the SQL transaction log is the event stream]({{ site.baseurl }}/architecture.html#the-sql-transaction-log-is-the-event-stream).
- [Design documents → compositional semantics]({{ site.baseurl }}/design-docs/compositional-semantics.html) — why the log is the only channel that needs interleaving.
