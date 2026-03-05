
:- protocol(iauto_task_service).
	:- public([evaluate_available_registrations/2,
				   calculate_new_offset/2,
				   calculate_updated_offset/2]).
:- end_protocol.


:- object(auto_task_service(_),
		  implements(iauto_task_service)).

	evaluate_available_registrations(WorkflowInstanceBusinessKey,
										 AvailableRegistrationsOut) :-
											 
	get_available_couch_corrections(WorkflowInstanceBusinessKey,
										AvailableRegistrationsOut).

:- end_object.


