:- module(appointment, []).

type(wellness).
type(clinical).
type(nail_trimming).


:- object(appointment(_Id, _ES)).

:- public([
	   for_patient/1,
	   of_type/1,
	   at_time/1,
	   confirmed/1,
	   ctor/3,
	   confirm/1
   ]).

:- initialization((
	   this(Id, ES),
	   uuid_property(Id, version(_)),
	   is_list(ES))).

/* queries
 *
 */

for_patient(patient(Patient_Id)) :-
	this(Id, ES),
	member(created(Id, patient(Patient_Id), _, _), ES).

of_type(type(Type)) :-
	this(Id, ES),
	member(created(Id, _, type(Type), _), ES).

at_time(time(Scheduled_Time)) :-
	this(Id, ES),
	member(created(Id, _, _, time(Scheduled_Time)), ES).

confirmed(Property) :-
	this(Id, ES),
	member(confirmed(Id, Property), ES).

/* commands
 *
 */

ctor(patient(Patient_Id), type(Type), time(Scheduled_Time)) :-

	type(Type),
	this(Id, [created(Id,
					  patient(Patient_Id),
					  type(Type),
					  time(Scheduled_Time))|_]).

confirm(type) :-
	\+ ::confirmed(type),
	this(Id, [confirmed(Id, type) |_]).

confirm(time) :-
	::confirmed(type),
	\+ ::confirmed(time),
	this(Id, [confirmed(Id, time) |_]).

:- end_object.












