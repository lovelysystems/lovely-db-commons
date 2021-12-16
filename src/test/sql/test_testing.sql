-- test exception assertions

create function raise_ex() returns void as
$$
begin
    raise 'my_exception' using hint = 'my hint';
end;
$$ language plpgsql stable;


-- does not fail if exception is raised
select t.raises('select raise_ex();');

-- use msg to test for a certain error message
select t.raises('select raise_ex();', 'my_exception', 'catches the correct exception');

-- set msg to null if you don't care about msg
select t.raises('select raise_ex();', null, 'just assert any exception is raised');

-- test w/o hint
select t.raises('select raise_ex();', 'my_exception');


-- raises error if exception is not raised
select t.raises(
               $$select t.raises('select 1;')$$,
               'exception not raised'
           );

-- raises error if specific exception is not raised
select t.raises(
               $$select t.raises('select 1;', 'expected_exception')$$,
               'exception "expected_exception" not raised'
           );
select t.raises(
               $$select t.raises('select raise_ex();', 'expected_exception')$$,
               'exception "my_exception" raised instead of "expected_exception"'
           );

drop function raise_ex;


-- test equality assertions

select t.raises('select t.eq(1,2);', null, 'should raise since numers are not equal');

-- numerics
select t.eq(1, 1, 'identical numerics should be equal');
select t.eq(1, 1::bigint, 'comparing to bigint with an int is possible');

-- json to json comparison
select t.eq('{}'::json, '{}'::json, 'json values (not only jsonb) can be compared');
