-module(server).
-author("Santiago Botta <santiago@camba.coop>").
-include_lib("eunit/include/eunit.hrl").
-export([server/0, server/1, proxy/1]).
-export([start_proxy/1, send_multiple_requests/3, stop_servers/1]).

%% @doc Given a process id, listens to palindrome requests to return a processed
%% result.
%% Usage:
%% ServerPid = spawn(server, server, [self()]).
%% ServerPid ! {check, "MadamImAdam"}.
%% flush().
server(From) ->
	receive
		{check, String} ->
			IsPalindromeResult = is_palindrome(String),
			From ! {result, String ++ IsPalindromeResult},
			server(From);
		_Message ->
			ok
	end.

%% @doc Takes requests from multiple clients
%% Usage:
%% ServerPid = spawn(server, server, []).
%% ServerPid ! {check, "MadamImAdam", self()}.
%% flush().
server() ->
	receive
		{check, String, From} ->
			io:format("~p ::: processing request from pid: ~p~n", [self(),From]),
			IsPalindromeResult = is_palindrome(String),
			From ! {result, String ++ IsPalindromeResult},
			server();
		_Message ->
			ok
	end.

%% Replicating the server

%% @doc Given a list of server pids, calls a function that accepts a request to
%% one of them and distributes the next requests to the rest of the servers
%% indefinately.
%% Usage:
%% Server1 = spawn(server, server, []).
%% Server2 = spawn(server, server, []).
%% Server3 = spawn(server, server, []).
%% Proxy   = spawn(server, proxy, [[Server1, Server2, Server3]]).
proxy(Servers) ->
	proxy(Servers, Servers).

%% @doc Given a list of server pids and a pid accumulator listens to requests
%% and delegates future requests to the next pid in the servers list indefinately.
proxy([], Servers) ->
	proxy(Servers, Servers);
proxy([S|Svrs], Servers) ->
	receive
		stop ->
			stop_servers(Servers),
			ok;
		Message ->
			S ! Message,
			proxy(Svrs, Servers)
	end.

%% @doc Given a list of servers, sends a stop message to each one.
stop_servers([]) ->
	ok;
stop_servers([S|Svrs]) ->
	io:format("Terminating ~p...~n", [S]),
	S ! stop,
	stop_servers(Svrs).

%%%-------------------------------------------------------------------
%% @doc server module auxiliary functions
%% @end
%%%-------------------------------------------------------------------

%% @doc Given an integer, spawns a proxy server with N servers as argument.
start_proxy(N) ->
	start_proxy(N, []).

%% @doc Starts N servers to return a tuple where the first component is the
%% proxy pid and the second component the list of spawned server pids.
start_proxy(0, Servers) ->
	{spawn(?MODULE, proxy, [Servers]), Servers};
start_proxy(N, Servers) ->
	Server = spawn(?MODULE, server, []),
	io:format("Starting... ~p~n", [Server]),
	start_proxy(N-1, [Server | Servers]).

%% @doc Given a server pid, a client pid and a number of requests, sends N
%% similar requests to the server pid.
send_multiple_requests(_ServerPid, _From, 0) ->
	ok;
send_multiple_requests(ServerPid, From, N) ->
	ServerPid ! {check, "Madam Im Adam", From},
	send_multiple_requests(ServerPid, From, N-1).

%%%-------------------------------------------------------------------
%% @doc Palindrome Auxiliary functions
%% @end
%%%-------------------------------------------------------------------

%% @doc Given a string, returns a string telling whether it's a palindrome or not.
-spec is_palindrome(string()) -> string().
is_palindrome(String) ->
	IsPalindrome = palin:palindrome(String),
	case IsPalindrome of
		true  -> " is a palindrome.";
		false -> " is not a palindrome."
	end.

is_palindrome_test() ->
	IsPalindrome = " is a palindrome.",
	IsNotPalindrome = " is not a palindrome.",
	?assertEqual(IsPalindrome, is_palindrome("Madam I'm Adam")),
	?assertEqual(IsNotPalindrome, is_palindrome("Madam I'm Adams")).
