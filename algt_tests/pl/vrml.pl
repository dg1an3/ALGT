%% VRML DCG Rules
%%
%% Copyright (C) 2003  DG Lane

:- consult(dcg_basics).

%% vrmlmesh_is_mesh/2
%%
%% converts a VRML mesh (indexed vertices) to a non-indexed mesh

vrmlmesh_is_mesh([Verts, [ [C1, C2, C3] | CoordRest]], 
	       [ [V1, V2, V3] | FacetTail ]) :-

	nth0(C1, Verts, V1),
	nth0(C2, Verts, V2),
	nth0(C3, Verts, V3),

	dist_point_point(V1, V2, DistV1_V2), DistV1_V2 =\= 0,
	dist_point_point(V2, V3, DistV2_V3), DistV2_V3 =\= 0,
	dist_point_point(V1, V3, DistV1_V3), DistV1_V3 =\= 0, !,

	vrmlmesh_is_mesh([Verts, CoordRest], FacetTail).

vrmlmesh_is_mesh([Verts, [_ | CoordRest]], Facets) :-

	vrmlmesh_is_mesh([Verts, CoordRest], Facets).

vrmlmesh_is_mesh([_, []], []).


%% vrmlmesh_oriented/1
%%
%% asserts that the mesh for the index list Ic is an oriented mesh

vrmlmesh_oriented(Ic) :-
	forall((member(IF1, Ic), nextto_wrap(I1, I2, IF1)),
	       (   member(IF2, Ic),
		   nextto_wrap(I2, I1, IF2)
	       )).

vrmlmesh_closed(Ic) :-
	forall((member(IF1, Ic), nextto_wrap(I1, I2, IF1)),
	       (   member(IF2, Ic),
		   member(I1, IF2),
		   member(I2, IF2)
	       )).

vrmlmesh_orient([], Ic_fixed, Ic_fixed) :- !.
	
vrmlmesh_orient([Ic1 | Ic_t], [], Ic_fixed_fixed) :-
	vrmlmesh_orient(Ic_t, [Ic1], Ic_fixed_fixed), !.

vrmlmesh_orient(Ic, Ic_fixed, Ic_fixed_fixed) :-

	%% pick a fixed facet
	member(IFacet_fixed, Ic_fixed),
	nextto_wrap(I1, I2, IFacet_fixed),

	%% pick a new facet and correct it
	select(IFacet_new, Ic, Ic_remain), 
	(   
	nextto_wrap(I2, I1, IFacet_new),
	    IFacet_new_fixed = IFacet_new, ! ;
	nextto_wrap(I1, I2, IFacet_new),
	    reverse(IFacet_new, IFacet_new_fixed)
	),

	%% continue
	vrmlmesh_orient(Ic_remain, [IFacet_new_fixed | Ic_fixed], Ic_fixed_fixed).

mesh_oriented(Ic) :-
	forall((member(F1, Ic), nextto_wrap(I1, I2, F1)),
	       (   member(F2, Ic),
		   nextto_wrap(I2, I1, F2) ;
	       format('No neighbor for edge ~p ~p ~n', [I1, I2])
	       )
	      ).

nextto_wrap(X, Y, [Y | Tail]) :-
	last(Tail, X).

nextto_wrap(X, Y, List) :-
	nextto(X, Y, List).

/*
poly_neighborhood(Ic, Index) :-
	select(F1, Ic, Ic_remain),
	member(Index, F1),
	findall([E1, E2],
		(   member(F2, Ic_remain),
		    member(Index, F2),
		    nextto_wrap(E1, E2, F2),
		    E1 =\= Index, E2 =\= Index
		),
		Edges),
	findall(PolyNeighborhood,
		(   make_polygon(Edges, PolyNeighborhood, Edges_remain).

make_polygon(Edges, [[E1_start, E1_end], [E1_end, E2_end] | Poly_t]) :-
	(   
	var(E1_start),
	    select([E1_start, E1_end], Edges, Edges_remain) ;
	select([E1_end, E2_end], Edges, Edges_remain)
	),
	make_polygon(Edges_remain, [[E1_end, E2_end] | Poly_t]).

make_polygon([], []).
	*/

%% vrml_file/4
%%
%% DCG rule to parse a VRML mesh

vrml_file(Verts, Norm, IFSCoord, IFSNormal) -->
	codes(_, _),
	"Separator", blanks, !,
	"{",
	codes(_, _),
	coordinate3_section(Verts), !,
	normal_section(Norm), 
	indexed_faceset_section(IFSCoord, IFSNormal),
	"}", blanks.


%% coordinate3_section/1
%%
%% DCG rule to parse a "Coordinate3" section of VRML

coordinate3_section(Coords) --> 
	"Coordinate3", blanks, 
	"{", blanks, 

	"point", blanks, 
	"[", blanks, 
	vector3s(Coords, ","),
	"]", blanks, 

	"}", blanks.

%% normal_section/1
%%
%% DCG rule to parse a "Normal" section of VRML

normal_section(Normals) --> 
	"Normal", blanks, 
	"{", blanks, 

	"vector", blanks, 
	"[", blanks, 
	vector3s(Normals, ","),
	"]", blanks, 

	"}", blanks.

%% indexed_faceset_section/2
%%
%% DCG rule to parse an "IndexedFaceSet" section of VRML

indexed_faceset_section(IFSCoord, IFSNormal) -->
	"IndexedFaceSet", blanks, 
	"{", blanks, 

	"coordIndex", blanks, 
	"[", blanks, 
	index_face3s(IFSCoord),
	"]", blanks,

	"normalIndex", blanks,
	"[", blanks, 
	index_face3s(IFSNormal),
	"]", blanks, 

	"}", blanks.

%% index_face3s/1
%%
%% DCG rule to parse a single index face

index_face3s([[I1, I2, I3] | T]) -->
	integer(I1), ",", blanks,
	integer(I2), ",", blanks,
	integer(I3), ",", blanks,
	integer(Sentinal), ",", blanks, !,
	{ Sentinal is -1 },
	index_face3s(T).

index_face3s([]) --> [].


format1_file(Polys) -->
	"S", blanks, integer(PlaneCount), blanks,
	format1_contours(Polys, PlaneCount).

format1_contours(Polys, PlaneCount) -->
	"V", blanks, integer(_), blanks,
	"z", blanks, number(Pz), blanks, !,
	format1_vertices_section_z(Polys_thisplane, Pz), !,
	{ PlaneCount_m1 is PlaneCount - 1 }, 
	format1_contours(Polys_restplanes, PlaneCount_m1),
	{ append(Polys_thisplane, Polys_restplanes, Polys) }. 

format1_contours(Polys, PlaneCount) -->
	"V", blanks, integer(_), blanks,
	number(_), blanks, number(_), blanks, number(_), blanks,
	format1_vertices_section(Polys_thisplane), !,
	{ PlaneCount_m1 is PlaneCount - 1 }, 
	format1_contours(Polys_restplanes, PlaneCount_m1),
	{ append(Polys_thisplane, Polys_restplanes, Polys) }. 

format1_contours([], _) --> [].

format1_vertices_section([Poly1 | Polys_t]) -->
	"{", blanks,
	vector3s([H | Tail], blanks),
	{ append([H | Tail], [H], Poly1) },
	"}", blanks, !,
	format1_vertices_section(Polys_t).

format1_vertices_section(Polys) -->
	"{", blanks,
	"}", blanks, !,
	format1_vertices_section(Polys).

format1_vertices_section([]) --> [].


format1_vertices_section_z([Poly1 | Polys_t], Z) -->
	"{", blanks,
	vector2s([H | Tail], Z, blanks),
	{ append([H | Tail], [H], Poly1) },
	"}", blanks, !,
	format1_vertices_section_z(Polys_t, Z).

format1_vertices_section_z(Polys, Z) -->
	"{", blanks,
	"}", blanks, !,
	format1_vertices_section_z(Polys, Z).

format1_vertices_section_z([], _) --> [].

format3_parameters([[Ident, Value] | Params_t]) --> 
	nonblanks(IdentCodes),
	{  string_to_atom(IdentCodes, Ident) },
	blanks, "=", blanks, 
	string_without("\n", Codes), 
	{  parameter_rule(Ident, Rule, Value),
	   phrase(Rule, Codes, _)
	},
	"\n", !,
	format3_parameters(Params_t).

format3_parameters([]) --> [].
	
parameter_rule('SAD', number(Value), Value).
parameter_rule('SBLDD', number(Value), Value).
parameter_rule('SID', number(Value), Value).
parameter_rule('Isocenter', vector3s([Value], blanks), Value).
parameter_rule('IsoCenter', vector3s([Value], blanks), Value).
parameter_rule(gantryAngle, number(Value), Value).
parameter_rule('GantryAngle', number(Value), Value).
parameter_rule(couchAngle, number(Value), Value).
parameter_rule('CouchAngle', number(Value), Value).
parameter_rule(collimatorAngle, number(Value), Value).
parameter_rule('CollimatorAngle', number(Value), Value).
parameter_rule('SSD', number(Value), Value).
parameter_rule('AxisStart', vector3s([Value], blanks), Value).
parameter_rule('AxisEnd', vector3s([Value], blanks), Value).

%% vector3s/1
%%
%% DCG rule to parse a single 3d vector

vector3s([[X, Y, Z]|T], Delim) -->
	number(X), blanks, 
	number(Y), blanks, 
	number(Z), blanks,
	Delim, blanks, !,
	vector3s(T, Delim).

vector3s([], _) --> [].

%% vector2s/1
%%
%% DCG rule to parse a single 3d vector

vector2s([[X, Y, Z]|T], Z, Delim) -->
	number(X), blanks, 
	number(Y), blanks, 
	Delim, blanks, !,
	vector2s(T, Z, Delim).

vector2s([], _, _) --> [].

%% codes/2
%%
%% code 'pass-through' rule

codes(Length, List) --> 
	{ length(List, Length) }, 
	List.





