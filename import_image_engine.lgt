%% Copyright Derek Lane
%%
%%

:- object(import_image_engine(_ProjectionImageDataAccess)).
    :- public([import_image/2]).

    import_image(request(Id, Image), Response) :-
	    this(import_eng(ProjectionImageDataAccess)),
		ProjectionImageDataAccess::write_image(request(Id, Image), Response).

:- end_object.
