%%%-------------------------------------------------------------------
%%% @author chenxi1
%%% @copyright (C) 2018, <COMPANY>
%%% @doc
%%%
%%% @end
%%% Created : 04. 五月 2018 下午3:50
%%%-------------------------------------------------------------------
-module(chat_server).
-author("chenxi1").

%% API
-export([init/1]).

init([]) ->
  initialize_ets(),
  start_server(),
  {ok,true}.

initialize_ets() ->
  ets:new(onlineusers,[set,public,named_table,{keypos,#users.id}]),
  ets:new(rooms,[set,public,named_table,{keypos,#rooms.rmid}]).

start_server() ->
  {ok,Listen} = gen_tcp:listen(2345,[binary,{packet,4},{reuseaddr,true},{active,true}]),
  spawn(fun() -> handle_connect(Listen) end),
  Pid=spawn(fun() ->loopid(0) end),
  register(idgen,Pid).

handle_connect(Listen) ->
  {ok,Socket} = gen_tcp:accept(Listen),
  spawn(fun() -> handle_connect(Listen) end),
  %loop(#data{socket = Socket}).
  user_server:start(Socket).

