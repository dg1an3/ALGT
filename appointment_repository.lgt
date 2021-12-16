
/*********************************************************
%!  appointment_repository(_Current, _Next) is not det
%
%	note that we need a bus because
**********************************************************/

:- object(appointment_repository(_Current_Dict -> _Next_Dict),
		 implements(repository)).

	%% TODO: this doesn't work
	:- initialization((
		   this(appointment_repository(Current_Dict -> _)),
		   var(Current_Dict) ->
			Current_Dict = appointment_repository{}; true)).

	%!
	%
	%
	get_by_id(Id, Appointment) :-
			this(appointment_repository(Current_Dict -> _)),
			get_dict(Id, Current_Dict, Appointment).

	:- info(get_by_id/2, [comment(query)]).

	%!
	%
	%
	get_all(All_Appointments) :-
	    	this(appointment_repository(Current_Dict -> _)),
			All_Appointments = Current_Dict.

	%!
	%
	%
	add(New_Appointment, New_Appointment) :-
			is_dict(New_Appointment, appointment),
			Next_Dict = Current_Dict,
			this(appointment_repository(Current_Dict -> Next_Dict)).

	%!
	%
	%
	update(Updated_Appointment) :-
	    	is_dict(Updated_Appointment, appointment),
			this(appointment_repository(Current_Dict -> Next_Dict)).
	%!
	%
	%
	delete(Id) :- true.

:- end_object.


