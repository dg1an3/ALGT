
:- object(event_store(_Committed, _New),
			implements(ievent_store)).
	:- public([emit/1, 
				last_if/1]).

	emit(Event) :-
		this(_, New),
		member(Event, New).

	last_if(Event) :-
		this(Committed, _),
		member(Event, Committed).

	commit(Committed) :-
		this(_, New),
		include(nonvar, New, Committed).

:- end_object.
