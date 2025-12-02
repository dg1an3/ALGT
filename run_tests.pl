:- use_module(src/clarion).
:- use_module(library(plunit)).
:- use_module(library(lists)). % For forall/2 and member/2

test_files([
    'examples/class_example.clw',
    'examples/control_flow.clw',
    'examples/data_types.clw',
    'examples/file_io.clw',
    'examples/hello_world.clw',
    'examples/queue_example.clw',
    'examples/report_example.clw',
    'examples/sql_example.clw',
    'examples/string_functions.clw',
    'examples/window_example.clw',
    'examples/ado_sql_example.clw'
]).

interpreter_test_files([
    'examples/hello_world.clw',
    'examples/string_functions.clw',
    'examples/control_flow.clw',
    'examples/file_io.clw',
    'examples/class_example.clw',
    'examples/case_variations.clw',
    'examples/report_example.clw',
    'examples/window_example.clw'
]).

% run_tests/0 will discover and run all tests defined with :- begin_tests/1
% The plunit:run_tests/0 predicate is dynamically found if tests are loaded.
run_all_plunit_tests :-
    format("Running all PLUnit tests...~n", []),
    % This will run all tests defined in loaded modules.
    run_tests, % This is the predicate from library(plunit)
    format("All PLUnit tests completed.~n", []).

:- initialization(run_all_plunit_tests, main).