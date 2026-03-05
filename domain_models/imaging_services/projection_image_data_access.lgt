%% Copyright 2021 Derek Lane
%%
%% projection_image_data_accesss is an IDesign resource access service
%% that represents a 2d (projection) image 

:- object(projection_image_data_access(_EventStore),
			implements(iprojection_image_data_access)).
    :- public([read_image/2,
			   write_image/2]).

    read_image(request(Id), response(Image)) :-
	    inject(EventStore),
		EventStore::event(created(image(Id), Image)).

    write_image(request(Id, Image), response(Status)) :-
	    inject(EventStore),
		EventStore::event(created(image(Id), Image)),
		Status = true.

	inject(EventStore) :-
		this(projection_image_data_access(EventStore)),
		implements_protocol(EventStore, iievent_store).

:- end_object.
