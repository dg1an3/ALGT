---
title: Architecture
layout: default
nav_order: 2
---

# Architecture
{: .no_toc }

How the pieces fit together: the eight-layer MDDT stack, the execution-trace
comparison strategy that ties simulators to compiled binaries, and the MUZAQ
modernization pipeline.

<details open markdown="block">
  <summary>Table of contents</summary>
  {: .text-delta }
- TOC
{:toc}
</details>

---

## The eight-layer MDDT stack

The [FDA MDDT proposal]({{ site.baseurl }}/design-docs/fda-mddt-proposal.html)
qualifies **ALGT-FMEA** as a tool for software FMEA on legacy medical device
code. It is organized as eight cooperating layers, each exercised end-to-end by
the [MUZAQ demo](#the-muzaq-modernization-story):

| # | Layer | Purpose | Primary component |
|---|---|---|---|
| 1 | **Formal algorithm verification** | Prove geometric/numeric kernels meet hazard-traceable predicates | [ALGT verification]({{ site.baseurl }}/components/algt-verification.html) |
| 2 | **Execution-trace comparison** | Confirm the interpreter matches the compiled binary | [Clarion projects]({{ site.baseurl }}/components/clarion-projects.html) |
| 3 | **Domain-model formalization** | Ground clinical terms in standardized ontologies | [Domain models]({{ site.baseurl }}/components/domain-models.html) |
| 4 | **Scenario validation** | Replay UI/workflow scenarios across implementations | [Simulators]({{ site.baseurl }}/components/simulators.html) |
| 5 | **Concurrent safety** | Explore interleavings, flag race conditions | [Model checker]({{ site.baseurl }}/components/model-checker.html) |
| 6 | **Probabilistic inference** | Estimate failure-mode likelihoods from trace exports | Trace exports (PGM/PyMC/Stan) |
| 7 | **Anomaly detection** | Flag out-of-distribution behavior via GNN-VAE over traces | Trace exports |
| 8 | **Semantic fault injection** | LLM-driven mutation of handlers to test robustness | Simulator tooling |

---

## Execution-trace comparison

The load-bearing idea of the whole platform: an interpreter is only trustworthy
if it produces the **same observable behavior** as the compiled binary it stands
in for. ALGT verifies this by emitting traces from both sides and diffing them.

### Level 1 — Procedure-level traces

Both sides emit `CALL ProcName(args) -> result` lines and are compared with
`diff`. The Prolog side uses `init_session`/`call_procedure` from the unified
`clarion.pl` module; the Python side wraps each `ctypes` DLL call.

```bash
diff <(cd clarion_projects/sensor-data && python trace_sensorlib.py | grep "^CALL") \
     <(cd simulators/clarion/unified && swipl -g "main,halt" trace_sensorlib.pl | grep "^CALL.*->")
```

### Level 1b — CDB debugger traces

The Windows **CDB** debugger sets hardware breakpoints on the DLL's exported
functions, reads arguments from the x86 stack, runs each function to completion,
and reads the return value from `eax`. This is ground truth taken **directly
from the compiled binary** — no Python wrapper instrumentation.

```bash
cd clarion_projects/sensor-data
python compare_cdb_prolog.py
```

```
--- Comparison ---
  OK: CALL SSOpen() -> 0
  OK: CALL SSAddReading(1, 100, 50) -> 0
  OK: CALL SSCalculateWeightedAverage() -> 152
  OK: CALL SSCleanupLowReadings(150) -> 1
  ...
RESULT: All 8 trace entries match!
```

### Level 1c — Variable-level comparison

Headless DLLs (FormLib, OffsetLib) expose get/set operations on internal
variables as named exports. CDB traces each call; the Prolog side implements the
same logic and is diffed against it. This is how GUI form logic —
direction sign-flips, magnitude calculations — is verified without a live UI.

### Level 2 — Statement-level traces

The Prolog interpreter can trace *every* statement (`assign`, `call`, `if` with
the condition value and branch taken, `loop` enter/exit, `break`, `return`) via
`set_trace(on)`. This is finer than anything the binary exposes and is used for
white-box analysis.

### Level 3 — Instrumented source (future)

Insert `TraceLog('label')` calls at key points in `.clw`/`.pas` source and diff
the trace-point sequences.

---

## The MUZAQ modernization story

**MUZAQ** is an open, non-proprietary stand-in for MOSAIQ — a treatment
management system written in **FreePascal / Lazarus** with **C/C++ interop** for
numerically intensive parts. It is modernized in two staged translations, each
preserving observable behavior in the **bisimilarity** sense defined in
[compositional-semantics]({{ site.baseurl }}/design-docs/compositional-semantics.html).

```
  ┌──────────────────────────┐    ┌────────────────────────┐    ┌──────────────────────┐
  │ MUZAQ (Lazarus + C/C++)  │ →  │ Prolog LTS             │ →  │ Elixir actor system  │
  │ Forms, TDataSet, events  │    │ States, labels,        │    │ GenServers per form, │
  │ DB calls via SQLdb       │    │ transitions, traces    │    │ event-stream bus     │
  └──────────────────────────┘    └────────────────────────┘    └──────────────────────┘
```

### Stage 1 — Lazarus to a Prolog labeled transition system

Each Lazarus `TForm` is parsed and projected onto an LTS:

- **States** — the form's persistent fields plus GUI state (focused control, modal/non-modal, dirty flags).
- **Labels** — observable actions in two families:
  - *GUI events* — `OnClick`, `OnChange`, `OnExit`, inter-form messages, C/C++ FFI calls.
  - *SQL transaction-log entries* — every database command (`Insert`, `Update`, `Delete`, `Post`, `ApplyUpdates`, `Commit`, `Rollback`) treated as an entry in the database's **logical transaction log**.
- **Transitions** — derived from event handlers and the `TDataSet` lifecycle.

### The SQL transaction log *is* the event stream

This is the key insight, and it falls out of the compositional-semantics
argument: a shared SQL database is an *uncontrolled communication channel*. The
transaction log is the **only** channel through which one form can observe
another's effects. So the log entries are exactly the labels whose interleavings
must be considered to model concurrent multi-form interaction — and that
interleaving is what the [model checker]({{ site.baseurl }}/components/model-checker.html)
explores.

### Stage 2 — Prolog LTS to Elixir actors

- Each Lazarus form becomes a **GenServer / `:gen_statem`** whose state machine is the LTS.
- The SQL transaction log is materialized as a **PubSub / Broadway pipeline** — every committed entry is a first-class message any actor can subscribe to.
- The C/C++ interop layer is preserved through Erlang **NIFs** or **Ports**, keeping the numerical core untouched while orchestration moves to the BEAM.
- Bisimilarity between the Lazarus original, the Prolog LTS, and the Elixir system is checked by replaying recorded traces through all three and diffing observable label sequences — the same technique proven against compiled Clarion DLLs.

The Elixir host exists in skeleton form under
[mcp_servers/elixir]({{ site.baseurl }}/components/mcp-servers.html); the
FreePascal/Lazarus MUZAQ source and the LTS extractor are the next pieces to
land.
