%============================================================
% storage_protocol.lgt - Storage Backend Protocol
%
% Defines the interface all storage backends must implement.
% Each predicate operates on file_state/8 tuples.
%============================================================

:- protocol(istorage_backend).

    :- public([
        open/2,       % (FSIn, FSOut)
        open/3,       % (FileName, FSIn, FSOut) - for file-backed stores
        close/2,      % (FSIn, FSOut)
        create/2,     % (FSIn, FSOut)
        add/2,        % (FSIn, FSOut)
        get/3,        % (KeyInfo, FSIn, FSOut)
        put/2,        % (FSIn, FSOut)
        delete/2,     % (FSIn, FSOut)
        next/2,       % (FSIn, FSOut)
        set/2,        % (FSIn, FSOut)
        records/2,    % (FS, Count)
        empty/2,      % (FSIn, FSOut)
        clear/2       % (FSIn, FSOut)
    ]).

:- end_protocol.
