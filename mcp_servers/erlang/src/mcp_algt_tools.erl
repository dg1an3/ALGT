%%%-------------------------------------------------------------------
%%% @doc MCP ALGT Tools - Domain-specific tool implementations
%%%
%%% Provides ALGT-specific tools for the MCP server, including
%%% Erlang shell evaluation and system information tools.
%%%
%%% Copyright (C) 2024 ALGT Project
%%%-------------------------------------------------------------------
-module(mcp_algt_tools).

-export([
    register_all/0,
    handle_eval/1,
    handle_module_info/1,
    handle_process_list/1,
    handle_system_info/1,
    handle_apply_function/1
]).

%%%===================================================================
%%% Tool Registration
%%%===================================================================

%%%-------------------------------------------------------------------
%%% @doc Register all ALGT tools with the MCP server
%%%-------------------------------------------------------------------
-spec register_all() -> ok.
register_all() ->
    register_eval_tool(),
    register_module_info_tool(),
    register_process_list_tool(),
    register_system_info_tool(),
    register_apply_function_tool(),
    ok.

%%%===================================================================
%%% Tool: erlang_eval
%%% Evaluate Erlang expressions
%%%===================================================================

register_eval_tool() ->
    mcp_tools:register_tool(
        <<"erlang_eval">>,
        <<"Evaluate an Erlang expression and return the result. "
          "Use for testing expressions, calculations, and exploring the runtime.">>,
        #{
            <<"type">> => <<"object">>,
            <<"properties">> => #{
                <<"expression">> => #{
                    <<"type">> => <<"string">>,
                    <<"description">> => <<"The Erlang expression to evaluate "
                                           "(e.g., 'lists:seq(1, 10).')">>
                }
            },
            <<"required">> => [<<"expression">>]
        },
        {?MODULE, handle_eval}
    ).

-spec handle_eval(map()) -> map().
handle_eval(Args) ->
    Expression = maps:get(<<"expression">>, Args, <<>>),
    ExprStr = binary_to_list(Expression),
    try
        {ok, Tokens, _} = erl_scan:string(ExprStr),
        {ok, Parsed} = erl_parse:parse_exprs(Tokens),
        {value, Result, _Bindings} = erl_eval:exprs(Parsed, []),
        ResultStr = io_lib:format("~p", [Result]),
        mcp_tools:format_result(iolist_to_binary(ResultStr))
    catch
        Class:Error ->
            ErrorMsg = io_lib:format("Evaluation error (~p): ~p",
                                     [Class, Error]),
            mcp_tools:format_error(iolist_to_binary(ErrorMsg))
    end.

%%%===================================================================
%%% Tool: module_info
%%% Get information about loaded modules
%%%===================================================================

register_module_info_tool() ->
    mcp_tools:register_tool(
        <<"module_info">>,
        <<"Get information about a loaded Erlang module, "
          "including exported functions.">>,
        #{
            <<"type">> => <<"object">>,
            <<"properties">> => #{
                <<"module">> => #{
                    <<"type">> => <<"string">>,
                    <<"description">> => <<"Module name (e.g., 'lists', 'maps')">>
                }
            },
            <<"required">> => [<<"module">>]
        },
        {?MODULE, handle_module_info}
    ).

-spec handle_module_info(map()) -> map().
handle_module_info(Args) ->
    ModuleName = maps:get(<<"module">>, Args, <<>>),
    try
        Module = list_to_existing_atom(binary_to_list(ModuleName)),
        Exports = Module:module_info(exports),

        %% Format exports as Name/Arity
        ExportStrs = [io_lib:format("  ~p/~p", [Name, Arity])
                      || {Name, Arity} <- lists:sort(Exports),
                         Name =/= module_info],

        Header = io_lib:format("Module: ~s~nExported functions (~p):~n",
                               [ModuleName, length(ExportStrs)]),
        Result = iolist_to_binary([Header | lists:join("\n", ExportStrs)]),
        mcp_tools:format_result(Result)
    catch
        _:_ ->
            ErrorMsg = io_lib:format("Module not found or not loaded: ~s",
                                     [ModuleName]),
            mcp_tools:format_error(iolist_to_binary(ErrorMsg))
    end.

%%%===================================================================
%%% Tool: process_list
%%% List running processes
%%%===================================================================

register_process_list_tool() ->
    mcp_tools:register_tool(
        <<"process_list">>,
        <<"List running Erlang processes with their registered names "
          "and current function.">>,
        #{
            <<"type">> => <<"object">>,
            <<"properties">> => #{
                <<"limit">> => #{
                    <<"type">> => <<"integer">>,
                    <<"description">> => <<"Maximum processes to list (default: 20)">>
                }
            }
        },
        {?MODULE, handle_process_list}
    ).

-spec handle_process_list(map()) -> map().
handle_process_list(Args) ->
    Limit = maps:get(<<"limit">>, Args, 20),
    Processes = erlang:processes(),
    Limited = lists:sublist(Processes, Limit),

    ProcessInfos = lists:map(
        fun(Pid) ->
            Info = erlang:process_info(Pid, [registered_name, current_function]),
            Name = case proplists:get_value(registered_name, Info) of
                [] -> io_lib:format("~p", [Pid]);
                RegName -> atom_to_list(RegName)
            end,
            {M, F, A} = proplists:get_value(current_function, Info, {unknown, unknown, 0}),
            io_lib:format("  ~s: ~p:~p/~p", [Name, M, F, A])
        end,
        Limited
    ),

    Header = io_lib:format("Processes (~p of ~p):~n",
                           [length(Limited), length(Processes)]),
    Result = iolist_to_binary([Header | lists:join("\n", ProcessInfos)]),
    mcp_tools:format_result(Result).

%%%===================================================================
%%% Tool: system_info
%%% Get Erlang system information
%%%===================================================================

register_system_info_tool() ->
    mcp_tools:register_tool(
        <<"system_info">>,
        <<"Get Erlang/OTP system information including version, "
          "schedulers, and memory usage.">>,
        #{
            <<"type">> => <<"object">>,
            <<"properties">> => #{}
        },
        {?MODULE, handle_system_info}
    ).

-spec handle_system_info(map()) -> map().
handle_system_info(_Args) ->
    Info = [
        io_lib:format("OTP Release: ~s", [erlang:system_info(otp_release)]),
        io_lib:format("ERTS Version: ~s", [erlang:system_info(version)]),
        io_lib:format("Schedulers: ~p (online: ~p)", [
            erlang:system_info(schedulers),
            erlang:system_info(schedulers_online)
        ]),
        io_lib:format("Process Count: ~p", [erlang:system_info(process_count)]),
        io_lib:format("Process Limit: ~p", [erlang:system_info(process_limit)]),
        io_lib:format("Atom Count: ~p", [erlang:system_info(atom_count)]),
        io_lib:format("Memory (total): ~p bytes", [erlang:memory(total)]),
        io_lib:format("Memory (processes): ~p bytes", [erlang:memory(processes)]),
        io_lib:format("Memory (system): ~p bytes", [erlang:memory(system)])
    ],
    Result = iolist_to_binary(lists:join("\n", Info)),
    mcp_tools:format_result(Result).

%%%===================================================================
%%% Tool: apply_function
%%% Apply a function from a module with arguments
%%%===================================================================

register_apply_function_tool() ->
    mcp_tools:register_tool(
        <<"apply_function">>,
        <<"Apply a function from a module with given arguments. "
          "Arguments should be valid Erlang terms.">>,
        #{
            <<"type">> => <<"object">>,
            <<"properties">> => #{
                <<"module">> => #{
                    <<"type">> => <<"string">>,
                    <<"description">> => <<"Module name">>
                },
                <<"function">> => #{
                    <<"type">> => <<"string">>,
                    <<"description">> => <<"Function name">>
                },
                <<"args">> => #{
                    <<"type">> => <<"string">>,
                    <<"description">> => <<"Arguments as Erlang list (e.g., '[1, 2, 3]')">>
                }
            },
            <<"required">> => [<<"module">>, <<"function">>, <<"args">>]
        },
        {?MODULE, handle_apply_function}
    ).

-spec handle_apply_function(map()) -> map().
handle_apply_function(Args) ->
    ModuleBin = maps:get(<<"module">>, Args),
    FunctionBin = maps:get(<<"function">>, Args),
    ArgsBin = maps:get(<<"args">>, Args),
    try
        Module = list_to_existing_atom(binary_to_list(ModuleBin)),
        Function = list_to_existing_atom(binary_to_list(FunctionBin)),

        %% Parse the arguments string as an Erlang term
        ArgsStr = binary_to_list(ArgsBin) ++ ".",
        {ok, Tokens, _} = erl_scan:string(ArgsStr),
        {ok, ArgsList} = erl_parse:parse_term(Tokens),

        %% Apply the function
        Result = apply(Module, Function, ArgsList),
        ResultStr = io_lib:format("~p", [Result]),
        mcp_tools:format_result(iolist_to_binary(ResultStr))
    catch
        Class:Error ->
            ErrorMsg = io_lib:format("Apply error (~p): ~p", [Class, Error]),
            mcp_tools:format_error(iolist_to_binary(ErrorMsg))
    end.
