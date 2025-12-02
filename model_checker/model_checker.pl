:- module(model_checker,
          [ valid/1,
            pruned_fork/2,
            model_to_sequence/2,
            analyze_pathways/3 ]).

:- use_module(library(clpfd)).

%!  valid(+Sequence_Or_Fork) is det
%
%   true if the structure is valid

valid(sequence(Statement_List)) :-
    maplist(valid_statement, Statement_List).

valid(fork(Sequence_List)) :-
    maplist(valid, Sequence_List).

%!  valid_statement(+Expression_To_Resource) is det
%
%   true if the expression is valid

valid_statement(Expression -> Resource_Key) :-
    functor(Expression,_,_),
    atom(Resource_Key), !.

valid_statement(Resource_Key -> Variable) :-
    atom(Resource_Key),
    var(Variable), !.


%!  model_to_sequence(-Fork,+Sequence) is det
%
%   sequentializes the fork

model_to_sequence(fork(Sequence_List),
                 sequence([])) :-

    % if the prune leaves us with nothing, then we are done
    pruned_fork(fork(Sequence_List), fork([])).

model_to_sequence(fork(Sequence_List),
                 sequence([Branch_N_Statement_0 | Statement_Rest])) :-

    % extract the Nth sequence from the list, and bind  first | rest
    nth0(N, Sequence_List,
         sequence([Branch_N_Statement_0 |
                   Branch_N_Statement_Rest]),
         Sequence_Rest),

    % reconstitute sequence list with out the first statement
    nth0(N, Next_Sequence_List,
         sequence(Branch_N_Statement_Rest),
         Sequence_Rest),

    % ensure we remove empty sequences
    pruned_fork(fork(Next_Sequence_List),
               fork(Pruned_Next_Sequence_List)),

    % recurse on remaining forks
    model_to_sequence(fork(Pruned_Next_Sequence_List),
                     sequence(Statement_Rest)).

%!  pruned_fork(-Fork,+PrunedFork) is det
%
%   excludes empty sequences from the fork

pruned_fork(fork(Sequence_List), fork(Pruned_Sequence_List)) :-
    exclude(empty_sequence, Sequence_List, Pruned_Sequence_List).

empty_sequence(sequence([])).


% ! run_statement(-Statement,-Resource_Dict_0,+Resource_Dict_Next) det
%
% single statement is either a capture or update

run_statement(Lhs -> Rhs, Resource_Dict_0, Resource_Dict_Next) :-

    is_dict(Resource_Dict_0),

    ( 
        % capture statement will have a Variable as target
        var(Rhs), !,
        get_dict(Lhs, Resource_Dict_0, Rhs),
        Resource_Dict_Next = Resource_Dict_0 
    ) ;
    (
        % assign statement will have a Resource_Key as a target
        atom(Rhs), !,
        get_dict(Rhs, Resource_Dict_0, _,
            Resource_Dict_Next, Lhs) 
    ).

% ! analyze_pathways(-Model, +Resource_Dicts_to_Final, +Sequence_List)
% is det
%
%   sequentializes the model and runs the sequences, then groups
%   by the resulting resource dicts

analyze_pathways(Model,
                 Resource_Dict_0
                 -> For_Resource_Dict,
                 Sequence_List) :-

    findall([Resource_Dict_For_Solution,
             Statement_List],
           (
                model_to_sequence(Model,
                                  sequence(Statement_List)),

                foldl(run_statement,
                      Statement_List,
                      Resource_Dict_0,
                      Resource_Dict_For_Solution)
            ),
            Resource_Sequence_Solution_Pairs),

    transpose(Resource_Sequence_Solution_Pairs,
              [All_Resource_Dicts, _]),
    list_to_set(All_Resource_Dicts,
                Distinct_Resource_Dicts),
    member(For_Resource_Dict, Distinct_Resource_Dicts),

    findall(Sequence_For_Resource_Dict,
            member([For_Resource_Dict,
                    Sequence_For_Resource_Dict],
                   Resource_Sequence_Solution_Pairs),
            Sequence_List).


:- begin_tests(model_checker).

test(valid) :-
    valid(sequence([])),
    valid(sequence([
        2 -> 'A'
    ])).

test(valid, [fail]) :-
    valid(sequence([
        3 -> B_init,    % BAD: can't assign constant to variable
        B_init -> 'A'
    ])).

test(valid) :-
    valid(fork([])),

    valid(
        fork([
            sequence([
            ])
        ])).

test(valid) :-
    valid(
        fork([
            % branch 1
            sequence([
                2 -> 'A',
                'B' -> B_in_1,
                B_in_1 * 2 -> 'A'
            ]),

            % branch 2
            sequence([])
        ])).

test(valid) :-
    valid(
        fork([
            % branch 1
            sequence([
                'A' -> A_in_1,
                A_in_1 * 2 -> 'A'
            ]),

            % branch 2
            sequence([
                'A' -> A_in_2,
                'B' -> B_in_2,
                A_in_2 + B_in_2 -> 'B'
            ])
        ])).

test(pruned_fork) :-
    pruned_fork(
        fork([
            sequence([]),
            sequence([
                2 -> 'A'
            ])
        ]),
        fork([
            sequence([
                2 -> 'A'
            ])
        ])).

test(model_to_sequence) :-
    model_to_sequence(
        fork([
            sequence([]),
            sequence([]),
            sequence([])
        ]),
        sequence([
        ])),
    !.

test(model_to_sequence) :-
    model_to_sequence(
        fork([
            sequence([
                'A' -> A_init,
                A_init * 2 -> 'A'
            ])
        ]),
        sequence([
            'A' -> A_init,
            A_init * 2 -> 'A'
        ])),
    !.


test(model_to_sequence) :-

    model_to_sequence(
        fork([
            % branch 1
            sequence([
                'A' -> A_in_1,
                A_in_1 * 2 -> 'A'
            ]),

            % branch 2
            sequence([
                'A' -> A_in_2,
                'B' -> B_in_2,
                A_in_2 + B_in_2 -> 'B'
            ])
        ]),
        sequence([
            'A' -> A_in_1,
            A_in_1 * 2 -> 'A',
            'A' -> A_in_2,
            'B' -> B_in_2,
            A_in_2 + B_in_2 -> 'B'
        ])),
    !.

test(run_statement) :-

    Resources = dict{ 'A':2, 'X':13 },

    % capture statement
    run_statement('X' -> X_Value,
            Resources, Resources),

    X_Value = 13.

test(run_statement) :-

    Resources = dict{ 'A':2, 'X':13 },

    % capture statement
    run_statement('X' -> X_Value,
        Resources, Resources),

    % assign statement
    run_statement(2 * X_Value -> 'X',
        Resources, Resources_Final),

    nl, nl,
    write_term('Final Resources after assign: ',
               []), nl,
    print_term(Resources_Final,
               [write_options([nl(true)])]), nl,

    % capture statement
    run_statement('X' -> X_Value_Final,
        Resources_Final, Resources_Final),

    X_Value_Final = 2 * 13.

%!
%  int startHours = 5;
%  int endHours = -6;
%
%  void UpdateStartAndEnd(int withOffset)
%  {
%       Task.Run(() =>
%                  startHours = startHours + withOffset);
%       UpdateEnd(withSum * 2)
%  }
%
%  void UpdateEnd(int withOffset)
%  {
%       endHours = endHours + startHours + withSum;
%  }
%
%  UpdateStartAndEnd(4);

test(analyze_pathways) :-

    _withOffset = 4,

    Model = fork([
                % branch 1
                sequence([
                    startHours -> _startHours_in_1,
                    _startHours_in_1 + _withOffset -> startHours
                ]),

                % branch 2
                sequence([
                    endHours -> _endHours_in_2,
                    startHours -> _startHours_in_2,
                    _endHours_in_2 + _startHours_in_2
                        + _withOffset * 2 -> endHours
                ])
            ]),

    nl, nl,
    write_term('==== Model ====', []), nl,
    print_term(Model, []), nl,

    Resources_0 = dict{ startHours: 5, endHours: -6 },
    findall(_,
            ( analyze_pathways(Model,
                               Resources_0
                               -> Resources_Final,
                               Sequence_List),

              nl, nl,
              write_term('==== Variation ====',
                         [nl(true)]), nl,

              write_term('Final Resource Values:',
                         []), nl,

              print_term(Resources_Final,
                         []), nl,

              write_term('Sequence Variations:',
                         []), nl,
              print_term(Sequence_List,
                         []), nl
            ), _).

:- end_tests(model_checker).


:- run_tests.











