%% Copyright Derek Lane
%%
%%

:- object(projection_image_data_access(_EventStore)).
    :- public([read_image/2,
			   write_image/2]).

    read_image(request(Id), response(Image)) :-
	    this(projection_image_data_access(EventStore)),
		EventStore::event(created(image(Id), Image)).

    write_image(request(Id, Image), response(Status)) :-
	    this(projection_image_data_access(EventStore)),
		EventStore::event(created(image(Id), Image)),
		Status = true.

:- end_object.
