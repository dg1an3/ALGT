%% ALGT_MESH_GEN Test Case 4.2.2
%% 
%% Verification test of the DWS meshing algorithm.
%%
%% Copyright (C) 2003 DG Lane

:- consult(pl/geom).
:- consult(pl/vrml).
:- consult(pl/io_basics).

:- set_prolog_flag(optimise, true).


%% ok_mesh_gen/2
%%
%% predicate that asserts that PlanesWithPolys is a collection of polygons 
%% that is the intersection of Mesh with the corresponding Plane.

ok_mesh_gen(PlanesWithPolys, Mesh, IFCVerts) :-

/*	format_log('    Testing mesh orientation...~n', []),
	vrmlmesh_oriented(IFCVerts),
	format_log('    Mesh is correctly oriented~n', []),

      	%% assert that the volume of the intersections is correct
	ok_mesh_gen_volume(PlanesWithPolys, Mesh),
	format_log('    Mesh volume is within tolerance~n', []),
*/
	%% assert that all polygons on a plane are in the correct position
	forall(member([Plane, Poly], PlanesWithPolys),
	       ok_mesh_gen_pos(Poly, Mesh, Plane)),
	format_log('    Mesh position is within tolerance~n', []).
	

%% ok_mesh_intersect_volume/3
%%
%% predicate that asserts that Polys is the intersection of Mesh and Plane,
%% based on correct volume

ok_mesh_gen_volume(PlanesWithPolys, Mesh) :-
	
	%% compute the volume of the original mesh
	mesh_volume(Mesh, MeshVolume),

	%% form the set of all volumes of individual slices
	findall(PolyVolume, 
		(    %% extract the collection of polygons on a given plane
		     select([Plane , Poly], PlanesWithPolys, RemainingPlanesWithPolys),

		     %% volume = area * thickness
		     poly_area(Poly, Plane, PolyArea),
									   
		     %% pick a point on the polygon
		     nth0(0, Poly, Vert),
			
		     %% find the minimum distance from the point to the other planes
		     findall(Distance,
			     (	 
			     member([OtherPlane, _], RemainingPlanesWithPolys),

				 dist_point_plane(Vert, OtherPlane, Distance),
				 Distance > 1e-6
			     ),
			     Distances),
		     min(Distances, Thickness),

		     %% compute volume for this polygon
		     PolyVolume is Thickness * PolyArea
		),
		SliceVolumes),

	%% total volume is sum of slice volumes
	sumlist(SliceVolumes, TotalSliceVolume),

	%% output volume statistics
        format_log('    Slice Volume = ~f ~n', [TotalSliceVolume]), 
	format_log('    Mesh Volume = ~f ~n', [MeshVolume]), 
	
	%% condition is met if two volume are within tolerance
	flag(volume_tolerance, Epsilon, Epsilon),
	is_approx_equal(MeshVolume, TotalSliceVolume, Epsilon).


%% ok_mesh_gen_pos/3
%%
%% predicate that asserts that Polys is the intersection of Mesh and Plane,
%% based on correct position.

ok_mesh_gen_pos(Poly, Mesh, Plane) :-

	flag(positional_tolerance, Epsilon, Epsilon),

	%% assert for all polygons in the set
	forall(member(Vert, Poly),
	       (     skip_sample, !;

	             %% output the vertex being tested
		     format('Testing vertex ~p ~n', [Vert]),
		     
	             %% each point is both on the mesh
	             point_on_mesh(Vert, Mesh, Epsilon),

		     %% and on the plane
		     point_on_plane(Vert, Plane, Epsilon), ! ;

	       %% failure, so output failure statistics
	       dist_point_mesh(Vert, Mesh, DistMesh),
		     dist_point_plane(Vert, Plane, DistPlane),
		     format_log('    **** Vertex ~p failed', [Vert]),
		     format_log('with mesh dist ~f, plane dist ~f~n', [DistMesh, DistPlane]),

		     %% ask user if we should continue
		     format('continue (y/n)? '), get_single_char("y") ;

	       %% otherwise fail test
	       fail
	       )).


%% test case execution

:- open_log,

	format_log('~n~n**** Test case 4.2.2: ALGT_MESH_GEN ****~n', []),

 	read_string('    Patient / Study / ROI Name', _),

	read_string('    StructureSet LOID', Loid),
	read_number('    ROI Number', ROI_Number),

	%% form the command string for the execution
	sformat(Args, '-S ~s -R ~d',
		[Loid, ROI_Number]),
	sformat(Cmd, '../bin/ALGT_MESH_GEN.exe ~s', [Args]),

	%% put files in temp directory
	chdir('temp'),

	%% shell the command
        shell(Cmd, _),

	%% done with directory
	chdir('..'),
		
	%% prepare the original contours

	%% read and parse the file
	format_log('~n    Reading contours...', []),
	read_file_to_codes('temp/ALGT_MESH_GEN_format1.dat', C_planes, []),
	phrase(format1_file(Polys), C_planes),
	format_log('done.~n', []),

	%% form planes
	planes_with_polys(Polys, [0, 0, 1], PlanesWithPolys),

	%% orient the polygons
	orient_polys(PlanesWithPolys, OrientedPlanesWithPolys),

	%% output statistics on polygons
	write_poly_stats('Contours', Polys),

	%% assert in to database
	assert(current_polys(OrientedPlanesWithPolys)),

	%% prepare the mesh

	%% read and parse the file
	format_log('~n    Reading meshes...', []),
	read_file_to_codes('temp/ALGT_MESH_GEN_format2.wrl', C_meshes, []),
	phrase(vrml_file(Verts, _, IFCVerts, _), C_meshes),
	format_log('done.~n', []),

	%% convert to internal mesh format
	vrmlmesh_is_mesh([Verts, IFCVerts], Mesh),

	%% output statistics on original mesh
	write_mesh_stats('Mesh', [Mesh]),

	%% assert in to database
	assert(current_mesh(Mesh)),

	repeat,

	% obtain testing parameters
	format_log('~n', []),
	read_number('    Sample Rate (%)', SampleRate),
	flag(sample_rate, _, SampleRate),

	read_number('    Positional Tolerance (+/- mm)', EpsPos),
	flag(positional_tolerance, _, EpsPos),
	read_number('    Volume Tolerance (+/- mm^3)', EpsVol),
	flag(volume_tolerance, _, EpsVol),

	% begin test
	write_test_time('begins'),

	ok_mesh_gen(OrientedPlanesWithPolys, Mesh, IFCVerts),

	% end test
	write_test_time('ends'),

	%% remove from database
	retract(current_polys(OrientedPlanesWithPolys)),
      	retract(current_mesh(Mesh)),

	format_log('**** TEST ALGT_MESH_GEN PASSED ****~n~n~n~n', []),
	close_log.

























