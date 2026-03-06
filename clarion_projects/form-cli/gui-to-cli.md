# Converting a Clarion GUI Form to a Headless CLI

Three mechanical steps convert a WINDOW/ACCEPT form into a headless CLI
that reads events from a `.evt` file.

## Step 1: Replace the WINDOW declaration with local variables

The WINDOW structure declares controls bound to variables via `USE()`.
Remove the WINDOW and keep only the variables — they're already declared
as globals or locals (the `USE()` binding is just for display).

If the WINDOW declares controls that imply state not already captured by
a variable (e.g. a LIST with `CHOICE()`), add a local variable to hold
that state:

```clarion
! GUI: CHOICE(?TypeList) reads the dropdown selection at runtime
! CLI: replace with a plain variable
SensorType  LONG(1)
```

No WINDOW, no OPEN(Window), no CLOSE(Window), no DISPLAY.

## Step 2: Replace the ACCEPT loop with a file-reading loop

The ACCEPT loop waits for the next Windows message. Replace it with a
loop that reads the next line from the event file:

```clarion
! GUI                          ! CLI
ACCEPT                         LOOP
  ...                            NEXT(EventFile)
END                              IF ERRORCODE() THEN BREAK.
                                 ...
                               END
```

The event file is declared as an ASCII driver file:

```clarion
EventFile  FILE,DRIVER('ASCII'),NAME('events.evt'),PRE(EV)
Record       RECORD
Line           STRING(256)
             END
           END
```

Open it before the loop, close it after:

```clarion
  OPEN(EventFile)
  SET(EventFile)
  LOOP
    NEXT(EventFile)
    IF ERRORCODE() THEN BREAK.
    ! ... dispatch ...
  END
  CLOSE(EventFile)
```

## Step 3: Replace ACCEPTED() dispatch with a string-based dispatch

Inside the ACCEPT loop, `CASE ACCEPTED()` dispatches on equate numbers.
Replace it with a helper that parses each line and returns the event
source as a string:

```clarion
! GUI                              ! CLI
CASE ACCEPTED()                    ReadEvent(CLIP(EV:Line), EvtType, EvtSource, EvtValue)
OF ?CalcBtn                        CASE UPPER(EvtType)
  DoCalc()                         OF 'ACCEPTED'
OF ?ClearBtn                         CASE UPPER(EvtSource)
  DoClear()                          OF 'CALCBTN'
OF ?CloseBtn                           DoCalc()
  BREAK                              OF 'CLEARBTN'
END                                    DoClear()
                                     OF 'CLOSEBTN'
                                       BREAK
                                     END
                                   OF 'SET'
                                     ! assign EvtValue to the named field
                                   END
```

The helper `ReadEvent` splits the line on spaces:

```clarion
ReadEvent  PROCEDURE(pLine, *CSTRING pType, *CSTRING pSource, *CSTRING pValue)
  CODE
  ! parse "set Reading 500" or "accepted CalcBtn"
  Pos1 = INSTRING(' ', pLine, 1, 1)
  IF Pos1 = 0 THEN RETURN.
  pType = SUB(pLine, 1, Pos1 - 1)
  Pos2 = INSTRING(' ', pLine, 1, Pos1 + 1)
  IF Pos2 = 0
    pSource = SUB(pLine, Pos1 + 1, LEN(CLIP(pLine)) - Pos1)
    pValue = ''
  ELSE
    pSource = SUB(pLine, Pos1 + 1, Pos2 - Pos1 - 1)
    pValue = SUB(pLine, Pos2 + 1, LEN(CLIP(pLine)) - Pos2)
  END
```

## Event file format (.evt)

One event per line, space-separated:

```
set SensorID 42
set Reading 500
set Weight 80
accepted CalcBtn
accepted CloseBtn
```

- **`set <Field> <Value>`** — assigns a value (replaces typing into an ENTRY)
- **`accepted <Control>`** — simulates a button press (replaces ACCEPTED() event)
