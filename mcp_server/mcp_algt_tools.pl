%% mcp_algt_tools.pl
%%
%% ALGT-specific tool implementations for MCP server
%%
%% Copyright (C) 2024 ALGT Project

:- module(mcp_algt_tools, [
    register_algt_tools/0
]).

:- use_module(mcp_tools).
:- use_module(library(http/json)).

%% register_algt_tools/0
%%
%% Registers all ALGT-specific tools with the MCP server

register_algt_tools :-
    register_prolog_query_tool,
    register_consult_file_tool,
    register_list_predicates_tool,
    register_model_checker_tool,
    register_analyze_pathways_tool.

%% ============================================================
%% Tool: prolog_query
%% Execute arbitrary Prolog queries
%% ============================================================

register_prolog_query_tool :-
    register_tool(
        "prolog_query",
        "Execute a Prolog query and return all solutions. The query should be valid Prolog syntax.",
        _{
            type: "object",
            properties: _{
                query: _{
                    type: "string",
                    description: "The Prolog query to execute (e.g., 'member(X, [1,2,3])')"
                },
                max_solutions: _{
                    type: "integer",
                    description: "Maximum number of solutions to return (default: 10)"
                }
            },
            required: ["query"]
        },
        mcp_algt_tools:handle_prolog_query
    ).

handle_prolog_query(Args, Result) :-
    get_dict(query, Args, QueryStr),
    (   get_dict(max_solutions, Args, MaxSolutions)
    ->  true
    ;   MaxSolutions = 10
    ),
    catch(
        (   term_string(Query, QueryStr),
            findnsols(MaxSolutions, Query, Query, Solutions),
            format_solutions(Solutions, ResultText),
            Result = _{
                content: [_{
                    type: "text",
                    text: ResultText
                }]
            }
        ),
        Error,
        (   format(atom(ErrorMsg), "Query error: ~w", [Error]),
            Result = _{
                isError: true,
                content: [_{
                    type: "text",
                    text: ErrorMsg
                }]
            }
        )
    ).

format_solutions([], "No solutions found.").
format_solutions(Solutions, ResultText) :-
    Solutions \= [],
    length(Solutions, Count),
    format(atom(Header), "Found ~d solution(s):\n", [Count]),
    maplist(format_solution, Solutions, SolutionStrs),
    atomics_to_string([Header | SolutionStrs], "\n", ResultText).

format_solution(Solution, SolutionStr) :-
    format(atom(SolutionStr), "  ~w", [Solution]).

%% ============================================================
%% Tool: consult_file
%% Load a Prolog file
%% ============================================================

register_consult_file_tool :-
    register_tool(
        "consult_file",
        "Load/consult a Prolog file into the current session.",
        _{
            type: "object",
            properties: _{
                file_path: _{
                    type: "string",
                    description: "Path to the Prolog file to load"
                }
            },
            required: ["file_path"]
        },
        mcp_algt_tools:handle_consult_file
    ).

handle_consult_file(Args, Result) :-
    get_dict(file_path, Args, FilePath),
    catch(
        (   consult(FilePath),
            format(atom(SuccessMsg), "Successfully loaded: ~w", [FilePath]),
            Result = _{
                content: [_{
                    type: "text",
                    text: SuccessMsg
                }]
            }
        ),
        Error,
        (   format(atom(ErrorMsg), "Failed to load file: ~w", [Error]),
            Result = _{
                isError: true,
                content: [_{
                    type: "text",
                    text: ErrorMsg
                }]
            }
        )
    ).

%% ============================================================
%% Tool: list_predicates
%% List predicates in a module
%% ============================================================

register_list_predicates_tool :-
    register_tool(
        "list_predicates",
        "List all predicates defined in a module or the current context.",
        _{
            type: "object",
            properties: _{
                module: _{
                    type: "string",
                    description: "Module name to list predicates from (optional, defaults to 'user')"
                }
            }
        },
        mcp_algt_tools:handle_list_predicates
    ).

handle_list_predicates(Args, Result) :-
    (   get_dict(module, Args, ModuleName),
        ModuleName \= ""
    ->  atom_string(Module, ModuleName)
    ;   Module = user
    ),
    catch(
        (   findall(Name/Arity,
                (   current_predicate(Module:Name/Arity),
                    \+ sub_atom(Name, 0, 1, _, '$')  % Skip internal predicates
                ),
                Predicates),
            sort(Predicates, SortedPreds),
            format_predicates(Module, SortedPreds, ResultText),
            Result = _{
                content: [_{
                    type: "text",
                    text: ResultText
                }]
            }
        ),
        Error,
        (   format(atom(ErrorMsg), "Error listing predicates: ~w", [Error]),
            Result = _{
                isError: true,
                content: [_{
                    type: "text",
                    text: ErrorMsg
                }]
            }
        )
    ).

format_predicates(Module, [], ResultText) :-
    format(atom(ResultText), "No predicates found in module '~w'", [Module]).
format_predicates(Module, Predicates, ResultText) :-
    Predicates \= [],
    length(Predicates, Count),
    format(atom(Header), "Predicates in module '~w' (~d total):\n", [Module, Count]),
    maplist(format_predicate, Predicates, PredStrs),
    atomics_to_string([Header | PredStrs], "\n", ResultText).

format_predicate(Name/Arity, PredStr) :-
    format(atom(PredStr), "  ~w/~d", [Name, Arity]).

%% ============================================================
%% Tool: model_checker_validate
%% Validate a concurrent operation model
%% ============================================================

register_model_checker_tool :-
    register_tool(
        "model_checker_validate",
        "Validate a concurrent operation model structure (sequence or fork).",
        _{
            type: "object",
            properties: _{
                model: _{
                    type: "string",
                    description: "The model to validate as a Prolog term (e.g., 'fork([sequence([...]), sequence([...])])')"
                }
            },
            required: ["model"]
        },
        mcp_algt_tools:handle_model_checker_validate
    ).

handle_model_checker_validate(Args, Result) :-
    get_dict(model, Args, ModelStr),
    catch(
        (   term_string(Model, ModelStr),
            (   model_checker:valid(Model)
            ->  ResultText = "Model is valid."
            ;   ResultText = "Model is NOT valid."
            ),
            Result = _{
                content: [_{
                    type: "text",
                    text: ResultText
                }]
            }
        ),
        Error,
        (   format(atom(ErrorMsg), "Validation error: ~w", [Error]),
            Result = _{
                isError: true,
                content: [_{
                    type: "text",
                    text: ErrorMsg
                }]
            }
        )
    ).

%% ============================================================
%% Tool: analyze_pathways
%% Analyze concurrent operation pathways
%% ============================================================

register_analyze_pathways_tool :-
    register_tool(
        "analyze_pathways",
        "Analyze all possible execution pathways of a concurrent model and identify state variations.",
        _{
            type: "object",
            properties: _{
                model: _{
                    type: "string",
                    description: "The concurrent model as a Prolog term"
                },
                initial_state: _{
                    type: "string",
                    description: "Initial resource state as a Prolog dict (e.g., 'dict{a: 1, b: 2}')"
                }
            },
            required: ["model", "initial_state"]
        },
        mcp_algt_tools:handle_analyze_pathways
    ).

handle_analyze_pathways(Args, Result) :-
    get_dict(model, Args, ModelStr),
    get_dict(initial_state, Args, StateStr),
    catch(
        (   term_string(Model, ModelStr),
            term_string(InitialState, StateStr),
            findall(
                variation(FinalState, Sequences),
                model_checker:analyze_pathways(Model, InitialState -> FinalState, Sequences),
                Variations
            ),
            format_variations(Variations, ResultText),
            Result = _{
                content: [_{
                    type: "text",
                    text: ResultText
                }]
            }
        ),
        Error,
        (   format(atom(ErrorMsg), "Analysis error: ~w", [Error]),
            Result = _{
                isError: true,
                content: [_{
                    type: "text",
                    text: ErrorMsg
                }]
            }
        )
    ).

format_variations([], "No variations found (empty model or no valid pathways).").
format_variations(Variations, ResultText) :-
    Variations \= [],
    length(Variations, Count),
    format(atom(Header), "Found ~d distinct state variation(s):\n", [Count]),
    maplist(format_variation, Variations, VarStrs),
    atomics_to_string([Header | VarStrs], "\n\n", ResultText).

format_variation(variation(FinalState, Sequences), VarStr) :-
    length(Sequences, SeqCount),
    format(atom(VarStr),
           "Final State: ~w\n  (~d pathway(s) lead to this state)",
           [FinalState, SeqCount]).
