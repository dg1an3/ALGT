%============================================================
% test_fidelity.pl - Language semantics that used to be silently wrong
%
% Included by test_unified.pl. Expected values are Claude's
% understanding of Clarion; they have not been checked against the
% compiler or the manual.
%============================================================

% fid(Label, Globals, Map, Locals, Code, Procs, Expected)
% Source: MEMBER(), Globals, MAP with T(),LONG plus Map, then T and Procs.
fid_source(Globals, Map, Locals, Code, Procs, Src) :-
    format(string(Src),
        "  MEMBER()\n~w  MAP\n    T(),LONG\n~w  END\nT PROCEDURE()\n~w  CODE\n~w~w",
        [Globals, Map, Locals, Code, Procs]).

run_fid(fid(Label, Globals, Map, Locals, Code, Procs, Expected)) :-
    fid_source(Globals, Map, Locals, Code, Procs, Src),
    ( catch(fid_result(Src, Result), error(E, _), Result = error(E))
    -> true
    ;  Result = failed
    ),
    check(Label, Result, Expected).

fid_result(Src, Result) :-
    with_output_to(string(_), exec_procedure(Src, 'T', [], Result)).

test_fidelity :-
    format("~nLanguage fidelity tests:~n"),
    forall(fid_case(Case), run_fid(Case)).

fid_case(fid(Label, G, Map, Loc, Code, Procs, Exp)) :-
    fid(Label, G0, Map, Loc, Code, Procs, Exp),
    ( G0 = files(Extra) -> fid_files(F), string_concat(F, Extra, G) ; G = G0 ).

fid_files("Item FILE,DRIVER('TOPSPEED'),PRE(ITM),CREATE\nKeyID KEY(ITM:ID),PRIMARY\nKeyNm KEY(ITM:Nm),DUP,NOCASE\nRecord RECORD\nID LONG\nNm STRING(10)\n  END\n  END\nSub FILE,DRIVER('TOPSPEED'),PRE(SUB),CREATE\nKeyID KEY(SUB:ID),PRIMARY\nKeyItem KEY(SUB:Item),DUP\nRecord RECORD\nID LONG\nItem LONG\n  END\n  END\n").

% --- Calls inside expressions keep their side effects ---
fid('call in IF keeps global change', "G LONG\n", "    P(),LONG\n", "", "  IF P() = 1 THEN G += 10.\n  RETURN(G)\n",
    "P PROCEDURE()\n  CODE\n  G = 5\n  RETURN(1)\n", 15).
fid('call in IF keeps file change', files(""), "    DoAdd:Item(),LONG\n", "", "  OPEN(Item)\n  ITM:ID = 1\n  IF DoAdd:Item() THEN RETURN(-1).\n  RETURN(RECORDS(Item))\n",
    "DoAdd:Item PROCEDURE()\n  CODE\n  ADD(Item)\n  RETURN(ERRORCODE())\n", 1).
fid('call in assignment keeps change', "G LONG\n", "    P(),LONG\n", "X LONG\n", "  X = P() + P()\n  RETURN(G * 100 + X)\n",
    "P PROCEDURE()\n  CODE\n  G += 1\n  RETURN(G)\n", 203).
fid('call in RETURN keeps change', "G LONG\n", "    P(),LONG\n    Q(),LONG\n", "X LONG\n", "  X = Q()\n  RETURN(G)\n",
    "P PROCEDURE()\n  CODE\n  G = 7\n  RETURN(1)\nQ PROCEDURE()\n  CODE\n  RETURN(P())\n", 7).
fid('call as argument keeps change', "G LONG\n", "    P(),LONG\n    Q(LONG a),LONG\n", "X LONG\n", "  X = Q(P())\n  RETURN(G * 10 + X)\n",
    "P PROCEDURE()\n  CODE\n  G = 7\n  RETURN(1)\nQ PROCEDURE(LONG a)\n  CODE\n  RETURN(a + 1)\n", 72).
fid('call in LOOP WHILE keeps change', "G LONG\n", "    P(),LONG\n", "X LONG\n", "  LOOP WHILE P() < 4\n    X += 1\n  END\n  RETURN(G * 10 + X)\n",
    "P PROCEDURE()\n  CODE\n  G += 1\n  RETURN(G)\n", 43).
fid('call in CASE keeps change', "G LONG\n", "    P(),LONG\n", "", "  CASE P()\n  OF 1\n    G += 1\n  END\n  RETURN(G)\n",
    "P PROCEDURE()\n  CODE\n  G = 5\n  RETURN(1)\n", 6).
fid('call in ELSIF keeps change', "G LONG\n", "    P(),LONG\n", "", "  IF 1 = 2\n    G = 99\n  ELSIF P() = 1\n    G += 1\n  END\n  RETURN(G)\n",
    "P PROCEDURE()\n  CODE\n  G = 5\n  RETURN(1)\n", 6).
fid('call in ~P() keeps change', "G LONG\n", "    P(),LONG\n", "", "  IF ~P() THEN RETURN(G).\n  RETURN(-1)\n",
    "P PROCEDURE()\n  CODE\n  G = 5\n  RETURN(0)\n", 5).
fid('falling off the end of a LONG function gives 0', "", "    P(),LONG\n", "", "  IF P() THEN RETURN(1).\n  RETURN(2)\n",
    "P PROCEDURE()\n  CODE\n", 2).

% --- Scope ---
fid('callee local does not overwrite caller local', "", "    P()\n", "X LONG\n", "  X = 1\n  P()\n  RETURN(X)\n",
    "P PROCEDURE()\nX LONG\n  CODE\n  X = 9\n", 1).
fid('callee parameter does not overwrite global', "X LONG\n", "    P(LONG X)\n", "", "  X = 1\n  P(9)\n  RETURN(X)\n",
    "P PROCEDURE(LONG X)\n  CODE\n  X += 1\n", 1).
fid('recursion keeps each level of locals', "", "    F(LONG n),LONG\n", "", "  RETURN(F(5))\n",
    "F PROCEDURE(LONG n)\nR LONG\n  CODE\n  IF n <= 1 THEN RETURN(1).\n  R = F(n - 1)\n  RETURN(n * R)\n", 120).
fid('callee sees global, not caller local', "X LONG(5)\n", "    P(),LONG\n", "X LONG\n", "  X = 1\n  RETURN(P())\n",
    "P PROCEDURE()\n  CODE\n  RETURN(X)\n", 5).
fid('callee changes global, caller local kept', "X LONG(5)\n", "    P()\n    Q(),LONG\n", "X LONG\n", "  X = 1\n  P()\n  RETURN(Q() * 10 + X)\n",
    "P PROCEDURE()\n  CODE\n  X = 8\nQ PROCEDURE()\n  CODE\n  RETURN(X)\n", 81).
fid('EXIT inside LOOP leaves the routine', "", "", "X LONG\n", "  DO R\n  RETURN(X)\nR ROUTINE\n  LOOP\n    X += 1\n    IF X = 3 THEN EXIT.\n    IF X > 50 THEN BREAK.\n  END\n  X = 99\n", "", 3).

% --- By reference ---
fid('*LONG changes caller variable', "", "    Inc(*LONG v)\n", "X LONG\n", "  X = 1\n  Inc(X)\n  RETURN(X)\n",
    "Inc PROCEDURE(*LONG v)\n  CODE\n  v += 1\n", 2).
fid('LONG by value does not', "", "    Inc(LONG v)\n", "X LONG\n", "  X = 1\n  Inc(X)\n  RETURN(X)\n",
    "Inc PROCEDURE(LONG v)\n  CODE\n  v += 1\n", 1).
fid('*LONG through two levels', "", "    A(*LONG v)\n    B(*LONG v)\n", "X LONG\n", "  X = 1\n  A(X)\n  RETURN(X)\n",
    "A PROCEDURE(*LONG v)\n  CODE\n  B(v)\n  v += 1\nB PROCEDURE(*LONG v)\n  CODE\n  v = v * 10\n", 11).
fid('*LONG with a file field', files(""), "    Inc(*LONG v)\n", "", "  ITM:ID = 4\n  Inc(ITM:ID)\n  RETURN(ITM:ID)\n",
    "Inc PROCEDURE(*LONG v)\n  CODE\n  v += 1\n", 5).
fid('*LONG with an array element', "", "    Inc(*LONG v)\n", "A LONG,DIM(3)\n", "  A[2] = 4\n  Inc(A[2])\n  RETURN(A[2])\n",
    "Inc PROCEDURE(*LONG v)\n  CODE\n  v += 1\n", 5).
fid('*LONG from a call in an expression', "", "    Inc(*LONG v),LONG\n", "X LONG\nY LONG\n", "  X = 1\n  Y = Inc(X) + 100\n  RETURN(Y + X * 1000)\n",
    "Inc PROCEDURE(*LONG v)\n  CODE\n  v += 1\n  RETURN(v)\n", 2102).

fid('method keeps global change', "Box CLASS,TYPE\nX LONG\nBump PROCEDURE(LONG n)\n  END\nG LONG\n", "", "o Box\n", "  o.Bump(3)\n  RETURN(G * 10 + o.X)\n",
    "Box.Bump PROCEDURE(LONG n)\n  CODE\n  G = n + 1\n  SELF.X = n\n", 43).
fid('method local does not overwrite caller local', "Box CLASS,TYPE\nX LONG\nBump PROCEDURE(LONG n)\n  END\n", "", "o Box\nK LONG\n", "  K = 1\n  o.Bump(3)\n  RETURN(K)\n",
    "Box.Bump PROCEDURE(LONG n)\nK LONG\n  CODE\n  K = 9\n", 1).
fid('queue prefix reaches the queue buffer', "Q QUEUE,PRE(QQ)\nV LONG\n  END\n", "", "", "  QQ:V = 5\n  ADD(Q)\n  QQ:V = 9\n  GET(Q, 1)\n  RETURN(QQ:V)\n", "", 5).
fid('local queue prefix', "", "", "Q QUEUE,PRE(QQ)\nV LONG\n  END\n", "  QQ:V = 5\n  ADD(Q)\n  QQ:V = 9\n  GET(Q, 1)\n  RETURN(QQ:V)\n", "", 5).

% --- Case ---
fid('variable names ignore case', "", "", "Abc LONG\n", "  ABC = 3\n  RETURN(abc)\n", "", 3).
fid('procedure names ignore case', "", "    DoIt(),LONG\n", "", "  RETURN(DOIT())\n", "doit PROCEDURE()\n  CODE\n  RETURN(4)\n", 4).
fid('prefixed fields ignore case', files(""), "", "", "  itm:id = 6\n  RETURN(ITM:ID)\n", "", 6).
fid('file labels ignore case', files(""), "", "", "  OPEN(ITEM)\n  ITM:ID = 1\n  ADD(item)\n  RETURN(records(Item))\n", "", 1).
fid('literals keep their case', "", "", "", "  IF 'Abc' = 'abc' THEN RETURN(1).\n  RETURN(0)\n", "", 0).
fid('quoted names and comments are untouched', "", "", "Nm STRING(9)\n", "  ! nm don't\n  Nm = 'NM it''s'\n  IF nm = 'NM it''s' THEN RETURN(1).\n  RETURN(0)\n", "", 1).

% --- Strings ---
fid('STRING(5) is padded: LEN', "", "", "S STRING(5)\n", "  S = 'ab'\n  RETURN(LEN(S))\n", "", 5).
fid('unset STRING(5) is blank', "", "", "S STRING(5)\n", "  IF S = '' THEN RETURN(LEN(S)).\n  RETURN(-1)\n", "", 5).
fid('STRING(3) truncates', "", "", "S STRING(3)\n", "  S = 'abcdef'\n  IF S = 'abc' THEN RETURN(LEN(S)).\n  RETURN(0)\n", "", 3).
fid('CSTRING(4) holds 3 characters', "", "", "S CSTRING(4)\n", "  S = 'abcdef'\n  RETURN(LEN(S))\n", "", 3).
fid('padding shows in concatenation', "", "", "S STRING(5)\n", "  S = 'ab'\n  IF S & 'x' = 'ab   x' THEN RETURN(1).\n  RETURN(0)\n", "", 1).
fid('LEN(CLIP(S))', "", "", "S STRING(5)\n", "  S = 'ab'\n  RETURN(LEN(CLIP(S)))\n", "", 2).
fid('comparison ignores trailing spaces', "", "", "S STRING(5)\n", "  S = 'ab'\n  IF S = 'ab' AND 'ab  ' = S THEN RETURN(1).\n  RETURN(0)\n", "", 1).
fid('built string equals literal', "", "", "", "  IF 'ab' & 'cd' = 'abcd' THEN RETURN(1).\n  RETURN(0)\n", "", 1).
fid('string ordering', "", "", "", "  IF 'abc' < 'abd' AND 'b' > 'abc' THEN RETURN(1).\n  RETURN(0)\n", "", 1).
fid('blank string is false', "", "", "S STRING(5)\n", "  IF S THEN RETURN(1).\n  RETURN(0)\n", "", 0).
fid('CASE on padded string', "", "", "S STRING(5)\n", "  S = 'ab'\n  CASE S\n  OF 'ab'\n    RETURN(1)\n  END\n  RETURN(0)\n", "", 1).
fid('file STRING field is padded', files(""), "", "", "  ITM:Nm = 'ab'\n  RETURN(LEN(ITM:Nm))\n", "", 10).
fid('number assigned to STRING', "", "", "S STRING(5)\n", "  S = 42\n  IF S = '42' THEN RETURN(LEN(CLIP(S))).\n  RETURN(0)\n", "", 2).

% --- Numbers ---
fid('BYTE wraps', "", "", "B BYTE\n", "  B = 256\n  RETURN(B)\n", "", 0).
fid('BYTE -1 is 255', "", "", "B BYTE\n", "  B = 0 - 1\n  RETURN(B)\n", "", 255).
fid('SHORT wraps', "", "", "W SHORT\n", "  W = 32768\n  RETURN(W)\n", "", -32768).
fid('LONG wraps', "", "", "L LONG\n", "  L = 2147483647\n  L += 1\n  RETURN(L)\n", "", -2147483648).
fid('REAL to LONG truncates', "", "", "L LONG\n", "  L = 2.9\n  RETURN(L)\n", "", 2).
fid('negative REAL to LONG truncates toward 0', "", "", "L LONG\n", "  L = 0 - 2.9\n  RETURN(L)\n", "", -2).
fid('numeric string to LONG', "", "", "L LONG\n", "  L = '17'\n  RETURN(L + 1)\n", "", 18).
fid('padded numeric string in arithmetic', "", "", "S STRING(5)\n", "  S = '17'\n  RETURN(S + 1)\n", "", 18).
fid('numeric string = number', "", "", "", "  IF '5' = 5 THEN RETURN(1).\n  RETURN(0)\n", "", 1).
fid('1.0 = 1', "", "", "", "  IF 1.0 = 1 THEN RETURN(1).\n  RETURN(0)\n", "", 1).
fid('BYTE parameter wraps', "", "    P(BYTE b),LONG\n", "", "  RETURN(P(257))\n", "P PROCEDURE(BYTE b)\n  CODE\n  RETURN(b)\n", 1).
fid('BYTE array element wraps', "", "", "A BYTE,DIM(2)\n", "  A[1] = 300\n  RETURN(A[1])\n", "", 44).
fid('BYTE return value wraps', "", "    P(),BYTE\n", "", "  RETURN(P())\n", "P PROCEDURE()\n  CODE\n  RETURN(300)\n", 44).

% --- Keys ---
fid('GET by key', files(""), "", "", "  OPEN(Item)\n  ITM:ID=1\n  ITM:Nm='one'\n  ADD(Item)\n  ITM:ID=2\n  ITM:Nm='two'\n  ADD(Item)\n  ITM:ID=1\n  GET(Item,ITM:KeyID)\n  IF ERRORCODE() THEN RETURN(-1).\n  IF ITM:Nm = 'one' THEN RETURN(1).\n  RETURN(0)\n", "", 1).
fid('GET miss is 35', files(""), "", "", "  OPEN(Item)\n  ITM:ID=9\n  GET(Item,ITM:KeyID)\n  RETURN(ERRORCODE())\n", "", 35).
fid('GET by NOCASE key', files(""), "", "", "  OPEN(Item)\n  ITM:ID=3\n  ITM:Nm='Abc'\n  ADD(Item)\n  CLEAR(ITM:Record)\n  ITM:Nm='aBC'\n  GET(Item,ITM:KeyNm)\n  RETURN(ITM:ID)\n", "", 3).
fid('GET then PUT changes that record', files(""), "", "", "  OPEN(Item)\n  ITM:ID=1\n  ADD(Item)\n  ITM:ID=2\n  ADD(Item)\n  ITM:ID=1\n  GET(Item,ITM:KeyID)\n  ITM:ID=7\n  PUT(Item)\n  ITM:ID=7\n  GET(Item,ITM:KeyID)\n  RETURN(ERRORCODE()*10+RECORDS(Item))\n", "", 2).
fid('duplicate ADD is 40', files(""), "", "", "  OPEN(Item)\n  ITM:ID=1\n  ADD(Item)\n  ADD(Item)\n  RETURN(ERRORCODE()*10+RECORDS(Item))\n", "", 401).
fid('duplicate on DUP key allowed', files(""), "", "", "  OPEN(Sub)\n  SUB:ID=1\n  SUB:Item=5\n  ADD(Sub)\n  SUB:ID=2\n  ADD(Sub)\n  RETURN(ERRORCODE()*10+RECORDS(Sub))\n", "", 2).
fid('PUT to a duplicate key is 40', files(""), "", "", "  OPEN(Item)\n  ITM:ID=1\n  ADD(Item)\n  ITM:ID=2\n  ADD(Item)\n  ITM:ID=1\n  PUT(Item)\n  RETURN(ERRORCODE())\n", "", 40).
fid('PUT keeping its own key is allowed', files(""), "", "", "  OPEN(Item)\n  ITM:ID=1\n  ADD(Item)\n  ITM:Nm='x'\n  PUT(Item)\n  RETURN(ERRORCODE())\n", "", 0).

% --- Sequential processing ---
fid('SET(key)/NEXT is in key order', files(""), "", "", "  OPEN(Item)\n  ITM:ID=5\n  ADD(Item)\n  ITM:ID=2\n  ADD(Item)\n  ITM:ID=9\n  ADD(Item)\n  SET(ITM:KeyID)\n  NEXT(Item)\n  IF ITM:ID <> 2 THEN RETURN(-1).\n  NEXT(Item)\n  RETURN(ITM:ID)\n", "", 5).
fid('SET(key)/PREVIOUS is from the last', files(""), "", "", "  OPEN(Item)\n  ITM:ID=5\n  ADD(Item)\n  ITM:ID=9\n  ADD(Item)\n  ITM:ID=2\n  ADD(Item)\n  SET(ITM:KeyID)\n  PREVIOUS(Item)\n  RETURN(ITM:ID)\n", "", 9).
fid('SET(file)/NEXT is in record order', files(""), "", "", "  OPEN(Item)\n  ITM:ID=5\n  ADD(Item)\n  ITM:ID=2\n  ADD(Item)\n  SET(Item)\n  NEXT(Item)\n  RETURN(ITM:ID)\n", "", 5).
fid('SET(key,key) child scan', files(""), "", "C LONG\n", "  OPEN(Sub)\n  SUB:ID=1\n  SUB:Item=6\n  ADD(Sub)\n  SUB:ID=2\n  SUB:Item=5\n  ADD(Sub)\n  SUB:ID=3\n  SUB:Item=6\n  ADD(Sub)\n  SUB:ID=4\n  SUB:Item=7\n  ADD(Sub)\n  SUB:Item=6\n  SET(SUB:KeyItem,SUB:KeyItem)\n  LOOP\n    NEXT(Sub)\n    IF ERRORCODE() THEN BREAK.\n    IF SUB:Item <> 6 THEN BREAK.\n    C = C * 10 + SUB:ID\n  END\n  RETURN(C)\n", "", 13).
fid('SET(key,key) starts at the next higher value', files(""), "", "", "  OPEN(Item)\n  ITM:ID=2\n  ADD(Item)\n  ITM:ID=9\n  ADD(Item)\n  ITM:ID=5\n  SET(ITM:KeyID,ITM:KeyID)\n  NEXT(Item)\n  RETURN(ITM:ID)\n", "", 9).
fid('DELETE during a scan visits each record once', files(""), "", "C LONG\n", "  OPEN(Item)\n  LOOP C = 1 TO 4\n    ITM:ID = C\n    ADD(Item)\n  END\n  C = 0\n  SET(Item)\n  LOOP\n    NEXT(Item)\n    IF ERRORCODE() THEN BREAK.\n    C = C * 10 + ITM:ID\n    IF ITM:ID = 2 THEN DELETE(Item).\n  END\n  RETURN(C * 10 + RECORDS(Item))\n", "", 12343).
fid('DELETE during a keyed scan', files(""), "", "C LONG\n", "  OPEN(Sub)\n  LOOP C = 1 TO 4\n    SUB:ID = C\n    SUB:Item = 6\n    ADD(Sub)\n  END\n  C = 0\n  SUB:Item = 6\n  SET(SUB:KeyItem,SUB:KeyItem)\n  LOOP\n    NEXT(Sub)\n    IF ERRORCODE() THEN BREAK.\n    C = C * 10 + SUB:ID\n    IF SUB:ID < 4 THEN DELETE(Sub).\n  END\n  RETURN(C * 10 + RECORDS(Sub))\n", "", 12341).
fid('GET does not move the scan', files(""), "", "", "  OPEN(Item)\n  ITM:ID=1\n  ADD(Item)\n  ITM:ID=2\n  ADD(Item)\n  ITM:ID=3\n  ADD(Item)\n  SET(Item)\n  NEXT(Item)\n  ITM:ID=3\n  GET(Item,ITM:KeyID)\n  NEXT(Item)\n  RETURN(ITM:ID)\n", "", 2).
fid('SET on an unknown key is an error', files(""), "", "", "  OPEN(Item)\n  SET(ITM:Nope)\n  RETURN(ERRORCODE())\n", "", 47).

% --- SIZE and record position ---
fid('SIZE(PRE:Record)', files(""), "", "", "  RETURN(SIZE(ITM:Record))\n", "", 14).
fid('SIZE of a field', files(""), "", "", "  RETURN(SIZE(ITM:Nm))\n", "", 10).
fid('SIZE of mixed types', "G GROUP,PRE(GG)\nA BYTE\nB SHORT\nC REAL\nD CSTRING(5)\nE DECIMAL(7,2)\n  END\n", "", "", "  RETURN(SIZE(G))\n", "", 20).
fid('SIZE of variables', "", "", "S STRING(7)\nB BYTE\nA SHORT,DIM(4)\n", "  RETURN(SIZE(S) * 100 + SIZE(B) * 10 + SIZE(A))\n", "", 718).
fid('DOS GET is by byte position', "D FILE,DRIVER('DOS'),PRE(DD),CREATE\nRecord RECORD\nA LONG\nB SHORT\n  END\n  END\n", "", "", "  OPEN(D)\n  DD:A = 10\n  ADD(D)\n  DD:A = 20\n  ADD(D)\n  GET(D, 1 * SIZE(DD:Record) + 1)\n  RETURN(DD:A * 10 + POINTER(D))\n", "", 207).
fid('TOPSPEED GET is by record number', files(""), "", "", "  OPEN(Item)\n  ITM:ID = 10\n  ADD(Item)\n  ITM:ID = 20\n  ADD(Item)\n  GET(Item, 2)\n  RETURN(ITM:ID)\n", "", 20).

% --- Error codes ---
fid('ADD before OPEN is 37', files(""), "", "", "  ADD(Item)\n  RETURN(ERRORCODE()*10+RECORDS(Item))\n", "", 370).
fid('NEXT before OPEN is 37', files(""), "", "", "  NEXT(Item)\n  RETURN(ERRORCODE())\n", "", 37).
fid('PUT before OPEN is 37', files(""), "", "", "  PUT(Item)\n  RETURN(ERRORCODE())\n", "", 37).
fid('DELETE before OPEN is 37', files(""), "", "", "  DELETE(Item)\n  RETURN(ERRORCODE())\n", "", 37).
fid('GET before OPEN is 37', files(""), "", "", "  GET(Item,ITM:KeyID)\n  RETURN(ERRORCODE())\n", "", 37).
fid('ADD after CLOSE is 37', files(""), "", "", "  OPEN(Item)\n  CLOSE(Item)\n  ADD(Item)\n  RETURN(ERRORCODE())\n", "", 37).
fid('second OPEN is 52', files(""), "", "", "  OPEN(Item)\n  OPEN(Item)\n  RETURN(ERRORCODE())\n", "", 52).
fid('NEXT past the end is 33', files(""), "", "", "  OPEN(Item)\n  SET(Item)\n  NEXT(Item)\n  RETURN(ERRORCODE())\n", "", 33).
fid('queue GET with a variable pointer', "Q QUEUE\nV LONG\n  END\n", "", "I LONG\n", "  Q.V = 10\n  ADD(Q)\n  Q.V = 20\n  ADD(Q)\n  I = 1\n  GET(Q, I)\n  RETURN(Q.V)\n", "", 10).
fid('queue GET past the end is 30', "Q QUEUE\nV LONG\n  END\n", "", "", "  GET(Q, 3)\n  RETURN(ERRORCODE())\n", "", 30).

% --- Nothing is skipped silently ---
fid('unresolved external call is an error', "", "    MODULE('other')\n      DoDelete:Item(),LONG\n    END\n", "", "  IF DoDelete:Item() THEN RETURN(1).\n  RETURN(0)\n", "",
    error(unresolved_external('DoDelete:Item', other))).
fid('MODULE procedure defined here is called', "", "    MODULE('other')\n      DoDelete:Item(),LONG\n    END\n", "", "  RETURN(DoDelete:Item())\n", "DoDelete:Item PROCEDURE()\n  CODE\n  RETURN(6)\n", 6).
fid('built-in with bad arguments names the built-in', "", "", "X LONG\n", "  X = INSTRING('a')\n  RETURN(X)\n", "", error(builtin_failed('INSTRING', 1))).

test_fidelity_stubs :-
    format("~nExplicit external stubs:~n"),
    fid_source("", "    MODULE('other')\n      Ext(LONG x),LONG\n    END\n", "", "  RETURN(Ext(3))\n", "", Src),
    with_external_stubs(['Ext' = 12], fid_result(Src, R1)),
    check('stubbed external returns its value', R1, 12),
    ( catch(fid_result(Src, _), error(unresolved_external('Ext', other), _), R2 = refused) -> true ; R2 = failed ),
    check('stub does not outlive its scope', R2, refused).

% The simulator must work from any directory.
test_fidelity_any_directory :-
    format("~nLoad path:~n"),
    module_property(clarion, file(ClarionFile)),
    current_prolog_flag(executable, Exe),
    format(atom(Goal), "use_module('~w'),init_session(\"  MEMBER()\\nQ QUEUE\\nV LONG\\n  END\\n  MAP\\n    T(),LONG\\n  END\\nT PROCEDURE()\\n  CODE\\n  ADD(Q)\\n  RETURN(RECORDS(Q))\\n\",S),call_procedure(S,'T',[],R,_),(R==1->halt(0);halt(3))", [ClarionFile]),
    tmp_file(anydir, Dir), make_directory(Dir),
    setup_call_cleanup(
        process_create(Exe, ['-g', Goal, '-t', 'halt(1)'],
                       [cwd(Dir), stdin(null), stdout(null), stderr(null), process(Pid)]),
        process_wait(Pid, Status),
        delete_directory(Dir)),
    check('runs from another directory', Status, exit(0)).
