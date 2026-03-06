:- use_module(clarion).
:- set_prolog_flag(double_quotes, codes).

debug_sensor :-
    read_file_to_codes('../../clarion_projects/sensor-data/SensorLib.clw', Codes, []),
    ( parse_clarion(Codes, AST) ->
        writeln('Full SensorLib.clw parse: PASS'),
        AST = program(F,G,Gl,M,P),
        length(F,NF), length(G,NG), length(Gl,NGl), length(M,NM), length(P,NP),
        format('Files:~w Groups:~w Globals:~w Map:~w Procs:~w~n', [NF,NG,NGl,NM,NP])
    ;
        writeln('Full SensorLib.clw parse: FAIL')
    ),
    halt.

:- debug_sensor.
