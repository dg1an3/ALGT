---
title: Domain models
layout: default
parent: Components
nav_order: 4
---

# Domain models

Logtalk object-oriented domain models that formalize the clinical and imaging
concepts the simulators and verification suites reason about. They ground
simulator types and verification predicates in standardized clinical
terminology.

**Location:** [`domain_models/`](https://github.com/dg1an3/ALGT/tree/main/domain_models)
· **Language:** Logtalk

## Models

| Model | Scope |
|---|---|
| `imaging_services/` | Image import manager and protocol definitions |
| `subject_image_domain_model/` | Subject (patient) image domain |
| `treatment_image_domain_model/` | Treatment image domain |
| `appointment_domain_model/` | Appointment / scheduling domain |
| `hello_world.lgt` | Minimal Logtalk example |

## Conventions

- Logtalk **protocols** are prefixed with `i` (e.g. `iimage_import_manager`).
- Domain models load the OWL/Turtle ontologies under
  [`docs/ontology/`](https://github.com/dg1an3/ALGT/tree/main/docs/ontology)
  (`basic-clinical-ontology.ttl`, `dicom-ontology.ttl`) so that types used in
  the models correspond to standardized clinical/DICOM terms.

## Role in the MDDT stack

This is **Layer 3 — domain-model formalization**. Grounding form fields and
algorithm inputs in a shared ontology is what lets scenario validation and
concurrent-safety analysis talk about "a dose", "a beam", or "an appointment"
consistently across the Clarion, Pascal, and Elixir realizations.

## Related

- [Design documents]({{ site.baseurl }}/design-docs/) — the ontologies live alongside the design docs.
- [Architecture → the eight-layer stack]({{ site.baseurl }}/architecture.html#the-eight-layer-mddt-stack).
