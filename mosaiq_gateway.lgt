


:- protocol('IMosaiqImagingDataForEquatorService').
:- end_protocol.



:- object('PatientSetupInteractionManager'(_MosaiqImagingDataForEquatorService)).

:- initialization((
	   this(MosaiqImagingDataForEquatorService),
	   implements_protocol(MosaiqImagingDataForEquatorService,
						   'IMosaiqImagingForEquatorService')
	   )).

:- end_object.



:- object('DiagnosisInteractionManager').

:- end_object.



:- object('MosaiqImagingForEquatorService',
		  implements('IMosaiqImagingDataForEquatorService')).

:- end_object.



:- object('WorkflowTaskManager').

:- end_object.





