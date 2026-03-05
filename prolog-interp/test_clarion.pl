% test_clarion.pl — Tests for the Clarion Prolog interpreter

:- use_module(clarion).
:- set_prolog_flag(double_quotes, codes).

mathlib_source("
  MEMBER()
  MAP
    MathAdd(LONG a, LONG b),LONG,C,NAME('MathAdd'),EXPORT
    Multiply(LONG a, LONG b),LONG,C,NAME('Multiply'),EXPORT
  END

MathAdd PROCEDURE(LONG a, LONG b)
  CODE
  RETURN(a + b)

Multiply PROCEDURE(LONG a, LONG b)
  CODE
  RETURN(a * b)
").

test_parse :-
    mathlib_source(Src),
    parse_clarion(Src, AST),
    format("=== Parsed AST ===~n"),
    print_term(AST, [indent_arguments(2)]),
    nl, nl.

test_mathadd :-
    mathlib_source(Src),
    parse_clarion(Src, AST),
    exec_procedure(AST, 'MathAdd', [3, 4], Result),
    format("MathAdd(3, 4) = ~w", [Result]),
    ( Result =:= 7 -> format(" [PASS]~n") ; format(" [FAIL: expected 7]~n") ).

test_multiply :-
    mathlib_source(Src),
    parse_clarion(Src, AST),
    exec_procedure(AST, 'Multiply', [5, 6], Result),
    format("Multiply(5, 6) = ~w", [Result]),
    ( Result =:= 30 -> format(" [PASS]~n") ; format(" [FAIL: expected 30]~n") ).

test_from_file :-
    read_file_to_codes('../python-dll/MathLib.clw', Codes, []),
    parse_clarion(Codes, AST),
    exec_procedure(AST, 'MathAdd', [10, 20], R1),
    exec_procedure(AST, 'Multiply', [7, 8], R2),
    format("From MathLib.clw:~n"),
    format("  MathAdd(10, 20) = ~w", [R1]),
    ( R1 =:= 30 -> format(" [PASS]~n") ; format(" [FAIL]~n") ),
    format("  Multiply(7, 8) = ~w", [R2]),
    ( R2 =:= 56 -> format(" [PASS]~n") ; format(" [FAIL]~n") ).

main :-
    format("--- Clarion Prolog Interpreter Tests ---~n~n"),
    test_parse,
    test_mathadd,
    test_multiply,
    test_from_file,
    format("~nAll tests complete.~n").
