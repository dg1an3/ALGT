!============================================================
! procedure_params.clw - Modern Procedure Declaration Syntax
! Demonstrates: Inline parameters, optional parameters with
!               angle bracket syntax, and default values
!============================================================

  PROGRAM

  MAP
    ! Old-style declarations (still supported)
    OldStyleProc       PROCEDURE

    ! New-style declarations with inline parameters
    Greet              PROCEDURE(STRING name)
    Add                PROCEDURE(LONG a, LONG b)
    FormatName         PROCEDURE(STRING first, STRING last, <STRING title>)
    Calculate          PROCEDURE(LONG value, <LONG multiplier>, <LONG offset>)
    CreateMessage      PROCEDURE(STRING msg, <LONG repeat>)
  END

result      STRING(200)
total       LONG

  CODE
    ! Call old-style procedure
    OldStyleProc()

    ! Call with all required parameters
    Greet('World')
    Add(10, 20)

    ! Call with required + optional parameters
    FormatName('John', 'Doe')
    FormatName('Jane', 'Smith', 'Dr.')

    ! Call with various optional parameter combinations
    Calculate(100)                  ! Use defaults for multiplier and offset
    Calculate(100, 2)               ! Provide multiplier, default offset
    Calculate(100, 2, 50)           ! Provide all parameters

    ! Optional parameter with default value
    CreateMessage('Hello')          ! Uses default repeat of 1
    CreateMessage('Hi', 3)          ! Repeats 3 times

    MESSAGE('All procedure tests completed!')
    RETURN

!------------------------------------------------------------
! Old-style procedure (no inline parameters)
!------------------------------------------------------------
OldStyleProc  PROCEDURE
localVar    STRING(50)

  CODE
    localVar = 'Old style procedure called'
    MESSAGE(localVar)
    RETURN

!------------------------------------------------------------
! Simple procedure with required parameters
!------------------------------------------------------------
Greet  PROCEDURE(STRING name)

  CODE
    MESSAGE('Hello, ' & name & '!')
    RETURN

!------------------------------------------------------------
! Procedure returning a value via MESSAGE (simulated)
!------------------------------------------------------------
Add  PROCEDURE(LONG a, LONG b)
sum   LONG

  CODE
    sum = a + b
    MESSAGE('Sum: ' & sum)
    RETURN

!------------------------------------------------------------
! Procedure with optional parameter (no default)
!------------------------------------------------------------
FormatName  PROCEDURE(STRING first, STRING last, <STRING title>)
fullName    STRING(100)

  CODE
    IF title <> ''
      fullName = title & ' ' & first & ' ' & last
    ELSE
      fullName = first & ' ' & last
    END
    MESSAGE('Name: ' & fullName)
    RETURN

!------------------------------------------------------------
! Procedure with multiple optional parameters with defaults
!------------------------------------------------------------
Calculate  PROCEDURE(LONG value, <LONG multiplier>, <LONG offset>)
result    LONG
mult      LONG
off       LONG

  CODE
    ! Use provided values or defaults
    IF multiplier = 0
      mult = 1
    ELSE
      mult = multiplier
    END
    off = offset

    result = (value * mult) + off
    MESSAGE('Calculate result: ' & result)
    RETURN

!------------------------------------------------------------
! Procedure with optional parameter that has explicit default
! Note: Default values are evaluated when the procedure is called
!------------------------------------------------------------
CreateMessage  PROCEDURE(STRING msg, <LONG repeat>)
i         LONG
output    STRING(200)
count     LONG

  CODE
    ! If repeat not provided, default to 1
    IF repeat = 0
      count = 1
    ELSE
      count = repeat
    END

    output = ''
    LOOP i = 1 TO count
      IF i > 1
        output = output & ' '
      END
      output = output & msg
    END
    MESSAGE(output)
    RETURN
