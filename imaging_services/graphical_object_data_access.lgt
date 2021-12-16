


/*
 *
 */

:- object(graphical_object_data_access(_ES),
		  implements(igraphical_object_data_access)).
	:- public([write_graphical_object/2]).

	write_graphical_object(request(GraphicalObject), response(Id)) :-
		uuid(Id),
		this([created(go(Id), GraphicalObject)|_]).

:- end_object.


/*
 *
 */

:- object(event_store(_EventList),
		  implements(ievent_store)).

:- end_object.


:- begin_tests(image_import).

test(import) :-
	EventStore = event_store(EventList),
	Pida = projection_image_data_access(EventStore),
	Goda = graphical_object_data_access(EventStore),
	ImportEng = image_import_engine(Pida, Goda),
	II2DM = image_import_2d_manager(ImportEng),

	Blob = [],
    II2DM::import_image(Blob),

	is_list(EventList).

:- end_tests.















