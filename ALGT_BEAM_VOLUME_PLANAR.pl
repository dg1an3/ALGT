:- consult(pl/geom).
:- consult(pl/vrml).
:- consult(pl/io_basics).

:- set_prolog_flag(optimise, true).

%% ok_beam_plane_intersect/5
%%
%% predicate that asserts that PlanesWithPolys is a collection of polygons 
%% that is the intersection of Mesh with the corresponding Plane.

ok_beam_plane_intersect(PlanesWithPolys, Thickness, Mesh) :-

      	%% assert that the volume of the intersections is correct
	ok_beam_intersect_volume(PlanesWithPolys, Thickness, Mesh),
	format_log('    Beam intersection volume OK~n', []),

	%% assert that all polygons on a plane are in the correct position
	forall(member([Plane, Poly], PlanesWithPolys),
	       ok_beam_intersect_pos(Poly, Mesh, Plane)),
	format_log('    Beam intersection position OK~n', []).
	

%% ok_mesh_plane_intersect_pos/5
%%
%% predicate that asserts that Polys is the intersection of Mesh and Plane,
%% based on correct position.

ok_beam_intersect_pos(Poly, Mesh, Plane) :-

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
		     format_log('    **** Vertex failed with mesh distance ~f ~n', 
			    [DistMesh]),
		     dist_point_plane(Vert, Plane, DistPlane),
		     format_log('    **** Vertex failed with plane distance ~f ~n', 
			    [DistPlane]),

		     %% and fail test
		     fail
	       )).

%% ok_mesh_intersect_volume/3
%%
%% predicate that asserts that Polys is the intersection of Mesh and Plane,
%% based on correct volume

ok_beam_intersect_volume(PlanesWithPolys, Thickness, Mesh) :-
	
	%% compute the volume of the original mesh
	mesh_volume(Mesh, MeshVolume),

	%% form the set of all volumes of individual slices
	findall(PolyVolume, 
		(    %% extract the collection of polygons on a given plane
		     member([Plane , Poly], PlanesWithPolys),

		     %% volume = area * thickness
		     poly_area(Poly, Plane, PolyArea),
		     PolyVolume is Thickness * PolyArea
		),
		SliceVolumes),

	%% total volume is sum of slice volumes
	sumlist(SliceVolumes, TotalSliceVolume),

	%% output the computed slice thickness
	format_log('    Slice Thickness = ~f ~n', [Thickness]),

	%% output volume statistics
        format_log('    Slice Volume = ~f ~n', [TotalSliceVolume]), 
	format_log('    Mesh Volume = ~f ~n', [MeshVolume]), 
	
	%% condition is met if two volume are within tolerance
	flag(volume_tolerance, Epsilon, Epsilon),
	is_approx_equal(MeshVolume, TotalSliceVolume, Epsilon).


%% test case execution

:- open_log,
	format_log('~n~n**** Test case 4.2.9: ALGT_BEAM_VOLUME_PLANAR ****~n', []),

 	read_string('    Patient / Study / Beam Name', _), % Ident),

	VolumeBoundsMax is 1500,
	VolumeBoundsMin is -VolumeBoundsMax,

	read_string('    Plan LOID', Loid),
	read_number('    Beam Number', Beam_Number),
	read_number('    Offset (mm)', Offset),
	Count is VolumeBoundsMax * 2 / Offset,

	%% get the plane normal
	format_log('    Plane Normal (mm, in DICOM Patient coord sys): ', []), 
	read(Normal),
	format_log('~p~n', [Normal]),

	vec_norm(Normal, Normal_unit),

	%% form the image row and column vectors
	member(Axis, [[1, 0, 0], [0, 1, 0], [0, 0, 1]]),
	cross_prod(Normal_unit, Axis, RowVector),
	vec_length(RowVector, RowLength),
	RowLength > 0.1,
	vec_norm(RowVector, [Xr, Yr, Zr]),

	cross_prod(Normal_unit, [Xr, Yr, Zr], ColVector),
	vec_length(ColVector, ColLength),
	ColLength > 0.1, !,
	vec_norm(ColVector, [Xc, Yc, Zc]),

	%% form the plane origin
	scalar_prod(VolumeBoundsMin, Normal_unit, [Xn, Yn, Zn]),

	%% form the command string for the execution
	sformat(Args, '-L ~s -B ~d -C ~d -O ~f -P ~f ~f ~f ~f ~f ~f ~f ~f ~f',
		[Loid, Beam_Number, Count, Offset, 
		 Xn, Yn, Zn,
		 Xr, Yr, Zr, Xc, Yc, Zc]),
	sformat(Cmd, '../bin/ALGT_BEAM_VOLUME_PLANAR.exe ~s', [Args]),

	%% put files in temp directory
	chdir('temp'),

	%% shell the command
        shell(Cmd, _),

	%% done with directory
	chdir('..'),
		
	%% prepare the intersection polygons

	%% read and parse the file
	format_log('    Reading polygons...', []),
	read_file_to_codes('temp/ALGT_BEAM_VOLUME_PLANAR_format1.dat', C_planes, []),
	phrase(format1_file(Polys), C_planes),
	format_log('done.~n', []),

	%% form planes
	planes_with_polys(Polys, Normal_unit, PlanesWithPolys),

	%% orient the polygons
	orient_polys(PlanesWithPolys, OrientedPlanesWithPolys),

	%% assert in to database
	assert(current_polys(OrientedPlanesWithPolys)),

	%% prepare the mesh

	%% read and parse the file
	format_log('    Reading mesh...', []),
	read_file_to_codes('temp/ALGT_BEAM_VOLUME_PLANAR_format2.wrl', C_meshes, []),
	phrase(vrml_file(Verts, _, IFCVerts, _), C_meshes),
	format_log('done.~n', []),

	%% convert to internal mesh format
	format_log('    Testing beam mesh orientation...~n', []),
	(   
	vrmlmesh_oriented(IFCVerts),
	    IFCVerts_or = IFCVerts,
	    format_log('    Mesh is oriented~n', []) ;
	format_log('    Mesh is not oriented -- orienting...~n', []),
	    vrmlmesh_orient(IFCVerts, [], IFCVerts_or),
	    format_log('    done.~n', [])
	),
	vrmlmesh_is_mesh([Verts, IFCVerts_or], Mesh),

	%% output statistics on original mesh
	write_mesh_stats('Original', [Mesh]),

	%% assert in to database
	assert(current_mesh(Mesh)),

	%% check that the mesh lies within the proscibed bounds
	(   mesh_bounds(Mesh, [Xmin, Ymin, Zmin], [Xmax, Ymax, Zmax]),
	    Xmin > VolumeBoundsMin, 
	    Ymin > VolumeBoundsMin, 
	    Zmin > VolumeBoundsMin,
	    Xmax < VolumeBoundsMax, 
	    Ymax < VolumeBoundsMax, 
	    Zmax < VolumeBoundsMax ;
	format('**** Mesh exceeds pre-defined bounding volume **** ~n'), fail
	),

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

	ok_beam_plane_intersect(OrientedPlanesWithPolys, Offset, Mesh),

	% end test
	write_test_time('ends'),

	%% remove from database
	retract(current_polys(OrientedPlanesWithPolys)),
      	retract(current_mesh(Mesh)),

	format_log('**** TEST ALGT_BEAM_VOLUME_PLANAR PASSED ****~n~n~n~n', []),
	close_log.

























