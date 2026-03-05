"""Tests for the DiagnosisStore Clarion DLL via Python wrapper."""

from datetime import date
from diagnosis_store import DiagnosisStore, DiagnosisStatus, DiagnosisStoreError
import os
import glob

def cleanup_tps():
    """Remove any leftover TPS files from previous runs."""
    for f in glob.glob('Diagnosis.*'):
        os.remove(f)
    for f in glob.glob('bin/Diagnosis.*'):
        os.remove(f)

def test_create_and_get():
    print("Test: Create and Get...", end=" ")
    with DiagnosisStore() as store:
        rid = store.create(
            patient_id=1001,
            icd_code='C34.1',
            description='Non-small cell lung cancer, right upper lobe',
            t_stage='T2',
            n_stage='N1',
            m_stage='M0',
            overall_stage='IIB',
            diag_date=date(2025, 3, 15),
        )
        assert rid > 0, f"Expected positive record ID, got {rid}"

        dx = store.get(rid)
        assert dx.record_id == rid
        assert dx.patient_id == 1001
        assert dx.icd_code == 'C34.1'
        assert dx.description == 'Non-small cell lung cancer, right upper lobe'
        assert dx.t_stage == 'T2'
        assert dx.n_stage == 'N1'
        assert dx.m_stage == 'M0'
        assert dx.overall_stage == 'IIB'
        assert dx.diag_date == date(2025, 3, 15)
        assert dx.status == DiagnosisStatus.DRAFT
        assert dx.approved_by == ''
        assert dx.approved_date is None
    print("PASSED")

def test_update():
    print("Test: Update...", end=" ")
    with DiagnosisStore() as store:
        rid = store.create(
            patient_id=1002,
            icd_code='C50.9',
            description='Breast cancer, unspecified',
            t_stage='T1',
            n_stage='N0',
            m_stage='M0',
            overall_stage='IA',
        )
        store.update(rid, description='Breast cancer, left side', t_stage='T1c')
        dx = store.get(rid)
        assert dx.description == 'Breast cancer, left side'
        assert dx.t_stage == 'T1c'
        assert dx.icd_code == 'C50.9'  # unchanged
    print("PASSED")

def test_approve():
    print("Test: Approve...", end=" ")
    with DiagnosisStore() as store:
        rid = store.create(
            patient_id=1003,
            icd_code='C61',
            description='Prostate cancer',
            t_stage='T2a',
            n_stage='N0',
            m_stage='M0',
            overall_stage='IIA',
        )
        store.approve(rid, 'Dr. Smith')
        dx = store.get(rid)
        assert dx.status == DiagnosisStatus.APPROVED
        assert dx.approved_by == 'Dr. Smith'
        assert dx.approved_date is not None
    print("PASSED")

def test_update_after_approve_fails():
    print("Test: Update after approve fails...", end=" ")
    with DiagnosisStore() as store:
        rid = store.create(
            patient_id=1004,
            icd_code='C18.0',
            description='Colon cancer',
        )
        store.approve(rid, 'Dr. Jones')
        try:
            store.update(rid, description='Updated description')
            assert False, "Should have raised DiagnosisStoreError"
        except DiagnosisStoreError as e:
            assert e.code == -3
    print("PASSED")

def test_delete():
    print("Test: Delete (soft)...", end=" ")
    with DiagnosisStore() as store:
        rid = store.create(
            patient_id=1005,
            icd_code='C43.5',
            description='Melanoma of trunk',
        )
        store.delete(rid)
        dx = store.get(rid)
        assert dx.status == DiagnosisStatus.DELETED
    print("PASSED")

def test_get_nonexistent():
    print("Test: Get nonexistent record...", end=" ")
    with DiagnosisStore() as store:
        try:
            store.get(99999)
            assert False, "Should have raised DiagnosisStoreError"
        except DiagnosisStoreError as e:
            assert e.code == -1
    print("PASSED")

def test_list_by_patient():
    print("Test: List by patient...", end=" ")
    with DiagnosisStore() as store:
        pid = 2000
        store.create(patient_id=pid, icd_code='C34.1', description='Lung primary')
        store.create(patient_id=pid, icd_code='C79.3', description='Brain met')
        store.create(patient_id=9999, icd_code='C61', description='Other patient')

        results = store.list_by_patient(pid)
        assert len(results) == 2, f"Expected 2 results, got {len(results)}"
        assert all(r.patient_id == pid for r in results)
        codes = {r.icd_code for r in results}
        assert 'C34.1' in codes
        assert 'C79.3' in codes
    print("PASSED")

def test_persistence_across_sessions():
    print("Test: Persistence across sessions...", end=" ")
    pid = 3000
    # Session 1: create a record
    with DiagnosisStore() as store:
        rid = store.create(patient_id=pid, icd_code='C71.1', description='Brain tumor')

    # Session 2: read it back
    with DiagnosisStore() as store:
        dx = store.get(rid)
        assert dx.icd_code == 'C71.1'
        assert dx.patient_id == pid
    print("PASSED")


if __name__ == '__main__':
    # Change to script directory so TPS files are created there
    os.chdir(os.path.dirname(os.path.abspath(__file__)))
    cleanup_tps()

    test_create_and_get()
    test_update()
    test_approve()
    test_update_after_approve_fails()
    test_delete()
    test_get_nonexistent()
    test_list_by_patient()
    test_persistence_across_sessions()

    cleanup_tps()
    print("\nAll tests passed!")
