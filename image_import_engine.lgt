%  Copyright 2021 Derek Lane
%
%  image_import_manager represents an image import service as an
%  IDesign-compliant service
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

:- object(image_import_engine(_ProjectionImageDataAccess,
							  _GraphicalObjectDataAccess),
		  implements([iimage_import_engine])).

    :- public([import_image/2]).

    :- initialization((this(ProjectionImageDataA,
							GraphicalObjectDA),

					   implements_protocol(ProjectionImageDataA,
										   iprojection_image_data_access),
					   implements_protocol(GraphicalObjectDA,
										   igraphical_object_data_access))).

    import_image(request(DicomDataset), response(Ok)) :-
	    this(ProjectionImageDataAccess, GraphicalObjectDA),

		dicomToProjectionImage(DicomDataset, ProjectionImage),
		ProjectionImageDataAccess::write_image(ProjectionImage),
		GraphicalObjectDA::write_graphical_object(_),
		Ok = true.

:- end_object.











