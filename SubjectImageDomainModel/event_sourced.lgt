%%
%%
%%

:- object(event_sourced(_Type_Id, _ES)).

	:- protected([emit/1, last/1]).

	:- initialization((
		   this(Type_Id, ES),
		   Type_Id =.. [Type, Id],
		   specializes_class(Type, event_sourced),
		   uuid_property(Id, _),
		   is_list(ES))).

	emit(Event) :-
		this(Type_Id, [Event|_]),
		Event =.. [_,Type_Id|_].

	last(Event) :-
		this(Type_Id, ES),
		Event =.. [_,Type_Id|_],
		member(Event, ES).

:- end_object.

