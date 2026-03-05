appointment_type(clinical).
appointment_type(wellness).
appointment_type(nail_clipping).

:- protocol(domain_object).
:- public([id/1]).
:- end_protocol.

%	mastercontrol training
%	wcf nethttpbinding for messages
%	workday sign off

:- object(appointment(_Id, _Transition)).

:- initialization((
	   this(_, Initial -> Initial),
	   appointment{
		   patient_id:_,
		   appointment_type:_,
		   is_appointment_type_confirmed:_,
		   scheduled_time:_,
		   is_appointment_time_confirmed:_,
		   duration:minutes(_),
		   is_appointment_started:_,
		   is_appointment_closed:_,
		   is_appointment_cancelled:_
	   } = Initial)).

:- public([ctor/5,
		   patient_id/1,
		   appointment_type/1,
		   scheduled_time/1,
		   update_appointment_time/1]).

ctor(Id, C.patient_id, C.appointment_type,
	 C.scheduled_time, C.duration) :-

	this(Id, C -> _),
	uuid(Id).

patient_id(C.patient_id) :-
	this(_, C -> _).

appointment_type(C.appointment_type) :-
	this(_, C -> _).

scheduled_time(C.scheduled_time
			   -> N.scheduled_time) :-
	this(_, C -> N).

% ...

update_appointment_time(C.scheduled_time
						-> N.scheduled_time) :-

	this(_, C -> N),
	C.is_appointment_type_confirmed,
	\+ C.is_appointment_started,
	\+ C.is_appointment_cancelled,
	N.is_appointment_time_confirmed = false.

:- end_object.














