% trace_quickdraw.pl — QuickDraw type operations through the unified simulator
%
% Usage: swipl -g "main,halt" -t "halt(1)" trace_quickdraw.pl
%
% LIMITATION: QuickDrawTypes.clw uses ADDRESS/MemCopy to pass structured
% data (Points, Rects) via LONG pointers. The unified Prolog simulator
% does not support ADDRESS() or MemCopy (RtlMoveMemory), because it has
% no concept of memory addresses or raw byte copying.
%
% All 12 QuickDraw procedures (QDSetPt, QDEqualPt, QDAddPt, QDSubPt,
% QDSetRect, QDEqualRect, QDEmptyRect, QDOffsetRect, QDInsetRect,
% QDSectRect, QDUnionRect, QDPtInRect) take LONG pointer arguments and
% use MemCopy to marshal data between caller-allocated structs and the
% module-level GROUP variables. This pattern cannot be simulated because:
%
%   1. ADDRESS(GroupName) returns a runtime memory address — the Prolog
%      simulator has no memory model, so ADDRESS is meaningless.
%   2. MemCopy(dest, src, len) does raw byte copying between addresses —
%      the simulator operates on symbolic variable bindings, not bytes.
%   3. The caller (Python/ctypes) allocates structs and passes their
%      addresses as LONG values — there is no ctypes equivalent in Prolog.
%
% ALTERNATIVE: To test the *logic* of these operations in the simulator,
% one would need a version of the .clw that uses direct GROUP field access
% instead of pointer-based MemCopy. Below we demonstrate what that would
% look like, using pure Prolog to replicate the QuickDraw semantics.

:- use_module(clarion).

%% QuickDraw Point operations in pure Prolog
%% These mirror the Clarion logic without ADDRESS/MemCopy.

% SetPt: set h and v fields
qd_set_pt(H, V, point(H, V)).

% EqualPt: compare two points
qd_equal_pt(point(V, H), point(V, H), 1) :- !.
qd_equal_pt(_, _, 0).

% AddPt: dst += src
qd_add_pt(point(SV, SH), point(DV, DH), point(RV, RH)) :-
    RH is DH + SH,
    RV is DV + SV.

% SubPt: dst -= src
qd_sub_pt(point(SV, SH), point(DV, DH), point(RV, RH)) :-
    RH is DH - SH,
    RV is DV - SV.

%% QuickDraw Rect operations in pure Prolog

% SetRect
qd_set_rect(Left, Top, Right, Bottom, rect(Top, Left, Bottom, Right)).

% EqualRect
qd_equal_rect(rect(T,L,B,R), rect(T,L,B,R), 1) :- !.
qd_equal_rect(_, _, 0).

% EmptyRect
qd_empty_rect(rect(Top, Left, Bottom, Right), 1) :-
    (Bottom =< Top ; Right =< Left), !.
qd_empty_rect(_, 0).

% OffsetRect
qd_offset_rect(rect(T,L,B,R), DH, DV, rect(T2,L2,B2,R2)) :-
    L2 is L + DH, R2 is R + DH,
    T2 is T + DV, B2 is B + DV.

% InsetRect
qd_inset_rect(rect(T,L,B,R), DH, DV, rect(T2,L2,B2,R2)) :-
    L2 is L + DH, R2 is R - DH,
    T2 is T + DV, B2 is B - DV.

% SectRect (intersection)
qd_sect_rect(rect(T1,L1,B1,R1), rect(T2,L2,B2,R2), rect(T,L,B,R), NonEmpty) :-
    T is max(T1, T2), L is max(L1, L2),
    B is min(B1, B2), R is min(R1, R2),
    (B > T, R > L -> NonEmpty = 1 ; NonEmpty = 0).

% UnionRect
qd_union_rect(rect(T1,L1,B1,R1), rect(T2,L2,B2,R2), rect(T,L,B,R)) :-
    T is min(T1, T2), L is min(L1, L2),
    B is max(B1, B2), R is max(R1, R2).

% PtInRect
qd_pt_in_rect(point(V, H), rect(Top, Left, Bottom, Right), 1) :-
    V >= Top, V < Bottom, H >= Left, H < Right, !.
qd_pt_in_rect(_, _, 0).

%% Trace output — mirrors the CALL format used by trace_sensorlib.pl

trace_pt(Label, point(V, H)) :-
    format("  ~w: point(v=~w, h=~w)~n", [Label, V, H]).

trace_rect(Label, rect(T, L, B, R)) :-
    format("  ~w: rect(top=~w, left=~w, bottom=~w, right=~w)~n", [Label, T, L, B, R]).

main :-
    format("=== QuickDraw Type Operations (Pure Prolog, no ADDRESS/MemCopy) ===~n~n"),

    % --- SetPt ---
    format("--- SetPt ---~n"),
    qd_set_pt(10, 20, Pt1),
    trace_pt('SetPt(10,20)', Pt1),

    % --- EqualPt ---
    format("--- EqualPt ---~n"),
    qd_set_pt(10, 20, PtA),
    qd_set_pt(10, 20, PtB),
    qd_equal_pt(PtA, PtB, Eq1),
    format("CALL QDEqualPt(same) -> ~w~n", [Eq1]),
    qd_set_pt(10, 21, PtC),
    qd_equal_pt(PtA, PtC, Eq2),
    format("CALL QDEqualPt(diff) -> ~w~n", [Eq2]),

    % --- AddPt ---
    format("--- AddPt ---~n"),
    qd_set_pt(3, 4, Src1),
    qd_set_pt(10, 20, Dst1),
    qd_add_pt(Src1, Dst1, Dst1b),
    trace_pt('AddPt result', Dst1b),

    % --- SubPt ---
    format("--- SubPt ---~n"),
    qd_set_pt(3, 4, Src2),
    qd_set_pt(10, 20, Dst2),
    qd_sub_pt(Src2, Dst2, Dst2b),
    trace_pt('SubPt result', Dst2b),

    % --- SetRect ---
    format("--- SetRect ---~n"),
    qd_set_rect(10, 20, 100, 200, R1),
    trace_rect('SetRect', R1),

    % --- EqualRect ---
    format("--- EqualRect ---~n"),
    qd_set_rect(10, 20, 100, 200, Ra),
    qd_set_rect(10, 20, 100, 200, Rb),
    qd_equal_rect(Ra, Rb, REq1),
    format("CALL QDEqualRect(same) -> ~w~n", [REq1]),
    qd_set_rect(10, 20, 101, 200, Rc),
    qd_equal_rect(Ra, Rc, REq2),
    format("CALL QDEqualRect(diff) -> ~w~n", [REq2]),

    % --- EmptyRect ---
    format("--- EmptyRect ---~n"),
    qd_set_rect(10, 20, 100, 200, RNorm),
    qd_empty_rect(RNorm, Em1),
    format("CALL QDEmptyRect(normal) -> ~w~n", [Em1]),
    qd_set_rect(10, 20, 100, 20, RFlat),
    qd_empty_rect(RFlat, Em2),
    format("CALL QDEmptyRect(bottom==top) -> ~w~n", [Em2]),

    % --- OffsetRect ---
    format("--- OffsetRect ---~n"),
    qd_set_rect(10, 20, 100, 200, RO1),
    qd_offset_rect(RO1, 5, 10, RO2),
    trace_rect('OffsetRect(5,10)', RO2),

    % --- SectRect (intersection) ---
    format("--- SectRect ---~n"),
    qd_set_rect(10, 20, 100, 200, RS1),
    qd_set_rect(50, 80, 150, 250, RS2),
    qd_sect_rect(RS1, RS2, RS3, Sect1),
    format("CALL QDSectRect(overlapping) -> ~w~n", [Sect1]),
    trace_rect('SectRect result', RS3),

    qd_set_rect(10, 20, 50, 60, RS4),
    qd_set_rect(60, 70, 100, 120, RS5),
    qd_sect_rect(RS4, RS5, _, Sect2),
    format("CALL QDSectRect(non-overlapping) -> ~w~n", [Sect2]),

    % --- UnionRect ---
    format("--- UnionRect ---~n"),
    qd_set_rect(10, 20, 100, 200, RU1),
    qd_set_rect(50, 80, 150, 250, RU2),
    qd_union_rect(RU1, RU2, RU3),
    trace_rect('UnionRect result', RU3),

    % --- PtInRect ---
    format("--- PtInRect ---~n"),
    qd_set_pt(50, 100, PtIn1),
    qd_set_rect(10, 20, 100, 200, RIn1),
    qd_pt_in_rect(PtIn1, RIn1, In1),
    format("CALL QDPtInRect(inside) -> ~w~n", [In1]),

    qd_set_pt(100, 200, PtIn2),
    qd_pt_in_rect(PtIn2, RIn1, In2),
    format("CALL QDPtInRect(bottom-right excl) -> ~w~n", [In2]),

    qd_set_pt(10, 20, PtIn3),
    qd_pt_in_rect(PtIn3, RIn1, In3),
    format("CALL QDPtInRect(top-left incl) -> ~w~n", [In3]),

    format("~n=== Done ===~n").
