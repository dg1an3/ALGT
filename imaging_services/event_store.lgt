%% Copyright Derek Lane
%%
%%

:- object(event_store(_List),
			implements(ievent_store)).
    :- public([event/1,
			   commit/1]).

    event(Event) :-
	    this(event_store(Uncommited)),
		list:member(Event, Uncommited).

    commit(OpenSorted) :-
	    this(event_store(Uncommited)),
		list:include(nonvar, Uncommited, Commited), !,
		list:sort(Commited, Sorted),
		list:append(Sorted, _, OpenSorted).

:- end_object.
