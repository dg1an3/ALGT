%============================================================
% execution_tracer.pl - Execution Trace Capture for Clarion Interpreter
%
% Captures detailed execution traces including:
%   - Statement executions
%   - Branch decisions (IF/CASE/LOOP conditions)
%   - Variable assignments
%   - Procedure/method calls
%   - File/database operations
%
% Usage:
%   ?- start_trace.
%   ?- run_file('example.clw').
%   ?- stop_trace(Trace).
%   ?- get_execution_path(Path).
%============================================================

:- module(execution_tracer, [
    % Trace control
    start_trace/0,
    start_trace/1,          % start_trace(+Options)
    stop_trace/1,           % stop_trace(-Trace)
    is_tracing/0,
    clear_trace/0,

    % Event recording
    trace_event/1,          % trace_event(+Event)
    trace_event/2,          % trace_event(+EventType, +Data)

    % Trace retrieval
    get_trace/1,            % get_trace(-Trace)
    get_execution_path/1,   % get_execution_path(-Path)
    get_branch_decisions/1, % get_branch_decisions(-Decisions)
    get_variable_history/2, % get_variable_history(+VarName, -History)
    get_call_stack/1,       % get_call_stack(-Stack)

    % Trace analysis
    trace_summary/1,        % trace_summary(-Summary)
    path_to_dot/2,          % path_to_dot(+Trace, -DotString)

    % Execution Graph (PyTorch-style DAG)
    get_execution_graph/1,  % get_execution_graph(-Graph)
    graph_to_dot/2,         % graph_to_dot(+Graph, -DotString)
    graph_to_json/2,        % graph_to_json(+Graph, -JsonString)
    get_data_flow/1,        % get_data_flow(-DataFlow) - variable dependencies
    get_control_flow/1,     % get_control_flow(-ControlFlow) - statement sequence

    % Graph node operations
    add_graph_node/3,       % add_graph_node(+Type, +Data, -NodeId)
    add_graph_edge/3,       % add_graph_edge(+FromId, +ToId, +EdgeType)
    current_node_id/1,      % current_node_id(-Id)
    set_current_node/1,     % set_current_node(+Id)

    % Data dependency tracking
    record_var_write/2,     % record_var_write(+VarName, +NodeId)
    record_var_read/2,      % record_var_read(+VarName, +NodeId)

    % High-level graph construction helpers
    graph_node_for_statement/3,   % graph_node_for_statement(+Type, +Data, -NodeId)
    graph_node_for_branch/3,      % graph_node_for_branch(+Cond, +Value, -NodeId)
    graph_node_for_assignment/4,  % graph_node_for_assignment(+Var, +Val, +Expr, -NodeId)

    % Convenience trace recording predicates
    trace_statement_start/2,
    trace_statement_end/2,
    trace_branch/4,
    trace_var_assign/3,
    trace_var_read/2,
    trace_proc_enter/2,
    trace_proc_exit/2,
    trace_method_enter/3,
    trace_method_exit/3,
    trace_loop_start/2,
    trace_loop_iteration/3,
    trace_loop_end/2,
    trace_case_match/3,
    trace_file_op/4,
    trace_error/1,

    % ML-friendly exports
    graph_to_adjacency/3,     % graph_to_adjacency(+Graph, -AdjList, -NodeTypes)
    graph_to_edge_index/3,    % graph_to_edge_index(+Graph, -EdgeIndex, -EdgeTypes) - PyTorch Geometric format
    graph_to_numpy_json/2,    % graph_to_numpy_json(+Graph, -JsonString) - NumPy/PyTorch friendly
    node_type_encoding/3,     % node_type_encoding(+Nodes, -TypeIds, -TypeMapping)

    % Probabilistic graphical model
    graph_to_pgm/2,           % graph_to_pgm(+Graph, -PGM) - Convert to Bayesian network structure
    path_probability/3,       % path_probability(+Graph, +Path, -Prob)
    sample_path/4             % sample_path(+Graph, +InputDist, -Path, -Prob)
]).

:- use_module(library(assoc)).

%------------------------------------------------------------
% Global State (using global variables for trace storage)
%------------------------------------------------------------

% Trace state stored in global variables:
%   trace_enabled    - true/false
%   trace_events     - list of trace events (newest first)
%   trace_options    - configuration options
%   trace_call_stack - current call stack
%   trace_start_time - when tracing started

:- dynamic trace_enabled/1.
:- dynamic trace_event_store/1.
:- dynamic trace_options_store/1.
:- dynamic trace_call_stack_store/1.
:- dynamic trace_start_time/1.
:- dynamic trace_event_counter/1.

% Execution graph state
:- dynamic graph_node/3.           % graph_node(Id, Type, Data)
:- dynamic graph_edge/3.           % graph_edge(FromId, ToId, EdgeType)
:- dynamic graph_node_counter/1.   % Counter for generating node IDs
:- dynamic current_graph_node/1.   % Currently active node (for control flow edges)
:- dynamic var_last_write/2.       % var_last_write(VarName, NodeId) - tracks last write to each variable

%------------------------------------------------------------
% Trace Event Structure
%------------------------------------------------------------
% Events are represented as:
%   event(Id, Timestamp, Type, Data)
%
% Event types:
%   statement_start(StmtType, StmtAST)
%   statement_end(StmtType, Control)
%   branch_decision(Context, Condition, Value, BranchTaken)
%   var_assign(VarName, OldValue, NewValue)
%   var_read(VarName, Value)
%   proc_enter(Name, Args)
%   proc_exit(Name, Result)
%   method_enter(Object, Method, Args)
%   method_exit(Object, Method, Result)
%   loop_iteration(LoopType, Iteration, CondValue)
%   file_op(Operation, FileName, Key, Result)
%   error(Message)

%------------------------------------------------------------
% Trace Control
%------------------------------------------------------------

%% start_trace is det.
%% start_trace(+Options) is det.
%
% Start capturing execution trace.
% Options is a dict with optional keys:
%   - capture_vars: true/false (default: true) - capture variable assignments
%   - capture_reads: true/false (default: false) - capture variable reads
%   - capture_statements: true/false (default: true) - capture statement execution
%   - capture_branches: true/false (default: true) - capture branch decisions
%   - capture_calls: true/false (default: true) - capture procedure calls
%   - capture_file_ops: true/false (default: true) - capture file operations
%   - max_events: integer (default: 100000) - maximum events to capture

start_trace :-
    start_trace(trace_options{
        capture_vars: true,
        capture_reads: false,
        capture_statements: true,
        capture_branches: true,
        capture_calls: true,
        capture_file_ops: true,
        max_events: 100000
    }).

start_trace(Options) :-
    clear_trace,
    get_time(StartTime),
    assertz(trace_enabled(true)),
    assertz(trace_options_store(Options)),
    assertz(trace_start_time(StartTime)),
    assertz(trace_call_stack_store([])),
    assertz(trace_event_counter(0)),
    % Initialize graph
    assertz(graph_node_counter(0)),
    % Create root node
    add_graph_node(root, root{}, RootId),
    set_current_node(RootId).

%% stop_trace(-Trace) is det.
%
% Stop tracing and return the collected trace.
% Trace is a dict containing:
%   - events: list of events in chronological order
%   - duration: elapsed time in seconds
%   - summary: quick statistics

stop_trace(Trace) :-
    ( trace_start_time(StartTime)
    -> get_time(EndTime),
       Duration is EndTime - StartTime
    ;  Duration = 0
    ),
    get_trace(Events),
    trace_summary(Summary),
    Trace = trace{
        events: Events,
        duration: Duration,
        summary: Summary
    },
    clear_trace.

%% is_tracing is semidet.
%
% Succeeds if tracing is currently enabled.

is_tracing :-
    trace_enabled(true).

%% clear_trace is det.
%
% Clear all trace state.

clear_trace :-
    retractall(trace_enabled(_)),
    retractall(trace_event_store(_)),
    retractall(trace_options_store(_)),
    retractall(trace_call_stack_store(_)),
    retractall(trace_start_time(_)),
    retractall(trace_event_counter(_)),
    % Clear graph state
    retractall(graph_node(_, _, _)),
    retractall(graph_edge(_, _, _)),
    retractall(graph_node_counter(_)),
    retractall(current_graph_node(_)),
    retractall(var_last_write(_, _)).

%------------------------------------------------------------
% Event Recording
%------------------------------------------------------------

%% trace_event(+Event) is det.
%
% Record a trace event if tracing is enabled.

trace_event(Event) :-
    ( is_tracing
    -> record_event(Event)
    ;  true
    ).

%% trace_event(+EventType, +Data) is det.
%
% Record a typed trace event.

trace_event(EventType, Data) :-
    trace_event(event_data(EventType, Data)).

%% record_event(+Event) is det.
%
% Internal: actually record the event with timestamp and ID.

record_event(Event) :-
    trace_options_store(Options),
    should_capture(Event, Options),
    !,
    get_time(Timestamp),
    next_event_id(Id),
    ( Options.max_events > 0,
      Id > Options.max_events
    -> true  % Skip if over limit
    ;  FullEvent = event(Id, Timestamp, Event),
       assertz(trace_event_store(FullEvent))
    ).
record_event(_).  % Silently ignore if not capturing this event type

%% next_event_id(-Id) is det.
%
% Get the next event ID.

next_event_id(Id) :-
    retract(trace_event_counter(Current)),
    Id is Current + 1,
    assertz(trace_event_counter(Id)).

%% should_capture(+Event, +Options) is semidet.
%
% Check if this event type should be captured based on options.

should_capture(event_data(statement_start, _), Opts) :- Opts.capture_statements.
should_capture(event_data(statement_end, _), Opts) :- Opts.capture_statements.
should_capture(event_data(branch_decision, _), Opts) :- Opts.capture_branches.
should_capture(event_data(var_assign, _), Opts) :- Opts.capture_vars.
should_capture(event_data(var_read, _), Opts) :- Opts.capture_reads.
should_capture(event_data(proc_enter, _), Opts) :- Opts.capture_calls.
should_capture(event_data(proc_exit, _), Opts) :- Opts.capture_calls.
should_capture(event_data(method_enter, _), Opts) :- Opts.capture_calls.
should_capture(event_data(method_exit, _), Opts) :- Opts.capture_calls.
should_capture(event_data(loop_iteration, _), Opts) :- Opts.capture_branches.
should_capture(event_data(loop_start, _), Opts) :- Opts.capture_branches.
should_capture(event_data(loop_end, _), Opts) :- Opts.capture_branches.
should_capture(event_data(file_op, _), Opts) :- Opts.capture_file_ops.
should_capture(event_data(case_match, _), Opts) :- Opts.capture_branches.
should_capture(event_data(error, _), _) :- true.  % Always capture errors
should_capture(_, _) :- true.  % Default: capture unknown events

%------------------------------------------------------------
% Convenience Recording Predicates
%------------------------------------------------------------

%% trace_statement_start(+StmtType, +StmtAST) is det.
trace_statement_start(StmtType, StmtAST) :-
    trace_event(statement_start, stmt{type: StmtType, ast: StmtAST}).

%% trace_statement_end(+StmtType, +Control) is det.
trace_statement_end(StmtType, Control) :-
    trace_event(statement_end, stmt{type: StmtType, control: Control}).

%% trace_branch(+Context, +Condition, +Value, +BranchTaken) is det.
trace_branch(Context, Condition, Value, BranchTaken) :-
    trace_event(branch_decision, branch{
        context: Context,
        condition: Condition,
        value: Value,
        branch_taken: BranchTaken
    }).

%% trace_var_assign(+VarName, +OldValue, +NewValue) is det.
trace_var_assign(VarName, OldValue, NewValue) :-
    trace_event(var_assign, var{name: VarName, old: OldValue, new: NewValue}).

%% trace_var_read(+VarName, +Value) is det.
trace_var_read(VarName, Value) :-
    trace_event(var_read, var{name: VarName, value: Value}).

%% trace_proc_enter(+Name, +Args) is det.
trace_proc_enter(Name, Args) :-
    trace_event(proc_enter, call{name: Name, args: Args}),
    push_call_stack(proc(Name)).

%% trace_proc_exit(+Name, +Result) is det.
trace_proc_exit(Name, Result) :-
    trace_event(proc_exit, call{name: Name, result: Result}),
    pop_call_stack.

%% trace_method_enter(+Object, +Method, +Args) is det.
trace_method_enter(Object, Method, Args) :-
    trace_event(method_enter, call{object: Object, method: Method, args: Args}),
    push_call_stack(method(Object, Method)).

%% trace_method_exit(+Object, +Method, +Result) is det.
trace_method_exit(Object, Method, Result) :-
    trace_event(method_exit, call{object: Object, method: Method, result: Result}),
    pop_call_stack.

%% trace_loop_start(+LoopType, +Info) is det.
trace_loop_start(LoopType, Info) :-
    trace_event(loop_start, loop{type: LoopType, info: Info}).

%% trace_loop_iteration(+LoopType, +Iteration, +CondValue) is det.
trace_loop_iteration(LoopType, Iteration, CondValue) :-
    trace_event(loop_iteration, loop{type: LoopType, iteration: Iteration, cond_value: CondValue}).

%% trace_loop_end(+LoopType, +Reason) is det.
trace_loop_end(LoopType, Reason) :-
    trace_event(loop_end, loop{type: LoopType, reason: Reason}).

%% trace_case_match(+Value, +MatchedCase, +Index) is det.
trace_case_match(Value, MatchedCase, Index) :-
    trace_event(case_match, case{value: Value, matched: MatchedCase, index: Index}).

%% trace_file_op(+Operation, +FileName, +Key, +Result) is det.
trace_file_op(Operation, FileName, Key, Result) :-
    trace_event(file_op, file{op: Operation, name: FileName, key: Key, result: Result}).

%% trace_error(+Message) is det.
trace_error(Message) :-
    trace_event(error, error{message: Message}).

%------------------------------------------------------------
% Call Stack Management
%------------------------------------------------------------

push_call_stack(Entry) :-
    ( retract(trace_call_stack_store(Stack))
    -> true
    ;  Stack = []
    ),
    assertz(trace_call_stack_store([Entry|Stack])).

pop_call_stack :-
    ( retract(trace_call_stack_store([_|Rest]))
    -> assertz(trace_call_stack_store(Rest))
    ;  true
    ).

%------------------------------------------------------------
% Trace Retrieval
%------------------------------------------------------------

%% get_trace(-Events) is det.
%
% Get all trace events in chronological order.

get_trace(Events) :-
    findall(E, trace_event_store(E), EventsReversed),
    reverse(EventsReversed, Events).

%% get_execution_path(-Path) is det.
%
% Get the execution path as a sequence of statement types and branch decisions.

get_execution_path(Path) :-
    get_trace(Events),
    extract_path(Events, Path).

extract_path([], []).
extract_path([event(_, _, event_data(statement_start, Data))|Rest], [stmt(Type)|Path]) :-
    Type = Data.type,
    extract_path(Rest, Path).
extract_path([event(_, _, event_data(branch_decision, Data))|Rest], [branch(Context, Taken)|Path]) :-
    Context = Data.context,
    Taken = Data.branch_taken,
    extract_path(Rest, Path).
extract_path([event(_, _, event_data(proc_enter, Data))|Rest], [enter(Name)|Path]) :-
    Name = Data.name,
    extract_path(Rest, Path).
extract_path([event(_, _, event_data(proc_exit, Data))|Rest], [exit(Name)|Path]) :-
    Name = Data.name,
    extract_path(Rest, Path).
extract_path([_|Rest], Path) :-
    extract_path(Rest, Path).

%% get_branch_decisions(-Decisions) is det.
%
% Get all branch decisions as a list.

get_branch_decisions(Decisions) :-
    get_trace(Events),
    include(is_branch_event, Events, BranchEvents),
    maplist(extract_branch_data, BranchEvents, Decisions).

is_branch_event(event(_, _, event_data(branch_decision, _))).

extract_branch_data(event(Id, Time, event_data(branch_decision, Data)),
    decision{id: Id, time: Time, context: Data.context,
             condition: Data.condition, value: Data.value,
             branch: Data.branch_taken}).

%% get_variable_history(+VarName, -History) is det.
%
% Get the history of assignments to a variable.

get_variable_history(VarName, History) :-
    get_trace(Events),
    include(is_var_event(VarName), Events, VarEvents),
    maplist(extract_var_data, VarEvents, History).

is_var_event(VarName, event(_, _, event_data(var_assign, Data))) :-
    Data.name = VarName.

extract_var_data(event(Id, Time, event_data(var_assign, Data)),
    assign{id: Id, time: Time, old: Data.old, new: Data.new}).

%% get_call_stack(-Stack) is det.
%
% Get the current call stack.

get_call_stack(Stack) :-
    ( trace_call_stack_store(Stack)
    -> true
    ;  Stack = []
    ).

%------------------------------------------------------------
% Trace Analysis
%------------------------------------------------------------

%% trace_summary(-Summary) is det.
%
% Get a summary of the trace.

trace_summary(Summary) :-
    get_trace(Events),
    length(Events, TotalEvents),
    count_event_types(Events, TypeCounts),
    count_branches(Events, BranchCounts),
    Summary = summary{
        total_events: TotalEvents,
        event_types: TypeCounts,
        branch_stats: BranchCounts
    }.

count_event_types(Events, Counts) :-
    findall(Type, (member(event(_, _, event_data(Type, _)), Events)), Types),
    msort(Types, SortedTypes),
    clumped(SortedTypes, Counts).

count_branches(Events, branch_stats{total: Total, true_branches: True, false_branches: False}) :-
    include(is_branch_event, Events, BranchEvents),
    length(BranchEvents, Total),
    include(is_true_branch, BranchEvents, TrueEvents),
    length(TrueEvents, True),
    False is Total - True.

is_true_branch(event(_, _, event_data(branch_decision, Data))) :-
    Data.branch_taken = true.

%============================================================
% EXECUTION GRAPH (PyTorch-style DAG)
%============================================================
%
% The execution graph captures:
%   - Nodes: Operations/statements with unique IDs
%   - Control edges: Sequential execution flow
%   - Data edges: Variable dependencies (reads from writes)
%
% Node types:
%   - root: Entry point
%   - assign: Variable assignment
%   - branch: IF/CASE decision point
%   - loop: LOOP construct
%   - call: Procedure/function call
%   - return: Return statement
%   - file_op: File operation
%
% Edge types:
%   - control: Sequential control flow
%   - data(VarName): Data dependency through variable

%------------------------------------------------------------
% Graph Node Operations
%------------------------------------------------------------

%% add_graph_node(+Type, +Data, -NodeId) is det.
%
% Add a new node to the execution graph.
% Creates a control flow edge from the current node.
% Returns the new node's ID.

add_graph_node(Type, Data, NodeId) :-
    ( is_tracing
    -> next_graph_node_id(NodeId),
       get_time(Timestamp),
       assertz(graph_node(NodeId, Type, node_data{data: Data, timestamp: Timestamp})),
       % Add control flow edge from current node (unless this is root)
       ( Type \= root,
         current_graph_node(CurrentId)
       -> assertz(graph_edge(CurrentId, NodeId, control))
       ;  true
       )
    ;  NodeId = -1
    ).

%% add_graph_edge(+FromId, +ToId, +EdgeType) is det.
%
% Add an edge to the execution graph.
% EdgeType can be: control, data(VarName), branch(true/false)

add_graph_edge(FromId, ToId, EdgeType) :-
    ( is_tracing, FromId >= 0, ToId >= 0
    -> assertz(graph_edge(FromId, ToId, EdgeType))
    ;  true
    ).

%% current_node_id(-Id) is det.
%
% Get the current node ID (for manual edge creation).

current_node_id(Id) :-
    ( current_graph_node(Id)
    -> true
    ;  Id = -1
    ).

%% set_current_node(+Id) is det.
%
% Set the current node (used after creating branch nodes).

set_current_node(Id) :-
    ( is_tracing
    -> retractall(current_graph_node(_)),
       assertz(current_graph_node(Id))
    ;  true
    ).

%% next_graph_node_id(-Id) is det.
%
% Get the next graph node ID.

next_graph_node_id(Id) :-
    ( retract(graph_node_counter(Current))
    -> true
    ;  Current = 0
    ),
    Id is Current + 1,
    assertz(graph_node_counter(Id)).

%------------------------------------------------------------
% Data Dependency Tracking
%------------------------------------------------------------

%% record_var_write(+VarName, +NodeId) is det.
%
% Record that a variable was written at this node.

record_var_write(VarName, NodeId) :-
    ( is_tracing
    -> retractall(var_last_write(VarName, _)),
       assertz(var_last_write(VarName, NodeId))
    ;  true
    ).

%% record_var_read(+VarName, +NodeId) is det.
%
% Record that a variable was read at this node.
% Creates a data dependency edge from the last write.

record_var_read(VarName, NodeId) :-
    ( is_tracing,
      var_last_write(VarName, WriteNodeId)
    -> add_graph_edge(WriteNodeId, NodeId, data(VarName))
    ;  true
    ).

%------------------------------------------------------------
% Graph Construction Helpers
%------------------------------------------------------------

%% graph_node_for_statement(+StmtType, +StmtData, -NodeId) is det.
%
% Create a graph node for a statement and update current node.

graph_node_for_statement(StmtType, StmtData, NodeId) :-
    add_graph_node(StmtType, StmtData, NodeId),
    set_current_node(NodeId).

%% graph_node_for_branch(+Condition, +Value, -NodeId) is det.
%
% Create a branch decision node.

graph_node_for_branch(Condition, Value, NodeId) :-
    add_graph_node(branch, branch{condition: Condition, value: Value}, NodeId),
    set_current_node(NodeId).

%% graph_node_for_assignment(+VarName, +Value, +Expr, -NodeId) is det.
%
% Create an assignment node and track the variable write.

graph_node_for_assignment(VarName, Value, Expr, NodeId) :-
    add_graph_node(assign, assign{var: VarName, value: Value, expr: Expr}, NodeId),
    record_var_write(VarName, NodeId),
    set_current_node(NodeId).

%------------------------------------------------------------
% Graph Retrieval
%------------------------------------------------------------

%% get_execution_graph(-Graph) is det.
%
% Get the complete execution graph.
% Graph is a dict with nodes and edges.

get_execution_graph(Graph) :-
    findall(node(Id, Type, Data), graph_node(Id, Type, Data), Nodes),
    findall(edge(From, To, Type), graph_edge(From, To, Type), Edges),
    % Compute some useful metadata
    length(Nodes, NodeCount),
    length(Edges, EdgeCount),
    include(is_data_edge, Edges, DataEdges),
    include(is_control_edge, Edges, ControlEdges),
    length(DataEdges, DataEdgeCount),
    length(ControlEdges, ControlEdgeCount),
    Graph = graph{
        nodes: Nodes,
        edges: Edges,
        metadata: metadata{
            node_count: NodeCount,
            edge_count: EdgeCount,
            data_edges: DataEdgeCount,
            control_edges: ControlEdgeCount
        }
    }.

is_data_edge(edge(_, _, data(_))).
is_control_edge(edge(_, _, control)).

%% get_data_flow(-DataFlow) is det.
%
% Get only the data dependency edges (variable flow).

get_data_flow(DataFlow) :-
    findall(
        flow{from: From, to: To, var: Var},
        graph_edge(From, To, data(Var)),
        DataFlow
    ).

%% get_control_flow(-ControlFlow) is det.
%
% Get only the control flow edges.

get_control_flow(ControlFlow) :-
    findall(
        flow{from: From, to: To},
        graph_edge(From, To, control),
        ControlFlow
    ).

%------------------------------------------------------------
% Graph Export (DOT format)
%------------------------------------------------------------

%% graph_to_dot(+Graph, -DotString) is det.
%
% Convert execution graph to GraphViz DOT format.
% Shows both control flow (solid arrows) and data flow (dashed arrows).

graph_to_dot(Graph, DotString) :-
    Graph = graph{nodes: Nodes, edges: Edges, metadata: _},
    nodes_to_dot(Nodes, NodeStrings),
    edges_to_dot(Edges, EdgeStrings),
    atomics_to_string([
        "digraph execution_graph {\n",
        "  rankdir=TB;\n",
        "  node [shape=box fontname=\"Courier\"];\n",
        "  \n",
        "  // Nodes\n",
        NodeStrings,
        "  \n",
        "  // Edges\n",
        EdgeStrings,
        "}\n"
    ], DotString).

nodes_to_dot([], "").
nodes_to_dot([Node|Rest], Result) :-
    node_to_dot(Node, NodeStr),
    nodes_to_dot(Rest, RestStr),
    atomics_to_string([NodeStr, RestStr], Result).

node_to_dot(node(Id, Type, Data), Str) :-
    node_label(Type, Data, Label),
    node_style(Type, Style),
    format(string(Str), "  n~d [label=\"~w\" ~w];~n", [Id, Label, Style]).

node_label(root, _, "START").
node_label(assign, node_data{data: D, timestamp: _}, Label) :-
    format(string(Label), "~w = ...", [D.var]).
node_label(branch, node_data{data: D, timestamp: _}, Label) :-
    format(string(Label), "~w?\\n(~w)", [D.condition, D.value]).
node_label(call, node_data{data: D, timestamp: _}, Label) :-
    format(string(Label), "CALL ~w", [D.name]).
node_label(return, node_data{data: D, timestamp: _}, Label) :-
    format(string(Label), "RETURN ~w", [D.value]).
node_label(loop, node_data{data: D, timestamp: _}, Label) :-
    format(string(Label), "LOOP ~w", [D.type]).
node_label(file_op, node_data{data: D, timestamp: _}, Label) :-
    format(string(Label), "~w(~w)", [D.op, D.file]).
node_label(Type, _, Label) :-
    format(string(Label), "~w", [Type]).

node_style(root, "shape=ellipse style=filled fillcolor=lightgray").
node_style(assign, "shape=box").
node_style(branch, "shape=diamond style=filled fillcolor=lightyellow").
node_style(call, "shape=box style=filled fillcolor=lightblue").
node_style(return, "shape=box style=filled fillcolor=lightgreen").
node_style(loop, "shape=hexagon style=filled fillcolor=lightcoral").
node_style(file_op, "shape=cylinder style=filled fillcolor=lightcyan").
node_style(_, "shape=box").

edges_to_dot([], "").
edges_to_dot([Edge|Rest], Result) :-
    edge_to_dot(Edge, EdgeStr),
    edges_to_dot(Rest, RestStr),
    atomics_to_string([EdgeStr, RestStr], Result).

edge_to_dot(edge(From, To, control), Str) :-
    format(string(Str), "  n~d -> n~d [style=solid];~n", [From, To]).
edge_to_dot(edge(From, To, data(Var)), Str) :-
    format(string(Str), "  n~d -> n~d [style=dashed color=blue label=\"~w\"];~n", [From, To, Var]).
edge_to_dot(edge(From, To, branch(Direction)), Str) :-
    format(string(Str), "  n~d -> n~d [style=bold label=\"~w\"];~n", [From, To, Direction]).
edge_to_dot(edge(From, To, _), Str) :-
    format(string(Str), "  n~d -> n~d;~n", [From, To]).

%------------------------------------------------------------
% Graph Export (JSON format)
%------------------------------------------------------------

%% graph_to_json(+Graph, -JsonString) is det.
%
% Convert execution graph to JSON format for visualization tools.

graph_to_json(Graph, JsonString) :-
    Graph = graph{nodes: Nodes, edges: Edges, metadata: Meta},
    nodes_to_json(Nodes, NodesJson),
    edges_to_json(Edges, EdgesJson),
    format(string(JsonString),
        "{~n  \"metadata\": ~w,~n  \"nodes\": [~n~w  ],~n  \"edges\": [~n~w  ]~n}~n",
        [Meta, NodesJson, EdgesJson]).

nodes_to_json([], "").
nodes_to_json([Node], Str) :- !,
    node_to_json(Node, Str).
nodes_to_json([Node|Rest], Result) :-
    node_to_json(Node, NodeStr),
    nodes_to_json(Rest, RestStr),
    atomics_to_string([NodeStr, ",\n", RestStr], Result).

node_to_json(node(Id, Type, Data), Str) :-
    format(string(Str), "    {\"id\": ~d, \"type\": \"~w\", \"data\": ~w}", [Id, Type, Data]).

edges_to_json([], "").
edges_to_json([Edge], Str) :- !,
    edge_to_json(Edge, Str).
edges_to_json([Edge|Rest], Result) :-
    edge_to_json(Edge, EdgeStr),
    edges_to_json(Rest, RestStr),
    atomics_to_string([EdgeStr, ",\n", RestStr], Result).

edge_to_json(edge(From, To, Type), Str) :-
    format(string(Str), "    {\"from\": ~d, \"to\": ~d, \"type\": \"~w\"}", [From, To, Type]).

%------------------------------------------------------------
% ML-Friendly Export Formats
%------------------------------------------------------------

%% graph_to_adjacency(+Graph, -AdjList, -NodeTypes) is det.
%
% Export graph as adjacency list format suitable for graph ML libraries.
% AdjList: List of From-To pairs (0-indexed for Python/C++)
% NodeTypes: List of node type atoms in order

graph_to_adjacency(Graph, AdjList, NodeTypes) :-
    Graph = graph{nodes: Nodes, edges: Edges, metadata: _},
    % Extract node types in ID order
    msort(Nodes, SortedNodes),
    maplist(node_type, SortedNodes, NodeTypes),
    % Convert edges to 0-indexed pairs
    findall([From1, To1],
        (member(edge(From, To, _), Edges),
         From1 is From - 1,  % Convert to 0-indexed
         To1 is To - 1),
        AdjList).

node_type(node(_, Type, _), Type).

%% graph_to_edge_index(+Graph, -EdgeIndex, -EdgeTypes) is det.
%
% Export in PyTorch Geometric COO format (edge_index tensor).
% EdgeIndex: [[src1,src2,...], [dst1,dst2,...]] (0-indexed)
% EdgeTypes: List of edge type atoms

graph_to_edge_index(Graph, EdgeIndex, EdgeTypes) :-
    Graph = graph{nodes: _, edges: Edges, metadata: _},
    findall(From1-To1-Type,
        (member(edge(From, To, Type), Edges),
         From1 is From - 1,
         To1 is To - 1),
        EdgeData),
    maplist(edge_src, EdgeData, Srcs),
    maplist(edge_dst, EdgeData, Dsts),
    maplist(edge_type_only, EdgeData, EdgeTypes),
    EdgeIndex = [Srcs, Dsts].

edge_src(S-_-_, S).
edge_dst(_-D-_, D).
edge_type_only(_-_-T, T).

%% graph_to_numpy_json(+Graph, -JsonString) is det.
%
% Export graph in JSON format optimized for numpy/PyTorch loading.
% Includes adjacency as COO sparse matrix format.

graph_to_numpy_json(Graph, JsonString) :-
    Graph = graph{nodes: Nodes, edges: Edges, metadata: Meta},
    length(Nodes, NumNodes),
    length(Edges, NumEdges),
    % Build edge index arrays
    graph_to_edge_index(Graph, [Srcs, Dsts], EdgeTypes),
    % Build node feature vectors (one-hot encoded types)
    node_type_encoding(Nodes, NodeTypeIds, TypeMapping),
    % Build branch info for probabilistic modeling
    findall(branch_info{node: N1, condition: C, value: V},
        (member(node(N, branch, node_data{data: D, timestamp: _}), Nodes),
         N1 is N - 1,
         C = D.condition,
         V = D.value),
        BranchInfos),
    format(string(JsonString),
'{
  "num_nodes": ~d,
  "num_edges": ~d,
  "edge_index": [~w, ~w],
  "edge_types": ~w,
  "node_type_ids": ~w,
  "type_mapping": ~w,
  "branch_nodes": ~w,
  "metadata": ~w
}',
        [NumNodes, NumEdges, Srcs, Dsts, EdgeTypes, NodeTypeIds, TypeMapping, BranchInfos, Meta]).

%% node_type_encoding(+Nodes, -TypeIds, -TypeMapping) is det.
%
% Encode node types as integers for neural network input.

node_type_encoding(Nodes, TypeIds, TypeMapping) :-
    % Collect unique types
    findall(Type, member(node(_, Type, _), Nodes), Types),
    sort(Types, UniqueTypes),
    % Create mapping
    findall(Type-Id, nth0(Id, UniqueTypes, Type), TypeMapping),
    % Encode each node
    msort(Nodes, SortedNodes),
    maplist(encode_node_type(TypeMapping), SortedNodes, TypeIds).

encode_node_type(Mapping, node(_, Type, _), Id) :-
    member(Type-Id, Mapping), !.
encode_node_type(_, _, -1).

%% graph_to_pgm(+Graph, -PGM) is det.
%
% Convert execution graph to a Probabilistic Graphical Model structure.
% Useful for probabilistic inference over execution paths.
%
% PGM structure:
%   pgm{
%     variables: [var{name, type, parents, domain}],
%     factors: [factor{vars, table}],
%     observed: [name-value pairs]
%   }

graph_to_pgm(Graph, PGM) :-
    Graph = graph{nodes: Nodes, edges: Edges, metadata: _},
    % Extract branch nodes as random variables
    findall(
        var{id: N1, name: VarName, type: branch, parents: Parents, domain: [true, false]},
        (member(node(N, branch, node_data{data: D, timestamp: _}), Nodes),
         N1 is N - 1,
         format(atom(VarName), 'branch_~d', [N1]),
         % Find parent branch nodes (through control flow)
         findall(P1,
             (member(edge(P, N, control), Edges),
              member(node(P, branch, _), Nodes),
              P1 is P - 1),
             Parents)),
        BranchVars),
    % Extract assignment nodes as observed variables (when values known)
    findall(
        var{id: N1, name: VarName, type: assign, parents: [], domain: continuous},
        (member(node(N, assign, node_data{data: D, timestamp: _}), Nodes),
         N1 is N - 1,
         D.var = AssignVar,
         format(atom(VarName), 'assign_~w_~d', [AssignVar, N1])),
        AssignVars),
    append(BranchVars, AssignVars, AllVars),
    % Create uniform prior factors for branches (can be updated with observations)
    findall(
        factor{vars: [VarName], table: [[true, 0.5], [false, 0.5]]},
        member(var{name: VarName, type: branch, parents: [], domain: _}, BranchVars),
        PriorFactors),
    PGM = pgm{
        variables: AllVars,
        factors: PriorFactors,
        observed: []
    }.

%% path_probability(+Graph, +Path, -Probability) is det.
%
% Calculate probability of a specific execution path given branch probabilities.
% Path is a list of branch decisions: [branch(NodeId, true/false), ...]
% Assumes uniform 0.5 probability for each branch by default.

path_probability(_, [], 1.0).
path_probability(Graph, [branch(NodeId, Decision)|Rest], Prob) :-
    % Default: uniform probability
    BranchProb = 0.5,
    path_probability(Graph, Rest, RestProb),
    Prob is BranchProb * RestProb.

%% sample_path(+Graph, +InputDist, -Path, -Probability) is det.
%
% Sample an execution path given an input distribution.
% InputDist: dict mapping variable names to distributions
%            e.g., input_dist{'X': uniform(0, 100), 'Y': normal(50, 10)}
% Returns the sampled Path and its Probability.
%
% Note: This is a stub - full implementation would require:
%       1. Symbolic execution to determine branch conditions
%       2. Constraint solving to check path feasibility
%       3. Integration with a probabilistic programming backend

sample_path(Graph, _InputDist, Path, Probability) :-
    % Collect all branch nodes
    Graph = graph{nodes: Nodes, edges: _, metadata: _},
    findall(NodeId,
        member(node(NodeId, branch, _), Nodes),
        BranchNodes),
    % For now: sample uniformly from recorded decisions
    maplist(sample_branch_uniform, BranchNodes, Path),
    path_probability(Graph, Path, Probability).

sample_branch_uniform(NodeId, branch(NodeId, Decision)) :-
    random(R),
    ( R < 0.5 -> Decision = true ; Decision = false ).

%% path_to_dot(+Trace, -DotString) is det.
%
% Convert trace to GraphViz DOT format for visualization.

path_to_dot(trace{events: Events}, DotString) :-
    path_to_dot_events(Events, DotString).

path_to_dot_events(Events, DotString) :-
    get_execution_path_from_events(Events, Path),
    format(string(DotString),
        "digraph execution_path {~n  rankdir=TB;~n  node [shape=box];~n~s}~n",
        [NodesAndEdges]),
    path_to_dot_nodes(Path, 0, NodesAndEdges).

get_execution_path_from_events(Events, Path) :-
    extract_path(Events, Path).

path_to_dot_nodes([], _, "").
path_to_dot_nodes([Item|Rest], N, Result) :-
    N1 is N + 1,
    item_to_dot_node(Item, N, NodeStr),
    ( Rest = []
    -> EdgeStr = ""
    ;  format(string(EdgeStr), "  n~d -> n~d;~n", [N, N1])
    ),
    path_to_dot_nodes(Rest, N1, RestStr),
    format(string(Result), "~s~s~s", [NodeStr, EdgeStr, RestStr]).

item_to_dot_node(stmt(Type), N, Str) :-
    format(string(Str), "  n~d [label=\"~w\"];~n", [N, Type]).
item_to_dot_node(branch(Context, Taken), N, Str) :-
    format(string(Str), "  n~d [label=\"~w: ~w\" shape=diamond];~n", [N, Context, Taken]).
item_to_dot_node(enter(Name), N, Str) :-
    format(string(Str), "  n~d [label=\"CALL ~w\" style=filled fillcolor=lightblue];~n", [N, Name]).
item_to_dot_node(exit(Name), N, Str) :-
    format(string(Str), "  n~d [label=\"RETURN ~w\" style=filled fillcolor=lightgreen];~n", [N, Name]).

%------------------------------------------------------------
% Tests
%------------------------------------------------------------

:- use_module(library(plunit)).

:- begin_tests(execution_tracer).

test(trace_control) :-
    clear_trace,
    \+ is_tracing,
    start_trace,
    is_tracing,
    trace_event(test, data{value: 1}),
    stop_trace(Trace),
    \+ is_tracing,
    Trace.summary.total_events > 0.

test(trace_events) :-
    start_trace,
    trace_event(statement_start, stmt{type: assign, ast: test}),
    trace_event(var_assign, var{name: 'X', old: 0, new: 42}),
    trace_event(branch_decision, branch{context: if, condition: 'X > 0', value: true, branch_taken: true}),
    stop_trace(Trace),
    length(Trace.events, 3).

test(branch_decisions) :-
    start_trace,
    trace_event(branch_decision, branch{context: if, condition: c1, value: true, branch_taken: true}),
    trace_event(branch_decision, branch{context: if, condition: c2, value: false, branch_taken: false}),
    get_branch_decisions(Decisions),
    length(Decisions, 2),
    stop_trace(_).

test(variable_history) :-
    start_trace,
    trace_event(var_assign, var{name: 'Counter', old: 0, new: 1}),
    trace_event(var_assign, var{name: 'Other', old: 0, new: 5}),
    trace_event(var_assign, var{name: 'Counter', old: 1, new: 2}),
    get_variable_history('Counter', History),
    length(History, 2),
    stop_trace(_).

% Graph tests
test(graph_creation) :-
    start_trace,
    % Should have root node
    get_execution_graph(Graph),
    Graph.metadata.node_count > 0,
    stop_trace(_).

test(graph_nodes_and_edges) :-
    start_trace,
    % Manually add nodes to simulate execution
    add_graph_node(assign, assign{var: 'X', value: 10, expr: num(10)}, N1),
    add_graph_node(assign, assign{var: 'Y', value: 20, expr: num(20)}, N2),
    add_graph_node(branch, branch{condition: 'X > Y', value: false}, _N3),
    set_current_node(N1),  % Go back to N1 for data flow
    record_var_write('X', N1),
    record_var_write('Y', N2),
    get_execution_graph(Graph),
    Graph.metadata.node_count >= 4,  % root + 3 nodes
    Graph.metadata.control_edges >= 3,  % root->N1->N2->N3
    stop_trace(_).

test(data_flow_tracking) :-
    start_trace,
    % Simulate: X = 10; Y = X + 5
    add_graph_node(assign, assign{var: 'X', value: 10}, N1),
    record_var_write('X', N1),
    set_current_node(N1),
    add_graph_node(assign, assign{var: 'Y', value: 15}, N2),
    record_var_read('X', N2),  % Y reads X
    record_var_write('Y', N2),
    get_data_flow(DataFlow),
    % Should have one data edge from X's write to Y's read
    length(DataFlow, 1),
    stop_trace(_).

test(graph_to_dot_export) :-
    start_trace,
    add_graph_node(assign, assign{var: 'X', value: 10}, _),
    get_execution_graph(Graph),
    graph_to_dot(Graph, DotString),
    sub_string(DotString, _, _, _, "digraph"),
    stop_trace(_).

:- end_tests(execution_tracer).
