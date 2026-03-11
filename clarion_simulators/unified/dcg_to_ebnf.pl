% dcg_to_ebnf.pl — Convert clarion_parser.pl DCG rules to Mermaid railroad diagrams
%
% Usage:
%   swipl -l dcg_to_ebnf.pl -g main -t halt              % all productions
%   swipl -l dcg_to_ebnf.pl -g main -t halt -- --top      % top-level only
%   swipl -l dcg_to_ebnf.pl -g main -t halt -- --select program statement expr
%
% Output: clarion_railroad.md with Mermaid flowchart blocks

:- module(dcg_to_ebnf, [main/0]).

:- use_module(library(lists)).
:- use_module(library(apply)).

%% ==========================================================================
%% Entry point
%% ==========================================================================

main :-
    current_prolog_flag(argv, Argv),
    parse_options(Argv, Options),
    extract_dcg_rules('clarion_parser.pl', Rules),
    group_rules(Rules, Grouped),
    filter_productions(Options, Grouped, Selected),
    generate_markdown(Selected, MD),
    setup_call_cleanup(
        open('clarion_railroad.md', write, Out),
        write(Out, MD),
        close(Out)
    ),
    length(Selected, N),
    format("Generated clarion_railroad.md with ~w production diagrams.~n", [N]).

parse_options(Argv, select(Names)) :-
    append(_, ['--select'|Names0], Argv), Names0 \= [], !,
    maplist(atom_string, Names, Names0).
parse_options(Argv, top) :-
    member('--top', Argv), !.
parse_options(_, all).

%% ==========================================================================
%% Extract DCG rules from source file
%% ==========================================================================

extract_dcg_rules(File, Rules) :-
    % Save and restore the double_quotes flag — clarion_parser.pl sets it to codes
    current_prolog_flag(double_quotes, OldFlag),
    set_prolog_flag(double_quotes, codes),
    setup_call_cleanup(
        open(File, read, In),
        read_all_terms(In, Terms),
        close(In)
    ),
    set_prolog_flag(double_quotes, OldFlag),
    include(is_dcg_rule, Terms, Rules).

read_all_terms(In, Terms) :-
    read_term(In, T, []),
    ( T == end_of_file
    -> Terms = []
    ; Terms = [T|Rest],
      read_all_terms(In, Rest)
    ).

% Keep DCG rules, excluding low-level lexical rules
is_dcg_rule((_ --> _)) --> { true }, !.  % trick to test
is_dcg_rule((Head --> _Body)) :-
    callable(Head),
    functor(Head, Name, _),
    \+ member(Name, [ws, ws_nonnl, comment_body, line_continuation,
                     kw, digit, digits, qchars, ident_rest,
                     to_upper]).

%% ==========================================================================
%% Group rules by head functor name
%% ==========================================================================

group_rules(Rules, Grouped) :-
    map_list_to_pairs(rule_key, Rules, Pairs),
    keysort(Pairs, Sorted),
    group_pairs_by_key(Sorted, Grouped).

rule_key((Head --> _), Name) :-
    functor(Head, Name, _).

%% ==========================================================================
%% Filter productions based on options
%% ==========================================================================

filter_productions(all, Grouped, Grouped).
filter_productions(top, Grouped, Selected) :-
    TopNames = [program, top_decl_item, map_block, map_entry_or_module,
                procedure, routine, statement, expr, type,
                control_decl, window_attr, field_decl],
    include(key_in(TopNames), Grouped, Selected).
filter_productions(select(Names), Grouped, Selected) :-
    include(key_in(Names), Grouped, Selected).

key_in(Names, Key-_) :- member(Key, Names).

%% ==========================================================================
%% Generate Mermaid markdown
%% ==========================================================================

generate_markdown(Productions, MD) :-
    maplist(production_to_mermaid, Productions, Blocks),
    atomic_list_concat(['# Clarion Language - Railroad Diagrams\n\n',
                        'Generated from `clarion_parser.pl` DCG rules.\n\n'
                        | Blocks], MD).

production_to_mermaid(Name-Rules, Block) :-
    reset_counter,
    fresh_id(StartId),
    fresh_id(EndId),
    maplist(single_rule_to_mermaid(StartId, EndId), Rules, NodeLists, EdgeLists),
    flatten(NodeLists, Nodes0),
    flatten(EdgeLists, Edges0),
    format_node(StartId, start, circle, StartNode),
    format_node(EndId, finish, circle, EndNode),
    append(Nodes0, [StartNode, EndNode], AllNodes),
    sort(AllNodes, UniqueNodes),
    sort(Edges0, UniqueEdges),
    atomic_list_concat(UniqueNodes, NodeBlock),
    atomic_list_concat(UniqueEdges, EdgeBlock),
    format(atom(Block),
           '## ~w\n\n```mermaid\nflowchart LR\n~w~w```\n\n',
           [Name, NodeBlock, EdgeBlock]).

%% ==========================================================================
%% Convert DCG rule bodies to Mermaid nodes and edges
%% ==========================================================================

single_rule_to_mermaid(StartId, EndId, (_Head --> Body), Nodes, Edges) :-
    body_to_mermaid(Body, StartId, EndId, Nodes, Edges), !.
single_rule_to_mermaid(StartId, EndId, _, [], [Edge]) :-
    % Fallback: direct edge for unparseable rules
    format(atom(Edge), '    ~w --> ~w\n', [StartId, EndId]).

% Sequence (A, B)
body_to_mermaid((A, B), InId, OutId, Nodes, Edges) :-
    !,
    fresh_id(MidId),
    body_to_mermaid(A, InId, MidId, N1, E1),
    body_to_mermaid(B, MidId, OutId, N2, E2),
    append(N1, N2, Nodes),
    append(E1, E2, Edges).

% Alternative (A ; B)
body_to_mermaid((A ; B), InId, OutId, Nodes, Edges) :-
    !,
    body_to_mermaid(A, InId, OutId, NA, EA),
    body_to_mermaid(B, InId, OutId, NB, EB),
    append(NA, NB, Nodes),
    append(EA, EB, Edges).

% If-then (A -> B) — treat as sequence
body_to_mermaid((A -> B), InId, OutId, Nodes, Edges) :-
    !,
    body_to_mermaid((A, B), InId, OutId, Nodes, Edges).

% Cut — transparent
body_to_mermaid(!, InId, OutId, [], [Edge]) :- !,
    ( InId \= OutId
    -> format(atom(Edge), '    ~w --> ~w\n', [InId, OutId])
    ; Edge = ''
    ).

% Prolog goals {Goal} — transparent
body_to_mermaid({_}, InId, OutId, [], [Edge]) :- !,
    ( InId \= OutId
    -> format(atom(Edge), '    ~w --> ~w\n', [InId, OutId])
    ; Edge = ''
    ).

% Negation \+ — transparent
body_to_mermaid(\+(_), InId, OutId, [], [Edge]) :- !,
    ( InId \= OutId
    -> format(atom(Edge), '    ~w --> ~w\n', [InId, OutId])
    ; Edge = ''
    ).

% kw("KEYWORD") — keyword terminal (code list from double_quotes(codes))
body_to_mermaid(kw(Codes), InId, OutId, [Node], [Edge]) :-
    is_list(Codes), !,
    atom_codes(KW, Codes),
    fresh_id(NId),
    format_node(NId, KW, keyword, Node),
    format(atom(Edge), '    ~w --> ~w --> ~w\n', [InId, NId, OutId]).

% Terminal string literal (code list from double_quotes(codes))
body_to_mermaid(Terminal, InId, OutId, [Node], [Edge]) :-
    is_code_list(Terminal), !,
    atom_codes(Text, Terminal),
    fresh_id(NId),
    escape_label(Text, Safe),
    format_node(NId, Safe, terminal, Node),
    format(atom(Edge), '    ~w --> ~w --> ~w\n', [InId, NId, OutId]).

% Single character terminal [C]
body_to_mermaid([C], InId, OutId, [Node], [Edge]) :-
    integer(C), !,
    fresh_id(NId),
    char_code(Ch, C),
    escape_label(Ch, Safe),
    format(atom(Label), '~w', [Safe]),
    format_node(NId, Label, terminal, Node),
    format(atom(Edge), '    ~w --> ~w --> ~w\n', [InId, NId, OutId]).

% ws — skip (transparent, it's whitespace)
body_to_mermaid(ws, InId, OutId, [], [Edge]) :- !,
    ( InId \= OutId
    -> format(atom(Edge), '    ~w --> ~w\n', [InId, OutId])
    ; Edge = ''
    ).
body_to_mermaid(ws_nonnl, InId, OutId, [], [Edge]) :- !,
    ( InId \= OutId
    -> format(atom(Edge), '    ~w --> ~w\n', [InId, OutId])
    ; Edge = ''
    ).

% Non-terminal reference: any callable term like expr(E), statement(S), etc.
body_to_mermaid(NT, InId, OutId, [Node], [Edge]) :-
    callable(NT),
    \+ is_list(NT),
    !,
    functor(NT, Name, _),
    fresh_id(NId),
    format_node(NId, Name, nonterminal, Node),
    format(atom(Edge), '    ~w --> ~w --> ~w\n', [InId, NId, OutId]).

% Fallback — transparent
body_to_mermaid(_, InId, OutId, [], [Edge]) :-
    ( InId \= OutId
    -> format(atom(Edge), '    ~w --> ~w\n', [InId, OutId])
    ; Edge = ''
    ).

%% ==========================================================================
%% Helpers
%% ==========================================================================

is_code_list(Term) :-
    is_list(Term),
    Term \= [],
    maplist(integer, Term).

% Node shapes:
%   keyword  → parallelogram [/ /]
%   terminal → stadium ([ ])
%   nonterminal → rectangle [ ]
%   circle → (( ))
format_node(Id, Label, keyword, Node) :- !,
    format(atom(Node), '    ~w[/"~w"/]~n', [Id, Label]).
format_node(Id, Label, terminal, Node) :- !,
    format(atom(Node), '    ~w(["~w"])~n', [Id, Label]).
format_node(Id, Label, nonterminal, Node) :- !,
    format(atom(Node), '    ~w["~w"]~n', [Id, Label]).
format_node(Id, _Label, circle, Node) :-
    format(atom(Node), '    ~w(((" ")))~n', [Id]).

escape_label(Text, Safe) :-
    atom_chars(Text, Chars),
    maplist(esc_char, Chars, EscParts),
    flatten(EscParts, FlatChars),
    atom_chars(Safe, FlatChars).

esc_char('"', ['&','#','3','4',';']) :- !.
esc_char('<', ['&','l','t',';']) :- !.
esc_char('>', ['&','g','t',';']) :- !.
esc_char(C, [C]).

%% ==========================================================================
%% Fresh ID counter
%% ==========================================================================

:- dynamic counter/1.
counter(0).

reset_counter :- retractall(counter(_)), assert(counter(0)).

fresh_id(Id) :-
    retract(counter(N)),
    N1 is N + 1,
    assert(counter(N1)),
    format(atom(Id), 'n~w', [N]).
