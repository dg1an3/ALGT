!============================================================
! case_variations.clw - Case Insensitivity Test
! Demonstrates: Mixed case keywords, identifiers, constructs,
!               and period (.) as END terminator
!============================================================

  Program

  Map
    MixedCaseProc  Procedure
    ALLCAPS        PROCEDURE
    alllower       procedure
  End

! Mixed case data types
CustomerName    String(50)
customerId      long
TOTAL_AMOUNT    Decimal(10,2)
isActive        Byte(false)
startDate       date
endTime         TIME

! Mixed case GROUP
CustomerRecord  Group
  firstName       string(30)
  LastName        STRING(30)
  EMAIL           String(50)
                End

! GROUP with period terminator
AddressRecord   GROUP
  Street          STRING(50)
  City            STRING(30)
                .

! Mixed case QUEUE
ItemQueue       queue
  ItemName        String(30)
  Quantity        LONG
  Price           decimal(8,2)
                END

! QUEUE with period terminator
OrderQueue      QUEUE
  OrderID         LONG
  Amount          DECIMAL(10,2)
                .

  Code
    MixedCaseProc()

MixedCaseProc Procedure
counter     Long
result      String(100)

  code
    ! Mixed case control structures
    counter = 0

    Loop counter = 1 to 10
      If counter > 5
        result = 'Greater'
      Elsif counter = 5
        result = 'Equal'
      Else
        result = 'Lesser'
      end
    End

    ! Mixed case LOOP variations
    LOOP WHILE counter < 20
      counter += 1
    END

    loop until counter >= 25
      counter = counter + 1
    end

    ! LOOP with period terminator
    LOOP counter = 1 TO 5
      result = 'Looping'
    .

    ! IF with period terminator
    IF counter > 0
      result = 'Positive'
    .

    ! Mixed case CASE statement
    Case counter
    Of 1
      result = 'One'
    OF 2
      result = 'Two'
    of 3
      result = 'Three'
    Else
      result = 'Other'
    End

    ! Mixed case function calls
    result = Clip(CustomerName)
    result = CLIP(result)
    result = clip(result)

    ! Mixed case DO/ROUTINE
    Do InitData
    DO ProcessData
    do CleanUp

    ! Mixed case boolean
    isActive = True
    isActive = FALSE
    isActive = true

    ! Mixed case operators
    If counter > 5 And counter < 10
      result = 'Range A'
    End

    If counter < 3 OR counter > 15
      result = 'Range B'
    end

    If Not isActive
      result = 'Inactive'
    END

    Return

InitData    Routine
    counter = 0
    Exit

ProcessData ROUTINE
    counter = counter + 1
    EXIT

CleanUp     routine
    counter = 0
    exit

ALLCAPS PROCEDURE
  CODE
    RETURN

alllower procedure
  code
    return
