%  Copyright 2021 Derek Lane
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


:- initialization(
	logtalk_load([contracts,
				  image_review_manager,
				  image_import_manager,

				  image_import_engine,
				  image_load_engine,
				  image_association_engine,

				  projection_image_data_access,
				  graphical_object_data_access,

				  event_store])).
