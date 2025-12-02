%============================================================
% interpreter.pl - Clarion AST Execution Engine
%
% Main entry point for the interpreter. Re-exports the core
% interpreter functionality from the modular implementation.
%
% Module Structure:
%   interpreter.pl          - This file, main entry point
%   interpreter_core.pl     - Entry points, statement execution
%   interpreter_state.pl    - State management, variables
%   interpreter_eval.pl     - Expression evaluation
%   interpreter_builtins.pl - Built-in functions, file I/O
%   interpreter_classes.pl  - Class/instance management
%   interpreter_control.pl  - Control flow helpers
%============================================================

:- module(interpreter, [
    run_file/1,
    run_ast/1,
    run_ast/2
]).

:- use_module(interpreter_core).
