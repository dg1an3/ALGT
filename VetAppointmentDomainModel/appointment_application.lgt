
/************************************************************
%!	appointment_application(_Repository) is det
%
%	note that we don't use a bus, as the repository is the only holder
%	of state
**************************************************************/

:- object(appointment_application(_Repository),
		 implements(appointment_application)).

	%!		list(_) is det
	%
	%

	list_all_appointments(All_Appointments) :-	
		this(appointment_application(Repository)).

	:- info(list_all_appointments/1, [comment(query)]).

	%!		update_appointment(_) is det
	%
	%

	update_appointment(Id, New_Time) :-
			this(appointment_application(Repository)),
			Repository::get_by_id(Id, Appointment),
			Appointment::update_scheduled_time(New_Time),
			Repository::update(Appointment).

	:- info(update_appointment/2, [comment(command)]).

:- end_object.

