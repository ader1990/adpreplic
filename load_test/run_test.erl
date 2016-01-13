-module(run_test).
-export([
    test_ping/1,
    test_read/1
    ]).

%% Exported methods

test_ping(FilePath) ->
    DCs = get_dcs("adpreplic-nodes.txt"),
    _LoadTestValue = get_load_test_value(FilePath),
    {ok, Value} = run_on_dcs(DCs,
        fun(X) -> get_ping_from_dc(X) end),
    io:fwrite(Value).

test_read(FilePath) ->
    DCs = get_dcs("adpreplic-nodes.txt"),
    _LoadTestValue = get_load_test_value(FilePath),
    {ok, Value} = run_on_dcs(DCs,
        fun(X) -> get_read_value_from_dc(X) end),
    io:fwrite(Value).

%% Test methods applied to each DC

get_ping_from_dc(DC) ->
    Result = net_adm:ping(DC),
    case Result of
        pong -> {ok, pong};
        {error, _Info}   -> {ok, _Info}
    end
    .

get_read_value_from_dc(DC) ->
    Result = rpc:call(DC,adpreplic,read,["1"]),
    case Result of
        {error, _Info}   -> {ok, _Info};
        _Value -> {ok, _Value}
    end
    .

%% Helper methods
for_each_line_in_file(Name, Proc, Accum0) ->
    {ok, Device} = file:open(Name, [read]),
    for_each_line(Device, Proc, Accum0).

for_each_line(Device, Proc, Accum) ->
    case io:get_line(Device, "") of
        eof  -> file:close(Device), Accum;
        Line -> NewAccum = Proc(Line, Accum),
                for_each_line(Device, Proc, NewAccum)
    end.

run_on_dcs([], _Proc) ->
    {ok, "Finished"};

run_on_dcs([H | T], Proc) ->
    case Proc(H) of
        {ok, Value}  ->
            io:fwrite("Sucess from DC:~p with result: ~p\n", [H, Value]),
            run_on_dcs(T, Proc);
        {error, _Info}   -> {ok, _Info}
    end
    .

trim_add_to_list(X, Y) ->
    Y ++ [erlang:list_to_atom(re:replace(X,"\n","",[{return,list}]))].

get_dcs(FilePath) ->
    for_each_line_in_file(FilePath,
        fun (X,Y) -> trim_add_to_list(X, Y) end,
        []).

get_load_test_value(FilePath) ->
    {ok, Device} = file:open(FilePath, [read]),
    Line = io:get_line(Device, ""),
    file:close(FilePath),
    Line.


