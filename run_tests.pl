:- use_module(clarion_interpreter/clarion).
:- use_module(library(plunit)).
:- use_module(library(lists)). % For forall/2 and member/2

test_files([
    'clarion_examples/class_example.clw',
    'clarion_examples/control_flow.clw',
    'clarion_examples/data_types.clw',
    'clarion_examples/file_io.clw',
    'clarion_examples/hello_world.clw',
    'clarion_examples/queue_example.clw',
    'clarion_examples/report_example.clw',
    'clarion_examples/sql_example.clw',
    'clarion_examples/string_functions.clw',
    'clarion_examples/window_example.clw',
    'clarion_examples/ado_sql_example.clw'
]).

interpreter_test_files([
    'clarion_examples/hello_world.clw',
    'clarion_examples/string_functions.clw',
    'clarion_examples/control_flow.clw',
    'clarion_examples/file_io.clw',
    'clarion_examples/class_example.clw',
    'clarion_examples/case_variations.clw',
    'clarion_examples/report_example.clw',
    'clarion_examples/window_example.clw',
    'clarion_examples/queue_example.clw'
]).

% run_tests/0 will discover and run all tests defined with :- begin_tests/1
% The plunit:run_tests/0 predicate is dynamically found if tests are loaded.
run_all_plunit_tests :-
    format("Running all PLUnit tests...~n", []),
    % This will run all tests defined in loaded modules.
    run_tests, % This is the predicate from library(plunit)
    format("All PLUnit tests completed.~n", []).

:- initialization(run_all_plunit_tests, main).