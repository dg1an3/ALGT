
%!  testing import of CBCT
import_cbct_sro_ok(Reference,
                   Sro,
                   Cbct) :-

    test_patient(Patient),

    generate_ct_image(_),
    generate_structure_set(_),
    generate_rt_plan(_),

    export_dicom(Ct,
                 Structure_Set,
                 Rt_Plan),

    dicom_scp_log_ok(_),
    wqe_log_ok(_),

    database_rtplan_check_ok(_),
    database_reference_structure_set_ok(_),

    database_image_check_ok(_),
    database_offset_check_ok(_),
    bds_check_ok(_).






%!  testing portal
import_portal_sro_ok(Reference,
                     Sro,
                     Portal_Image) :-

    test_patient(Patient),

    generate_rt_plan(_),
    generate_portal_image(_),

    export_dicom(Rt_Plan,
                 Portal_Image),

    dicom_scp_log_ok(_),

    wcf_manager_log_ok('ImageImport2dManager'),
    wcf_engine_log_ok('ImageAssociationEngine'),
    wcf_data_access_log_ok(_),

    database_check_ok(_),

    couchdb_check_ok(_).

wcf_manager_log_ok(_) :-
    nettcp_manager_service
    ;
    (   discovery_manager
    ;   tcp_port_sharing
    ;   database_record
    );
    cancel_transaction_msdtc
    ;
    client_side_cached_manager_service
    ;
    inproc_manager_service.

wcf_engine_log_ok(_) :-
    unity_injection_component_service
    ;
    no_msdtc_component_service
    ;
    netnamedpipe_component_service.

health_monitor_from_cache.

nlog_logger.







