  MEMBER()
! ==========================================================================
! AutomataLib.clw — 1D Cellular Automaton Library
!
! Translated from AUTOMATA.MOD (Modula-2), Derek Graham Lane, 1991.
! Clarion is case-insensitive; this file deliberately uses variant casing
! to demonstrate case-invariance (mixed UPPER, lower, PascalCase).
!
! Original Modula-2 (AUTOMATA.MOD, D.G.Lane 1991):
!   MODULE Automata;
!   FROM InOut IMPORT Write, WriteLn, WriteCard;
!   CONST NumStates = 15;
!         Size = 640;
!   TYPE Sum = [0..3*NumStates];
!        States = [0..NumStates];
!        Cell = States;
!        Rule = ARRAY Sum OF States;
!        Automaton = RECORD
!          Cells: ARRAY [0..Size] OF Cell;
!          Rules: Rule;
!        END;
! ==========================================================================

! Original Modula-2: CONST NumStates = 15; Size = 640;
NumStates equate(15)
Size      EQUATE(640)

! Original Modula-2:
!   TYPE Cell = States;               (* cell value 0..NumStates *)
!        Rule = ARRAY Sum OF States;  (* sum index 0..3*NumStates = 0..45 *)
!        Automaton = RECORD
!          Cells: ARRAY [0..Size] OF Cell;
!          Rules: Rule;
!        END;
! Note: Clarion arrays are 1-based, so Dim(641) covers indices 0..640
!       and Dim(49) covers sums 0..48 (3*NumStates + safety margin).
Cells    Long,Dim(641)
NewCells Long,Dim(641)
Rules    Long,Dim(49)

  MAP
    MODULE('kernel32')
      MemCopy(LONG dest, LONG src, LONG len),RAW,PASCAL,NAME('RtlMoveMemory')
    END
    CAInit(),Long,C,NAME('CAInit'),EXPORT
    CASetRule(Long index, Long value),Long,C,NAME('CASetRule'),EXPORT
    CAGetRule(Long index),Long,C,NAME('CAGetRule'),EXPORT
    CASetCell(Long index, Long value),Long,C,NAME('CASetCell'),EXPORT
    CAGetCell(Long index),Long,C,NAME('CAGetCell'),EXPORT
    CAStep(),Long,C,NAME('CAStep'),EXPORT
    CASpatialEntropy(),Long,C,NAME('CASpatialEntropy'),EXPORT
    CATemporalEntropy(Long prevPtr),Long,C,NAME('CATemporalEntropy'),EXPORT
    CASetRuleFromHex(Long strPtr, Long strLen),Long,C,NAME('CASetRuleFromHex'),EXPORT
    CAGetCellCount(Long state),Long,C,NAME('CAGetCellCount'),EXPORT
    HexCharToVal(Long ch),Long,PRIVATE
  END

! Original Modula-2: PROCEDURE InitAutomaton(VAR A: Automaton);
!   FOR I := 0 TO Size DO A.Cells[I] := 0 END;
!   FOR I := 0 TO 3*NumStates DO A.Rules[I] := 0 END;
CAInit PROCEDURE()
i Long
  CODE
  loop i = 1 TO 641
    Cells[i] = 0
    NewCells[i] = 0
  end
  loop i = 1 TO 49
    Rules[i] = 0
  end
  RETURN 0

! Original Modula-2: A.Rules[index] := value;
CASetRule PROCEDURE(Long index, Long value)
  CODE
  if index < 0 OR index > 48 then
    RETURN -1
  end
  Rules[index + 1] = value
  RETURN 0

! Original Modula-2: RETURN A.Rules[index];
CAGetRule PROCEDURE(Long index)
  CODE
  if index < 0 OR index > 48 then
    RETURN -1
  end
  RETURN Rules[index + 1]

! Original Modula-2: A.Cells[index] := value;
CASetCell PROCEDURE(Long index, Long value)
  CODE
  if index < 0 OR index > Size then
    RETURN -1
  end
  Cells[index + 1] = value
  RETURN 0

! Original Modula-2: RETURN A.Cells[index];
CAGetCell PROCEDURE(Long index)
  CODE
  if index < 0 OR index > Size then
    RETURN -1
  end
  RETURN Cells[index + 1]

! Original Modula-2: PROCEDURE HaveaKid(Bob: Automaton; VAR BobJr: Automaton);
!   (* Produce next generation by applying rules to neighbor sums *)
!   FOR I := 0 TO Size DO
!     IF I = 0 THEN Left := Bob.Cells[Size]
!     ELSE Left := Bob.Cells[I-1] END;
!     IF I = Size THEN Right := Bob.Cells[0]
!     ELSE Right := Bob.Cells[I+1] END;
!     BobJr.Cells[I] := Bob.Rules[Left + Bob.Cells[I] + Right];
!   END;
CAStep PROCEDURE()
i     Long
left  Long
right Long
sum   Long
  CODE
  loop i = 0 TO Size
    if i = 0
      left = Size
    ELSE
      left = i - 1
    end
    if i = Size
      right = 0
    ELSE
      right = i + 1
    end
    sum = Cells[left + 1] + Cells[i + 1] + Cells[right + 1]
    if sum >= 0 AND sum <= 48
      NewCells[i + 1] = Rules[sum + 1]
    ELSE
      NewCells[i + 1] = 0
    end
  end
  loop i = 1 TO 641
    Cells[i] = NewCells[i]
  end
  RETURN 0

! Original Modula-2: PROCEDURE Spatial(A: Automaton): CARDINAL;
!   (* Count adjacent cell pairs with equal state *)
!   cnt := 0;
!   FOR I := 1 TO Size DO
!     IF A.Cells[I] = A.Cells[I-1] THEN INC(cnt) END;
!   END;
!   RETURN cnt;
CASpatialEntropy PROCEDURE()
count Long(0)
i     Long
  CODE
  loop i = 1 TO Size
    if Cells[i + 1] = Cells[i] then
      count += 1
    end
  end
  RETURN count

! Original Modula-2: PROCEDURE Temporal(A, Prev: Automaton): CARDINAL;
!   (* Count cells unchanged from previous generation *)
!   cnt := 0;
!   FOR I := 0 TO Size DO
!     IF A.Cells[I] = Prev.Cells[I] THEN INC(cnt) END;
!   END;
!   RETURN cnt;
CATemporalEntropy PROCEDURE(Long prevPtr)
count    Long(0)
i        Long
PrevCells Long,Dim(641)
  CODE
  MemCopy(ADDRESS(PrevCells), prevPtr, 641 * 4)
  loop i = 1 TO 641
    if Cells[i] = PrevCells[i] then
      count += 1
    end
  end
  RETURN count

! Original Modula-2: (no direct equivalent — hex rule loading is a Clarion addition)
! Parses a hex character string into rule values.
CASetRuleFromHex PROCEDURE(Long strPtr, Long strLen)
i      Long
ch     Long
val    Long
HexBuf BYTE,Dim(128)
  CODE
  if strLen > 128 OR strLen > 49 then
    RETURN -1
  end
  MemCopy(ADDRESS(HexBuf), strPtr, strLen)
  loop i = 1 TO strLen
    ch = HexBuf[i]
    val = HexCharToVal(ch)
    if val < 0 then
      RETURN -2
    end
    Rules[i] = val
  end
  RETURN 0

HexCharToVal PROCEDURE(Long ch)
  CODE
  if ch >= 48 AND ch <= 57 then
    RETURN ch - 48
  end
  if ch >= 65 AND ch <= 70 then
    RETURN ch - 65 + 10
  end
  if ch >= 97 AND ch <= 102 then
    RETURN ch - 97 + 10
  end
  RETURN -1

! Original Modula-2: (no direct equivalent — cell counting is a Clarion addition)
CAGetCellCount PROCEDURE(Long state)
count Long(0)
i     Long
  CODE
  loop i = 1 TO 641
    if Cells[i] = state then
      count += 1
    end
  end
  RETURN count
