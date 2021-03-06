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
%% Managing information about replica placement
%% 
%% @author Amadeo Asco, Annette Bieniusa, Adrian Vladu
%% @version 1.0.0
%% @reference Project <a href="https://syncfree.lip6.fr/">SyncFree</a>
%% @reference More courses at <a href="http://www.trifork.com">Trifork Leeds</a>
%% @end
%% =============================================================================

%% @doc Replication management

-module(replica_manager).
-author(['aas@trifork.co.uk','bieniusa@cs.uni-kl.de', 'vladu@rhrk.uni-kl.de']).
-behaviour(gen_server).

%-ifdef(TEST).
%-compile(export_all).
%-else.
-compile(report).
% interface calls
-export([start/0, stop/0, create/4, read/1, update/2, remove_replica/1,
    add_dc_to_replica/2, remove_dc_from_replica/2]).
    
% gen_server callbacks
-export([init/1, handle_call/3, handle_cast/2, handle_info/2,
         terminate/2, code_change/3]).
%-endif.

-include("adprep.hrl").

%TODO: Parameterize by strategy
%TODO: Parameterize by data store

%% =============================================================================
%% Public API
%% =============================================================================

%% @doc Start the replication manager.
start() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

%% @doc Creates the first instance of the specified data in this DC.
-spec create(key(), value(), strategy(), strategy_params()) 
  -> ok | {error, reason()}.
create(Key, Value, Strategy, StrategyParams) ->
    gen_server:call(?MODULE, {create, Key, Value, Strategy, StrategyParams}, infinity).

%% @doc Reads the value of the specified data.
-spec read(key()) -> {ok, value()} | {error, reason()}.
read(Key) ->
    gen_server:call(?MODULE, {read, Key}, infinity).
    
%% @doc Writes the new value of the specified data.
-spec update(key(), value()) -> ok | {error, reason()}.
update(Key, Value) ->
    gen_server:call(?MODULE, {update, Key, Value}, infinity).

%% @doc Remove the local replica.
-spec remove_replica(key()) -> ok | {error, reason()}.
remove_replica(Key) ->
    gen_server:call(?MODULE, {remove, Key}, infinity).

%% @doc Add the DC to the replica locations.
-spec add_dc_to_replica(key(), datacenter()) -> ok | {error, reason()}.
add_dc_to_replica(Key, DC) ->
    gen_server:call(?MODULE, {add_dc_to_replica, Key, DC}, infinity).

%% @doc Remove the DC from the replica locations.
-spec remove_dc_from_replica(key(), datacenter()) -> ok | {error, reason()}.
remove_dc_from_replica(Key, DC) ->
    gen_server:call(?MODULE, {remove_dc_from_replica, Key, DC}, infinity).

%% @doc Shutdown replication manager.
stop() ->
    gen_server:call(?MODULE, terminate).

%%====================================================================
%% gen_server callbacks
%%====================================================================
init([]) ->
   lager:info("Initializing the replica manager"),
   ?MODULE = ets:new(?MODULE, [set, named_table, protected]),
   {ok, ?MODULE}.

handle_call({create, Key, Value, Strategy, StrategyParams}, _From, Tid) ->
    lager:info("Create data item with key: ~p, value: ~p, strategy: ~p 
        and StrategyParams: ~p, with Tid: ~p",
        [Key, Value, Strategy, StrategyParams, Tid]),

    %% Start the replication strategy
    Result = strategy_adprep:init_strategy(Key, true,
        StrategyParams),
    lager:info("Replication info is ~p", [Result]),
    case Result of
        {ok, _ReplicationInfo} ->
            %% Save data item meta information locally
            State = sys:get_state(_ReplicationInfo),
            { _, _, Strength, _, _, _} = State,
            lager:info("New Strength is ~p", [Strength]),
            {ok, ThisDC} = inter_dc_manager:get_my_dc(),
            datastore_mnesia_data_info:create(Key,
                #data_info{
                    replicated = true,
                    strength = Strength,
                    strategy = Strategy,
                    dcs = [ThisDC],
                    timestamp = os:timestamp()
                }),
            %% Save data item value locally
            ok = datastore_mnesia:create(Key,Value),
            %% Send data to all available DCs
            SendResult = inter_dc_manager:send_data_item_location(Key),
            lager:info("SendResult is ~p", [SendResult]),
            _ReplicationResult = inter_dc_manager:send_data_item_to_dcs(Key,
                Value, Strategy, StrategyParams),
            lager:info("SendResult is ~p", [_ReplicationResult]),
            {reply, {ok}, Tid};
        {error, Error} ->
            lager:info("Error starting strategy ~p", [Error]),
            {reply, {error, Error}, Tid};
        ignore -> {reply, {error, ignored}, Tid}
    end;

    % TO DO
    %% Send the data item to the minimum required DCs
    %%     (for now we consider the minimum required 1)
    %% Handle the case that replica has already been created at other DC

handle_call({add_dc_to_replica, Key, DC}, _From, Tid) ->
    lager:info("Adding DC: ~p to data item: ~p", [Key, DC]),
    Result = datastore_mnesia_data_info:read(Key),
    case Result of
        {ok, DataInfoWithKey} ->
            DataInfo = DataInfoWithKey#data_info_with_key.value,
            DCs = DataInfo#data_info.dcs,
            DCIsMember = lists:member(DC, DCs),
            case DCIsMember of
                false ->
                    lager:info("Adding to DCs: ~p", [DC]),
                    DataInfoWithDC = DataInfo#data_info{dcs= DCs ++ [DC]},
                    datastore_mnesia_data_info:update(Key, DataInfoWithDC),
                    {ok, StrategyParams} = get_strategy(Key),
                    _Result = strategy_adprep:init_strategy(Key, true, StrategyParams);
                _ -> lager:info("Not adding to DCs: ~p", [DC])
            end,
            {reply, {ok}, Tid};
        {error, _ErrorInfo} ->
            {ok, StrategyParams} = get_strategy(Key),
            _Result = strategy_adprep:init_strategy(Key, false, StrategyParams),
            datastore_mnesia_data_info:create(Key, #data_info{
                    replicated = false,
                    strength = 0.0,
                    strategy = none,
                    dcs = [DC]
                }),
            {reply, {ok}, Tid};
        _Info ->
            lager:info("Failure: ~p", [_Info]),
            {reply, {error}, Tid}
    end;

handle_call({remove_dc_from_replica, Key, DC}, _From, Tid) ->
    lager:info("Removing DC: ~p from data item: ~p", [Key, DC]),
    {_Key, DataInfoWithKey} = datastore_mnesia_data_info:read(Key),
    DataInfo = DataInfoWithKey#data_info_with_key.value,
    DCs = DataInfo#data_info.dcs,
    DCIsMember = lists:member(DC, DCs),
    case DCIsMember of
        true ->
            lager:info("Removing from DCs: ~p", [DC]),
            DataInfoWithDC = DataInfo#data_info{dcs= DCs -- [DC]},
            datastore_mnesia_data_info:update(Key, DataInfoWithDC);
        _ -> lager:info("Not removing from DCs: ~p", [DC])
    end,
    {reply, {ok}, Tid};

handle_call({read, Key}, _From, Tid) ->
    lager:info("Read data item with key: ~p", [Key]),
    {ok, _StrategyParams} = get_strategy(Key),
    Result = datastore_mnesia:read(Key),
    case Result of
        {error, _ErrorMessage} ->
            lager:info("Key not present on ~p", [node()]),
            ResultDataInfo = datastore_mnesia_data_info:read(Key),
            case ResultDataInfo of
                {ok, DataInfoWithKey} ->
                    DataInfo = DataInfoWithKey#data_info_with_key.value,
                    DCs = DataInfo#data_info.dcs,
                    DCsWithKey = inter_dc_manager:get_other_dcs(DCs),
                    lager:info("Key present on ~p", [DCsWithKey]),
                    ResultKeyValue = inter_dc_manager:read_from_any_dc(Key, DCsWithKey),
                    strategy_adprep:init_strategy(Key, false, _StrategyParams),
                    {ok, ShouldReplicate} = strategy_adprep:local_read(Key),
                    case ShouldReplicate of
                        true ->
                            lager:info("Key ~p should local replicate", [Key]),
                            {ok, {_, ValueProxy}} = ResultKeyValue,
                            datastore_mnesia:create(Key, ValueProxy),
                            DataInfoUpdated = DataInfo#data_info{
                                replicated = true,
                                strength = _StrategyParams#strategy_params.repl_threshold,
                                dcs = DCs ++ [node()]
                            },
                            datastore_mnesia_data_info:update(Key, DataInfoUpdated),
                            _SendResult = inter_dc_manager:send_data_item_location(Key);
                        false ->
                            lager:info("Key ~p should not local replicate", [Key])
                    end,
                    {reply, ResultKeyValue, Tid};
                {error, _ErrorInfo} ->
                    {reply, {error, _ErrorMessage}, Tid};
                _Info ->
                    lager:info("Failure: ~p", [_Info]),
                    {reply, {error, _Info}, Tid}
            end;
        {ok, KeyValue} ->
            strategy_adprep:init_strategy(Key, true, _StrategyParams),
            strategy_adprep:local_read(Key),
            {reply, {ok, KeyValue}, Tid}
    end;

handle_call({update, Key, Value}, _From, Tid) ->
    %% TO DO
    %% Update on other DC in case it is not on this DC
    %% Proxy the update process
    Timestamp = os:timestamp(),
    lager:info("Update data item with key: ~p", [Key]),
    {ok, StrategyParams} = get_strategy(Key),
    Result = datastore_mnesia_data_info:read(Key),
    case Result of
        {ok, DataInfoWithKey} ->
            strategy_adprep:init_strategy(Key, true, StrategyParams),
            strategy_adprep:local_write(Key),
            DataInfo = DataInfoWithKey#data_info_with_key.value,
            Replicated = DataInfo#data_info.replicated,
            case Replicated of
                false ->
                    forward_update_to_dcs(Key, Value, DataInfo, StrategyParams,
                        Timestamp),
                    {reply, {ok, "Value updated"}, Tid};
                true ->
                    lager:info("Updating local replica: ~p", [Key]),
                    datastore_mnesia:update(Key, Value),
                    forward_update_to_dcs(Key, Value, DataInfo, StrategyParams,
                        Timestamp),
                    {reply, {ok, "Value updated"}, Tid}
            end;
        {error, ErrorInfo} ->
            lager:info("Failure: ~p", [ErrorInfo]),
            {reply, {error, ErrorInfo}, Tid};
        Info ->
            lager:info("Failure: ~p", [Info]),
            {reply, {error, Info}, Tid}
    end;

handle_call({remove, Key}, _From, Tid) ->
    lager:info("Remove data item with key: ~p", [Key]),

    Result = datastore_mnesia_data_info:read(Key),
    case Result of
        {ok, DataInfoWithKey} ->
            {ok, StrategyParams} = get_strategy(Key),
            strategy_adprep:init_strategy(Key, true, StrategyParams),
            datastore_mnesia:remove(Key),
            DataInfo = DataInfoWithKey#data_info_with_key.value,
            DCsNew = inter_dc_manager:get_other_dcs(DataInfo#data_info.dcs),
            DataInfoUpdated = DataInfo#data_info{
                replicated = false,
                strength = 0.0,
                dcs = DCsNew
            },
            inter_dc_manager:signal_remove_replica_from_dc(DCsNew, Key),
            datastore_mnesia_data_info:update(Key, DataInfoUpdated),
            {reply, {ok}, Tid};
        {error, ErrorInfo} ->
            lager:info("Failure: ~p", [ErrorInfo]),
            {reply, {error, ErrorInfo}, Tid};
        Info ->
            lager:info("Failure: ~p", [Info]),
            {reply, {error, Info}, Tid}
    end.

handle_cast(shutdown, Tid) ->
    lager:info("Shutting down the replica manager"),
    ets:delete(Tid),
    {stop, normal, Tid};
handle_cast(_Message, State) ->
    {noreply, State}.

handle_info(_Message, State) ->
    {noreply, State}.

%% Server termination
terminate(_Reason, _State) ->
    ok.

%% Code change
code_change(_OldVersion, State, _Extra) ->
    {ok, State}.

get_strategy(_Key) ->
    StrategyParams = #strategy_params{
        decay_time     = 5,
        repl_threshold = 100.0,
        rmv_threshold  = 50.0,
        max_strength   = 300.0,
        decay_factor   = 20.0,
        rstrength      = 50.0,
        wstrength      = 100.0,
        min_dcs_number = 1
    },
    {ok, StrategyParams}.


forward_update_to_dcs(Key, Value, DataInfo, StrategyParams, Timestamp) ->
    %% TO DO
    %% Forward the updated version to the other DCs
    %% that contain the replica
    DCs = DataInfo#data_info.dcs,
    DCsWithKey = inter_dc_manager:get_other_dcs(DCs),
    lager:info("Updating external replicas on DCs: ~p", [DCsWithKey]),
    inter_dc_manager:update_external_replicas(DCsWithKey, Key, Value,
        StrategyParams, Timestamp),
    {ok, "Updated external replicas"}.