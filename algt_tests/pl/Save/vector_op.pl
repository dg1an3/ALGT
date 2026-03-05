:- op(700, xfx, is_v),
	op(400, yfx, x),
	op(400, yfx, proj),
	arithmetic_function(vec_len/1).

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

x([Ax, Ay, Az], [Bx, By, Bz], [Cx, Cy, Cz]) :-
	Cx is Ay * Bz - Az * By,
	Cy is Ax * Bz - Az * Bx,
	Cz is Ax * By - Ay * Bx.

proj(A, B, C) :-
	C is_v A * B.

vec_len(V, Length) :-
	Length is_v sqrt(V * V).
	
+(A, B, C) :-
	length(A, Length),
	length(B, Length),
	findall(El, (nth0(N, A, A1), nth0(N, B, B1), El is A1 + B1), C).

-(A, B, C) :-
	length(A, Length),
	length(B, Length),
	findall(El, (nth0(N, A, A1), nth0(N, B, B1), El is A1 - B1), C).

*(A, B, C) :-
	length(A, Length),
	length(B, Length),
	findall(Prod, (nth0(N, A, A1), nth0(N, B, B1), Prod is A1 * B1), 
		Prods),
	sumlist(Prods, C), !.

*(A, B, C) :-
	(   
	is_list(A),
	    findall(Prod, (member(A1, A), Prod is B * A1), C), !;
	is_list(B),
	    findall(Prod, (member(B1, B), Prod is A * B1), C)
	).









