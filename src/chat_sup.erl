%%%-------------------------------------------------------------------
%% @doc chat top level supervisor.
%% @end
%%%-------------------------------------------------------------------

-module(chat_sup).

-behaviour(supervisor).

%% API
-export([start_link/0]).

%% Supervisor callbacks
-export([init/1]).

-define(SERVER, ?MODULE).

%%====================================================================
%% API functions
%%====================================================================

start_link() ->
    supervisor:start_link({local, ?SERVER}, ?MODULE, []).

%%====================================================================
%% Supervisor callbacks
%%====================================================================

%% Child :: {Id,StartFunc,Restart,Shutdown,Type,Modules}
init([]) ->
    Restart = permanent,
    Shutdown = 2000,

    ChatServer = {chat_server, {chat_server, start_link, []},
        Restart, Shutdown, worker, [chat_server]},


    UserSup = {user_sup, {user_sup, start_link, []},
        Restart, Shutdown, supervisor, [user_sup]},

    {ok, { {one_for_all, 0, 1}, [ChatServer, UserSup]} }.

%%====================================================================
%% Internal functions
%%====================================================================
