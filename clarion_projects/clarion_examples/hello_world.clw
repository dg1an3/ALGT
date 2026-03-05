!============================================================
! hello_world.clw - Basic Clarion Program Structure
! Demonstrates: PROGRAM, MAP, CODE sections
!============================================================

  PROGRAM

  MAP
    HelloWorld  PROCEDURE
  END

  CODE
    HelloWorld()

HelloWorld PROCEDURE
  CODE
    MESSAGE('Hello, World!','Clarion Example')
    RETURN
