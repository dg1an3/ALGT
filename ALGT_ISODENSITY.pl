%% ALGT_ISODENSITY Test Case 4.2.7
%% 
%% Verification test of the DWS isodensity algorithm.
%%
%% Copyright (C) 2003 DG Lane

:- consult(pl/geom).
:- consult(pl/dicom_objects).
:- consult(pl/io_basics).

:- set_prolog_flag(optimise, true).

%% ok_margin2D/3
%%
%% asserts that the passed polygons are correctly margined

ok_isodensity(Img_obj, SSet_obj, ROI_Number, Thresh) :-

	%% form the scan lines for the image
	dcm_pixel_conv(Img_obj, Scanlines),

	%% extrace the imag plane information
	dcm_image_plane(Img_obj, [Origin, Row_dir, Col_dir]),
	format('Image plane = ~p, row = ~p, col = ~p~n', [Origin, Row_dir, Col_dir]),

	format('    Computing crossing sets...~n'),

	%% form the X-direction crossings
	crossings(Scanlines, Origin, Row_dir, Col_dir, Thresh,
		  RowCrossSet),
       
	%% transpose and form Y-direction crossings
	transpose(Scanlines, Scanlines_transposed),
	crossings(Scanlines_transposed, Origin, Col_dir, Row_dir, Thresh, 
		  ColCrossSet),

	%% combine crossing sets
	append(RowCrossSet, ColCrossSet, CrossSet), !,

	%% output length of crossing set
	length(CrossSet, CxLen),
	format_log('    ~d crossings found on image~n', [CxLen]),
	%% format('Crossings ~p ~n', [CrossSet]),

	%% obtain contour
	dcm_contour_conv(SSet_obj, ROI_Number, Polys),

	%% find the contour that lies on the image plane
	member(Poly, Polys),
	[[_, _, Z] | _] = Poly,
	[_, _, Z] = Origin, !,

	%% output polygon information
	length(Poly, VertCount),
	format_log('    Found poly at ~f, consisting of ~d vertices ~n', [Z, VertCount]),

	flag(positional_tolerance, Epsilon, Epsilon), 

	forall(member(Vert, Poly),
	       (   
	       format('    Testing vertex ~p ~n', [Vert]),
		   
		   findall(Dist,
			  (   
			  member(CrossPoint, CrossSet),
			      dist_point_point(Vert, CrossPoint, Dist)
			  ),
			   Dists),
		   min(Dists, Dist),
		   
		   (   
		   Dist < Epsilon, ! ;
		   
		   format_log('    **** Vertex ~p failed, distance ~p ~n', 
			      [Vert, Dist]),
		       
		       get_yn ;
		   
		   fail
		   )
	       )).
	

crossings(Scanlines, Origin, Row_dir, Col_dir, Thresh, CrossingSet) :-

	findall(CrossingPosition,
		(  
		nth0(N_scan, Scanlines, Scanline),
		nth0(N_pix1, Scanline, Value1),

		succ(N_pix1, N_pix2),
		nth0(N_pix2, Scanline, Value2),

		%% see if we have crossed the threshold
		(   Value1 =< Thresh,
		    Value2 > Thresh ;
		Value1 > Thresh,
		    Value2 =< Thresh ),

		%% pixel position is halfway between two pixels
		N_pix_at is (N_pix1 + N_pix2) / 2.0,

		scalar_prod(N_pix_at, Row_dir, Row_offset),
		scalar_prod(N_scan, Col_dir, Col_offset),
		
		vec_sum(Origin, Row_offset, Temp),
		vec_sum(Temp, Col_offset, CrossingPosition)
		),
		CrossingSet).

%% test case execution

:- open_log,

	format_log('**** Test case 4.2.7: ALGT_ISODENSITY ****~n', []),

 	read_string('    Patient / Study / ROI Name', _),

	read_string('    DICOM Image File Name', ImgFileName),
	read_string('    StructureSet File Name', SSetFileName),
	read_number('    ROI Number', ROI_Number),
	read_number('    Threshold', Thresh),
		
	%% read image
	string_to_atom(ImgFileName, ImgFileNameAtom),
	read_file_to_codes(ImgFileNameAtom, C_img, [type(binary)]),
	phrase(dcm_file(Img_file), C_img),
	dcm_conv_values(Img_file, Img_obj),

	%% read SSet
	string_to_atom(SSetFileName, SSetFileNameAtom),
	read_file_to_codes(SSetFileNameAtom, C_sset, [type(binary)]),
	phrase(dcm_file(SSet_file), C_sset),
	dcm_conv_values(SSet_file, SSet_obj), 

	repeat,

	% obtain testing parameters
	format_log('~n', []),
	read_number('    Positional Tolerance (+/- mm)', Epsilon),
	flag(positional_tolerance, _, Epsilon), !,

	% begin test
	write_test_time('begins'),

	ok_isodensity(Img_obj, SSet_obj, ROI_Number, Thresh),

	% begin test
	write_test_time('ends'),

	format_log('**** TEST ALGT_ISODENSITY COMPLETED ****~n~n~n~n', []),
	close_log.










