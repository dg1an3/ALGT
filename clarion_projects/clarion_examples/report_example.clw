!============================================================
! report_example.clw - Report Generation
! Demonstrates: REPORT structure, bands, page breaks, totals
!============================================================

  PROGRAM

  MAP
    ReportDemo  PROCEDURE
  END

! Sample Data Queue
SalesQueue      QUEUE
Region            STRING(20)
Product           STRING(30)
Quantity          LONG
UnitPrice         DECIMAL(10,2)
SaleDate          DATE
Salesperson       STRING(30)
                END

  CODE
    ReportDemo()

ReportDemo PROCEDURE
! Report totals
GrandTotal      DECIMAL(12,2)
RegionTotal     DECIMAL(12,2)
LineTotal       DECIMAL(12,2)
PageNumber      LONG
CurrentRegion   STRING(20)

! Report Structure
SalesReport REPORT,AT(500,500,6500,9500),PRE(Rpt),FONT('Arial',10),THOUS
              HEADER,AT(0,0,6500,750)
                STRING('Sales Report'),AT(2500,100),FONT(,14,,FONT:Bold)
                STRING('Date: ' & FORMAT(TODAY(),@D2)),AT(5500,100)
                BOX,AT(0,600,6500,10),LINEWIDTH(2),COLOR(COLOR:Black)
              END

              ! Page Header (repeats on each page)
              HEADER,AT(0,750,6500,400),PAGE
                STRING('Region'),AT(100,50),FONT(,,FONT:Bold)
                STRING('Product'),AT(1500,50),FONT(,,FONT:Bold)
                STRING('Qty'),AT(3500,50),FONT(,,FONT:Bold)
                STRING('Price'),AT(4200,50),FONT(,,FONT:Bold)
                STRING('Total'),AT(5200,50),FONT(,,FONT:Bold)
                BOX,AT(0,350,6500,5),COLOR(COLOR:Black)
              END

              ! Group Header - Region Break
              BREAK(SalesQueue.Region)
                HEADER,AT(0,0,6500,300)
                  STRING('Region:'),AT(100,50)
                  STRING(@s20),AT(700,50),USE(SalesQueue.Region),FONT(,,FONT:Bold)
                END

                ! Group Footer - Region Subtotal
                FOOTER,AT(0,0,6500,350)
                  BOX,AT(100,50,6300,5),COLOR(COLOR:Gray)
                  STRING('Region Subtotal:'),AT(3800,100),FONT(,,FONT:Bold)
                  STRING(@n$12.2),AT(5200,100),USE(RegionTotal)
                END
              END

              ! Detail Band
              DETAIL,AT(0,0,6500,250)
                STRING(@s30),AT(1500,50),USE(SalesQueue.Product)
                STRING(@n6),AT(3500,50),USE(SalesQueue.Quantity)
                STRING(@n$10.2),AT(4200,50),USE(SalesQueue.UnitPrice)
                STRING(@n$12.2),AT(5200,50),USE(LineTotal)
              END

              ! Page Footer
              FOOTER,AT(0,9200,6500,300),PAGE
                BOX,AT(0,50,6500,5),COLOR(COLOR:Black)
                STRING('Page:'),AT(5700,100)
                STRING(@n3),AT(6100,100),USE(PageNumber)
              END

              ! Report Footer - Grand Total
              FOOTER,AT(0,0,6500,500)
                BOX,AT(100,50,6300,10),LINEWIDTH(2),COLOR(COLOR:Black)
                STRING('Grand Total:'),AT(3800,150),FONT(,12,,FONT:Bold)
                STRING(@n$14.2),AT(5000,150),USE(GrandTotal),FONT(,12,,FONT:Bold)
              END
            END

  CODE
    ! Load sample data
    DO LoadSampleData

    ! Sort by Region for grouping
    SORT(SalesQueue, SalesQueue.Region, SalesQueue.Product)

    ! Initialize totals
    GrandTotal = 0
    RegionTotal = 0
    PageNumber = 0
    CurrentRegion = ''

    ! Open report (to preview or printer)
    SalesReport{PROP:Preview} = TRUE
    OPEN(SalesReport)

    IF ERRORCODE()
      MESSAGE('Error opening report: ' & ERROR(),'Error')
      RETURN
    END

    ! Process all records
    LOOP i# = 1 TO RECORDS(SalesQueue)
      GET(SalesQueue, i#)

      ! Check for region break
      IF CurrentRegion <> '' AND CurrentRegion <> SalesQueue.Region
        ! Print region footer with subtotal
        PRINT(Rpt:BREAK1:Footer)
        RegionTotal = 0
      END

      ! Print region header for new region
      IF CurrentRegion <> SalesQueue.Region
        CurrentRegion = SalesQueue.Region
        PRINT(Rpt:BREAK1:Header)
      END

      ! Calculate line total
      LineTotal = SalesQueue.Quantity * SalesQueue.UnitPrice
      RegionTotal += LineTotal
      GrandTotal += LineTotal

      ! Print detail line
      PRINT(Rpt:Detail)
    END

    ! Print final region footer
    IF CurrentRegion <> ''
      PRINT(Rpt:BREAK1:Footer)
    END

    ! Close report (triggers report footer)
    CLOSE(SalesReport)

    ! Clean up
    FREE(SalesQueue)
    RETURN

LoadSampleData ROUTINE
    FREE(SalesQueue)

    SalesQueue.Region = 'East'
    SalesQueue.Product = 'Widget A'
    SalesQueue.Quantity = 100
    SalesQueue.UnitPrice = 25.00
    SalesQueue.SaleDate = TODAY()
    SalesQueue.Salesperson = 'John Smith'
    ADD(SalesQueue)

    SalesQueue.Region = 'East'
    SalesQueue.Product = 'Widget B'
    SalesQueue.Quantity = 75
    SalesQueue.UnitPrice = 35.50
    ADD(SalesQueue)

    SalesQueue.Region = 'West'
    SalesQueue.Product = 'Widget A'
    SalesQueue.Quantity = 150
    SalesQueue.UnitPrice = 25.00
    ADD(SalesQueue)

    SalesQueue.Region = 'West'
    SalesQueue.Product = 'Gadget X'
    SalesQueue.Quantity = 50
    SalesQueue.UnitPrice = 99.99
    ADD(SalesQueue)

    SalesQueue.Region = 'North'
    SalesQueue.Product = 'Widget C'
    SalesQueue.Quantity = 200
    SalesQueue.UnitPrice = 15.00
    ADD(SalesQueue)

    SalesQueue.Region = 'North'
    SalesQueue.Product = 'Gadget Y'
    SalesQueue.Quantity = 30
    SalesQueue.UnitPrice = 149.95
    ADD(SalesQueue)

    EXIT
