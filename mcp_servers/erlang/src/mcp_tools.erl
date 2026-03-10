%%%-------------------------------------------------------------------
%%% @doc MCP Tools - Tool registry and execution
%%%
%%% Provides a registry for MCP tools and handles tool execution.
%%% Uses an ETS table for storing tool definitions.
%%%
%%% Copyright (C) 2024 ALGT Project
%%%-------------------------------------------------------------------
-module(mcp_tools).

-behaviour(gen_server).

%% API
-export([
    start_link/0,
    register_tool/4,
    list_tools/0,
    call_tool/2,
    format_result/1,
    format_error/1
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
-define(TOOLS_TABLE, mcp_tools_registry).

-record(state, {}).

%%%===================================================================
%%% API
%%%===================================================================

start_link() ->
    gen_server:start_link({local, ?SERVER}, ?MODULE, [], []).

%%%-------------------------------------------------------------------
%%% @doc Register a tool with the MCP server
%%% Handler is {Module, Function} that takes (Arguments) -> Result
%%%-------------------------------------------------------------------
-spec register_tool(binary(), binary(), map(), {module(), atom()}) -> ok.
register_tool(Name, Description, InputSchema, Handler) ->
    gen_server:call(?SERVER, {register, Name, Description, InputSchema, Handler}).

%%%-------------------------------------------------------------------
%%% @doc List all registered tools in MCP format
%%%-------------------------------------------------------------------
-spec list_tools() -> [map()].
list_tools() ->
    gen_server:call(?SERVER, list_tools).

%%%-------------------------------------------------------------------
%%% @doc Call a registered tool with arguments
%%%-------------------------------------------------------------------
-spec call_tool(binary(), map()) -> map().
call_tool(Name, Arguments) ->
    gen_server:call(?SERVER, {call_tool, Name, Arguments}, infinity).

%%%-------------------------------------------------------------------
%%% @doc Format a successful result in MCP format
%%%-------------------------------------------------------------------
-spec format_result(binary() | string()) -> map().
format_result(Text) when is_list(Text) ->
    format_result(list_to_binary(Text));
format_result(Text) when is_binary(Text) ->
    #{
        <<"content">> => [#{
            <<"type">> => <<"text">>,
            <<"text">> => Text
        }]
    }.

%%%-------------------------------------------------------------------
%%% @doc Format an error result in MCP format
%%%-------------------------------------------------------------------
-spec format_error(term()) -> map().
format_error(Error) ->
    ErrorBin = iolist_to_binary(io_lib:format("~p", [Error])),
    #{
        <<"isError">> => true,
        <<"content">> => [#{
            <<"type">> => <<"text">>,
            <<"text">> => ErrorBin
        }]
    }.

%%%===================================================================
%%% gen_server callbacks
%%%===================================================================

init([]) ->
    %% Create ETS table for tool storage
    ets:new(?TOOLS_TABLE, [named_table, set, protected]),
    {ok, #state{}}.

handle_call({register, Name, Description, InputSchema, Handler}, _From, State) ->
    Tool = #{
        name => Name,
        description => Description,
        input_schema => InputSchema,
        handler => Handler
    },
    ets:insert(?TOOLS_TABLE, {Name, Tool}),
    {reply, ok, State};

handle_call(list_tools, _From, State) ->
    Tools = ets:foldl(
        fun({_Name, Tool}, Acc) ->
            ToolDef = #{
                <<"name">> => maps:get(name, Tool),
                <<"description">> => maps:get(description, Tool),
                <<"inputSchema">> => maps:get(input_schema, Tool)
            },
            [ToolDef | Acc]
        end,
        [],
        ?TOOLS_TABLE
    ),
    {reply, Tools, State};

handle_call({call_tool, Name, Arguments}, _From, State) ->
    Result = case ets:lookup(?TOOLS_TABLE, Name) of
        [{_, Tool}] ->
            {Module, Function} = maps:get(handler, Tool),
            try
                Module:Function(Arguments)
            catch
                Class:Error:Stacktrace ->
                    log_error("Tool ~s error: ~p:~p~n~p",
                              [Name, Class, Error, Stacktrace]),
                    format_error({Class, Error})
            end;
        [] ->
            ErrorMsg = iolist_to_binary(
                io_lib:format("Tool not found: ~s", [Name])),
            format_error(ErrorMsg)
    end,
    {reply, Result, State};

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
%%% Internal functions
%%%===================================================================

log_error(Format, Args) ->
    Timestamp = calendar:system_time_to_rfc3339(
        erlang:system_time(second)),
    io:format(standard_error, "[~s] ERROR: " ++ Format ++ "~n",
              [Timestamp | Args]).
