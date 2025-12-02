%% dicom_objects.pl
%%
%% rules for manipulating DICOM images, RT structure sets, and RT plans.
%%
%% Copyright (C) 2003, DG Lane


:- consult(dicom_syntax).
:- consult(vector).

:- multifile dcm_attr_atom/3.
:- discontiguous dcm_attr_atom/3.


dcm_image_plane(Img_obj, [Origin, Row_dir, Col_dir]) :-

	%% get the row and column direction cosine
	dcm_find(attr('Image Position (Patient)', _, 
		      val(Origin)), Img_obj),
	dcm_find(attr('Image Orientation (Patient)', _, 
		      val([Xr, Yr, Zr, Xc, Yc, Zc])), Img_obj),
	dcm_find(attr('Pixel Spacing', _, val([X_ps, Y_ps])), Img_obj),

	scalar_prod(X_ps, [Xr, Yr, Zr], Row_dir),
	scalar_prod(Y_ps, [Xc, Yc, Zc], Col_dir).



%% dcm_pixel_conv/2
%%
%% converts pixel values as codes in to a list of scanlines

dcm_pixel_conv(D, Scanlines) :-

        %% match the physical pixel description
	dcm_find(attr('Rows', _, val(Rows)), D),
	dcm_find(attr('Columns', _, val(Columns)), D),
	dcm_find(attr('Bits Allocated', _, val(Bits_Allocated)), D),

	%% match the slope and intercept, 
	(   dcm_find(attr('Rescale Intercept', _, val(B)), D),
	    dcm_find(attr('Rescale Slope', _, val(M)), D), !;

	%% or use defaults
	B is 0.0, 
	    M is 1.0 ),

	%% match the pixel data as byte codes
	dcm_find(attr('Pixel Data', vr('OW'), codes(C)), D),

	%% parse pixels
	dcm_pixel_conv(Rows, Columns, [Bits_Allocated, B, M], C, Scanlines).

dcm_pixel_conv(0, _, _, [], []) :- !.

dcm_pixel_conv(Rows, Columns, [Bits_Allocated, B, M], 
	       C, [Scanline | Scanline_t]) :-
	
	%% parse this scanline
	phrase(dcm_codes_to_pixels([Bits_Allocated, B, M], Columns, 
				   Scanline), C, Rest),

	%% parse remaining scanlines
	succ(RowsRemaining, Rows),
	dcm_pixel_conv(RowsRemaining, Columns, [Bits_Allocated, B, M], 
		       Rest, Scanline_t).


%% dcm_codes_to_pixels([Bits_Allocated, B, M], Columns, Scanline)
%%
%% DCG rule for converting byte codes to pixels, performing slope/intercept
%% conversion

dcm_codes_to_pixels([_, _, _], 0, []) --> [].

dcm_codes_to_pixels([Bits_Allocated, B, M], Columns, [Pixel1 | Pixels_t]) -->

	%% decode Bits pixel
	uint_le(Bits_Allocated, SV), !, 

	%% adjust pixel value based on slope / intercept
	{ Pixel1 is M * SV + B },

	%% parse remaining columns
	{ succ(ColsRemaining, Columns) },
	dcm_codes_to_pixels([Bits_Allocated, B, M], ColsRemaining, Pixels_t).


%%  image pixel tags 

dcm_attr_atom('Rows', 0x0028, 0x0010).
dcm_attr_atom('Columns', 0x0028, 0x0011).
dcm_attr_atom('Bits Allocated', 0x0028, 0x0100).
dcm_attr_atom('Pixel Data', 0x7fe0, 0x0010).

%% image plane tags 

dcm_attr_atom('Pixel Spacing', 0x0028, 0x0030).
dcm_attr_atom('Image Orientation (Patient)', 0x0020, 0x0037).
dcm_attr_atom('Image Position (Patient)', 0x0020, 0x0032).

%% CT image tags

dcm_attr_atom('Rescale Intercept', 0x0028, 0x1052).
dcm_attr_atom('Rescale Slope', 0x0028, 0x1053).


%% dcm_contour_conv/3
%% 
%% extracts and converts polygons from StructureSet to a list of vertices
 
dcm_contour_conv(D, ROI_Number, Polygons) :-

	%% match the ROI contour sequence
	dcm_find(attr('ROI Contour Sequence', vr('SQ'), 
		      val(ROI_Contour_Seq)), D),

	%% match the ROI contours for the ROI number
	member(ROI_Contours, ROI_Contour_Seq),
	dcm_find(attr('Referenced ROI Number', _, 
		      val(ROI_Number)), ROI_Contours),
	dcm_find(attr('Contour Sequence', vr('SQ'), 
		      val(Contour_Seq)), ROI_Contours),

	%% collect all polygons for the ROI
	findall(Polygon,
		(   
		member(Contour, Contour_Seq),
		    dcm_find(attr('Contour Data', _, val(Verts)), Contour),
		    dcm_find(attr('Number of Contour Points', _, val(VertCount)), 
			     Contour),
		%% group contour in to 3D coords
		findall([C1, C2, C3],
			(   
			between(0, VertCount, N),
			    N1 is N * 3, nth0(N1, Verts, C1),
			    succ(N1, N2), nth0(N2, Verts, C2),
			    succ(N2, N3), nth0(N3, Verts, C3)
			),
			Polygon)
		),
		Polygons).


%% RT StructureSet tags

dcm_attr_atom('Structure Set ROI Sequence', 0x3006, 0x0020).
dcm_attr_atom('ROI Number', 0x3006, 0x0022).
dcm_attr_atom('ROI Name', 0x3006, 0x0024).

dcm_attr_atom('ROI Contour Sequence', 0x3006, 0x0039).
dcm_attr_atom('Referenced ROI Number', 0x3006, 0x0084).
dcm_attr_atom('Contour Sequence', 0x3006, 0x0040).
dcm_attr_atom('Number of Contour Points', 0x3006, 0x0046).
dcm_attr_atom('Contour Data', 0x3006, 0x0050).


%% beam identification information

dcm_attr_atom('Beam Sequence', 0x300a, 0x00b0).
dcm_attr_atom('Beam Name', 0x300a, 0x00c2).

%% machine geometry

dcm_attr_atom('Source-Axis Distance', 0x300a, 0x00b4).
dcm_attr_atom('Beam Limiting Device Sequence', 0x300a, 0x00b6).
dcm_attr_atom('RT Beam Limiting Device Type', 0x300a, 0x00b8).
dcm_attr_atom('Source to Beam Limiting Device Distance', 0x300a, 0x00ba).
dcm_attr_atom('Number of Leaf/Jaw Pairs', 0x300a, 0x00bc).
dcm_attr_atom('Leaf Position Boundaries', 0x300a, 0x00be).

%% blocks / ports

dcm_attr_atom('Block Sequence', 0x300a, 0x00f4).
dcm_attr_atom('Block Type', 0x300a, 0x00f8).
dcm_attr_atom('Block Number of Points', 0x300a, 0x0104).
dcm_attr_atom('Block Data', 0x300a, 0x0106).

%% control points

dcm_attr_atom('Number of Control Points', 0x300a, 0x0110).
dcm_attr_atom('Control Point Sequence', 0x300a, 0x0111).
dcm_attr_atom('Control Point Index', 0x300a, 0x0112).
dcm_attr_atom('Beam Limiting Device Position Sequence', 0x300a, 0x011a).
dcm_attr_atom('Leaf/Jaw Positions', 0x300a, 0x011c).
dcm_attr_atom('Gantry Angle', 0x300a, 0x011e).
dcm_attr_atom('Beam Limiting Device Angle', 0x300a, 0x0120).
dcm_attr_atom('Patient Support Angle', 0x300a, 0x0122).
dcm_attr_atom('Isocenter Position', 0x300a, 0x012c).
dcm_attr_atom('Source to Surface Distance', 0x300a, 0x0130).










