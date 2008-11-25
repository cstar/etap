%% ChangeLog
%% - 2008-11-25 ngerakines
%%   - Consolidated test server and plan server.
%%   - Added meta information when creating new plan.
%%   - Added lots of documentation.
%%   - Cleaned up the current test suite.
%%   - Started extending testing capabilities of etap_request.
%% @author Nick Gerakines <nick@gerakines.net> [http://socklabs.com/]
%% @author Jeremy Wall <jeremy@marzhillstudios.com>
%% @version 0.3
%% @copyright 2007-2008 Jeremy Wall
%% @reference http://testanything.org/wiki/index.php/Main_Page
%% @reference http://en.wikipedia.org/wiki/Test_Anything_Protocol
%% @todo Finish implementing the skip directive.
%% @todo Document the messages handled by this receive loop.
%% @todo Explain in documentation why we use a process to handle test input.
%% @doc etap is a TAP testing module for Erlang components and applications.
%% This module allows developers to test their software using the TAP method.
%% 
%% <blockquote cite="http://en.wikipedia.org/wiki/Test_Anything_Protocol"><p>
%% TAP, the Test Anything Protocol, is a simple text-based interface between
%% testing modules in a test harness. TAP started life as part of the test
%% harness for Perl but now has implementations in C/C++, Python, PHP, Perl
%% and probably others by the time you read this.
%% </p></blockquote>
%% 
%% The testing process begins by defining a plan using etap:plan/1, running
%% a number of etap tests and then calling eta:end_tests/0. Please refer to
%% the Erlang modules in the t directory of this project for example tests.
-module(etap).
-export([
    ensure_test_server/0, start_etap_server/0, test_server/1,
    diag/1, plan/1, end_tests/0, not_ok/2, ok/2, is/3, isnt/3
]).

-record(test_state, {planned = 0, count = 0, pass = 0, fail = 0, skip = 0}).

% ---
% External / Public functions

%% @doc Create a test plan and boot strap the test server.
plan(N) when is_integer(N), N > 0 ->
    ensure_test_server(),
    etap_server ! {self(), plan, N},
    ok.

%% @doc End the current test plan and output test results.
end_tests() -> etap_server ! done.

%% @doc Print a debug/status message related to the test suite.
diag(S) -> etap_server ! {self(), log, "# " ++ S}.

%% @doc Assert that a statement is true.
ok(Expr, Desc) -> mk_tap(Expr == true, Desc).

%% @doc Assert that a statement is false.
not_ok(Expr, Desc) -> mk_tap(Expr == false, Desc).

%% @doc Assert that two values are the same.
is(Got, Expected, Desc) -> mk_tap(Got == Expected, Desc).

%% @doc Assert that two values are not the same.
isnt(Got, Expected, Desc) -> mk_tap(Got /= Expected, Desc).

% ---
% Internal / Private functions

%% @private
%% @doc Start the etap_server process if it is not running already.
ensure_test_server() ->
    case whereis(etap_server) of
        undefined ->
            proc_lib:start(?MODULE, start_etap_server,[]);
        _ ->
            diag("The test server is already running.")
    end.

%% @private
%% @doc Start the etap_server loop and register itself as the etap_server
%% process.
start_etap_server() ->
    catch register(etap_server, self()),
    proc_lib:init_ack(ok),
    etap:test_server(#test_state{}).


%% @private
%% @doc The main etap_server receive/run loop. The etap_server receive loop
%% responds to seven messages apperatining to failure or passing of tests.
%% It is also used to initiate the testing process with the {_, plan, _}
%% message that clears the current test state.
test_server(State) ->
    NewState = receive
        {_From, plan, N} ->
            io:format("1..~p~n", [N]),
            io:format("# Current time local ~s~n", [datetime(erlang:localtime())]),
            io:format("# Using etap version 0.3~n"),
            #test_state{
                planned = N, count = 0, pass = 0, fail = 0, skip = 0
            };
        {_From, pass, N} ->
            #test_state{
                count = State#test_state.count + N,
                pass = State#test_state.pass + N
            };
        {_From, fail, N} ->
            #test_state{
                count = State#test_state.count + N,
                fail = State#test_state.fail + N
            };
        {_From, skip, N} ->
            #test_state{
                count = State#test_state.count + N,
                skip = State#test_state.skip + N
            };
        {From, state} ->
            From ! State,
            State;
        {_From, log, Message} ->
            io:format("~s~n", [Message]),
            State;
        {From, count} ->
            From ! State#test_state.count,
            State;
        done ->
            io:format("Ran ~p Tests Passed: ~p Failed: ~p Skipped: ~p~n~n", [State#test_state.count, State#test_state.pass, State#test_state.fail, State#test_state.skip]),
            exit(normal)
    end,
    test_server(NewState).

%% @private
%% @doc Process the result of a test and send it to the etap_server process.
mk_tap(Result, Desc) ->
    N = lib:sendw(etap_server, count),
    case Result of
        true ->
            etap_server ! {self(), log, lists:concat(["ok ", N, " -  ",  Desc])},
            etap_server ! {self(), pass, 1};
            
        false ->
            etap_server ! {self(), log, lists:concat(["not ok ", N, " -  ",  Desc])},
            etap_server ! {self(), fail, 1}
    end.

%% @private
%% @doc Format a date/time string.
datetime(DateTime) ->
    {{Year, Month, Day}, {Hour, Min, Sec}} = DateTime,
    io_lib:format("~4.10.0B-~2.10.0B-~2.10.0B ~2.10.0B:~2.10.0B:~2.10.0B", [Year, Month, Day, Hour, Min, Sec]).
