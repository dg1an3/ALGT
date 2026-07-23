---
title: Home
layout: default
nav_order: 1
---

# ALGT

**Algorithm Logic Verification Tool · Legacy-language simulators · MUZAQ modernization demo**
{: .fs-5 .fw-300 }

A research and engineering platform for the **formal analysis of legacy medical
device software**. The repository braids together algorithm verification,
executable semantic models of legacy languages, and a worked demonstration of
modernizing a treatment-management system without changing its observable
behavior.
{: .fs-5 .fw-300 }

[Get started](#quick-start){: .btn .btn-primary .mr-2 }
[View on GitHub](https://github.com/DLaneAtElekta/ALGT){: .btn }

---

## The three threads

Everything in the repository serves one regulatory narrative: an
[FDA Medical Device Development Tool (MDDT) qualification]({{ site.baseurl }}/design-docs/fda-mddt-proposal.html)
for **ALGT-FMEA**, an automated software-FMEA toolset for legacy medical device
code. Three threads support that argument, all sharing a foundation in
SWI-Prolog and Logtalk.

| Thread | What it is | Where it lives |
|---|---|---|
| **1. Algorithm verification** | Formal proofs that geometric routines used in radiation-therapy planning meet hazard-traceable specifications. Descended from the 2003 Siemens COHERENCE *CRUTPr* procedure. | [ALGT verification]({{ site.baseurl }}/components/algt-verification.html) |
| **2. Legacy-language simulation** | DCG parsers + modular execution engines for Clarion 4GL, Object Pascal/Lazarus, LLVM IR, and F#. Each simulator is checked against the compiled binary by execution-trace comparison. | [Simulators]({{ site.baseurl }}/components/simulators.html) · [Clarion projects]({{ site.baseurl }}/components/clarion-projects.html) |
| **3. Modernization demonstration** | **MUZAQ** — a FreePascal/Lazarus treatment-management system modernized to a Prolog labeled transition system and then to an Elixir actor system, preserving observable behavior in a formal, checkable sense. | [Architecture]({{ site.baseurl }}/architecture.html) |

---

## What's in this site

- **[Architecture]({{ site.baseurl }}/architecture.html)** — the eight-layer MDDT approach, the execution-trace comparison strategy (Levels 1–3), and the MUZAQ modernization story from Lazarus to Prolog to Elixir.
- **[Components]({{ site.baseurl }}/components/)** — a page for every major part of the repository:
  - [ALGT algorithm verification]({{ site.baseurl }}/components/algt-verification.html)
  - [Language simulators]({{ site.baseurl }}/components/simulators.html) (Clarion, Pascal, LLVM, F#)
  - [Clarion projects]({{ site.baseurl }}/components/clarion-projects.html) (real compiled DLL/EXE test cases)
  - [Domain models]({{ site.baseurl }}/components/domain-models.html) (Logtalk)
  - [Model checker]({{ site.baseurl }}/components/model-checker.html) (concurrent-interleaving verification)
  - [MCP servers]({{ site.baseurl }}/components/mcp-servers.html) (Prolog, Erlang, Elixir, Python)
  - [F# projects]({{ site.baseurl }}/components/fsharp-projects.html) and [Pascal samples]({{ site.baseurl }}/components/pascal-samples.html)
- **[Design documents]({{ site.baseurl }}/design-docs/)** — the regulatory narrative, historical provenance, and the formal bisimilarity backbone.

---

## The MDDT approach in brief

Legacy radiation-oncology systems (MOSAIQ in Clarion 4GL, Monaco in C++, and
analogous FreePascal/Delphi systems) carry hundreds of thousands of lines of
validated, regulated code that no commercial static analyzer understands.
ALGT builds an **executable semantic model** of that source — a parser plus an
interpreter — and uses it to:

1. **Verify** safety-critical algorithms against formal predicates.
2. **Compare** execution traces against the compiled binary at the procedure,
   debugger-breakpoint, and variable level.
3. **Explore** concurrent interleavings and probabilistic failure models that
   no source-level static tool can reach.

The technique is not theoretical — it descends from a production verification
of the COHERENCE Dosimetrist Workspace 2.0 in 2003. See
[Design documents]({{ site.baseurl }}/design-docs/) for the full story.

---

## Quick start

The core Prolog and Logtalk components run anywhere SWI-Prolog is installed.

**Verify the development environment (DSC v3):**

```bash
dsc config test --file algt-devenv.dsc.yaml
```

**Run the Clarion simulator test suite:**

```bash
cd simulators/clarion/unified
swipl -g "main,halt" -t "halt(1)" test_unified.pl
```

**Run an ALGT algorithm verification:**

```bash
swipl -s algt_tests/ALGT_BEAM_VOLUME.pl
```

**Compare a Prolog trace against a compiled Clarion DLL:**

```bash
cd clarion_projects/sensor-data
python compare_cdb_prolog.py
```

See the [Requirements](#requirements) below for the optional, thread-specific
toolchains.

---

## Requirements

**Core**

- **SWI-Prolog** 8.0+ — [swi-prolog.org](https://www.swi-prolog.org/)
- **Logtalk** — [logtalk.org](https://logtalk.org/) — for the object-oriented domain models and storage/UI dispatchers
- **DSC v3** — run `dsc config test --file algt-devenv.dsc.yaml` to verify tooling

**Optional, by thread**

| Thread | Tooling |
|---|---|
| Clarion DLL trace comparison | Clarion 11.1; 32-bit Python 3.11; CDB (x86) from Windows SDK Debugging Tools |
| F# components | .NET SDK 8+ |
| LLVM simulator (Pascal target) | LLVM toolchain |
| MUZAQ modernization demo | FreePascal/Lazarus 3.x; Erlang/OTP 26+; Elixir 1.16+ |

---

## License

Copyright &copy; 2015, dg1an3. Licensed under the **BSD 2-Clause License**.
Given the medical-device focus, all changes should preserve test coverage and
avoid weakening assertions without an explicit safety rationale.
