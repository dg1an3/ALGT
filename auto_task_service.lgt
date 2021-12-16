
:- protocol('IAutoTaskService').
:- public(['EvaluateAvailableRegistrations'/2,
		   'CalculateNewOffset'/2,
		   'CalculateUpdatedOffset'/2]).
:- end_protocol.


:- object('AutoTaskService'(_),
		  implements('IAutoTaskService')).

'EvaluateAvailableRegistrations'(WorkflowInstanceBusinessKey,
								 AvailableRegistrationsOut) :-

	'GetAvailableCouchCorrections'(WorkflowInstanceBusinessKey,
								   AvailableRegistrationsOut).


:- end_object.



:- object('WorkflowSubsystemClient').

%!	these are the three RESTful endpoints

:- end_object.



:- protocol('IWorkflowSubsystemMessaging').
:- public(['SubscribeToMessageEvent'/2]).
:- end_protocol.


:- object('WorkflowSubsystemMessaging').

'SubscribeToMessageEvent'(Message, Goal) :-
	listen(Message, Goal).

:- end_object.



:- object('ImageReviewApplicationCoordinator'(_WorkflowSubsystemMessaging)).

:- initialization((
	   this(WorkflowSubsystemMessaging),
	   WorkflowSubsystemMessaging::'SubscribeToMessageEvent'(
									   'PlanOfCareUpdateCompleted',
									   _),
	   WorkflowSubsystemMessaging::'SubscribeToMessageEvent'(
									   'SroImportdInEquator',
									   _)
   )).

:- end_object.




:- object('ImageListViewModel'(_WorkflowSubsystemMessaging)).

:- initialization((
	   this(WorkflowSubsystemMessaging),
	   WorkflowSubsystemMessaging::'SubscribeToMessageEvent'(
									   'ImageImportedInEquator',
									   _)
   )).

:- end_object.




:- object('MessagingClient').

%!	this is used by Namer and SRO to send messages
%

'SendImageImportedMessage'(Img_Id) :-
	true.

'SendNewTrendDataFromMosaiq'(Patient_Id, Sit_Set_Id, Offset_Id) :-
	true.

:- end_object.




:- object('ImageImport2dService').

% StartDefaultWorkflowsAsyncIfNeeded
%
:- end_object.





:- object('ImageListPopUpDialogViewModel').

% StartDefaultWorkflowsAsyncIfNeeded
%

:- end_object.







:- object('TrendDetailViewModel').

% StartDefaultWorkflowsAsyncIfNeeded
%

:- end_object.




