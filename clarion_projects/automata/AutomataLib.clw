  MEMBER()

NumStates EQUATE(15)
Size      EQUATE(640)

Cells    LONG,DIM(641)
NewCells LONG,DIM(641)
Rules    LONG,DIM(49)

  MAP
    MODULE('kernel32')
      MemCopy(LONG dest, LONG src, LONG len),RAW,PASCAL,NAME('RtlMoveMemory')
    END
    CAInit(),LONG,C,NAME('CAInit'),EXPORT
    CASetRule(LONG index, LONG value),LONG,C,NAME('CASetRule'),EXPORT
    CAGetRule(LONG index),LONG,C,NAME('CAGetRule'),EXPORT
    CASetCell(LONG index, LONG value),LONG,C,NAME('CASetCell'),EXPORT
    CAGetCell(LONG index),LONG,C,NAME('CAGetCell'),EXPORT
    CAStep(),LONG,C,NAME('CAStep'),EXPORT
    CASpatialEntropy(),LONG,C,NAME('CASpatialEntropy'),EXPORT
    CATemporalEntropy(LONG prevPtr),LONG,C,NAME('CATemporalEntropy'),EXPORT
    CASetRuleFromHex(LONG strPtr, LONG strLen),LONG,C,NAME('CASetRuleFromHex'),EXPORT
    CAGetCellCount(LONG state),LONG,C,NAME('CAGetCellCount'),EXPORT
    HexCharToVal(LONG ch),LONG,PRIVATE
  END

CAInit PROCEDURE()
i LONG
  CODE
  LOOP i = 1 TO 641
    Cells[i] = 0
    NewCells[i] = 0
  END
  LOOP i = 1 TO 49
    Rules[i] = 0
  END
  RETURN 0

CASetRule PROCEDURE(LONG index, LONG value)
  CODE
  IF index < 0 OR index > 48
    RETURN -1
  END
  Rules[index + 1] = value
  RETURN 0

CAGetRule PROCEDURE(LONG index)
  CODE
  IF index < 0 OR index > 48
    RETURN -1
  END
  RETURN Rules[index + 1]

CASetCell PROCEDURE(LONG index, LONG value)
  CODE
  IF index < 0 OR index > Size
    RETURN -1
  END
  Cells[index + 1] = value
  RETURN 0

CAGetCell PROCEDURE(LONG index)
  CODE
  IF index < 0 OR index > Size
    RETURN -1
  END
  RETURN Cells[index + 1]

CAStep PROCEDURE()
i     LONG
left  LONG
right LONG
sum   LONG
  CODE
  LOOP i = 0 TO Size
    IF i = 0
      left = Size
    ELSE
      left = i - 1
    END
    IF i = Size
      right = 0
    ELSE
      right = i + 1
    END
    sum = Cells[left + 1] + Cells[i + 1] + Cells[right + 1]
    IF sum >= 0 AND sum <= 48
      NewCells[i + 1] = Rules[sum + 1]
    ELSE
      NewCells[i + 1] = 0
    END
  END
  LOOP i = 1 TO 641
    Cells[i] = NewCells[i]
  END
  RETURN 0

CASpatialEntropy PROCEDURE()
count LONG(0)
i     LONG
  CODE
  LOOP i = 1 TO Size
    IF Cells[i + 1] = Cells[i]
      count += 1
    END
  END
  RETURN count

CATemporalEntropy PROCEDURE(LONG prevPtr)
count    LONG(0)
i        LONG
PrevCells LONG,DIM(641)
  CODE
  MemCopy(ADDRESS(PrevCells), prevPtr, 641 * 4)
  LOOP i = 1 TO 641
    IF Cells[i] = PrevCells[i]
      count += 1
    END
  END
  RETURN count

CASetRuleFromHex PROCEDURE(LONG strPtr, LONG strLen)
i      LONG
ch     LONG
val    LONG
HexBuf BYTE,DIM(128)
  CODE
  IF strLen > 128 OR strLen > 49
    RETURN -1
  END
  MemCopy(ADDRESS(HexBuf), strPtr, strLen)
  LOOP i = 1 TO strLen
    ch = HexBuf[i]
    val = HexCharToVal(ch)
    IF val < 0
      RETURN -2
    END
    Rules[i] = val
  END
  RETURN 0

HexCharToVal PROCEDURE(LONG ch)
  CODE
  IF ch >= 48 AND ch <= 57
    RETURN ch - 48
  END
  IF ch >= 65 AND ch <= 70
    RETURN ch - 65 + 10
  END
  IF ch >= 97 AND ch <= 102
    RETURN ch - 97 + 10
  END
  RETURN -1

CAGetCellCount PROCEDURE(LONG state)
count LONG(0)
i     LONG
  CODE
  LOOP i = 1 TO 641
    IF Cells[i] = state
      count += 1
    END
  END
  RETURN count
