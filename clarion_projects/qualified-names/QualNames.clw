  MEMBER()

DoseFile FILE,DRIVER('DOS'),PRE(DOSE)
Record     RECORD
Dose_Ttl     LONG
Display      GROUP,PRE(DSP)
Size           LONG
Scale          LONG
             END
           END
         END

TreatGrp GROUP,PRE(TRT)
Plan       GROUP,PRE(PLN)
BeamCount    LONG
Energy       LONG
           END
Offset     LONG
         END

  MAP
    InitDose(),LONG,C,NAME('InitDose'),EXPORT
    SetDisplay(LONG, LONG),LONG,C,NAME('SetDisplay'),EXPORT
    GetDisplaySize(),LONG,C,NAME('GetDisplaySize'),EXPORT
    GetDisplayScale(),LONG,C,NAME('GetDisplayScale'),EXPORT
    CalcTotal(),LONG,C,NAME('CalcTotal'),EXPORT
    SetPlan(LONG, LONG),LONG,C,NAME('SetPlan'),EXPORT
    GetBeamCount(),LONG,C,NAME('GetBeamCount'),EXPORT
    GetEnergy(),LONG,C,NAME('GetEnergy'),EXPORT
    CalcDoseProduct(),LONG,C,NAME('CalcDoseProduct'),EXPORT
  END

InitDose PROCEDURE()
  CODE
  DOSE:Dose_Ttl = 0
  DSP:Size = 0
  DSP:Scale = 1
  TRT:Offset = 0
  PLN:BeamCount = 0
  PLN:Energy = 0
  RETURN(0)

SetDisplay PROCEDURE(LONG sz, LONG sc)
  CODE
  DSP:Size = sz
  DSP:Scale = sc
  RETURN(0)

GetDisplaySize PROCEDURE()
  CODE
  RETURN(DSP:Size)

GetDisplayScale PROCEDURE()
  CODE
  RETURN(DSP:Scale)

CalcTotal PROCEDURE()
  CODE
  DOSE:Dose_Ttl = DSP:Size * DSP:Scale
  RETURN(DOSE:Dose_Ttl)

SetPlan PROCEDURE(LONG beams, LONG energy)
  CODE
  PLN:BeamCount = beams
  PLN:Energy = energy
  RETURN(0)

GetBeamCount PROCEDURE()
  CODE
  RETURN(PLN:BeamCount)

GetEnergy PROCEDURE()
  CODE
  RETURN(PLN:Energy)

CalcDoseProduct PROCEDURE()
  CODE
  DOSE:Dose_Ttl = PLN:BeamCount * PLN:Energy + TRT:Offset
  RETURN(DOSE:Dose_Ttl)
