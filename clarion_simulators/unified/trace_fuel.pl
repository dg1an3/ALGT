% trace_fuel.pl — Run FuelLib through the unified simulator
% with procedure-level trace output compatible with CDB comparison.
%
% Usage: swipl -g "main,halt" -t "halt(1)" trace_fuel.pl
%
% Output format matches compare_cdb_prolog.py expectations:
%   CALL ProcName(args) -> result
%
% FILE I/O Notes (DOS driver + simulator storage backend):
% --------------------------------------------------------
% The unified simulator's storage_memory backend supports:
%   - OPEN/CREATE/CLOSE on FILE declarations
%   - ADD (append record), SET/NEXT (sequential scan), PUT (update in place)
%   - GET by position (byte offset), CLEAR on records
%   - ERRORCODE() after file operations
%   - SIZE() for record size calculations
%
% What works for FuelLib:
%   - FLOpen/FLClose — file open/create/close lifecycle
%   - FLSetPrice/FLGetPrice — sequential scan with PUT for update, ADD for insert
%   - FLAddTransaction — sequential scan for last balance, ADD new record
%   - FLGetTransactionCount — sequential scan counting
%   - FLGetBalance — sequential scan for last balance
%   - FLRecalcBalances — GET by position + PUT update loop
%
% What does NOT work (or requires workarounds):
%   - FLGetTransaction — uses MemCopy (RtlMoveMemory via kernel32 MODULE),
%     which is a Windows API call not available in the simulator.
%     The GROUP-to-buffer copy via ADDRESS/MemCopy cannot be simulated.
%     We trace it but expect the simulator to either skip MemCopy or error.
%   - FLAddTransaction description copy — same MemCopy issue for descPtr.
%     The description field will be empty/zero in simulator output.
%   - FLDeleteTransaction — uses REMOVE/RENAME on filenames, which the
%     in-memory storage backend does not support. Also uses a TempFile
%     for the copy-skip pattern. This procedure will likely fail or
%     need a custom simulator extension.
%   - ADDRESS() builtin — returns memory address; not meaningful in simulator.
%
% For trace comparison, we focus on procedures that work without MemCopy:
%   FLOpen, FLClose, FLSetPrice, FLGetPrice, FLGetTransactionCount,
%   FLGetBalance, FLRecalcBalances
%
% FLAddTransaction is traced but description will be empty (no MemCopy).
% FLDeleteTransaction and FLGetTransaction are omitted from comparison.

:- use_module(clarion).

main :-
    read_file_to_string('../../clarion_projects/ssm-fuel/FuelLib.clw', Src, []),
    init_session(Src, S0),

    % Open files
    call_procedure(S0, 'FLOpen', [], R0, S1),
    format("CALL FLOpen() -> ~w~n", [R0]),

    % Set prices for 4 fuel types
    call_procedure(S1, 'FLSetPrice', [1, 359], R1, S2),
    format("CALL FLSetPrice(1, 359) -> ~w~n", [R1]),

    call_procedure(S2, 'FLSetPrice', [2, 389], R2, S3),
    format("CALL FLSetPrice(2, 389) -> ~w~n", [R2]),

    call_procedure(S3, 'FLSetPrice', [3, 419], R3, S4),
    format("CALL FLSetPrice(3, 419) -> ~w~n", [R3]),

    call_procedure(S4, 'FLSetPrice', [4, 399], R4, S5),
    format("CALL FLSetPrice(4, 399) -> ~w~n", [R4]),

    % Invalid fuel type
    call_procedure(S5, 'FLSetPrice', [5, 100], R5, S6),
    format("CALL FLSetPrice(5, 100) -> ~w~n", [R5]),

    % Get prices back
    call_procedure(S6, 'FLGetPrice', [1], R6, S7),
    format("CALL FLGetPrice(1) -> ~w~n", [R6]),

    call_procedure(S7, 'FLGetPrice', [3], R7, S8),
    format("CALL FLGetPrice(3) -> ~w~n", [R7]),

    call_procedure(S8, 'FLGetPrice', [5], R8, S9),
    format("CALL FLGetPrice(5) -> ~w~n", [R8]),

    % Add transactions (descPtr=0, descLen=0 since MemCopy not available)
    call_procedure(S9, 'FLAddTransaction', [3, 1, 2026, 8, 0, 0, 0, 50000], R9, S10),
    format("CALL FLAddTransaction(3, 1, 2026, 8, 0, 0, 0, 50000) -> ~w~n", [R9]),

    call_procedure(S10, 'FLAddTransaction', [3, 1, 2026, 10, 30, 0, 0, -1500], R10, S11),
    format("CALL FLAddTransaction(3, 1, 2026, 10, 30, 0, 0, -1500) -> ~w~n", [R10]),

    call_procedure(S11, 'FLAddTransaction', [3, 2, 2026, 14, 15, 0, 0, -2500], R11, S12),
    format("CALL FLAddTransaction(3, 2, 2026, 14, 15, 0, 0, -2500) -> ~w~n", [R11]),

    % Check count and balance
    call_procedure(S12, 'FLGetTransactionCount', [], R12, S13),
    format("CALL FLGetTransactionCount() -> ~w~n", [R12]),

    call_procedure(S13, 'FLGetBalance', [], R13, S14),
    format("CALL FLGetBalance() -> ~w~n", [R13]),

    % Recalc balances (should be no-op, already correct)
    call_procedure(S14, 'FLRecalcBalances', [], R14, S15),
    format("CALL FLRecalcBalances() -> ~w~n", [R14]),

    % Close
    call_procedure(S15, 'FLClose', [], R15, _),
    format("CALL FLClose() -> ~w~n", [R15]).
