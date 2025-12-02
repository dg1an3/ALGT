!============================================================
! window_example.clw - Window and Control Handling
! Demonstrates: WINDOW, ACCEPT loop, Events, Controls
!============================================================

  PROGRAM

  MAP
    MainWindow  PROCEDURE
  END

  CODE
    MainWindow()

MainWindow PROCEDURE
FirstName   STRING(30)
LastName    STRING(30)
Email       STRING(50)
Age         LONG
SaveClicked BYTE(FALSE)

Window WINDOW('Customer Entry'),AT(,,300,180),CENTER,SYSTEM,GRAY
       PROMPT('First Name:'),AT(10,10)
       ENTRY(@s30),AT(80,10,150,12),USE(FirstName)
       PROMPT('Last Name:'),AT(10,30)
       ENTRY(@s30),AT(80,30,150,12),USE(LastName)
       PROMPT('Email:'),AT(10,50)
       ENTRY(@s50),AT(80,50,150,12),USE(Email)
       PROMPT('Age:'),AT(10,70)
       SPIN(@n3),AT(80,70,50,12),USE(Age),RANGE(1,120)
       BUTTON('&Save'),AT(80,100,60,20),USE(?SaveButton)
       BUTTON('&Cancel'),AT(150,100,60,20),USE(?CancelButton)
       BUTTON('&Clear'),AT(220,100,60,20),USE(?ClearButton)
       STRING(''),AT(10,130,280,12),USE(?StatusText)
     END

  CODE
    OPEN(Window)

    ! Set initial values
    FirstName = ''
    LastName = ''
    Email = ''
    Age = 25

    ACCEPT
      CASE EVENT()

      OF EVENT:OpenWindow
        ?StatusText{PROP:Text} = 'Enter customer information'
        SELECT(?FirstName)

      OF EVENT:Accepted
        CASE ACCEPTED()

        OF ?SaveButton
          IF CLIP(FirstName) = '' OR CLIP(LastName) = ''
            ?StatusText{PROP:Text} = 'Name fields are required!'
            BEEP
            IF CLIP(FirstName) = ''
              SELECT(?FirstName)
            ELSE
              SELECT(?LastName)
            END
            CYCLE
          END
          SaveClicked = TRUE
          ?StatusText{PROP:Text} = 'Customer saved successfully!'
          MESSAGE('Saved: ' & CLIP(FirstName) & ' ' & CLIP(LastName), |
                  'Success')

        OF ?CancelButton
          IF SaveClicked = FALSE
            IF FirstName <> '' OR LastName <> '' OR Email <> ''
              IF MESSAGE('Discard changes?','Confirm',ICON:Question,BUTTON:Yes+BUTTON:No) = BUTTON:No
                CYCLE
              END
            END
          END
          BREAK

        OF ?ClearButton
          FirstName = ''
          LastName = ''
          Email = ''
          Age = 25
          DISPLAY
          ?StatusText{PROP:Text} = 'Form cleared'
          SELECT(?FirstName)
        END

      OF EVENT:CloseWindow
        BREAK

      END
    END

    CLOSE(Window)
    RETURN
