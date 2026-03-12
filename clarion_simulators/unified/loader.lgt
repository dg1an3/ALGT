%============================================================
% loader.lgt - Logtalk Backends Loader
%
% Load with: logtalk_load('clarion_simulators/unified/loader').
%============================================================

:- initialization(
    logtalk_load([
        % Protocols (interfaces)
        storage_protocol,
        ui_protocol,

        % Storage backends
        storage_memory,
        storage_csv,
        storage_odbc,
        storage_dispatcher,

        % UI backends
        ui_simulation,
        ui_dispatcher
    ])).
