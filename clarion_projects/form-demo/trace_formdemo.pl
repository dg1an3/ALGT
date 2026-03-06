% trace_formdemo.pl — Prolog-side trace output for FormDemo
% Produces trace lines matching the instrumented FormDemo_trace.clw output.
%
% Usage:
%   cd form-demo
%   swipl -g "main,halt" -t "halt(1)" trace_formdemo.pl

:- use_module('../prolog-interp/clarion_parser').
:- use_module('../prolog-interp/clarion_interpreter').
:- set_prolog_flag(double_quotes, codes).

main :-
    read_file_to_codes('FormDemo.clw', Codes, []),
    parse_clarion(Codes, AST),
    set_trace(on),
    % Equates: TypeList=1, CalcBtn=2, ClearBtn=3, CloseBtn=4
    % Simulate: enter values, default list selection (Standard=1),
    %           click Calculate (2), then Close (4)
    Events = [set('SensorID', 42), set('Reading', 500), set('Weight', 20), 2, 4],
    exec_program(AST, Events, _Result),
    get_trace(Log),
    print_form_trace(Log).

print_form_trace([]).
print_form_trace([E|Es]) :-
    ( E = stmt(Name, Type, Details) ->
        format_trace_line(Name, Type, Details)
    ; true  % skip proc_enter/proc_exit
    ),
    print_form_trace(Es).

format_trace_line(Name, Type, Details) :-
    ( Details == '' ->
        format("~w: ~w~n", [Name, Type])
    ; format("~w: ~w ~w~n", [Name, Type, Details])
    ).
