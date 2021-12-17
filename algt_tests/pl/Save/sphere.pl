:- consult(geom).
:- consult(coord_sys).

sphere_mesh(Radius, Samples, Mesh) :-
	sphere_quads(Radius, Samples, Quads),
	findall([Q1, Q2, Q3], member([Q1, Q2, Q3, _], Quads), Mup),
	findall([Q4, Q3, Q2], member([_, Q2, Q3, Q4], Quads), Mdn),
	append(Mup, Mdn, Mesh).

sphere_quads(R, S, Quads) :-
	findall(Quad, 
		(   LatRange is 360 / S,
		    between(0, LatRange, Lat), 
		    LongRange is 90 / S,
		    NegLongRange is -LongRange,
		    between(NegLongRange, LongRange, Long),
		    sphere_quad(R, Lat, Long, S, Quad)
		),
		Quads).

sphere_quad(R, Lat, Long, S, Quad) :-
	findall([X, Y, Z],
		(   between(0, 1, Lato),
		    between(0, 1, Longo),
		    X is R * cos((Lat+Lato) * S*pi/180) 
		* cos((Long+Longo)* S*pi/180),
		    Y is R * sin((Lat+Lato) * S*pi/180) 
		* cos((Long+Longo)* S*pi/180),
		    Z is R * sin((Long+Longo)* S*pi/180)
		),
		Quad).


tetrahedron_mesh(S, [[[S,0,0],	   V2,	   V3],
		     [     V4,     V3,     V2],
		     [     V4,     V3,[S,0,0]],
		     [	   V3,[S,0,0],	   V2]]) :-

	mat_rotate(109.5, [0,1,0], YRot),
	transform([S,0,0], YRot, V2),
	mat_rotate(109.5, [1,0,0], XRot),
	transform(V2, XRot, V3),
	transform(V3, XRot, V4).
	

circle_poly(Radius, Verts) :-
	findall([X,Y,0],
		(   between(0, 360, Angle),
		    AngleRad is Angle * pi / 180,
		    X is Radius * sin(AngleRad),
		    Y is Radius * cos(AngleRad)),
		Verts).








