%% Copyright 2021 Derek Lane
%%
%% manager for analyzing systematic trends in daily offsets

:- object(trending_manager(_RegistrationDataAccess)).

	offset_series_for_site(request(Site_Id), response(Offset_Series)) :-
		this(RegistrationDataAccess).

:- end_object.
