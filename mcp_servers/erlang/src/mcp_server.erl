%%%-------------------------------------------------------------------
%%% @doc MCP Server - Main server implementation
%%%
%%% Model Context Protocol server for Erlang/OTP.
%%% Communicates via stdio using JSON-RPC 2.0.
%%%
%%% Copyright (C) 2024 ALGT Project
%%%
%%% Usage:
%%%   erl -pa _build/default/lib/*/ebin -s mcp_server start
%%%-------------------------------------------------------------------
-module(mcp_server).

-behaviour(gen_server).

%% API
-export([
    start/0,
    start_link/0,
    stop/0
]).

%% gen_server callbacks
-export([
    init/1,
    handle_call/3,
    handle_cast/2,
    handle_info/2,
    terminate/2,
    code_change/3
]).

-define(SERVER, ?MODULE).
-define(PROTOCOL_VERSION, <<"2024-11-05">>).
-define(SERVER_NAME, <<"algt-mcp-server-erlang">>).
-define(SERVER_VERSION, <<"0.1.0">>).

-record(state, {
    initialized = false :: boolean()
}).

%%%===================================================================
%%% API
%%%===================================================================

%%%-------------------------------------------------------------------
%%% @doc Start the MCP server (called from command line)
%%%-------------------------------------------------------------------
start() ->
    %% Start required applications
    application:ensure_all_started(jsx),

    %% Start the tools registry
    {ok, _} = mcp_tools:start_link(),

    %% Register ALGT tools
    mcp_algt_tools:register_all(),

    %% Start the server and enter message loop
    {ok, Pid} = start_link(),
    log_info("ALGT MCP Server (Erlang) starting..."),

    %% Enter the message loop
    message_loop(Pid),

    %% Halt when done
    init:stop().

%%%-------------------------------------------------------------------
%%% @doc Start the server as a gen_server
%%%-------------------------------------------------------------------
start_link() ->
    gen_server:start_link({local, ?SERVER}, ?MODULE, [], []).

%%%-------------------------------------------------------------------
%%% @doc Stop the server
%%%-------------------------------------------------------------------
stop() ->
    gen_server:stop(?SERVER).

%%%===================================================================
%%% gen_server callbacks
%%%===================================================================

init([]) ->
    {ok, #state{}}.

handle_call({handle_message, Message}, _From, State) ->
    {Response, NewState} = process_message(Message, State),
    {reply, Response, NewState};

handle_call(_Request, _From, State) ->
    {reply, {error, unknown_request}, State}.

handle_cast(_Msg, State) ->
    {noreply, State}.

handle_info(_Info, State) ->
    {noreply, State}.

terminate(_Reason, _State) ->
    ok.

code_change(_OldVsn, State, _Extra) ->
    {ok, State}.

%%%===================================================================
%%% Message Loop
%%%===================================================================

%%%-------------------------------------------------------------------
%%% @doc Main message processing loop
%%%-------------------------------------------------------------------
message_loop(Pid) ->
    case mcp_protocol:read_message() of
        eof ->
            log_info("End of input, shutting down"),
            ok;
        {error, Reason} ->
            log_error("Read error: ~p", [Reason]),
            ok;
        {ok, Message} ->
            case gen_server:call(Pid, {handle_message, Message}) of
                {response, Response} ->
                    mcp_protocol:write_response(Response);
                no_response ->
                    ok;
                shutdown ->
                    ok
            end,
            message_loop(Pid)
    end.

%%%===================================================================
%%% Message Processing
%%%===================================================================

%%%-------------------------------------------------------------------
%%% @doc Process a JSON-RPC message
%%%-------------------------------------------------------------------
-spec process_message(map(), #state{}) ->
    {{response, map()} | no_response | shutdown, #state{}}.
process_message(Message, State) ->
    Id = maps:get(<<"id">>, Message, null),
    Method = maps:get(<<"method">>, Message, <<>>),
    Params = maps:get(<<"params">>, Message, #{}),

    log_info("Received: ~s (id=~p)", [Method, Id]),

    case Method of
        <<"initialize">> ->
            handle_initialize(Id, Params, State);
        <<"initialized">> ->
            handle_initialized(State);
        <<"shutdown">> ->
            handle_shutdown(Id, State);
        <<"tools/list">> ->
            handle_tools_list(Id, State);
        <<"tools/call">> ->
            handle_tools_call(Id, Params, State);
        <<"ping">> ->
            handle_ping(Id, State);
        _ when Id =/= null ->
            %% Unknown method with id -> error response
            ErrorMsg = iolist_to_binary(
                io_lib:format("Unknown method: ~s", [Method])),
            Response = mcp_protocol:error_response(
                Id,
                mcp_protocol:method_not_found(),
                ErrorMsg
            ),
            {{response, Response}, State};
        _ ->
            %% Unknown notification -> ignore
            log_info("Ignoring unknown notification: ~s", [Method]),
            {no_response, State}
    end.

%%%-------------------------------------------------------------------
%%% @doc Handle initialize request
%%%-------------------------------------------------------------------
handle_initialize(Id, Params, State) ->
    %% Log client info if present
    case maps:get(<<"clientInfo">>, Params, undefined) of
        undefined -> ok;
        ClientInfo -> log_info("Client: ~p", [ClientInfo])
    end,

    Response = #{
        <<"jsonrpc">> => <<"2.0">>,
        <<"id">> => Id,
        <<"result">> => #{
            <<"protocolVersion">> => ?PROTOCOL_VERSION,
            <<"capabilities">> => #{
                <<"tools">> => #{
                    <<"listChanged">> => false
                }
            },
            <<"serverInfo">> => #{
                <<"name">> => ?SERVER_NAME,
                <<"version">> => ?SERVER_VERSION
            }
        }
    },
    {{response, Response}, State#state{initialized = true}}.

%%%-------------------------------------------------------------------
%%% @doc Handle initialized notification
%%%-------------------------------------------------------------------
handle_initialized(State) ->
    log_info("Client initialized successfully"),
    {no_response, State}.

%%%-------------------------------------------------------------------
%%% @doc Handle shutdown request
%%%-------------------------------------------------------------------
handle_shutdown(Id, State) ->
    log_info("Shutdown requested"),
    Response = #{
        <<"jsonrpc">> => <<"2.0">>,
        <<"id">> => Id,
        <<"result">> => null
    },
    {{response, Response}, State}.

%%%-------------------------------------------------------------------
%%% @doc Handle ping request
%%%-------------------------------------------------------------------
handle_ping(Id, State) ->
    Response = #{
        <<"jsonrpc">> => <<"2.0">>,
        <<"id">> => Id,
        <<"result">> => #{}
    },
    {{response, Response}, State}.

%%%-------------------------------------------------------------------
%%% @doc Handle tools/list request
%%%-------------------------------------------------------------------
handle_tools_list(Id, State) ->
    Tools = mcp_tools:list_tools(),
    Response = #{
        <<"jsonrpc">> => <<"2.0">>,
        <<"id">> => Id,
        <<"result">> => #{
            <<"tools">> => Tools
        }
    },
    {{response, Response}, State}.

%%%-------------------------------------------------------------------
%%% @doc Handle tools/call request
%%%-------------------------------------------------------------------
handle_tools_call(Id, Params, State) ->
    Response = case {maps:get(<<"name">>, Params, undefined),
                     maps:get(<<"arguments">>, Params, undefined)} of
        {undefined, _} ->
            mcp_protocol:error_response(
                Id,
                mcp_protocol:invalid_params(),
                <<"Missing required parameter: name">>
            );
        {_, undefined} ->
            mcp_protocol:error_response(
                Id,
                mcp_protocol:invalid_params(),
                <<"Missing required parameter: arguments">>
            );
        {ToolName, Arguments} ->
            log_info("Calling tool: ~s", [ToolName]),
            ToolResult = mcp_tools:call_tool(ToolName, Arguments),
            #{
                <<"jsonrpc">> => <<"2.0">>,
                <<"id">> => Id,
                <<"result">> => ToolResult
            }
    end,
    {{response, Response}, State}.

%%%===================================================================
%%% Logging
%%%===================================================================

log_info(Format, Args) ->
    Timestamp = calendar:system_time_to_rfc3339(
        erlang:system_time(second)),
    io:format(standard_error, "[~s] INFO: " ++ Format ++ "~n",
              [Timestamp | Args]).

log_info(Message) ->
    log_info("~s", [Message]).

log_error(Format, Args) ->
    Timestamp = calendar:system_time_to_rfc3339(
        erlang:system_time(second)),
    io:format(standard_error, "[~s] ERROR: " ++ Format ++ "~n",
              [Timestamp | Args]).
