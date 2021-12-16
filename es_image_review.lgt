:- module(image_review, []).



is_valid(geometry,
		 geometry{position:_,
				  orientation:_,
				  scaling:_}).

is_valid(pixels,
		 pixels{width:_,
				height:_,
				pixels:_}).

is_valid(transformation,
		 Transformation_List) :-

	forall(member(Transformation,
				  Transformation_List),
		   member(Transformation,
				  [rotate(_,_),
				   translate(_)])).


/****************************************************************
 * tx_image is a treatment image
 *
 ****************************************************************/

:- object(tx_image(_Id, _ES)).

:- public([
	   % queries
	   review/1,

	   % commands
	   ctor/3,
	   associate_to/1,
	   set_as_reference/1,
	   register_to/2
   ]).

:- initialization((
	   this(Id, ES),
	   uuid_property(Id, version(_)),
	   is_list(ES))).


%!	review(List) is det.
%
%	review is a query...

review([tx_image(Geometry, Pixels,
				 reference(Geometry, Pixels),
				 Transformation_List)]) :-

	this(Id, ES),
	Stereo_Option = tx_image(_, _, _, _)
	;
	Stereo_Option = [].

review([Tx_Image, Stereo_Partner]) :-
	::review([Tx_Image]),

	this(Id, ES),
	member(associated_to(stereo(Id, Stereo_Id)), ES),
	tx_image(Stereo_Id, ES)::review([Stereo_Partner]).


%!	ctor(_,_,_) is det
%
%	command that ...

ctor(acquired(Acquisition_DateTime),
	 geometry(Geometry),
	 pixels(Pixels)) :-

	is_valid(geometry, Geometry),
	is_valid(pixels, Pixels),
	this(Id, [created(Id,
					  acquired(Acquisition_DateTime),
					  geometry(Geometry),
					  pixels(Pixels)) |_]).


%!	associate_to(_) is det
%
%	command that ...

associate_to(Associated_Object_Id) :-
	member(Associated_Object_Id,
		   [field(_), site(_), stereo(_), offset(_)]),
	this(Id,
		[associated_to(Id, Associated_Object_Id) |_]).


%!	set_as_reference(_) is det
%
%	command that ...

set_as_reference(Site_Or_Field_Id) :-
	member(Site_Or_Field_Id,
		   [field(_), site(_)]),
	this(Id,
		[set_as_reference(Id, Site_Or_Field_Id) |_]).


%!	register_to(_,_) is det
%
%	command that ...

register_to(Other_Image_Id,
			Transformation_List) :-
	is_valid(transformation, Transformation_List),
	this(Id,
		 [registered_to(Id,
						Other_Image_Id,
						Transformation_List) |_]).

:- end_object.





