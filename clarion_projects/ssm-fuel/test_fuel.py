import ctypes
import os
import struct
import sys

# TransBuf layout matches the Clarion GROUP:
#   Month       BYTE       (1)
#   Day         BYTE       (1)
#   Year        SHORT      (2)
#   Hour        BYTE       (1)
#   Minute      BYTE       (1)
#   Description STRING(40) (40)
#   Amount      LONG       (4)
#   Balance     LONG       (4)
# Total: 54 bytes, packed (no padding)

TRANSBUF_SIZE = 54
TRANSBUF_FMT = '<BBhBB40sii'

def parse_trans(buf):
    """Parse a TransBuf bytes object into a dict."""
    month, day, year, hour, minute, desc_raw, amount, balance = struct.unpack(TRANSBUF_FMT, buf)
    # Clarion STRING is space-padded; strip trailing spaces and nulls
    desc = desc_raw.rstrip(b'\x00').rstrip(b' ').decode('ascii', errors='replace')
    return {
        'month': month, 'day': day, 'year': year,
        'hour': hour, 'minute': minute,
        'description': desc,
        'amount': amount, 'balance': balance,
    }

def main():
    dll_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "bin", "FuelLib.dll")
    if not os.path.exists(dll_path):
        print(f"Error: {dll_path} not found.")
        sys.exit(1)

    # Clean up previous data files
    for f in ('FuelTrans.dat', 'FuelPrice.dat'):
        dat = os.path.join(os.path.dirname(os.path.abspath(__file__)), f)
        if os.path.exists(dat):
            os.remove(dat)

    try:
        lib = ctypes.CDLL(dll_path)
    except Exception as e:
        print(f"Error loading DLL: {e}")
        sys.exit(1)

    passed = 0
    failed = 0

    def check(name, actual, expected):
        nonlocal passed, failed
        if actual == expected:
            print(f"  PASS: {name} = {actual}")
            passed += 1
        else:
            print(f"  FAIL: {name} = {actual}, expected {expected}")
            failed += 1

    # ---- Open ----
    print("=== Open ===")
    rc = lib.FLOpen()
    check("FLOpen()", rc, 0)

    # ---- Set Prices ----
    print("\n=== Set Prices ===")
    check("FLSetPrice(1, 359) Regular", lib.FLSetPrice(1, 359), 0)
    check("FLSetPrice(2, 389) Midgrade", lib.FLSetPrice(2, 389), 0)
    check("FLSetPrice(3, 419) Premium", lib.FLSetPrice(3, 419), 0)
    check("FLSetPrice(4, 399) Diesel", lib.FLSetPrice(4, 399), 0)
    check("FLSetPrice(5, 100) invalid", lib.FLSetPrice(5, 100), -1)
    check("FLSetPrice(0, 100) invalid", lib.FLSetPrice(0, 100), -1)

    # ---- Get Prices ----
    print("\n=== Get Prices ===")
    check("FLGetPrice(1) Regular", lib.FLGetPrice(1), 359)
    check("FLGetPrice(2) Midgrade", lib.FLGetPrice(2), 389)
    check("FLGetPrice(3) Premium", lib.FLGetPrice(3), 419)
    check("FLGetPrice(4) Diesel", lib.FLGetPrice(4), 399)
    check("FLGetPrice(5) invalid", lib.FLGetPrice(5), -1)

    # ---- Update a price ----
    print("\n=== Update Price ===")
    check("FLSetPrice(1, 369) update Regular", lib.FLSetPrice(1, 369), 0)
    check("FLGetPrice(1) updated", lib.FLGetPrice(1), 369)

    # ---- Add Transactions ----
    print("\n=== Add Transactions ===")

    def add_trans(month, day, year, hour, minute, desc, amount):
        desc_bytes = desc.encode('ascii')
        desc_buf = ctypes.create_string_buffer(desc_bytes)
        return lib.FLAddTransaction(month, day, year, hour, minute,
                                    ctypes.addressof(desc_buf), len(desc_bytes),
                                    amount)

    # Transaction 1: Fuel delivery +50000 cents ($500.00)
    bal = add_trans(3, 1, 2026, 8, 0, "Fuel delivery - Regular", 50000)
    check("Add tx1 balance", bal, 50000)

    # Transaction 2: Sale -1500 cents ($15.00)
    bal = add_trans(3, 1, 2026, 10, 30, "Sale - 4.06 gal Regular", -1500)
    check("Add tx2 balance", bal, 48500)

    # Transaction 3: Sale -2500 cents ($25.00)
    bal = add_trans(3, 2, 2026, 14, 15, "Sale - 6.78 gal Regular", -2500)
    check("Add tx3 balance", bal, 46000)

    # Transaction 4: Fuel delivery +75000 cents ($750.00)
    bal = add_trans(3, 3, 2026, 7, 0, "Fuel delivery - Premium", 75000)
    check("Add tx4 balance", bal, 121000)

    # Transaction 5: Sale -3200 cents ($32.00)
    bal = add_trans(3, 3, 2026, 16, 45, "Sale - 7.64 gal Premium", -3200)
    check("Add tx5 balance", bal, 117800)

    # ---- Transaction Count ----
    print("\n=== Transaction Count ===")
    check("FLGetTransactionCount()", lib.FLGetTransactionCount(), 5)

    # ---- Get Balance ----
    print("\n=== Get Balance ===")
    check("FLGetBalance()", lib.FLGetBalance(), 117800)

    # ---- Get Transactions ----
    print("\n=== Get Transactions ===")
    buf = ctypes.create_string_buffer(TRANSBUF_SIZE)

    rc = lib.FLGetTransaction(1, ctypes.addressof(buf))
    check("FLGetTransaction(1) rc", rc, 0)
    if rc == 0:
        t = parse_trans(buf.raw)
        check("tx1 month", t['month'], 3)
        check("tx1 day", t['day'], 1)
        check("tx1 year", t['year'], 2026)
        check("tx1 hour", t['hour'], 8)
        check("tx1 minute", t['minute'], 0)
        check("tx1 description", t['description'], "Fuel delivery - Regular")
        check("tx1 amount", t['amount'], 50000)
        check("tx1 balance", t['balance'], 50000)

    rc = lib.FLGetTransaction(3, ctypes.addressof(buf))
    check("FLGetTransaction(3) rc", rc, 0)
    if rc == 0:
        t = parse_trans(buf.raw)
        check("tx3 amount", t['amount'], -2500)
        check("tx3 balance", t['balance'], 46000)

    # Invalid index
    rc = lib.FLGetTransaction(99, ctypes.addressof(buf))
    check("FLGetTransaction(99) invalid", rc, -1)

    # ---- Delete Transaction ----
    print("\n=== Delete Transaction ===")
    # Delete tx2 (Sale -1500). After delete:
    #   tx1: amount=50000,  balance=50000
    #   tx3: amount=-2500,  balance=47500  (was 46000, recalculated)
    #   tx4: amount=75000,  balance=122500 (was 121000)
    #   tx5: amount=-3200,  balance=119300 (was 117800)
    rc = lib.FLDeleteTransaction(2)
    check("FLDeleteTransaction(2) rc", rc, 0)
    check("Count after delete", lib.FLGetTransactionCount(), 4)
    check("Balance after delete", lib.FLGetBalance(), 119300)

    # Verify rebalanced transactions
    rc = lib.FLGetTransaction(1, ctypes.addressof(buf))
    if rc == 0:
        t = parse_trans(buf.raw)
        check("after del tx1 balance", t['balance'], 50000)

    rc = lib.FLGetTransaction(2, ctypes.addressof(buf))
    if rc == 0:
        t = parse_trans(buf.raw)
        check("after del tx2 (was tx3) amount", t['amount'], -2500)
        check("after del tx2 (was tx3) balance", t['balance'], 47500)

    rc = lib.FLGetTransaction(3, ctypes.addressof(buf))
    if rc == 0:
        t = parse_trans(buf.raw)
        check("after del tx3 (was tx4) balance", t['balance'], 122500)

    rc = lib.FLGetTransaction(4, ctypes.addressof(buf))
    if rc == 0:
        t = parse_trans(buf.raw)
        check("after del tx4 (was tx5) balance", t['balance'], 119300)

    # Invalid delete
    rc = lib.FLDeleteTransaction(99)
    check("FLDeleteTransaction(99) invalid", rc, -1)

    # ---- Recalc Balances ----
    print("\n=== Recalc Balances ===")
    final_bal = lib.FLRecalcBalances()
    check("FLRecalcBalances()", final_bal, 119300)

    # ---- Close ----
    print("\n=== Close ===")
    rc = lib.FLClose()
    check("FLClose()", rc, 0)

    # ---- Summary ----
    print(f"\n{'='*40}")
    print(f"Results: {passed} passed, {failed} failed out of {passed + failed} tests")
    if failed > 0:
        sys.exit(1)
    else:
        print("All tests passed!")

if __name__ == "__main__":
    main()
