%%%-------------------------------------------------------------------
%%% @author chenxi1
%%% @copyright (C) 2018, <COMPANY>
%%% @doc
%%%
%%% @end
%%% Created : 07. 五月 2018 下午5:01
%%%-------------------------------------------------------------------
-module(chat_user_server).
-author("chenxi1").
-include("user.hrl").


-behaviour(gen_server).

%% API
-export([start_link/1]).

%% gen_server callbacks
-export([init/1,
  handle_call/3,
  handle_cast/2,
  handle_info/2,
  terminate/2,
  code_change/3]).

-define(SERVER, ?MODULE).

-record(state, {
  socket,
  id
}).

%%%===================================================================
%%% API
%%%===================================================================

%%--------------------------------------------------------------------
%% @doc
%% Starts the server
%%
%% @end
%%--------------------------------------------------------------------
-spec(start_link(Args :: list()) ->
  {ok, Pid :: pid()} | ignore | {error, Reason :: term()}).
start_link(Args) ->
  gen_server:start_link(?MODULE, Args, []).

%%%===================================================================
%%% gen_server callbacks
%%%===================================================================

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Initializes the server
%%
%% @spec init(Args) -> {ok, State} |
%%                     {ok, State, Timeout} |
%%                     ignore |
%%                     {stop, Reason}
%% @end
%%--------------------------------------------------------------------
-spec(init(Args :: term()) ->
  {ok, State :: #state{}} | {ok, State :: #state{}, timeout() | hibernate} |
  {stop, Reason :: term()} | ignore).
init([Socket]) ->
  inet:setopts(Socket, [{active, once}]),
  {ok, #state{socket = Socket}}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Handling call messages
%%
%% @end
%%--------------------------------------------------------------------
-spec(handle_call(Request :: term(), From :: {pid(), Tag :: term()},
    State :: #state{}) ->
  {reply, Reply :: term(), NewState :: #state{}} |
  {reply, Reply :: term(), NewState :: #state{}, timeout() | hibernate} |
  {noreply, NewState :: #state{}} |
  {noreply, NewState :: #state{}, timeout() | hibernate} |
  {stop, Reason :: term(), Reply :: term(), NewState :: #state{}} |
  {stop, Reason :: term(), NewState :: #state{}}).

handle_call(stop, From, State) ->
%%  If {stop,Reason,Reply,NewState} is returned, Reply is given back to From
  {stop, {shutdown,From}, State};
handle_call(_Request, _From, State) ->
  {reply, ok, State}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Handling cast messages
%%
%% @end
%%--------------------------------------------------------------------
-spec(handle_cast(Request :: term(), State :: #state{}) ->
  {noreply, NewState :: #state{}} |
  {noreply, NewState :: #state{}, timeout() | hibernate} |
  {stop, Reason :: term(), NewState :: #state{}}).
handle_cast(stop, State) ->
  {stop, shutdown,State};
handle_cast(_Request, State) ->
  {noreply, State}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Handling all non call/cast messages
%%
%% @spec handle_info(Info, State) -> {noreply, State} |
%%                                   {noreply, State, Timeout} |
%%                                   {stop, Reason, State}
%% @end
%%--------------------------------------------------------------------
-spec(handle_info(Info :: timeout() | term(), State :: #state{}) ->
  {noreply, NewState :: #state{}} |
  {noreply, NewState :: #state{}, timeout() | hibernate} |
  {stop, Reason :: term(), NewState :: #state{}}).
handle_info({tcp, _, Data}, State=#state{socket = Socket})->
  inet:setopts(Socket, [{active, once}]),
  io:format("tcp data ~p~n", [Data]),
  <<Code:8, Str/binary>> = Data,
  NewState = case Code of
               0000 ->
                 do_login(Str,State);
               0001 ->
                 do_chat(Str, State);
               0003 ->
                 do_creatrm(Str,State);
               0004 ->
                 do_joinrm(Str,State);
               0005 ->
                 do_chatrm(Str,State)
%%               0002->
%%                 do_logout(Str,State)
  end,
  {noreply, NewState};

handle_info({tcp_closed,_Socket}, State) ->
  io:format("Server socket closed~n"),
  Id = State#state.id,
  true = ets:delete(onlineusers, Id),
  ok = gen_server:cast(self(),stop),
  {noreply, State};

handle_info({privchat, Srcid, Msg}, State) ->
  Sid = term_to_binary(Srcid),
  M = term_to_binary(Msg),
  Packet = <<0006:8, (byte_size(Sid)):16, Sid/binary, M/binary>>,
  Socket=State#state.socket,
  ok = gen_tcp:send(Socket, Packet),
  {noreply, State};

handle_info({roomchat, MsgBody}, State) ->
  Packet = <<0007:8, MsgBody/binary>>,
  Socket=State#state.socket,
  ok = gen_tcp:send(Socket, Packet),
  {noreply, State};

handle_info({roomid, Room} , State) ->
  io:format("generate room id ~p~n", [Room#rooms.rmid]),
  true = ets:insert(rooms, Room),
  {noreply, State};

handle_info(_Info, State) ->
  io:format("Unknown info ~p~n", [_Info]),
  {noreply, State}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% This function is called by a gen_server when it is about to
%% terminate. It should be the opposite of Module:init/1 and do any
%% necessary cleaning up. When it returns, the gen_server terminates
%% with Reason. The return value is ignored.
%%
%% @spec terminate(Reason, State) -> void()
%% @end
%%--------------------------------------------------------------------
-spec(terminate(Reason :: (normal | shutdown | {shutdown, term()} | term()),
    State :: #state{}) -> term()).

terminate({shutdown,From}, State) ->
%%  do some clean up here
  Sokect=State#state.socket,
  ok = gen_tcp:close(Sokect),
  gen_server:reply(From,ok),
  io:format("~p proc is going to terminate ~n",[self()]);
terminate(_Reason, _State) ->
  ok.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Convert process state when code is changed
%%
%% @spec code_change(OldVsn, State, Extra) -> {ok, NewState}
%% @end
%%--------------------------------------------------------------------
-spec(code_change(OldVsn :: term() | {down, term()}, State :: #state{},
    Extra :: term()) ->
  {ok, NewState :: #state{}} | {error, Reason :: term()}).
code_change(_OldVsn, State, _Extra) ->
  {ok, State}.

%%%===================================================================
%%% Internal functions
%%%===================================================================

do_login(Str,State)->
  io:format("received login msg~n"),
  LId = binary_to_term(Str),
  Regid = "user" ++ integer_to_list(LId),
  IdAtom = list_to_atom(Regid),
  Socket = State#state.socket,
  NewUser = #users{id = LId,socket =Socket},
  case ets:lookup(onlineusers, LId) of
    [Record] ->
      PrevSocket = Record#users.socket,
      io:format("the previous socket is ~p~n",[PrevSocket]),
      Pid = whereis(IdAtom),
      true = unregister(IdAtom),
      ok = gen_server:call(Pid,stop),
      io:format("~p ~p~n", [?MODULE, ?LINE]),
      true = ets:delete(onlineusers, LId);
    []->
      ok
  end,
  true = ets:insert(onlineusers, NewUser),
  true = register(IdAtom, self()),
  State#state{id=LId}.

do_chat(Str,State)->
  io:format("received chat msg~n"),
  <<Sidsize:16, Sid:Sidsize/binary-unit:8, Tidsize:16, Tid:Tidsize/binary-unit:8,
    Msg/binary>> = Str,
  %send to tgt Pid
  Regid = "user" ++ integer_to_list(binary_to_term(Tid)),
  io:format("send msg to user ~p~n", [binary_to_term(Tid)]),
  case ets:lookup(onlineusers, binary_to_term(Tid)) of
    [Record] ->
      io:format("record found~p~n", [Record]),
      IdAtom = list_to_atom(Regid),
      IdAtom ! {privchat, binary_to_term(Sid), binary_to_term(Msg)};
    [] ->
      io:format("target user not online~n")
  end,
  State.

do_creatrm(Str,State)->
  io:format("received room creat msg~n"),
  RmName = binary_to_term(Str),
  Id=State#state.id,
  genid(#rooms{rmmems = [Id], rmname = RmName}),
  State.

do_joinrm(Str,State)->
  io:format("received room join msg~n"),
  <<SidSize:16, Sid:SidSize/binary, Rid/binary>> = Str,
  SrcId = binary_to_term(Sid),
  RmId = binary_to_term(Rid),
  case ets:lookup(rooms, RmId) of
    [Room] ->
      io:format("found room ~p~n", [Room]),
      RoomMembs = Room#rooms.rmmems,
      NewRoom = Room#rooms{rmmems = [SrcId | RoomMembs]},
      true = ets:insert(rooms, NewRoom);
    [] ->
      io:format("room not found~n")
  end,
  State.

do_chatrm(Str,State)->
  io:format(("received room chat msg~n")),
  <<Sidsize:16, _Sid:Sidsize/binary-unit:8,
    Ridsize:16, Rid:Ridsize/binary-unit:8, _Body/binary>> = Str,
  RmId = binary_to_term(Rid),
  case ets:lookup(rooms, RmId) of
    [Room] ->
      io:format("found room~p~n", [Room]),
      RmMembs = Room#rooms.rmmems,
      ok = sendMsg(RmMembs, Str);
    [] ->
      io:format("room not found~n")
  end,
  State.

do_logout(_Str,State)->
  io:format("received logout msg~n"),
  Id=State#state.id,
  true = ets:delete(onlineusers, Id),
  ok = gen_server:call(self(),stop),
  State.

sendMsg([], _Packet) ->
  ok;
sendMsg([Head | Tail], Packet) ->
  Pid = list_to_atom("user" ++ integer_to_list(Head)),
  Pid ! {roomchat, Packet},
  sendMsg(Tail, Packet).

genid(Room = #rooms{}) ->
  idgen ! {self(), roomid, Room}.