:- protocol(aggregate_root).
	:- public(id/1).
:- end_protocol.

:- protocol(repository).
	:- public([get_by_id/2,
		get_all/1,
		add/2,
		update/1,
		delete/1]).
:- end_protocol.

:- protocol(appointment_application).
	:- public([list_all_appointments/1,
			create_appointment/3,
			update_appointment/2,
			delete_appointment/1]).
:- end_protocol.


