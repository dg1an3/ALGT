---
title: ALGT algorithm verification
layout: default
parent: Components
nav_order: 1
---

# ALGT algorithm verification

Formal verification of the geometric algorithms used in radiation-therapy
treatment planning. These test suites descend directly from the 2003 Siemens
COHERENCE *CRUTPr* procedure (see
[Design documents]({{ site.baseurl }}/design-docs/algt-crutpr.html)), and each
one checks an algorithm against predicate-logic verification conditions rather
than a handful of example inputs.

**Location:** [`algt_tests/`](https://github.com/dg1an3/ALGT/tree/main/algt_tests)
· **Language:** SWI-Prolog

## The algorithms

| File | Algorithm |
|---|---|
| `ALGT_BEAM_VOLUME.pl`, `ALGT_BEAM_VOLUME_PLANAR.pl` | Radiation beam volume (3D and planar) |
| `ALGT_BEAM_CAX_ISOCENTER.pl` | Central-axis / isocenter geometry |
| `ALGT_MESH_GEN.pl` | 3D mesh generation from contours |
| `ALGT_MESH_PLANE_INTERSECTION.pl` | Mesh ∩ plane intersection |
| `ALGT_MARGIN2D.pl`, `ALGT_MARGIN3D.pl` | Structure margin expansion |
| `ALGT_ISODENSITY.pl` | Isodose / isodensity extraction |
| `ALGT_STRUCT_PROJ.pl` | Beam's-eye-view structure projection |
| `ALGT_SSD.pl` | Source-to-surface distance |

## Why predicates, not examples

Each routine is verified against a formal specification expressed as
predicate-logic *verification conditions*. Because correctness here is a
patient-safety property, the goal is to characterize the algorithm's behavior
over its whole input domain, not to spot-check a few cases. This is the same
methodology used in the 2003 production verification of the COHERENCE
Dosimetrist Workspace 2.0.

## Run it

```bash
# Run a single algorithm's verification
swipl -s algt_tests/ALGT_BEAM_VOLUME.pl

# The ALGT test runner (from the repository root)
swipl run_tests.pl
```

## Related

- [Architecture → the eight-layer stack]({{ site.baseurl }}/architecture.html#the-eight-layer-mddt-stack) — this is **Layer 1**.
- [Design documents → CRUTPr]({{ site.baseurl }}/design-docs/algt-crutpr.html) — the historical provenance.
