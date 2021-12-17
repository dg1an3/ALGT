%% ALGT_SSD Case 4.2.7
%% 
%% Verification test of the DWS beam SSD calculation
%%
%% Copyright (C) 2003 DG Lane

:- consult(pl/geom).
:- consult(pl/vrml).
:- consult(pl/io_basics).
:- consult(pl/coord_sys).

:- set_prolog_flag(optimise, true).

%% ok_ssd/3
%%
%% predicate that asserts the computed SSD is corect

ok_ssd(Beam, Mesh, SSD) :-

	member([gantryAngle, GantryAngle], Beam),
	format_log('    Gantry angle = ~p ~n', [GantryAngle]),
	member([couchAngle, CouchAngle], Beam),
	format_log('    Couch angle = ~p ~n', [CouchAngle]),

	transform_from(Beam, iecBeam, dicomPatient, Xform),
	mat_prod(Xform, [[0,0,0,1]], [SourcePos_hg]),
	mat_prod(Xform, [[0,0,-1,0]], [SourceDir_hg]),
	
	append(SourcePos, [_], SourcePos_hg),
	format_log('    Source Position (DICOM Patient CS) = ~p~n', [SourcePos]),
	append(SourceDir, [_], SourceDir_hg),
	format_log('    Source Dir (DICOM Patient CS) = ~p~n', [SourceDir]),

	ray_mesh_intersect([SourcePos, SourceDir], Mesh, Intersect),
	format_log('    Intersection point at = ~p ~n', [Intersect]),

	vec_diff(SourcePos, Intersect, Offset),
	vec_length(Offset, ComputedSSD),

	format_log('    Computed SSD = ~p ~n', [ComputedSSD]),
	format_log('    Test SSD = ~p ~n', [SSD]),

	flag(positional_tolerance, EpsPos, EpsPos),
	is_approx_equal(SSD, ComputedSSD, EpsPos),

	format_log('    SSD value is OK~n', []).


%% test case execution

:- open_log,

	format_log('~n~n**** Test case 4.2.7: ALGT_SSD ****~n', _),

	read_string('    Patient / Study / Beam', _),

	read_string('    Plan LOID', Loid),
	read_number('    Beam Number', Beam_Number),

	%% form the command string for the execution
	sformat(Args, '-p ~s -b ~d', [Loid, Beam_Number]),
	sformat(Cmd, '../bin/ALGT_SSD.exe ~s', [Args]),

	%% put files in temp directory
	chdir('temp'),

	%% shell the command
        shell(Cmd, _),

	%% done with directory
	chdir('..'),
		
	%% prepare the intersection polygons

	%% read and parse the parameter file
	format_log('~n    Reading parameters...', []),
	read_file_to_codes('temp/ALGT_SSD.dat', C_beam, []),
	phrase(format3_parameters(Beam), C_beam),
	format_log('done.~n', []),

	%% assert in to database
	assert(current_beam(Beam)),

	%% prepare the mesh

	%% read and parse the file
	format_log('~n    Reading surface mesh...', []),
	read_file_to_codes('temp/ALGT_SSD_Ext1_format2.wrl', C_surf, []),
	phrase(vrml_file(Verts, _, IFCVerts, _), C_surf),
	format_log('done.~n', []),

	%% convert to internal mesh format
	vrmlmesh_is_mesh([Verts, IFCVerts], Mesh),

	%% output statistics on original mesh
	write_mesh_stats('Surface', [Mesh]),

	%% assert in to database
	assert(current_mesh(Mesh)),

	repeat,

	% obtain testing parameters
	format_log('~n', []),
	read_number('    Positional Tolerance', EpsPos),
	flag(positional_tolerance, _, EpsPos),

	% begin test
	write_test_time('begins'),

	member(['SSD', SSD], Beam),
	ok_ssd(Beam, Mesh, SSD),

	% end test
	write_test_time('ends'),

	%% remove from database
	retract(current_beam(Beam)),
      	retract(current_mesh(Mesh)),

	format_log('**** TEST ALGT_SSD PASSED ****~n', []),

	close_log.

























