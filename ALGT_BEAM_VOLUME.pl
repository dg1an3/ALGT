%% ALGT_BEAM_VOLUME Test Case 4.2.8
%% 
%% Verification test of the DWS beam volume generation algorithm.
%%
%% Copyright (C) 2003 DG Lane

:- consult(pl/geom).
:- consult(pl/vrml).
:- consult(pl/io_basics).

:- set_prolog_flag(optimise, true).


%% ok_beam_volume/3
%%
%% 

ok_beam_volume(Beam, Polys, Mesh) :-

      	%% assert that the beam shape is correctly reflected by the mesh
	ok_beam_volume_pos(Polys, Mesh),
	format_log('    Beam volume positions ok.~n', []),

	%% assert that the mesh has the correct divergence
	ok_beam_volume_div(Polys, Mesh),
	format_log('    Beam volume divergence ok.~n', []),

	%% assert that the mesh has the correct volume
	ok_beam_volume_vol(Beam, Polys, Mesh),
	format_log('    Beam volume volume ok.~n', []).


%% ok_beam_volume_pos/2
%%
%% predicate that asserts that Polys is the intersection of Mesh and Plane,
%% based on correct position.

ok_beam_volume_pos(Polys, Mesh) :-

	flag(positional_tolerance, Epsilon, Epsilon),

	%% assert for all polygons in the set
	forall((member(Poly, Polys), member(Vert, Poly)),
	       (     skip_sample, !;

	             %% output the vertex being tested
		     format('    Testing vertex ~p ~n', [Vert]),
		     
	             %% each point is both on the mesh
	             point_on_mesh(Vert, Mesh, Epsilon), ! ;

	       %% failure, so output failure statistics
	       dist_point_mesh(Vert, Mesh, DistMesh),
		     format_log('    **** Vertex ~p failed with mesh distance ~f ~n', 
			    [Vert, DistMesh]),
		     
		     get_yn ;

	       %% otherwise fail test
	       fail
	       )).

%% ok_beam_volume_div/3
%%
%% predicate that asserts that Polys is the intersection of Mesh and Plane,
%% based on correct volume

ok_beam_volume_div(Polys, Mesh) :-

	%% get the positional tolerance
	flag(positional_tolerance, Epsilon, Epsilon),

	%% for all facets in the mesh,
	forall(member(Facet, Mesh),
	       (   
	       %% form the plane for the facet
	       facet_plane(Facet, Plane),

		   (   
		   %% see if the plane is perp to central axis
		   [_, Normal] = Plane,
		       dot_prod(Normal, [0, 0, -1], Dot),
		       Dot_abs is abs(Dot),
		       is_approx_equal(Dot_abs, 1.0, Epsilon), ! ;
		   
		   %% not perp plane, so check divergence with source point
		   point_on_plane([0,0,0], Plane, Epsilon),
		       
		   %% check divergence with polygon segment
		   member(Poly, Polys),
		       nextto_wrap(V1, V2, Poly),
		       point_on_plane(V1, Plane, Epsilon),
		       point_on_plane(V2, Plane, Epsilon)
		   )
	       )).
	       
%% ok_beam_volume_vol/3
%%
%% predicate that asserts that Polys is the intersection of Mesh and Plane,
%% based on correct volume

ok_beam_volume_vol(Beam, Polys, Mesh) :-

	findall(PolyArea,
		(   member(Poly, Polys),
		    nth0(0, Poly, Orig),
		    poly_area(Poly, [Orig, [0, 0, -1]], PolyArea)
		),
		PolysAreas),
	sumlist(PolysAreas, TotalArea),

	member(['SAD', SAD], Beam),
	member(['SBLDD', SBLDD], Beam),
	member(['SID', SID], Beam),

	PolyProjVolume is TotalArea * (SID * SID - SBLDD * SBLDD) / (2.0 * SAD),

	%% output volume statistics
        format_log('    Projected Polygon Volume = ~f ~n', [PolyProjVolume]),

	%% compute the volume of the original mesh
	mesh_volume(Mesh, MeshVolume),

	format_log('    Mesh Volume = ~f ~n', [MeshVolume]),
	
	%% condition is met if two volume are within tolerance
	flag(volume_tolerance, Epsilon, Epsilon),
	is_approx_equal(MeshVolume, PolyProjVolume, Epsilon).


%% test case execution

:- open_log,

	format_log('**** Test case 4.2.8: ALGT_BEAM_VOLUME ****~n', []),

 	read_string('    Patient / Study / Beam Name', _), % Ident),

	read_string('    Plan LOID', Loid),
	read_number('    Beam Number', Beam_Number),

	%% form the command string for the execution
	sformat(Args, '-p ~s -b ~d', [Loid, Beam_Number]),
	sformat(Cmd, '../bin/ALGT_BEAM_VOLUME.exe ~s', [Args]),

	%% put files in temp directory
	chdir('temp'),

	%% shell the command
        shell(Cmd, _),

	%% done with directory
	chdir('..'),
		
	%% prepare the intersection polygons

	%% read and parse the file
	format_log('    Reading polys...', []),
	read_file_to_codes('temp/ALGT_BEAM_VOLUME_format1.dat', C_planes, []),
	phrase(format1_file(Polys), C_planes),
	format_log('    done.', []),

	%% form planes
	planes_with_polys(Polys, [0, 0, -1], PlanesWithPolys),

	%% orient the polygons
	orient_polys(PlanesWithPolys, OrientedPlanesWithPolys),

	%% strip off planes
	transpose(OrientedPlanesWithPolys, [_, OrientedPolys]),

	%% assert in to database
	assert(current_polys(OrientedPolys)),

	%% prepare the mesh

	%% read and parse the file
	format_log('    Reading volume...', []),
	read_file_to_codes('temp/ALGT_BEAM_VOLUME_format2.wrl', C_meshes, []),
	phrase(vrml_file(Verts, _, IFCVerts, _), C_meshes),
	format_log('    done.', []),

	(   
	format_log('    Checking beam volume orientation...', []),
	    
	    vrmlmesh_oriented(IFCVerts),
	    IFCVerts_or = IFCVerts,
	    format_log('    ok.~n', []) ;

	format_log('~n    Orienting beam volume...', []),
	    vrmlmesh_orient(IFCVerts, [], IFCVerts_or),
	    format_log('    done.~n', [])
	),
	
	%% convert to internal mesh format
	vrmlmesh_is_mesh([Verts, IFCVerts_or], Mesh),

	%% output statistics on original mesh
	write_mesh_stats('Original', [Mesh]),

	%% assert in to database
	assert(current_mesh(Mesh)),

	%% read beam parameters
	format_log('    Reading beam parameters...', []),
	read_file_to_codes('temp/ALGT_BEAM_VOLUME_format3.dat', C_beam, []),
	phrase(format3_parameters(Beam), C_beam, _),
	format_log('    done.', []),

	assert(current_beam(Beam)),

	repeat,

	% obtain testing parameters
	format_log('~n', []),
	read_number('    Sample Rate (%) ', SampleRate),
	flag(sample_rate, _, SampleRate),

	read_number('    Positional Tolerance (mm)', EpsPos),
	flag(positional_tolerance, _, EpsPos),
	read_number('    Volume Tolerance (mm^3)', EpsVol),
	flag(volume_tolerance, _, EpsVol),

	% begin test
	write_test_time('begins'),

	ok_beam_volume(Beam, OrientedPolys, Mesh),

	% end test
	write_test_time('ends'),

	%% remove from database
        retract(current_beam(Beam)),
	retract(current_polys(OrientedPolys)),
      	retract(current_mesh(Mesh)),

	format_log('**** TEST ALGT_BEAM_VOLUME PASSED ****~n~n~n~n', []),
	close_log.

























