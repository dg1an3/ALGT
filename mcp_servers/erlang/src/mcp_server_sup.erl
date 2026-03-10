%%%-------------------------------------------------------------------
%%% @doc MCP Server Supervisor
%%%
%%% Top-level supervisor for the MCP server application.
%%%
%%% Copyright (C) 2024 ALGT Project
%%%-------------------------------------------------------------------
-module(mcp_server_sup).

-behaviour(supervisor).

-export([start_link/0]).
-export([init/1]).

-define(SERVER, ?MODULE).

start_link() ->
    supervisor:start_link({local, ?SERVER}, ?MODULE, []).

init([]) ->
    SupFlags = #{
        strategy => one_for_one,
        intensity => 1,
        period => 5
    },

    ChildSpecs = [
        #{
            id => mcp_tools,
            start => {mcp_tools, start_link, []},
            restart => permanent,
            shutdown => 5000,
            type => worker,
            modules => [mcp_tools]
        }
    ],

    {ok, {SupFlags, ChildSpecs}}.
