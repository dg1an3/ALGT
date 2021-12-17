%% Copyright 2021 Derek Lane
%%
%% image_import_manager represents an image import service as an
%% IDesign-compliant service

:- object(image_import_manager(_ImageImportEngine)),
			implements([iimage_import_manager])).
    :- public([import_legacy_image/2]).


	:- info([version is 1:0:0,
		author is 'Derek Lane',
		date is 2021-12-14,
		comment is 'implementation of an IDesign-compliant image import service.'
	]).


	%!	import_legacy_image(Request, Response) is det
	%
	%	perform import and reply

    import_legacy_image(request(R), response(R)) :-
	    this(image_import_manager(ImageImportEngine)),
		ImageImportEngine::import_image(request(Id, R), Response),
		Response = true.


	%! inject(ImageEngine) is det
	%
	% check that injected engine implements the import engine interface

	inject(ImageEngine) :-
		this(image_import_manager(ImageImportEngine)),
		implements_protocol(ImageEngine,
			iimage_import_engine))).

:- end_object.

