%  Copyright 2021 Derek Lane
%
%  Contracts for import and review manager, import and load engines,
%  and data access services
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

:- protocol(iimage_import_manager).
:- public([import_legacy_image/2]).
:- end_protocol.


:- protocol(iimage_import_engine).
:- public([import_image/2]).
:- end_protocol.


:- protocol(iprojection_image_resource_access).
:- public([write_projection_image/2,
		   read_projection_image/2]).
:- end_protocol.


:- protocol(ievent_store).
:- public([emit/1, last_if/1]).
:- end_protocol.




