%============================================================
% ast_bridge.pl - AST Translation Layer
%
% Translates ASTs from the simple parser (clarion_parser.pl)
% into the modular simulator's format (simulator.pl).
%
% Simple parser AST:
%   program(Files, Groups, Globals, MapEntries, Procedures)
%
% Modular simulator AST:
%   program(map(MapDecls), GlobalDecls, code(MainBody), Procedures)
%============================================================

:- module(ast_bridge, [
    bridge_ast/2          % bridge_ast(+SimpleAST, -ModularAST)
]).

:- use_module(clarion_types, []).

%------------------------------------------------------------
% Top-level program translation
%------------------------------------------------------------

bridge_ast(program(Files, Groups, Globals, MapEntries, Procedures),
           program(map(MapDecls), GlobalDecls, code(MainBody), ModProcs)) :-
    bridge_map_entries(MapEntries, MapDecls),
    bridge_files(Files, FileDecs, NestedGroups),
    bridge_groups(Groups, GroupDecs),
    bridge_groups(NestedGroups, NestedGroupDecs),
    bridge_globals(Globals, VarDecs, Windows, MainBody0),
    append([FileDecs, GroupDecs, NestedGroupDecs, VarDecs, Windows], GlobalDecls),
    bridge_procedures(Procedures, MainBody0, ModProcs, MainBody).

%------------------------------------------------------------
% MAP entries
%------------------------------------------------------------

bridge_map_entries([], []).
bridge_map_entries([map_entry(Name, Params, RetType, Attrs)|Rest],
                   [map_proto(Name, BParams, RetTypeAtom, BAttrs)|Decls]) :-
    bridge_map_params(Params, BParams),
    bridge_return_type(RetType, RetTypeAtom),
    bridge_map_attrs(Attrs, BAttrs),
    bridge_map_entries(Rest, Decls).
bridge_map_entries([module_entry(ModName, Entries)|Rest], Decls) :-
    bridge_module_entries(ModName, Entries, ModDecls),
    bridge_map_entries(Rest, RestDecls),
    append(ModDecls, RestDecls, Decls).

% MODULE entries become external_proc declarations
bridge_module_entries(_, [], []).
bridge_module_entries(ModName, [map_entry(Name, Params, RetType, Attrs)|Rest],
                      [external_proc(Name, ModName, BParams, RetTypeAtom, BAttrs)|Decls]) :-
    bridge_map_params(Params, BParams),
    bridge_return_type(RetType, RetTypeAtom),
    bridge_map_attrs(Attrs, BAttrs),
    bridge_module_entries(ModName, Rest, Decls).
bridge_module_entries(ModName, [_|Rest], Decls) :-
    bridge_module_entries(ModName, Rest, Decls).

% MAP parameter bridging (preserves type info for arity checking)
bridge_map_params([], []).
bridge_map_params([param(Name, Type)|Rest], [map_param(TypeAtom, Name)|BRest]) :-
    bridge_type_name(Type, TypeAtom),
    bridge_map_params(Rest, BRest).
bridge_map_params([param(Name, Type, optional)|Rest],
                  [map_param(TypeAtom, Name, optional)|BRest]) :-
    bridge_type_name(Type, TypeAtom),
    bridge_map_params(Rest, BRest).

% Return type bridging
bridge_return_type(void, void).
bridge_return_type(Type, TypeAtom) :- bridge_type_name(Type, TypeAtom).

% MAP attribute bridging (preserves NAME alias, EXPORT, C, etc.)
bridge_map_attrs([], []).
bridge_map_attrs([name(N)|Rest], [name(N)|BRest]) :- bridge_map_attrs(Rest, BRest).
bridge_map_attrs([export|Rest], [export|BRest]) :- bridge_map_attrs(Rest, BRest).
bridge_map_attrs([c|Rest], [c|BRest]) :- bridge_map_attrs(Rest, BRest).
bridge_map_attrs([pascal|Rest], [pascal|BRest]) :- bridge_map_attrs(Rest, BRest).
bridge_map_attrs([private|Rest], [private|BRest]) :- bridge_map_attrs(Rest, BRest).
bridge_map_attrs([raw|Rest], [raw|BRest]) :- bridge_map_attrs(Rest, BRest).
bridge_map_attrs([virtual|Rest], [virtual|BRest]) :- bridge_map_attrs(Rest, BRest).
bridge_map_attrs([_|Rest], BRest) :- bridge_map_attrs(Rest, BRest).

%------------------------------------------------------------
% FILE declarations
%------------------------------------------------------------

bridge_files([], [], []).
bridge_files([file(Name, Prefix, Attrs, Fields)|Rest],
             [file(Name, BridgedAttrs, Contents)|RestDecs],
             AllNestedGroups) :-
    bridge_file_attrs(Prefix, Attrs, BridgedAttrs),
    findall(key(K, KF, KA), member(key(K, KF, KA), Attrs), Keys),
    append(Keys, [record(BridgedFields)], Contents),
    bridge_fields(Fields, BridgedFields),
    extract_nested_groups(Fields, NestedGroups),
    bridge_files(Rest, RestDecs, RestNestedGroups),
    append(NestedGroups, RestNestedGroups, AllNestedGroups).

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
bridge_file_attr_list([_|Rest], BRest) :-
    bridge_file_attr_list(Rest, BRest).

%------------------------------------------------------------
% GROUP declarations
%------------------------------------------------------------

bridge_groups([], []).
bridge_groups([group(Name, Prefix, Fields)|Rest],
              AllDecs) :-
    bridge_fields(Fields, BridgedFields),
    extract_nested_groups(Fields, NestedGroups),
    bridge_groups(NestedGroups, NestedDecs),
    bridge_groups(Rest, RestDecs),
    append([group(Name, Prefix, BridgedFields)], NestedDecs, ThisDecs),
    append(ThisDecs, RestDecs, AllDecs).

%------------------------------------------------------------
% Field declarations (shared by FILE and GROUP)
%------------------------------------------------------------

bridge_fields([], []).
bridge_fields([field(Name, Type)|Rest], [field(Name, TypeAtom, Size)|BRest]) :-
    bridge_type_name(Type, TypeAtom),
    type_size(Type, Size),
    bridge_fields(Rest, BRest).
bridge_fields([field(Name, Type, Size)|Rest], [field(Name, TypeAtom, size(Size))|BRest]) :-
    bridge_type_name(Type, TypeAtom),
    bridge_fields(Rest, BRest).
% Nested GROUP inside RECORD/GROUP: flatten sub-fields into the parent field list
bridge_fields([group(_Name, _Prefix, SubFields)|Rest], Result) :-
    bridge_fields(SubFields, BridgedSub),
    bridge_fields(Rest, BRest),
    append(BridgedSub, BRest, Result).

% Extract nested group declarations from a field list (for prefix registration)
extract_nested_groups([], []).
extract_nested_groups([group(Name, Prefix, SubFields)|Rest], [group(Name, Prefix, SubFields)|AllGroups]) :-
    extract_nested_groups(SubFields, SubGroups),
    extract_nested_groups(Rest, RestGroups),
    append(SubGroups, RestGroups, AllGroups).
extract_nested_groups([_|Rest], Groups) :-
    extract_nested_groups(Rest, Groups).

% Declared length of a type (used to pad, truncate and size values)
type_size(string(N), size(N)) :- number(N), !.
type_size(cstring(N), size(N)) :- number(N), !.
type_size(pstring(N), size(N)) :- number(N), !.
type_size(decimal(N), size(N)) :- number(N), !.
type_size(decimal(N, _), size(N)) :- number(N), !.
type_size(pdecimal(N), size(N)) :- number(N), !.
type_size(pdecimal(N, _), size(N)) :- number(N), !.
type_size(_, none).

% Type with its length, for variables and parameters
sized_type(ref(file), file_ref) :- !.            % *FILE parameter
sized_type(ref(T), ref(Sized)) :- !, sized_type(T, Sized).
sized_type(Type, Sized) :-
    bridge_type_name(Type, TypeAtom),
    type_size(Type, Size),
    ( Size == none -> Sized = TypeAtom ; Sized = typed(TypeAtom, Size) ).

% The parser gives 0 as the initial value of an uninitialised string
initial_value(Type, 0, "") :- is_text_type(Type), !.
initial_value(_, Init, Init).

initial_array(Type, Size, array(Values)) :-
    length(Values, Size),
    sized_type(Type, Sized),
    clarion_types:split_type(Sized, T, S),
    ( is_text_type(Type) -> clarion_types:type_default(T, S, V) ; V = 0 ),
    maplist(=(V), Values).

is_text_type(string).
is_text_type(string(_)).
is_text_type(cstring).
is_text_type(cstring(_)).
is_text_type(pstring).
is_text_type(pstring(_)).

bridge_type_name(long, 'LONG').
bridge_type_name(ulong, 'ULONG').
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
bridge_type_name(ref(T), TypeAtom) :- !, bridge_type_name(T, TypeAtom).
bridge_type_name(key, 'KEY') :- !.
bridge_type_name(group, 'GROUP') :- !.
bridge_type_name(queue, 'QUEUE') :- !.
bridge_type_name(any, 'ANY') :- !.
bridge_type_name(like(Ref, _Attrs), like(Ref)) :- !.  % LIKE(Ref): type resolved at runtime (default 0)
bridge_type_name(T, T).  % pass through unknown types

%------------------------------------------------------------
% Global variables and windows
%------------------------------------------------------------

bridge_globals([], [], [], []).
bridge_globals([global(Name, Type, Init0)|Rest], [var(Name, TypeAtom, init(Init))|VRest], Wins, Main) :-
    sized_type(Type, TypeAtom),
    initial_value(Type, Init0, Init),
    bridge_globals(Rest, VRest, Wins, Main).
bridge_globals([array(Name, Type, Size)|Rest], [var(Name, TypeAtom, init(Values))|VRest], Wins, Main) :-
    sized_type(Type, TypeAtom),
    initial_array(Type, Size, Values),
    bridge_globals(Rest, VRest, Wins, Main).
bridge_globals([queue(Name, Fields)|Rest], [queue(Name, BridgedFields)|VRest], Wins, Main) :-
    bridge_fields(Fields, BridgedFields),
    bridge_globals(Rest, VRest, Wins, Main).
bridge_globals([queue(Name, Prefix, Fields)|Rest], [queue(Name, Prefix, BridgedFields)|VRest], Wins, Main) :-
    bridge_fields(Fields, BridgedFields),
    bridge_globals(Rest, VRest, Wins, Main).
bridge_globals([window(Name, Title, Attrs, Controls)|Rest], Vars,
               [window(Name, Title, Attrs, Controls)|WRest], Main) :-
    bridge_globals(Rest, Vars, WRest, Main).
bridge_globals([equate(Name, Value)|Rest], [var(Name, Type, init(Value))|VRest], Wins, Main) :-
    ( atom(Value) -> Type = 'STRING' ; Type = 'LONG' ),   % EQUATE('text') vs EQUATE(n)
    bridge_globals(Rest, VRest, Wins, Main).
bridge_globals([global_instance(Name, ClassName)|Rest], [instance_global(Name, ClassName)|VRest], Wins, Main) :-
    bridge_globals(Rest, VRest, Wins, Main).
bridge_globals([class(Name, Parent, _Attrs, Members)|Rest],
               [class(Name, Parent, [], BridgedMembers)|VRest], Wins, Main) :-
    bridge_class_members(Members, BridgedMembers),
    bridge_globals(Rest, VRest, Wins, Main).

%------------------------------------------------------------
% CLASS member translation
%------------------------------------------------------------

bridge_class_members([], []).
bridge_class_members([property(Name, Type, Size)|Rest], [property(Name, TypeAtom, Size)|BRest]) :-
    bridge_type_name(Type, TypeAtom),
    bridge_class_members(Rest, BRest).
bridge_class_members([method(Name, Params, _RetType, _Attrs)|Rest],
                     [method(Name, BParams)|BRest]) :-
    bridge_params(Params, BParams),
    bridge_class_members(Rest, BRest).

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

% Split 'ClassName.MethodName' atom into two atoms
split_dotted_name(DottedName, ClassName, MethodName) :-
    atom(DottedName),
    atom_string(DottedName, Str),
    sub_string(Str, Before, 1, After, "."),
    Before > 0, After > 0,
    sub_string(Str, 0, Before, _, ClassStr),
    Pos is Before + 1,
    sub_string(Str, Pos, After, 0, MethodStr),
    atom_string(ClassName, ClassStr),
    atom_string(MethodName, MethodStr).

bridge_proc_list([], []).
% Method definition: ClassName.MethodName PROCEDURE(...)
bridge_proc_list([procedure(DottedName, Params, _RetType, Locals, Body)|Rest],
                 [method_impl(ClassName, MethodName, BParams, BLocals, code(BBody))|BRest]) :-
    split_dotted_name(DottedName, ClassName, MethodName), !,
    bridge_params(Params, BParams),
    bridge_locals(Locals, BLocals),
    bridge_stmts(Body, BBody),
    bridge_proc_list(Rest, BRest).
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
    sized_type(Type, TypeAtom),
    bridge_params(Rest, BRest).
bridge_params([param(Name, Type)|Rest], [param(TypeAtom, Name)|BRest]) :-
    sized_type(Type, TypeAtom),
    bridge_params(Rest, BRest).

bridge_locals([], []).
bridge_locals([instance_var(Name, ClassName)|Rest],
              [local_var(Name, custom(ClassName), init(none))|BRest]) :-
    bridge_locals(Rest, BRest).
bridge_locals([array(Name, Type, Size)|Rest],
              [local_var(Name, TypeAtom, init(Values))|BRest]) :-
    sized_type(Type, TypeAtom),
    initial_array(Type, Size, Values),
    bridge_locals(Rest, BRest).
% LIKE(Ref) local: the referenced declaration is not resolved here, so the
% variable starts at the simulator's default value (0).
bridge_locals([like(Name, Ref, _Attrs)|Rest],
              [local_var(Name, like(Ref), init(none))|BRest]) :-
    bridge_locals(Rest, BRest).
% Local QUEUE / GROUP: wrapped as local_decl/1 so the simulator initialises
% them exactly like the matching global declarations. Nested GROUPs inside a
% local GROUP are emitted as separate local_decls (for prefix registration).
bridge_locals([queue(Name, Fields)|Rest], [local_decl(queue(Name, BFields))|BRest]) :- !,
    bridge_fields(Fields, BFields),
    bridge_locals(Rest, BRest).
bridge_locals([queue(Name, Prefix, Fields)|Rest], [local_decl(queue(Name, Prefix, BFields))|BRest]) :- !,
    bridge_fields(Fields, BFields),
    bridge_locals(Rest, BRest).
bridge_locals([group(Name, Prefix0, Fields)|Rest], Decls) :- !,
    ( Prefix0 == none -> Prefix = '' ; Prefix = Prefix0 ),
    bridge_groups([group(Name, Prefix, Fields)], GroupDecs),
    findall(local_decl(G), member(G, GroupDecs), GDecls),
    bridge_locals(Rest, BRest),
    append(GDecls, BRest, Decls).
% Local reference (Name &Type): starts as NULL until assigned with &=
bridge_locals([ref_var(Name, Type)|Rest],
              [local_var(Name, reference(Type), init(null))|BRest]) :- !,
    bridge_locals(Rest, BRest).
% Local WINDOW (title only; body skipped by the parser): nothing to initialise
bridge_locals([window(_, _)|Rest], BRest) :- !,
    bridge_locals(Rest, BRest).
bridge_locals([local(Name, Type, Init0)|Rest],
              [local_var(Name, TypeAtom, init(Init))|BRest]) :-
    sized_type(Type, TypeAtom),
    initial_value(Type, Init0, Init),
    bridge_locals(Rest, BRest).

%------------------------------------------------------------
% Statement translation
%------------------------------------------------------------

bridge_stmts([], []).
bridge_stmts([S|Ss], [BS|BSs]) :-
    bridge_stmt(S, BS),
    bridge_stmts(Ss, BSs).

% Assignment to array element: assign(array_ref(Name, Idx), Expr) -> array_assign(Name, BIdx, BExpr)
bridge_stmt(assign(array_field(Name, Idx, Field), Expr), array_field_assign(Name, BIdx, Field, BExpr)) :- !,
    bridge_expr(Idx, BIdx),
    bridge_expr(Expr, BExpr).

bridge_stmt(assign(array_ref(Name, Idx), Expr), array_assign(Name, BIdx, BExpr)) :- !,
    bridge_expr(Idx, BIdx),
    bridge_expr(Expr, BExpr).

% Assignment. `SELF.P += E` reaches here as assign('SELF.P', add(var('SELF.P'), E)):
% treat a SELF.P target as a SELF property assignment.
bridge_stmt(assign(Var, Expr), self_assign(Prop, BExpr)) :-
    self_prop_name(Var, Prop), !,
    bridge_expr(Expr, BExpr).
bridge_stmt(assign(Var, Expr), assign(Var, BExpr)) :- !,
    bridge_expr(Expr, BExpr).

% Compound assignment (Var += Expr) - simple parser stores as assign(Var, add(var(Var), Expr))
% The modular simulator has assign_add but we can keep it as assign with binop

% Procedure call
bridge_stmt(call(Name, Args), call(Name, BArgs)) :- !,
    bridge_exprs(Args, BArgs).

% Return
bridge_stmt(return(Expr), return(BExpr)) :- !,
    bridge_expr(Expr, BExpr).
bridge_stmt(return, return) :- !.

% SELF assignment
bridge_stmt(self_assign(Prop, Expr), self_assign(Prop, BExpr)) :- !,
    bridge_expr(Expr, BExpr).

% PARENT method call
bridge_stmt(parent_call(Method, Args), parent_call(Method, BArgs)) :- !,
    bridge_exprs(Args, BArgs).

% Method call on instance
bridge_stmt(method_call(Obj, Method, Args), method_call(Obj, Method, BArgs)) :- !,
    bridge_exprs(Args, BArgs).

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

% Reference assignment: Ref &= NULL | NEW(Class) | Name | Expr
bridge_stmt(ref_assign(Var, null), ref_assign(Var, null)) :- !.
bridge_stmt(ref_assign(Var, call(New, [var(Class)])), ref_assign(Var, new(Class))) :-
    upcase_atom(New, 'NEW'), !.
bridge_stmt(ref_assign(Var, var(Name)), ref_assign(Var, name(Name))) :- !.
bridge_stmt(ref_assign(Var, Expr), ref_assign(Var, expr(BExpr))) :- !,
    bridge_expr(Expr, BExpr).

% Catch-all: pass through
bridge_stmt(S, S) :-
    format(user_error, "Warning: ast_bridge unhandled statement: ~w~n", [S]).

%------------------------------------------------------------
% CASE branch translation
%------------------------------------------------------------

bridge_case_ofs([], []).
% OF a OROF b ... : expand to one case_of per alternative, sharing the statements.
% Equivalent because CASE runs only the first matching branch.
bridge_case_ofs([of(any(Ranges), Stmts)|Rest], BCases) :- !,
    findall(of(R, Stmts), member(R, Ranges), Expanded),
    append(Expanded, Rest, All),
    bridge_case_ofs(All, BCases).
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
bridge_expr(var(Name), self_access(Prop)) :- self_prop_name(Name, Prop), !.
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
% Ref &= NULL / Ref &= Other (reference identity test)
bridge_expr(ref_eq(A, null), ref_eq(BA, null)) :- !, bridge_expr(A, BA).
bridge_expr(ref_eq(A, B), ref_eq(BA, BB)) :- !, bridge_expr(A, BA), bridge_expr(B, BB).
bridge_expr(neq(A, B), binop('<>', BA, BB)) :- !, bridge_expr(A, BA), bridge_expr(B, BB).
bridge_expr(lt(A, B), binop('<', BA, BB)) :- !, bridge_expr(A, BA), bridge_expr(B, BB).
bridge_expr(lte(A, B), binop('<=', BA, BB)) :- !, bridge_expr(A, BA), bridge_expr(B, BB).
bridge_expr(gt(A, B), binop('>', BA, BB)) :- !, bridge_expr(A, BA), bridge_expr(B, BB).
bridge_expr(gte(A, B), binop('>=', BA, BB)) :- !, bridge_expr(A, BA), bridge_expr(B, BB).

% Logical operators
bridge_expr(and(A, B), binop(and, BA, BB)) :- !, bridge_expr(A, BA), bridge_expr(B, BB).
bridge_expr(or(A, B), binop(or, BA, BB)) :- !, bridge_expr(A, BA), bridge_expr(B, BB).
bridge_expr(not(A), not(BA)) :- !, bridge_expr(A, BA).

% String concatenation
bridge_expr(concat(A, B), binop('&', BA, BB)) :- !, bridge_expr(A, BA), bridge_expr(B, BB).

% SELF property access
bridge_expr(self_access(Prop), self_access(Prop)) :- !.

% PARENT method call in expression
bridge_expr(parent_call(Method, Args), parent_call(Method, BArgs)) :- !, bridge_exprs(Args, BArgs).

% Method call on instance in expression
bridge_expr(method_call(Obj, Method, Args), method_call(Obj, Method, BArgs)) :- !, bridge_exprs(Args, BArgs).

% Function calls
bridge_expr(call(Name, Args), call(Name, BArgs)) :- !, bridge_exprs(Args, BArgs).

% Array reference
bridge_expr(array_ref(Name, Index), array_access(Name, BIndex)) :- !, bridge_expr(Index, BIndex).
bridge_expr(array_field(Name, Index, Field), array_field_access(Name, BIndex, Field)) :- !,
    bridge_expr(Index, BIndex).

% Logical NOT / ~expr (operand may contain calls)
bridge_expr(not(E), not(BE)) :- !, bridge_expr(E, BE).

% Omitted argument in a call: f(, a)
bridge_expr(omitted, omitted) :- !.

% Pass through anything already in modular format or unrecognized
bridge_expr(number(N), number(N)) :- !.
bridge_expr(string(S), string(S)) :- !.
bridge_expr(binop(Op, A, B), binop(Op, A, B)) :- !.
bridge_expr(control_ref(N), control_ref(N)) :- !.

% Catch-all
bridge_expr(E, E) :-
    format(user_error, "Warning: ast_bridge unhandled expr: ~w~n", [E]).

% 'SELF.Prop' (any case) names a property of the current object
self_prop_name(Name, Prop) :-
    atom(Name), sub_atom(Name, 0, 5, _, Pre), upcase_atom(Pre, 'SELF.'),
    sub_atom(Name, 5, _, 0, Prop), Prop \== ''.
