%============================================================
% test_parse_coverage.pl - Constructs found by the project survey
%
% Included by test_unified.pl. Each case is parsed and run, so a
% construct that parses but computes the wrong value fails too.
% Expected values are Claude's understanding of Clarion; they have
% not been checked against the compiler.
%============================================================

% pc(Label, Globals (between MEMBER and MAP), Locals of Run, Code of Run, Expected)
pc('DIM(EQUATE)', "N EQUATE(4)\nA LONG,DIM(N)\n", "", "  A[4] = 7\n  RETURN(A[4])\n", 7).
pc('DIM of an expression', "N EQUATE(4)\nM EQUATE(N * N)\nA LONG,DIM(M + 1)\n", "", "  A[17] = 7\n  RETURN(A[17] + M)\n", 23).
pc('equate names ignore case', "Max EQUATE(4)\nA LONG,DIM(MAX)\n", "", "  A[4] = 7\n  RETURN(A[4])\n", 7).
pc('local DIM(EQUATE)', "N EQUATE(3)\n", "A LONG,DIM(N)\n", "  A[3] = 5\n  RETURN(A[3])\n", 5).
pc('LONG(EQUATE) and LONG(-EQUATE)', "N EQUATE(3)\nG LONG(N)\nH LONG(-N)\n", "", "  RETURN(G * 10 + H)\n", 27).
pc('STRING(EQUATE)', "N EQUATE(3)\nS STRING(N)\n", "", "  S = 'abcdef'\n  RETURN(LEN(S))\n", 3).
pc('BYTE(TRUE) and BYTE(FALSE)', "T BYTE(TRUE)\nF BYTE(FALSE)\n", "L BYTE(TRUE)\n", "  RETURN(T * 100 + F * 10 + L)\n", 101).
pc('REAL equate keeps its fraction', "PI EQUATE(3.14159)\n", "R REAL\n", "  R = PI * 100000\n  RETURN(ROUND(R))\n", 314159).
pc('equate of an equate keeps its fraction', "A EQUATE(2.5)\nB EQUATE(A * 2)\n", "", "  RETURN(B * 10)\n", 50).
pc('EQUATE(0FFFFFFFFh)', "M EQUATE(0FFFFFFFFh)\n", "U ULONG\n", "  U = M\n  RETURN((U = 4294967295) * 10 + (M > 0))\n", 11).
pc('unknown constant is an error', "A LONG,DIM(Nope)\n", "", "  RETURN(1)\n", error(unknown_constant('Nope'))).

pc('*= on an integer', "", "X LONG(6)\n", "  X *= 7\n  RETURN(X)\n", 42).
pc('/= on an integer truncates', "", "X LONG(7)\n", "  X /= 2\n  RETURN(X)\n", 3).
pc('*= rounds toward zero into an integer', "", "X LONG(5)\n", "  X *= 1.5\n  RETURN(X)\n", 7).
pc('/= on a REAL keeps the fraction', "", "X REAL(7)\n", "  X /= 2\n  RETURN(X * 10)\n", 35).
pc('the whole right side is one operand', "", "X LONG(10)\n", "  X *= 2 + 3\n  RETURN(X)\n", 50).
pc('-= with an expression', "", "X LONG(10)\n", "  X -= 2 - 5\n  RETURN(X)\n", 13).
pc('+= on an array element', "", "A LONG,DIM(3)\nI LONG(2)\n", "  A[I] = 5\n  A[I] += 2\n  A[I + 1] -= 4\n  RETURN(A[2] * 10 + A[3])\n", 66).
pc('*= and /= on array elements', "", "A REAL,DIM(2)\n", "  A[1] = 3\n  A[1] *= 2.5\n  A[2] = 9\n  A[2] /= 2\n  RETURN(A[1] * 100 + A[2] * 10)\n", 795.0).
pc('array op keeps the element type', "", "A BYTE,DIM(2)\n", "  A[1] = 250\n  A[1] += 10\n  RETURN(A[1])\n", 4).
pc('index of an array op is evaluated once', "C LONG(0)\n", "A LONG,DIM(5)\n", "  A[Bump()] += 5\n  RETURN(C * 10 + A[1])\n", 15).
pc('*= on SELF and group fields', "G GROUP\nX LONG\n  END\n", "", "  G.X = 3\n  G.X *= 4\n  RETURN(G.X)\n", 12).
pc('assignment through a by-reference global', "C LONG(3)\n", "", "  Twice(C)\n  RETURN(C)\n", 6).

pc('unary minus on a name', "", "X LONG(5)\n", "  RETURN(-X)\n", -5).
pc('unary minus in an expression', "", "X LONG(5)\n", "  RETURN(10 * -X - -(X + 1) + (-X - 1))\n", -50).
pc('unary minus on a call', "", "X LONG(5)\n", "  RETURN(3 + -ABS(X))\n", -2).
pc('minus between names still subtracts', "", "X LONG(5)\nY LONG(3)\n", "  RETURN(X -Y)\n", 2).
pc('unary minus of numeric text', "", "S STRING('5')\n", "  RETURN(-S)\n", -5).

pc('1.5E-3', "", "", "  RETURN(1.5E-3 * 10000)\n", 15.0).
pc('2.0e+3 and 1E3', "", "", "  RETURN(2.0e+3 + 1E3)\n", 3000.0).
pc('0E1h is still hex', "", "", "  RETURN(0E1h)\n", 225).

pc('a REAL holding a whole number divides as REAL', "", "X REAL\nY LONG(2)\n", "  X = 7\n  RETURN(X / Y * 10)\n", 35).
pc('a REAL parameter given an integer', "", "", "  RETURN(HalfOf(7) * 10)\n", 35).

pc('LOOP BY 2', "", "I LONG\nT LONG\n", "  LOOP I = 1 TO 9 BY 2\n    T += I\n  END\n  RETURN(T)\n", 25).
pc('LOOP BY -1', "", "I LONG\nT LONG\n", "  LOOP I = 3 TO 1 BY -1\n    T = T * 10 + I\n  END\n  RETURN(T)\n", 321).
pc('LOOP BY -1 that never runs', "", "I LONG\nT LONG(9)\n", "  LOOP I = 1 TO 3 BY -1\n    T = 0\n  END\n  RETURN(T)\n", 9).
pc('LOOP BY with CYCLE and BREAK', "", "I LONG\nT LONG\n", "  LOOP I = 0 TO 20 BY 5\n    IF I = 5 THEN CYCLE.\n    IF I = 15 THEN BREAK.\n    T += I\n  END\n  RETURN(T * 100 + I)\n", 1015).
pc('LOOP 3 TIMES', "", "T LONG\n", "  LOOP 3 TIMES\n    T += 2\n  END\n  RETURN(T)\n", 6).
pc('LOOP expression TIMES counts once', "", "N LONG(2)\nT LONG\n", "  LOOP N * 2 TIMES\n    N += 1\n    T += 1\n  END\n  RETURN(T)\n", 4).

pc('OF 2; statement', "", "X LONG(2)\n", "  CASE X\n  OF 1; X = 10\n  OF 2; X = 20; X += 1\n  ELSE; X = 30\n  END\n  RETURN(X)\n", 21).
pc('bare procedure call', "C LONG(0)\n", "", "  BumpOnly\n  IF C = 1 THEN BumpOnly.\n  BumpOnly   ! comment\n  RETURN(C)\n", 3).
pc('bare BEEP before IF', "", "X LONG(1)\n", "  BEEP\n  IF X = 1\n    X = 5\n  END\n  RETURN(X)\n", 5).
pc('bare call inside IF THEN ELSE', "C LONG(0)\n", "", "  IF C THEN BEEP ELSE BumpOnly.\n  RETURN(C)\n", 1).

pc('S[a:b] reads a slice', "", "S STRING('abcdef')\n", "  RETURN(S[2:4] = 'bcd')\n", 1).
pc('S[i] reads one character', "", "S STRING('abcdef')\nI LONG(3)\n", "  RETURN(S[I] = 'c')\n", 1).
pc('a slice as an argument', "", "S CSTRING(20)\n", "  S = 'ath0'\n  RETURN(UPPER(S[1:3]) = 'ATH')\n", 1).
pc('S[a:b] = text pads to the slice', "", "S STRING('abcdef')\n", "  S[2:4] = 'X'\n  RETURN(S = 'aX  ef')\n", 1).
pc('S[i] = character', "", "S STRING('abcdef')\n", "  S[1] = 'Z'\n  RETURN(S = 'Zbcdef')\n", 1).
pc('slice of an unset CSTRING is empty', "", "S CSTRING(20)\n", "  RETURN(LEN(S[1:3]))\n", 0).

pc('GROUP field initial values', "G GROUP,PRE(GG)\nA REAL(6.5)\nB LONG(2)\nC LONG\n  END\n", "", "  RETURN(GG:A * 10 + G.B + GG:C)\n", 67.0).
pc('local GROUP initial values', "", "G GROUP\nA LONG(6)\nB STRING('xy')\n  END\n", "  RETURN(G.A + LEN(CLIP(G.B)))\n", 8).
pc('a FILE named by OWNER(variable)', "Conn STRING(20)\nF FILE,DRIVER('TOPSPEED'),OWNER(Conn),PRE(FF),CREATE\nRecord RECORD\nA LONG\n  END\n  END\n", "", "  CREATE(F)\n  OPEN(F)\n  FF:A = 4\n  ADD(F)\n  RETURN(RECORDS(F))\n", 1).

pc('G.Field and PRE:Field are the same field', "G GROUP,PRE(GG)\nB LONG(2)\n  END\n", "", "  G.B += 1\n  GG:B = GG:B * 10\n  RETURN(G.B)\n", 30).
pc('a GROUP without PRE: G.Field, unassigned', "G GROUP\nA LONG\nB LONG(4)\n  END\n", "", "  RETURN(G.A * 10 + G.B)\n", 4).
pc('a GROUP without PRE: G:Field', "G GROUP\nB LONG(4)\n  END\n", "", "  G:B += 1\n  RETURN(G.B)\n", 5).
pc('G.Field converts to the field type', "G GROUP\nB BYTE\n  END\n", "", "  G.B = 300\n  RETURN(G.B)\n", 44).
pc('a called procedure does not see a local GROUP', "C LONG(0)\nG GROUP\nB LONG(9)\n  END\n", "G GROUP\nB LONG(4)\n  END\n", "  G.B = 5\n  RETURN(G.B * 10 + SeeG())\n", 59).

pc('a whole REAL joins as text without .0', "", "R REAL(7)\n", "  RETURN('<' & R & '>' = '<7>')\n", 1).
pc('a REAL array index', "", "A LONG,DIM(3)\nR REAL(2)\n", "  A[R] = 5\n  A[R + 0.5] += 1\n  RETURN(A[2])\n", 6).
pc('REAL positions in SUB, slices and INSTRING', "", "S STRING('abcdef')\nR REAL(2)\n", "  RETURN((SUB(S, R, R) = 'bc') * 100 + (S[R : R + 1] = 'bc') * 10 + INSTRING('e', S, R))\n", 115).
pc('SQRT divides as a REAL', "", "", "  RETURN(SQRT(25) / 2)\n", 2.5).
pc('REAL loop bounds', "", "I LONG\nT LONG\nR REAL(3)\n", "  LOOP I = 1 TO R\n    T += I\n  END\n  RETURN(T)\n", 6).
pc('a REAL in CASE and as a record number', "F FILE,DRIVER('TOPSPEED'),PRE(FF),CREATE\nRecord RECORD\nA LONG\n  END\n  END\n", "R REAL(1)\n", "  CREATE(F)\n  OPEN(F)\n  FF:A = 8\n  ADD(F)\n  FF:A = 0\n  GET(F, R)\n  CASE R\n  OF 1\n    RETURN(FF:A)\n  END\n  RETURN(-1)\n", 8).

% --- built-ins ---
pc('CHOOSE by number', "", "X LONG(2)\n", "  RETURN(CHOOSE(X, 10, 20, 30))\n", 20).
pc('CHOOSE out of range gives the last', "", "X LONG(9)\n", "  RETURN(CHOOSE(X, 10, 20, 30) * 100 + CHOOSE(0, 1, 2))\n", 3002).
pc('CHOOSE by condition', "", "X LONG(5)\n", "  RETURN(CHOOSE(X <> 0, 1, 2) * 10 + CHOOSE(X = 0, 1, 2))\n", 12).
pc('CHOOSE of a condition alone', "", "X LONG(5)\n", "  RETURN(CHOOSE(X = 5) * 10 + CHOOSE(X = 6))\n", 10).
pc('CHOOSE returns text', "", "X LONG(1)\n", "  RETURN(CHOOSE(X = 1, 'yes', 'no') = 'yes')\n", 1).
pc('SIN and COS in radians', "", "", "  RETURN(ROUND(SIN(0.5) * 1000000 + COS(0.5) * 1000))\n", 480303).
pc('TAN ATAN ASIN ACOS', "", "", "  RETURN(ROUND((TAN(1) + ATAN(1) + ASIN(1) + ACOS(0)) * 10000))\n", 54844).
pc('LOGE and LOG10', "", "", "  RETURN(LOG10(1000) * 10 + LOGE(1))\n", 30.0).
pc('BSHIFT left and right', "", "", "  RETURN(BSHIFT(1, 4) * 100 + BSHIFT(256, -4))\n", 1616).
pc('BSHIFT fills a right shift with zeros', "", "", "  RETURN(BSHIFT(-1, -28))\n", 15).
pc('BSHIFT drops bits past 32', "", "L LONG\n", "  L = BSHIFT(1, 31)\n  RETURN((L < 0) * 10 + BSHIFT(1, 32))\n", 10).
pc('LEFT(s, n)', "", "", "  RETURN('[' & LEFT('  ab', 5) & ']' = '[ab   ]')\n", 1).
pc('LEFT(s) keeps the length', "", "S STRING('  ab')\n", "  RETURN('[' & LEFT(S) & ']' = '[ab  ]')\n", 1).
pc('RIGHT(s) and RIGHT(s, n)', "", "S STRING('ab  ')\n", "  RETURN(('[' & RIGHT(S) & ']' = '[  ab]') * 10 + ('[' & RIGHT(S, 3) & ']' = '[ ab]'))\n", 11).
pc('LEFT and RIGHT cut to n', "", "", "  RETURN((LEFT('abcd', 2) = 'ab') * 10 + (RIGHT('abcd', 2) = 'cd'))\n", 11).
pc('CENTER', "", "", "  RETURN(('[' & CENTER('ab', 6) & ']' = '[  ab  ]') * 10 + (LEN(CENTER('ab', 5)) = 5))\n", 11).
pc('ALL', "", "", "  RETURN((ALL('ab', 5) = 'ababa') * 1000 + LEN(ALL('-')))\n", 1255).
pc('NUMERIC', "", "", "  RETURN(NUMERIC('12.5') * 1000 + NUMERIC('-3') * 100 + NUMERIC('12a') * 10 + NUMERIC(''))\n", 1100).
pc('DEFORMAT with a numeric picture', "", "", "  RETURN(DEFORMAT('$1,234.50', @n$12.2) * 2)\n", 2469.0).

% --- arrays ---
pc('a new array holds its type''s empty value', "A LONG,DIM(3)\nS STRING(4),DIM(2)\n", "", "  RETURN(A[3] * 100 + LEN(S[2]))\n", 4).
pc('every element of an array is separate', "A LONG,DIM(37)\n", "I LONG\nT LONG\n", "  LOOP I = 1 TO 37\n    A[I] = I\n  END\n  LOOP I = 37 TO 1 BY -1\n    IF A[I] <> I THEN RETURN(-I).\n    T += A[I]\n  END\n  RETURN(T)\n", 703).
pc('setting one element leaves the rest', "A LONG,DIM(5)\n", "", "  A[2] = 7\n  A[2] = 8\n  RETURN(A[1] + A[2] + A[3] + A[4] + A[5])\n", 8).
pc('SIZE of an array', "A SHORT,DIM(6)\n", "", "  RETURN(SIZE(A))\n", 12).
pc('a one-element array', "A LONG,DIM(1)\n", "", "  A[1] = 4\n  RETURN(A[1])\n", 4).
pc('writing past the end is an error', "A LONG,DIM(3)\n", "", "  A[4] = 1\n  RETURN(1)\n", error(index_out_of_range('A', 4, 3))).
pc('writing element 0 is an error', "A LONG,DIM(3)\n", "", "  A[0] = 1\n  RETURN(1)\n", error(index_out_of_range('A', 0, 3))).
pc('reading element 0 gives 0', "A LONG,DIM(3)\n", "", "  A[1] = 5\n  RETURN(A[0])\n", 0).
pc('a big array is quick', "A REAL,DIM(270400)\n", "I LONG\n", "  LOOP I = 1 TO 20000\n    A[I * 13] = I\n  END\n  RETURN(A[260000] + A[13])\n", 20001.0).

% pc_src(Label, Source, Procedure, Args, Expected)
pc_src('MEMBER globals after MAP', "  MEMBER()\nA LONG(1)\n  MAP\n    Run(),LONG\n  END\nN EQUATE(2)\nB LONG(N)\nC LONG,DIM(N)\nRun PROCEDURE()\n  CODE\n  C[2] = 5\n  RETURN(A * 100 + B * 10 + C[2])\n", 'Run', [], 125).
pc_src('PROGRAM globals before and after MAP', "  PROGRAM\nA LONG(1)\n  MAP\n    Run(),LONG\n  END\nB LONG(2)\n  CODE\n  Run()\nRun PROCEDURE()\n  CODE\n  RETURN(A * 10 + B)\n", 'Run', [], 12).
pc_src('parameters and a procedure with non-reserved names', "  MEMBER()\n  MAP\n    Run PROCEDURE(),LONG\n    Add PROCEDURE(LONG name, LONG key),LONG\n  END\nAdd PROCEDURE(LONG name, LONG key)\n  CODE\n  RETURN(name * 10 + key)\nRun PROCEDURE()\nX LONG(3)\n  CODE\n  RETURN(Add(X, 4))\n", 'Run', [], 34).
pc_src('a procedure named Add taking one variable', "  MEMBER()\n  MAP\n    Run(),LONG\n    Add(LONG a),LONG\n  END\nF FILE,DRIVER('TOPSPEED'),PRE(FF),CREATE\nRecord RECORD\nA LONG\n  END\n  END\nAdd PROCEDURE(LONG a)\n  CODE\n  RETURN(a + 1)\nRun PROCEDURE()\nX LONG(3)\n  CODE\n  CREATE(F)\n  OPEN(F)\n  ADD(F)\n  RETURN(Add(X) * 10 + RECORDS(F))\n", 'Run', [], 41).
pc_src('a label alone on a line is not swallowed', "  MEMBER()\n  MAP\n    Run(),LONG\n    Other()\n  END\nRun PROCEDURE()\nX LONG\n  CODE\n  X = 1\n  DO R1\n  RETURN(X)\nR1 ROUTINE\n  X += 1\nOther PROCEDURE\n  CODE\n", 'Run', [], 2).

pc_src('REMOVE and RENAME replace a file', "  MEMBER()\nOld FILE,DRIVER('DOS'),NAME('Old.dat'),PRE(OO),CREATE\nRecord RECORD\nA LONG\n  END\n  END\nTmp FILE,DRIVER('DOS'),NAME('Tmp.dat'),PRE(TT),CREATE\nRecord RECORD\nA LONG\n  END\n  END\n  MAP\n    Run(),LONG\n  END\nRun PROCEDURE()\n  CODE\n  CREATE(Old)\n  OPEN(Old)\n  OO:A = 1\n  ADD(Old)\n  OO:A = 2\n  ADD(Old)\n  CLOSE(Old)\n  CREATE(Tmp)\n  OPEN(Tmp)\n  TT:A = 7\n  ADD(Tmp)\n  CLOSE(Tmp)\n  REMOVE('old.dat')\n  IF ERRORCODE() THEN RETURN(-1).\n  RENAME('Tmp.dat', 'Old.dat')\n  IF ERRORCODE() THEN RETURN(-2).\n  OPEN(Old)\n  SET(Old)\n  NEXT(Old)\n  RETURN(OO:A * 10 + RECORDS(Old))\n", 'Run', [], 71).
pc_src('REMOVE of an open file is refused', "  MEMBER()\nOld FILE,DRIVER('DOS'),NAME('Old.dat'),PRE(OO),CREATE\nRecord RECORD\nA LONG\n  END\n  END\n  MAP\n    Run(),LONG\n  END\nRun PROCEDURE()\n  CODE\n  CREATE(Old)\n  OPEN(Old)\n  OO:A = 1\n  ADD(Old)\n  REMOVE(Old)\n  RETURN(ERRORCODE() * 10 + RECORDS(Old))\n", 'Run', [], 51).
pc_src('RENAME by label', "  MEMBER()\nOld FILE,DRIVER('DOS'),NAME('Old.dat'),PRE(OO),CREATE\nRecord RECORD\nA LONG\n  END\n  END\nTmp FILE,DRIVER('DOS'),NAME('Tmp.dat'),PRE(TT),CREATE\nRecord RECORD\nA LONG\n  END\n  END\n  MAP\n    Run(),LONG\n  END\nRun PROCEDURE()\n  CODE\n  CREATE(Tmp)\n  OPEN(Tmp)\n  TT:A = 7\n  ADD(Tmp)\n  CLOSE(Tmp)\n  REMOVE(Old)\n  RENAME(Tmp, 'Old.dat')\n  OPEN(Old)\n  OPEN(Tmp)\n  RETURN(RECORDS(Old) * 10 + RECORDS(Tmp))\n", 'Run', [], 10).

pc_source(Globals, Locals, Code, Src) :-
    ( sub_string(Globals, _, _, _, "C LONG(") -> Inc = "  C += 1\n" ; Inc = "" ),
    ( sub_string(Globals, _, _, _, "B LONG(9)") -> SeeG = "SeeG PROCEDURE()\n  CODE\n  RETURN(G.B)\n" ; SeeG = "SeeG PROCEDURE()\n  CODE\n  RETURN(0)\n" ),
    format(string(Src),
        "  MEMBER()\n~w  MAP\n    Run(),REAL\n    Bump(),LONG\n    BumpOnly()\n    Twice(*LONG v)\n    HalfOf(REAL r),REAL\n    SeeG(),LONG\n  END\nRun PROCEDURE()\n~w  CODE\n~wBump PROCEDURE()\n  CODE\n~w  RETURN(1)\nBumpOnly PROCEDURE()\n  CODE\n~wTwice PROCEDURE(*LONG v)\n  CODE\n  v = v * 2\nHalfOf PROCEDURE(REAL r)\n  CODE\n  RETURN(r / 2)\n~w",
        [Globals, Locals, Code, Inc, Inc, SeeG]).

pc_run(Src, Proc, Args, R) :-
    catch(call_with_time_limit(10, exec_procedure(Src, Proc, Args, R0)), E,
          ( E = error(Formal, _) -> R0 = error(Formal) ; R0 = E )), !,
    R = R0.
pc_run(_, _, _, failed).

% Run returns REAL, so whole results arrive as 7.0
pc_check(Label, R, Expected) :-
    ( number(R), number(Expected), R =:= Expected -> check(Label, ok, ok) ; check(Label, R, Expected) ).

test_parse_coverage :-
    format("~nConstructs from the project survey:~n"),
    forall(pc(Label, Globals, Locals, Code, Expected),
           ( pc_source(Globals, Locals, Code, Src),
             pc_run(Src, 'Run', [], R),
             pc_check(Label, R, Expected) )),
    forall(pc_src(Label, Src, Proc, Args, Expected),
           ( pc_run(Src, Proc, Args, R),
             pc_check(Label, R, Expected) )).
