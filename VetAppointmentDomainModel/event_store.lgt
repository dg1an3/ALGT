
:- use_module(library(lists)).

:- object(event_store(_Current_Next)).
    :- public([dump/0, emit/1, last_of/1]).

    emit(Event) :-
		this(event_store(ES -> ESNext)),
		lists:append(ES, [Event], ESNext).

    last_of(Event) :-
	    this(event_store(ES -> _)),
		member(Event, ES).

:- end_object.
