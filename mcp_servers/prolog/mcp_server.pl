%% mcp_server.pl
%%
%% Main MCP (Model Context Protocol) server implementation for SWI-Prolog
%% Communicates via stdio using JSON-RPC 2.0
%%
%% Copyright (C) 2024 ALGT Project
%%
%% Usage:
%%   swipl -g start -t halt mcp_server/mcp_server.pl
%%
%% Or interactively:
%%   ?- consult('mcp_server/mcp_server.pl').
%%   ?- start.

:- module(mcp_server, [
    start/0,
    start/1
]).

:- use_module(mcp_protocol).
:- use_module(mcp_tools).
:- use_module(mcp_algt_tools).
:- use_module(library(http/json)).
:- use_module(library(readutil)).

%% MCP Protocol Version
mcp_protocol_version("2024-11-05").

%% Server Info
server_name("algt-mcp-server").
server_version("0.1.0").

%% start/0
%%
%% Starts the MCP server on stdio

start :-
    start([]).

%% start/1
%%
%% Starts the MCP server with options

start(Options) :-
    % Register ALGT tools
    register_algt_tools,

    % Set up streams
    current_input(In),
    current_output(Out),
    set_stream(In, encoding(utf8)),
    set_stream(Out, encoding(utf8)),
    set_stream(In, newline(detect)),

    % Log startup to stderr (doesn't interfere with stdio protocol)
    log_info("ALGT MCP Server starting..."),

    % Enter main message loop
    message_loop(In, Out, Options).

%% message_loop(+In, +Out, +Options)
%%
%% Main message processing loop

message_loop(In, Out, Options) :-
    catch(
        read_jsonrpc_message(In, Message),
        Error,
        (   log_error("Read error: ~w", [Error]),
            Message = error(Error)
        )
    ),
    (   Message == end_of_file
    ->  log_info("End of input, shutting down"),
        true
    ;   Message = error(_)
    ->  true  % Exit on read error
    ;   Message = json_error(ParseError)
    ->  parse_error(Code),
        format(atom(ErrorMsg), "Parse error: ~w", [ParseError]),
        Response = _{
            jsonrpc: "2.0",
            id: null,
            error: _{code: Code, message: ErrorMsg}
        },
        write_jsonrpc_response(Out, Response),
        message_loop(In, Out, Options)
    ;   handle_message(Message, Out, Options),
        message_loop(In, Out, Options)
    ).

%% handle_message(+Message, +Out, +Options)
%%
%% Dispatches a JSON-RPC message to the appropriate handler

handle_message(Message, Out, _Options) :-
    % Extract message components
    (   get_dict(id, Message, Id) -> true ; Id = null ),
    (   get_dict(method, Message, Method) -> true ; Method = "" ),
    (   get_dict(params, Message, Params) -> true ; Params = _{} ),

    log_info("Received: ~w (id=~w)", [Method, Id]),

    % Handle based on method
    (   Method == "initialize"
    ->  handle_initialize(Id, Params, Out)
    ;   Method == "initialized"
    ->  handle_initialized(Out)
    ;   Method == "shutdown"
    ->  handle_shutdown(Id, Out)
    ;   Method == "tools/list"
    ->  handle_tools_list(Id, Out)
    ;   Method == "tools/call"
    ->  handle_tools_call(Id, Params, Out)
    ;   Method == "ping"
    ->  handle_ping(Id, Out)
    ;   Id \= null
    ->  % Unknown method with id -> error response
        method_not_found(Code),
        format(atom(ErrorMsg), "Unknown method: ~w", [Method]),
        Response = _{
            jsonrpc: "2.0",
            id: Id,
            error: _{code: Code, message: ErrorMsg}
        },
        write_jsonrpc_response(Out, Response)
    ;   % Unknown notification -> ignore
        log_info("Ignoring unknown notification: ~w", [Method])
    ).

%% handle_initialize(+Id, +Params, +Out)
%%
%% Handles the initialize request

handle_initialize(Id, Params, Out) :-
    mcp_protocol_version(ProtocolVersion),
    server_name(ServerName),
    server_version(ServerVersion),

    % Log client info
    (   get_dict(clientInfo, Params, ClientInfo)
    ->  log_info("Client: ~w", [ClientInfo])
    ;   true
    ),

    Response = _{
        jsonrpc: "2.0",
        id: Id,
        result: _{
            protocolVersion: ProtocolVersion,
            capabilities: _{
                tools: _{
                    listChanged: false
                }
            },
            serverInfo: _{
                name: ServerName,
                version: ServerVersion
            }
        }
    },
    write_jsonrpc_response(Out, Response).

%% handle_initialized(+Out)
%%
%% Handles the initialized notification

handle_initialized(_Out) :-
    log_info("Client initialized successfully").

%% handle_shutdown(+Id, +Out)
%%
%% Handles the shutdown request

handle_shutdown(Id, Out) :-
    log_info("Shutdown requested"),
    Response = _{
        jsonrpc: "2.0",
        id: Id,
        result: null
    },
    write_jsonrpc_response(Out, Response).

%% handle_ping(+Id, +Out)
%%
%% Handles ping request

handle_ping(Id, Out) :-
    Response = _{
        jsonrpc: "2.0",
        id: Id,
        result: _{}
    },
    write_jsonrpc_response(Out, Response).

%% handle_tools_list(+Id, +Out)
%%
%% Handles tools/list request

handle_tools_list(Id, Out) :-
    list_tools(Tools),
    Response = _{
        jsonrpc: "2.0",
        id: Id,
        result: _{
            tools: Tools
        }
    },
    write_jsonrpc_response(Out, Response).

%% handle_tools_call(+Id, +Params, +Out)
%%
%% Handles tools/call request

handle_tools_call(Id, Params, Out) :-
    (   get_dict(name, Params, ToolName),
        get_dict(arguments, Params, Arguments)
    ->  log_info("Calling tool: ~w", [ToolName]),
        call_tool(ToolName, Arguments, ToolResult),
        Response = _{
            jsonrpc: "2.0",
            id: Id,
            result: ToolResult
        }
    ;   invalid_params(Code),
        Response = _{
            jsonrpc: "2.0",
            id: Id,
            error: _{
                code: Code,
                message: "Missing required parameters: name, arguments"
            }
        }
    ),
    write_jsonrpc_response(Out, Response).

%% log_info(+Format, +Args)
%%
%% Logs an info message to stderr

log_info(Format, Args) :-
    get_time(Time),
    format_time(atom(TimeStr), "%Y-%m-%d %H:%M:%S", Time),
    format(user_error, "[~w] INFO: ", [TimeStr]),
    format(user_error, Format, Args),
    nl(user_error),
    flush_output(user_error).

log_info(Message) :-
    log_info("~w", [Message]).

%% log_error(+Format, +Args)
%%
%% Logs an error message to stderr

log_error(Format, Args) :-
    get_time(Time),
    format_time(atom(TimeStr), "%Y-%m-%d %H:%M:%S", Time),
    format(user_error, "[~w] ERROR: ", [TimeStr]),
    format(user_error, Format, Args),
    nl(user_error),
    flush_output(user_error).
