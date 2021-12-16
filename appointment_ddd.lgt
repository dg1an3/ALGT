
/******************************************************
%!	appointment(_Current, _Next) is det
%   uses
*******************************************************/

:- object(appointment(_Current -> _Next),
		  implements(aggregate_root)).

	:- public([ctor/3,
		   	update_scheduled_time/1]).

	%% TODO: this doesn't work
	:- initialization((
	   	this(appointment(Current -> Next)),
	   	var(Current) ->
	   		appointment{id:Id,
				   	title:_,
					scheduled_time:_} = Current,
		var(Next) ->
			appointment{id:Id,
				   title:_,
				   scheduled_time:_} = Next
	)).

	%!		ctor(I,T,S) is det
	%
	%		constructor

	ctor(Id, Title, Scheduled_Time) :-
			this(appointment(appointment{id:Id,
									 	title:Title,
									 	scheduled_time:Scheduled_Time} -> _)).

	:- info(ctor/3, [comment(ctor)]).

	%!		id(I) is det
	%
	%		returns Id

	id(Id) :-
			this(appointment(appointment{id:Id,
										 title:_,
										 scheduled_time:_} -> _)).

	:- info(id/1, [comment(query), protocol(aggregate_root)]).

	%!		update_scheduled_time(N) is det
	%
	%

	update_scheduled_time(New_Time) :-
			this(appointment(appointment{id:Id,
										 title:Title,
										 scheduled_time:_} ->

							 appointment{id:Id,
										 title:Title,
										 scheduled_time:New_Time})).

	:- info(update_scheduled_time/1, [comment(command)]).

:- end_object.
