%%
%%
%%

:- object(tx_image(_Id, _ES)).

    :- public([has_reference/1,
			   has_registration/2,
			   has_session/1,
			   ctor/3,
			   scale/1,
			   set_as_reference/1,
			   associate_to/1,
			   register_to/2]).

    %%	queries
    has_reference(tx_image(Reference_Image_Id)) :-
		this(Id, ES),
		member(associated_to(tx_image(Id),
							 field(Field_Id)), ES),
		member(set_as_reference(tx_image(Reference_Image_Id),
								field(Field_Id)), ES).

    has_registration(tx_image(Reference_Image_Id),
					 xform(Xform_List)) :-
	    this(Id, ES),
		::has_reference(tx_image(Reference_Image_Id)),
		member(registered_to(tx_image(Id),
							 tx_image(Reference_Image_Id),
							 xform(Xform_List)), ES)
		;
		Xform_List = [id].

    has_session(session(Session_Number)) :-
	    this(Id, ES),
		member(associated_to(tx_image(Id),
							 session(Session_Number)), ES).


    %%	commands
    ctor(Acquisition_DateTime, Geometry, Pixels) :-
	    this(Id, [created(tx_image(Id),
						  Acquisition_DateTime, Geometry, Pixels) |_]).

    scale(Geometry) :-
	    this(Id, [scaled(tx_image(Id),
						 Geometry) |_]).

    set_as_reference(field(Field_Id)) :-
	    this(Id, [set_as_reference(tx_image(Id),
								   field(Field_Id)) |_]).

    associate_to(Associated_Object) :-
	    member(Associated_Object, [field(_), site(_), session(_)]),
		this(Id, [associated_to(tx_image(Id),
								Associated_Object) |_]).

    register_to(treatment_image(Other_Image_Id), Transformation) :-
	    this(Id, [registered_to(tx_image(Id),
								tx_image(Other_Image_Id),
								Transformation) |_]).

:- end_object.


