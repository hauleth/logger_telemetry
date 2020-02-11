-module(logger_telemetry).

-export([attach/1]).

-export([log/2]).

%% @doc
%% Register domains which should fire Telemetry events.
%% @end
attach(Domains) ->
    try
        DomainFilters = [match_domain(Domain) || Domain <- Domains],
        Config = #{level => all,
                   filters => DomainFilters,
                   filter_default => stop},
        case logger:add_handler(?MODULE, ?MODULE, Config) of
            {error, {already_exist, ?MODULE}} ->
                logger:set_handler_config(?MODULE, Config),
                ok;
            ok ->
                ok
        end
    catch
        throw:Term ->
            {error, Term}
    end.

match_domain({_Compare, []}) ->
    error(empty_domain);
match_domain({Compare, Domain})
  when is_list(Domain),
       (Compare =:= sub
        orelse Compare =:= super
        orelse Compare =:= equal) ->
    case check_match_domain(Domain) of
        true -> {fun logger_filters:domain/2, {log, Compare, Domain}};
        false -> error({invalid_domain, Domain})
    end;
match_domain(Domain) when is_list(Domain) ->
    match_domain({sub, Domain}).


check_match_domain([]) ->
    true;
check_match_domain([Atom | Rest]) when is_atom(Atom) ->
    check_match_domain(Rest);
check_match_domain(_) ->
    false.

%% ----------------------------------------------------------------------------
%% Logger Handler callback

%% @hidden
log(#{msg := {report, Report}, meta := #{domain := Domain} = Meta}, _Config)
  when is_list(Domain) ->
    execute(Domain, Report, Meta),
    ok;
% Ignore non-report messages, as we do not want to parse text formats
log(_LogEvent, _Config) -> ok.

execute(Domain, Report0, Meta) when is_map(Report0) ->
    Report = maps:merge(#{count => 1}, Report0),
    ok = telemetry:execute(Domain, Report, Meta);
execute(Domain, Report, Meta) when is_list(Report) ->
    ok = telemetry:execute(Domain, maps:from_list(Report), Meta).
