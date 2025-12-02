%% Copyright Derek Lane
%%
%%

:- object(load_image_engine(_ProjectionImageDataAcccess)).
    :- public([load_image/2]).

    load_image(request(Id), response(Image)) :-
	    this(load_image_engine(ProjectionImageDataAcccess)),
	    ProjectionImageDataAcccess::has_image(Id, Image).

:- end_object.



