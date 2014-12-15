%% -------------------------------------------------------------------
%%
%% Copyright (c) 2014 SyncFree Consortium.  All Rights Reserved.
%%
%% This file is provided to you under the Apache License,
%% Version 2.0 (the "License"); you may not use this file
%% except in compliance with the License.  You may obtain
%% a copy of the License at
%%
%%   http://www.apache.org/licenses/LICENSE-2.0
%%
%% Unless required by applicable law or agreed to in writing,
%% software distributed under the License is distributed on an
%% "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
%% KIND, either express or implied.  See the License for the
%% specific language governing permissions and limitations
%% under the License.
%%
%% -------------------------------------------------------------------

%% =============================================================================
%% Adaptive Replications DC - SyncFree
%%
%% The Replication Layer. Support function to access the current DC and other DCs.
%% 
%% @author Amadeo Asco
%% @version 1.0.0
%% @reference Project <a href="https://syncfree.lip6.fr/">SyncFree</a>
%% @end
%% =============================================================================
%% 
%% @doc The Replication Layer.
-module(adprep).
-author('aas@trifork.co.uk').

-ifdef(EUNIT).
% Unit-test
-compile(export_all).
-else.
-compile(report).

%% Interface calls
-export([start/0, stop/0, create/1, create/2, create/4, delete/1, hasReplica/1, read/1, 
         update/2, remove/1, remove/3, getNumReplicas/1, newId/0, newId/1]).
% gen_server callbacks
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, code_change/3, 
         terminate/2]).
-endif.
-behaviour(gen_server).

-include("adprep.hrl").


%% =============================================================================
%% Server interface
%% =============================================================================
%%
%% @doc Start the server.
-spec start() -> {ok, pid()} | ignore | {error, {already_started, pid()} | term()}.
start() -> 
    io:format("Starting adprep server ~n"),
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

%% @doc Stops the server asynchronously.
-spec stop() -> ok.
stop() ->
    io:format("Stopping adprep server ~n"),
    gen_server:cast(?MODULE, shutdown).

%% 
%% @doc Creates the replica locally and creates other replicas if the startegy requires. 
%        The result may have the values ok or {error, ErrorCode}.
%%
%%        NextDCFunc is a function which must take three arguments; the current DC, a list 
%%        of DCs and its own Args. Such function must return a tuple composed of the list 
%%        of DCs to replicate and another list of potential DCs to replicate. If any 
%%        replication to a DC from the list of DCs to replicate in failes a DC from the 
%%        potential list will be used instead.
-spec create(key(), term(), function(), term()) -> ok | {error, does_not_exist | already_exists_replica}.
create(Key, Value, NextDCFunc, Args) ->
    io:format("(adprep, NextDCFunc, Args): Creating entry for ~p~n",[{Key, Value}]),
    gen_server:call(?MODULE, {create, Key, {Value, NextDCFunc, Args}}).

%% @doc Creates the local replica only. 
-spec create(key(), term()) -> ok | {error, does_not_exist | already_exists_replica}.
create(Key, Value) ->
    io:format("(adprep): Creating entry for ~p~n",[{Key, Value}]),
    gen_server:call(?MODULE, {create, Key, {Value, Key}}).

%% @doc Creates the local replica only. The value for the specified key must already 
%%        exists in another DC. 
-spec create(key()) -> ok | {error, does_not_exist | already_exists_replica}.
create(Key) ->
    io:format("(adprep): Creating entry for ~p~n",[Key]),
    gen_server:call(?MODULE, {create, Key}).

%% @doc Deletes an entry from within all the DCs with replica. 
-spec delete(key()) -> ok | {error, does_not_exist | already_exists_replica}. 
delete(Key) ->
    io:format("(adprep): Removing entry for ~p~n",[Key]),
    gen_server:call(?MODULE, {delete, Key}).

%% @doc Gets the number of replicas.
-spec getNumReplicas(key()) -> integer().
getNumReplicas(Key) ->
    io:format("(adprep): Getting number of replicas of entry for ~p~n",[Key]),
    gen_server:call(?MODULE, {num_replicas, Key}).

%% @doc Checks if there is a local replica. 
-spec hasReplica(key()) -> boolean().
hasReplica(Key) ->
    io:format("(adprep): Checking existance of entry for ~p~n",[Key]),
    gen_server:call(?MODULE, {has_a_replica, Key}).

%% @doc Reads specified entry. 
-spec read(key()) -> {ok, term()} | {error}.
read(Key) ->
    io:format("(adprep): Reading entry for ~p~n",[Key]),
    gen_server:call(?MODULE, {read, Key}).

%% @doc Removes the local entry. 
-spec remove(key()) -> ok | {error}.
remove(Key) ->
    io:format("(adprep): Removing entry for ~p~n",[Key]),
    gen_server:call(?MODULE, {remove, Key}).


%% @doc Removes the local entry if the conditios are apropiated, which is check by calling 
%%        function VerifyRemove with the record associated to the passed key and the passed 
%%        arguments. 
-spec remove(key(), function(), term()) -> ok | {ok, failed_verification} | {error}.
remove(Key, VerifyRemove, Args) ->
    io:format("(adprep): Removing entry for ~p~n",[Key]),
    gen_server:call(?MODULE, {remove, Key, VerifyRemove, Args}).

%% @doc Updates the specified value into the local data and forward update messages to the 
%%        other DCs with replicas. 
-spec update(key(), term()) -> ok | {error}.
update(Key, Value) ->
    io:format("(adprep): Updating entry for ~p~n",[Key]),
    gen_server:call(?MODULE, {write, Key, Value}).

%% @spec newId(Key::atom()) -> Id::integer()
%% 
%% @doc Provides a new ID.
newId(_Key) ->
    io:format("(adprep): Creating new ID~n",[]),
    gen_server:call(?MODULE, {new_id}).
%% @spec newId() -> Id::integer()
%% 
%% @doc Provides a new ID.
newId() ->
    Key = process_info(self(), registered_name),
    newId(Key).


%% =============================================================================
%% Propossed Adaptive Replication Strategy process
%% =============================================================================
%% @spec init([]) -> {ok, LoopData::tuple()}
%%
%% @doc Initialises the process and start the process.
init([]) ->
    {ok, {0}}.

%% @spec handle_info(Msg, LoopData) -> {noreply, LoopData}
%%
%% @doc Does nothing.
handle_info(_Msg, LoopData) ->
    {noreply, LoopData}.

%% @spec terminate(Reason, LoopData) -> ok
%%
%% @doc Does nothing.
terminate(_Reason, _LoopData) ->
    ok.

%% @spec code_change(PreviousVersion, State, Extra) -> Result::tuple()
%%
%% @doc Does nothing. No change planned yet.
code_change(_PreviousVersion, State, _Extra) ->
    % The function is there for the behaviour, but will not be used. Only a version on the
    % next
    {ok, State}.

%% =============================================================================
%% Messages handlers
%% =============================================================================
handle_call({new_id}, _From, {OwnId}) ->
    {reply, OwnId, {OwnId+1}};

handle_call({num_replicas, Key}, _From, {OwnId}) ->
    NumReplicas = getNumReplicas_(Key),
    {reply, NumReplicas, {OwnId}};

handle_call({get_dcs, Key}, _From, {OwnId}) ->
    {Response, OwnId1} = case getRecord(Key) of
        none ->
            Response1 = getAllDCsWithReplicas(Key, OwnId),
            Response2 = case Response1 of
                {error, _} ->
                    {exists, []};
                R ->
                    R
            end,
            {Response2, OwnId+1};
        Record ->
            #replica{list_dcs_with_replicas=List}=Record,
            {{ok, List}, OwnId}
    end,
    {reply, Response, {OwnId1}};

handle_call({create, Key}, _From, {OwnId}) ->
    % The data should not already exist
    case getNumReplicas_(Key) of
        0 ->
            % Get current value
            case read(Key, OwnId) of
                {{ok, Value}, OwnId1} ->
                    handle_call({create, Key, {Value, ?MODULE}}, _From, {OwnId1}); % could be made more efficient
                {{error, timeout}, OwnId1} ->
                    {reply, {error, does_not_exist}, {OwnId1}}
            end;
        _ ->
            % Ignore as there is a local replica
            {reply, {error, already_exists_replica}, {OwnId}}
    end;

%% @doc Returns ok | {error, already_exists_replica}
handle_call({create, Key, {Value, RegName}}, _From, {OwnId}) ->
    % The data should not already exist
    case getNumReplicas_(Key) of
        0 ->
            % Create the record for the specified key and save it
            case create_(Key, Value) of
                ok ->
                    % Success: extis locally now
                    case getAllDCsWithReplicas(Key, OwnId) of
                        {ok, DCs} ->
                            Record = getRecord(Key), % must exist as we have just created
                            Record1 = Record#replica{num_replicas=sets:size(DCs)+1, 
                                                         list_dcs_with_replicas=DCs},
                            case datastore:update(Key, Record1) of
                                ok ->
                                    % Notify other DCs with replica
                                    % TODO: should be asynchronous
                                    gen_server:multi_call(sets:to_list(DCs), RegName, {new_replica, node(), Key, Value}),
                                    {reply, ok, {OwnId+1}};
                                Response -> 
                                    % Should not happen {error, not_found}
                                    {reply, Response, {OwnId}}
                            end;
                        {error, timeout} -> 
                            % TODO: what happen in this case for now continue
                            {reply, ok, {OwnId}}
                    end;
                Response ->
                    % Failure
                    {reply, Response, {OwnId}}
            end;
        _ ->
            % Ignore as there is a local replica
            {reply, {error, already_exists_replica}, {OwnId}}
    end;

%% @doc Returns ok | {error, already_exists_replica}
handle_call({create, Key, {Value, NextDCFunc, Args}}, _From, {OwnId}) ->
    % The data should not already exist
    case getNumReplicas_(Key) of
        0 ->
            % Create the record for the specified key and save it
            case createOtherReplicas(Key, Value, OwnId, NextDCFunc, Args) of 
                {ok, OwnId1} ->
                    % Create all necessary replicas
                    {reply, ok, {OwnId1}};
                {Response, OwnId1} ->
                    {reply, Response, {OwnId1}}
            end;
        _ ->
            % Ignore as there is a local replica
            {reply, {error, already_exists_replica}, {OwnId}}
    end;

%% @spec handle_call({rmv_replica, Dc, Key}, From, Args) -> Result::tuple()
%%
%% @doc Removes the specified DC from the list of DCs with replica.
handle_call({rmv_replica, Dc, Key}, _From, {OwnId}) ->
    % The data should already exist
    {Reply, Args} = case getRecord(Key) of
        none ->
            % Ignore as there is no replica
            {{error, no_replica}, {OwnId}};
        Record ->
            % The data exists
            #replica{num_replicas=Num,list_dcs_with_replicas=List}=Record,
            List1 = sets:del_element(Dc, List),
            Record1 = Record#replica{num_replicas=Num-1,list_dcs_with_replicas=List1},
            Result = datastore:update(Key, Record1),
            {Result, {OwnId}}
    end,
    {reply, Reply, Args};

handle_call({new_replica, Dc, Key, Value}, _From, {OwnId}) ->
    {Reply, Args} = if 
        Dc == self() ->
            % Unable to update record of itself
            {{error, self}, {OwnId}};
        true ->
            % The data should already exist as it comes from another DC
            case getRecord(Key) of
                none ->
                    % It does not alreday exist
                    {{error, does_not_exist}, {OwnId}};
                Record ->
                    % Update it
                    #replica{num_replicas = NumReplicas, 
                             list_dcs_with_replicas=List} = Record,
                    List1 = sets:add_element(Dc, List),
                    Record1 = Record#replica{value=Value,
                                             num_replicas = NumReplicas+1, 
                                                 list_dcs_with_replicas=List1},
                    Result = datastore:update(Key, Record1),
                    {Result, {OwnId}}
            end
    end,
    {reply, Reply, Args};

handle_call({new_replica, Dc, Key}, _From, {OwnId}) ->
    {Reply, Args} = if 
        Dc == self() ->
            % Unable to update record of itself
            {{error, self}, {OwnId}};
        true ->
            % The data should already exist as it comes from another DC
            case getRecord(Key) of
                none ->
                    % It does not alreday exist
                    {{error, does_not_exist}, {OwnId}};
                Record ->
                    % Update it
                    #replica{num_replicas = NumReplicas, 
                             list_dcs_with_replicas=List} = Record,
                    List1 = sets:add_element(Dc, List),
                    Record1 = Record#replica{num_replicas = NumReplicas+1, 
                                                 list_dcs_with_replicas=List1},
                    Result = datastore:update(Key, Record1),
                    {Result, {OwnId}}
            end
    end,
    {reply, Reply, Args};

handle_call({read, Key}, _From, {OwnId}) ->
    {Response, OwnId1} = read(Key, OwnId),
    {reply, Response, {OwnId1}};

handle_call({write, Key, Value}, _From, {OwnId}) ->
    {Response, OwnId1} = write(Key, OwnId, Value),
    {reply, Response, {OwnId1}};

handle_call({delete, Key}, _From, {OwnId}) ->
    {Response, OwnId1} = rmvDel(Key, OwnId, forward_delete),
    {reply, Response, {OwnId1}};

handle_call({forward_delete, Key}, _From, {OwnId}) ->
    % Remove Strategy Layer for the key
    gen_server:cast({node(), Key}, shutdown),
    % Remove replica
    Result = datastore:remove(Key),
    {reply, Result, {OwnId}};

handle_call({remove, Key}, _From, {OwnId}) ->
    {Response, OwnId1} = rmvDel(Key, OwnId, rmv_replica),
    {reply, Response, {OwnId1}};
handle_call({remove, Key, VerifyRemove, Args}, _From, {OwnId}) ->
    case getRecord(Key) of
        none ->
            % No local replica; ignore request
            {reply, ok, {OwnId}};
        Record ->
            % DCs with replica
            case VerifyRemove(Record, Args) of
                true ->
                    % Proceed
                    #replica{list_dcs_with_replicas=DCs}=Record,
                    case forward({rmv_replica, node(), Key}, DCs) of
                        ok ->
                            % Success - Remove local replica
                            datastore:remove(Key),
                            {reply, ok, {reply}};
                        {error, no_replica} ->
                            % Failed remote - Remove local replica
                            datastore:remove(Key),
                            {reply, ok, {OwnId}};
                        R ->
                            % Failure - should alreday have rolled back
                            {reply, R, {OwnId}}
                    end;
                false ->
                    {reply, {ok, failed_verification}, {OwnId}}
            end
    end;

handle_call({has_a_replica, Key}, _From, {OwnId}) ->
    case getRecord(Key) of
        none ->
            {reply, false,  {OwnId}};
        _Record ->
            {reply, true, {OwnId}}
    end;

handle_call(_Msg, _From, LoopData) ->
    {noreply, LoopData}.

handle_cast({update, Id, Key, Value}, {OwnId}) ->
    case getRecord(Key) of
        none ->
            % Ignore as there is no replica
            {reply, adpreps_:buildReply(update, Id, {error, no_replica}), {OwnId}};
        Record ->
            Record1 = Record#replica{value=Value},
            datastore:update(Key, Record1),
            {reply, adpreps_:buildReply(update, Id, {ok, updated}), {OwnId}}
    end;

handle_cast(shutdown, {OwnId}) ->
    {stop, normal, {OwnId}};

handle_cast({has_replica, Origin, Id, Key}, {OwnId}) ->
    case getRecord(Key) of
        none ->
            {noreply, {OwnId}};
        Record ->
            #replica{list_dcs_with_replicas=DCs}=Record,
            Origin ! adpreps_:buildReply(has_replica, Id, {exists, [node() | DCs]}),
            {noreply, {OwnId}}
    end;

handle_cast({create_new, Id, Key, Value, DCs}, {OwnId}) ->
    % Create replica but do not notify anyone
    % The data should not already exist
    {Reply, Args} = case getRecord(Key) of
        0 ->
            % Create the record for the specified key and save it
            List = sets:del_element(self(), DCs),
            Record=#replica{key=Key,value=Value,num_replicas=sets:size(DCs),list_dcs_with_replicas=List},
            datastore:create(Key, Record),
            {adpreps_:buildReply(create_new, Id, ok), {OwnId}};
        _ ->
            % Ignore as there is a replica
            {adpreps_:buildReply(create_new, Id, {error, no_replica}), {OwnId}}
    end,
    {reply, Reply, Args};

% 
handle_cast({new_replica, Id, Key}, {OwnId}) ->
    {Response, OwnId1} = read(Key, OwnId),
    case Response of
        {ok, Value} ->
            Result = handle_call({new_replica, ?MODULE, Key, Value}, ?MODULE, {OwnId1}),
            {reply, adpreps_:buildReply(new_replica, Id, Result), {OwnId1}};
        _ ->
            {reply, adpreps_:buildReply(new_replica, Id, Response), {OwnId1}}
    end;

handle_cast({reply, has_replica, _Id, _Result}, {OwnId}) ->
    % Ignore
    {noreply, {OwnId}};
handle_cast({reply, update, _Id, Key, Result}, {OwnId}) ->
    case Result of
        {error, no_replica, Dc} ->
            % The DC does not have a replica
            case getRecord(Key) of
                none ->
                    % Ignore as there is no replica anymore
                    {noreply, {OwnId}};
                Record ->
                    % Remove it
                    #replica{list_dcs_with_replicas=List}=Record,
                    List1 = sets:del_element(Dc, List),
                    Record1 = Record#replica{list_dcs_with_replicas=List1},
                    datastore:update(Key, Record1),
                    {noreply, {OwnId}}
            end;
        _ ->
            % Ignore as previous responses has been already processed getting oll needed 
            % data
            {noreply, {OwnId}}
    end;

handle_cast(_Msg, LoopData) ->
    {noreply, LoopData}.


%% =============================================================================
%% Support functions
%% =============================================================================

%% @spec getAllDCs() -> DCs::List
%% 
%% @doc The list of all the DCs.
getAllDCs() ->
    % TODO: complete it
    [node() | []].

%% @spec getNumReplicas_(Key::atom()) -> Result::integer()
%%
%% @doc Gets the number of replicas, if any, or zero otherwise.
getNumReplicas_(Key) ->
    case getRecord(Key) of
        none ->
            0;
        Record ->
            #replica{num_replicas=Num}=Record,
            Num
    end.

%% @spec getRecord(Key::atom()) -> Record::record()
%%
%% @doc Gets the record for the specified Key and returns it, if exists, otherwise 
%%      returns none.
getRecord(Key) ->
    case datastore:read(Key) of
        {ok, Record} ->
            Record;
        {error, not_found} ->
            none
    end.

%% @spec create_(Key::atom(), Value::item()) -> Result::tuple()
%%
%% @doc Ceates a record for the specified data, adds it to the passed map and return all 
%%        the new information.
%%
%%      Returns {ok, Record::record()} | {error, already_created}.
create_(Key, Value) ->
    % Create the record for the specified key and save it
    DCs = sets:new(),
    create_(Key, Value, DCs).
create_(Key, Value, DCs) ->
io:format("(adprep): Creating local ~p~n",[{Key, Value, DCs}]),
    % Create the record for the specified key and save it
    Record=#replica{key=Key,value=Value,num_replicas=1,list_dcs_with_replicas=DCs},
    datastore:create(Key, Record).

%% @spec createOtherReplicas(Key::key(), Value::term(), OwnId::integer(), NextDCsFunc::function(), Args) -> {ok | {error, {creating_replica, Dc}}, Id::integer()}
%%
%% @doc Gets a list of DC where replicas should be created, updates the record with the 
%%         new list of DCs with replicas and request the creation of the new replicas in each 
%%        of those DCs.
%%
%%        NextDCsFunc is a function that takes the current DC, the list of all DCs and the 
%%        provided arguments, Args and return a tuple with a list of DC to replicat in and a 
%%        list of potential DCs to replicate in if any of others fail.
createOtherReplicas(Key, Value, OwnId, NextDCsFunc, Args) ->
    AllDCs = getAllDCs(), % get the list of all DCs with or without replica
    {DCs, PotentialDCs} = NextDCsFunc(node(), AllDCs, Args),
    Ds = sets:del_element(self(), sets:from_list(DCs)),
    Size = sets:size(Ds),
    DCs1 = sets:to_list(Ds),
    DCs2 = [node() | DCs1],
    Record=#replica{key=Key,value=Value,num_replicas=Size+1,list_dcs_with_replicas=DCs1},
    case datastore:create(Key, Record) of
        ok ->
            {registered_name, RegName} = process_info(self(), registered_name),
            createOtherReplicas_(RegName, Record, OwnId, DCs2, DCs1, PotentialDCs);
        Result ->
            {Result, OwnId}
    end.

%% @spec createOtherReplicas_(RegName::atom(), Record::record(), OwnId::integer(), AllReplicatedDCs::list(), DCs::list(), PotentialDCs::list()) -> {ok | {error, {creating_replica, Dc}}, Id::integer()}
%%
%% @doc Creates the other necessary replicas without need for each to notify the others.
createOtherReplicas_(_RegName, _Record, OwnId, _AllReplicatedDCs, [], _PotentialDCs) ->
    {ok, OwnId+1};
createOtherReplicas_(RegName, Record, OwnId, AllReplicatedDCs, [Dc | DCs], PotentialDCs) ->
    #replica{key=Key,value=Value}=Record,
    {reply, create_new, OwnId, Result} = gen_server:call({RegName, Dc}, {create_new, OwnId, Key, Value, AllReplicatedDCs}),
    case Result of
        {error, _ErrorCode} ->
            % Failed: abort
            % TODO: remove from the current and others already successfully created
            {{error, {creating_replica, Dc}}, OwnId+1};
%            PotentialDCs2 = createReplicasPotentialDcs(RegName, Record, OwnId, AllReplicatedDCs, PotentialDCs, PotentialDCs),
%            % Allow it to be later re-use the DC if needed
%            [Dc | PotentialDCs2];
        _ ->
            createOtherReplicas_(RegName, Record, OwnId, AllReplicatedDCs, DCs, PotentialDCs)
    end.

%% @spec createReplicasPotentialDcs(RegName::atom(), Record, OwnId::integer(), AllReplicatedDCs::List, PotentialDCs::List, NextPotentialDCs::List) -> NewPotentialDCs::List
%%
%% @doc Tries to create the replica to a DC from within the list of other potential DCs.
%createReplicasPotentialDcs(RegName, Record, OwnId, AllReplicatedDCs, PotentialDCs, [Dc | NextPotentialDCs]) ->
%    #replica{key=Key,value=Value}=Record,
%    {reply, create_new, OwnId, Result} = gen_server:call({RegName, Dc}, {create_new, OwnId, Key, Value, AllReplicatedDCs}),
%    case Result of
%        {error, _ErrorCode} ->
%            % Failed
%            createReplicasPotentialDcs(RegName, Record, OwnId, AllReplicatedDCs, PotentialDCs, NextPotentialDCs);
%        _ ->
%            sets:del_element(Dc, PotentialDCs)
%    end;
%createReplicasPotentialDcs(_RegName, _Record, _OwnId, _AllReplicatedDCs, PotentialDCs, []) ->
%    PotentialDCs.

%% @doc Reads the data locally if exist, i.e. replicated, or alternativelly get the data 
%%        from any of the other DCs with replicas.
%%
%%        The returned value is a tuple with the response of the form 
%%        {{ok, Value}, NewOwnId} or {{error, ErrorCode}, NewOwnId}.
-spec read(key(), integer()) -> {{ok, term()}, integer()} | {{error, _ }, integer()}.
read(Key, OwnId) ->
    case getRecord(Key) of
        none ->
            % Find DCs with replica
            case getAllDCsWithReplicas(Key, OwnId) of
                {ok, DCs} ->
                    %% Get the data from one of the DCs with replica
                    {registered_name, RegName} = process_info(self(), registered_name),
                    {Result, OwnId1} = sendOne(read, OwnId+1, Key, {read, OwnId, Key}, RegName, DCs),
                    {Result, OwnId1};
                {error, ErrorCode} ->
                    % An error
                    {{error, ErrorCode}, OwnId+1}
            end;
        Record ->
            #replica{value=Value}=Record,
io:format("(adprep): Read entry ~p~n",[{Key, Value}]),
            {{ok, Value}, OwnId}
    end.

%% @spec write(Key::atom(), OwnId::integer(), Value::term()) -> Result::tuple()
%%
%% @doc Saves locally the new value and sets to send updates to all DCs with replicas if 
%%        the data exists locally, otherwise requested from DCs with replicas and if the 
%%        data does not esists an error is returned.
write(Key, OwnId, Value) ->
    case getRecord(Key) of
        none ->
            % Find DCs with replica
            case getAllDCsWithReplicas(Key, OwnId) of
                {ok, DCs} ->
                    % Send updates to each of the replicated sites
                    gen_server:abcast(DCs, Key, {update, OwnId, Key, Value}),
                    {ok, OwnId+1};
                {error, ErrorCode} ->
                    % An error
                    {{error, ErrorCode}, OwnId+1}
            end;
        Record ->
            % Update local data
            Record1 = Record#replica{value=Value},
            datastore:update(Key, Record1),
            % Send updates to other DCs
            #replica{list_dcs_with_replicas=DCs}=Record1,
            gen_server:abcast(DCs, Key, {update, OwnId, Key, Value}),
            {ok, OwnId+1}
    end.

%% @spec getAllDCsWithReplicas(Key::atom(), OwnId::integer()) -> Result::tuple()
%%
%% @doc Gets all the DCs with a replica.
%%
%%        Returs a tuple that can be {ok, DCS} on success or {error, timeout} otherwise.
getAllDCsWithReplicas(Key, OwnId) ->
    % Discover the DCs with replicas
    AllDCs = getAllDCs(),
    ok = flush(OwnId),
    gen_server:abcast(AllDCs, Key, {has_replica, self(), OwnId, Key}),
    % Only take response from the first one
    receive
        {reply, has_replica, OwnId, {exists, DCs}} ->
            {ok, DCs}
    after
        1000 ->
            {error, timeout}
    end.

%% @spec sendOne(Type::atom(), OwnId::integer(), Key::atom(), Msg, RegName::atom(), DCs::List) -> Result::tuple()
%%
%% @doc Sends synchronously the specified message to the first of the specified DC for 
%%      its process registered with the key and on failure will try with the other DCs.
%%
%%      Returned result is a tuple with the result and the new own internal ID.
sendOne(Type, OwnId, Key, Msg, RegName, [Dc | DCs]) ->
    {reply, Type, OwnId, {ResultType, Result}} = gen_server:call({RegName, Dc}, Msg, 1000),
    case ResultType of
        error ->
            % Should be a timeout, so try with the next DC
            sendOne(Type, OwnId, Key, Msg, RegName, DCs);
        _ ->
            {{ResultType, Result}, OwnId+1}
    end;
sendOne(_Type, OwnId, _Key, _Msg, _RegName, []) ->
    {{error, no_dcs}, OwnId+1}.

%% @doc Removes all the messages that match the specified one from the mailbox.
-spec flush(integer()) -> ok.
flush(Id) ->
    receive
        {reply, has_replica, Id, {exists, _DCs}} ->
            flush(Id)
    after
        0 ->
            ok
    end.

%% @spec rmvDel(Key::atom(), OwnId::integer(), Type::atom()) -> {ok | {error, ErrorCode::atom()}, Id::integer()}
%%
%% @doc Removes the local replica and depending of the Type passed also forward apropiate 
%%      messages to other DCs with replicas to remove them.
rmvDel(Key, OwnId, Type) ->
    case getRecord(Key) of
        none ->
            % No local record
            case Type of
                forward_delete ->
                    % Forward the delettion
                    Value = getAllDCsWithReplicas(Key, OwnId),
                    Result = case Value of
                        {error, ErrorCode} ->
                            {error, ErrorCode};
                        {ok, DCs} ->
                            % Forward
                            forward({Type, Key}, DCs)
                    end,
                    {Result, OwnId+1};
                _ ->
                    {ok, OwnId}
            end;
        Record ->
            % DCs with replica
            #replica{list_dcs_with_replicas=DCs}=Record,
            Response = case forward({Type, node(), Key}, DCs) of
                ok ->
                    % Success - Remove local replica
                    datastore:remove(Key),
                    ok;
                {error, no_replica} ->
                    % Success- Remove local replica
                    datastore:remove(Key),
                    ok;
                R ->
                    % Failure - should alreday have rolled back
                    R
            end,
            {Response, OwnId+1}
    end.

%% @spec forward(Msg::map(), DCs::list()) -> Result
%%
%% @doc Removes the local replica and depending of the Type passed also forward apropiate 
%%      messages to other DCs with replicas to remove them.
forward(_Msg, []) ->
    ok;
forward(Msg, [Dc | DCs]) ->
    Result = gen_server:call({adpref, Dc}, Msg),
    case Result of
        {error, no_replica} ->
            forward(Msg, DCs);
        {error, _} ->
            % TODO: roll back
            Result;
        _ ->
            forward(Msg, DCs)
    end.
