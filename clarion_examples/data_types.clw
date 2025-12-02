!============================================================
! data_types.clw - Clarion Data Types and Variables
! Demonstrates: STRING, LONG, SHORT, DECIMAL, DATE, TIME
!============================================================

  PROGRAM

  MAP
    ShowDataTypes  PROCEDURE
  END

! Global Data Declarations
CustomerName    STRING(50)
CustomerID      LONG
Quantity        SHORT
UnitPrice       DECIMAL(10,2)
TotalPrice      DECIMAL(12,2)
OrderDate       DATE
OrderTime       TIME
IsActive        BYTE
Notes           STRING(255)

! Group Structure
CustomerRecord  GROUP
Name              STRING(50)
Address           STRING(100)
City              STRING(30)
State             STRING(2)
ZipCode           STRING(10)
Phone             STRING(15)
Balance           DECIMAL(12,2)
                END

! Array Declaration
MonthlyTotals   DECIMAL(12,2),DIM(12)

  CODE
    ShowDataTypes()

ShowDataTypes PROCEDURE
i   LONG
msg STRING(500)

  CODE
    ! Initialize variables
    CustomerName = 'John Smith'
    CustomerID = 12345
    Quantity = 10
    UnitPrice = 29.99
    TotalPrice = Quantity * UnitPrice
    OrderDate = TODAY()
    OrderTime = CLOCK()
    IsActive = TRUE

    ! Initialize group
    CustomerRecord.Name = 'Jane Doe'
    CustomerRecord.Address = '123 Main Street'
    CustomerRecord.City = 'Springfield'
    CustomerRecord.State = 'IL'
    CustomerRecord.ZipCode = '62701'
    CustomerRecord.Phone = '555-123-4567'
    CustomerRecord.Balance = 1500.75

    ! Initialize array
    LOOP i = 1 TO 12
      MonthlyTotals[i] = i * 1000.00
    END

    msg = 'Customer: ' & CustomerName & |
          '<13,10>ID: ' & CustomerID & |
          '<13,10>Total: $' & TotalPrice & |
          '<13,10>Date: ' & FORMAT(OrderDate,@D2)

    MESSAGE(msg,'Data Types Demo')
    RETURN
