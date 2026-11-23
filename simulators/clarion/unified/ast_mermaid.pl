%============================================================
% ast_mermaid.pl - Mermaid Sequence Diagram from Clarion AST
%
% Generates Mermaid sequence diagram markup from a parsed
% Clarion AST (simple parser format). Shows procedure calls
% as messages between participants, with alt/loop/opt
% combined fragments for control flow.
%
% Usage:
%   :- use_module(ast_mermaid).
%   ast_to_mermaid(+SimpleAST, -MermaidString).
%   ast_to_mermaid_file(+SimpleAST, +FileName).
%
% Works with the simple parser AST from clarion_parser.pl:
%   program(Files, Groups, Globals, MapEntries, Procedures)
%============================================================

:- module(ast_mermaid, [
    ast_to_mermaid/2,           % ast_to_mermaid(+SimpleAST, -MermaidString)
    ast_to_mermaid_file/2       % ast_to_mermaid_file(+SimpleAST, +FileName)
]).

%------------------------------------------------------------
% Top-level: AST -> Mermaid string
%------------------------------------------------------------

ast_to_mermaid(program(_, _, _, _, Procedures), Mermaid) :-
    collect_participants(Procedures, Participants),
    generate_diagram(Participants, Procedures, Mermaid).

%------------------------------------------------------------
% Collect all procedure names as participants
%------------------------------------------------------------

collect_participants(Procedures, Participants) :-
    maplist(proc_name, Procedures, Names),
    sort(Names, Participants).

proc_name(procedure(Name, _, _, _, _), Name).
proc_name(routine(Name, _), Name).

%------------------------------------------------------------
% Generate the full Mermaid diagram
%------------------------------------------------------------

generate_diagram(Participants, Procedures, Mermaid) :-
    % Header
    Header = "sequenceDiagram",
    % Participant declarations
    maplist(participant_line, Participants, ParticipantLines),
    % Interaction lines from each procedure
    maplist(procedure_interactions, Procedures, InteractionLists),
    append(InteractionLists, AllInteractions),
    % Combine
    append([[Header], ParticipantLines, AllInteractions], AllLines),
    atomics_to_lines(AllLines, Mermaid).

participant_line(Name, Line) :-
    format(atom(Line), "    participant ~w", [Name]).

%------------------------------------------------------------
% Generate interactions for a single procedure
%------------------------------------------------------------

procedure_interactions(procedure(Name, _Params, _RetType, _Locals, Body), Lines) :-
    stmts_to_lines(Name, Body, Lines).
procedure_interactions(routine(Name, Body), Lines) :-
    stmts_to_lines(Name, Body, Lines).

%------------------------------------------------------------
% Statements -> Mermaid lines
%------------------------------------------------------------

stmts_to_lines(_, [], []).
stmts_to_lines(Caller, [Stmt|Rest], Lines) :-
    stmt_to_lines(Caller, Stmt, StmtLines),
    stmts_to_lines(Caller, Rest, RestLines),
    append(StmtLines, RestLines, Lines).

% Deterministic wrapper: the first matching stmt_lines/3 clause wins, so the
% catch-all at the end never yields an alternative on backtracking.
stmt_to_lines(Caller, Stmt, Lines) :-
    once(stmt_lines(Caller, Stmt, Lines)).

% Assignment target: the parser emits a bare atom ('R'); var('R') is also
% accepted for hand-built ASTs.
assign_target(var(Var), Var) :- !.
assign_target(Var, Var) :- atom(Var).

% Procedure call (statement position)
stmt_lines(Caller, call(Target, Args), Lines) :-
    format_args(Args, ArgsStr),
    format(atom(Line), "    ~w->>~w: ~w(~w)", [Caller, Target, Target, ArgsStr]),
    Lines = [Line].

% Assignment with a call on the RHS
stmt_lines(Caller, assign(Target0, call(Target, Args)), Lines) :-
    assign_target(Target0, Var),
    format_args(Args, ArgsStr),
    format(atom(CallLine), "    ~w->>~w: ~w(~w)", [Caller, Target, Target, ArgsStr]),
    format(atom(RetLine), "    ~w-->>~w: ~w", [Target, Caller, Var]),
    Lines = [CallLine, RetLine].

% Assignment with a method call on the RHS
stmt_lines(Caller, assign(Target0, method_call(Obj, Method, Args)), Lines) :-
    assign_target(Target0, Var),
    format_args(Args, ArgsStr),
    format(atom(CallLine), "    ~w->>~w: ~w(~w)", [Caller, Obj, Method, ArgsStr]),
    format(atom(RetLine), "    ~w-->>~w: ~w", [Obj, Caller, Var]),
    Lines = [CallLine, RetLine].

% Plain assignment (note on caller)
stmt_lines(Caller, assign(Target0, Expr), Lines) :-
    assign_target(Target0, Var),
    Expr \= call(_, _),
    Expr \= method_call(_, _, _),
    format_expr(Expr, ExprStr),
    format(atom(Line), "    Note right of ~w: ~w = ~w", [Caller, Var, ExprStr]),
    Lines = [Line].

% Array assignment
stmt_lines(Caller, assign(array_ref(Name, _Idx), _Expr), Lines) :-
    format(atom(Line), "    Note right of ~w: ~w[] = ...", [Caller, Name]),
    Lines = [Line].
stmt_lines(Caller, assign_array(Name, _Idx, _Expr), Lines) :-
    format(atom(Line), "    Note right of ~w: ~w[] = ...", [Caller, Name]),
    Lines = [Line].

% IF statement -> alt fragment
stmt_lines(Caller, if(Cond, Then, Else), Lines) :-
    format_expr(Cond, CondStr),
    format(atom(AltStart), "    alt ~w", [CondStr]),
    stmts_to_lines(Caller, Then, ThenLines),
    ( Else = [] ->
        append([[AltStart], ThenLines, ["    end"]], Lines)
    ;
        stmts_to_lines(Caller, Else, ElseLines),
        append([[AltStart], ThenLines, ["    else"], ElseLines, ["    end"]], Lines)
    ).

% LOOP (infinite)
stmt_lines(Caller, loop(Body), Lines) :-
    stmts_to_lines(Caller, Body, BodyLines),
    append([["    loop"], BodyLines, ["    end"]], Lines).

% LOOP FOR
stmt_lines(Caller, loop_for(Var, Start, End, Body), Lines) :-
    format_expr(Start, StartStr),
    format_expr(End, EndStr),
    format(atom(LoopHead), "    loop ~w = ~w TO ~w", [Var, StartStr, EndStr]),
    stmts_to_lines(Caller, Body, BodyLines),
    append([[LoopHead], BodyLines, ["    end"]], Lines).

% LOOP WHILE
stmt_lines(Caller, loop_while(Cond, Body), Lines) :-
    format_expr(Cond, CondStr),
    format(atom(LoopHead), "    loop WHILE ~w", [CondStr]),
    stmts_to_lines(Caller, Body, BodyLines),
    append([[LoopHead], BodyLines, ["    end"]], Lines).

% LOOP UNTIL
stmt_lines(Caller, loop_until(Cond, Body), Lines) :-
    format_expr(Cond, CondStr),
    format(atom(LoopHead), "    loop UNTIL ~w", [CondStr]),
    stmts_to_lines(Caller, Body, BodyLines),
    append([[LoopHead], BodyLines, ["    end"]], Lines).

% CASE -> alt with multiple branches
stmt_lines(Caller, case(Expr, Ofs, Else), Lines) :-
    format_expr(Expr, ExprStr),
    ofs_to_lines(Caller, ExprStr, Ofs, first, OfLines),
    ( Else = [] ->
        append([OfLines, ["    end"]], Lines)
    ;
        stmts_to_lines(Caller, Else, ElseLines),
        append([OfLines, ["    else"], ElseLines, ["    end"]], Lines)
    ).

% ACCEPT -> opt fragment
stmt_lines(Caller, accept(Body), Lines) :-
    stmts_to_lines(Caller, Body, BodyLines),
    append([["    critical ACCEPT loop"], BodyLines, ["    end"]], Lines).

% RETURN with value
stmt_lines(Caller, return(Expr), Lines) :-
    format_expr(Expr, ExprStr),
    format(atom(Line), "    Note right of ~w: RETURN ~w", [Caller, ExprStr]),
    Lines = [Line].

% RETURN bare
stmt_lines(_, return, []).

% Method call (statement)
stmt_lines(Caller, method_call(Obj, Method, Args), Lines) :-
    format_args(Args, ArgsStr),
    format(atom(Line), "    ~w->>~w: ~w(~w)", [Caller, Obj, Method, ArgsStr]),
    Lines = [Line].

% Self assign
stmt_lines(Caller, self_assign(Prop, Expr), Lines) :-
    format_expr(Expr, ExprStr),
    format(atom(Line), "    Note right of ~w: SELF.~w = ~w", [Caller, Prop, ExprStr]),
    Lines = [Line].

% Parent call
stmt_lines(Caller, parent_call(Method, Args), Lines) :-
    format_args(Args, ArgsStr),
    format(atom(Line), "    Note right of ~w: PARENT.~w(~w)", [Caller, Method, ArgsStr]),
    Lines = [Line].

% DO routine
stmt_lines(Caller, do(Name), Lines) :-
    format(atom(Line), "    ~w->>~w: DO ~w", [Caller, Name, Name]),
    Lines = [Line].

% Break, cycle, display, exit — skip (control flow noise)
stmt_lines(_, break, []).
stmt_lines(_, cycle, []).
stmt_lines(_, display, []).
stmt_lines(_, exit, []).

% Catch-all: ignore unrecognized statements
stmt_lines(_, _, []).

%------------------------------------------------------------
% CASE OF branches -> alt/else fragments
%------------------------------------------------------------

ofs_to_lines(_, _, [], _, []).
ofs_to_lines(Caller, ExprStr, [of(Range, Stmts)|Rest], first, Lines) :-
    format_range(Range, RangeStr),
    format(atom(Head), "    alt ~w = ~w", [ExprStr, RangeStr]),
    stmts_to_lines(Caller, Stmts, StmtLines),
    ofs_to_lines(Caller, ExprStr, Rest, subsequent, RestLines),
    append([[Head], StmtLines, RestLines], Lines).
ofs_to_lines(Caller, ExprStr, [of(Range, Stmts)|Rest], subsequent, Lines) :-
    format_range(Range, RangeStr),
    format(atom(Head), "    else ~w = ~w", [ExprStr, RangeStr]),
    stmts_to_lines(Caller, Stmts, StmtLines),
    ofs_to_lines(Caller, ExprStr, Rest, subsequent, RestLines),
    append([[Head], StmtLines, RestLines], Lines).

format_range(single(Val), Str) :- format_expr(Val, Str).
format_range(range(Start, End), Str) :-
    format_expr(Start, StartStr),
    format_expr(End, EndStr),
    format(atom(Str), "~w TO ~w", [StartStr, EndStr]).

%------------------------------------------------------------
% Expression formatting (human-readable)
%------------------------------------------------------------

% Deterministic wrapper: first matching fmt_expr/2 clause wins.
format_expr(E, Str) :-
    once(fmt_expr(E, Str)).

fmt_expr(lit(N), Str) :- format(atom(Str), "~w", [N]).
fmt_expr(var(Name), Str) :- format(atom(Str), "~w", [Name]).
fmt_expr(equate(Name), Str) :- format(atom(Str), "?~w", [Name]).
fmt_expr(call(Name, Args), Str) :-
    format_args(Args, ArgsStr),
    format(atom(Str), "~w(~w)", [Name, ArgsStr]).
fmt_expr(method_call(Obj, Method, Args), Str) :-
    format_args(Args, ArgsStr),
    format(atom(Str), "~w.~w(~w)", [Obj, Method, ArgsStr]).
fmt_expr(self_access(Prop), Str) :-
    format(atom(Str), "SELF.~w", [Prop]).
fmt_expr(add(A, B), Str) :- format_binop('+', A, B, Str).
fmt_expr(sub(A, B), Str) :- format_binop('-', A, B, Str).
fmt_expr(mul(A, B), Str) :- format_binop('*', A, B, Str).
fmt_expr(div(A, B), Str) :- format_binop('/', A, B, Str).
fmt_expr(modulo(A, B), Str) :- format_binop('%', A, B, Str).
fmt_expr(eq(A, B), Str) :- format_binop('=', A, B, Str).
fmt_expr(neq(A, B), Str) :- format_binop('<>', A, B, Str).
fmt_expr(lt(A, B), Str) :- format_binop('<', A, B, Str).
fmt_expr(lte(A, B), Str) :- format_binop('<=', A, B, Str).
fmt_expr(gt(A, B), Str) :- format_binop('>', A, B, Str).
fmt_expr(gte(A, B), Str) :- format_binop('>=', A, B, Str).
fmt_expr(and(A, B), Str) :- format_binop('AND', A, B, Str).
fmt_expr(or(A, B), Str) :- format_binop('OR', A, B, Str).
fmt_expr(concat(A, B), Str) :- format_binop('&', A, B, Str).
fmt_expr(not(E), Str) :-
    format_expr(E, EStr),
    format(atom(Str), "NOT ~w", [EStr]).
fmt_expr(array_ref(Name, Idx), Str) :-
    format_expr(Idx, IdxStr),
    format(atom(Str), "~w[~w]", [Name, IdxStr]).
% Catch-all
fmt_expr(E, Str) :- format(atom(Str), "~w", [E]).

format_binop(Op, A, B, Str) :-
    format_expr(A, AStr),
    format_expr(B, BStr),
    format(atom(Str), "~w ~w ~w", [AStr, Op, BStr]).

%------------------------------------------------------------
% Argument list formatting
%------------------------------------------------------------

format_args([], "").
format_args(Args, Str) :-
    Args \= [],
    maplist(format_expr, Args, ArgStrs),
    atomic_list_concat(ArgStrs, ', ', Str).

%------------------------------------------------------------
% Join lines with newlines
%------------------------------------------------------------

atomics_to_lines(Lines, Result) :-
    atomic_list_concat(Lines, '\n', Result).

%------------------------------------------------------------
% Write diagram to file
%------------------------------------------------------------

ast_to_mermaid_file(AST, FileName) :-
    ast_to_mermaid(AST, Mermaid),
    open(FileName, write, Out),
    write(Out, Mermaid),
    nl(Out),
    close(Out).
