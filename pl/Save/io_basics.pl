open_log :-
	open('output/ALGT_LOG.txt', append, Log),
	assert(current_log_stream(Log)).

close_log :-
	current_log_stream(Log),
	close(Log),
	retract(current_log_stream(Log)).


format_log(String, Params) :-
	format(String, Params),
	(   current_log_stream(Log),
	    format(Log, String, Params) ;
	true).

read_string(Label, Var) :-
	format_log('~a: ', Label),
	current_input(InStr),
	read_line_to_codes(InStr, Var),
	current_log_stream(Log),
	format(Log, '~s~n', [Var]).

read_number(Label, Var) :-
	read_string(Label, VarStr),
	number_codes(Var, VarStr).

write_poly_stats(Label, Polys) :-
	length(Polys, PolyCount),
	format_log('    ~a Polygon Count ~a ~n', [Label, PolyCount]),
	findall(VertCount,
		(   member(Poly, Polys),
		    length(Poly, VertCount)
		),
		VertCounts),
	sumlist(VertCounts, TotalVertCount),
	format_log('    ~a Vertex Count ~a ~n', [Label, TotalVertCount]).

write_mesh_stats(Label, Meshes) :-
	length(Meshes, MeshCount),
	format_log('    ~a Mesh Count ~a ~n', [Label, MeshCount]),
	findall(FacetCount,
		(   member(Mesh, Meshes),
		    length(Mesh, FacetCount)
		),
		FacetCounts),
	sumlist(FacetCounts, TotalFacetCount),
	format_log('    ~a Facet Count ~a ~n', [Label, TotalFacetCount]).

       
write_test_time(Label) :-
	get_time(Time),
	convert_time(Time, StrTime),
	format_log('~nTest ~a at: ~s~n', [Label, StrTime]).

skip_sample :-
	flag(sample_rate, SampleRate, SampleRate),
	SampleRate < random(100).














