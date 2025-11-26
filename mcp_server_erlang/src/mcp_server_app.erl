%%%-------------------------------------------------------------------
%%% @doc MCP Server Application
%%%
%%% OTP Application behaviour for the MCP server.
%%%
%%% Copyright (C) 2024 ALGT Project
%%%-------------------------------------------------------------------
-module(mcp_server_app).

-behaviour(application).

-export([start/2, stop/1]).

start(_StartType, _StartArgs) ->
    mcp_server_sup:start_link().

stop(_State) ->
    ok.
