

:- object(event_sourced(_Type_Id, _ES)).

:- protected([emit/1, last/1]).

:- initialization((
	   this(Type_Id, ES),
	   Type_Id =.. [Type, Id],
	   specializes_class(Type, event_sourced),
	   uuid_property(Id, _),
	   is_list(ES))).

emit(Event) :-
	this(Type_Id, [Event|_]),
	Event =.. [_,Type_Id|_].

last(Event) :-
	this(Type_Id, ES),
	Event =.. [_,Type_Id|_],
	member(Event, ES).

:- end_object.


/*  object(subject) is det
 *
 *	represents a test subject
 */

:- object(subject(_Id, _ES),
		  specializes(event_sourced)).

:- public([ctor/1,
		   add_image/1,
		   set_reference/1,
		   register_image/3,
		   has_properties/1,
		   has_image/2,
		   has_reference/1,
		   has_registration/3]).

:- initialization(_).

%!	ctor(Subject_Dict) is det
%
%	constructs...

ctor(Subject_Dict) :-
	::emit(ctord(_, Subject_Dict)).

%!	add_image(ImageId) is det
%
%	adds an image

add_image(ImageId) :-
	this(_,ES),
	\+ subject(_,ES)::has_image(image(ImageId)),
	::emit(image_added(_, image(ImageId))).

%!	set_reference is det
%
%	sets the reference image

set_reference(image(ImageId)) :-
	::has_image(ImageId, image(ImageId,ES)),
	image(ImageId,ES)::is_approved,
	::emit(reference_set(_, image(ImageId))).


%!	register_image(_,_,_) is det
%
%	register the two images...

register_image(ImageId, ReferenceImageId, Transformation) :-
	::has_reference(ReferenceImageId),
	::emit(registered(_, image(ImageId), image(ReferenceImageId),
					  Transformation)).


%!	has_properties(_) is det
%
%	does the same with properties

has_properties(Subject_Dict) :-
	::only(ctord(_), Subject_Dict).


%!	has_image(_,_) is det
%
%

has_image(ImageId, image(ImageId,ES)) :-
	this(_,ES),
	::last(image_added(_, ImageId)).


%!
%
%

has_reference(ImageId) :-
	::last(reference_set(_, image(ImageId))).


has_registration(ImageId, ReferenceImageId, Transformation) :-
	::last(registered(_, image(ImageId), image(ReferenceImageId),
					Transformation)).

:- end_object.


/*
 *
 *
 */

:- object(image(_Id, _ES)).

:- public([ctor/3,
		   rescale/1,
		   approve/0,
		   reject/1,
		   has_acquisition/1,
		   has_scale/1,
		   has_pixels/1,
		   is_approved/0,
		   is_rejected/1]).

:- initialization((
	   this(Id, ES),
	   guid_property(Id,_),
	   is_list(ES))).

ctor(Acquisition_DateTime, Scale, Pixels) :-
	::emit(ctord(_,
				 Acquisition_DateTime,
				 Scale, Pixels)).

rescale(Scale) :-
	\+ ::is_approved,
	\+ ::is_rejected,
	::emit(rescaled(_, Scale)).

approve :-
	\+ ::is_approved,
	\+ ::is_rejected,
    ::emit(approved(_)).

reject(Reason) :-
	\+ ::is_approved,
	\+ ::is_rejected,
	::emit(rejected(_, Reason)).

has_acquisition(DateTime) :-
	::only(ctord(_, DateTime, _, _)).

has_scale(Scale) :-
	::last([rescaled(_, Scale),
			ctord(_, _, _, Scale)]).

has_pixels(Pixels) :-
	::only(ctord(_, _, Pixels, _)).

is_approved :-
	::last(approved(_)).

is_rejected(Reason) :-
	::last(rejected(_, Reason)).

:- end_object.
















