%% verif.pl
%%
%% top-level verification predicates.
%%
%% Copyright (C) 2003  DG Lane


:- consult(vrml).
:- consult(geom).
:- consult(coord_sys).

%% ok_margin2D/5
%%
%% asserts that PolyExpand is Poly dilated/eroded by Margin.

ok_margin2D(Margin, Rate, Epsilon) :-
	read_file_to_codes('ALGT_MARGIN2D_Expanded_format1.dat', C_exp, []),
	phrase(format1_file(Polys_exp), C_exp),
	read_file_to_codes('ALGT_MARGIN2D_format1.dat', C, []),
	phrase(format1_file(Polys), C, []),

	ok_margin2D(Polys_exp, Polys, Margin, Rate, Epsilon),

	findall(L, (member(Poly, Polys), length(Poly, L)), L_list),
	sumlist(L_list, Total_Orig_Verts),
	print_string("Original polygon verts = "),
	write(Total_Orig_Verts), nl,

	findall(L, (member(Poly, Polys_exp), length(Poly, L)), L_list_exp),
	sumlist(L_list_exp, Total_Exp_Verts),
	print_string("Expanded polygon verts = "),
	write(Total_Exp_Verts), nl,

	print_string("Sample rate = "), write(Rate), nl,
	print_string("Tolerance = "), write(Epsilon), nl.


ok_margin2D(PolysExpand, Polys, Margin, Rate, Epsilon) :-

	%% assert for all vertices in the expanded polygon
	forall((member(PolyExpand, PolysExpand), 
		member(Vert, PolyExpand)), 
	       (    skip_sample(Rate), !;
	       
		    %% assert for each member of poly, min distance from 
		    %%    the point to the original polygon
	            member(Poly, Polys),
	            dist_point_poly(Vert, Poly, Distance),

	            %% is within tolerance of the margin distance
	            (	
		    is_approx_equal(Distance, Margin, Epsilon) ;
		    print_string("Original -> Expanded distance failed at "),
			write(dist(Vert, Distance)), nl, fail
		    )
	       )),

	%% assert for all vertices in the original polygon
	forall((member(Poly, Polys), 
		member(Vert, Poly)), 
	       (    skip_sample(Rate), !;
	       
		    %% assert for each member of poly, min distance from 
		    %%    the point to the original polygon
	            member(PolyExpand, PolysExpand),
	            dist_point_poly(Vert, PolyExpand, Distance),

	            %% is greater than or within tolerance of the margin 
	            %%    distance
	            (   
	            Distance > Margin - Epsilon ;
		    print_string("Original -> Expanded distance failed at "),
			write(dist(Vert, Distance)), nl, fail		   
		    )
	       )),

	%% assert that the expanded polygon area
	maplist(poly_area, Polys, PolyAreas),
	sumlist(PolyAreas, PolyArea),
	maplist(poly_area, PolysExpand, PolyExpAreas),
	sumlist(PolyExpAreas, ExpArea),
		
	%% is greater than the original
	ExpArea > PolyArea.


%% ok_margin3D/5
%%
%% asserts that MeshExpand is Mesh dilated/eroded by Margin.

ok_margin3D(MeshesExpand, Meshes, Margin, Rate, Epsilon) :-

	%% assert for all vertices in the expanded meshes
	forall((member(MeshExpand, MeshesExpand), 
		member(Facet, MeshExpand),
		member(Vert, Facet)),
	       (   skip_sample(Rate), !;
	 
	           %% nearest distance from point to original mesh
	           member(Mesh, Meshes),
		   dist_point_mesh(Vert, Mesh, Distance),

	           %% is within tolerance of the margin distance
	           is_approx_equal(Distance, Margin, Epsilon)
	       )),

	%% assert for all vertices in the original meshes
	forall((member(Mesh, Meshes), 
		member(Facet, Mesh),
		member(Vert, Facet)),
	       (   skip_sample(Rate), !;
	 
	           %% nearest distance from point to original mesh
	           member(MeshExpand, MeshesExpand),
		   dist_point_mesh(Vert, MeshExpand, Distance),

		   %% is greater than or within tolerance of the margin 
	           %%    distance
	           Distance > Margin - Epsilon
	       )),

	%% assert that the expanded (contracted) mesh volume 
	maplist(mesh_volume, Meshes, MeshVolumes),
	sumlist(MeshVolumes, MeshVolume),
	maplist(mesh_volume, MeshesExpand, ExpVolumes),
	sumlist(ExpVolumes, ExpVolume),
	
	%% is greater (less than) than the original, depending on sign of
	%%     margin
	(   Margin > 0.0, ExpVolume > MeshVolume ;
	    ExpVolume < MeshVolume ).


%% ok_isodensity/6
%%
%% asserts that Mesh is the isodensity surface of Volume at level Threshold.

ok_isodensity(Mesh, Scanlines, EpsPos, EpsVol) :-

	%% assert positional correctness for all beams
	forall(member(Scanline, Scanlines),
	       ok_isodensity_pos(Mesh, Scanline, EpsPos)),

	%% assert volume correctness
	ok_isodensity_volume(Mesh, Scanlines, EpsVol).


%% ok_isodensity_pos/5
%%
%% asserts that Mesh is the isodensity surface of Volume at level Threshold, 
%% based on positions derived from Beam.

ok_isodensity_pos(Mesh, [[Pos, Delta], Runs], EpsPos) :-
	forall(member(run(pos(P), length(L)), Runs),
	       (   Begin is P + 0.5,
	           scalarProd(Begin, Delta, OffsetBegin),
		   vec_sum(Pos, OffsetBegin, PosStart),
		   point_on_mesh(PosStart, Mesh, EpsPos),
		   
		   End is P + L - 0.5,
		   scalarProd(End, Delta, OffsetEnd),
		   vec_sum(Pos, OffsetEnd, PosEnd),
		   point_on_mesh(PosEnd, Mesh, EpsPos))).

%% ok_isodensity_volume/4
%%
%% asserts that Mesh is the isodensity surface of Volume at level Threshold.

ok_isodensity_volume(Mesh, Scanlines, VoxelVolume, EpsVol) :-
	findall(RunVolume,
		(    member([_, Runs], Scanlines),
		     member(run(_, length(L)), Runs),
		     RunVolume is L * VoxelVolume),
		RunVolumes),
	sumlist(RunVolumes, ScanVolume),
	
	mesh_volume(Mesh, MeshVolume),
	is_approx_equal(MeshVolume, ScanVolume, EpsVol).


%% ok_beam_ssd/4
%%
%% asserts that BeamVolume is the 3D shape of BeamShape, projected 
%% by Beam's geometry.

ok_beam_ssd(BeamShape, BeamVolume, Rate, Epsilon) :-

	%% for all members of Beam Shape
	forall(member(V, BeamShape), 
	       (    skip_sample(Rate), !;

		    %% must be on the mesh
	            point_on_mesh(V, BeamVolume, Epsilon)
	       )).


%% ok_beam_volume/4
%%
%% asserts that BeamVolume is the 3D shape of BeamShape, projected 
%% by Beam's geometry.

ok_beam_volume(Beam, BeamShape, BeamVolume, Rate, Epsilon) :-

	%% assert verification conditions
	ok_beam_volume_shape(BeamShape, BeamVolume, Rate, Epsilon),
	ok_beam_volume_div(Beam, BeamShape, BeamVolume, Rate, Epsilon),
	ok_beam_volume_volume(Beam, BeamShape, BeamVolume, Epsilon).


%% ok_beam_volume_shape/4
%%
%% asserts that BeamVolume is the 3D shape of BeamShape, projected 
%% by Beam's geometry.

ok_beam_volume_shape(BeamShape, BeamVolume, Rate, Epsilon) :-

	%% for each point in the beam shape polygon set
	forall(member(V, BeamShape), 
	       (    skip_sample(Rate), !;

	            %% shape is correct if each vertex is on the mesh
	            point_on_mesh(V, BeamVolume, Epsilon)
	       )).


%% ok_beam_volume_div/3
%%
%% asserts that BeamVolume is the 3D shape of BeamShape, projected 
%% by Beam's geometry, based on the volume of BeamVolume vs. BeamShape

ok_beam_volume_div(Beam, BeamShape, BeamVolume, Rate, Epsilon) :-

	%% form the source point in DICOM patient coords
	transform_to(Beam, iecBeam, dicomPatient, Xform),
	transform([0,0,0], Xform, SrcPt),

	%% for all facets in beam volume
	forall(member(F, BeamVolume), 
	       (	skip_sample(Rate), !;

			%% F subset of P
			facet_plane(F, P),

			%% SrcPt member of P
		    	point_on_plane(SrcPt, P, Epsilon),

			%% their exists a segment of the beam shape polygon
			member(Poly, BeamShape),
			member(S, Poly),

			%% which is a subset of P
			point_on_plane(S, P, Epsilon),
			nextto(S, T, Poly),
			point_on_plane(T, P, Epsilon), !
	       )).


%% ok_beam_volume_volume/4
%%
%% asserts that BeamVolume is the 3D shape of BeamShape, projected 
%% by Beam's geometry, based on the volume of BeamVolume vs. BeamShape

ok_beam_volume_volume(Beam, BeamShape, BeamVolume, Epsilon) :-

	%% total the area of the beam shape polygons
	findall(Area,
		(     member(Poly, BeamShape), 
			poly_area(Poly, Area)),
		Areas),
	sumlist(Areas, TotalArea),

	%% compute the volume based on polygon area
	sfd(Beam, SFD),
	sbldd(Beam, SBLDD),
	sad(Beam, SAD),
	VolumeForArea is TotalArea * (SFD^2 - SBLDD^2) / SAD^2,

	%% compare to total mesh volume
	mesh_volume(BeamVolume, Volume),
	is_approx_equal(VolumeForArea, Volume, Epsilon).


%% ok_structure_proj/4
%%
%% asserts that BeamShape is the 2-d projection of Mesh through
%% Beam's geometry.

ok_structure_proj(Beam, Mesh, MeshProj, Epsilon) :-
	transform_to(Beam, iecBeam, dicomPatient, Xform),
	transform(Mesh, Xform, MeshProj, Epsilon).


%% predicate that evaluates to True (100-Rate)% of the time

skip_sample(SampleRate) :-
	SampleRate < random(100).

print_string([H | T]) :-
	put(H), print_string(T).

print_string([]).


















