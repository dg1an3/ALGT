%% mcp_protocol.pl
%%
%% JSON-RPC 2.0 protocol handling for MCP server
%%
%% Copyright (C) 2024 ALGT Project

:- module(mcp_protocol, [
    read_jsonrpc_message/2,
    write_jsonrpc_response/2,
    write_jsonrpc_error/4,
    write_jsonrpc_notification/3,
    jsonrpc_error_response/4,
    parse_error/1,
    invalid_request/1,
    method_not_found/1,
    invalid_params/1,
    internal_error/1
]).

:- use_module(library(http/json)).
:- use_module(library(readutil)).

%% JSON-RPC 2.0 Error Codes
parse_error(-32700).
invalid_request(-32600).
method_not_found(-32601).
invalid_params(-32602).
internal_error(-32603).

%% read_jsonrpc_message(+Stream, -Message)
%%
%% Reads a JSON-RPC message from the stream.
%% MCP stdio transport uses newline-delimited JSON (one JSON object per line).

read_jsonrpc_message(Stream, Message) :-
    read_line_to_string(Stream, Line),
    (   Line == end_of_file
    ->  Message = end_of_file
    ;   string_trim(Line, Trimmed),
        Trimmed == ""
    ->  read_jsonrpc_message(Stream, Message)  % skip blank lines
    ;   string_trim(Line, Trimmed),
        catch(
            atom_json_dict(Trimmed, Message, []),
            Error,
            (   log_error("JSON parse error: ~w", [Error]),
                Message = json_error(Error)
            )
        )
    ).

%% string_trim(+String, -Trimmed)
%% Remove leading/trailing whitespace and CR
string_trim(String, Trimmed) :-
    split_string(String, "", " \t\r\n", [Trimmed|_]),
    !.
string_trim(_, "").

%% write_jsonrpc_response(+Stream, +Response)
%%
%% Writes a JSON-RPC response as a single line of JSON followed by a newline.
%% MCP stdio transport uses newline-delimited JSON.

write_jsonrpc_response(Stream, Response) :-
    with_output_to(string(JsonString),
        json_write_dict(current_output, Response, [width(0)])
    ),
    format(Stream, "~w\n", [JsonString]),
    flush_output(Stream).

%% write_jsonrpc_error(+Stream, +Id, +Code, +Message)
%%
%% Writes a JSON-RPC error response

write_jsonrpc_error(Stream, Id, Code, Message) :-
    Response = _{
        jsonrpc: "2.0",
        id: Id,
        error: _{
            code: Code,
            message: Message
        }
    },
    write_jsonrpc_response(Stream, Response).

%% write_jsonrpc_notification(+Stream, +Method, +Params)
%%
%% Writes a JSON-RPC notification (no id, no response expected)

write_jsonrpc_notification(Stream, Method, Params) :-
    Notification = _{
        jsonrpc: "2.0",
        method: Method,
        params: Params
    },
    write_jsonrpc_response(Stream, Notification).

%% jsonrpc_error_response(+Id, +Code, +Message, -Response)
%%
%% Creates a JSON-RPC error response dict

jsonrpc_error_response(Id, Code, Message, Response) :-
    Response = _{
        jsonrpc: "2.0",
        id: Id,
        error: _{
            code: Code,
            message: Message
        }
    }.

%% log_error(+Format, +Args)
%%
%% Logs an error to stderr

log_error(Format, Args) :-
    format(user_error, Format, Args),
    nl(user_error),
    flush_output(user_error).
