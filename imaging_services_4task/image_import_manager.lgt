%% Copyright Derek Lane
%%
%%

:- object(image_import_manager(_ImageImportEngine)).
    :- public([import_legacy_image/2]).

    import_legacy_image(request(R), response(R)) :-
	    this(image_import_manager(ImageImportEngine)),
		ImageImportEngine::import_image(request(Id, R), Response),
		Response = true.

:- end_object.


