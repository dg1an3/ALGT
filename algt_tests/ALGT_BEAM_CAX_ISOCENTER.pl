%% ALGT_BEAM_CAX_ISOCENTER Test Case 4.2.10
%% 
%% Verification test of the DWS beam central axis and isocenter positioning
%%
%% Copyright (C) 2003 DG Lane

:- consult(pl/geom).
:- consult(pl/vrml).
:- consult(pl/io_basics).

:- set_prolog_flag(optimise, true).


%% ok_beam_cax_isocenter/4
%%
%% predicate that asserts that PlanesWithPolys is a collection of polygons 
%% that is the intersection of Mesh with the corresponding Plane.

ok_beam_cax_isocenter(Beam, AxisStart, AxisEnd, Isocenter) :-

	flag(positional_tolerance, EpsPos, EpsPos),

	transform_from(Beam, iecBeam, dicomPatient, Xform),
	member(['GantryAngle', GantryAngle], Beam),
	format_log('    Gantry angle = ~p ~n', [GantryAngle]),
	member(['CouchAngle', CouchAngle], Beam),
	format_log('    Couch angle = ~p ~n', [CouchAngle]),

	member(['SBLDD', SBLDD], Beam),
	mat_prod(Xform, [[0,0,-SBLDD,1]], [AxisStart_hg]),
	vec_hg(AxisStart_calc, AxisStart_hg),
	format_log('    AxisStart = ~p, proj = ~p ~n', [AxisStart_calc, AxisStart]),
	dist_point_point(AxisStart, AxisStart_calc, ErrAxisStart),
	abs(ErrAxisStart) < EpsPos,

	member(['SID', SID], Beam),
	mat_prod(Xform, [[0,0,-SID,1]], [AxisEnd_hg]),
	vec_hg(AxisEnd_calc, AxisEnd_hg),
	format_log('    AxisEnd = ~p, proj = ~p ~n', [AxisEnd_calc, AxisEnd]),
	dist_point_point(AxisEnd, AxisEnd_calc, ErrAxisEnd),
	abs(ErrAxisEnd) < EpsPos,

	member(['SAD', SAD], Beam),
	mat_prod(Xform, [[0,0,-SAD,1]], [Isocenter_hg]),
	vec_hg(Isocenter_calc, Isocenter_hg),
	format_log('    Isocenter = ~p, proj = ~p ~n', [Isocenter_calc, Isocenter]),
	dist_point_point(Isocenter, Isocenter_calc, ErrIsocenter),
	abs(ErrIsocenter) < EpsPos,

	format_log('    Beam CAX / Isocenter Position OK', []).


%% test case execution

:- open_log,

	format_log('~n~n**** Test case 4.2.10: ALGT_BEAM_CAX_ISOCENTER ****~n', []),

 	read_string('    Patient / Study / Beam Name', _),

	read_string('    Plan LOID', Loid),
	read_number('    Beam Number', Beam_Number),

	%% form the command string for the execution
	sformat(Args, '-P ~s -b ~d',
		[Loid, Beam_Number]),
	sformat(Cmd, '../bin/ALGT_BEAM_CAX_ISOCENTER.exe ~s', [Args]),

	%% put files in temp directory
	chdir('temp'),

	%% shell the command
        shell(Cmd, _),

	%% done with directory
	chdir('..'),
		
	%% prepare the intersection polygons

	%% read and parse the file
	format_log('~n    Reading beam parameters...', []),
	read_file_to_codes('temp/ALGT_BEAM_CAX_ISOCENTER_format3.dat', C_beam, []),
	phrase(format3_parameters(Beam), C_beam),
	format_log('done.~n', []),

	%% assert in to database
	assert(current_beam(Beam)),

	repeat,

	% obtain testing parameters
	format_log('~n', []),
	read_number('    Positional Tolerance (+/- mm)', EpsPos),
	flag(positional_tolerance, _, EpsPos),

	% begin test
	write_test_time('begins'),

	member(['AxisStart', AxisStart], Beam),
	member(['AxisEnd', AxisEnd], Beam),
	member(['IsoCenter', Isocenter], Beam),
	ok_beam_cax_isocenter(Beam, AxisStart, AxisEnd, Isocenter),

	% end test
	write_test_time('ends'),

	%% remove from database
      	retract(current_beam(Beam)),

	format_log('**** TEST ALGT_BEAM_CAX_ISOCENTER ****~n~n~n~n', []),
	close_log.

























