%============================================================
% interpreter.pl - Clarion AST Execution Engine
%
% Main entry point for the interpreter. It loads the core
% interpreter logic.
%============================================================

:- module(interpreter, [
    run_file/1,
    run_ast/1,
    run_ast/2
]).

:- use_module(interpreter_logic).
