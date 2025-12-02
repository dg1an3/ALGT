%%%-------------------------------------------------------------------
%%% @doc MCP Protocol - JSON-RPC 2.0 handling for MCP server
%%%
%%% Handles reading/writing JSON-RPC messages over stdio with
%%% Content-Length framing as required by MCP.
%%%
%%% Copyright (C) 2024 ALGT Project
%%%-------------------------------------------------------------------
-module(mcp_protocol).

-export([
    read_message/0,
    write_response/1,
    write_error/3,
    write_notification/2,
    error_response/3
]).

%% JSON-RPC 2.0 Error Codes
-define(PARSE_ERROR, -32700).
-define(INVALID_REQUEST, -32600).
-define(METHOD_NOT_FOUND, -32601).
-define(INVALID_PARAMS, -32602).
-define(INTERNAL_ERROR, -32603).

-export([
    parse_error/0,
    invalid_request/0,
    method_not_found/0,
    invalid_params/0,
    internal_error/0
]).

parse_error() -> ?PARSE_ERROR.
invalid_request() -> ?INVALID_REQUEST.
method_not_found() -> ?METHOD_NOT_FOUND.
invalid_params() -> ?INVALID_PARAMS.
internal_error() -> ?INTERNAL_ERROR.

%%%-------------------------------------------------------------------
%%% @doc Read a JSON-RPC message from stdin
%%% Messages are framed with Content-Length headers
%%%-------------------------------------------------------------------
-spec read_message() -> {ok, map()} | {error, term()} | eof.
read_message() ->
    case read_headers() of
        eof ->
            eof;
        {error, Reason} ->
            {error, Reason};
        Headers ->
            case proplists:get_value(content_length, Headers) of
                undefined ->
                    {error, missing_content_length};
                Length ->
                    case io:get_chars(standard_io, "", Length) of
                        eof ->
                            eof;
                        {error, Reason} ->
                            {error, Reason};
                        Data ->
                            try
                                Json = jsx:decode(iolist_to_binary(Data), [return_maps]),
                                {ok, Json}
                            catch
                                _:Error ->
                                    {error, {json_parse_error, Error}}
                            end
                    end
            end
    end.

%%%-------------------------------------------------------------------
%%% @doc Read HTTP-style headers until empty line
%%%-------------------------------------------------------------------
-spec read_headers() -> [{atom(), term()}] | eof | {error, term()}.
read_headers() ->
    read_headers([]).

read_headers(Acc) ->
    case io:get_line(standard_io, "") of
        eof ->
            eof;
        {error, Reason} ->
            {error, Reason};
        Line ->
            Trimmed = string:trim(Line, both),
            case Trimmed of
                "" ->
                    Acc;
                _ ->
                    case parse_header(Trimmed) of
                        {ok, Header} ->
                            read_headers([Header | Acc]);
                        ignore ->
                            read_headers(Acc)
                    end
            end
    end.

%%%-------------------------------------------------------------------
%%% @doc Parse a single header line
%%%-------------------------------------------------------------------
-spec parse_header(string()) -> {ok, {atom(), term()}} | ignore.
parse_header(Line) ->
    case string:split(string:lowercase(Line), ":") of
        ["content-length", Value] ->
            try
                Length = list_to_integer(string:trim(Value)),
                {ok, {content_length, Length}}
            catch
                _:_ -> ignore
            end;
        _ ->
            ignore
    end.

%%%-------------------------------------------------------------------
%%% @doc Write a JSON-RPC response to stdout
%%%-------------------------------------------------------------------
-spec write_response(map()) -> ok.
write_response(Response) ->
    JsonBin = jsx:encode(Response),
    Length = byte_size(JsonBin),
    io:format(standard_io, "Content-Length: ~B\r\n\r\n~s", [Length, JsonBin]),
    ok.

%%%-------------------------------------------------------------------
%%% @doc Write a JSON-RPC error response
%%%-------------------------------------------------------------------
-spec write_error(term(), integer(), binary()) -> ok.
write_error(Id, Code, Message) ->
    Response = #{
        <<"jsonrpc">> => <<"2.0">>,
        <<"id">> => Id,
        <<"error">> => #{
            <<"code">> => Code,
            <<"message">> => Message
        }
    },
    write_response(Response).

%%%-------------------------------------------------------------------
%%% @doc Write a JSON-RPC notification
%%%-------------------------------------------------------------------
-spec write_notification(binary(), map()) -> ok.
write_notification(Method, Params) ->
    Notification = #{
        <<"jsonrpc">> => <<"2.0">>,
        <<"method">> => Method,
        <<"params">> => Params
    },
    write_response(Notification).

%%%-------------------------------------------------------------------
%%% @doc Create an error response map
%%%-------------------------------------------------------------------
-spec error_response(term(), integer(), binary()) -> map().
error_response(Id, Code, Message) ->
    #{
        <<"jsonrpc">> => <<"2.0">>,
        <<"id">> => Id,
        <<"error">> => #{
            <<"code">> => Code,
            <<"message">> => Message
        }
    }.
