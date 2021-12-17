%% coord_sys.pl
%%
%% contains conversions among IEC-defined coordinate systems for a beam.
%%
%% Copyright (C) 2003  DG Lane

%% depends on vector
:- consult(vector).


%% transform composition rule

%% transform_to
%%
%% asserts transform relationships among IEC coordinates

%% IEC tabletop - table support transformation

transform_to(Beam, dicomPatient, iecTableSupport, Xform) :-
	(   member(['Isocenter', IsocenterPosition], Beam), ! ;
	member(['IsoCenter', IsocenterPosition], Beam)),
	scalar_prod(-1.0, IsocenterPosition, InvIsocenterPosition),
	mat_translate(InvIsocenterPosition, Xlate), 
	mat_rotate(-90.0, [1, 0, 0], Xrot),
	mat_prod(Xrot, Xlate, Xform), !.

transform_to(Beam, iecTableSupport, iecFixed, Xform) :-
	(   member([couchAngle, CouchAngle], Beam), !;
	member(['CouchAngle', CouchAngle], Beam) ),
	mat_rotate(CouchAngle, [0, 0, 1], Xform), !.

transform_to(Beam, iecFixed, iecGantry, Xform) :-
	(   member([gantryAngle, GantryAngle], Beam), !;
	member(['GantryAngle', GantryAngle], Beam) ),
	mat_rotate(GantryAngle, [0, 1, 0], Xform), !.

transform_to(Beam, iecGantry, iecBeam, Xform) :-
	member(['SAD', SAD], Beam),
	scalar_prod(SAD, [0, 0, -1], Offset),
	mat_translate(Offset, Xform), !.

%% transform_to(Beam, iecBeam, iecBLD, Xform) :-
%%	member([collimatorAngle, CollimAngle], Beam),
%%	mat_rotate(CollimAngle, [0, 0, -1], Xform), !.

transform_to(Beam, A, B, Xform) :-
	transform_to(Beam, A, C, XformAC), 
	transform_to(Beam, C, B, XformCB), 
	mat_prod(XformCB, XformAC, Xform), !.


%% transform_from(Beam, iecBLD, iecBeam, Xform) :-
%%	member([collimatorAngle, CollimAngle], Beam),
%%	mat_rotate(CollimAngle, [0, 0, 1], Xform), !.

transform_from(Beam, iecBeam, iecGantry, Xform) :-
	member(['SAD', SAD], Beam),
	scalar_prod(SAD, [0, 0, 1], Offset),
	mat_translate(Offset, Xform), !.

transform_from(Beam, iecGantry, iecFixed, Xform) :-	
	(   member([gantryAngle, GantryAngle], Beam), !;
	member(['GantryAngle', GantryAngle], Beam) ),
	mat_rotate(GantryAngle, [0, -1, 0], Xform), !.

transform_from(Beam, iecFixed, iecTableSupport, Xform) :-
	(   member([couchAngle, CouchAngle], Beam), !;
	member(['CouchAngle', CouchAngle], Beam) ),
	mat_rotate(CouchAngle, [0, 0, -1], Xform), !.

transform_from(Beam, iecTableSupport, dicomPatient, Xform) :-
	(   member(['Isocenter', IsocenterPosition], Beam), ! ;
	member(['IsoCenter', IsocenterPosition], Beam)),
	mat_translate(IsocenterPosition, Xlate),
	mat_rotate(90.0, [1, 0, 0], Xrot),
	mat_prod(Xlate, Xrot, Xform), !.


transform_from(Beam, A, B, Xform) :-
	transform_from(Beam, A, C, XformAC), 
	transform_from(Beam, C, B, XformCB), 
	mat_prod(XformCB, XformAC, Xform), !.




%% transforms
%% 
%% asserts transform relationship between Vs and Vts via Xfrom

transform(Vs, Xform, Vts) :-
	maplist(mat_prod(Xform), Vs, Vts).


%% homogeneous 
%%
%% asserts relationship between non-hg and hg vectors

vec_hg(V, V_hg) :-
	nonvar(V), !,
	append(V, [1], V_hg).

vec_hg([], [_]) :- !.

vec_hg([V1 | V_t], [V1_hg | V_t_hg]) :-
	nonvar(V1_hg), !,
	append(_, [Hg], V_t_hg),
	V1 is V1_hg / Hg,
	vec_hg(V_t, V_t_hg).

mat_hg([Vec1 | Vec_t], [Vec1_hg | Vec_t_hg]) :-

	vec_hg(Vec1, Vec1_hg),
	mat_hg(Vec_t, Vec_t_hg).

mat_hg([], []).



%% mat_prod/3
%% 
%% asserts that /1 * /2 is /3

mat_prod([[]], _, []) :- !.

mat_prod(L, R, P) :-
	transpose(L, LT),
	mat_prod_transpose(LT, R, PT),
	transpose(PT, P).

%% helper predicate to express L * R^T = P

mat_prod_transpose([LH | LT], R, [PH | PT]) :-
       maplist(dot_prod(LH), R, PH),
       mat_prod_transpose(LT, R, PT).

mat_prod_transpose([], _, []).


%% transpose/3
%% 
%% uses decap to transpose a matrix recursively.

transpose(M, [TH | TT] ) :-
	decap(M, TH, T_t),
	transpose(T_t, TT).

transpose([[]|_], []).

%% helper predicate to "decaptitate" a list of lists (matrix)

decap([[H1 | T1] | T], [H1 | HT], [T1 | TT]) :-
	decap(T, HT, TT).

decap([], [], []).


%% mat_translate/2
%% 
%% translation matrix -- homogeneous form.

mat_translate([Tx, Ty, Tz], 
	     [[1, 0, 0, 0],
	      [0, 1, 0, 0],
	      [0, 0, 1, 0],
	      [Tx, Ty, Tz, 1]]).


%% mat_rotate/2
%% 
%% specific forms for rotation matrices about Y and Z -- homogeneous forms.

mat_rotate(Angle, [Dir, 0, 0], 

	  [[ 1,       0,    0, 0],
	   [ 0,    CosA, SinA, 0],
	   [ 0, NegSinA, CosA, 0],
	   [ 0,       0,    0, 1]]) :-

	sin_cos_neg(Angle, Dir, SinA, CosA, NegSinA).

mat_rotate(Angle, [0, Dir, 0], 

	  [[   CosA, 0, SinA, 0],
	   [      0, 1,    0, 0],
	   [NegSinA, 0,	CosA, 0],
	   [      0, 0,    0, 1]]) :-

	sin_cos_neg(Angle, Dir, SinA, CosA, NegSinA).

mat_rotate(Angle, [0, 0, Dir], 

	  [[   CosA, SinA, 0, 0],
	   [NegSinA, CosA, 0, 0],
	   [      0,    0, 1, 0],
	   [      0,    0, 0, 1]]) :-

	sin_cos_neg(Angle, Dir, SinA, CosA, NegSinA).

sin_cos_neg(Angle, Dir, SinA, CosA, NegSinA) :-

	Radians is pi * Angle / 180.0,
	SinA is Dir * sin(Radians),
	NegSinA is -SinA,
	CosA is cos(Radians).











