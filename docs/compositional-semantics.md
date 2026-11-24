---
title: Compositional Semantics
layout: default
parent: Design Documents
nav_order: 3
permalink: /design-docs/compositional-semantics.html
---

# Compositional Semantics and Independent Release

## TL;DR

Legacy systems that share a SQL database are almost never truly independently releasable, even when they are independently deployable. The reason is formal: a shared database is an uncontrolled communication channel, and components that communicate through an uncontrolled channel cannot be reasoned about in isolation. Releasing one component can silently change the observable behavior of another — through a schema migration, a missing transaction, a reinterpreted null — without either component's specification saying so.

The concept of **bisimilarity** offers a precise and actionable remedy. Two versions of a component are *bisimilar* if no external observer can tell them apart through their behavior. A release is genuinely safe when the new version is bisimilar to the old one with respect to every interface the component publishes — including its database interface. This is a stronger and more useful criterion than "the tests pass," because it asks the right question: *does anything in the environment observe a behavioral difference?*

Pursuing bisimilarity as a release criterion for legacy components means making their interfaces explicit enough to check. In practice this means: versioning the schema objects each component depends on, giving each component sole ownership of the tables it writes, expressing invariants as schema constraints or ACL contracts rather than tribal knowledge, and — eventually — replacing the shared database channel with typed event contracts that can be tested for backward compatibility directly. Each of these steps makes bisimilarity *checkable*, and checkable bisimilarity is what independent release actually requires.

----------

**NERD ALERT:** 🤓🤓🤓

## 1\. What Is Compositional Semantics?

In linguistics, the *Principle of Compositionality* — often called Frege's Principle — holds that the meaning of a complex expression is determined entirely by the meanings of its parts and the rules used to combine them. "The cat sat on the mat" means what it does because of *cat*, *sat*, *mat*, and the grammatical rules binding them — not because the whole phrase has some atomic, indivisible meaning of its own.

Computer science inherited this idea wholesale, and it sits at the heart of nearly every abstraction we trust.

**In programming language semantics**, compositionality means: the denotation of a compound program is a function of the denotations of its sub-programs. You don't need to look inside `f` to reason about `g(f(x))` — you only need `f`'s *interface*, its type, its contract. This is the formal basis for why type systems, module systems, and APIs work at all.

> **Analogy:** Think of a symphony score. A conductor can reason about how the brass and strings will combine *from their individual parts alone* — she doesn't need to hear them play together first. Each instrument's part is a self-contained semantic unit; the symphony is their composition. Compositionality is the promise that the parts don't secretly depend on which other parts happen to be rehearsing in the next room.

----------

## 2\. The Formal Skeleton

*(The mathematical formulation of compositionality and the definition of bisimulation are in [Appendix A](#appendix-a---formal-definitions). This section focuses on the concepts and their consequences.)*

A semantics is *compositional* if the meaning of any compound expression is fully determined by the meanings of its parts and the rule used to combine them — with no "reaching in" to inspect the internals of a sub-expression. The meaning of the whole is assembled from the meanings of the parts at their boundaries.

This has three direct computational consequences:

**Substitutability (Liskov-style).** If two components have the same meaning at their boundary, they are interchangeable in any context. You can release a new version without breaking anything that uses the old one's interface — provided the boundary meaning is preserved.

**Modular verification.** You can verify each component against its specification in isolation, then compose the proofs. You never need to reason about the whole system at once.

**Contextual equivalence.** Two programs are semantically equivalent if no observing *context* can tell them apart through their behavior. This is the basis for safe refactoring: if external observers cannot distinguish the old from the new, the change is safe.

**Bisimilarity** is compositionality made operational for concurrent and communicating systems. Two components are *bisimilar* if they can forever mimic each other's observable actions — every action one can take, the other can match, and the resulting states are again bisimilar. Crucially, bisimilarity is a *congruence*: if `A` and `B` are bisimilar, then substituting `B` for `A` in any larger system preserves the system's behavior. This is precisely the property that makes independent release safe.

In a shared-database context, bisimilarity has a concrete meaning: a new release of Component A is bisimilar to the old release if the database — and every other component that reads it — cannot observe any behavioral difference. Schema migrations, changed nullability handling, altered write ordering: any of these can break bisimilarity and make the "independent" release not independent at all.

----------

## 3\. The Problem: A Shared Legacy SQL Database

Now consider a practical scenario that many modernizing teams face:

> Multiple independently releasable software components — microservices, OIS modules, API layers — all read from and write to the **same legacy SQL database**, whose schema evolved organically over years and was never designed as a published interface.

This arrangement *systematically violates* compositional semantics. Here's why:

### 3.1 The Schema Is a Hidden Shared Channel

In process algebra terms, two processes communicate through named channels. If two processes share a channel `c`, their behaviors are no longer independent — they are *coupled* through `c`. The legacy database is exactly such a channel, but an *untyped*, *undeclared*, and *uncontrolled* one.

> **Analogy:** Imagine two musicians who are supposed to be playing from independent parts, but both have secretly tuned to a piano that is slightly flat. They sound fine together — until someone tunes the piano. Then both parts break, and neither musician knew the other was listening to the same reference pitch.

The database schema is the out-of-tune piano. Every component has silently coupled itself to it.

### 3.2 Semantic Obligations Are Invisible

A compositional system requires that each component's semantic obligations be *fully expressed at its boundary*. But in a shared-DB architecture:

- **Column semantics leak.** A nullable `VARCHAR(50)` column named `PatientStatus` carries business meaning that is not in its type. Component A may treat `NULL` as "unknown"; Component B may treat it as "inactive." Both are "correct" with respect to the schema — neither is correct with respect to the system.

- **Write-side effects are untracked.** When Component A deletes a row, Component B may fail silently on its next read. There is no contract expressing that A's writes are inputs to B.

- **Temporal ordering is implicit.** SQL commits from different components interleave non-deterministically. No component's specification captures this. And when components do not use transactions — which is common in legacy codebases that grew up around single-row updates and stored procedures — the problem deepens: multi-step writes are visible in their intermediate states to any concurrent reader.

These are *semantic gaps* — meaning that exists in the system but is not expressed in any component's interface.

### 3.3 Transactions Are the Missing Semantic Boundary

In a compositional system, a component's contract includes not just *what* it reads and writes, but *when* those writes become visible and *what invariants hold* at every observable moment. SQL transactions are the mechanism that makes this possible: a transaction wraps a multi-step write into a single atomic, isolated unit — other components either see all of it, or none of it.

When components skip transactions — as is routine in legacy codebases built around single-row stored procedures, row-by-row cursors, or ORMs that autocommit by default — this guarantee evaporates entirely. The consequences are three distinct consistency failures:

**Lost updates.** Component A reads a row, Component B reads the same row, A writes back, B writes back. B's write silently discards A's change. Without a transaction, there is no pessimistic lock; and without optimistic concurrency (a version column, a row timestamp), nothing detects the collision. The data is quietly wrong, and neither component's log shows an error.

**Partial write visibility.** A logical operation that touches three tables — say, inserting a clinical order, inserting its line items, and updating a status flag — may be observed by a concurrent reader in any of the intermediate states between the first and last write. A component reading after the first write but before the third will see an order with no line items, or an order with items but a stale status. This is a state the writing component never intended to exist, and the reading component has no way to know it is transient.

**Invariant erosion.** If a business invariant spans multiple rows or tables — *every active order must have at least one non-cancelled line item*, *a patient encounter must not be closed while a prescription is pending* — and no component enforces that invariant transactionally, then the invariant is only ever *approximately* true. It holds between writes, not during them. Any component that reads mid-write receives a lie that is semantically indistinguishable from the truth.

In bisimulation terms: a component that claims to maintain an invariant `I` is not bisimilar to its specification unless `I` holds at every point that an external observer can synchronize with it. Untransacted multi-step writes create observable intermediate states that violate `I` — the component's actual behavior diverges from its contract at observable moments, which means it cannot be composed safely with anything that depends on `I`.

> **Analogy:** A musician is supposed to play a chord — three notes, simultaneous. Instead, she plays them one at a time, quickly. To her, it sounds like a chord. To anyone listening at the right moment, it sounds like a broken arpeggio. The semantic contract said "chord." The implementation says "hopefully fast enough."

### 3.4 Release Independence Is an Illusion

The promise of independently releasable components is that you can verify a new release of Component A without re-testing Component B. But if they share a live database schema, this promise cannot be kept:

- A schema migration by A can silently change B's runtime semantics.

- A new index added for A's query patterns can alter B's transaction isolation behavior.

- A change to a stored procedure used by A may have been the only thing enforcing an invariant that B depended on.

The components are not bisimilar to their prior versions — an observing context (the database, or any component that reads through it) *can* tell the old release from the new one, which means the release was never truly independent.

----------

## 4\. Restoring Compositionality

The goal is to make each component's semantic obligations explicit and boundary-local. Here is a progression of strategies, from lightweight to rigorous:

### 4.1 Level 0 — Schema as Versioned Contract (Minimal Intervention)

Treat the database schema as a *published API*. Apply semantic versioning to schema objects:

- Every table, view, stored procedure, and column is a versioned artifact.

- Migrations are classified as breaking (column removal, type narrowing, constraint addition) or non-breaking (new nullable column, new view, additive index).

- Each component declares a *schema dependency manifest* — the specific objects and versions it relies on.

This doesn't eliminate coupling, but it makes coupling *explicit and traceable*. You've moved from an untyped shared channel to a named, versioned channel.

> **Analogy:** You haven't separated the musicians, but you've given them a published tuning standard and a version number. When the piano is retuned, everyone knows.

### 4.2 Level 1 — Anticorruption Layer per Component

Each component accesses the database only through its own *anticorruption layer* (ACL) — a set of typed read/write abstractions (repository interfaces, query objects, view models) that map between the component's domain model and the raw schema.

Semantic translation happens at the boundary. Nullability policy, enum interpretation, date semantics — all resolved inside the ACL, never leaked upward.

This gives each component a *locally coherent semantic domain* even if the underlying schema is chaotic. You've introduced a *semantic firewall*.

Compositional property recovered: **substitutability within a component's domain**. You can reason about the component against its ACL contract without reading the schema.

### 4.3 Level 2 — Owned Schema Segments with Cross-Component Views

Partition the schema: each component *owns* a set of tables and is the *sole writer* to them. Other components access foreign data only through published *read-only views* or API calls — never direct cross-component table writes.

```
Component A  →  owns {orders, order_items}
Component B  →  owns {patients, encounters}
Component B  →  reads A's data via view: v_active_orders_for_patient
```

The view is the *published interface*. A can change its internal table structure freely, as long as the view contract is preserved.

This is the database analog of *information hiding* — the module boundary principle that compositionality depends on.

Compositional property recovered: **contextual equivalence across schema migrations**. Refactoring A's internals doesn't change what B observes through the view.

#### 4.3.1 Consistency Within an Owned Segment — Tactical Options

Sole-writer ownership is the *structural* solution to the no-transaction problem: once Component A is the only writer to its tables, the cross-component partial-write hazard disappears by construction. No other component can observe A's intermediate states, because no other component writes to A's tables.

But the component still needs to manage consistency *internally*, especially if it was built without transactions. A progression of techniques, from lowest to highest friction:

**Convergent write patterns.** Design column updates to be *merge-safe* regardless of interleaving. Use `balance = balance + :delta` instead of `balance = :new_value`. Use append-only logs rather than in-place status updates. Use bitmask columns where each component owns a distinct bit and only ever sets (never clears) its own bits. These are informal CRDTs: their semantics are defined so that concurrent writes always produce a well-defined, correct result without coordination.

**Optimistic concurrency via version columns.** Add a `row_version` integer or `updated_at` timestamp to each owned table. Every update includes a `WHERE row_version = :seen_version` predicate and checks `rows_affected`. If zero rows were affected, the update lost a race and must retry or signal a conflict. This is compare-and-swap at the SQL level — single-row atomicity without a transaction, and detectable failure instead of silent data loss.

**Schema-enforced invariants.** Push invariant enforcement into the database itself via `CHECK` constraints, `UNIQUE` constraints, computed columns, and — where necessary — triggers. The database becomes the *invariant guardian*: a component cannot violate the invariant even mid-write, because the constraint fires at the statement level, not at the transaction level. This is imperfect (triggers are opaque and hard to test in isolation) but it is the pragmatic floor when retrofitting components that cannot be made transactional.

**The Outbox pattern for write + event atomicity.** When a component *does* have the ability to run a local transaction — even a small one — the Outbox pattern gives atomic "write + notify" without distributed transactions. Write the domain event to an `outbox` table in the *same* transaction as the business write. A separate relay process reads the outbox and publishes events to the stream, deleting processed rows. The event is guaranteed to be published if and only if the business write committed. This is the correct bridge between Level 2 (owned tables) and Level 3 (event streams), and it requires only that the owning component can transact against its own tables — which is a much weaker requirement than coordinating transactions across components.

**Sagas for multi-step operations that cannot be wrapped in a single transaction.** When a logical operation genuinely spans multiple components or multiple autonomous write steps, each step is individually committed, but every step has a defined *compensating operation* that reverses it if a later step fails. A saga coordinator tracks progress and issues compensations on failure. This makes eventual consistency *explicit and auditable* rather than accidental. In a regulated context, the saga log also serves as a traceability artifact: every step, and every compensation, is recorded.

> **Analogy:** The musician who cannot play a true chord has options. She can redesign her part so each note is meaningful on its own (convergent writes). She can play each note and check that the previous one is still ringing before she adds the next (optimistic concurrency). She can have the conductor enforce that certain combinations are never allowed (schema constraints). Or she can commit to playing the notes in order and have a plan for what to do if her bow slips mid-chord (saga with compensation). None of these are as clean as a true chord — but they are all far better than hoping the audience doesn't notice the arpeggio.

### 4.4 Level 3 — Event Streams as the Canonical Interface

The strongest form: components communicate *exclusively through events*, not through shared state. The database becomes a local implementation detail — each component's *private event store* or *materialized read model*.

```
Component A publishes:  OrderPlaced(orderId, patientId, ...)
Component B subscribes: OrderPlaced → updates its own local read model
```

Now the interface is a *typed event schema*, not a SQL table. Compositionality is fully restored:

- Each component's semantic obligations are expressed as event contracts.

- Release independence is genuine: A can be redeployed as long as its event schema is backward-compatible.

- Temporal coupling is made explicit through event ordering guarantees.

In CCS terms, you've replaced a shared mutable channel with explicit synchronization points — named, typed, and under version control.

> **Analogy:** Instead of both musicians secretly listening to the same piano, they now communicate through a *published score* with a version number. Musician A can practice in a different room entirely. Their coordination is explicit, not ambient.

----------

## 5\. Verification Strategy: Composing the Proofs

Once boundaries are explicit, you can *compose* correctness arguments:

| Component | Verified Against |
| --- | --- |
| ACL / Repository | Schema contract (type safety, nullability, constraint compliance) |
| Domain logic | ACL interface (pure, schema-free) |
| Event publisher | Domain event schema (structural + semantic contract) |
| Event consumer | Event schema + local read model invariants |
| Integration | Event ordering + temporal contract between components |

Each box is verifiable in isolation. Integration testing shrinks to verifying the *glue* between separately verified components — which is what compositional semantics promises.

For a legacy SQL system, a practical toolchain might include:

- **Schema contract tests** (SQL unit tests, Pester, tSQLt) validating that the schema version satisfies each component's declared dependencies.

- **Repository integration tests** validating ACL semantic translation.

- **Consumer-driven contract tests** (Pact, or a home-grown equivalent) validating event schema compatibility between producers and consumers.

- **Property-based tests** on domain logic, schema-free.

----------

## 6\. Applying This in a Modernization Context

When the legacy system is a mature, regulated product — an oncology information system, a clinical data platform — additional constraints apply:

- **Traceability requirements** mean that every semantic boundary must be documented in a way that satisfies a risk management framework (ISO 14971, IEC 62304). The schema dependency manifest and event contracts become regulatory artifacts.

- **Incremental migration** is essential. You cannot rewrite the shared database at once. The progression in §4 (Level 0 → Level 3) maps naturally onto a phased modernization roadmap, with each level independently deployable and auditable.

- **Semantic versioning of clinical concepts** (diagnosis codes, dosage units, laterality) requires the same rigor as schema versioning. The ACL is also the right place to enforce clinical terminology binding.

The goal at each phase: make the system *more compositional* — shrink the semantic surface area that components share, make what remains *explicit*, and verify each boundary in isolation.

----------

## 7\. Summary

A shared legacy SQL database is, formally, a large untyped channel through which all components are permanently entangled. Restoring compositionality is the work of progressively making that entanglement *explicit, typed, versioned, and bounded* — until each component can be reasoned about, tested, and released as a genuine semantic unit. Bisimilarity is the criterion that tells you when you have succeeded: when no observer can distinguish a new release from the old one through any interface the component exposes, the release is genuinely independent.

----------

*The ideal end state is not necessarily microservices or event sourcing — it is a system where the boundary of each component is a trustworthy contract, and where "independently releasable" means what it says: you can reason about a release in isolation, because the semantics don't leak.*

----------

## Appendix A — Formal Definitions

### A.1 Compositionality

A semantic mapping `⟦·⟧` is *compositional* if, for every compound syntactic form `E[e₁, e₂, ..., eₙ]`:

```
⟦E[e₁, ..., eₙ]⟧ = F_E(⟦e₁⟧, ..., ⟦eₙ⟧)
```

where `F_E` is a combining function determined solely by the *form* `E` — not by the internal structure of the `eᵢ`. The meaning of the whole depends on the meanings of the parts at their boundaries, and on nothing else. This is why black-box reasoning is possible: you never need to look inside a sub-expression to understand the compound.

### A.2 Bisimulation and Bisimilarity

Given a labeled transition system where processes have states and can perform observable actions (labels), a *bisimulation* is a binary relation `R` over process states such that whenever `(P, Q) ∈ R`:

- For every action `α` and state `P'` such that `P →^α P'`, there exists `Q'` such that `Q →^α Q'` and `(P', Q') ∈ R`.

- Symmetrically: for every action `α` and state `Q'` such that `Q →^α Q'`, there exists `P'` such that `P →^α P'` and `(P', Q') ∈ R`.

Two processes `P` and `Q` are *bisimilar* (written `P ~ Q`) if there exists some bisimulation `R` containing the pair `(P, Q)`. Bisimilarity is the largest bisimulation.

The critical property for software composition is that bisimilarity is a *congruence* with respect to the standard process operators of CCS and CSP — parallel composition (`|`), sequential composition (`.`), and choice (`+`). That is:

```
P ~ Q  ⟹  C[P] ~ C[Q]  for any context C[·]
```

This is the formal guarantee behind independent release: if the new version `Q` is bisimilar to the old version `P`, then any system `C` that previously contained `P` behaves identically after substituting `Q`. No integration test is needed — the behavioral equivalence is a theorem.

### A.3 Weak Bisimilarity

In practice, components perform internal actions (database reads, cache lookups, log writes) that are not visible to external observers. *Weak bisimilarity* (`P ≈ Q`) extends the definition above to allow one side to perform any number of internal `τ` steps before or after matching an observable action. This is the appropriate notion for real systems: we care only that externally observable behavior is equivalent, not that the internal implementation steps match one-for-one.

For legacy component release verification, weak bisimilarity with respect to the component's published interface (ACL contract, event schema, or API surface) is the practically achievable and sufficient criterion.

----------

## Appendix B — References

References are grouped by topic to make it easier to follow specific threads.

### B.1 Compositionality and the Principle of Frege

**Frege, G.** (1892). *Über Sinn und Bedeutung* \[On Sense and Reference\]. *Zeitschrift für Philosophie und philosophische Kritik*, 100, 25–50. The original source of the principle that the meaning of a compound expression is determined by the meanings of its parts. The "Principle of Compositionality" is Frege's, though the term itself was coined by later interpreters.

**Janssen, T. M. V.** (1997). Compositionality. In J. van Benthem & A. ter Meulen (Eds.), *Handbook of Logic and Language* (pp. 417–473). Elsevier. A thorough philosophical and formal treatment of compositionality across logic and linguistics, including the conditions under which it can fail.

**Partee, B., ter Meulen, A., & Wall, R.** (1990). *Mathematical Methods in Linguistics*. Kluwer. Covers the application of compositional semantics in natural language, providing the linguistic grounding that computer science drew from.

### B.2 Denotational Semantics

**Scott, D. S., & Strachey, C.** (1971). *Toward a Mathematical Semantics for Computer Languages* (Technical Monograph PRG-6). Oxford University Computing Laboratory. The foundational paper establishing denotational semantics as a compositional account of programming language meaning.

**Stoy, J. E.** (1977). *Denotational Semantics: The Scott-Strachey Approach to Programming Language Theory*. MIT Press. The standard textbook treatment of the Scott-Strachey approach; contains the formal development of `⟦·⟧` notation used in Appendix A.1.

**Tennent, R. D.** (1976). The denotational semantics of programming languages. *Communications of the ACM*, 19(8), 437–453. A readable introduction to denotational semantics and its compositional structure.

### B.3 Process Calculi — CCS and CSP

**Milner, R.** (1980). *A Calculus of Communicating Systems* (Lecture Notes in Computer Science, Vol. 92). Springer. The original monograph introducing CCS, labeled transition systems, and the notion of observational equivalence that bisimilarity formalizes.

**Milner, R.** (1989). *Communication and Concurrency*. Prentice Hall. The more accessible successor to the 1980 monograph; introduces weak bisimilarity (≈) and establishes the congruence results that justify compositional reasoning about concurrent processes.

**Hoare, C. A. R.** (1985). *Communicating Sequential Processes*. Prentice Hall. The CSP companion to CCS; traces and failures models are the alternative behavioral equivalence framework.

### B.4 Bisimulation and Bisimilarity

**Park, D.** (1981). Concurrency and automata on infinite sequences. In P. Deussen (Ed.), *Theoretical Computer Science* (Lecture Notes in Computer Science, Vol. 104, pp. 167–183). Springer. Park introduced the bisimulation relation independently of Milner; this is the paper that named it and proved it is the largest fixed point of the transition-matching functional.

**Sangiorgi, D.** (2011). *Introduction to Bisimulation and Coinduction*. Cambridge University Press. The modern definitive treatment; covers strong and weak bisimilarity, coinductive proof methods, and applications to typed and higher-order systems.

**Sangiorgi, D., & Rutten, J.** (Eds.) (2011). *Advanced Topics in Bisimulation and Coinduction*. Cambridge University Press. Companion volume covering up-to techniques, probabilistic bisimulation, and game-theoretic characterizations.

**Hennessy, M., & Milner, R.** (1985). Algebraic laws for nondeterminism and concurrency. *Journal of the ACM*, 32(1), 137–161. Establishes the Hennessy-Milner logic characterization of bisimilarity: two processes are bisimilar if and only if they satisfy exactly the same modal logic formulas. This is the link between bisimilarity and property-based specification.

### B.5 Substitutability and Behavioral Subtyping

**Liskov, B., & Wing, J.** (1994). A behavioral notion of subtyping. *ACM Transactions on Programming Languages and Systems*, 16(6), 1811–1841. The formal basis for the Liskov Substitution Principle: a subtype must be substitutable for its supertype in any client context. This is the object-oriented instance of compositional substitutability.

### B.6 Domain-Driven Design and the Anticorruption Layer

**Evans, E.** (2003). *Domain-Driven Design: Tackling Complexity in the Heart of Software*. Addison-Wesley. Introduces the Anticorruption Layer pattern (Ch. 14), Bounded Contexts, and the Strategic Design patterns that map directly onto the Level 1 and Level 2 strategies in §4. The definitive reference for the architectural vocabulary used throughout this primer.

**Vernon, V.** (2013). *Implementing Domain-Driven Design*. Addison-Wesley. The practical companion to Evans; provides detailed implementation guidance for context mapping, ACLs, and published language patterns.

### B.7 Saga Pattern and Compensating Transactions

**Garcia-Molina, H., & Salem, K.** (1987). Sagas. *ACM SIGMOD Record*, 16(3), 249–259. The original paper introducing long-lived transactions decomposed into a sequence of local transactions with compensating actions. The formal basis for the Saga pattern described in §4.3.1.

### B.8 Event Sourcing, the Outbox Pattern, and Microservices Consistency

**Fowler, M.** (2005). *Event Sourcing*. martinfowler.com. <https://martinfowler.com/eaaDev/EventSourcing.html>. The canonical description of event sourcing as an architectural pattern.

**Richardson, C.** (2018). *Microservices Patterns: With Examples in Java*. Manning. Covers the Outbox pattern (Ch. 3), Saga orchestration and choreography (Ch. 4), and CQRS (Ch. 7) in depth. The most practical reference for the consistency strategies described in §4.3.1.

**Kleppmann, M.** (2017). *Designing Data-Intensive Applications*. O'Reilly. Chapters 11–12 provide an authoritative treatment of event streams, log-based messaging, and the consistency guarantees achievable without distributed transactions. Essential background for the Level 3 strategy in §4.4.

### B.9 Conflict-Free Replicated Data Types (CRDTs)

**Shapiro, M., Preguiça, N., Baquero, C., & Zawirski, M.** (2011). Conflict-free replicated data types. In *Proceedings of the 13th International Symposium on Stabilization, Safety, and Security of Distributed Systems* (SSS 2011), Lecture Notes in Computer Science, Vol. 6976, pp. 386–400. Springer. The foundational paper on CRDTs; the "convergent write patterns" described in §4.3.1 are informal applications of the CRDT idea to SQL column design.

### B.10 Consumer-Driven Contract Testing

**Robinson, I.** (2006). *Consumer-Driven Contracts: A Service Evolution Pattern*. <https://martinfowler.com/articles/consumerDrivenContracts.html>. The original formulation of consumer-driven contract testing as a discipline for verifying that service providers remain backward-compatible with their consumers — an applied instance of bisimilarity checking at the API level.

**Pact Foundation.** *Pact Documentation*. [https://docs.pact.io](https://docs.pact.io/). The reference implementation of consumer-driven contract testing; the toolchain cited in §5.