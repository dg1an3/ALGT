%% Copyright 2021 Derek Lane
%%
%% image_import_engine represents an IDesign engine for importing
%% 2D images

:- object(image_import_engine(_ProjectionImageDataAccess,
							  _GraphicalObjectDataAccess),
		  implements([iimage_import_engine])).
    :- public([import_image/2]).

    import_image(request(DicomDataset), response(Ok)) :-
	    ::inject(ProjectionImageDataAccess, 
			GraphicalObjectDataAcces),

		dicom_to_projection_image(DicomDataset, ProjectionImage),
		ProjectionImageDataAccess::write_image(ProjectionImage),
		GraphicalObjectDataAccess::write_graphical_object(_),
		Ok = true.

	inject(ProjectionImageDataAccess, 
				GraphicalObjectDataAccess) :-
		this(ProjectionImageDataAccess, 
				GraphicalObjectDataAccess),
		
		implements_protocol(ProjectionImageDataAccess,	
								iprojection_image_data_access),
		implements_protocol(GraphicalObjectDataAccess,
								igraphical_object_data_access).

:- end_object.

