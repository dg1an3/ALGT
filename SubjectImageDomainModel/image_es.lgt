
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

	ctor(Acquisition_DateTime, Scale, Pixels) :-
		this(Id, ES),
		guid_property(Id,_),
		is_list(ES))),
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





