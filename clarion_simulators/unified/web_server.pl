%============================================================
% web_server.pl - Web UI for the Clarion Simulator
%
% Serves HTML pages showing Clarion source code, parsed AST,
% and (eventually) interactive simulator execution.
%
% Static assets (CSS, JS) live in the web/ subdirectory.
%
% Usage:
%   swipl -l web_server.pl -g "start_server(8080)"
%
% Then open http://localhost:8080/ in a browser.
%============================================================

:- module(web_server, [
    start_server/1
]).

:- use_module(library(http/thread_httpd)).
:- use_module(library(http/http_dispatch)).
:- use_module(library(http/http_parameters)).
:- use_module(library(http/html_write)).
:- use_module(library(http/html_head)).
:- use_module(library(http/http_json)).
:- use_module(library(http/json)).
:- use_module(library(filesex)).

:- use_module(clarion, [parse_clarion/2, bridge/2, exec_procedure/4]).
:- use_module(ast_bridge, [bridge_ast/2]).

%------------------------------------------------------------
% HTTP Routes
%------------------------------------------------------------

:- http_handler(root(.),       handle_index,   []).
:- http_handler(root(view),    handle_view,    []).
:- http_handler(root(run),     handle_run,     [method(post)]).
:- http_handler(root(api/parse), handle_api_parse, [method(post)]).
:- http_handler(root(api/run),   handle_api_run,   [method(post)]).
:- http_handler(root(static),   handle_static,  [prefix]).

%------------------------------------------------------------
% Server Start
%------------------------------------------------------------

start_server(Port) :-
    http_server(http_dispatch, [port(Port)]),
    format("Clarion Simulator Web UI running at http://localhost:~w/~n", [Port]).

%------------------------------------------------------------
% Static File Serving
%------------------------------------------------------------

%% web_dir(-Dir) is det.
% Absolute path to the web/ assets directory.
web_dir(Dir) :-
    source_file(web_server:start_server(_), ThisFile),
    file_directory_name(ThisFile, BaseDir),
    directory_file_path(BaseDir, web, Dir).

%% mime_type(+Ext, -ContentType) is semidet.
mime_type(css,  'text/css').
mime_type(js,   'application/javascript').
mime_type(html, 'text/html').

handle_static(Request) :-
    memberchk(path(Path), Request),
    % Strip /static/ prefix to get relative file name
    atom_concat('/static/', RelPath, Path),
    web_dir(WebDir),
    directory_file_path(WebDir, RelPath, AbsPath),
    ( exists_file(AbsPath) ->
        file_name_extension(_, Ext, AbsPath),
        ( mime_type(Ext, ContentType) -> true ; ContentType = 'application/octet-stream' ),
        read_file_to_string(AbsPath, Content, []),
        format('Content-type: ~w~n~n', [ContentType]),
        write(Content)
    ;
        format('Content-type: text/plain~nStatus: 404~n~nNot found: ~w~n', [RelPath])
    ).

%------------------------------------------------------------
% File Discovery
%------------------------------------------------------------

%% clw_search_dirs(-Dirs) is det.
% Directories to scan for .clw files.
clw_search_dirs(Dirs) :-
    Dirs = [
        '../../clarion_projects/python-dll',
        '../../clarion_projects/sensor-data',
        '../../clarion_projects/stats-calc',
        '../../clarion_projects/diagnosis-store',
        '../../clarion_projects/form-demo',
        '../../clarion_projects/treatment-offset',
        '../../clarion_projects/hello-world',
        '../../clarion_projects/clarion_examples'
    ].

%% find_clw_files(-Files) is det.
% Find all .clw files in search directories.
% Files is a list of file(DisplayName, AbsPath).
find_clw_files(Files) :-
    clw_search_dirs(Dirs),
    findall(File, (
        member(Dir, Dirs),
        absolute_file_name(Dir, AbsDir, [file_type(directory), access(exist), file_errors(fail)]),
        directory_files(AbsDir, Entries),
        member(Entry, Entries),
        file_name_extension(_, clw, Entry),
        directory_file_path(AbsDir, Entry, AbsPath),
        % Build display name from parent dir + filename
        file_base_name(AbsDir, ParentDir),
        atomic_list_concat([ParentDir, '/', Entry], DisplayName),
        File = file(DisplayName, AbsPath)
    ), Files).

%------------------------------------------------------------
% Index Page — File Listing
%------------------------------------------------------------

handle_index(_Request) :-
    find_clw_files(Files),
    group_by_dir(Files, Grouped),
    reply_html_page(
        title('Clarion Simulator'),
        [ \html_head_extras,
          div(class(container), [
            h1('Clarion Simulator'),
            p(class(subtext), 'Select a .clw file to view its source and AST, or write code in the editor.'),
            div(class(panels), [
                div(class(panel), [
                    div(class('panel-header'), 'Project Files'),
                    ul(class('file-list'), \file_list_grouped(Grouped))
                ]),
                div(class(panel), [
                    div(class('panel-header'), 'Code Editor'),
                    \editor_panel
                ])
            ])
          ]),
          script([src('/static/editor.js')], [])
        ]).

html_head_extras -->
    html(link([rel(stylesheet), href('/static/style.css')])).

file_list_grouped([]) --> [].
file_list_grouped([Dir-DirFiles|Rest]) -->
    html(li(class('dir-header'), Dir)),
    file_list_entries(DirFiles),
    file_list_grouped(Rest).

file_list_entries([]) --> [].
file_list_entries([file(_Display, Path)|Rest]) -->
    { file_base_name(Path, FileName),
      format(atom(Href), '/view?file=~w', [Path]) },
    html(li(a([href(Href)], FileName))),
    file_list_entries(Rest).

editor_panel -->
    html([
        textarea([class('code-editor'), id(editor)],
'  MEMBER()\r\n\r\n  MAP\r\n    MyAdd(LONG a, LONG b),LONG,C,NAME(\'MyAdd\')\r\n  END\r\n\r\nMyAdd PROCEDURE(LONG a, LONG b)\r\n  CODE\r\n  RETURN a + b\r\n'),
        div(class('editor-actions'), [
            button([class('run-btn'), onclick('parseEditor()')], 'Parse AST'),
            button([class('run-btn'), onclick('runEditor()')], 'Run...')
        ]),
        div([id('editor-ast'), class('run-output')], '')
    ]).

group_by_dir([], []).
group_by_dir(Files, Grouped) :-
    findall(Dir, (member(file(D, _), Files), atomic_list_concat([Dir|_], '/', D)), DirsRaw),
    sort(DirsRaw, Dirs),
    maplist(dir_files(Files), Dirs, Grouped).

dir_files(Files, Dir, Dir-DirFiles) :-
    include(file_in_dir(Dir), Files, DirFiles).

file_in_dir(Dir, file(Display, _)) :-
    atomic_list_concat([Dir|_], '/', Display).

%------------------------------------------------------------
% View Page — Source + AST
%------------------------------------------------------------

handle_view(Request) :-
    http_parameters(Request, [file(FilePath, [])]),
    ( exists_file(FilePath) ->
        read_file_to_string(FilePath, Source, []),
        file_base_name(FilePath, FileName),
        % Try to parse
        ( catch(parse_clarion(Source, SimpleAST), ParseErr, (SimpleAST = error(ParseErr))) ->
            true
        ; SimpleAST = error(parse_failed)
        ),
        % Try to bridge
        ( SimpleAST \= error(_),
          catch(bridge_ast(SimpleAST, ModAST), BridgeErr, (ModAST = error(BridgeErr))) ->
            true
        ; ModAST = none
        ),
        % Extract procedure names for run form
        ( ModAST \= none, ModAST \= error(_),
          ModAST = program(_, _, _, Procs) ->
            findall(PName, (
                member(P, Procs),
                proc_name(P, PName)
            ), ProcNames)
        ; ProcNames = []
        ),
        reply_html_page(
            title(FileName),
            [ \html_head_extras,
              div(class(container), [
                div(class(nav), [
                    a(href('/'), 'Back to files')
                ]),
                h1(FileName),
                \run_section(ProcNames),
                div(class(panels), [
                    div(class(panel), [
                        div(class('panel-header'), 'Source'),
                        pre(\highlight_source(Source))
                    ]),
                    div(class(panel), [
                        div(class('tab-bar'), [
                            div([class('tab active'), onclick('switchTab(this, \'simple-ast\')')], 'Simple AST'),
                            div([class(tab), onclick('switchTab(this, \'bridged-ast\')')], 'Bridged AST')
                        ]),
                        div([class('tab-content active'), id('simple-ast')],
                            pre(class(ast), \format_ast(SimpleAST, 0))),
                        div([class('tab-content'), id('bridged-ast')],
                            pre(class(ast), \format_ast(ModAST, 0)))
                    ])
                ]),
                \file_path_script(FilePath)
              ]),
              script([src('/static/view.js')], [])
            ])
    ;
        reply_html_page(title('Not Found'),
            [h1('File not found'), p(FilePath)])
    ).

proc_name(proc(Name, _, _, _), Name) :- !.
proc_name(proc(Name, _, _), Name) :- !.
proc_name(procedure(Name, _, _), Name) :- !.
proc_name(procedure(Name, _, _, _), Name) :- !.

%% file_path_script(+FilePath)// is det.
% Emit a small inline script that sets window.__filePath for view.js.
file_path_script(FilePath) -->
    { format(atom(JS), 'window.__filePath = "~w";', [FilePath]) },
    html(script([], JS)).

%------------------------------------------------------------
% Run Section
%------------------------------------------------------------

run_section(ProcNames) -->
    { ProcNames \= [] },
    !,
    html(div(class('run-section'), [
        div(class('run-form'), [
            label(for(proc), 'Procedure:'),
            select([id(proc), name(proc)], \proc_options(ProcNames)),
            label(for(args), 'Args (comma-separated):'),
            input([id(args), name(args), type(text), placeholder('e.g. 3, 4'), size(20)]),
            button([class('run-btn'), onclick('runProcedure()')], 'Run')
        ]),
        div([id('run-output'), class('run-output')], '')
    ])).
run_section(_) --> [].

proc_options([]) --> [].
proc_options([Name|Rest]) -->
    html(option([value(Name)], Name)),
    proc_options(Rest).

%------------------------------------------------------------
% API Endpoints
%------------------------------------------------------------

handle_api_parse(Request) :-
    http_read_json_dict(Request, Dict),
    Source = Dict.source,
    ( catch(
        ( parse_clarion(Source, SimpleAST),
          bridge_ast(SimpleAST, ModAST),
          term_to_ast_string(SimpleAST, SimpleStr),
          term_to_ast_string(ModAST, ModStr),
          Reply = json{status: ok, simple_ast: SimpleStr, bridged_ast: ModStr}
        ),
        Err,
        ( term_string(Err, ErrStr),
          Reply = json{status: error, message: ErrStr}
        )
      ) -> true
    ; Reply = json{status: error, message: "Parse failed"}
    ),
    reply_json_dict(Reply).

handle_api_run(Request) :-
    http_read_json_dict(Request, Dict),
    ( get_dict(source, Dict, Source) -> true
    ; get_dict(file, Dict, FilePath),
      read_file_to_string(FilePath, Source, [])
    ),
    ProcName = Dict.procedure,
    ArgsRaw = Dict.get(args, []),
    ( is_list(ArgsRaw) -> ArgsList = ArgsRaw
    ; atom_string(ArgsRaw, ArgsStr),
      ( ArgsStr == "" -> ArgsList = []
      ; split_string(ArgsStr, ",", " ", ArgParts),
        maplist(parse_arg, ArgParts, ArgsList)
      )
    ),
    atom_string(ProcAtom, ProcName),
    ( catch(
        ( exec_procedure(Source, ProcAtom, ArgsList, Result),
          term_string(Result, ResultStr),
          Reply = json{status: ok, result: ResultStr}
        ),
        Err,
        ( term_string(Err, ErrStr),
          Reply = json{status: error, message: ErrStr}
        )
      ) -> true
    ; Reply = json{status: error, message: "Execution failed"}
    ),
    reply_json_dict(Reply).

handle_run(Request) :-
    handle_api_run(Request).

parse_arg(S, N) :-
    number_string(N, S), !.
parse_arg(S, A) :-
    atom_string(A, S).

term_to_ast_string(Term, String) :-
    with_output_to(string(String),
        print_term(Term, [output(current_output), right_margin(100)])).

%------------------------------------------------------------
% Syntax Highlighting (Clarion)
%------------------------------------------------------------

highlight_source(Source) -->
    { split_string(Source, "\n", "", Lines),
      length(Lines, NumLines),
      numlist(1, NumLines, LineNums),
      pairs_keys_values(Pairs, LineNums, Lines) },
    highlight_lines(Pairs).

highlight_lines([]) --> [].
highlight_lines([N-Line|Rest]) -->
    { format(atom(NumStr), "~d", [N]) },
    html([span(class('line-num'), NumStr), \highlight_line(Line), '\n']),
    highlight_lines(Rest).

highlight_line(Line) -->
    { string_codes(Line, Codes),
      tokenize_line(Codes, Tokens) },
    emit_tokens(Tokens).

emit_tokens([]) --> [].
emit_tokens([Token|Rest]) -->
    html(\emit_token(Token)),
    emit_tokens(Rest).

emit_token(kw(Text)) -->
    html(span(class(kw), Text)).
emit_token(type_kw(Text)) -->
    html(span(class('type-kw'), Text)).
emit_token(comment(Text)) -->
    html(span(class(comment), Text)).
emit_token(str(Text)) -->
    html(span(class(str), Text)).
emit_token(num(Text)) -->
    html(span(class(num), Text)).
emit_token(op(Text)) -->
    html(span(class(op), Text)).
emit_token(proc(Text)) -->
    html(span(class('proc-name'), Text)).
emit_token(plain(Text)) -->
    html(Text).

% Tokenizer — splits a line into classified tokens
tokenize_line([], []).
tokenize_line(Codes, Tokens) :-
    Codes = [C|_],
    ( C =:= 0'! ->
        string_codes(S, Codes),
        Tokens = [comment(S)]
    ; C =:= 0'' ->
        take_string(Codes, StrCodes, Rest),
        string_codes(S, StrCodes),
        tokenize_line(Rest, RestTokens),
        Tokens = [str(S)|RestTokens]
    ; is_alpha(C) ->
        take_word(Codes, WordCodes, Rest),
        string_codes(Word, WordCodes),
        classify_word(Word, Token),
        tokenize_line(Rest, RestTokens),
        Tokens = [Token|RestTokens]
    ; is_digit(C) ->
        take_number(Codes, NumCodes, Rest),
        string_codes(S, NumCodes),
        tokenize_line(Rest, RestTokens),
        Tokens = [num(S)|RestTokens]
    ; memberchk(C, [0'+, 0'-, 0'*, 0'/, 0'=, 0'<, 0'>, 0'(, 0'), 0',, 0'[, 0'], 0'&, 0'%]) ->
        char_code(Ch, C),
        atom_string(Ch, ChStr),
        Codes = [_|Rest],
        tokenize_line(Rest, RestTokens),
        Tokens = [op(ChStr)|RestTokens]
    ; Codes = [_|Rest],
        char_code(Ch, C),
        atom_string(Ch, ChStr),
        tokenize_line(Rest, RestTokens),
        Tokens = [plain(ChStr)|RestTokens]
    ).

is_alpha(C) :- C >= 0'a, C =< 0'z, !.
is_alpha(C) :- C >= 0'A, C =< 0'Z, !.
is_alpha(C) :- C =:= 0'_, !.
is_alpha(C) :- C =:= 0'?, !.  % Clarion equates like ?Button
is_alpha(C) :- C =:= 0':, !.  % For qualified names like ST:Mean

is_digit(C) :- C >= 0'0, C =< 0'9.

is_alnum(C) :- is_alpha(C), !.
is_alnum(C) :- is_digit(C).

take_word([], [], []).
take_word([C|Cs], [C|Ws], Rest) :- is_alnum(C), !, take_word(Cs, Ws, Rest).
take_word(Codes, [], Codes).

take_number([], [], []).
take_number([C|Cs], [C|Ns], Rest) :- is_digit(C), !, take_number(Cs, Ns, Rest).
take_number([0'.|Cs], [0'.|Ns], Rest) :- Cs = [D|_], is_digit(D), !, take_number(Cs, Ns, Rest).
take_number(Codes, [], Codes).

take_string([0''|Cs], [0''|Ss], Rest) :- take_string_inner(Cs, Ss, Rest).
take_string(Codes, [], Codes).

take_string_inner([], [], []).
take_string_inner([0''|Cs], [0''], Cs) :- !.
take_string_inner([C|Cs], [C|Ss], Rest) :- take_string_inner(Cs, Ss, Rest).

classify_word(Word, Token) :-
    upcase_atom(Word, Upper),
    atom_string(Upper, UpperStr),
    ( is_keyword(UpperStr) -> Token = kw(Word)
    ; is_type_keyword(UpperStr) -> Token = type_kw(Word)
    ; Token = plain(Word)
    ).

upcase_atom(Word, Upper) :-
    string_upper(Word, UpperStr),
    atom_string(Upper, UpperStr).

is_keyword(W) :- memberchk(W, [
    "MEMBER", "PROGRAM", "MAP", "MODULE", "END", "PROCEDURE", "CODE",
    "IF", "THEN", "ELSIF", "ELSE", "CASE", "OF", "OROF",
    "LOOP", "TO", "BY", "WHILE", "UNTIL", "BREAK", "CYCLE", "EXIT",
    "RETURN", "DO", "ROUTINE",
    "FILE", "RECORD", "GROUP", "QUEUE", "CLASS", "EXPORT", "PRIVATE",
    "OPEN", "CLOSE", "ADD", "PUT", "GET", "DELETE", "NEXT", "PREVIOUS",
    "SET", "FREE", "SORT", "RECORDS", "CREATE",
    "ACCEPT", "WINDOW", "BUTTON", "ENTRY", "STRING", "LIST", "DROP",
    "DISPLAY", "SELECT", "USE", "SELF", "PARENT", "VIRTUAL",
    "BEGIN", "SECTION", "INCLUDE", "NAME", "LIKE", "PRE", "DIM",
    "NOT", "AND", "OR", "TRUE", "FALSE", "RAW", "PASCAL"
]).

is_type_keyword(W) :- memberchk(W, [
    "LONG", "SHORT", "BYTE", "REAL", "SREAL", "DECIMAL", "PDECIMAL",
    "STRING", "CSTRING", "PSTRING", "DATE", "TIME",
    "SIGNED", "UNSIGNED", "BINARY", "BOOL"
]).

%------------------------------------------------------------
% AST Pretty-Printer (HTML)
%------------------------------------------------------------

format_ast(error(Err), _Indent) -->
    !,
    { term_string(Err, ErrStr) },
    html(span(class('run-error'), ['Parse error: ', ErrStr])).
format_ast(none, _Indent) -->
    !,
    html(span(class('ast-atom'), 'N/A')).
format_ast(Term, Indent) -->
    { compound(Term), \+ is_list(Term), \+ string(Term) },
    !,
    { Term =.. [Functor|Args],
      NextIndent is Indent + 1 },
    html(span(class('ast-functor'), Functor)),
    ( { Args = [] } -> html('') ; \format_ast_args(Args, NextIndent) ).
format_ast(List, Indent) -->
    { is_list(List) },
    !,
    \format_ast_list(List, Indent).
format_ast(N, _) -->
    { number(N) },
    !,
    { term_string(N, NS) },
    html(span(class('ast-number'), NS)).
format_ast(A, _) -->
    { atom(A) },
    !,
    { atom_string(A, AS) },
    html(span(class('ast-atom'), AS)).
format_ast(S, _) -->
    { string(S) },
    !,
    { format(atom(Quoted), '"~w"', [S]) },
    html(span(class('ast-atom'), Quoted)).
format_ast(T, _) -->
    { term_string(T, TS) },
    html(TS).

format_ast_args([], _) --> [].
format_ast_args(Args, Indent) -->
    html('('),
    ( { length(Args, Len), Len =< 2, all_simple(Args) } ->
        % Inline short args
        \format_ast_inline(Args, Indent)
    ;
        html('\n'),
        \format_ast_indented(Args, Indent)
    ),
    html(')').

format_ast_inline([], _) --> [].
format_ast_inline([Arg], Indent) -->
    \format_ast(Arg, Indent).
format_ast_inline([Arg|Rest], Indent) -->
    { Rest \= [] },
    \format_ast(Arg, Indent),
    html(', '),
    format_ast_inline(Rest, Indent).

format_ast_indented([], _) --> [].
format_ast_indented([Arg], Indent) -->
    \indent_html(Indent),
    \format_ast(Arg, Indent),
    html('\n').
format_ast_indented([Arg|Rest], Indent) -->
    { Rest \= [] },
    \indent_html(Indent),
    \format_ast(Arg, Indent),
    html(',\n'),
    format_ast_indented(Rest, Indent).

format_ast_list([], _) --> html(span(class('ast-list'), '[]')).
format_ast_list(List, Indent) -->
    { length(List, Len), Len =< 3, all_simple(List) },
    !,
    html(span(class('ast-list'), '[')),
    format_ast_inline(List, Indent),
    html(span(class('ast-list'), ']')).
format_ast_list(List, Indent) -->
    { NextIndent is Indent + 1 },
    html(span(class('ast-list'), '[\n')),
    format_ast_indented(List, NextIndent),
    \indent_html(Indent),
    html(span(class('ast-list'), ']')).

all_simple([]).
all_simple([X|Xs]) :- (atom(X) ; number(X) ; string(X)), all_simple(Xs).

indent_html(0) --> !.
indent_html(N) -->
    { N > 0, N1 is N - 1 },
    html('  '),
    indent_html(N1).

%------------------------------------------------------------
% Standalone entry point
%------------------------------------------------------------

:- initialization((
    current_prolog_flag(argv, Argv),
    ( Argv = [PortAtom|_] ->
        atom_number(PortAtom, Port)
    ; Port = 8080
    ),
    start_server(Port)
), main).
