  MEMBER()
! GrafUtil.clw — Clarion implementation of Apple GrafUtil.p utility functions
! Based on GrafUtil.p by Apple Computer, 1983 (UNIT GrafUtil)
!
! This file deliberately uses variant casing to demonstrate that Clarion
! is case-insensitive. Keywords, types, and variable names appear in
! mixed case throughout — UPPER, lower, and PascalCase are all equivalent.
!
! Original Pascal types from GrafUtil.p:
!   TYPE Fixed = LongInt;                         {16.16 fixed-point}
!        Int64Bit = RECORD hiLong: LongInt;       {high 32 bits}
!                          loLong: LongInt; END;  {low 32 bits}

  MAP
    ! Original Pascal: FUNCTION BitAnd(long1,long2: LongInt): LongInt;
    GUBitAnd(long a, long b),LONG,C,NAME('GUBitAnd'),EXPORT
    ! Original Pascal: FUNCTION BitOr(long1,long2: LongInt): LongInt;
    GUBitOr(Long a, Long b),Long,C,Name('GUBitOr'),Export
    ! Original Pascal: FUNCTION BitXor(long1,long2: LongInt): LongInt;
    GUBitXor(LONG a, LONG b),LONG,C,NAME('GUBitXor'),EXPORT
    ! Original Pascal: FUNCTION BitNot(long: LongInt): LongInt;
    GUBitNot(long a),long,c,name('GUBitNot'),export
    ! Original Pascal: FUNCTION BitShift(long: LongInt; count: INTEGER): LongInt;
    !   {positive=left, negative=right}
    GUBitShift(Long val, Long count),Long,C,Name('GUBitShift'),Export
    ! Original Pascal: FUNCTION BitTst(bytePtr: QDPtr; bitNum: LongInt): BOOLEAN;
    GUBitTst(LONG val, LONG bitNum),LONG,C,NAME('GUBitTst'),EXPORT
    ! Original Pascal: PROCEDURE BitSet(bytePtr: QDPtr; bitNum: LongInt);
    GUBitSet(long val, long bitNum),LONG,C,NAME('GUBitSet'),EXPORT
    ! Original Pascal: PROCEDURE BitClr(bytePtr: QDPtr; bitNum: LongInt);
    GUBitClr(Long val, Long bitNum),Long,C,Name('GUBitClr'),Export
    ! Original Pascal: PROCEDURE LongMul(a,b: LongInt; VAR dst: Int64Bit);
    !   Split into Hi/Lo since Clarion has no 64-bit integer type
    GULongMulHi(LONG a, LONG b),LONG,C,NAME('GULongMulHi'),EXPORT
    GULongMulLo(long a, long b),long,c,name('GULongMulLo'),export
    ! Original Pascal: FUNCTION FixMul(a,b: Fixed): Fixed;  {16.16 fixed-point multiply}
    GUFixMul(Long a, Long b),Long,C,Name('GUFixMul'),Export
    ! Original Pascal: FUNCTION FixRatio(numer,denom: INTEGER): Fixed;
    GUFixRatio(LONG numer, LONG denom),LONG,C,NAME('GUFixRatio'),EXPORT
    ! Original Pascal: FUNCTION HiWord(x: Fixed): INTEGER;
    GUHiWord(long x),long,c,name('GUHiWord'),export
    ! Original Pascal: FUNCTION LoWord(x: Fixed): INTEGER;
    GULoWord(Long x),Long,C,Name('GULoWord'),Export
    ! Original Pascal: FUNCTION FixRound(x: Fixed): INTEGER;
    GUFixRound(LONG x),LONG,C,NAME('GUFixRound'),EXPORT
  END

! ---- Bitwise operations ----

! Original Pascal: FUNCTION BitAnd(long1,long2: LongInt): LongInt;
GUBitAnd Procedure(Long a, Long b)
  code
  Return BAND(a, b)

! Original Pascal: FUNCTION BitOr(long1,long2: LongInt): LongInt;
GUBitOr procedure(long a, long b)
  CODE
  return BOR(a, b)

! Original Pascal: FUNCTION BitXor(long1,long2: LongInt): LongInt;
GUBitXor PROCEDURE(LONG a, LONG b)
  Code
  RETURN BXOR(a, b)

! Original Pascal: FUNCTION BitNot(long: LongInt): LongInt;
GUBitNot Procedure(Long a)
  code
  Return BXOR(a, -1)

! Original Pascal: FUNCTION BitShift(long: LongInt; count: INTEGER): LongInt;
!   positive count = shift left, negative count = shift right
GUBitShift procedure(Long val, Long count)
  CODE
  return BSHIFT(val, count)

! Original Pascal: FUNCTION BitTst(bytePtr: QDPtr; bitNum: LongInt): BOOLEAN;
!   Adapted: operates on a LONG value instead of a byte pointer.
!   Returns 1 if bit is set, 0 if clear.
GUBitTst PROCEDURE(LONG val, LONG bitNum)
  Code
  if BAND(val, BSHIFT(1, bitNum)) <> 0
    RETURN 1
  end
  Return 0

! Original Pascal: PROCEDURE BitSet(bytePtr: QDPtr; bitNum: LongInt);
!   Adapted: returns val with the specified bit set.
GUBitSet Procedure(long val, long bitNum)
  code
  Return BOR(val, BSHIFT(1, bitNum))

! Original Pascal: PROCEDURE BitClr(bytePtr: QDPtr; bitNum: LongInt);
!   Adapted: returns val with the specified bit cleared.
GUBitClr procedure(Long val, Long bitNum)
  CODE
  return BAND(val, BXOR(BSHIFT(1, bitNum), -1))

! ---- 64-bit multiplication ----

! Original Pascal: PROCEDURE LongMul(a,b: LongInt; VAR dst: Int64Bit);
!   Returns high 32 bits of the 64-bit product a*b.
!   Uses REAL (floating-point) as intermediate to hold full product.
GULongMulHi PROCEDURE(LONG a, LONG b)
product   REAL
hiVal     LONG
  Code
  product = a * 1.0 * b
  ! Divide by 2^32 and truncate to get high 32 bits
  if product < 0
    hiVal = -1 - INT((-product - 1) / 4294967296)
  else
    hiVal = INT(product / 4294967296)
  end
  RETURN hiVal

! Original Pascal: PROCEDURE LongMul(a,b: LongInt; VAR dst: Int64Bit);
!   Returns low 32 bits of the 64-bit product a*b.
GULongMulLo procedure(long a, long b)
  code
  ! For values that fit in 32 bits, a*b mod 2^32 is just the normal product
  ! Clarion LONG wraps on overflow, giving us the low 32 bits naturally
  return a * b

! ---- Fixed-point arithmetic (16.16 format) ----

! Original Pascal: FUNCTION FixMul(a,b: Fixed): Fixed;
!   Multiplies two 16.16 fixed-point numbers.
!   Result = (a * b) / 65536, using REAL intermediate to avoid overflow.
GUFixMul Procedure(Long a, Long b)
product   REAL
  Code
  product = a
  product = product * b
  product = product / 65536
  if product < 0
    Return INT(product - 0.5)
  else
    Return INT(product + 0.5)
  end

! Original Pascal: FUNCTION FixRatio(numer,denom: INTEGER): Fixed;
!   Returns numer/denom as a 16.16 fixed-point number.
GUFixRatio PROCEDURE(LONG numer, LONG denom)
result    REAL
  CODE
  if denom = 0
    if numer >= 0
      RETURN 7FFFFFFFh    ! +max fixed
    else
      RETURN 80000001h    ! -max fixed (most negative representable)
    end
  end
  result = numer
  result = result * 65536
  result = result / denom
  ! Truncate toward zero (Pascal convention)
  if result >= 0
    Return INT(result)
  else
    Return -INT(-result)
  end

! Original Pascal: FUNCTION HiWord(x: Fixed): INTEGER;
!   Returns the upper 16 bits (integer part of 16.16 fixed-point).
!   Arithmetic shift right by 16 preserves sign.
GUHiWord procedure(long x)
  code
  ! Arithmetic shift right 16: use integer division to preserve sign
  if x >= 0
    return x / 65536
  else
    return -1 - ((-x - 1) / 65536)
  end

! Original Pascal: FUNCTION LoWord(x: Fixed): INTEGER;
!   Returns the lower 16 bits (fractional part of 16.16 fixed-point).
GULoWord Procedure(Long x)
  Code
  Return BAND(x, 0FFFFh)

! Original Pascal: FUNCTION FixRound(x: Fixed): INTEGER;
!   Rounds a 16.16 fixed-point number to the nearest integer.
!   Adds 0.5 (= 8000h in 16.16) then takes integer part.
GUFixRound PROCEDURE(LONG x)
rounded   REAL
  CODE
  rounded = x
  rounded = rounded + 08000h
  rounded = rounded / 65536
  if rounded >= 0
    Return INT(rounded)
  else
    Return INT(rounded) - 1
  end
