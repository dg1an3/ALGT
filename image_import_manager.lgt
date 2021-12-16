%  Copyright 2021 Derek Lane
%
%  image_import_manager represents an image import service as an
%  IDesign-compliant service
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

:- object(image_import_manager(_ImportEngine),
		  implements([iimage_import_manager])).

:- info([
	   version is 1:0:0,
	   author is 'Derek Lane',
	   date is 2021-12-14,
	   comment is 'implementation of an IDesign-compliant image import service.'
   ]).

:- public([import_legacy_image/2]).


%!	initialization(Check) is det
%
%	check that injected engine implements the import engine interface

:- initialization((this(ImageEngine),
				   implements_protocol(ImageEngine,
									   iimage_import_engine))).

%!	import_legacy_image(Request, Response) is det
%
%	perform import and reply

import_legacy_image(request(DicomDataset), response(Ok)) :-
	this(ImportEngine),
	ImportEngine::import_image(DicomDataset),
	Ok = true.

:- end_object.








