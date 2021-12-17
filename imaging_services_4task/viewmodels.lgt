

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




:- object(image_list_dialog_viewmodel).

	% starts default workflow
	%
:- end_object.





:- object(trend_detail_viewModel).

	% starts default workflow
	%
:- end_object.



