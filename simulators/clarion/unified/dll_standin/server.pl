% server.pl - Runs one Clarion module for run_dll_test.py
%
%   swipl -q -g main -t halt server.pl -- Module.clw
%
% Reads c('Proc', [Args]). terms, and answers each with one line:
%   @@N number    @@T other result    @@E error
% The session, with its globals and open files, lasts until end of input.

:- use_module('../clarion').
:- use_module(library(time)).
:- use_module(library(readutil)).

main :-
    current_prolog_flag(argv, [File|_]),
    read_file_to_string(File, Source, [encoding(iso_latin_1)]),
    ( catch(init_session(Source, Session), E, true) -> true ; E = not_parsed ),
    ( nonvar(E) -> format("~n@@E ~q~n", [E]) ; format("~n@@READY~n"), flush_output, loop(Session) ).

loop(Session) :-
    read_term(user_input, Term, []),
    ( Term = c(Proc, Args)
    -> ( catch(call_with_time_limit(300, call_procedure(Session, Proc, Args, R0, S0)), E, true)
       -> ( var(E) -> R = R0, S = S0 ; R = error(E), S = Session )
       ;  R = error(failed), S = Session
       ),
       answer(R),
       flush_output,
       loop(S)
    ;  true
    ).

answer(R) :- number(R), !, format("~n@@N ~w~n", [R]).
answer(error(E)) :- !, format("~n@@E ~q~n", [E]).
answer(R) :- format("~n@@T ~q~n", [R]).
