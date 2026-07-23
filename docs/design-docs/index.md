---
title: Design Documents
layout: default
nav_order: 4
has_children: true
permalink: /design-docs/
---

# Design Documents

Three documents build a single argument: that legacy medical device software can
be modernized safely if the modernization **preserves observable behavior** in a
formal, checkable sense, and that this approach is mature enough to be qualified
as an FDA Medical Device Development Tool.

| Document | Role |
|---|---|
| [FDA MDDT Proposal]({{ site.baseurl }}/design-docs/fda-mddt-proposal.html) | The regulatory narrative — Context of Use, the eight-layer architecture, validation strategy, hazard-to-test traceability. **Read this first.** |
| [ALGT CRUTPr (2003)]({{ site.baseurl }}/design-docs/algt-crutpr.html) | The historical provenance — the 2003 COHERENCE Dosimetrist Workspace 2.0 verification procedure that proves the methodology has 20+ years of production track record. |
| [Compositional Semantics]({{ site.baseurl }}/design-docs/compositional-semantics.html) | The formal backbone — **bisimilarity** as the criterion for safe substitution, and why a shared SQL database is an uncontrolled communication channel. |

## Ontologies

The design docs are accompanied by OWL/Turtle ontologies under
[`docs/ontology/`](https://github.com/DLaneAtElekta/ALGT/tree/main/docs/ontology)
that ground simulator types and verification predicates in standardized clinical
terminology:

- `basic-clinical-ontology.ttl` — patient, plan, prescription, dose, beam basics
- `dicom-ontology.ttl` — DICOM-RT object model
- `catalog-v001.xml` — OWL import catalog

These are loaded by the [domain models]({{ site.baseurl }}/components/domain-models.html)
and referenced by the verification test suites.
