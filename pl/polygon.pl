boundary_polygons(Index, IFC, Polys) :-
	findall([E1, E2],
		(   member(Facet, IFC),
		    member(Index, Facet),
		    nextto_wrap(E1, E2, Facet),
		    E1 =\= Index, E2 =\= Index
		),
		Edges),
	connect_polygons(Edges, Polys).

nextto_wrap(A1, A2, [A2 | Tail]) :-
	last(Tail, A1).

nextto_wrap(A1, A2, List) :-
	nextto(A1, A2, List).

connect_polygons(Edges, [[V1_start, V1_end | V_t] | Poly_t]) :-
	select([V1_start, V1_end], Edges, Edges_remain),
	(   
	connect_polygons(Edges_remain, [[V1_end | V_t] | Poly_t]), !;
	V_t = [],
	    connect_polygons(Edges_remain, Poly_t)
	).

connect_polygons([], []).

remove_tetra([I1, I_t], IFC, [New_Facet | IFC_fixed_t]) :-
	findall([Facet, I2, I3],
		(   
		member(Facet, IFC),
		    member(I1, Facet),
		    member(I2, I_t), member(I2, Facet),
		    nextto(I2, I3, I_t), member(I3, Facet)
		),
		Facets_Edges),
	decap(Facets_Edges, Facets, Edges),

	connect_polygons(Edges, [_ | Rev_Facet]),
	reverse(Rev_Facet, New_Facet),

	subtract(IFC, Facets, IFC_fixed_t).	


remove_double_neighborhoods(IFC, IndexList, IFC_fixed) :-

	%% get a facet and index from the IFC
	member(Facet, IFC),
	member(Index, Facet),

	%% check that its not on the list
	\+ member(Index, IndexList),

	%% form the boundary polygons for the index
	boundary_polygons(Index, IFC, Polys),
	length(Polys, Poly_count),

	Poly_count > 1 ->
	    member([_ | Poly], Polys),
	    length(Poly, 4), !,
	    remove_tetra([Index | Poly], IFC, IFC_fixed_Index),
	    remove_double_neighborhoods(IFC_fixed_Index, 
					IndexList, IFC_fixed) ;

	remove_double_neighborhoods(IFC, [Index | IndexList], IFC_fixed).

remove_double_neighborhoods(IFC, IndexList, IFC) :-
	length(IndexList, Index_count),
	length(IFC, Index_count),
	forall((member(Facet, IFC), member(Index, Facet)),
	       boundary_polygons(Index, IFC, [_])).













