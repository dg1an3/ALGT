# FDA Medical Device Developer Tool (MDDT) Qualification Proposal

## Tool Name: ALGT-FMEA — Automated Software Failure Mode and Effects Analysis for Legacy Medical Device Software

### Submission to: FDA Center for Devices and Radiological Health (CDRH)
### MDDT Program — Software Analysis Tool Qualification

---

## 1. Executive Summary

This proposal requests FDA qualification of **ALGT-FMEA**, a multi-layer software analysis toolset, as a Medical Device Developer Tool (MDDT) for conducting **software Failure Mode and Effects Analysis (FMEA)** on legacy medical device software systems.

ALGT-FMEA combines formal verification, execution trace comparison, probabilistic inference, concurrent operation analysis, and machine learning-based anomaly detection to systematically identify and characterize software failure modes in radiation oncology systems such as MOSAIQ (Clarion 4GL) and Monaco (C++).

**Proposed Context of Use (COU):** Supporting software FMEA activities during:
- Pre-market submissions (510(k), PMA) for software modifications to existing medical devices
- Post-market surveillance and change impact analysis
- Legacy system modernization risk assessment
- Software of Unknown Provenance (SOUP) risk characterization

**Key Innovation:** Rather than relying solely on manual code review or conventional static analysis, ALGT-FMEA constructs an *executable semantic model* of legacy source code, enabling automated exploration of failure modes through simulation, trace comparison against compiled binaries, and probabilistic analysis of execution paths.

---

## 2. Background and Unmet Need

### 2.1 The Legacy Medical Device Software Challenge

Radiation oncology systems such as MOSAIQ (Elekta) represent decades of accumulated software in languages like Clarion 4GL — a domain-specific language with limited tooling support. These systems:

- Control patient treatment delivery and dose calculation
- Contain hundreds of thousands of lines of validated, regulated code
- Require ongoing modification for clinical requirements, interoperability, and cybersecurity
- Lack modern static analysis tool support (no Clarion analyzers exist commercially)
- Present significant risk when modified, due to complex interdependencies

### 2.2 Current FMEA Limitations for Software

IEC 62304 and FDA guidance on software validation require hazard analysis including FMEA. For legacy systems, current practice relies on:

1. **Manual code review** — Labor-intensive, subjective, and unable to explore all execution paths
2. **Black-box testing** — Cannot systematically enumerate internal failure modes
3. **Generic static analysis** — Tools like Coverity, Polyspace, and SonarQube do not support Clarion 4GL or many legacy languages
4. **Expert judgment** — Subject to cognitive bias and limited by reviewer familiarity with aged codebases

These limitations leave a gap: **no systematic, tool-supported method exists for performing software FMEA on legacy medical device code written in unsupported languages.**

### 2.3 Regulatory Context

- **IEC 62304:2006+AMD1:2015** — Requires software hazard analysis proportional to safety classification
- **FDA Guidance: Content of Premarket Submissions for Device Software Functions (2023)** — Expects risk analysis including software failure modes
- **FDA Guidance: Off-The-Shelf Software Use in Medical Devices (2019)** — Addresses SOUP risk characterization
- **ISO 14971:2019** — Risk management process requiring systematic hazard identification
- **AAMI TIR57:2016** — Principles for medical device security risk management

---

## 3. Tool Description

### 3.1 Architecture Overview

ALGT-FMEA is a layered analysis platform built on SWI-Prolog and Logtalk, with Python and CDB (Windows debugger) integration for ground-truth validation.

```
┌─────────────────────────────────────────────────────────────┐
│                    ALGT-FMEA Platform                        │
├─────────────────────────────────────────────────────────────┤
│  Layer 8: Semantic Fault Injection (LLM-driven)             │
│  Layer 7: Anomaly Detection (GNN-VAE)                       │
│  Layer 6: Probabilistic Inference (PyMC / Stan)             │
│  Layer 5: Concurrent Safety (Model Checker)                 │
│  Layer 4: Specification Validation (Scenario DSL)           │
│  Layer 3: Domain Model Formalization (Logtalk)              │
│  Layer 2: Execution Trace Comparison (CDB ground truth)     │
│  Layer 1: Formal Algorithm Verification (ALGT tests)        │
├─────────────────────────────────────────────────────────────┤
│  Foundation: Clarion Parser (DCG) + Execution Engine        │
│  198 passing tests | Pluggable storage/UI backends          │
└─────────────────────────────────────────────────────────────┘
```

### 3.2 Foundation: Clarion Language Simulator

The core of ALGT-FMEA is a **unified Clarion language simulator** that parses and executes Clarion 4GL source code in a controlled, instrumented environment.

**Parser** (DCG-based):
- Parses real production `.clw` source files
- Handles MEMBER/PROGRAM declarations, FILE/GROUP/WINDOW structures
- Supports all control flow: IF/ELSIF/ELSE, LOOP WHILE/UNTIL, CASE, BREAK/CYCLE
- Produces structured AST for downstream analysis

**Execution Engine** (modular architecture):
- Variable management with scoping (local/global)
- Procedure/function calls with parameter passing
- WINDOW/ACCEPT event loop simulation
- FILE I/O with pluggable storage backends (memory, CSV, ODBC)
- Built-in function library (CLIP, LEN, CHR, VAL, TODAY, CLOCK, etc.)
- 198 automated tests covering parser, arithmetic, control flow, I/O, GUI simulation

**FMEA Relevance:** The simulator enables *what-if analysis* — injecting faults, boundary values, and unexpected inputs to systematically explore how the software responds to abnormal conditions.

### 3.3 Layer 1: Formal Algorithm Verification

Ten formal verification test suites validate geometric algorithms critical to radiation therapy:

| Test Suite | Algorithm Verified | Patient Safety Relevance |
|---|---|---|
| ALGT_BEAM_VOLUME | Radiation beam volume generation | Incorrect beam volume → wrong tissue irradiated |
| ALGT_MESH_GEN | 3D mesh from contour data | Incorrect anatomy representation → treatment errors |
| ALGT_MARGIN3D | 3D structure margin expansion | Wrong margins → target underdosage or OAR overdosage |
| ALGT_MARGIN2D | 2D margin calculations | Planar margin errors in BEV |
| ALGT_ISODENSITY | Dose isodensity contour extraction | Incorrect isodose display → clinical misjudgment |
| ALGT_BEAM_CAX | Central axis / isocenter positioning | Beam misalignment → geographic miss |
| ALGT_STRUCT_PROJ | Structure projection through beam | Incorrect BEV → wrong shielding |
| ALGT_SSD | Source-to-surface distance | Wrong SSD → dose calculation error |
| ALGT_MESH_PLANE | Mesh-plane intersection | Contour reconstruction errors |
| ALGT_BEAM_VOL_PLANAR | Planar beam volume | 2D beam geometry errors |

Each test:
1. Loads clinical data (DICOM, beam parameters)
2. Executes the algorithm under test
3. Verifies results against Prolog-computed geometric predicates
4. Reports with configurable tolerance thresholds

**FMEA Application:** These tests identify *algorithmic failure modes* — conditions where geometric calculations produce clinically incorrect results (e.g., mesh degeneration at extreme gantry angles, margin collapse for non-convex structures).

### 3.4 Layer 2: Execution Trace Comparison

Three levels of trace comparison establish **ground truth equivalence** between the Prolog simulator and compiled Clarion DLLs:

**Level 1 — Procedure-level traces:**
Both the Prolog simulator and the compiled DLL (via Python ctypes) emit `CALL ProcName(args) -> result` lines. Traces are compared with `diff`.

**Level 1b — CDB debugger traces (hardware breakpoints):**
The Windows CDB debugger sets breakpoints on exported DLL symbols, reads arguments from the x86 stack, executes the function, and captures return values from `eax`. This provides **ground truth from the actual compiled binary** with no instrumentation overhead.

**Level 1c — Variable-level comparison:**
Headless DLLs expose get/set operations on internal variables. CDB traces each operation, enabling comparison of **internal state evolution** between the compiled DLL and the Prolog simulator.

**Level 2 — Statement-level traces (simulator only):**
The Prolog simulator traces every statement: assign, call, if (with condition value and branch taken), loop enter/exit, break, return.

```
Example CDB vs. Prolog comparison output:

--- Comparison ---
  OK: CALL SSOpen() -> 0
  OK: CALL SSAddReading(1, 100, 50) -> 0
  OK: CALL SSAddReading(2, 200, 25) -> 0
  OK: CALL SSCalculateWeightedAverage() -> 152
  OK: CALL SSCleanupLowReadings(150) -> 1
  OK: CALL SSClose() -> 0

RESULT: All 8 trace entries match!
```

**FMEA Application:** Trace comparison validates that the simulator faithfully represents the compiled code. Discrepancies between traces indicate either simulator limitations (documented) or actual compiler-introduced behaviors that differ from source-level semantics — both of which are relevant failure modes.

### 3.5 Layer 3: Domain Model Formalization

Logtalk-based domain models encode business rules, invariants, and state machines for clinical subsystems:

- **Appointment Domain** — Scheduling state machine with invariants (cannot start before confirmed, cannot modify after started)
- **Imaging Services** — Image import, review, approval workflow with event sourcing
- **Subject/Treatment Image** — Image lifecycle with state constraints (cannot rescale after approval)

All domain models use **event sourcing**, providing a complete audit trail of every state change.

**FMEA Application:** Formalized domain models make business rule violations detectable as explicit constraint failures. The event-sourced design enables *temporal analysis* — examining whether specific sequences of operations can lead to invalid states.

### 3.6 Layer 4: Specification-Based Validation (Scenario DSL)

A declarative testing DSL enables **specification-driven FMEA**:

```prolog
scenario('Invalid sensor reading rejected',
  setup([
    program(SensorSource),
    var('ReadingValue', -1)        % Negative reading (invalid)
  ]),
  actions([
    click('AddButton'),
    run_to_completion
  ]),
  expectations([
    message_contains('Invalid'),   % Error message displayed
    var('RecordCount', 0)          % No record added
  ])
).
```

Scenarios are executable specifications that:
- Define preconditions (setup)
- Simulate user interactions (actions)
- Assert expected outcomes (expectations)
- Report pass/fail with detailed failure reasons

**FMEA Application:** Each scenario encodes a potential failure mode and its expected mitigation. Scenario libraries systematically cover:
- Boundary value inputs
- Invalid state transitions
- Race conditions in event processing
- Error handling adequacy

### 3.7 Layer 5: Concurrent Safety Verification

The model checker formally verifies concurrent operations by exploring **all possible interleavings**:

```prolog
% Model: Two concurrent threads incrementing a shared counter
Model = fork([
  sequence([read(Counter) -> Local1, Local1 + 1 -> Counter]),
  sequence([read(Counter) -> Local2, Local2 + 1 -> Counter])
]),

% Result: Counter can be 1 OR 2 — race condition detected
analyze_pathways(Model, {Counter: 0} -> FinalStates, Interleavings).
```

The checker:
- Enumerates all possible execution orderings
- Computes final state for each interleaving
- Groups interleavings by outcome
- Identifies non-deterministic results (race conditions)

**FMEA Application:** Concurrent failure modes are among the hardest to detect by manual review. The model checker provides **exhaustive proof** of determinism or documents all possible non-deterministic outcomes — directly mapping to FMEA severity/occurrence ratings.

### 3.8 Layer 6: Probabilistic Execution Analysis

The execution tracer exports program behavior in formats suitable for **probabilistic inference**:

**Probabilistic Graphical Model (PGM):**
- Branch decisions modeled as Bernoulli random variables
- Assignment nodes as observed variables
- Conditional probability tables derived from control flow structure

**PyMC Export:**
- Generates executable Python code for Bayesian inference
- Beta-Bernoulli conjugate priors for branch probabilities
- Posterior inference over branch execution frequencies

**Stan Export:**
- Generates compiled statistical models
- High-performance MCMC sampling for path probability estimation
- Generated quantities: new path sampling, path probability computation

**FMEA Application:** Probabilistic analysis answers questions critical to FMEA:
- *"What is the probability that execution reaches this error-handling code?"*
- *"Given observed field data, what is the posterior probability of this failure mode?"*
- *"Which execution paths are statistically anomalous given the training corpus?"*

### 3.9 Layer 7: Machine Learning Anomaly Detection (GNN-VAE)

The execution tracer exports execution graphs in formats compatible with **Graph Neural Network Variational Autoencoders**:

- Execution traces encoded as directed graphs (nodes = statements, edges = control/data flow)
- Node features: one-hot encoded statement type
- Edge features: control flow vs. data dependency
- Branch decision annotations

The GNN-VAE:
1. **Encodes** execution traces into a learned latent space
2. **Learns** the distribution of "normal" execution patterns
3. **Detects anomalies** as traces far from the learned distribution
4. **Generates** synthetic traces for coverage analysis

**FMEA Application:**
- **Anomaly detection:** Identify execution traces that deviate from learned normal behavior
- **Coverage gaps:** Synthetic trace generation reveals untested execution paths
- **Clustering:** Group similar failure modes for systematic analysis
- **Regression detection:** New code changes that shift the trace distribution

### 3.10 Layer 8: Semantic Fault Injection Framework (LLM-Driven)

A novel approach to fault injection that leverages Large Language Models' **naive domain understanding** to generate data inputs that are *semantically plausible but clinically incorrect*.

**The Problem with Existing Fault Injection:**

| Approach | Weakness |
|---|---|
| Random fuzzing | Generates obviously invalid inputs rejected by input validation — never reaches business logic |
| Boundary value analysis | Limited to numeric edges; misses semantic errors (correct format, wrong meaning) |
| Expert-crafted test cases | Expensive, limited coverage, biased by expert's mental model |
| Mutation testing | Mutates code, not data — misses data-driven failure modes |

**The Semantic Middle Ground:**

An LLM "knows" the domain well enough to generate inputs that *look right* but are *wrong in ways that matter clinically*. For radiation oncology data-driven systems:

```
Category: Unit Confusion (passes format validation, wrong magnitude)
  - Prescription dose: 200 Gy instead of 2 Gy (cGy/Gy confusion)
  - Monitor units: 50 instead of 500 (decimal place error)
  - SSD: 1000 mm instead of 100 cm (unit mismatch)

Category: Orientation/Sign Errors (valid values, wrong frame of reference)
  - Patient position: FFS instead of HFS (systematic sign flip)
  - Couch angle: 90° instead of 270° (equivalent but opposite convention)
  - Lateral offset: +2.5 instead of -2.5 cm (left/right confusion)

Category: Plausible Substitution (correct type, wrong instance)
  - Treatment field applied to wrong anatomical structure
  - Beam energy 6 MV instead of 6 MeV (photon vs. electron)
  - Wednesday fraction delivered on Thursday schedule

Category: Boundary Exploitation (valid but extreme clinical values)
  - Gantry angle: 359.9° (near-wrap numerical instability)
  - Very small field size: 0.5 x 0.5 cm (dosimetric uncertainty)
  - 45-fraction regimen (unusual but valid, tests loop limits)

Category: Temporal/Sequencing Errors (valid operations, wrong order)
  - Plan approval before dose calculation completes
  - Image acquisition after treatment field delivery
  - Prescription modification during active treatment session
```

**Architecture:**

```
┌──────────────────────────────────────────────────┐
│  LLM Fault Generator                              │
│  (Domain-aware, schema-constrained)               │
│                                                    │
│  Inputs:                                           │
│  ├─ Data schema (FILE/GROUP declarations from AST) │
│  ├─ Domain ontology (radiation oncology terms)     │
│  ├─ Value constraints (ranges, enumerations)       │
│  └─ Clinical context (treatment type, site, etc.)  │
│                                                    │
│  Outputs:                                           │
│  ├─ Fault vectors with clinical rationale          │
│  ├─ Expected failure category                      │
│  └─ Severity hypothesis                            │
└────────────┬─────────────────────────────────────┘
             │ Fault vectors
             ▼
┌──────────────────────────────────────────────────┐
│  Clarion Simulator (Layers 1-7)                   │
│  ├─ Execute with injected data                    │
│  ├─ Capture execution trace                       │
│  ├─ Compare against nominal trace                 │
│  └─ Detect invariant violations                   │
└────────────┬─────────────────────────────────────┘
             │ Execution results
             ▼
┌──────────────────────────────────────────────────┐
│  Failure Mode Classifier                          │
│  ├─ Did the fault propagate to output?            │
│  ├─ Was it caught by validation logic?            │
│  ├─ What was the clinical effect magnitude?       │
│  └─ Map to FMEA severity/detection ratings        │
└──────────────────────────────────────────────────┘
```

**Integration with Existing Layers:**
- The LLM extracts data schemas from the **Clarion parser** (Layer 1 foundation) — FILE declarations, GROUP structures, and variable types provide the injection points
- Fault vectors are executed through the **simulator** with the **execution tracer** capturing behavior
- Nominal vs. faulted traces are compared using **trace comparison** (Layer 2)
- Probabilistic models (Layer 6) estimate the likelihood of each fault class occurring in practice
- The GNN-VAE (Layer 7) learns to detect faulted execution patterns automatically

**Why LLM-Naive Understanding is Specifically Valuable:**

The LLM's understanding of radiation oncology is *incomplete and imprecise* — which is exactly the kind of understanding that causes real-world data entry errors. A radiation therapist who confuses cGy and Gy, or a physicist who transposes a sign, is making the same class of "naive but domain-aware" errors that an LLM would generate. This makes LLM-generated faults a **realistic proxy for human data entry errors** in clinical systems.

**FMEA Application:** Semantic fault injection directly populates the FMEA failure mode column with *data-driven failure modes* — the class of errors where the software functions correctly but operates on incorrect input that was plausible enough to pass validation. These are historically the hardest failure modes to enumerate systematically.

---

## 4. Proposed Context of Use

### 4.1 Primary Use Case: Software FMEA for Legacy Medical Device Modifications

**When:** A manufacturer proposes a software change to a legacy medical device (e.g., MOSAIQ treatment management system, Monaco treatment planning system)

**How ALGT-FMEA supports the FMEA process:**

| FMEA Column | ALGT-FMEA Contribution |
|---|---|
| **Failure Mode Identification** | LLM semantic fault injection; simulator-based exploration; concurrent interleaving analysis |
| **Failure Effects** | Execution trace analysis showing propagation from fault to observable output |
| **Severity Assessment** | Domain model invariant violations mapped to clinical impact categories |
| **Cause Analysis** | Trace comparison (CDB vs. simulator) identifying root cause at statement level |
| **Occurrence Estimation** | Probabilistic inference (PyMC/Stan) over branch execution frequencies from field data |
| **Detection Assessment** | Scenario DSL coverage analysis; GNN-VAE anomaly detection capability |
| **Risk Priority Number** | Computed from probabilistic severity, occurrence, and detection estimates |

### 4.2 Secondary Use Cases

1. **SOUP Risk Characterization** — Analyzing third-party or legacy code of unknown provenance
2. **Change Impact Analysis** — Comparing execution traces before/after a software modification
3. **Regression Risk Assessment** — Detecting behavioral changes via trace distribution shifts
4. **Cybersecurity Risk Analysis** — Concurrent operation verification for thread-safety in networked medical devices

### 4.3 Intended Users

- Software quality engineers at medical device manufacturers
- Regulatory affairs specialists preparing pre-market submissions
- Independent software assessors conducting third-party reviews
- Post-market surveillance teams analyzing field issues

### 4.4 Limitations and Exclusions

ALGT-FMEA is **NOT** proposed for:
- Replacing manual clinical risk assessment by domain experts
- Serving as the sole basis for safety classification decisions
- Validating real-time performance or timing requirements
- Analyzing hardware failure modes
- Producing results without expert interpretation

The tool **augments** but does not replace human judgment in the FMEA process.

---

## 5. Analytical Validation Plan

### 5.1 Simulator Fidelity Validation

**Objective:** Demonstrate that the Clarion simulator faithfully represents compiled Clarion code behavior.

| Test | Method | Acceptance Criteria |
|---|---|---|
| Procedure-level trace match | Compare Prolog vs. ctypes output | 100% match on all exported procedures |
| CDB ground-truth match | Compare Prolog vs. CDB hardware breakpoint traces | 100% match on arguments and return values |
| Variable-level state match | Compare internal variable evolution | 100% match on all tracked variables |
| Coverage | Run against production MOSAIQ procedures | >80% of parser-supported language constructs exercised |

**Current Status:** 198 passing tests; 3 Clarion projects with CDB trace comparison (sensor-data, form-demo, treatment-offset); all traces match.

### 5.2 FMEA Completeness Validation

**Objective:** Demonstrate that ALGT-FMEA identifies failure modes that manual review alone would miss.

**Study Design:**
1. Select 5 historical software defects from MOSAIQ/Monaco field reports (known failure modes)
2. Apply ALGT-FMEA to the pre-fix code version *without knowledge of the defect*
3. Measure whether ALGT-FMEA identifies the failure mode or a related hazard
4. Compare ALGT-FMEA findings against manual FMEA performed by experienced engineers

**Metrics:**
- Sensitivity: Proportion of known failure modes detected
- Specificity: Proportion of non-failures correctly classified
- Time efficiency: Hours required vs. manual FMEA

### 5.3 Probabilistic Model Validation

**Objective:** Validate that probabilistic execution path estimates correlate with observed field frequencies.

**Method:**
1. Collect execution logs from deployed MOSAIQ instances (anonymized)
2. Train PyMC/Stan models on execution trace corpus
3. Compare predicted branch probabilities against observed frequencies
4. Validate anomaly detection (GNN-VAE) against known anomalous executions

### 5.4 Concurrent Safety Validation

**Objective:** Demonstrate model checker correctly identifies known race conditions.

**Method:**
1. Inject known race conditions into test programs
2. Verify model checker identifies all non-deterministic outcomes
3. Verify model checker does not produce false positives on correctly synchronized code

---

## 6. Benefits to FDA and Medical Device Ecosystem

### 6.1 Addressing the Legacy Software Gap

No commercially available tools support FMEA for Clarion 4GL or many other legacy medical device languages. ALGT-FMEA fills this gap with a language-agnostic architecture (DCG parser can be extended to additional languages).

### 6.2 Reproducible, Auditable Evidence

Every ALGT-FMEA analysis produces:
- Execution traces (deterministic, reproducible)
- Formal verification results (pass/fail with tolerances)
- Probabilistic models (distributional parameters with credible intervals)
- Scenario test results (specification-based, reviewable)

All outputs are machine-readable and version-controllable, supporting regulatory review.

### 6.3 Scalability

Manual FMEA for a system with hundreds of thousands of lines of code is impractical for all but the highest-risk modifications. ALGT-FMEA enables **systematic, automated exploration** of failure modes, scaling the FMEA process to match the complexity of modern medical device software.

### 6.4 Post-Market Surveillance

The GNN-VAE anomaly detection capability enables **continuous monitoring** of execution patterns in deployed systems, supporting proactive identification of emerging failure modes before adverse events occur.

---

## 7. Qualification Submission Timeline

| Phase | Activity | Duration |
|---|---|---|
| Phase 1 | Tool documentation and validation protocol | 3 months |
| Phase 2 | Simulator fidelity validation study | 4 months |
| Phase 3 | FMEA completeness validation study | 4 months |
| Phase 4 | Probabilistic model validation | 3 months |
| Phase 5 | Submission preparation and pre-submission meeting | 2 months |
| Phase 6 | FDA review and qualification | 6-12 months |

---

## 8. References

1. FDA. *Medical Device Development Tools (MDDT) Program.* CDRH, 2017.
2. FDA. *Content of Premarket Submissions for Device Software Functions.* Guidance, 2023.
3. FDA. *Off-The-Shelf Software Use in Medical Devices.* Guidance, 2019.
4. IEC 62304:2006+AMD1:2015. *Medical device software — Software life cycle processes.*
5. ISO 14971:2019. *Medical devices — Application of risk management to medical devices.*
6. AAMI TIR57:2016. *Principles for medical device security — Risk management.*
7. IEC 60812:2018. *Failure modes and effects analysis (FMEA and FMECA).*

---

## Appendix A: Technology Component Inventory

| Component | Language | Purpose | Tests |
|---|---|---|---|
| Clarion Parser (DCG) | SWI-Prolog | Parse .clw source to AST | 11 |
| Execution Engine | SWI-Prolog | Execute Clarion programs | 187 |
| Execution Tracer | SWI-Prolog | Capture execution DAG, export ML formats | Integrated |
| ALGT Verification | SWI-Prolog | Geometric algorithm testing | 10 suites |
| Model Checker | SWI-Prolog | Concurrent interleaving analysis | Integrated |
| Scenario DSL | SWI-Prolog | Specification-based testing | Integrated |
| Domain Models | Logtalk | Business rule formalization | 3 domains |
| Storage Backends | Logtalk | Memory/CSV/ODBC dispatch | 7 tests |
| CDB Tracing | Python/CDB | Ground-truth DLL comparison | 3 projects |
| ML Exports | SWI-Prolog | PGM, PyMC, Stan, GNN-VAE | Integrated |
| Semantic Fault Injector | LLM + Prolog | Domain-aware data fault generation | Proposed |
| MCP Servers | Python | Claude Code integration | 3 implementations |

## Appendix B: Clarion Language Coverage

The parser and simulator currently support:

- **Declarations:** PROGRAM, MEMBER, MAP, PROCEDURE, FUNCTION, ROUTINE
- **Data Types:** LONG, SHORT, REAL, STRING, CSTRING, BYTE, GROUP, QUEUE, FILE
- **Control Flow:** IF/ELSIF/ELSE/END, LOOP/WHILE/UNTIL/END, CASE/OF/OROF/END, BREAK, CYCLE, DO, RETURN
- **Expressions:** Arithmetic (+, -, *, /, %), comparison (<, >, =, <=, >=, <>), logical (AND, OR, NOT), string concatenation (&)
- **I/O:** OPEN, CLOSE, ADD, PUT, GET, SET, NEXT, PREVIOUS, DELETE, RECORDS
- **GUI:** WINDOW, ACCEPT, EVENT:Accepted, FIELD, DISPLAY, UPDATE, SELECT
- **Builtins:** MESSAGE, CLIP, LEN, CHR, VAL, TODAY, CLOCK, FORMAT, SIZE, RECORDS

## Appendix C: Mapping to IEC 62304 Software Safety Classification

| IEC 62304 Class | ALGT-FMEA Analysis Depth |
|---|---|
| Class A (no injury possible) | Layer 1 (formal algorithm verification) + Layer 4 (scenario testing) |
| Class B (non-serious injury possible) | Layers 1-5 (adds trace comparison, domain models, concurrency checking) |
| Class C (death or serious injury possible) | All 8 layers including probabilistic inference, anomaly detection, and semantic fault injection |

---

*Document Version: 1.0*
*Date: 2026-03-13*
*Author: Derek Lane*
*Status: DRAFT — For internal review prior to FDA pre-submission*
