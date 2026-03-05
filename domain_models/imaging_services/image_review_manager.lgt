%% Copyright Derek Lane
%%
%%

:- object(image_review_manager(_ImageLoadEngine)).
    :- public([get_viewer_data/2]).

    get_viewer_data(request(Id),
					response(viewer_data{image:Image})) :-
	    this(image_review_manager(ImageLoadEngine)),
		ImageLoadEngine::load_image(request(Id), response(Image)).

:- end_object.




