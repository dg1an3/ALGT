%% ALGT_MARGIN2D Test Case 4.2.4
%% 
%% Verification test of the DWS 2D margin algorithm.
%%
%% Copyright (C) 2003 DG Lane

:- consult(pl/geom).
:- consult(pl/vrml).
:- consult(pl/io_basics).

:- set_prolog_flag(optimise, true).

%% ok_margin2D/3
%%
%% asserts that the passed polygons are correctly margined

ok_margin2D(PolysExpand, Polys, Margin) :-

	flag(positional_tolerance, Epsilon, Epsilon),

	format_log('    Testing Expanded -> Original Distances~n', []),

	%% assert for all vertices in the expanded polygon
	forall((member(PolyExpand, PolysExpand), 
		member(Vert, PolyExpand)), 
	       (    skip_sample, !;

		    format('Testing vertex ~p~n', [Vert]),
	       
		    (  
		    %% assert for each member of poly, min distance from 
		    %%    the point to the original polygon
	            member(Poly, Polys),
	            dist_point_poly(Vert, Poly, Distance),
 
		    %% is within tolerance of the margin distance
		    is_approx_equal(Distance, Margin, Epsilon) ;
		    
		    %% failure, so notify user
		    format_log('    **** Expanded -> Original distance ', []),
			format_log('failed at vertex ~p, dist ~p ~n', [Vert, Distance]),
			
		    %% see if we should continue
		    format('continue (y/n)? '), get_single_char("y") ;
		    
		    %% otherwise fail test
		    fail 
		    )
	       )),

	format_log('    Expanded -> Original Distances OK~n', []),

	format_log('    Testing Original -> Expanded Distances~n', []),

	%% assert for all vertices in the original polygon
	forall((member(Poly, Polys), 
		member(Vert, Poly)), 
	       (    skip_sample, !;
	       
		    format('Testing vertex ~p~n', [Vert]),
	       
		    (      
		    %% assert for each member of poly, min distance from 
		    %%    the point to the original polygon
		    member(PolyExpand, PolysExpand),
			   dist_point_poly(Vert, PolyExpand, Distance),
		    
		    %% is greater than or within tolerance of the margin 
		    %%    distance
		    Distance > Margin - Epsilon ;
		    
		    %% failure, so notify user
		    format_log('    **** Original -> Expanded distance ', []),
			   format_log('failed at vertex ~p, dist ~p ~n', [Vert, Distance]),
			   
		    %% see if we should continue
		    format('continue (y/n)? '), get_single_char("y") ;
		    
		    %% otherwise fail test
		    fail
		    )
	       )),

	format_log('    Original -> Expanded Distances OK~n', []),

	%% assert that the expanded polygon area
	findall(Area, (member(Poly, Polys), poly_area(Poly, [[0,0,0],[0,0,1]], Area)), 
		PolyAreas),
	sumlist(PolyAreas, PolyArea),
	format_log('    Original polygon areas: ~p ~n', [PolyArea]),

	findall(Area, (member(Poly, PolysExpand), poly_area(Poly, [[0,0,0],[0,0,1]], Area)), 
		PolyExpAreas),
	sumlist(PolyExpAreas, ExpArea),
	format_log('    Expanded polygon areas: ~p ~n', [ExpArea]),
		
	%% is greater than the original
	ExpArea > PolyArea,
	format_log('    Polygon Areas OK~n', []).


%% test case execution

:- open_log,

	format_log('**** Test case 4.2.4: ALGT_MARGIN2D ****~n', []),

 	read_string('    Patient / Study / ROI Name', _),

	read_string('    StructureSet LOID', Loid),
	read_number('    ROI Number', ROI_Number),
	read_number('    Z Plane (mm)', Z_plane),
	read_number('    Margin (mm)', Margin),

	sformat(Cmd, '../bin/ALGT_MARGIN2D.exe -S ~s -R ~d -Z ~e -M ~e',
		[Loid, ROI_Number, Z_plane, Margin]), 

	chdir('temp'),
        shell(Cmd),
	chdir('..'),
		
	% read original polygons
	format_log('    Reading original polygons...', []),
	read_file_to_codes('temp/ALGT_MARGIN2D_format1.dat', C, []),
	phrase(format1_file(Polys), C),
	format_log('    done~n', []),

	% output statistics on original polys
	write_poly_stats('Original', Polys),

	% read expanded polygons
	format_log('    Reading expanded polygons...', []),
	read_file_to_codes('temp/ALGT_MARGIN2D_Expanded_Format1.dat', C_exp, []),
	phrase(format1_file(Polys_exp), C_exp),
	format_log('    done~n', []),

	% output statistics on expanded polys
	write_poly_stats('Expanded', Polys_exp),

	repeat,

	% obtain testing parameters
	format_log('~n', []),
	read_number('    Sample Rate (%)', SampleRate),
	flag(sample_rate, _, SampleRate),
	read_number('    Positional Tolerance (+/- mm)', Epsilon),
	flag(positional_tolerance, _, Epsilon),

	% begin test
	write_test_time('begins'),

	ok_margin2D(Polys_exp, Polys, Margin),

	% begin test
	write_test_time('ends'),

	format_log('**** TEST ALGT_MARGIN2D PASSED ****~n~n~n~n', []),
	close_log.










