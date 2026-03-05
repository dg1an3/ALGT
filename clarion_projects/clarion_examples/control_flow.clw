!============================================================
! control_flow.clw - Control Flow Structures
! Demonstrates: IF/ELSIF/ELSE, LOOP, CASE, DO/ROUTINE
!============================================================

  PROGRAM

  MAP
    ControlFlowDemo  PROCEDURE
  END

  CODE
    ControlFlowDemo()

ControlFlowDemo PROCEDURE
Score       LONG
Grade       STRING(1)
Counter     LONG
Sum         LONG
DayOfWeek   LONG
DayName     STRING(10)
Result      STRING(200)

  CODE
    ! IF/ELSIF/ELSE Example
    Score = 85
    IF Score >= 90
      Grade = 'A'
    ELSIF Score >= 80
      Grade = 'B'
    ELSIF Score >= 70
      Grade = 'C'
    ELSIF Score >= 60
      Grade = 'D'
    ELSE
      Grade = 'F'
    END

    ! LOOP with counter
    Sum = 0
    LOOP Counter = 1 TO 10
      Sum = Sum + Counter
    END

    ! LOOP WHILE
    Counter = 0
    LOOP WHILE Counter < 5
      Counter = Counter + 1
    END

    ! LOOP UNTIL
    Counter = 0
    LOOP UNTIL Counter >= 5
      Counter = Counter + 1
    END

    ! LOOP with BREAK
    LOOP Counter = 1 TO 100
      IF Counter > 10
        BREAK
      END
    END

    ! LOOP with CYCLE (continue)
    Sum = 0
    LOOP Counter = 1 TO 10
      IF Counter % 2 = 0   ! Skip even numbers
        CYCLE
      END
      Sum = Sum + Counter  ! Sum of odd numbers only
    END

    ! CASE Statement
    DayOfWeek = 3
    CASE DayOfWeek
    OF 1
      DayName = 'Sunday'
    OF 2
      DayName = 'Monday'
    OF 3
      DayName = 'Tuesday'
    OF 4
      DayName = 'Wednesday'
    OF 5
      DayName = 'Thursday'
    OF 6
      DayName = 'Friday'
    OF 7
      DayName = 'Saturday'
    ELSE
      DayName = 'Invalid'
    END

    ! DO ROUTINE calls
    DO InitializeData
    DO ProcessData
    DO DisplayResults

    Result = 'Grade: ' & Grade & |
             '<13,10>Day: ' & DayName
    MESSAGE(Result,'Control Flow Demo')
    RETURN

InitializeData ROUTINE
    ! Initialization logic here
    EXIT

ProcessData ROUTINE
    ! Processing logic here
    EXIT

DisplayResults ROUTINE
    ! Display logic here
    EXIT
