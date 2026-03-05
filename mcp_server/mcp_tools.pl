%% mcp_tools.pl
%%
%% Tool registry and base tool definitions for MCP server
%%
%% Copyright (C) 2024 ALGT Project

:- module(mcp_tools, [
    register_tool/4,
    list_tools/1,
    call_tool/3,
    tool_schema/2
]).

:- use_module(library(http/json)).

%% Dynamic predicate to store registered tools
:- dynamic registered_tool/4.

%% register_tool(+Name, +Description, +InputSchema, +Handler)
%%
%% Registers a tool with the MCP server
%% Handler is a predicate of the form handler(+Arguments, -Result)

register_tool(Name, Description, InputSchema, Handler) :-
    (   registered_tool(Name, _, _, _)
    ->  retract(registered_tool(Name, _, _, _))
    ;   true
    ),
    assertz(registered_tool(Name, Description, InputSchema, Handler)).

%% list_tools(-ToolList)
%%
%% Returns a list of all registered tools in MCP format

list_tools(ToolList) :-
    findall(Tool,
        (   registered_tool(Name, Description, InputSchema, _),
            Tool = _{
                name: Name,
                description: Description,
                inputSchema: InputSchema
            }
        ),
        ToolList).

%% call_tool(+Name, +Arguments, -Result)
%%
%% Calls a registered tool with the given arguments

call_tool(Name, Arguments, Result) :-
    (   registered_tool(Name, _, _, Handler)
    ->  catch(
            call(Handler, Arguments, Result),
            Error,
            Result = _{
                isError: true,
                content: [_{
                    type: "text",
                    text: Error
                }]
            }
        )
    ;   format(atom(ErrorMsg), "Tool not found: ~w", [Name]),
        Result = _{
            isError: true,
            content: [_{
                type: "text",
                text: ErrorMsg
            }]
        }
    ).

%% tool_schema(+Type, -Schema)
%%
%% Helper to create JSON Schema definitions

tool_schema(string, _{type: "string"}).
tool_schema(number, _{type: "number"}).
tool_schema(integer, _{type: "integer"}).
tool_schema(boolean, _{type: "boolean"}).
tool_schema(array(ItemType), _{type: "array", items: ItemSchema}) :-
    tool_schema(ItemType, ItemSchema).
tool_schema(object(Properties), _{type: "object", properties: PropsDict}) :-
    maplist(property_to_schema, Properties, PropPairs),
    dict_pairs(PropsDict, _, PropPairs).

property_to_schema(Name-Type, Name-Schema) :-
    tool_schema(Type, Schema).

%% format_tool_result(+Text, -Result)
%%
%% Helper to format a text result in MCP format

format_tool_result(Text, Result) :-
    (   is_list(Text)
    ->  atomics_to_string(Text, "\n", TextStr)
    ;   TextStr = Text
    ),
    Result = _{
        content: [_{
            type: "text",
            text: TextStr
        }]
    }.

%% format_tool_error(+Error, -Result)
%%
%% Helper to format an error result in MCP format

format_tool_error(Error, Result) :-
    format(atom(ErrorStr), "~w", [Error]),
    Result = _{
        isError: true,
        content: [_{
            type: "text",
            text: ErrorStr
        }]
    }.
