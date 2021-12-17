%% dicom_syntax.pl
%%
%% rules for basic manipulation of DICOM files.
%%
%% Copyright (C) 2003, DG Lane


:- consult(dcg_basics).

:- multifile dcm_attr_atom/3.
:- discontiguous dcm_attr_atom/3.

%% dcm_find/2
%%
%% locates an attribute in the parsed DICOM list, either by atom tag
%% or group/element pair
%%
%% recursively searches sequences

dcm_find(attr(T, VR, X), D) :-
	member(attr(T, VR, X), D).

dcm_find(attr(Atom, VR, X), D) :-
	
	%% decipher atom tag
	dcm_attr_atom(Atom, Group, Element),
	member(attr(tag(Group, Element), VR, X), D).

dcm_find(attr(T, VR, X), D) :-

	%% find any sequences
	member(attr(_, vr('SQ'), val(Seq)), D),
	
	%% recursively search each member of the sequence
	member(S, Seq), 
	dcm_find(attr(T, VR, X), S).		


%% dcm_conv_values/2
%%
%% converts values in the list of attributes from codes to values,
%% based on conversion DCG rules for the VR type of the attribute.

dcm_conv_values([attr(T, vr('SQ'), val(Seq)) | Tail], 
	       [attr(T, vr('SQ'), val(Seq_conv)) | Tail_conv]) :-
	maplist(dcm_conv_values, Seq, Seq_conv), !,
	dcm_conv_values(Tail, Tail_conv).

dcm_conv_values([attr(T, vr(VR), codes(Codes)) | Tail], 
	       [attr(T, vr(VR), val(Value)) | Tail_conv]) :-
	phrase(dcm_value_from_codes(VR, Value_List), Codes), 
	list_single(Value_List, Value), !,
	dcm_conv_values(Tail, Tail_conv).

dcm_conv_values([Head | Tail], [Head | Tail_conv]) :-
	dcm_conv_values(Tail, Tail_conv).

dcm_conv_values([], []).


%% dcm_value_from_codes('DS', _)
%%
%% conversion for decimal string 'DS'

dcm_value_from_codes('DS', [Value | Value_t]) -->	

	%% parse with VM > 1, recursively
	number(Value), blanks, "\\", !, 
	dcm_value_from_codes('DS', Value_t).

dcm_value_from_codes('DS', [Value]) -->

	%% parse single (remaining) value
	number(Value), blanks.

dcm_value_from_codes('DS', []) --> [].


%% dcm_value_from_codes('IS', _)
%%
%% conversion for decimal string 'DS'

dcm_value_from_codes('IS', [Value | Value_t]) -->	

	%% parse with VM > 1, recursively
	integer(Value), blanks, "\\", !, 
	dcm_value_from_codes('IS', Value_t).

dcm_value_from_codes('IS', [Value]) -->

	%% parse single (remaining) value
	integer(Value), blanks.

dcm_value_from_codes('IS', []) --> [].


%% dcm_value_from_codes('US', _)
%%
%% conversion for unsigned short 'US', including value multiplicity

dcm_value_from_codes('US', [Value | Value_t]) -->

	%% parse with VM > 1, recursively
	uint_le(16, Value),
	dcm_value_from_codes('US', Value_t).

dcm_value_from_codes('US', []) --> [].



%% dcm_file/1
%%
%% top-level DCG rule for a DICOM file

dcm_file(D) -->
	codes(128, _), 
	"DICM",
	dcm_attrs(D).

%% dcm_attrs/1
%%
%% DCG rule for lists of attributes

dcm_attrs([attr(T, VR, Val) | Tail]) -->
	dcm_attr(T, VR, Val), !,
	dcm_attrs(Tail).

dcm_attrs([]) --> [].


%% dcm_attr/1
%%
%% DCG rule for a single attribute tag/vr/value triple

%% 'SQ' recursively parses the sequence

dcm_attr(tag(L, R), vr('SQ'), val(Value)) -->
	
	%% parse tag, VR = 'SQ'
	dcm_tag(L, R),
	dcm_value_representation('SQ'),

	%% reserved
	uint_le(16, _),

	%% parse undefined length
	(  uint_le(32, 0xffffffff), !,
	   dcm_sequence(Value) ;

	%% OR parse defined length by launching sub-parse
	uint_le(32, Length),
	   codes(Length, ItemCodes),
	   { phrase(dcm_sequence(Value), ItemCodes) } 
	).
	
dcm_attr(tag(L, R), vr(VR), codes(Codes)) -->

	%% parse non-SQ VR
	dcm_tag(L, R),
	dcm_value_representation(VR),
	dcm_codes(VR, Codes).

%% dcm_tag/1
%%
%% DCG rule for tag value -- can be used with attribute tag atoms

dcm_tag(Atom) -->
	{ dcm_attr_atom(Atom, Group, Element) },
	dcm_tag(Group, Element).

dcm_tag(Group, Element) --> 
	uint_le(16, Group), uint_le(16, Element).


%% dcm_value_representation/1
%%
%% DCG rule for VR 

dcm_value_representation(VR) -->
	[VR1, VR2],
	{ vr_from_code([VR1, VR2], VR), 
	  dcm_vr(VR_List),
	  member(VR, VR_List) }.

%% dcm_sequence/1
%%
%% DCG rule for a sequence -- either delimited or defined length 

dcm_sequence([Item | Tail]) -->
	dcm_tag('Item'),
	uint_le(32, ItemLength),
	codes(ItemLength, ItemCodes),
	{ phrase(dcm_attrs(Item), ItemCodes) }, !,
	dcm_sequence(Tail).

%% sequence delimitation

dcm_sequence([]) -->
	dcm_tag('Sequence Delimitation Item'),
	uint_le(32, 0), !.

dcm_sequence([]) --> [].


%% sequence encoding tags 

dcm_attr_atom('Item', 0xfffe, 0xe000).
dcm_attr_atom('Item Delimitation Item', 0xfffe, 0xe00d).
dcm_attr_atom('Sequence Delimitation Item', 0xfffe, 0xe0dd).


%% dcm_codes/1
%%
%% DCG rule for reading codes (bytes for attribute value) -- interprets
%% length field and then creates a code list

dcm_codes(VR, C) --> 
       { ( VR == 'UN'; VR == 'OB'; VR == 'OW'; VR = 'UT' ) }, !,
       uint_le(16, _), %% reserved
       uint_le(32, Length),
       codes(Length, C).

dcm_codes(_, C) --> 
	uint_le(16, Length),
	codes(Length, C).

%% vr_from_code/1
%%
%% creates an atom for the VR

vr_from_code([C1, C2], Atom) :-
	atom_codes(Atom, [C1, C2]).

%% dcm_vr/1
%%
%% fact of allowed DICOM VRs

dcm_vr(['AS', 'AT', 'CS', 'DA', 'DS', 'DT', 
	'FL', 'FD', 'IS', 'LO', 'LT', 'OB', 
	'OW', 'PN', 'SH', 'SL', 'SS', 'ST', 
	'SQ', 'TM', 'UI', 'UL', 'UN', 'US', 
	'UT']).

%% uint_le/2
%%
%% parses unsigned integer, little endian, w/ bits indicated

uint_le(16, V) --> 
	[VL, VU],
	{ V is VU * 256 + VL }.

uint_le(32, V) --> 
	[VLL, VLU, VUL, VUU],
	{ V is ((VUU * 256 + VUL) * 256 + VLU) * 256 + VLL }.

%% codes/2
%%
%% code 'pass-through' rule

codes(Length, List) --> 
	{ length(List, Length) }, 
	List.

%% list_single/2
%%
%% 'demotes' a list with single element

list_single([V], V) :- !.

list_single(V, V).








