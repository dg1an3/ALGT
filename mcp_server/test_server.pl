%% test_server.pl
%%
%% Test suite for the ALGT MCP Server
%%
%% Run with: swipl -g run_tests -t halt test_server.pl

:- use_module(mcp_server).
:- use_module(mcp_protocol).
:- use_module(mcp_tools).
:- use_module(mcp_algt_tools).
:- use_module(library(plunit)).
:- use_module(library(http/json)).

:- begin_tests(mcp_tools).

test(register_tool) :-
    register_tool(
        "test_tool",
        "A test tool",
        _{type: "object", properties: _{}},
        test_handler
    ),
    list_tools(Tools),
    member(Tool, Tools),
    get_dict(name, Tool, "test_tool").

test(list_tools_after_algt_registration) :-
    register_algt_tools,
    list_tools(Tools),
    length(Tools, Count),
    Count >= 5,  % Should have at least 5 ALGT tools
    format("Registered ~d tools~n", [Count]).

test(call_prolog_query) :-
    register_algt_tools,
    call_tool("prolog_query", _{query: "member(X, [1,2,3])"}, Result),
    get_dict(content, Result, Content),
    Content = [ContentItem],
    get_dict(text, ContentItem, Text),
    sub_string(Text, _, _, _, "solution").

test(call_list_predicates) :-
    register_algt_tools,
    call_tool("list_predicates", _{module: "lists"}, Result),
    get_dict(content, Result, Content),
    Content = [ContentItem],
    get_dict(text, ContentItem, Text),
    sub_string(Text, _, _, _, "member").

test(call_unknown_tool) :-
    call_tool("nonexistent_tool", _{}, Result),
    get_dict(isError, Result, true).

:- end_tests(mcp_tools).

:- begin_tests(mcp_protocol).

test(json_response_format) :-
    Response = _{
        jsonrpc: "2.0",
        id: 1,
        result: _{tools: []}
    },
    atom_json_dict(Json, Response, []),
    atom_string(Json, JsonStr),
    sub_string(JsonStr, _, _, _, "jsonrpc").

:- end_tests(mcp_protocol).

%% Run all tests
:- initialization(run_tests, main).
