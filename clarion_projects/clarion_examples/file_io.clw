!============================================================
! file_io.clw - File I/O Operations
! Demonstrates: FILE declaration, OPEN, CLOSE, READ, WRITE
!============================================================

  PROGRAM

  MAP
    FileIODemo  PROCEDURE
  END

! File Structure Declaration
CustomerFile    FILE,DRIVER('TOPSPEED'),PRE(Cust),CREATE
ByID              KEY(Cust:CustomerID),NOCASE,PRIMARY
ByName            KEY(Cust:LastName,Cust:FirstName),NOCASE,DUP
Record            RECORD
CustomerID          LONG
FirstName           STRING(30)
LastName            STRING(30)
Email               STRING(50)
Phone               STRING(15)
Balance             DECIMAL(12,2)
DateAdded           DATE
Active              BYTE
                  END
                END

  CODE
    FileIODemo()

FileIODemo PROCEDURE
i           LONG
RecCount    LONG
msg         STRING(500)

  CODE
    ! Create and open the file
    CREATE(CustomerFile)
    OPEN(CustomerFile)
    IF ERRORCODE()
      MESSAGE('Error opening file: ' & ERROR(),'Error')
      RETURN
    END

    ! Clear existing data
    EMPTY(CustomerFile)

    ! Add records using ADD
    CLEAR(Cust:Record)
    Cust:CustomerID = 1
    Cust:FirstName = 'John'
    Cust:LastName = 'Smith'
    Cust:Email = 'john.smith@email.com'
    Cust:Phone = '555-0101'
    Cust:Balance = 1500.00
    Cust:DateAdded = TODAY()
    Cust:Active = TRUE
    ADD(CustomerFile)

    CLEAR(Cust:Record)
    Cust:CustomerID = 2
    Cust:FirstName = 'Jane'
    Cust:LastName = 'Doe'
    Cust:Email = 'jane.doe@email.com'
    Cust:Phone = '555-0102'
    Cust:Balance = 2300.50
    Cust:DateAdded = TODAY()
    Cust:Active = TRUE
    ADD(CustomerFile)

    CLEAR(Cust:Record)
    Cust:CustomerID = 3
    Cust:FirstName = 'Bob'
    Cust:LastName = 'Johnson'
    Cust:Email = 'bob.j@email.com'
    Cust:Phone = '555-0103'
    Cust:Balance = 750.25
    Cust:DateAdded = TODAY()
    Cust:Active = FALSE
    ADD(CustomerFile)

    ! Read by primary key
    CLEAR(Cust:Record)
    Cust:CustomerID = 2
    GET(CustomerFile, Cust:ByID)
    IF NOT ERRORCODE()
      msg = 'Found by ID: ' & CLIP(Cust:FirstName) & ' ' & CLIP(Cust:LastName)
    ELSE
      msg = 'Record not found'
    END

    ! Update a record
    Cust:Balance = Cust:Balance + 100.00
    PUT(CustomerFile)

    ! Sequential read through all records
    RecCount = 0
    SET(CustomerFile)
    LOOP
      NEXT(CustomerFile)
      IF ERRORCODE() THEN BREAK END
      RecCount += 1
    END

    ! Read using secondary key (sorted by name)
    msg = msg & '<13,10><13,10>Customers by Name:<13,10>'
    SET(Cust:ByName)
    LOOP
      NEXT(CustomerFile)
      IF ERRORCODE() THEN BREAK END
      msg = msg & CLIP(Cust:LastName) & ', ' & CLIP(Cust:FirstName) & '<13,10>'
    END

    ! Delete a record
    CLEAR(Cust:Record)
    Cust:CustomerID = 3
    GET(CustomerFile, Cust:ByID)
    IF NOT ERRORCODE()
      DELETE(CustomerFile)
    END

    ! Get final count
    RecCount = RECORDS(CustomerFile)
    msg = msg & '<13,10>Total Records: ' & RecCount

    MESSAGE(msg,'File I/O Demo')

    ! Close the file
    CLOSE(CustomerFile)
    RETURN
