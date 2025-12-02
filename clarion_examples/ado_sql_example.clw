!============================================================
! ado_sql_example.clw - ADO Driver Example for Clarion
! Demonstrates: ADO file driver, BINDABLE, KEYs, and both
!               keyed access and embedded SQL.
!============================================================

  PROGRAM

  MAP
    SQLDemo  PROCEDURE
  END

! Connection string for the ADO driver
ConnectionString  STRING('Provider=SQLOLEDB;Server=localhost;Database=SalesDB;UID=sa;PWD=password')

! ADO File Declaration for SQL Server
OrdersFile      FILE,DRIVER('ADO'),NAME('Orders'),OWNER(ConnectionString),PRE(Ord),BINDABLE,THREAD
OrderIDKey        KEY(Ord:OrderID),NOCASE,PRIMARY
ByDateKey         KEY(Ord:OrderDate),NOCASE
Record            RECORD
OrderID             LONG,NAME('o_OrderID')
CustomerID          LONG,NAME('o_CustomerID')
OrderDate           DATE,NAME('o_OrderDate')
ShipDate            DATE,NAME('o_ShipDate')
TotalAmount         DECIMAL(12,2),NAME('o_TotalAmount')
Status              STRING(20),NAME('o_Status')
                  END
                END

! Queue for query results
ResultQueue     QUEUE
OrderID           LONG
CustomerName      STRING(50)
OrderDate         DATE
TotalAmount       DECIMAL(12,2)
                END

  CODE
    SQLDemo()

SQLDemo PROCEDURE
sqlStmt     STRING(1000)
custID      LONG
orderTotal  DECIMAL(12,2)
startDate   DATE
endDate     DATE
recCount    LONG
msg         STRING(500)

  CODE
    OPEN(OrdersFile)
    IF ERRORCODE()
      MESSAGE('Cannot connect to database: ' & ERROR(),'Error')
      RETURN
    END

    ! Initialize parameters
    custID = 100
    startDate = DATE(1,1,2024)
    endDate = TODAY()

    !------------------------------------------------------------
    ! Keyed access (replaces simple SELECT)
    !------------------------------------------------------------
    ! With BINDABLE, we can use standard Clarion access methods
    SET(OrdersFile, ByDateKey)
    LOOP
      NEXT(OrdersFile)
      IF ERRORCODE() THEN BREAK END
      IF Ord:OrderDate > endDate THEN BREAK END

      ! Process each row...
      IF Ord:CustomerID = custID
         ! Found a matching record
      END
    END

    !------------------------------------------------------------
    ! SELECT with JOIN using embedded SQL
    ! (Still useful for complex queries)
    !------------------------------------------------------------
    FREE(ResultQueue)

    sqlStmt = 'SELECT o.o_OrderID, c.CustomerName, o.o_OrderDate, o.o_TotalAmount ' & |
              'FROM Orders o ' & |
              'INNER JOIN Customers c ON o.o_CustomerID = c.c_CustomerID ' & |
              'WHERE o.o_Status = ''Completed'' ' & |
              'ORDER BY o.o_TotalAmount DESC'

    Ord:Record = sqlStmt  ! Use the FILE buffer to execute the query
    LOOP
      NEXT(OrdersFile)
      IF ERRORCODE() THEN BREAK END
      ResultQueue.OrderID = Ord:OrderID
      ! ResultQueue.CustomerName would need to be handled, perhaps with a separate QUEUE
      ResultQueue.OrderDate = Ord:OrderDate
      ResultQueue.TotalAmount = Ord:TotalAmount
      ADD(ResultQueue)
    END

    !------------------------------------------------------------
    ! INSERT Statement (using standard ADD)
    !------------------------------------------------------------
    CLEAR(Ord:Record)
    ! Ord:OrderID is auto-incrementing in the database
    Ord:CustomerID = custID
    Ord:OrderDate = TODAY()
    Ord:TotalAmount = 599.99
    Ord:Status = 'Pending'
    ADD(OrdersFile)

    IF ERRORCODE()
      MESSAGE('Insert failed: ' & ERROR(),'Error')
    END

    !------------------------------------------------------------
    ! UPDATE Statement (using GET/PUT)
    !------------------------------------------------------------
    CLEAR(Ord:Record)
    Ord:OrderID = 1001
    GET(OrdersFile, OrderIDKey)
    IF NOT ERRORCODE()
      Ord:Status = 'Delivered'
      PUT(OrdersFile)
    END

    !------------------------------------------------------------
    ! DELETE Statement (using standard DELETE)
    !------------------------------------------------------------
    CLEAR(Ord:Record)
    Ord:OrderID = 1002
    GET(OrdersFile, OrderIDKey)
    IF NOT ERRORCODE()
      DELETE(OrdersFile)
    END

    !------------------------------------------------------------
    ! Aggregate Query (still requires embedded SQL)
    !------------------------------------------------------------
    sqlStmt = 'SELECT COUNT(*) AS RecCount, SUM(o_TotalAmount) AS TotalSales ' & |
              'FROM Orders ' & |
              'WHERE YEAR(o_OrderDate) = 2024'

    Ord:Record = sqlStmt
    NEXT(OrdersFile)
    IF NOT ERRORCODE()
      recCount = Ord:OrderID      ! First field = COUNT
      orderTotal = Ord:TotalAmount ! Mapped field = SUM
    END

    msg = 'SQL Demo Complete<13,10>' & |
          'Records in result queue: ' & RECORDS(ResultQueue)
    MESSAGE(msg,'SQL Demo')

    FREE(ResultQueue)
    CLOSE(OrdersFile)
    RETURN
