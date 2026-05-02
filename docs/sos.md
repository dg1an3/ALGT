# Structural Operational Semantics of the Clarion Simulator

This document gives a Plotkin-style SOS description of the unified Clarion simulator
in [../simulators/clarion/unified/](../simulators/clarion/unified/). The goal is not to
*specify* a semantics that the simulator must conform to — the simulator is the
specification — but to make the rule structure already implicit in the Prolog code
explicit, and to call out the places where the implementation departs from a clean
declarative reading.

The simulator is written in SWI-Prolog. SOS inference rules and Horn clauses share
the same shape (head ⇐ premises), so each `exec_statement/4` clause is essentially
an SOS rule with the turnstile rotated. The value of writing the rules out
separately is that it surfaces the operational concessions — cuts, clause ordering,
meta-level state operations — that the executable form has to make.

---

## 1. Configurations

### State

A simulator state σ is a 9-tuple (see [simulator_state.pl:77](../simulators/clarion/unified/simulator_state.pl#L77)):

```
σ = ⟨V, P, O, F, ε, C, self, U, k⟩
```

| Component | Domain | Role |
|---|---|---|
| V | Var ⇀ Val | variable bindings |
| P | list of Procedure | procedure definitions (fixed after init) |
| O | list of String | accumulated output |
| F | list of FileState | file/queue contents and buffers |
| ε | ℤ | last error code |
| C | list of ClassDef | class definitions |
| self | none ∣ self_context(obj, cls, parent) | active method receiver |
| U | UIState | window stack, event queue, mode |
| k | none ∣ Continuation | for pausable ACCEPT |

### Control flag

```
κ ::= normal ∣ break ∣ cycle ∣ return ∣ return(v) ∣ exit
```

The control flag is threaded as the fourth argument to `exec_statement/4`. In a
textbook SOS this would appear as separate rule schemas per construct
(`⟨break; S⃗, σ⟩ ⇓ ⟨σ, break⟩`, etc.); the simulator uses a single judgment with κ
as data. The two formulations are equivalent.

### Values

```
v ::= n ∈ ℤ ∣ r ∈ ℝ ∣ s ∈ String
   ∣ array(vs)
   ∣ group_val(prefix, fields, vs)
   ∣ instance(class, props)
   ∣ picture(p)
```

### UI events

```
ev ::= set(x, v)              -- field entry, updates state without running body
     ∣ choice(name, i)         -- list-control selection
     ∣ accepted(name)          -- button-style commit, sets __EVENT__ = 1
     ∣ selected(name)          -- focus event, __EVENT__ = 2
     ∣ new_selection(name)     -- list re-selection, __EVENT__ = 17
     ∣ n ∈ ℤ                   -- legacy bare integer = button equate
```

---

## 2. Judgments

| Judgment | Form | Meaning | Source |
|---|---|---|---|
| Expression eval (pure) | ⟨e, σ⟩ ⇓ v | side-effect-free | [simulator_eval.pl](../simulators/clarion/unified/simulator_eval.pl) |
| Expression eval (effectful) | ⟨e, σ⟩ ⇓ ⟨v, σ'⟩ | binop subexprs may contain calls | [simulator.pl:438](../simulators/clarion/unified/simulator.pl#L438) |
| Statement exec | ⟨S, σ⟩ ⇓ ⟨σ', κ⟩ | natural / big-step | [simulator.pl:219](../simulators/clarion/unified/simulator.pl#L219) |
| ACCEPT step | ⟨body, σ⟩ →ₐ ⟨body, σ'⟩ | small-step over event queue | [simulator.pl:590](../simulators/clarion/unified/simulator.pl#L590) |

The `⇓` for statements is natural-style (no intermediate configurations); the only
small-step layer in the simulator is the ACCEPT loop, because it consumes UI events
one at a time from a queue that lives inside σ.U.

---

## 3. Expression rules

### Pure subset

```
─────────────────────────  E-Num         ─────────────────────────  E-Var
⟨number(n), σ⟩ ⇓ n                       ⟨var(x), σ⟩ ⇓ σ.V(x)


⟨e₁, σ⟩ ⇓ v₁    ⟨e₂, σ⟩ ⇓ v₂    v₁,v₂ ∈ ℤ
─────────────────────────────────────────────────  E-Div-Int
⟨binop('/', e₁, e₂), σ⟩ ⇓ v₁ // v₂


⟨e, σ⟩ ⇓ v    truthy(v)
──────────────────────────  E-Not-False
⟨not(e), σ⟩ ⇓ 0
```

E-Div-Int is Clarion-specific: `LONG / LONG` produces an integer result. See
[simulator_eval.pl:98-103](../simulators/clarion/unified/simulator_eval.pl#L98-L103).
truthy: nonzero number, nonempty string/atom (`is_truthy/1`,
[simulator_eval.pl:133](../simulators/clarion/unified/simulator_eval.pl#L133)).

### Effectful subset

When a binop's operand contains a procedure call, evaluation thread σ:

```
⟨e₁, σ⟩ ⇓ ⟨v₁, σ₁⟩    ⟨e₂, σ₁⟩ ⇓ ⟨v₂, σ₂⟩    eval_binop(op, v₁, v₂) = v
─────────────────────────────────────────────────────────────────────────  E-Binop-Effectful
⟨binop(op, e₁, e₂), σ⟩ ⇓ ⟨v, σ₂⟩
```

This is precisely why `eval_full_expr` exists alongside `eval_expr` — see
[simulator.pl:438-462](../simulators/clarion/unified/simulator.pl#L438-L462) and Fix
#2 in [../simulators/clarion/unified/CLAUDE.md](../simulators/clarion/unified/CLAUDE.md).

---

## 4. Statement rules

### Sequencing

```
⟨S, σ⟩ ⇓ ⟨σ', normal⟩    ⟨S⃗, σ'⟩ ⇓ ⟨σ'', κ⟩
─────────────────────────────────────────────  Seq-Continue
⟨S; S⃗, σ⟩ ⇓ ⟨σ'', κ⟩


⟨S, σ⟩ ⇓ ⟨σ', κ⟩    κ ≠ normal
─────────────────────────────────  Seq-Abort
⟨S; S⃗, σ⟩ ⇓ ⟨σ', κ⟩
```

Direct counterpart of the two clauses at
[simulator.pl:219-225](../simulators/clarion/unified/simulator.pl#L219-L225).

### Assignment

```
⟨e, σ⟩ ⇓ v
─────────────────────────────────────────  Assign
⟨assign(x, e), σ⟩ ⇓ ⟨σ[x ↦ v], normal⟩
```

The substitution `σ[x ↦ v]` is *not* a simple variable update: it dispatches on the
form of `x` (prefix:field → file buffer; prefix.field → group/instance; plain →
variable map). See `set_var/4` and the prefix-resolution chain at
[simulator_state.pl:139-206](../simulators/clarion/unified/simulator_state.pl#L139-L206).

### Conditional

```
⟨c, σ⟩ ⇓ v    truthy(v)    ⟨S⃗ₜ, σ⟩ ⇓ ⟨σ', κ⟩
─────────────────────────────────────────────  If-Then
⟨if(c, S⃗ₜ, E⃗, S⃗ₑ), σ⟩ ⇓ ⟨σ', κ⟩


⟨c, σ⟩ ⇓ v    ¬truthy(v)    ⟨elsif(E⃗, S⃗ₑ), σ⟩ ⇓ ⟨σ', κ⟩
──────────────────────────────────────────────────────────  If-Else
⟨if(c, S⃗ₜ, E⃗, S⃗ₑ), σ⟩ ⇓ ⟨σ', κ⟩
```

with `elsif` recursing through the ELSIF chain — see
[simulator.pl:468-475](../simulators/clarion/unified/simulator.pl#L468-L475).

### Loops

The four loop forms (`loop`, `loop_to`, `loop_while`, `loop_until`) share a control
discipline: `break` becomes `normal` at the loop boundary, `cycle` re-enters the
loop, `return`/`return(v)` propagates outward.

```
⟨B⃗, σ⟩ ⇓ ⟨σ', break⟩
──────────────────────────────────  Loop-Break
⟨loop(B⃗), σ⟩ ⇓ ⟨σ', normal⟩


⟨B⃗, σ⟩ ⇓ ⟨σ', return(v)⟩
─────────────────────────────────────  Loop-Return-Value
⟨loop(B⃗), σ⟩ ⇓ ⟨σ', return(v)⟩


⟨B⃗, σ⟩ ⇓ ⟨σ', κ⟩    κ ∈ {normal, cycle}    ⟨loop(B⃗), σ'⟩ ⇓ ⟨σ'', κ'⟩
──────────────────────────────────────────────────────────────────────  Loop-Iter
⟨loop(B⃗), σ⟩ ⇓ ⟨σ'', κ'⟩
```

`loop_to` adds a guard ⟨e_from, σ⟩ ⇓ from, ⟨e_to, σ⟩ ⇓ to and bumps the loop
variable between iterations; `loop_while` evaluates the condition before each
iteration; `loop_until` evaluates after. See
[simulator.pl:481-525](../simulators/clarion/unified/simulator.pl#L481-L525).

### CASE with range

```
⟨e, σ⟩ ⇓ v    ⟨e_lo, σ⟩ ⇓ lo    ⟨e_hi, σ⟩ ⇓ hi    lo ≤ v ≤ hi    ⟨S⃗, σ⟩ ⇓ ⟨σ', κ⟩
─────────────────────────────────────────────────────────────────────────────────────  Case-Range-Hit
⟨case(e, [case_of(range(e_lo, e_hi), S⃗) | rest], else), σ⟩ ⇓ ⟨σ', κ⟩
```

The non-range form requires `v = MatchVal` after evaluating each case label. See
[simulator.pl:541-569](../simulators/clarion/unified/simulator.pl#L541-L569).

### Procedure call

This is the rule that requires the most care because the implementation has a
non-trivial scoping discipline.

```
⟨args⃗, σ⟩ ⇓ vs⃗
σ₁ = bind_params(params, vs⃗, σ)
σ₂ = init_locals(locals, σ₁)
⟨body, σ₂⟩ ⇓ ⟨σ₃, κ⟩
result = (κ = return(v) ? v : none)
σ_out = ⟨merge_globals(σ.V, σ₃.V, paramNames, localNames),
        σ.P, σ₃.O, σ₃.F, σ₃.ε, σ₃.C, none, σ.U, σ.k⟩
─────────────────────────────────────────────────────────────────────  Call
⟨call(f, args⃗), σ⟩ ⇓ ⟨σ_out, normal⟩  ⟹  result
```

The subtle piece is `merge_globals`: parameters and locals are *dropped* from the
final variable map, but writes to pre-existing outer variables *survive* (so a
callee's `NextID += 1` persists in the caller). Output, files, errcode, and
classes propagate through unconditionally. See
[simulator.pl:689-694, 752-757](../simulators/clarion/unified/simulator.pl#L689-L694)
and Fix #5 in
[../simulators/clarion/unified/CLAUDE.md](../simulators/clarion/unified/CLAUDE.md).

`DO routine` follows the same shape but rewrites `exit` to `normal` at the routine
boundary ([simulator.pl:578](../simulators/clarion/unified/simulator.pl#L578)).

---

## 5. ACCEPT — the small-step layer

ACCEPT consumes events from σ.U.queue one at a time. Different event kinds have
different effects; we give the most representative three.

### Field entry — body is *not* executed

```
σ.U.queue = set(x, v) :: q'    σ' = σ[x ↦ v, U.queue ↦ q']
─────────────────────────────────────────────────────────────  Accept-Field
⟨accept(body), σ⟩ →ₐ ⟨accept(body), σ'⟩
```

### Button press / accepted event — body runs with `__EVENT__ = 1`

```
σ.U.queue = accepted(n) :: q'
σ' = σ[U.queue ↦ q', __ACCEPTED__ ↦ σ.V(equate(n)), __EVENT__ ↦ 1]
⟨body, σ'⟩ ⇓ ⟨σ'', κ⟩    κ ∉ {break, return(_)}
─────────────────────────────────────────────────────────────────────  Accept-Accepted
⟨accept(body), σ⟩ →ₐ ⟨accept(body), σ''⟩
```

`break` exits the ACCEPT (κ becomes `normal`); `return(v)` propagates through.
See [simulator.pl:604-615](../simulators/clarion/unified/simulator.pl#L604-L615).

### Empty queue — termination

```
σ.U.queue = []
─────────────────────────────────────────  Accept-Done
⟨accept(body), σ⟩ ⇓ ⟨σ, normal⟩
```

The selected/new_selection cases differ only in the `__EVENT__` value (2 / 17
respectively). See [simulator.pl:616-639](../simulators/clarion/unified/simulator.pl#L616-L639).

---

## 6. SOS rules ↔ Horn clauses

Each rule above corresponds directly to one Prolog clause. As a worked example,
Loop-Iter:

```
⟨B⃗, σ⟩ ⇓ ⟨σ', κ⟩    κ ∈ {normal, cycle}    ⟨loop(B⃗), σ'⟩ ⇓ ⟨σ'', κ'⟩
──────────────────────────────────────────────────────────────────────
⟨loop(B⃗), σ⟩ ⇓ ⟨σ'', κ'⟩
```

…is, modulo the if-then-else that combines all four loop-control cases into one
clause:

```prolog
exec_loop_infinite(Body, StateIn, StateOut, Control) :-
    exec_statements(Body, StateIn, State1, BodyControl),
    ( BodyControl = break    -> StateOut = State1, Control = normal
    ; BodyControl = return   -> StateOut = State1, Control = return
    ; BodyControl = return(V) -> StateOut = State1, Control = return(V)
    ; exec_loop_infinite(Body, State1, StateOut, Control)
    ).
```

([simulator.pl:481-487](../simulators/clarion/unified/simulator.pl#L481-L487))

The conclusion of the rule is the head; the premises are the body. The tail call
`exec_loop_infinite(Body, State1, ...)` is the recursive premise of Loop-Iter.

---

## 7. Where the implementation departs from declarative SOS

A faithful SOS reading of the Prolog requires acknowledging four operational
concessions:

**Cuts (`!`) in `exec_statement` clauses.** The clause heads are not mutually
exclusive on their first argument alone (e.g. `if/3` legacy form vs `if/4` four-arg
form both unify against `if(_,_,_)` goals). Cuts commit to the first matching
clause. In SOS terms this means rules are tried in textual order with later rules
silently overridden — not the "any rule whose conclusion matches may fire"
non-determinism a declarative reading would expect.

**Clause ordering matters.** Same point from the other direction. Reordering
`exec_statement` clauses is not safe: the four-argument `if/4` clause must precede
the legacy three-argument `if/3` clause for SLD resolution to do the right thing.

**`merge_globals` is meta-level.** The Call rule uses substitution
`σ.V[outer-vars-overwritten-by-callee]`, which the implementation realizes as a
list traversal over both var lists ([simulator.pl:752-757](../simulators/clarion/unified/simulator.pl#L752-L757)).
This is a Horn clause, but it is not naturally rule-shaped — it operates on σ as
data rather than treating σ as the conclusion's environment.

**ACCEPT's small-step structure is implicit.** The ACCEPT rules above use →ₐ to
emphasize the small-step nature, but the implementation expresses this as
tail-recursive self-call to `exec_accept_loop/5`. The "transition relation" is
inlined into the Prolog control flow rather than being a visible relation.

These are not bugs; they are the price of having an executable specification.
Calling them out here is the point of writing the SOS separately from the code.

---

## 8. Extensions not covered

Three pieces of the simulator are deliberately omitted from the rules above:

1. **Storage and UI dispatch.** File operations resolve through Logtalk protocol
   dispatch ([storage_dispatcher.lgt](../simulators/clarion/unified/storage_dispatcher.lgt),
   [ui_dispatcher.lgt](../simulators/clarion/unified/ui_dispatcher.lgt)). A
   layered semantics would have one rule firing the dispatcher and dispatcher
   rules firing the backend. The shape is the same; the rules just multiply.

2. **The execution tracer.** Tracing
   ([execution_tracer.pl](../simulators/clarion/unified/execution_tracer.pl)) is an
   *observational* semantics over the same transitions — easily modeled as a
   labeled transition system ⟨S, σ⟩ ─ℓ→ ⟨σ', κ⟩ where ℓ is the trace event. The
   underlying ⇓ is unchanged; ℓ is emitted as a side-channel.

3. **External MODULE stubs.** External-procedure calls ([simulator.pl:710-748](../simulators/clarion/unified/simulator.pl#L710-L748))
   return type-defaulted values without executing a body, with `MemCopy` as a
   no-op special case. From an SOS standpoint these are uninterpreted constants.

The bisimulation work in [../simulators/clarion/unified/bisimulation.pl](../simulators/clarion/unified/bisimulation.pl)
relies on (2): bisimilarity is defined over the labels emitted by the tracer, which
is why the tracer being observational rather than constitutive matters.
