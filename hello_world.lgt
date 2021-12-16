:- object(hello_world(Message)).
:- initialization((write(Message), nl)).

:- public(sayhi/1).
sayhi :- write(Message), nl.

:- end_object.
