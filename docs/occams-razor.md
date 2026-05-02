# Programming with Occam's Razor

*How predicate logic compresses legacy semantics into a form that reasoning systems can actually hold in mind*

-----

## The Attentional Window Problem

The most important property of a program representation isn't correctness — it's how much of it fits in a reasoning system's attention at once.

This is true for human programmers. A function that fits on one screen is easier to reason about than one that requires scrolling. A module whose invariants can be held in working memory is easier to modify safely than one whose behavior emerges from distant interactions. We have always known this intuitively, and we have always built tools — type systems, abstractions, DSLs — to manage the gap between what we need to express and what we can hold in mind.

It is also true, in a newly concrete way, for large language models. An LLM's context window is finite, and attention within that window is not uniformly distributed. The model reasons better when more of the *relevant structure* of a problem fits within the window — not more of the *text*, but more of the *semantics*. These are not the same thing. A program can consume thousands of tokens while conveying only a handful of meaningful constraints. Conversely, a compact logical representation can encode the full behavioral specification of a complex system in a fraction of the space.

The choice of representation is therefore a first-class engineering concern — not aesthetics, not elegance for its own sake, but a direct determinant of reasoning capacity. And this is where William of Ockham, a fourteenth-century Franciscan friar, turns out to have something useful to say.

-----

## The Razor

William of Ockham formulated the principle we now call Occam's Razor: *entities should not be multiplied beyond necessity*. In its usual application, it is a heuristic for theory selection — given two explanations with equal predictive power, prefer the one that posits fewer entities.

But the razor is more general than that. It is a principle of parsimony applied to *representations*: any element in your description that isn't doing necessary explanatory work is dead weight. It clutters the picture without adding to the picture's fidelity.

Applied to programming, the question becomes: which entities in a program representation are doing genuine semantic work, and which are merely implementation scaffolding? The answer, it turns out, varies dramatically across paradigms — procedural, functional, and predicate logic — and the variation is not incidental. It is the organizing structure of the argument that follows.

-----

## The Procedural Tax

Procedural code specifies behavior as a sequence of mutations to state. This is cognitively cheap to *produce* — you are scripting the machine step by step — but expensive to *reason about*, because the semantics are entangled with the mechanics.

Consider a fragment of Clarion drawn from a radiation oncology information system — specifically, the embed point logic that fires when a clinician enters a prescribed dose for a treatment site:

```clarion
RxDetail PROCEDURE
  
  ! ... window declaration and local variable setup elided ...
  
  TotalDose         DECIMAL(8,2)
  FractionsEntered  SHORT
  DosePerFx         DECIMAL(8,2)
  ValidationCode    SHORT

  CODE

  OPEN(RxDetailWindow)
  ACCEPT

    ! Embed: AfterField
    CASE FIELD()

    OF RXS:PrescribedDose
      IF RXS:PrescribedDose > 0
        IF RXS:Fractions > 0
          DosePerFx = RXS:PrescribedDose / RXS:Fractions
          IF DosePerFx > MaxSingleFractionDose  ! global constant
            MESSAGE('Dose per fraction exceeds tolerance: ' & |
                    FORMAT(DosePerFx, @N5.2) & ' Gy', |
                    'Prescription Warning', ICON:Exclamation)
            SELECT(RXS:PrescribedDose)
          ELSE
            RXS:DosePerFraction = DosePerFx
            DISPLAY(RXS:DosePerFraction)
          END
        END
      END

    OF RXS:Fractions
      IF RXS:Fractions > 0
        IF RXS:PrescribedDose > 0
          DosePerFx = RXS:PrescribedDose / RXS:Fractions
          IF DosePerFx > MaxSingleFractionDose
            MESSAGE('Dose per fraction exceeds tolerance: ' & |
                    FORMAT(DosePerFx, @N5.2) & ' Gy', |
                    'Prescription Warning', ICON:Exclamation)
            SELECT(RXS:Fractions)
          ELSE
            RXS:DosePerFraction = DosePerFx
            DISPLAY(RXS:DosePerFraction)
          END
        END
      END

    OF RXS:Technique
      DO ValidateTechniqueForSite
      IF ValidationCode <> 0
        SELECT(RXS:Technique)
      END

    END ! CASE
  END ! ACCEPT
```

What does this *mean*? The intent is legible if you already know the domain: dose-per-fraction must not exceed a tolerance, and it should be derived automatically when both total dose and fractions are known. But that intent is buried under considerable scaffolding.

The `CASE FIELD()` pattern — Clarion's mechanism for dispatching on which field the user just left — appears *twice*, once for `RXS:PrescribedDose` and once for `RXS:Fractions`, with nearly identical bodies. The constraint `DosePerFx > MaxSingleFractionDose` is evaluated in both branches, but `MaxSingleFractionDose` is a global constant whose definition lives elsewhere. The derived field `RXS:DosePerFraction` is updated imperatively via `DISPLAY()`, a side effect that pushes a value to the window buffer. `ValidationCode` is set by `ValidateTechniqueForSite` — a procedure call whose contract is implicit.

To understand whether this code is correct, you must hold in mind: the field currently in focus, the value of `ValidationCode` from a called procedure, the definition of `MaxSingleFractionDose`, the semantics of `SELECT()` as a focus-reset operation, and the assumed pre/post conditions of `ValidateTechniqueForSite`. None of those things are *in* the fragment. They live in surrounding context, in called procedures, in global state. The fragment is not self-contained. It cannot be evaluated in isolation.

This is the procedural tax: a large fraction of the tokens in procedural code are not semantics. They are loop machinery, temporary variables, cursor management, defensive null checks, and side-effecting calls woven through the logic. The signal — *what this code means* — is diluted by the noise of *how it achieves it*.

For a human programmer maintaining old code, this is a chronic irritant. For an LLM trying to reason about behavioral equivalence across a migration, it is a fundamental obstacle.

-----

## From How to What: Procedural, Functional, and Predicate Logic

In 1979, Robert Kowalski published a paper in *Communications of the ACM* whose central thesis can be stated in four symbols: **Algorithm = Logic + Control**. Any algorithm, he argued, consists of two separable components — a logic component that specifies the knowledge used to solve the problem, and a control component that determines the search strategy used to apply that knowledge. The logic component determines the *meaning* of the algorithm. The control component affects only its *efficiency*. Crucially, the same logic can be paired with different control strategies to produce algorithms that are behaviorally equivalent but computationally distinct.

This decomposition is the formal skeleton of the paradigm spectrum. Procedural languages collapse logic and control into a single undifferentiated text. Functional languages begin to separate them, privileging compositional logic while abstracting over some control detail. Predicate logic separates them completely — the programmer writes only the logic component, and the inference engine supplies the control.

The three paradigms therefore sit on a spectrum measured by *semantic distance from the machine* — and inversely, *semantic proximity to the problem*.

**Procedural** programming sits closest to the machine. You describe execution: what to do next. Control flow is explicit, state mutation is the primary mechanism, and the logical structure of the computation is implicit in the sequencing. Easy to write; hard to reason about in the large.

**Functional** programming improves the situation considerably. Referential transparency — the guarantee that a function's output depends only on its inputs — means you can reason about functions in isolation. Equational reasoning becomes possible. You can substitute equals for equals without worrying about side effects.

But functional representations still carry computational shape. A function `validateField :: Field -> Value -> Context -> Result` presupposes a particular compositional structure. For inherently relational domains — event-driven state machines, record-based business rules, dependency graphs between fields — you end up encoding relationships *as* functions, which inverts the natural grain of the problem. The representation is cleaner than procedural, but still requires you to read the code to discover the relations it encodes.

**Predicate logic** — and Prolog in particular — sits at the far end of the spectrum. A predicate doesn't describe a computation. It describes a *truth condition*: the circumstances under which a claim holds. The computational interpretation (how to derive that truth) is handled by the inference engine, not by the programmer.

This is the key shift. Instead of describing *how* to validate a field, you describe *under what conditions* a field is valid. The difference is not stylistic. It is the difference between encoding mechanism and encoding meaning.

-----

## Prolog as Applied Razor

The same logic rendered as Prolog predicates:

```prolog
% Dose-per-fraction is derivable when both inputs are present and positive
dose_per_fraction(PrescribedDose, Fractions, DosePerFx) :-
    PrescribedDose > 0,
    Fractions > 0,
    DosePerFx is PrescribedDose / Fractions.

% A prescription is within tolerance if derived DPF does not exceed the limit
within_fraction_tolerance(PrescribedDose, Fractions) :-
    dose_per_fraction(PrescribedDose, Fractions, DosePerFx),
    max_single_fraction_dose(Limit),
    DosePerFx =< Limit.

% A prescription site is valid when dose, fractions, and technique all clear
rx_site_valid(rx_site(Dose, Fractions, Technique, SiteID)) :-
    within_fraction_tolerance(Dose, Fractions),
    technique_valid_for_site(Technique, SiteID).

% The derived DPF field value — not a side effect, a relation
rx_site_derived(rx_site(Dose, Fractions, _), dose_per_fraction, DosePerFx) :-
    dose_per_fraction(Dose, Fractions, DosePerFx).
```

Observe what has been removed:

- No `CASE FIELD()` dispatch — the predicate *is* the field specification; its name replaces the branch condition
- No duplication — the dose/fraction constraint appeared twice in Clarion (once per field entry path); here it appears once, as `within_fraction_tolerance/2`
- No `DISPLAY()` side effect — `rx_site_derived/3` is a *relation* between an rx site and a derived value, not an imperative push to a window buffer
- No `ValidationCode` global — `technique_valid_for_site/2` is a predicate that either holds or fails; failure *is* the error signal
- No sequencing — the clauses describe what must be true, not what must happen in what order

What remains is the logical skeleton: the relations, constraints, and entailment structure that define what the code *means*. The Clarion code was an *implementation* of a relational specification that was never written down. The Prolog predicates *are* that specification.

This is Occam's Razor applied to representation. Every entity that has been removed was not doing semantic work — it was implementation scaffolding that the procedural paradigm forced into existence. The predicates that remain are necessary. None can be removed without changing the meaning.

The compression is substantial. The Clarion fragment requires its surrounding context to be interpretable. The Prolog predicates are self-contained: each clause can be read, evaluated for correctness, and composed with others without reference to hidden state. The signal-to-noise ratio is dramatically higher.

-----

## Why This Matters for Reasoning Systems

Return now to the attentional window. A large language model processing a Clarion codebase faces a representation that is semantically sparse. Thousands of tokens encode relatively few behavioral constraints. The model must simultaneously track procedure call stacks, global variable lifetimes, embed point semantics, and field dependencies — most of which are implicit in the code structure rather than stated explicitly.

Ask the same model to reason over Prolog predicates extracted from that codebase, and the situation changes. The predicates are dense with semantic content. The relations are named. The conditions are explicit. Composition is transparent — a predicate's behavior is fully determined by its clauses, which are right there.

More of the system's *meaning* fits in the window. Not because the window is larger, but because the representation is more parsimonious. Occam's Razor is, among other things, an attentional optimization.

This has practical consequences for LLM-assisted legacy modernization:

- **Behavioral equivalence checking** becomes tractable when both old and new systems can be expressed as predicate theories. You are comparing logical structures, not execution traces.
- **Specification extraction** — pulling the *intent* out of procedural code — is itself easier when the target representation is predicate logic, because the extraction process is guided by a clear goal: what are the minimal sufficient conditions?
- **Incremental reasoning** is natural in Prolog. Each predicate is a unit of meaning. You can verify, extend, or replace predicates one at a time without disturbing the surrounding theory.
- **The spec becomes the code.** In a predicate representation, there is no gap between the behavioral specification and a runnable artifact. The predicates *are* executable. This eliminates an entire class of translation errors that arise when specifications and implementations diverge.

-----

## Implications for Formal Verification

The deepest implication concerns bisimulation — the formal technique for establishing behavioral equivalence between systems. Bisimulation asks: do these two systems produce indistinguishable observations under all possible interactions?

To answer that question, you need a representation of both systems that exposes their observable behavior without obscuring it in implementation detail. Procedural code fails here almost by definition — its observable behavior is entangled with its mechanism. Functional code does better, but compositional structure can still obscure the relational grain of the behavior.

Labeled transition systems — the semantic substrate for bisimulation — are inherently relational. A transition is a relation between a source state, a label, and a target state. Prolog predicates map onto this structure almost without translation:

```prolog
transition(State, Label, NextState) :-
    enabled(Label, State),
    effect(Label, State, NextState).
```

The predicate *is* the transition relation. Bisimulation checking, in this representation, reduces to asking whether two sets of predicates define the same relation. This is a natural question for a logic programming system — and a natural question for a language model reasoning over predicate theories.

The razor, applied consistently, produces representations that are not just easier to read or maintain. They are structurally aligned with the formal tools we use to verify that software does what it is supposed to do.

-----

## Conclusion

Occam's Razor is usually invoked as a tiebreaker between theories. But it is better understood as a design principle: *remove every entity that is not doing necessary work*.

Applied to program representation, this principle drives us along the paradigm spectrum — from procedural code, where implementation scaffolding crowds out semantic content, toward predicate logic, where the representation and the meaning converge.

This convergence matters for human programmers reasoning about legacy systems. It matters more for LLM-assisted reasoning, where the attentional window is finite and semantic density determines what can actually be held in mind. And it matters most for formal verification, where behavioral equivalence requires representations that expose the relational structure of computation directly.

Clarion codebases, viewed through this lens, are not just technically obsolete. They are semantically compressed in the wrong direction — they have optimized for machine execution at the cost of human and machine legibility. Extracting their operational semantics as Prolog predicates is not a translation. It is a decompression: recovering the relational truth that the procedural code was always, imperfectly, trying to express.

William of Ockham would, one suspects, have approved.

-----

## References

**Kowalski, R.A. (1979).** Algorithm = Logic + Control. *Communications of the ACM*, 22(7), 424–436. https://doi.org/10.1145/359131.359136

The foundational statement of the paradigm-spectrum argument made in this article. Kowalski observes that any algorithm consists of a logic component — specifying the knowledge to be used — and a control component — determining the search strategy. Crucially, the logic component determines the *meaning* of the algorithm while the control component affects only its efficiency. The article you are reading is, in many respects, an application of this thesis to the problem of legacy code semantics extraction: Clarion conflates logic and control; predicate extraction separates them.

**Liu, N., Lin, K., Hewitt, J., Paranjape, A., Hopkins, M., Liang, P., & Manning, C.D. (2023).** Lost in the Middle: How Language Models Use Long Contexts. *Transactions of the Association for Computational Linguistics*, 12, 157–173.

The empirical grounding for the attentional window argument. Liu et al. demonstrate that LLM performance degrades when relevant information is positioned in the middle of a long context, with a characteristic U-shaped performance curve favoring information at the start and end of the window. The implication for representation design is direct: semantic density — getting more meaning into fewer tokens — is not merely an elegance concern but a practical determinant of reasoning quality.

**Miller, G.A. (1956).** The Magical Number Seven, Plus or Minus Two: Some Limits on Our Capacity for Processing Information. *Psychological Review*, 63(2), 81–97.

The human cognition parallel to the LLM attentional window. Miller's discovery that working memory is bounded — not by raw information volume but by the number of *chunks* it can hold — is the cognitive science foundation for the claim that representation choice matters for reasoning capacity. The insight that chunking (grouping related information into meaningful units) extends effective working memory capacity maps directly onto the claim that predicate-level representations, by compressing procedural detail into named relations, reduce the number of cognitive units required to hold a system's behavior in mind.

**Milner, R. (1980).** *A Calculus of Communicating Systems*. Lecture Notes in Computer Science, vol. 92. Springer. https://doi.org/10.1007/3-540-10235-3

The origin of bisimulation as a formal equivalence for concurrent systems expressed as labeled transition systems. Milner's framework is the semantic substrate for the formal verification argument in this article: two systems are bisimilar if they are indistinguishable by any observer, where observability is defined by the labels on transitions. The relational structure of LTS — transitions as ternary relations between source state, label, and target state — maps onto Prolog predicates with near-zero overhead, which is why predicate representations are structurally aligned with bisimulation checking rather than merely convenient for it.

**Plotkin, G.D. (1981).** A Structural Approach to Operational Semantics. Technical Report DAIMI FN-19, Computer Science Department, Aarhus University.

The foundational treatment of structural operational semantics, in which the behavior of programming constructs is defined by inference rules over configurations. SOS inference rules have exactly the shape of Horn clauses: a conclusion holds if a set of premises hold. This structural correspondence between SOS specifications and Prolog predicates is not coincidental — it is why logic programming was recognized early as a natural implementation vehicle for operational semantics, and why extracting operational semantics *as* Prolog predicates produces representations that are immediately amenable to formal reasoning.
