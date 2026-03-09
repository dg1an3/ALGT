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
%% Reads a JSON-RPC message from the stream using Content-Length header
%% MCP uses HTTP-style headers: Content-Length: <n>\r\n\r\n<json>

read_jsonrpc_message(Stream, Message) :-
    read_headers(Stream, Headers),
    (   Headers == end_of_file
    ->  Message = end_of_file
    ;   memberchk(content_length(Length), Headers),
        read_string(Stream, Length, JsonString),
        catch(
            atom_json_dict(JsonString, Message, []),
            Error,
            (   log_error("JSON parse error: ~w", [Error]),
                Message = json_error(Error)
            )
        )
    ).

%% read_headers(+Stream, -Headers)
%%
%% Reads HTTP-style headers until empty line

read_headers(Stream, Headers) :-
    read_line_to_string(Stream, Line),
    (   Line == end_of_file
    ->  Headers = end_of_file
    ;   Line == ""
    ->  Headers = []
    ;   Line == "\r"
    ->  Headers = []
    ;   parse_header(Line, Header),
        read_headers(Stream, RestHeaders),
        (   RestHeaders == end_of_file
        ->  Headers = [Header]
        ;   Headers = [Header | RestHeaders]
        )
    ).

%% parse_header(+Line, -Header)
%%
%% Parses a single header line

parse_header(Line, content_length(Length)) :-
    (   sub_string(Line, 0, _, _, "Content-Length:")
    ;   sub_string(Line, 0, _, _, "content-length:")
    ),
    !,
    sub_string(Line, _, _, 0, Rest),
    sub_string(Rest, Start, _, 0, Value),
    sub_string(Rest, 0, Start, _, "Content-Length:"),
    string_codes(Value, Codes),
    exclude(is_space_code, Codes, NumCodes),
    number_codes(Length, NumCodes).

parse_header(Line, unknown_header(Line)).

is_space_code(32).   % space
is_space_code(9).    % tab
is_space_code(13).   % CR

%% write_jsonrpc_response(+Stream, +Response)
%%
%% Writes a JSON-RPC response with Content-Length header

write_jsonrpc_response(Stream, Response) :-
    atom_json_dict(JsonAtom, Response, []),
    atom_string(JsonAtom, JsonString),
    string_length(JsonString, Length),
    format(Stream, "Content-Length: ~d\r\n\r\n~s", [Length, JsonString]),
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
