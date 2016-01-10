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

%%% Persistent data store for test purposes.

-module(mnesia_datastore).
-behaviour(gen_server).

% interface calls
-export([start/0, stop/0, create/2, read/1, update/2, remove/1]).
    
% gen_server callbacks
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, 
         terminate/2, code_change/3]).

-include("adprep.hrl").

%%====================================================================
%% Public API
%%====================================================================

%% Starting server
start() -> 
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

%% Stopping server asynchronously
stop() ->
    gen_server:cast(?MODULE, shutdown).

%% Create a new entry
create(Id, Obj) ->
    gen_server:call(?MODULE, {create, Id, Obj}).

%% Reads an entry
read(Id) ->
    gen_server:call(?MODULE, {read, Id}).

%% Updates an entry by merging the states
update(Id, Obj) ->
    gen_server:call(?MODULE, {update, Id, Obj}).

%% Removes an entry
remove(Id) ->
    gen_server:call(?MODULE, {remove, Id}).

%%====================================================================
%% gen_server callbacks
%%====================================================================
init([]) ->
   lager:info("Initializing the mnesia datastore"),

   {State,Message} = mnesia:create_schema(node()),
   lager:info("Schema created with status: ~p and message: ~p", [State, Message]),

   Mnesia_state = mnesia:start(),
   lager:info("Mnesia started with status: ~p", [Mnesia_state]),

   {State_Table,Message_table} = mnesia:create_table(data_item, [{attributes, record_info(fields, data_item)}, {ram_copies, nodes()}, {disc_only_copies, [node()]}, {storage_properties, [{ets, [compressed]}, {dets, [{auto_save, 5000}]}]}]),
   lager:info("Table created with status: ~p and message: ~p", [State_Table, Message_table]),

   {Mnesia_state, ?MODULE}.

handle_call({create, Id, Obj}, _From, Tid) ->
    lager:info("Creating entry for ~p",[Id]),

    FunWrite = fun() ->mnesia:write(#data_item{key=Id,value=Obj}) end,
    mnesia:transaction(FunWrite),
    {reply, {ok, Obj}, Tid};

handle_call({read, Id}, _From, Tid) ->
    lager:info("Reading entry for ~p",[Id]),
    DataItemId = #data_item{key = Id, _ = '_'},
    FunRead = fun() ->mnesia:select(data_item, [{DataItemId, [], ['$_']}]) end,
    {_, Obj} = mnesia:transaction(FunRead),
    {reply, {ok, Obj}, Tid};

handle_call({update, Id, Obj}, _From, Tid) ->
    lager:info("Updating entry for ~p",[Id]),

    FunWrite = fun() ->mnesia:write(#data_item{key=Id,value=Obj}) end,
    mnesia:transaction(FunWrite),
    {reply, {ok, Obj}, Tid};

handle_call({remove, Id}, _From, Tid) ->
    lager:info("Removing entry for ~p",[Id]),

    FunDelete = fun() -> mnesia:delete({data_item, Id}) end,
    {_, Message} = mnesia:transaction(FunDelete),
    lager:info("Mnesia item deleted with message: ~p", [Message]),

    {reply, Message, Tid};

handle_call(_Message, _From, State) ->
    {noreply, State}.

handle_cast(shutdown, Tid) ->
    lager:info("Shutting down the mnesia datastore"),
    Mnesia_state = mnesia:stop(),
    lager:info("Mnesia server shutdown with status: ~p", [Mnesia_state]),
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
