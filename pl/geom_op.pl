%% geom.pl
%%
%% contains basic computational geometry predicates.
%%
%% Copyright (C) 2003  DG Lane

%% depends on vector
:- consult(vector).
:- consult(coord_sys).

%% mesh_volume/2
%% 
%% predicate to unify /3 with the element-wise vector addition
%% of the input vectors.

mesh_volume(Mesh, Volume) :-

	%% use center of mesh bounds as origin
	mesh_bounds(Mesh, [Xmin, Ymin, Zmin], [Xmax, Ymax, Zmax]),
	Xo is (Xmax - Xmin) / 2.0,
	Yo is (Ymax - Ymin) / 2.0,
	Zo is (Zmax - Zmin) / 2.0,

	%% compute individual facet signed volumes, based on origin
	findall(Volume_Facet,
		(   
		%% for each mesh,
		member(Facet, Mesh),

		    %% compute volume
		    facet_volume(Facet, [Xo, Yo, Zo], Volume_Facet)
		),

		%% accumulate in Volumes
		Volumes),

	%% sum the resulting list of volumes
	sumlist(Volumes, Volume).

facet_volume([V1, V2, V3], Orig, Volume) :-
	Volume is_v ((V1 - Orig) x (V2 - Orig)) * (V3 - Orig) / 6.0.


%% mesh_volume/2
%% 
%% predicate to unify /3 with the element-wise vector addition
%% of the input vectors.

mesh_bounds(Mesh, [Xmin, Ymin, Zmin], [Xmax, Ymax, Zmax]) :-

	%% accumulate all vertices (flatten mesh)
	findall(Vert,
		(   member(Facet, Mesh),
		    member(Vert, Facet)
		),
		Verts),

	%% transpose to create list of Xs, Ys, and Zs
	transpose(Verts, [Xs, Ys, Zs]),

	%% form min and max of lists
	min(Xs, Xmin), max(Xs, Xmax),
	min(Ys, Ymin), max(Ys, Ymax),
	min(Zs, Zmin), max(Zs, Zmax).


%% dist_line_mesh/3
%% 
%% predicate to unify /3 with minimum distance from Mesh to Line

dist_line_mesh(Line, Mesh, Distance) :-
	
	%% accumulate all distances to line
	findall(VertDist,
		(    member(Facet, Mesh),
		     member(Vertex, Facet),
		     dist_point_line(Vertex, Line, VertDist)
		),
		Distances),

	%% return min distance
	min(Distances, Distance).

ray_mesh_intersect([Orig, Dir], Mesh, P) :-

	findall([IntersectPoint, Dist],
		(   
		member(Facet, Mesh),
		    ray_facet_intersect([Orig, Dir], Facet, IntersectPoint),
		    vec_diff(Orig, IntersectPoint, Offset),
		    vec_length(Offset, Dist)
		),
		IntersectionPairs),
	transpose(IntersectionPairs, [_, Distances]),
	min(Distances, D),
	member([P, D], IntersectionPairs).

%% point_on_mesh/3
%% 
%% predicate to unify /3 with the element-wise vector addition
%% of the input vectors.

point_on_mesh(Point, Mesh, Epsilon) :-	
	dist_point_mesh(Point, Mesh, Distance),
	is_approx_equal(Distance, 0, Epsilon).


%% dist_point_mesh/3
%% 
%% predicate to unify /3 with the element-wise vector addition
%% of the input vectors.

dist_point_mesh(Point, Mesh, Distance) :-

	%% accumulate all distances
	findall(FacetDist,
		(    member(Facet, Mesh),
		     dist_point_facet(Point, Facet, FacetDist)
		),
		Distances),

	%% determine minimum
	min(Distances, Distance).


ray_facet_intersect([Orig, Dir], [F1, F2, F3], P) :-

	%% compute barycentric coordinates for the origin point,
	%%    along the direction vector
	bary_coord_facet(Orig, [F1, F2, F3], Dir, [S, T, U]),

	%% do we intersect the triangle?
	S >= 0, 
	T >= 0, 
	S + T =< 1,

	%% make sure we are in the correct hemispace
	U =< 0,

	%% compute the offset to the intersection point
	P is_v F1 + S * (F2 - F1) + T * (F3 - F1).


%% dist_point_facet/3
%% 
%% predicate to unify /3 with the element-wise vector addition
%% of the input vectors.

dist_point_facet(Point, Verts, Distance) :-

	bary_coord_facet(Point, Verts, _, [S, T, U]),

	S >= 0, 
	T >= 0, 
	S + T =< 1, !,
	Distance is abs(U).


dist_point_facet(Point, [V1, V2, V3], Distance) :-

	dist_point_seg(Point, [V1, V2], Dist1_2),
	dist_point_seg(Point, [V2, V3], Dist2_3),
	dist_point_seg(Point, [V3, V1], Dist3_1),

	min([Dist1_2, Dist2_3, Dist3_1], Distance).


facet_plane([V1, V2, V3], [V1, Dir]) :-
	Dir is_v vec_norm((V2 - V1) x (V3 - V1)).
	

%% bary_coord_facet/3
%% 
%% predicate to unify /3 with the element-wise vector addition
%% of the input vectors.

bary_coord_facet(Point, [F1, F2, F3], N, [S, T, Z]) :-

	%% use F1 as origin
	W is_v Point - F1,
	U is_v F2 - F1,
	V is_v F3 - F1,
	
	(  	
	%% do we need to compute the normal?
	var(N),

	%% form cross product of two legs of triangle
	N is_v U x V, !;

	%% otherwise, leave N alone
	true ),

	%% use perp-dot function to form S and T
	proj_perp(W, U, V, N, S),
	proj_perp(W, V, U, N, T),

	%% use unit normal vector to determine Z
	Z is_v W * vec_norm(N).

proj_perp(P, U, V, N, Proj) :-

	Cross is_v V x N,
        Cross_U is_v Cross * U, Cross_U =\= 0.0,
	Proj is_v Cross * P / Cross_U.


%% poly_area/2
%% 
%% predicate to unify /3 with the element-wise vector addition
%% of the input vectors.

poly_area(Polygon, Plane, Area) :-

	%% accumulate all individual edge areas in to Areas list
	findall(Area_Edge,
		(   nth0(N, Polygon, Vert1),
		    nth1(N, Polygon, Vert2),
		    edge_area([Vert1, Vert2], Plane, Area_Edge)
		),
		Areas),

	%% sum Areas list
	sumlist(Areas, Area).

edge_area([U, V], [Orig, Normal], Area) :-
	Area is_v ((U - Orig) x (V - Orig)) * Normal / 2.0.

%% dist_point_poly/3
%% 
%% minimum distance from a point to a polygon

dist_point_poly(Point, Poly, Distance) :-
	findall(Dist, 
		(   member(V1, Poly), 
		    nextto(V1, V2, Poly),
		    dist_point_seg(Point, [V1, V2], Dist)),
		DistAll),
	min(DistAll, Distance).


%% planes_with_polys/3
%% 
%% a list of polygons is associated with planes for each polygon

planes_with_polys([Poly1 | Polys_t], Normal,
		  [[[Orig1, Normal], Poly1] | PlanesWithPolys_t]) :-
	poly_plane(Poly1, [Orig1, Normal], _),
	planes_with_polys(Polys_t, Normal, PlanesWithPolys_t).

planes_with_polys([[] | Polys_t], Normal, PlanesWithPolys_t) :-
	planes_with_polys(Polys_t, Normal, PlanesWithPolys_t).

planes_with_polys([], _, []).


%% poly_plane/3
%% 
%% associates a polygon with a plane containing the polygon.

poly_plane(Poly, [V1, Plane_normal], _) :-

	%% if the normal is provided
	nonvar(Plane_normal),

	%% just choose one of the members of the polygon as the plane point
	member(V1, Poly), !.

poly_plane(Poly, [V1, Plane_normal], MinCross) :-

	%% choose three points
	nth0(N1, Poly, V1),
	nth0(N2, Poly, V2), N2 > N1,
	nth0(N3, Poly, V3), N3 > N2,

	%% form cross product
	Cross is_v (V2 - V1) x (V3 - V1),

	%% check that length > MinCross
	L is_v vec_len(Cross), L > MinCross, !,

	%% normalize cross product to form plane normal
	Plane_normal is_v vec_norm(Cross) ;

	%% if failed on length check, try smaller min crossing
	SmallerMinCross is MinCross * 0.5,

	%% recursive call
	poly_plane(Poly, [V1, Plane_normal], SmallerMinCross).


%% orient_polys/2
%% orient_poly/2
%%
%% associates a list of unoriented polys w/ planes with a list of 
%% oriented polys w/ planes

orient_polys(PlanesWithPolys, PlanesWithOrientedPolys) :-

	%% form the list for all members
	findall([Plane, OrientedPoly],

		%% remove the currently selected poly from the list
		(   select([Plane, Poly], PlanesWithPolys, 
			   RemPlanesWithPolys),
		    
		    %% orient the currently selected
		    orient_poly([Plane, Poly], RemPlanesWithPolys, 
				OrientedPoly)
		),

		%% collect into oriented list
		PlanesWithOrientedPolys).

orient_poly([[PlaneOrigin, PlaneNormal], Poly], 
	    OtherPlanesWithPolys, OrientedPoly) :-

	%% locate another polygon in the list
	member([OtherPlane, OtherPoly], OtherPlanesWithPolys),

	%% on the same plane as this one
	planes_approx_equal([PlaneOrigin, PlaneNormal], OtherPlane, 1e-6),
	format('Other Plane = ~p ~n', [OtherPlane]),

	%% pick a point on this polygon
	nth0(0, Poly, Vert),

	%% if it is inside the other polygon,
	point_inside_poly(OtherPoly, PlaneNormal, Vert),
	    
	%% compute the signed area of the polygon
	poly_area(Poly, [PlaneOrigin, PlaneNormal], PolyArea),

	(   
	    %% then the area should be negative
	    PolyArea < 0.0,
	
	    %% so orientation is OK
	    OrientedPoly = Poly, ! ;
	
	%% otherwise, reverse orientation
	reverse(Poly, OrientedPoly), !).

orient_poly([Plane, Poly], _, OrientedPoly) :-

	%% compute the signed area of the polygon
	poly_area(Poly, Plane, PolyArea),

	(   		    
	%% area should be positive
	PolyArea > 0.0,

	    %% so orientation is OK
	    OrientedPoly = Poly, ! ;

	%% otherwise, reverse orientation
	reverse(Poly, OrientedPoly)).


%% point_inside_poly/3
%%
%% test that a point is inside a polygon -- point and polygon must be coplanar

point_inside_poly(Poly, PlaneNormal, Point) :-

	%% form the direction vector for the intersection
	member(Axis, [[1, 0, 0], [0, 1, 0], [1, 0, 0]]),
	Dir is_v PlaneNormal x Axis,
	Dir_length is_v vec_len(Dir), Dir_length > 0.1, !,

	%% locate all intersections for the polygon
	findall(IntersectPoint,
		(    nth1(N, Poly, V1), 
		     nth0(N, Poly, V2),
		     ray_seg_intersect([Point, Dir], PlaneNormal,
				       [V1, V2], IntersectPoint)
		),
		IntersectPoints),
 
	%% locate all duplicates within the list
	findall(DuplicateIntersection,
		(    nth0(M, IntersectPoints, DuplicateIntersection),
		     nth0(N, IntersectPoints, OtherIntersection),
		     N > M, 
		     dist_point_point(DuplicateIntersection, 
				      OtherIntersection, Dist),
		     is_approx_equal(Dist, 0, 1e-6)
		),
		DuplicateIntersections),

	%% count the number of intersections minus duplicates
	length(IntersectPoints, IntersectCount),
	length(DuplicateIntersections, DuplicateCount), 

	%% if odd, then the point is inside the polygon
	1 =:= (IntersectCount - DuplicateCount) mod 2.


%% ray_seg_intersect/4
%%
%% determines intersection of ray with a segment, if it exists.
%% ray and segment must be coplanar

ray_seg_intersect([Orig, Dir], PlaneNormal, [S1, S2], P) :-

	%% form the normal to the ray
	Normal is_v Dir x PlaneNormal,
	Normal_length is_v vec_len(Normal),
	is_approx_equal(Normal_length, 1.0, 1e-6),

	%% form the offset from segment end to start, dot normal
	Denom is_v (S2 - S1) * Normal,

	%% denom must be sufficiently non-zero
	abs(Denom) > 1e-6,

	%% form scalar for intersection
	Lambda is_v (Orig - S1) * Normal / Denom, 
	
	%% scalar must be >= 0.0 and =< 1.0 for intersection to 
	%% lie on segment
	Lambda >= 0.0, Lambda =< 1.0,

	%% form scalar product of S1 + Lambda * Ds (intersection point)
	P is_v Lambda * (S2 - S1) + S1,

	%% check that intersection is on the ray
	DirSign is_v (P - Orig) * Dir,
	DirSign >= 0.0. 


%% dist_point_seg/4
%% 
%% predicate to unify /3 with the element-wise vector addition
%% of the input vectors.

dist_point_seg(Point, [Seg1, Seg2], Distance) :-
	
	%% use Seg1 as origin
	Offset is_v Seg2 - Seg1,
	Point_offset is_v Point - Seg1,
	
	%% Scale is scalar of projection
	Scale is_v (Point_offset * Offset) / (Offset * Offset),

	%% test for range of scale
	(   
	%% Scale =< 0.0 -> point is closest to Seg1
	Scale =< 0.0, !,
	    Distance is_v vec_len(Point_offset) ;

	%% Scale >= 1.0 -> point is closest to Seg2
	Scale >= 1.0, !,
	    Distance is_v vec_len(Point - Seg2) ;

	%% otherwise point is closest to its projection on to the segment
	Distance is_v vec_len(Point_offset - Scale * Offset)
	).


%% planes_approx_equal/3
%%
%% test that two planes are approximately eqivalent

planes_approx_equal([O1, N1], [O2, N2], Epsilon) :-

	%% use O1 as origin
	Offset is_v O2 - O1,

	%% Test Offset <dot> N1 ~= 0
	Dot1 is_v Offset * N1,
	is_approx_equal(Dot1, 0, Epsilon),

	%% Test Offset <dot> N2 ~= 0
	Dot2 is_v Offset * N2,
	is_approx_equal(Dot2, 0, Epsilon).


%% point_on_plane/3
%% 
%% determines if the point lies on the plane, up to the specified epsilon

point_on_plane(Point, Plane, Epsilon) :-	
	dist_point_plane(Point, Plane, Distance),
	is_approx_equal(Distance, 0, Epsilon).


%% dist_point_plane/4
%% 
%% predicate to unify /3 with the distance from the point to the
%% plane.

dist_point_plane(Point, [PlanePoint, PlaneNorm], Distance) :-
	Point_offset is_v Point - PlanePoint,
	Point_proj is_v vec_proj(Point_offset, vec_norm(PlaneNorm)),
	Distance is_v vec_len(Point_proj).

%% point_on_line/3
%% 
%% asserts that the point lies on the line, to within a distance
%% of Epsilon.

point_on_line(Point, Line, Epsilon) :-	
	dist_point_line(Point, Line, Distance),
	is_approx_equal(Distance, 0, Epsilon).


%% dist_point_line/4
%% 
%% predicate to unify /3 with the element-wise vector addition
%% of the input vectors.

dist_point_line(Point, [LinePoint, LineDir], Distance) :-
	Point_offset is_v Point - LinePoint,
	Point_proj is_v vec_proj(Point_offset, vec_norm(LineDir)),
	dist_point_point(Point_offset, Point_proj, Distance). 


%% dist_point_point/3
%% 
%% predicate to unify /3 with the element-wise vector addition
%% of the input vectors.

dist_point_point(PtL, PtR, Distance) :-
	Distance is_v vec_len(PtL - PtR).














