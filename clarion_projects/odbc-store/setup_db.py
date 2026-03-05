"""
One-time setup for OdbcStore: creates database, DSN, and table.

Usage:
    cd odbc-store
    ~/.pyenv/pyenv-win/versions/3.11.9-win32/python.exe setup_db.py
"""

import ctypes
import ctypes.wintypes

import pyodbc

CONN_STR_MASTER = (
    "DRIVER={SQL Server Native Client 11.0};"
    "Server=localhost;"
    "Database=master;"
    "Trusted_Connection=yes;"
)
CONN_STR_DB = (
    "DRIVER={SQL Server Native Client 11.0};"
    "Server=localhost;"
    "Database=OdbcDemo;"
    "Trusted_Connection=yes;"
)


def create_database():
    """Create OdbcDemo database if it doesn't exist."""
    conn = pyodbc.connect(CONN_STR_MASTER, autocommit=True)
    cursor = conn.cursor()
    cursor.execute("SELECT name FROM sys.databases WHERE name='OdbcDemo'")
    if cursor.fetchone():
        print("  Database OdbcDemo already exists")
    else:
        cursor.execute("CREATE DATABASE OdbcDemo")
        print("  Created database OdbcDemo")
    conn.close()


def create_dsn():
    """Create a 32-bit User DSN 'OdbcDemo' pointing to SQL Server."""
    ODBC_ADD_DSN = 1
    odbccp32 = ctypes.windll.LoadLibrary("odbccp32.dll")
    func = odbccp32.SQLConfigDataSourceW
    func.argtypes = [
        ctypes.wintypes.HWND, ctypes.c_ushort,
        ctypes.c_wchar_p, ctypes.c_wchar_p,
    ]
    func.restype = ctypes.wintypes.BOOL

    attrs = (
        "DSN=OdbcDemo\x00"
        "Description=OdbcDemo SQL Server\x00"
        "Server=localhost\x00"
        "Database=OdbcDemo\x00"
        "Trusted_Connection=Yes\x00\x00"
    )
    buf = ctypes.create_unicode_buffer(attrs)
    result = func(None, ODBC_ADD_DSN, "SQL Server Native Client 11.0", buf)
    if result:
        print("  Created/updated User DSN 'OdbcDemo'")
    else:
        print("  WARNING: Failed to create DSN (may already exist)")


def create_table():
    """Create SensorReadings table if it doesn't exist."""
    conn = pyodbc.connect(CONN_STR_DB, autocommit=True)
    cursor = conn.cursor()
    # Drop and recreate to ensure correct schema with primary key
    cursor.execute(
        "IF OBJECT_ID('SensorReadings','U') IS NOT NULL DROP TABLE SensorReadings"
    )
    cursor.execute("""
        CREATE TABLE SensorReadings (
            ReadingID INT PRIMARY KEY,
            SensorID INT,
            Value INT,
            Weight INT,
            Timestamp INT
        )
    """)
    # Check if table exists now
    cursor.execute("SELECT COUNT(*) FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME='SensorReadings'")
    if cursor.fetchone()[0]:
        print("  Table SensorReadings ready")
    else:
        print("  WARNING: Could not create table")
    conn.close()


def main():
    print("Setting up OdbcStore...")
    print("1. Database:")
    create_database()
    print("2. ODBC DSN:")
    create_dsn()
    print("3. Table:")
    create_table()
    print("Done!")


if __name__ == "__main__":
    main()
