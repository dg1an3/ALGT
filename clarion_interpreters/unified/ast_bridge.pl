%============================================================
% ast_bridge.pl - AST Translation Layer
%
% Translates ASTs from the simple parser (clarion_parser.pl)
% into the modular interpreter's format (interpreter.pl).
%
% Simple parser AST:
%   program(Files, Groups, Globals, MapEntries, Procedures)
%
% Modular interpreter AST:
%   program(map(MapDecls), GlobalDecls, code(MainBody), Procedures)
%============================================================

:- module(ast_bridge, [
    bridge_ast/2          % bridge_ast(+SimpleAST, -ModularAST)
]).

%------------------------------------------------------------
% Top-level program translation
%------------------------------------------------------------

bridge_ast(program(Files, Groups, Globals, MapEntries, Procedures),
           program(map(MapDecls), GlobalDecls, code(MainBody), ModProcs)) :-
    bridge_map_entries(MapEntries, MapDecls),
    bridge_files(Files, FileDecs),
    bridge_groups(Groups, GroupDecs),
    bridge_globals(Globals, VarDecs, Windows, MainBody0),
    append([FileDecs, GroupDecs, VarDecs, Windows], GlobalDecls),
    bridge_procedures(Procedures, MainBody0, ModProcs, MainBody).

%------------------------------------------------------------
% MAP entries
%------------------------------------------------------------

bridge_map_entries([], []).
bridge_map_entries([map_entry(Name, _, _, _)|Rest], [proc_decl(Name, procedure)|Decls]) :-
    bridge_map_entries(Rest, Decls).
bridge_map_entries([module_entry(_, Entries)|Rest], Decls) :-
    bridge_map_entries(Entries, ModDecls),
    bridge_map_entries(Rest, RestDecls),
    append(ModDecls, RestDecls, Decls).

%------------------------------------------------------------
% FILE declarations
%------------------------------------------------------------

bridge_files([], []).
bridge_files([file(Name, Prefix, Attrs, Fields)|Rest],
             [file(Name, BridgedAttrs, [record(BridgedFields)])|RestDecs]) :-
    bridge_file_attrs(Prefix, Attrs, BridgedAttrs),
    bridge_fields(Fields, BridgedFields),
    bridge_files(Rest, RestDecs).

bridge_file_attrs(Prefix, Attrs, [pre(Prefix)|BridgedAttrs]) :-
    bridge_file_attr_list(Attrs, BridgedAttrs).

bridge_file_attr_list([], []).
bridge_file_attr_list([driver(D)|Rest], [driver(D)|BRest]) :-
    bridge_file_attr_list(Rest, BRest).
bridge_file_attr_list([name(N)|Rest], [name(N)|BRest]) :-
    bridge_file_attr_list(Rest, BRest).
bridge_file_attr_list([owner(O)|Rest], [owner(O)|BRest]) :-
    bridge_file_attr_list(Rest, BRest).
bridge_file_attr_list([create|Rest], [create|BRest]) :-
    bridge_file_attr_list(Rest, BRest).
bridge_file_attr_list([key(KName, KFields, KAttrs)|Rest],
                      [key(KName, KFields, KAttrs)|BRest]) :-
    bridge_file_attr_list(Rest, BRest).
bridge_file_attr_list([_|Rest], BRest) :-
    bridge_file_attr_list(Rest, BRest).

%------------------------------------------------------------
% GROUP declarations
%------------------------------------------------------------

bridge_groups([], []).
bridge_groups([group(Name, Prefix, Fields)|Rest],
              [group(Name, Prefix, BridgedFields)|RestDecs]) :-
    bridge_fields(Fields, BridgedFields),
    bridge_groups(Rest, RestDecs).

%------------------------------------------------------------
% Field declarations (shared by FILE and GROUP)
%------------------------------------------------------------

bridge_fields([], []).
bridge_fields([field(Name, Type)|Rest], [field(Name, TypeAtom, none)|BRest]) :-
    bridge_type_name(Type, TypeAtom),
    bridge_fields(Rest, BRest).
bridge_fields([field(Name, Type, Size)|Rest], [field(Name, TypeAtom, size(Size))|BRest]) :-
    bridge_type_name(Type, TypeAtom),
    bridge_fields(Rest, BRest).

bridge_type_name(long, 'LONG').
bridge_type_name(short, 'SHORT').
bridge_type_name(byte, 'BYTE').
bridge_type_name(real, 'REAL').
bridge_type_name(sreal, 'SREAL').
bridge_type_name(date, 'DATE').
bridge_type_name(time, 'TIME').
bridge_type_name(decimal, 'DECIMAL').
bridge_type_name(decimal(_), 'DECIMAL').
bridge_type_name(decimal(_, _), 'DECIMAL').
bridge_type_name(pdecimal, 'PDECIMAL').
bridge_type_name(pdecimal(_), 'PDECIMAL').
bridge_type_name(pdecimal(_, _), 'PDECIMAL').
bridge_type_name(cstring, 'CSTRING').
bridge_type_name(cstring(N), 'CSTRING') :- number(N).
bridge_type_name(pstring, 'PSTRING').
bridge_type_name(pstring(N), 'PSTRING') :- number(N).
bridge_type_name(string, 'STRING').
bridge_type_name(string(N), 'STRING') :- number(N).
bridge_type_name(ref(T), TypeAtom) :- bridge_type_name(T, TypeAtom).
bridge_type_name(T, T).  % pass through unknown types

%------------------------------------------------------------
% Global variables and windows
%------------------------------------------------------------

bridge_globals([], [], [], []).
bridge_globals([global(Name, Type, Init)|Rest], [var(Name, TypeAtom, init(Init))|VRest], Wins, Main) :-
    bridge_type_name(Type, TypeAtom),
    bridge_globals(Rest, VRest, Wins, Main).
bridge_globals([array(Name, Type, Size)|Rest], [var(Name, TypeAtom, init(array(Zeros)))|VRest], Wins, Main) :-
    bridge_type_name(Type, TypeAtom),
    length(Zeros, Size),
    maplist(=(0), Zeros),
    bridge_globals(Rest, VRest, Wins, Main).
bridge_globals([queue(Name, Fields)|Rest], [queue(Name, BridgedFields)|VRest], Wins, Main) :-
    bridge_fields(Fields, BridgedFields),
    bridge_globals(Rest, VRest, Wins, Main).
bridge_globals([window(Name, Title, Attrs, Controls)|Rest], Vars,
               [window(Name, Title, Attrs, Controls)|WRest], Main) :-
    bridge_globals(Rest, Vars, WRest, Main).

%------------------------------------------------------------
% Procedures
%------------------------------------------------------------

bridge_procedures(Procs, _MainBody0, ModProcs, MainBody) :-
    ( select_main_proc(Procs, MainProc, OtherProcs) ->
        MainProc = procedure('_main', _, _, _, Body),
        bridge_stmts(Body, MainBody),
        bridge_proc_list(OtherProcs, ModProcs)
    ;   MainBody = [],
        bridge_proc_list(Procs, ModProcs)
    ).

select_main_proc([procedure('_main', P, R, L, B)|Rest],
                 procedure('_main', P, R, L, B), Rest).
select_main_proc([Proc|Rest], Main, [Proc|Others]) :-
    Proc \= procedure('_main', _, _, _, _),
    select_main_proc(Rest, Main, Others).

bridge_proc_list([], []).
bridge_proc_list([procedure(Name, Params, _RetType, Locals, Body)|Rest],
                 [procedure(Name, BParams, BLocals, code(BBody))|BRest]) :-
    bridge_params(Params, BParams),
    bridge_locals(Locals, BLocals),
    bridge_stmts(Body, BBody),
    bridge_proc_list(Rest, BRest).
bridge_proc_list([routine(Name, Body)|Rest],
                 [routine(Name, BBody)|BRest]) :-
    bridge_stmts(Body, BBody),
    bridge_proc_list(Rest, BRest).

bridge_params([], []).
bridge_params([param(Name, Type, optional)|Rest], [param(TypeAtom, Name, optional, none)|BRest]) :-
    bridge_type_name(Type, TypeAtom),
    bridge_params(Rest, BRest).
bridge_params([param(Name, Type)|Rest], [param(TypeAtom, Name)|BRest]) :-
    bridge_type_name(Type, TypeAtom),
    bridge_params(Rest, BRest).

bridge_locals([], []).
bridge_locals([local(Name, Type, Init)|Rest],
              [local_var(Name, TypeAtom, init(Init))|BRest]) :-
    bridge_type_name(Type, TypeAtom),
    bridge_locals(Rest, BRest).

%------------------------------------------------------------
% Statement translation
%------------------------------------------------------------

bridge_stmts([], []).
bridge_stmts([S|Ss], [BS|BSs]) :-
    bridge_stmt(S, BS),
    bridge_stmts(Ss, BSs).

% Assignment to array element: assign(array_ref(Name, Idx), Expr) -> array_assign(Name, BIdx, BExpr)
bridge_stmt(assign(array_ref(Name, Idx), Expr), array_assign(Name, BIdx, BExpr)) :- !,
    bridge_expr(Idx, BIdx),
    bridge_expr(Expr, BExpr).

% Assignment
bridge_stmt(assign(Var, Expr), assign(Var, BExpr)) :- !,
    bridge_expr(Expr, BExpr).

% Compound assignment (Var += Expr) - simple parser stores as assign(Var, add(var(Var), Expr))
% The modular interpreter has assign_add but we can keep it as assign with binop

% Procedure call
bridge_stmt(call(Name, Args), call(Name, BArgs)) :- !,
    bridge_exprs(Args, BArgs).

% Return
bridge_stmt(return(Expr), return(BExpr)) :- !,
    bridge_expr(Expr, BExpr).
bridge_stmt(return, return) :- !.

% Break, Cycle, Display, Exit
bridge_stmt(break, break) :- !.
bridge_stmt(cycle, cycle) :- !.
bridge_stmt(display, display) :- !.
bridge_stmt(exit, exit) :- !.

% IF (simple parser: 3-arg if(Cond, Then, Else))
bridge_stmt(if(Cond, Then, Else), if(BCond, BThen, [], BElse)) :- !,
    bridge_expr(Cond, BCond),
    bridge_stmts(Then, BThen),
    bridge_stmts(Else, BElse).

% LOOP (infinite)
bridge_stmt(loop(Body), loop(BBody)) :- !,
    bridge_stmts(Body, BBody).

% LOOP FOR (simple: loop_for; modular: loop_to)
bridge_stmt(loop_for(Var, Start, End, Body), loop_to(Var, BStart, BEnd, BBody)) :- !,
    bridge_expr(Start, BStart),
    bridge_expr(End, BEnd),
    bridge_stmts(Body, BBody).

% LOOP WHILE
bridge_stmt(loop_while(Cond, Body), loop_while(BCond, BBody)) :- !,
    bridge_expr(Cond, BCond),
    bridge_stmts(Body, BBody).

% LOOP UNTIL
bridge_stmt(loop_until(Cond, Body), loop_until(BCond, BBody)) :- !,
    bridge_expr(Cond, BCond),
    bridge_stmts(Body, BBody).

% CASE
bridge_stmt(case(Expr, Ofs, Else), case(BExpr, BCases, BElse)) :- !,
    bridge_expr(Expr, BExpr),
    bridge_case_ofs(Ofs, BCases),
    bridge_stmts(Else, BElse).

% ACCEPT
bridge_stmt(accept(Body), accept(BBody)) :- !,
    bridge_stmts(Body, BBody).

% DO routine
bridge_stmt(do(Name), do(Name)) :- !.

% Array assignment
bridge_stmt(assign_array(Name, Index, Expr), array_assign(Name, BIndex, BExpr)) :- !,
    bridge_expr(Index, BIndex),
    bridge_expr(Expr, BExpr).

% Catch-all: pass through
bridge_stmt(S, S) :-
    format(user_error, "Warning: ast_bridge unhandled statement: ~w~n", [S]).

%------------------------------------------------------------
% CASE branch translation
%------------------------------------------------------------

bridge_case_ofs([], []).
bridge_case_ofs([of(single(Val), Stmts)|Rest], [case_of(BVal, BStmts)|BRest]) :-
    bridge_expr(Val, BVal),
    bridge_stmts(Stmts, BStmts),
    bridge_case_ofs(Rest, BRest).
bridge_case_ofs([of(range(Start, End), Stmts)|Rest],
                [case_of(range(BStart, BEnd), BStmts)|BRest]) :-
    bridge_expr(Start, BStart),
    bridge_expr(End, BEnd),
    bridge_stmts(Stmts, BStmts),
    bridge_case_ofs(Rest, BRest).

%------------------------------------------------------------
% Expression translation
%------------------------------------------------------------

bridge_exprs([], []).
bridge_exprs([E|Es], [BE|BEs]) :-
    bridge_expr(E, BE),
    bridge_exprs(Es, BEs).

% Literals
bridge_expr(lit(N), number(N)) :- integer(N), !.
bridge_expr(lit(N), number(N)) :- float(N), !.
bridge_expr(lit(S), string(S)) :- atom(S), !.

% Variables
bridge_expr(var(Name), var(Name)) :- !.

% Equates -> control references
bridge_expr(equate(Name), control_ref(Name)) :- !.

% Arithmetic operators
bridge_expr(add(A, B), binop('+', BA, BB)) :- !, bridge_expr(A, BA), bridge_expr(B, BB).
bridge_expr(sub(A, B), binop('-', BA, BB)) :- !, bridge_expr(A, BA), bridge_expr(B, BB).
bridge_expr(mul(A, B), binop('*', BA, BB)) :- !, bridge_expr(A, BA), bridge_expr(B, BB).

% Division
bridge_expr(div(A, B), binop('/', BA, BB)) :- !, bridge_expr(A, BA), bridge_expr(B, BB).

% Modulo
bridge_expr(modulo(A, B), binop('%', BA, BB)) :- !, bridge_expr(A, BA), bridge_expr(B, BB).

% Comparison operators
bridge_expr(eq(A, B), binop('=', BA, BB)) :- !, bridge_expr(A, BA), bridge_expr(B, BB).
bridge_expr(neq(A, B), binop('<>', BA, BB)) :- !, bridge_expr(A, BA), bridge_expr(B, BB).
bridge_expr(lt(A, B), binop('<', BA, BB)) :- !, bridge_expr(A, BA), bridge_expr(B, BB).
bridge_expr(lte(A, B), binop('<=', BA, BB)) :- !, bridge_expr(A, BA), bridge_expr(B, BB).
bridge_expr(gt(A, B), binop('>', BA, BB)) :- !, bridge_expr(A, BA), bridge_expr(B, BB).
bridge_expr(gte(A, B), binop('>=', BA, BB)) :- !, bridge_expr(A, BA), bridge_expr(B, BB).

% Logical operators
bridge_expr(and(A, B), binop(and, BA, BB)) :- !, bridge_expr(A, BA), bridge_expr(B, BB).
bridge_expr(or(A, B), binop(or, BA, BB)) :- !, bridge_expr(A, BA), bridge_expr(B, BB).

% String concatenation
bridge_expr(concat(A, B), binop('&', BA, BB)) :- !, bridge_expr(A, BA), bridge_expr(B, BB).

% Function calls
bridge_expr(call(Name, Args), call(Name, BArgs)) :- !, bridge_exprs(Args, BArgs).

% Array reference
bridge_expr(array_ref(Name, Index), array_access(Name, BIndex)) :- !, bridge_expr(Index, BIndex).

% Pass through anything already in modular format or unrecognized
bridge_expr(number(N), number(N)) :- !.
bridge_expr(string(S), string(S)) :- !.
bridge_expr(binop(Op, A, B), binop(Op, A, B)) :- !.
bridge_expr(control_ref(N), control_ref(N)) :- !.

% Catch-all
bridge_expr(E, E) :-
    format(user_error, "Warning: ast_bridge unhandled expr: ~w~n", [E]).
