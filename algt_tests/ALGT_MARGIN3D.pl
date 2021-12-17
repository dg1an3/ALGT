%% ALGT_MARGIN3D Test Case 4.2.5
%% 
%% Verification test of the DWS 3D margin algorithm.
%%
%% Copyright (C) 2003 DG Lane

:- consult(pl/geom).
:- consult(pl/vrml).
:- consult(pl/io_basics).

:- set_prolog_flag(optimise, true).


%% ok_margin3D/3
%%
%% asserts that MeshExpand is Mesh dilated/eroded by Margin.

ok_margin3D(MeshesExpand, Meshes, Margin) :-

	flag(positional_tolerance, Epsilon, Epsilon),

	format_log('    Testing Expanded -> Original...~n', []),

	%% assert for all vertices in the expanded meshes
	forall((member(MeshExpand, MeshesExpand), 
		member(Facet, MeshExpand),
		member(Vert, Facet)),
	       (   skip_sample, !;
	 
	       format('Testing vertex ~p ~n', [Vert]),

	           %% nearest distance from point to original mesh
	           member(Mesh, Meshes),
		   dist_point_mesh(Vert, Mesh, Distance),

		   (   
		   %% is within tolerance of the margin distance
		   is_approx_equal(Distance, Margin, Epsilon) ; 
		   
		   format_log('    **** Expanded -> Original distance failed', []),
		       format_log('at vertex ~p, dist ~p ~n', [Vert, Distance]), 
		       
		   %% should we continue?
		   get_yn ;

		   %% otherwise, fail test
		   fail
		   )
	       )),

	format_log('    Expanded -> Original OK...~n', []),

	format_log('    Testing Original -> Expanded...~n', []),

	%% assert for all vertices in the original meshes
	forall((member(Mesh, Meshes), 
		member(Facet, Mesh),
		member(Vert, Facet)),
	       (   skip_sample, !;
	 
	       format('Testing vertex ~p ~n', [Vert]),

	           %% nearest distance from point to original mesh
	           member(MeshExpand, MeshesExpand),
		   dist_point_mesh(Vert, MeshExpand, Distance),

		   (   
		   %% is greater than or within tolerance of the margin 
		   %%    distance
		   Distance > Margin - Epsilon ;
		   
		   format_log('    **** Original -> Expanded distance failed', []),
		       format_log('at vertex ~p, dist ~p ~n', [Vert, Distance]), 
		       
		   %% should we continue?
		   get_yn ;
		   
		   %% otherwise, fail test
		   fail
		   )
	       )),
	
	format_log('    Original -> Expanded OK...~n', []),

	%% assert that the expanded (contracted) mesh volume 
	maplist(mesh_volume, Meshes, MeshVolumes),
	sumlist(MeshVolumes, MeshVolume),
	format_log('    Original mesh volumes: ~p ~n', [MeshVolume]),

	maplist(mesh_volume, MeshesExpand, ExpVolumes),
	sumlist(ExpVolumes, ExpVolume),
	format_log('    Expanded mesh volumes: ~p ~n', [ExpVolume]),

	%% is greater (less than) than the original, depending on sign of
	%%     margin
	(   Margin > 0.0, ExpVolume > MeshVolume ;
	    ExpVolume < MeshVolume ),

	format_log('    Mesh Volumes OK~n', []).


kernel_radius([Xp, Xm, Yp, Ym, Zp, Zm], Dir, Radius) :-

	[X, Y, Z] = Dir,
	(   X > 0.0 -> Xa = Xp ; Xa = Xm ),
	(   Y > 0.0 -> Ya = Yp ; Ya = Ym ),
	(   Z > 0.0 -> Za = Zp ; Za = Zm ),
	    
	Radius is sqrt(1.0 / (X*X/(Xa*Xa) + Y*Y/(Ya*Ya) + Z*Z/(Za*Za))).
 
%% test case execution

:- open_log,

	format_log('~n~n **** Test case 4.2.5: ALGT_MARGIN3D ****~n', []),

 	read_string('    Patient / Study / ROI Name', _),

	read_string('    StructureSet LOID', Loid),
	read_number('    ROI Number', ROI_Number),
	read_number('    Margin (mm)', Margin),

	(   Margin >= 0, 
	    ExpandFlag is 1 ;
	Margin < 0,
	    ExpandFlag is 0 ),

	sformat(Cmd, '../bin/ALGT_MARGIN3D.exe -S ~s -R ~d -E ~e -M ~e ~e ~e ~e ~e ~e',
		[Loid, ROI_Number, ExpandFlag,
		 Margin, Margin, Margin, Margin, Margin, Margin]), 

	chdir('temp'),
        shell(Cmd, _),
	chdir('..'),
		
	% read original mesh
	format_log('~n    Reading original mesh...', []),
	read_file_to_codes('temp/ALGT_MARGIN3D_Original_format2.wrl', C, []),
	phrase(vrml_file(MeshesC, _, MeshesCI, _), C),
	vrmlmesh_is_mesh([MeshesC, MeshesCI], Mesh),
	format_log('done.~n', []),

	assert(current_original_mesh(Mesh)),

	% output statistics on original polys
	write_mesh_stats('Original', [Mesh]),

	% read expanded polygons
	format_log('~n    Reading expanded mesh...', []),
	read_file_to_codes('temp/ALGT_MARGIN3D_Expanded_format2.wrl', C_exp, []),
	phrase(vrml_file(Meshes_expC, _, Meshes_expCI, _), C_exp),
	vrmlmesh_is_mesh([Meshes_expC, Meshes_expCI], Mesh_exp),
	format_log('done.~n', []),

	assert(current_expanded_mesh(Mesh_exp)),

	% output statistics on expanded polys
	write_mesh_stats('Expanded', [Mesh_exp]),

	repeat,

	% obtain testing parameters
	format_log('~n', []),
	read_number('    Sample Rate (%)', SampleRate),
	flag(sample_rate, _, SampleRate),
	read_number('    Positional Tolerance (+/- mm)', Epsilon),
	flag(positional_tolerance, _, Epsilon),

	% begin test
	write_test_time('begins'),

	ok_margin3D([Mesh_exp], [Mesh], Margin),

	% begin test
	write_test_time('ends'),

	format_log('**** TEST ALGT_MARGIN3D PASSED ****~n~n~n~n', []),
	close_log.
























