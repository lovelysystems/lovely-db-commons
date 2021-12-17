create schema if not exists t;
grant usage on schema t to public;

create or replace function t.eq(expected anyelement,
                                actual anyelement,
                                hint text default '') returns void as
$$
begin
    if (expected is distinct from actual) then
        raise exception E'not equal:\nexpected: % \nactual: %', expected, actual
            using hint = hint;
    end if;
end
$$ language plpgsql immutable;


-- explicit override for comparing number values without casting explicitly
create or replace function t.eq(expected integer,
                                actual bigint,
                                hint text default '') returns void as
$$
select t.eq(expected::bigint, actual, hint)
$$ language sql immutable;

-- explicit override for comparing json values since
-- there is no json=json operator
create or replace function t.eq(expected json,
                                actual json,
                                hint text default '') returns void as
$$
select t.eq(expected::jsonb, actual::jsonb, hint)
$$ language sql immutable;

create or replace function t.raises(stmt text, msg_pattern text default null, hint text default '') returns void as
$$
declare
    ex_message text;
    ex_detail  text;
    ex_hint    text;
begin
    begin
        execute stmt;
        --perform stmt;
    EXCEPTION
        WHEN OTHERS then
            GET STACKED DIAGNOSTICS
                ex_message = MESSAGE_TEXT,
                ex_detail = PG_EXCEPTION_DETAIL,
                ex_hint = PG_EXCEPTION_HINT;

            if nullif(msg_pattern, '') is not null and (ex_message not like msg_pattern) then
                raise 'exception "%" raised instead of "%"', ex_message, msg_pattern;
            end if;
            return;
    end;
    if nullif(msg_pattern, '') is not null then
        raise 'exception "%" not raised', msg_pattern using hint = hint;
    else
        raise 'exception not raised' using hint = hint;
    end if;
end;
$$ language plpgsql volatile;

comment on function t.raises is E'
Assert that the given sql statement raises an exception.
The optional message pattern gets compared against the error message using LIKE';

create or replace function t.denied(stmt text, hint text default '') returns void as
$$
select t.raises(stmt, 'permission denied%', hint);
$$ language sql volatile;

comment on function t.denied is
    E'Assert that the given sql statement raises a permission denied exception.';