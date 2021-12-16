
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



:- object(image_review_coordinator(_WorkflowSubsystemMessaging)).

	:- initialization((
		this(WorkflowSubsystemMessaging),
		WorkflowSubsystemMessaging::subscribe_to_message_event(
										'CareRulesUpdateCompleted',
										_),
		WorkflowSubsystemMessaging::subscribe_to_message_event(
										'SroImported',
										_)
	)).

:- end_object.




:- object(image_list_view_model(_WorkflowSubsystemMessaging)).

	subscribe :-
		this(WorkflowSubsystemMessaging),
		WorkflowSubsystemMessaging::subscribe_to_message_event(
									   'ImageImportedInNew', _)
   )).

:- end_object.




:- object(messaging_client).

	%!	this is a wrapper for messaging from legacy components
	%

	sendImageImportedMessage(Img_Id) :-
		true.

	sendNewTrendDataFromMosaiq(Patient_Id, Sit_Set_Id, Offset_Id) :-
		true.

:- end_object.




:- object(image_import_2d_service).

	% starts default workflow
	%
:- end_object.





:- object(image_list_dialog_viewmodel).

	% starts default workflow
	%
:- end_object.







:- object('Trend_Detail_ViewModel').

	% starts default workflow
	%
:- end_object.




