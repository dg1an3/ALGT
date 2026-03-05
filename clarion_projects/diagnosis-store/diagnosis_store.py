"""Python wrapper for the DiagnosisStore Clarion DLL.

Clarion's *CSTRING parameters with C calling convention pass a hidden
length LONG before the pointer on the stack. The _cstr_args() helper
produces (len, pointer) pairs to match this convention.
"""

import ctypes
import os
from dataclasses import dataclass
from datetime import date, timedelta
from enum import IntEnum
from typing import Optional

# Clarion date epoch: December 28, 1800
_CLARION_EPOCH = date(1800, 12, 28)


def _date_to_clarion(d: date) -> int:
    """Convert a Python date to Clarion date (days since 1800-12-28)."""
    return (d - _CLARION_EPOCH).days


def _clarion_to_date(n: int) -> Optional[date]:
    """Convert a Clarion date to Python date. Returns None if 0."""
    if n == 0:
        return None
    return _CLARION_EPOCH + timedelta(days=n)


def _cstr_args(s: str, bufsize: int) -> tuple:
    """Return (length, c_char_p) pair matching Clarion *CSTRING C convention.

    Clarion passes a hidden LONG length before each *CSTRING pointer.
    bufsize is the CSTRING(n) declared size from the Clarion source.
    """
    buf = ctypes.create_string_buffer(s.encode('ascii'), bufsize)
    return (bufsize, ctypes.cast(buf, ctypes.c_char_p))


class DiagnosisStatus(IntEnum):
    DRAFT = 0
    APPROVED = 1
    DELETED = 2


class _DiagRecord(ctypes.Structure):
    """ctypes struct matching the Clarion DiagBuf GROUP layout."""
    _pack_ = 1
    _fields_ = [
        ('record_id', ctypes.c_long),
        ('patient_id', ctypes.c_long),
        ('icd_code', ctypes.c_char * 12),
        ('description', ctypes.c_char * 256),
        ('t_stage', ctypes.c_char * 8),
        ('n_stage', ctypes.c_char * 8),
        ('m_stage', ctypes.c_char * 8),
        ('overall_stage', ctypes.c_char * 8),
        ('diag_date', ctypes.c_long),
        ('status', ctypes.c_long),
        ('approved_by', ctypes.c_char * 64),
        ('approved_date', ctypes.c_long),
    ]


@dataclass
class Diagnosis:
    """A cancer diagnosis record."""
    record_id: int
    patient_id: int
    icd_code: str
    description: str
    t_stage: str
    n_stage: str
    m_stage: str
    overall_stage: str
    diag_date: Optional[date]
    status: DiagnosisStatus
    approved_by: str
    approved_date: Optional[date]

    @classmethod
    def _from_record(cls, rec: _DiagRecord) -> 'Diagnosis':
        def _cstr(raw: bytes) -> str:
            """Decode a null-terminated CSTRING field."""
            idx = raw.find(b'\x00')
            if idx >= 0:
                raw = raw[:idx]
            return raw.decode('ascii', errors='replace')

        return cls(
            record_id=rec.record_id,
            patient_id=rec.patient_id,
            icd_code=_cstr(bytes(rec.icd_code)),
            description=_cstr(bytes(rec.description)),
            t_stage=_cstr(bytes(rec.t_stage)),
            n_stage=_cstr(bytes(rec.n_stage)),
            m_stage=_cstr(bytes(rec.m_stage)),
            overall_stage=_cstr(bytes(rec.overall_stage)),
            diag_date=_clarion_to_date(rec.diag_date),
            status=DiagnosisStatus(rec.status),
            approved_by=_cstr(bytes(rec.approved_by)),
            approved_date=_clarion_to_date(rec.approved_date),
        )

    def _to_record(self) -> _DiagRecord:
        rec = _DiagRecord()
        rec.record_id = self.record_id
        rec.patient_id = self.patient_id
        rec.icd_code = self.icd_code.encode('ascii')
        rec.description = self.description.encode('ascii')
        rec.t_stage = self.t_stage.encode('ascii')
        rec.n_stage = self.n_stage.encode('ascii')
        rec.m_stage = self.m_stage.encode('ascii')
        rec.overall_stage = self.overall_stage.encode('ascii')
        rec.diag_date = _date_to_clarion(self.diag_date) if self.diag_date else 0
        rec.status = self.status
        rec.approved_by = self.approved_by.encode('ascii')
        rec.approved_date = _date_to_clarion(self.approved_date) if self.approved_date else 0
        return rec


class DiagnosisStoreError(Exception):
    """Error from the DiagnosisStore DLL."""
    _MESSAGES = {
        -1: 'Record not found',
        -2: 'File I/O error',
        -3: 'Invalid operation (record not in Draft status)',
    }

    def __init__(self, code: int):
        self.code = code
        msg = self._MESSAGES.get(code, f'Unknown error ({code})')
        super().__init__(msg)


class DiagnosisStore:
    """Context manager wrapping the DiagnosisStore Clarion DLL.

    Clarion *CSTRING params with C calling convention pass a hidden
    length LONG before each string pointer on the stack. All string
    arguments are sent as (length, pointer) pairs.
    """

    def __init__(self, dll_path: Optional[str] = None):
        if dll_path is None:
            dll_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'bin')
            dll_path = os.path.join(dll_dir, 'DiagnosisStore.dll')
        self._lib = ctypes.CDLL(dll_path)
        self._setup_signatures()

    def _setup_signatures(self):
        lib = self._lib

        lib.DSOpenStore.argtypes = []
        lib.DSOpenStore.restype = ctypes.c_long

        lib.DSCloseStore.argtypes = []
        lib.DSCloseStore.restype = ctypes.c_long

        # *CSTRING params each become (c_long length, c_char_p pointer)
        lib.DSCreateDiagnosis.argtypes = [
            ctypes.c_long,                     # patientID
            ctypes.c_long, ctypes.c_char_p,    # icdCode:   len, ptr
            ctypes.c_long, ctypes.c_char_p,    # desc:      len, ptr
            ctypes.c_long, ctypes.c_char_p,    # tstage:    len, ptr
            ctypes.c_long, ctypes.c_char_p,    # nstage:    len, ptr
            ctypes.c_long, ctypes.c_char_p,    # mstage:    len, ptr
            ctypes.c_long, ctypes.c_char_p,    # ostage:    len, ptr
            ctypes.c_long,                     # diagDate
        ]
        lib.DSCreateDiagnosis.restype = ctypes.c_long

        lib.DSGetDiagnosis.argtypes = [ctypes.c_long, ctypes.c_long]
        lib.DSGetDiagnosis.restype = ctypes.c_long

        lib.DSUpdateDiagnosis.argtypes = [ctypes.c_long, ctypes.c_long]
        lib.DSUpdateDiagnosis.restype = ctypes.c_long

        # *CSTRING approvedBy becomes (c_long length, c_char_p pointer)
        lib.DSApproveDiagnosis.argtypes = [
            ctypes.c_long,                     # id
            ctypes.c_long, ctypes.c_char_p,    # approvedBy: len, ptr
        ]
        lib.DSApproveDiagnosis.restype = ctypes.c_long

        lib.DSDeleteDiagnosis.argtypes = [ctypes.c_long]
        lib.DSDeleteDiagnosis.restype = ctypes.c_long

        lib.DSListByPatient.argtypes = [
            ctypes.c_long,  # patientID
            ctypes.c_long,  # bufPtr
            ctypes.c_long,  # maxCount
            ctypes.c_long,  # outCountPtr
        ]
        lib.DSListByPatient.restype = ctypes.c_long

    def __enter__(self) -> 'DiagnosisStore':
        rc = self._lib.DSOpenStore()
        if rc != 0:
            raise DiagnosisStoreError(rc)
        return self

    def __exit__(self, exc_type, exc_val, exc_tb):
        self._lib.DSCloseStore()
        return False

    def _check(self, rc: int):
        if rc < 0:
            raise DiagnosisStoreError(rc)

    def create(
        self,
        patient_id: int,
        icd_code: str,
        description: str,
        t_stage: str = '',
        n_stage: str = '',
        m_stage: str = '',
        overall_stage: str = '',
        diag_date: Optional[date] = None,
    ) -> int:
        """Create a new diagnosis in Draft status. Returns the record ID."""
        clarion_date = _date_to_clarion(diag_date) if diag_date else 0
        rc = self._lib.DSCreateDiagnosis(
            patient_id,
            *_cstr_args(icd_code, 12),
            *_cstr_args(description, 256),
            *_cstr_args(t_stage, 8),
            *_cstr_args(n_stage, 8),
            *_cstr_args(m_stage, 8),
            *_cstr_args(overall_stage, 8),
            clarion_date,
        )
        if rc < 0:
            raise DiagnosisStoreError(rc)
        return rc  # positive = new RecordID

    def get(self, record_id: int) -> Diagnosis:
        """Retrieve a diagnosis by record ID."""
        rec = _DiagRecord()
        rc = self._lib.DSGetDiagnosis(record_id, ctypes.addressof(rec))
        self._check(rc)
        return Diagnosis._from_record(rec)

    def update(self, record_id: int, **fields) -> None:
        """Update a draft diagnosis. Pass field names as keyword args."""
        current = self.get(record_id)
        for key, value in fields.items():
            if not hasattr(current, key):
                raise ValueError(f'Unknown field: {key}')
            setattr(current, key, value)
        rec = current._to_record()
        rc = self._lib.DSUpdateDiagnosis(record_id, ctypes.addressof(rec))
        self._check(rc)

    def approve(self, record_id: int, approved_by: str) -> None:
        """Approve a draft diagnosis."""
        rc = self._lib.DSApproveDiagnosis(
            record_id,
            *_cstr_args(approved_by, 64),
        )
        self._check(rc)

    def delete(self, record_id: int) -> None:
        """Soft-delete a diagnosis (sets status to Deleted)."""
        rc = self._lib.DSDeleteDiagnosis(record_id)
        self._check(rc)

    def list_by_patient(self, patient_id: int, max_count: int = 100) -> list:
        """List all diagnoses for a patient."""
        buf = (_DiagRecord * max_count)()
        out_count = ctypes.c_long(0)
        rc = self._lib.DSListByPatient(
            patient_id,
            ctypes.addressof(buf),
            max_count,
            ctypes.addressof(out_count),
        )
        self._check(rc)
        return [Diagnosis._from_record(buf[i]) for i in range(out_count.value)]
