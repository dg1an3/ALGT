!============================================================
! class_example.clw - Object-Oriented Programming in Clarion
! Demonstrates: CLASS declaration, methods, inheritance
!============================================================

  PROGRAM

  MAP
    ClassDemo  PROCEDURE
  END

!------------------------------------------------------------
! Base Shape Class
!------------------------------------------------------------
ShapeClass      CLASS,TYPE
Name              STRING(20)
X                 LONG
Y                 LONG
Construct         PROCEDURE
Destruct          PROCEDURE,VIRTUAL
Init              PROCEDURE(STRING pName, LONG pX, LONG pY)
GetName           PROCEDURE,STRING
Move              PROCEDURE(LONG pDeltaX, LONG pDeltaY)
GetArea           PROCEDURE,DECIMAL,VIRTUAL
GetDescription    PROCEDURE,STRING,VIRTUAL
                END

!------------------------------------------------------------
! Rectangle Class (inherits from ShapeClass)
!------------------------------------------------------------
RectangleClass  CLASS(ShapeClass),TYPE
Width             LONG
Height            LONG
Init              PROCEDURE(STRING pName, LONG pX, LONG pY, LONG pWidth, LONG pHeight)
SetSize           PROCEDURE(LONG pWidth, LONG pHeight)
GetArea           PROCEDURE,DECIMAL,VIRTUAL
GetDescription    PROCEDURE,STRING,VIRTUAL
                END

!------------------------------------------------------------
! Circle Class (inherits from ShapeClass)
!------------------------------------------------------------
CircleClass     CLASS(ShapeClass),TYPE
Radius            LONG
Init              PROCEDURE(STRING pName, LONG pX, LONG pY, LONG pRadius)
SetRadius         PROCEDURE(LONG pRadius)
GetArea           PROCEDURE,DECIMAL,VIRTUAL
GetDescription    PROCEDURE,STRING,VIRTUAL
GetCircumference  PROCEDURE,DECIMAL
                END

  CODE
    ClassDemo()

!============================================================
! Main Demo Procedure
!============================================================
ClassDemo PROCEDURE
MyRect      RectangleClass
MyCircle    CircleClass
msg         STRING(500)

  CODE
    ! Initialize Rectangle
    MyRect.Init('Rectangle1', 10, 20, 100, 50)

    ! Initialize Circle
    MyCircle.Init('Circle1', 50, 50, 25)

    ! Build output message
    msg = 'Shape Demo Results:<13,10><13,10>'

    msg = msg & MyRect.GetDescription() & '<13,10>'
    msg = msg & '  Area: ' & MyRect.GetArea() & '<13,10>'

    msg = msg & '<13,10>' & MyCircle.GetDescription() & '<13,10>'
    msg = msg & '  Area: ' & MyCircle.GetArea() & '<13,10>'
    msg = msg & '  Circumference: ' & MyCircle.GetCircumference() & '<13,10>'

    ! Move shapes
    MyRect.Move(5, 10)
    MyCircle.Move(-10, 5)

    msg = msg & '<13,10>After moving:<13,10>'
    msg = msg & MyRect.GetName() & ' at (' & MyRect.X & ',' & MyRect.Y & ')<13,10>'
    msg = msg & MyCircle.GetName() & ' at (' & MyCircle.X & ',' & MyCircle.Y & ')<13,10>'

    MESSAGE(msg,'Class Demo')

    ! Cleanup
    MyRect.Destruct()
    MyCircle.Destruct()
    RETURN

!============================================================
! ShapeClass Methods
!============================================================
ShapeClass.Construct PROCEDURE
  CODE
    SELF.Name = ''
    SELF.X = 0
    SELF.Y = 0

ShapeClass.Destruct PROCEDURE
  CODE
    ! Cleanup code here
    RETURN

ShapeClass.Init PROCEDURE(STRING pName, LONG pX, LONG pY)
  CODE
    SELF.Name = pName
    SELF.X = pX
    SELF.Y = pY

ShapeClass.GetName PROCEDURE
  CODE
    RETURN CLIP(SELF.Name)

ShapeClass.Move PROCEDURE(LONG pDeltaX, LONG pDeltaY)
  CODE
    SELF.X = SELF.X + pDeltaX
    SELF.Y = SELF.Y + pDeltaY

ShapeClass.GetArea PROCEDURE
  CODE
    RETURN 0  ! Base class returns 0

ShapeClass.GetDescription PROCEDURE
  CODE
    RETURN 'Shape: ' & CLIP(SELF.Name)

!============================================================
! RectangleClass Methods
!============================================================
RectangleClass.Init PROCEDURE(STRING pName, LONG pX, LONG pY, LONG pWidth, LONG pHeight)
  CODE
    PARENT.Init(pName, pX, pY)
    SELF.Width = pWidth
    SELF.Height = pHeight

RectangleClass.SetSize PROCEDURE(LONG pWidth, LONG pHeight)
  CODE
    SELF.Width = pWidth
    SELF.Height = pHeight

RectangleClass.GetArea PROCEDURE
  CODE
    RETURN SELF.Width * SELF.Height

RectangleClass.GetDescription PROCEDURE
  CODE
    RETURN 'Rectangle: ' & CLIP(SELF.Name) & ' (' & SELF.Width & 'x' & SELF.Height & ')'

!============================================================
! CircleClass Methods
!============================================================
CircleClass.Init PROCEDURE(STRING pName, LONG pX, LONG pY, LONG pRadius)
  CODE
    PARENT.Init(pName, pX, pY)
    SELF.Radius = pRadius

CircleClass.SetRadius PROCEDURE(LONG pRadius)
  CODE
    SELF.Radius = pRadius

CircleClass.GetArea PROCEDURE
PI  DECIMAL(10,8)
  CODE
    PI = 3.14159265
    RETURN PI * SELF.Radius * SELF.Radius

CircleClass.GetDescription PROCEDURE
  CODE
    RETURN 'Circle: ' & CLIP(SELF.Name) & ' (radius=' & SELF.Radius & ')'

CircleClass.GetCircumference PROCEDURE
PI  DECIMAL(10,8)
  CODE
    PI = 3.14159265
    RETURN 2 * PI * SELF.Radius
