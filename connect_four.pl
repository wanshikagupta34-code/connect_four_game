:- use_module(library(lists)).

:- dynamic search_depth/1.

rows(6).
cols(7).
win_length(4).
search_depth(5).
empty_board(Board) :-
    rows(R), cols(C),
    length(Row, C),
    maplist(=(empty), Row),
    length(Board, R),
    maplist(=(Row), Board).

get_cell(Board, R, C, Cell) :-
    nth0(R, Board, Row),
    nth0(C, Row, Cell).

set_cell(Board, R, C, Value, NewBoard) :-
    nth0(R, Board, OldRow, RestRows),
    nth0(C, OldRow, _, RestCells),
    nth0(C, NewRow, Value, RestCells),
    nth0(R, NewBoard, NewRow, RestRows).
drop_row(Board, Col, Row) :-
    rows(MaxRow),
    Bottom is MaxRow - 1,
    drop_row_helper(Board, Col, Bottom, Row).

drop_row_helper(Board, Col, R, R) :-
    R >= 0,
    get_cell(Board, R, Col, empty), !.
drop_row_helper(Board, Col, R, Row) :-
    R >= 0,
    R1 is R - 1,
    drop_row_helper(Board, Col, R1, Row).

valid_move(Board, Col) :-
    cols(MaxCol),
    Col >= 0, Col < MaxCol,
    get_cell(Board, 0, Col, empty).
valid_moves(Board, Cols) :-
    cols(MaxCol),
    MaxColIdx is MaxCol - 1,
    findall(C,
        (between(0, MaxColIdx, C), valid_move(Board, C)),
        Cols).
make_move(Board, Col, Player, NewBoard) :-
    drop_row(Board, Col, Row),
    set_cell(Board, Row, Col, Player, NewBoard).
four_in_a_row(Board, Player) :-
    win_length(WL),
    rows(Rows), cols(Cols),
    RL is Rows - 1, CL is Cols - 1,
    (   horizontal_win(Board, Player, WL, RL, CL)
    ;   vertical_win(Board, Player, WL, RL, CL)
    ;   diag_down_win(Board, Player, WL, RL, CL)
    ;   diag_up_win(Board, Player, WL, RL, CL)
    ).
horizontal_win(Board, Player, WL, _, CL) :-
    rows(Rows), RL is Rows - 1,
    between(0, RL, R),
    EndC is CL - WL + 2,
    between(0, EndC, C),
    EndC2 is C + WL - 1,
    check_window_h(Board, Player, R, C, EndC2).

check_window_h(_, _, _, C, EndC) :-
    C > EndC, !.
check_window_h(Board, Player, R, C, EndC) :-
    get_cell(Board, R, C, Player),
    C1 is C + 1,
    check_window_h(Board, Player, R, C1, EndC).
vertical_win(Board, Player, WL, RL, _) :-
    EndR is RL - WL + 2,
    cols(Cols), CL is Cols - 1,
    between(0, EndR, R),
    between(0, CL, C),
    EndR2 is R + WL - 1,
    check_window_v(Board, Player, R, C, EndR2).

check_window_v(_, _, R, _, EndR) :-
    R > EndR, !.
check_window_v(Board, Player, R, C, EndR) :-
    get_cell(Board, R, C, Player),
    R1 is R + 1,
    check_window_v(Board, Player, R1, C, EndR).
diag_down_win(Board, Player, WL, RL, CL) :-
    EndR is RL - WL + 2,
    EndC is CL - WL + 2,
    between(0, EndR, R),
    between(0, EndC, C),
    WL1 is WL - 1,
    check_diag_down(Board, Player, R, C, WL1).

check_diag_down(_, _, _, _, -1) :- !.
check_diag_down(Board, Player, R, C, Steps) :-
    get_cell(Board, R, C, Player),
    R1 is R + 1, C1 is C + 1,
    Steps1 is Steps - 1,
    check_diag_down(Board, Player, R1, C1, Steps1).
diag_up_win(Board, Player, WL, RL, CL) :-
    StartR is WL - 1,
    EndC is CL - WL + 2,
    between(StartR, RL, R),
    between(0, EndC, C),
    WL1 is WL - 1,
    check_diag_up(Board, Player, R, C, WL1).

check_diag_up(_, _, _, _, -1) :- !.
check_diag_up(Board, Player, R, C, Steps) :-
    get_cell(Board, R, C, Player),
    R1 is R - 1, C1 is C + 1,
    Steps1 is Steps - 1,
    check_diag_up(Board, Player, R1, C1, Steps1).

board_full(Board) :-
    valid_moves(Board, []).

terminal_state(Board, win(x)) :- four_in_a_row(Board, x), !.
terminal_state(Board, win(o)) :- four_in_a_row(Board, o), !.
terminal_state(Board, draw)   :- board_full(Board), !.
terminal_state(_, continue).
score_window(Window, Player, Score) :-
    opponent(Player, Opp),
    count_in_list(Player, Window, PC),
    count_in_list(empty,  Window, EC),
    count_in_list(Opp,    Window, OC),
    window_score(PC, EC, OC, Score).

window_score(4, _, _, 100)  :- !.
window_score(3, 1, 0, 5)    :- !.
window_score(2, 2, 0, 2)    :- !.
window_score(_, _, 3, -4)   :- !.
window_score(_, _, 4, -100) :- !.
window_score(_, _, _, 0).

count_in_list(_, [], 0).
count_in_list(X, [X|T], N) :- !, count_in_list(X, T, N1), N is N1 + 1.
count_in_list(X, [_|T], N) :- count_in_list(X, T, N).
heuristic(Board, Player, Score) :-
    center_score(Board, Player, CS),
    all_window_scores(Board, Player, WS),
    Score is CS + WS.
center_score(Board, Player, Score) :-
    cols(Cols), CenterCol is Cols // 2,
    rows(Rows), RL is Rows - 1,
    findall(1,
        (between(0, RL, R), get_cell(Board, R, CenterCol, Player)),
        Matches),
    length(Matches, Count),
    Score is Count * 3.
all_window_scores(Board, Player, Total) :-
    rows(Rows), cols(Cols),
    RL is Rows - 1, CL is Cols - 1,
    findall(S, window_score_on_board(Board, Player, RL, CL, S), Scores),
    sumlist(Scores, Total).

window_score_on_board(Board, Player, RL, CL, S) :-
    win_length(WL), WL1 is WL - 1,
    between(0, RL, R),
    EndC is CL - WL1,
    between(0, EndC, C),
    EndC2 is C + WL1,
    collect_h(Board, R, C, EndC2, Win),
    score_window(Win, Player, S).

window_score_on_board(Board, Player, RL, CL, S) :-
    win_length(WL), WL1 is WL - 1,
    EndR is RL - WL1,
    between(0, EndR, R),
    between(0, CL, C),
    EndR2 is R + WL1,
    collect_v(Board, R, C, EndR2, Win),
    score_window(Win, Player, S).

window_score_on_board(Board, Player, RL, CL, S) :-
    win_length(WL), WL1 is WL - 1,
    EndR is RL - WL1,
    EndC is CL - WL1,
    between(0, EndR, R),
    between(0, EndC, C),
    collect_diag_down(Board, R, C, WL1, Win),
    score_window(Win, Player, S).

window_score_on_board(Board, Player, RL, CL, S) :-
    win_length(WL), WL1 is WL - 1,
    StartR is WL1,
    EndC is CL - WL1,
    between(StartR, RL, R),
    between(0, EndC, C),
    collect_diag_up(Board, R, C, WL1, Win),
    score_window(Win, Player, S).

collect_h(_, _, C, EndC, []) :- C > EndC, !.
collect_h(Board, R, C, EndC, [Cell|Rest]) :-
    get_cell(Board, R, C, Cell),
    C1 is C + 1,
    collect_h(Board, R, C1, EndC, Rest).

collect_v(_, R, _, EndR, []) :- R > EndR, !.
collect_v(Board, R, C, EndR, [Cell|Rest]) :-
    get_cell(Board, R, C, Cell),
    R1 is R + 1,
    collect_v(Board, R1, C, EndR, Rest).

collect_diag_down(Board, R, C, 0, [Cell]) :- !, get_cell(Board, R, C, Cell).
collect_diag_down(Board, R, C, Steps, [Cell|Rest]) :-
    get_cell(Board, R, C, Cell),
    R1 is R + 1, C1 is C + 1, Steps1 is Steps - 1,
    collect_diag_down(Board, R1, C1, Steps1, Rest).

collect_diag_up(Board, R, C, 0, [Cell]) :- !, get_cell(Board, R, C, Cell).
collect_diag_up(Board, R, C, Steps, [Cell|Rest]) :-
    get_cell(Board, R, C, Cell),
    R1 is R - 1, C1 is C + 1, Steps1 is Steps - 1,
    collect_diag_up(Board, R1, C1, Steps1, Rest).

sumlist([], 0).
sumlist([H|T], S) :- sumlist(T, S1), S is S1 + H.
opponent(x, o).
opponent(o, x).
is_maximizer(o).

minimax(Board, 0, _, _, _Player, none, Score) :-
    !,
    heuristic(Board, o, Score).

minimax(Board, _, _, _, _Player, none, Score) :-
    terminal_state(Board, win(o)), !,
    Score = 100000.

minimax(Board, _, _, _, _Player, none, Score) :-
    terminal_state(Board, win(x)), !,
    Score = -100000.

minimax(Board, _, _, _, _Player, none, 0) :-
    terminal_state(Board, draw), !.

minimax(Board, Depth, Alpha, Beta, Player, BestCol, BestScore) :-
    valid_moves(Board, Moves),
    Moves \= [],
    is_maximizer(Player), !,
    Depth1 is Depth - 1,
    opponent(Player, Opp),
    best_max(Board, Depth1, Alpha, Beta, Opp, Moves, -1000000, none, BestScore, BestCol).

minimax(Board, Depth, Alpha, Beta, Player, BestCol, BestScore) :-
    valid_moves(Board, Moves),
    Moves \= [],
    Depth1 is Depth - 1,
    opponent(Player, Opp),
    best_min(Board, Depth1, Alpha, Beta, Opp, Moves, 1000000, none, BestScore, BestCol).
best_max(_, _, _, _, _, [], BestScore, BestCol, BestScore, BestCol).
best_max(Board, Depth, Alpha, Beta, Opp, [Col|Rest], CurBest, CurCol, BestScore, BestCol) :-
    make_move(Board, Col, o, NewBoard),
    minimax(NewBoard, Depth, Alpha, Beta, Opp, _, Score),
    (   Score > CurBest
    ->  NewBest = Score, NewCol = Col
    ;   NewBest = CurBest, NewCol = CurCol
    ),
    NewAlpha is max(Alpha, NewBest),
    (   NewAlpha >= Beta
    ->  BestScore = NewBest, BestCol = NewCol
    ;   best_max(Board, Depth, NewAlpha, Beta, Opp, Rest, NewBest, NewCol, BestScore, BestCol)
    ).

best_min(_, _, _, _, _, [], BestScore, BestCol, BestScore, BestCol).
best_min(Board, Depth, Alpha, Beta, Opp, [Col|Rest], CurBest, CurCol, BestScore, BestCol) :-
    make_move(Board, Col, x, NewBoard),
    minimax(NewBoard, Depth, Alpha, Beta, Opp, _, Score),
    (   Score < CurBest
    ->  NewBest = Score, NewCol = Col
    ;   NewBest = CurBest, NewCol = CurCol
    ),
    NewBeta is min(Beta, NewBest),
    (   Alpha >= NewBeta
    ->  BestScore = NewBest, BestCol = NewCol
    ;   best_min(Board, Depth, Alpha, NewBeta, Opp, Rest, NewBest, NewCol, BestScore, BestCol)
    ).
ai_move(Board, Col) :-
    search_depth(Depth),
    minimax(Board, Depth, -1000000, 1000000, o, Col, Score),
    format("  [AI] chose column ~w (score: ~w)~n", [Col, Score]).



print_board(Board) :-
    nl,
    print_col_numbers,
    rows(Rows), RL is Rows - 1,
    forall(between(0, RL, R),
        (nth0(R, Board, Row), print_row(Row))),
    print_separator,
    nl.

print_col_numbers :-
    cols(Cols), CL is Cols - 1,
    write('  '),
    forall(between(0, CL, C), (format(" ~w ", [C]))),
    nl,
    print_separator.

print_separator :-
    cols(Cols), CL is Cols - 1,
    write('  '),
    forall(between(0, CL, _), write('---')),
    nl.

print_row(Row) :-
    write('| '),
    forall(member(Cell, Row), (cell_char(Cell, Ch), format("~w  ", [Ch]))),
    write('|'), nl.

cell_char(empty, '.').
cell_char(x, 'X').
cell_char(o, 'O').



play :-
    nl,
    write('========================================'), nl,
    write('   CONNECT FOUR - Prolog Edition'),        nl,
    write('   You = X   |   AI = O'),                nl,
    write('========================================'), nl,
    empty_board(Board),
    print_board(Board),
    game_loop(Board, x).
game_loop(Board, _) :-
    terminal_state(Board, win(x)), !,
    write('>>> You win! Congratulations! <<<'), nl.

game_loop(Board, _) :-
    terminal_state(Board, win(o)), !,
    write('>>> AI wins! Better luck next time. <<<'), nl.

game_loop(Board, _) :-
    terminal_state(Board, draw), !,
    write(">>> It's a draw! <<<"), nl.

game_loop(Board, x) :-
    write('Your turn (X). Enter column (0-6): '),
    read(Col),
    (   valid_move(Board, Col)
    ->  make_move(Board, Col, x, NewBoard),
        print_board(NewBoard),
        game_loop(NewBoard, o)
    ;   write('Invalid move. Try again.'), nl,
        game_loop(Board, x)
    ).

game_loop(Board, o) :-
    write('AI is thinking...'), nl,
    ai_move(Board, Col),
    make_move(Board, Col, o, NewBoard),
    print_board(NewBoard),
    game_loop(NewBoard, x).


test_ai(Depth, Col) :-
    retractall(search_depth(_)),
    assert(search_depth(Depth)),
    empty_board(Board),
    minimax(Board, Depth, -1000000, 1000000, o, Col, Score),
    format("Depth ~w: AI picks column ~w (score: ~w)~n", [Depth, Col, Score]).
test_win_detection :-
    empty_board(B0),
    make_move(B0, 0, x, B1), make_move(B1, 1, x, B2),
    make_move(B2, 2, x, B3), make_move(B3, 3, x, B4),
    (four_in_a_row(B4, x) -> write('Win detection: PASS') ; write('Win detection: FAIL')), nl.


