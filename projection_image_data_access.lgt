%  Copyright 2021 Derek Lane
%
%  image_import_manager represents an image import service as an
%  IDesign-compliant service
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


:- object(projection_image_data_access(_ES),
		  implements(iprojection_image_data_access)).
:- public([write_image/2]).

:- initialization((this(EventStore),
				   implements_protocol(EventStore, iievent_store))).

write_image(request(ProjectionImage), response(Id)) :-
	this(EventStore),
	uuid(Id),
	EventStore::emit(created(pida(Id), ProjectionImage)).

:- end_object.







