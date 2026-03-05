!============================================================
! queue_example.clw - Queue (Dynamic Array) Operations
! Demonstrates: QUEUE declaration, ADD, GET, PUT, DELETE, SORT
!============================================================

  PROGRAM

  MAP
    QueueDemo  PROCEDURE
  END

! Queue Declaration
ProductQueue    QUEUE
ProductID         LONG
ProductName       STRING(50)
Category          STRING(20)
Price             DECIMAL(10,2)
Quantity          LONG
                END

  CODE
    QueueDemo()

QueueDemo PROCEDURE
i           LONG
TotalValue  DECIMAL(12,2)
msg         STRING(1000)

  CODE
    ! Clear any existing records
    FREE(ProductQueue)

    ! ADD records to the queue
    ProductQueue.ProductID = 1001
    ProductQueue.ProductName = 'Laptop Computer'
    ProductQueue.Category = 'Electronics'
    ProductQueue.Price = 999.99
    ProductQueue.Quantity = 10
    ADD(ProductQueue)

    ProductQueue.ProductID = 1002
    ProductQueue.ProductName = 'Office Chair'
    ProductQueue.Category = 'Furniture'
    ProductQueue.Price = 299.50
    ProductQueue.Quantity = 25
    ADD(ProductQueue)

    ProductQueue.ProductID = 1003
    ProductQueue.ProductName = 'Desk Lamp'
    ProductQueue.Category = 'Lighting'
    ProductQueue.Price = 45.00
    ProductQueue.Quantity = 50
    ADD(ProductQueue)

    ProductQueue.ProductID = 1004
    ProductQueue.ProductName = 'Keyboard'
    ProductQueue.Category = 'Electronics'
    ProductQueue.Price = 79.99
    ProductQueue.Quantity = 30
    ADD(ProductQueue)

    ProductQueue.ProductID = 1005
    ProductQueue.ProductName = 'Monitor Stand'
    ProductQueue.Category = 'Furniture'
    ProductQueue.Price = 89.95
    ProductQueue.Quantity = 15
    ADD(ProductQueue)

    ! SORT by ProductName
    SORT(ProductQueue, ProductQueue.ProductName)

    ! Calculate total inventory value using GET
    TotalValue = 0
    LOOP i = 1 TO RECORDS(ProductQueue)
      GET(ProductQueue, i)
      TotalValue = TotalValue + (ProductQueue.Price * ProductQueue.Quantity)
    END

    ! Update a record using GET and PUT
    ProductQueue.ProductID = 1001
    GET(ProductQueue, ProductQueue.ProductID)  ! Key lookup
    IF NOT ERRORCODE()
      ProductQueue.Quantity = ProductQueue.Quantity + 5  ! Add 5 more
      PUT(ProductQueue)
    END

    ! DELETE a record
    ProductQueue.ProductID = 1003
    GET(ProductQueue, ProductQueue.ProductID)
    IF NOT ERRORCODE()
      DELETE(ProductQueue)
    END

    ! Build display message
    msg = 'Products in Queue:<13,10><13,10>'
    LOOP i = 1 TO RECORDS(ProductQueue)
      GET(ProductQueue, i)
      msg = msg & ProductQueue.ProductName & ' - $' & ProductQueue.Price & '<13,10>'
    END
    msg = msg & '<13,10>Total Inventory Value: $' & TotalValue
    msg = msg & '<13,10>Record Count: ' & RECORDS(ProductQueue)

    MESSAGE(msg,'Queue Demo')

    ! Clean up
    FREE(ProductQueue)
    RETURN
