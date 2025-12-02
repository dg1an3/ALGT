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
