% trace_formdemo.pl — Prolog-side trace output for FormDemo
% Produces trace lines for FormDemo using the unified simulator.
%
% Usage:
%   cd form-demo
%   swipl -g "main,halt" -t "halt(1)" trace_formdemo.pl

:- use_module('../../clarion_simulators/unified/clarion').

main :-
    read_file_to_string('FormDemo.clw', Src, []),
    % Equates: TypeList=1, CalcBtn=2, ClearBtn=3, CloseBtn=4
    % Simulate: enter values, default list selection (Standard=1),
    %           click Calculate (2), then Close (4)
    Events = [set('SensorID', 42), set('Reading', 500), set('Weight', 20), 2, 4],
    exec_program(Src, Events, Result),
    format("FormDemo result: ~w~n", [Result]).
