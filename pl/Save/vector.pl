%% vector.pl
%%
%% vector predicates.
%%
%% Copyright (C) 2003  DG Lane

:- op(700, xfx, is_v),
	op(400, yfx, x),
	op(400, yfx, proj),
	arithmetic_function(vec_len/1),
	arithmetic_function(vec_norm/1).

%% vec_proj/3
%% 
%% infers /1 projected onto /2 is /3.  

vec_proj(Point, ProjectTo, PointProj) :-
	vec_norm(ProjectTo, ProjectTo_norm),
	dot_prod(Point, ProjectTo_norm, LengthProj),
	scalar_prod(LengthProj, ProjectTo_norm, PointProj).

proj(Point, Project_onto, Proj) :-
	Project_norm is_v vec_norm(Project_onto),
	Proj is_v (Point * Project_norm) * Project_norm.

%% cross_prod/3
%% 
%% infers /3 is rh cross product of /1 with /2.

cross_prod([L1, L2, L3], [R1, R2, R3], [P1, P2, P3]) :-
        P1 is (L2 * R3) - (L3 * R2),
	P2 is (L3 * R1) - (L1 * R3),
	P3 is (L1 * R2) - (L2 * R1).

x([L1, L2, L3], [R1, R2, R3], [P1, P2, P3]) :-
        P1 is (L2 * R3) - (L3 * R2),
	P2 is (L3 * R1) - (L1 * R3),
	P3 is (L1 * R2) - (L2 * R1).


%% vecLength/2
%% 
%% infers the length of /1 is /2.

vec_length(Vector, Length) :-
	dot_prod(Vector, Vector, Length_sq),
	Length is sqrt(Length_sq).

vec_len(V, Length) :-
	Length is_v sqrt(V * V).
	

%% vecNorm/2
%% 
%% infers V_unit is normalized form for V.

vec_norm(V, V_unit) :-

	V_unit is_v (1.0 / vec_len(V)) * V.
/*	vec_length(V, Length_V),
	Scale_V is 1.0 / Length_V,
	scalar_prod(Scale_V, V, V_unit). */


%% dot_prod/3
%% 
%% predicate to unify /3 with the dot product of /1 and /2.

dot_prod(L, R, P) :-
	findall(Product, 
		(    nth0(N, L, L1), 
		     nth0(N, R, R1), 
		     Product is L1 * R1
		),
		Products),
	sumlist(Products, P).

*(L, R, P) :-
	length(L, Length), length(R, Length),
	findall(Prod, (nth0(N, L, L_el), nth0(N, R, R_el), 
		       Prod is L_el * R_el), 
		Prods),
	sumlist(Prods, P), !.

*(A, B, C) :-
	(   
	is_list(A),
	    findall(Prod, (member(A1, A), Prod is B * A1), C), !;
	is_list(B),
	    findall(Prod, (member(B1, B), Prod is A * B1), C)
	).


%% scalar_prod/3
%% 
%% predicate to unify /3 with the scalar product of /1 and /2.

scalar_prod(S, V, P) :-
	findall(Prod, (member(V1, V), Prod is S * V1), P).

	
%% vec_sum/3
%% 
%% asserts /1 + /2 is /3

vec_sum(L, R, S) :-
	findall(Sum, (nth0(N, L, L1), nth0(N, R, R1), Sum is L1 + R1), S).

+(L, R, S) :-
	length(L, Length), length(R, Length),
	findall(S_el, (nth0(N, L, L_el), nth0(N, R, R_el), 
		     S_el is L_el + R_el), S).

%% vec_diff/3
%% 
%% asserts /1 - /2 is /3

vec_diff(L, R, D) :-
	findall(Diff, (nth0(N, L, L1), nth0(N, R, R1), Diff is L1 - R1), D).

-(L, R, D) :-
	length(L, Length), length(R, Length),
	findall(D_el, (nth0(N, L, L_el), nth0(N, R, R_el), 
		       D_el is L_el - R_el), D).


is_v(Result, Expr) :-

	Expr =.. [Op | Args],
	atom(Op),

	(   
	current_op(_, Type, Op),

	    length(Args, Arg_count),
	    (   
	    member(Type, [xf, yf, fy, fx]), Arg_count = 1 ;
	    member(Type, [xfx,  xfy, yfx,  yfy]), Arg_count = 2 
	    ), ! ;

	current_arithmetic_function(Expr)
	),

	maplist(is_v, Args_eval, Args),

	(   
	forall(member(Arg_eval, Args_eval), number(Arg_eval)),
	    Expr_eval =.. [Op | Args_eval],
	    Result is Expr_eval, !;
	
	append([Op | Args_eval], [Result], Expr_list),
	    Expr_eval =.. Expr_list,
	    Expr_eval, !
	).

is_v(Result, Result).


%% max/2 min/2 
%% 
%% predicate to unify /2 with the minimum/maximum value in list /1.

max([X | X_t], Z) :-
	max(X_t, Z_t), 	
	Z is max(X, Z_t).

max([X], X).

min([X | X_t], Z) :-
	min(X_t, Z_t), 	
	Z is min(X, Z_t).

min([X], X).


%% isApproxEqual/3
%% 
%% predicate if A and B are within Epsilon of each other

is_approx_equal(A, B, Epsilon) :-
	Epsilon > abs(A - B).




















