



:- object(appointment(_Id, _ES)).

:- public([ctor/2,
		   type/1,
		   scheduled_time/1,
		   is_time_confirmed/0,
		   confirm_time/0,
		   update_time/1]).

:- initialization((this(_Id, _ES),
				   uuid(_Id))).

%%	query operations

type(Type) :-
	this(Id, ES),
	member(created(Id, Type, _), ES).

scheduled_time(Scheduled_Time) :-
	this(Id, ES),
	member(created(Id, _, Scheduled_Time), ES).

is_time_confirmed :-
	this(Id, ES),
	member(is_time_confirmed(Id), ES).

%%	commands

ctor(Type, Scheduled_Time) :-
	this(Id, [created(Id, Type, Scheduled_Time) | _]).

confirm_time :-
	this(Id, [is_time_confirmed(Id) | _]),
	\+ ::is_time_confirmed.

update_time(New_Time) :-
	this(Id, [time_updated(Id, New_Time) | _]).

:- end_object.




:- begin_test(appointment).

test(create) :-
	appointment(Id, ES_0)::ctor(wellness, date(2010,01,01)),
	appointment(Id, ES_0)::type(wellness),
	appointment(Id, ES_0)::scheduled_time(date(2010,01,01)),
	\+ appointment(Id, ES_0)::is_time_confirmed,

	ES_1 = [_, ES_0],
	appointment(Id, ES_1)::confirm_time,
	appointment(Id, ES_1)::is_time_confirmed,

	ES_2 = [_, ES_1],
	appointment(Id, ES_2)::update_time(date(2009,01,01)),
	\+ appointment(Id, ES_2)::is_time_confirmed,

	ES_3 = [_, ES_2],
	appointment(Id, ES_3)::Command,
	Command = update_time.

:- end_test.





