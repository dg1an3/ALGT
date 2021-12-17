
:- object(workflow_subsystem_client).

	%!	these are the three RESTful endpoints

:- end_object.



:- protocol(iworkflow_subsystem_messaging).
	:- public([subscribe_To_Message_Event/2]).
:- end_protocol.


:- object(workflow_subsystem_messaging).

	subscribe_to_message_event(Message, Goal) :-
		listen(Message, Goal).

:- end_object.





:- object(messaging_client).

	%!	this is a wrapper for messaging from legacy components
	%

	send_image_imported_message(Img_Id) :-
		true.

	send_new_trend_data(Patient_Id, Site_Id, Offset_Id) :-
		true.

:- end_object.
