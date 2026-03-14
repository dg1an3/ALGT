# Model Checker

A SWI-Prolog model checker that exhaustively enumerates all possible interleavings of concurrent operations and identifies distinct final states. This detects race conditions and non-deterministic outcomes in systems with shared mutable resources.

## Motivation

The original ALGT verification suite deals with purely functional (input/output) predicates — given the same inputs, results are deterministic. Real systems, however, have concurrent operations that read and write shared state, and the order in which those operations interleave can produce different outcomes.

This model checker fills that gap: given a set of concurrent operation sequences (a **fork**), it generates every legal interleaving, executes each one against an initial resource state, and groups the results by distinct final state. If more than one distinct final state exists, the system has a **race condition**.

In conjunction with domain-driven design and event sourcing, this provides a powerful way of validating system behavior before implementation.

## Concepts

### Statements

A statement is either a **capture** (read) or an **update** (write), expressed with the `->` operator:

| Form | Meaning | Example |
|------|---------|---------|
| `ResourceKey -> Variable` | Capture: read the value of `ResourceKey` into `Variable` | `startHours -> S` |
| `Expression -> ResourceKey` | Update: evaluate `Expression` and write result to `ResourceKey` | `S + 4 -> startHours` |

Expressions can use arithmetic (`+`, `*`, etc.) and reference previously captured variables.

### Sequences

A **sequence** is an ordered list of statements representing one thread of execution:

```prolog
sequence([
    startHours -> S,
    S + 4 -> startHours
])
```

### Forks

A **fork** is a set of sequences that execute concurrently — the model checker explores all valid interleavings of their statements:

```prolog
fork([
    sequence([...]),   % thread 1
    sequence([...])    % thread 2
])
```

Statement order *within* each sequence is preserved; the interleaving happens *between* sequences.

### Resources

Resources are a dictionary (`dict`) of named values representing shared mutable state:

```prolog
Resources = dict{ startHours: 5, endHours: -6 }
```

## Module API

```prolog
:- module(model_checker, [
    valid/1,
    pruned_fork/2,
    model_to_sequence/2,
    analyze_pathways/3
]).
```

### `valid(+SequenceOrFork)`

Validates the structure of a model. A valid statement is either a capture (`ResourceKey -> Variable` where `Variable` is unbound) or an update (`Expression -> ResourceKey` where `ResourceKey` is an atom). Ensures you don't accidentally write a malformed model.

### `pruned_fork(+Fork, -PrunedFork)`

Removes empty sequences from a fork. Used internally during interleaving to discard completed threads.

### `model_to_sequence(+Fork, -Sequence)`

The core interleaving engine. Non-deterministically generates all possible sequential orderings of a fork's concurrent sequences. On backtracking, produces every legal interleaving.

**Algorithm**: At each step, non-deterministically pick a branch (via `nth0/4`), take its first statement, then recurse on the remaining fork (after pruning empty sequences). The base case is when all branches are exhausted.

### `analyze_pathways(+Model, +InitialResources -> -FinalResources, -SequenceLists)`

The top-level analysis predicate. For a given model and initial resource state:

1. Generates all interleavings via `model_to_sequence/2`
2. Executes each interleaving with `foldl(run_statement, ...)`
3. Groups interleavings by their distinct final resource state
4. On backtracking, yields each distinct outcome with the list of interleavings that produce it

If `analyze_pathways/3` yields more than one solution, the model has a race condition.

## Example: Race Condition Detection

Consider a C#-like program with a `Task.Run` creating concurrency:

```csharp
int startHours = 5;
int endHours = -6;

void UpdateStartAndEnd(int withOffset) {
    Task.Run(() => startHours = startHours + withOffset);
    UpdateEnd(withOffset * 2);
}

void UpdateEnd(int withOffset) {
    endHours = endHours + startHours + withOffset;
}

UpdateStartAndEnd(4);
```

Modeled in Prolog:

```prolog
WithOffset = 4,
Model = fork([
    % Thread 1: Task.Run — updates startHours
    sequence([
        startHours -> S1,
        S1 + WithOffset -> startHours
    ]),
    % Thread 2: UpdateEnd — reads startHours and endHours
    sequence([
        endHours -> E2,
        startHours -> S2,
        E2 + S2 + WithOffset * 2 -> endHours
    ])
]),
Resources_0 = dict{ startHours: 5, endHours: -6 },
analyze_pathways(Model, Resources_0 -> Final, Sequences).
```

The model checker finds **two distinct outcomes** depending on whether Thread 2 reads `startHours` before or after Thread 1 writes it — confirming a race condition.

## Running

Requires [SWI-Prolog](https://www.swi-prolog.org/).

```bash
cd model_checker
swipl -g "run_tests,halt" -t "halt(1)" model_checker.pl
```

The test suite includes validation tests, pruning tests, interleaving tests, statement execution tests, and the full race condition analysis example.

## Files

- `model_checker.pl` — Module source with embedded `plunit` test suite
- `README.md` — This file
