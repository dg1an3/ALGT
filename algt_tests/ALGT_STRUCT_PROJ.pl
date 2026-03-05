%% ALGT_STRUCT_PROJ Test Case 4.2.11
%% 
%% Verification test of the DWS structure projection.
%%
%% Copyright (C) 2003 DG Lane

:- consult(pl/geom).
:- consult(pl/vrml).
:- consult(pl/io_basics).
:- consult(pl/coord_sys).

:- set_prolog_flag(optimise, true).


%% ok_struct_proj/3
%%
%% predicate that asserts that Mesh_proj is a projection of Mesh_in
%% through the given beam's perspective projection.

ok_struct_proj(Beam, Mesh_in, Mesh_proj) :-

	flag(positional_tolerance, EpsPos, EpsPos),

	transform_to(Beam, dicomPatient, iecBeam, Xform),
	format_log('    Beam -> DICOM Patient Transform = ~p~n', [Xform]),

	forall( (nth0(N, Mesh_in, Facet_in), nth0(N, Mesh_proj, Facet_proj) ), 
	       (
	       format('Testing facet ~p ~n', [Facet_in]),
		
		mat_hg(Facet_in, Facet_in_hg),
		mat_prod(Xform, Facet_in_hg, Facet_calc_hg),
		mat_hg(Facet_calc, Facet_calc_hg),
		format('Transformed facet ~p ~n', [Facet_calc]),

		   forall((nth0(M, Facet_calc, Vert_calc), nth0(M, Facet_proj, Vert_proj)),
			  ( 
			  %% check the calculated point is within tol of projected point
			  [Xc, Yc, Zc] = Vert_calc,
			    Xpc is Xc / Zc * -1000.0 / 200.0,
			    Ypc is Yc / Zc * -1000.0 / 200.0,
			    [Xp, Yp, _] = Vert_proj,			      
			    format(' Original ~p vs. ~p ~n', [[Xpc, Ypc], [Xp, Yp]]),

			    abs(Xpc - Xp) < EpsPos,
			    abs(Ypc - Yp) < EpsPos, ! ;
			  
			  %% output 
			  format_log('    **** Projection failed at point = ~p, proj = ~p ~n', 
				     [Vert_calc, Vert_proj]),
			    
			  %% shall we continue?
			  get_yn, ! ; 
			  
			  %% otherwise, fail
			  fail			  
			  )
			 )
	       )),

	format_log('    Structure projection positions OK~n', []).


%% test case execution

:- open_log,

	format_log('~n~n**** Test case 4.2.11: ALGT_STRUCT_PROJ ****~n', _),

	read_string('    Patient / Study / Beam', _),

	read_string('    SSet LOID', SSetLoid),
	read_number('    ROI Number', ROI_Number),
	read_string('    Plan LOID', PlanLoid),
	read_number('    Beam Number', Beam_Number),

	%% form the command string for the execution
	sformat(Args, '-s ~s -i ~d -p ~s -b ~d', 
		[SSetLoid, ROI_Number, PlanLoid, Beam_Number]),
	sformat(Cmd, '../bin/ALGT_STRUCT_PROJ.exe ~s', [Args]),

	%% put files in temp directory
	chdir('temp'),

	%% shell the command
        shell(Cmd, _),

	%% done with directory
	chdir('..'),
		
	%% prepare the intersection polygons

	%% read and parse the parameter file
	format_log('    Reading beam parameters...', []),
	read_file_to_codes('temp/ALGT_STRUCT_PROJ_format3.dat', C_beam, []),
	phrase(format3_parameters(Beam), C_beam),
	format_log('done.~n', []),

	%% assert in to database
	assert(current_beam(Beam)),

	%% prepare the mesh

	%% read and parse the file
	format_log('    Reading original mesh...', []),
	read_file_to_codes('temp/ALGT_STRUCT_PROJ_format2.wrl', C_mesh_orig, []),
	phrase(vrml_file(Verts_orig, _, IFCVerts_orig, _), C_mesh_orig),
	format_log('done.~n', []),

	%% convert to internal mesh format
	vrmlmesh_is_mesh([Verts_orig, IFCVerts_orig], Mesh_orig),

	%% output statistics on original mesh
	write_mesh_stats('Original', [Mesh_orig]),

	%% assert in to database
	assert(current_mesh(Mesh_orig)),

	%% read and parse the file
	format_log('    Reading projected mesh...', []),
	read_file_to_codes('temp/ALGT_STRUCT_PROJ_OUTPUT_format2.wrl', C_mesh_proj, []),
	phrase(vrml_file(Verts_proj, _, IFCVerts_proj, _), C_mesh_proj),
	format_log('done.~n', []),

	%% convert to internal mesh format
	vrmlmesh_is_mesh([Verts_proj, IFCVerts_proj], Mesh_proj),

	%% output statistics on original mesh
	write_mesh_stats('Projected', [Mesh_proj]),

	%% assert in to database
	assert(current_mesh_proj(Mesh_proj)),

	repeat,

	% obtain testing parameters
	format_log('~n', []),
	read_number('    Positional Tolerance', EpsPos),
	flag(positional_tolerance, _, EpsPos),

	% begin test
	write_test_time('begins'),

	ok_struct_proj(Beam, Mesh_orig, Mesh_proj),

	% end test
	write_test_time('ends'),

	%% remove from database
	retract(current_beam(Beam)),
      	retract(current_mesh(Mesh_orig)),
      	retract(current_mesh_proj(Mesh_proj)),

	format_log('**** TEST ALGT_STRUCT_PROJ PASSED ****~n~n~n', []),

	close_log.

























