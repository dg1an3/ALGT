!============================================================
! sql_example.clw - Embedded SQL in Clarion
! Demonstrates: SQL SELECT, INSERT, UPDATE, DELETE
!============================================================

  PROGRAM

  MAP
    SQLDemo  PROCEDURE
  END

! SQL File Declaration for ODBC
OrdersFile      FILE,DRIVER('ODBC'),OWNER('DSN=SalesDB'),PRE(Ord)
Record            RECORD
OrderID             LONG
CustomerID          LONG
OrderDate           DATE
ShipDate            DATE
TotalAmount         DECIMAL(12,2)
Status              STRING(20)
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
    ! SELECT with WHERE clause
    !------------------------------------------------------------
    sqlStmt = 'SELECT OrderID, CustomerID, OrderDate, TotalAmount ' & |
              'FROM Orders ' & |
              'WHERE CustomerID = ' & custID & ' ' & |
              'AND OrderDate BETWEEN ''' & FORMAT(startDate,@D10) & ''' ' & |
              'AND ''' & FORMAT(endDate,@D10) & ''' ' & |
              'ORDER BY OrderDate DESC'

    Ord:Record = sqlStmt
    LOOP
      NEXT(OrdersFile)
      IF ERRORCODE() THEN BREAK END
      ! Process each row...
    END

    !------------------------------------------------------------
    ! SELECT with JOIN using embedded SQL
    !------------------------------------------------------------
    FREE(ResultQueue)

    sqlStmt = 'SELECT o.OrderID, c.CustomerName, o.OrderDate, o.TotalAmount ' & |
              'FROM Orders o ' & |
              'INNER JOIN Customers c ON o.CustomerID = c.CustomerID ' & |
              'WHERE o.Status = ''Completed'' ' & |
              'ORDER BY o.TotalAmount DESC'

    Ord:Record = sqlStmt
    SET(OrdersFile)
    LOOP
      NEXT(OrdersFile)
      IF ERRORCODE() THEN BREAK END
      ResultQueue.OrderID = Ord:OrderID
      ! ResultQueue.CustomerName would come from joined data
      ResultQueue.OrderDate = Ord:OrderDate
      ResultQueue.TotalAmount = Ord:TotalAmount
      ADD(ResultQueue)
    END

    !------------------------------------------------------------
    ! INSERT Statement
    !------------------------------------------------------------
    CLEAR(Ord:Record)
    Ord:OrderID = 0            ! Auto-increment
    Ord:CustomerID = custID
    Ord:OrderDate = TODAY()
    Ord:TotalAmount = 599.99
    Ord:Status = 'Pending'
    ADD(OrdersFile)

    IF ERRORCODE()
      MESSAGE('Insert failed: ' & ERROR(),'Error')
    END

    !------------------------------------------------------------
    ! UPDATE Statement
    !------------------------------------------------------------
    sqlStmt = 'UPDATE Orders ' & |
              'SET Status = ''Shipped'', ShipDate = ''' & FORMAT(TODAY(),@D10) & ''' ' & |
              'WHERE OrderID = 1001'

    Ord:Record = sqlStmt
    PUT(OrdersFile)

    !------------------------------------------------------------
    ! Parameterized UPDATE using GET/PUT
    !------------------------------------------------------------
    CLEAR(Ord:Record)
    Ord:OrderID = 1001
    GET(OrdersFile, Ord:OrderID)
    IF NOT ERRORCODE()
      Ord:Status = 'Delivered'
      PUT(OrdersFile)
    END

    !------------------------------------------------------------
    ! DELETE Statement
    !------------------------------------------------------------
    sqlStmt = 'DELETE FROM Orders ' & |
              'WHERE Status = ''Cancelled'' ' & |
              'AND OrderDate < ''' & FORMAT(startDate,@D10) & ''''

    Ord:Record = sqlStmt
    DELETE(OrdersFile)

    !------------------------------------------------------------
    ! Aggregate Query
    !------------------------------------------------------------
    sqlStmt = 'SELECT COUNT(*) AS RecCount, SUM(TotalAmount) AS TotalSales ' & |
              'FROM Orders ' & |
              'WHERE YEAR(OrderDate) = 2024'

    Ord:Record = sqlStmt
    NEXT(OrdersFile)
    IF NOT ERRORCODE()
      recCount = Ord:OrderID      ! First field = COUNT
      orderTotal = Ord:TotalAmount ! Mapped field = SUM
    END

    !------------------------------------------------------------
    ! Transaction Example
    !------------------------------------------------------------
    LOGOUT(1, OrdersFile)         ! Begin transaction

    ! Multiple operations within transaction
    CLEAR(Ord:Record)
    Ord:CustomerID = 200
    Ord:OrderDate = TODAY()
    Ord:TotalAmount = 150.00
    Ord:Status = 'Pending'
    ADD(OrdersFile)

    IF ERRORCODE()
      ROLLBACK(OrdersFile)        ! Rollback on error
    ELSE
      COMMIT(OrdersFile)          ! Commit on success
    END

    msg = 'SQL Demo Complete<13,10>' & |
          'Records in result queue: ' & RECORDS(ResultQueue)
    MESSAGE(msg,'SQL Demo')

    FREE(ResultQueue)
    CLOSE(OrdersFile)
    RETURN
