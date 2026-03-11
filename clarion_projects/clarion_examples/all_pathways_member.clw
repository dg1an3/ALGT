!============================================================
! all_pathways_member.clw - Exercises the MEMBER() program pathway
!
! The PROGRAM form is covered by all_pathways.clw; this file
! covers the MEMBER() form used by DLL source files.
!
! Production: program -> MEMBER() top_decls map_block procedures
!============================================================

  MEMBER()

!------------------------------------------------------------
! top_decl_item: FILE, GROUP, QUEUE, global, array
! (Same constructs but in MEMBER context -- no CODE section at top)
!------------------------------------------------------------
DataFile    FILE,DRIVER('TOPSPEED'),PRE(Dat),CREATE
ByKey         KEY(Dat:ID),PRIMARY
Record        RECORD
ID              LONG
Label           CSTRING(50)
Amount          DECIMAL(10,2)
              END
            END

Settings    GROUP,PRE(Cfg)
Threshold     LONG
MaxItems      LONG
            END

ItemQ       QUEUE
ItemID        LONG
ItemLabel     STRING(30)
            END

Buffer      LONG,DIM(5)

NextID      LONG(1)

  MAP
    ! map_entry: params with ref (*Type) and optional (<Type>)
    MemberInit(),LONG,C,EXPORT,NAME('MInit')
    MemberAdd(*CSTRING, LONG, <LONG>),LONG,C,EXPORT
    MemberCalc PROCEDURE(LONG),LONG
    MemberLookup(LONG, *LONG),LONG,PASCAL
    MemberClose PROCEDURE,RAW,PRIVATE
  END

!============================================================
! Procedures -- exercises ref params, optional params, calling conventions
!============================================================
MemberInit PROCEDURE
  CODE
    NextID = 1
    RETURN 0

MemberAdd PROCEDURE(*CSTRING Lbl, LONG Amt, <LONG Extra>)
  CODE
    NextID += 1
    RETURN NextID

MemberCalc PROCEDURE(LONG Mode)
Acc   LONG(0)
Idx   LONG
  CODE
    LOOP Idx = 1 TO 5
      Acc += Buffer[Idx]
    END
    IF Mode = 1
      RETURN Acc
    ELSE
      RETURN Acc / 5
    END

MemberLookup PROCEDURE(LONG ID, *LONG OutVal)
  CODE
    RETURN 0

MemberClose PROCEDURE
  CODE
    RETURN
