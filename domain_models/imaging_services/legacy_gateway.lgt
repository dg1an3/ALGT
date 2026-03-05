


:- protocol(ilegacy_data_service).
:- end_protocol.


:- object(patient_setup_legacy_bridge(_LegacyDataService)).

	inject(LegacyDataService) :-
	   this(LegacyDataService),
	   implements_protocol(LegacyDataService,
		   ilegacy_data_service)
	   )).

:- end_object.



:- object(diagnosis_legacy_bridge).

:- end_object.



:- object(legacy_data_service,
		  implements(ilegacy_data_service)).

:- end_object.



:- object(workflow_task_manager).

:- end_object.





