!============================================================
! string_functions.clw - String Manipulation Functions
! Demonstrates: CLIP, LEFT, RIGHT, SUB, INSTRING, UPPER, etc.
!============================================================

  PROGRAM

  MAP
    StringDemo  PROCEDURE
  END

  CODE
    StringDemo()

StringDemo PROCEDURE
SourceStr     STRING(100)
ResultStr     STRING(100)
SearchStr     STRING(20)
PartStr       STRING(50)
NumericStr    STRING(20)
FormattedStr  STRING(100)
Position      LONG
Length        LONG
NumValue      DECIMAL(12,2)
msg           STRING(2000)

  CODE
    msg = 'String Function Demonstrations:<13,10><13,10>'

    !------------------------------------------------------------
    ! CLIP - Remove trailing spaces
    !------------------------------------------------------------
    SourceStr = 'Hello World          '
    ResultStr = CLIP(SourceStr)
    msg = msg & 'CLIP: [' & ResultStr & ']<13,10>'

    !------------------------------------------------------------
    ! LEFT - Left justify and pad
    !------------------------------------------------------------
    SourceStr = 'Test'
    ResultStr = LEFT(SourceStr, 10)
    msg = msg & 'LEFT: [' & ResultStr & ']<13,10>'

    !------------------------------------------------------------
    ! RIGHT - Right justify
    !------------------------------------------------------------
    SourceStr = 'Test'
    ResultStr = RIGHT(SourceStr, 10)
    msg = msg & 'RIGHT: [' & ResultStr & ']<13,10>'

    !------------------------------------------------------------
    ! CENTER - Center in field
    !------------------------------------------------------------
    SourceStr = 'Test'
    ResultStr = CENTER(SourceStr, 10)
    msg = msg & 'CENTER: [' & ResultStr & ']<13,10>'

    !------------------------------------------------------------
    ! SUB - Extract substring
    !------------------------------------------------------------
    SourceStr = 'Hello World'
    PartStr = SUB(SourceStr, 7, 5)      ! Start at 7, length 5
    msg = msg & 'SUB(7,5): ' & PartStr & '<13,10>'

    !------------------------------------------------------------
    ! INSTRING - Find substring position
    !------------------------------------------------------------
    SourceStr = 'Hello World Hello'
    SearchStr = 'Hello'
    Position = INSTRING(SearchStr, SourceStr, 1, 1)    ! First occurrence
    msg = msg & 'INSTRING (1st): ' & Position & '<13,10>'

    Position = INSTRING(SearchStr, SourceStr, 1, 2)    ! Second occurrence
    msg = msg & 'INSTRING (2nd): ' & Position & '<13,10>'

    !------------------------------------------------------------
    ! UPPER / LOWER - Case conversion
    !------------------------------------------------------------
    SourceStr = 'Hello World'
    ResultStr = UPPER(SourceStr)
    msg = msg & 'UPPER: ' & ResultStr & '<13,10>'

    ResultStr = LOWER(SourceStr)
    msg = msg & 'LOWER: ' & ResultStr & '<13,10>'

    !------------------------------------------------------------
    ! LEN - String length
    !------------------------------------------------------------
    SourceStr = 'Hello World'
    Length = LEN(CLIP(SourceStr))
    msg = msg & 'LEN: ' & Length & '<13,10>'

    !------------------------------------------------------------
    ! VAL / CHR - Character codes
    !------------------------------------------------------------
    msg = msg & 'VAL(A): ' & VAL('A') & '<13,10>'
    msg = msg & 'CHR(65): ' & CHR(65) & '<13,10>'

    !------------------------------------------------------------
    ! Concatenation with &
    !------------------------------------------------------------
    SourceStr = 'Hello' & ' ' & 'World'
    msg = msg & 'Concat: ' & SourceStr & '<13,10>'

    !------------------------------------------------------------
    ! NUMERIC - Check if string is numeric
    !------------------------------------------------------------
    NumericStr = '12345'
    IF NUMERIC(NumericStr)
      msg = msg & NumericStr & ' is numeric<13,10>'
    ELSE
      msg = msg & NumericStr & ' is not numeric<13,10>'
    END

    NumericStr = '123.45'
    IF NUMERIC(NumericStr)
      msg = msg & NumericStr & ' is numeric<13,10>'
    ELSE
      msg = msg & NumericStr & ' is not numeric<13,10>'
    END

    NumericStr = '123abc'
    IF NUMERIC(NumericStr)
      msg = msg & NumericStr & ' is numeric<13,10>'
    ELSE
      msg = msg & NumericStr & ' is not numeric<13,10>'
    END

    !------------------------------------------------------------
    ! FORMAT - Format numbers as strings
    !------------------------------------------------------------
    NumValue = 12345.67
    FormattedStr = FORMAT(NumValue, @n$12.2)
    msg = msg & 'FORMAT currency: ' & FormattedStr & '<13,10>'

    FormattedStr = FORMAT(NumValue, @n12.2)
    msg = msg & 'FORMAT decimal: ' & FormattedStr & '<13,10>'

    !------------------------------------------------------------
    ! DEFORMAT - Parse formatted string to number
    !------------------------------------------------------------
    FormattedStr = '$1,234.56'
    NumValue = DEFORMAT(FormattedStr, @n$12.2)
    msg = msg & 'DEFORMAT: ' & NumValue & '<13,10>'

    !------------------------------------------------------------
    ! ALL - Repeat character/string
    !------------------------------------------------------------
    ResultStr = ALL('-', 20)
    msg = msg & 'ALL: ' & ResultStr & '<13,10>'

    MESSAGE(msg,'String Functions Demo')
    RETURN
