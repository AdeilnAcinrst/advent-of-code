BEGIN;

CREATE EXTENSION file_fdw;

CREATE SERVER advent_of_code FOREIGN DATA WRAPPER file_fdw;

CREATE FOREIGN TABLE monkey_rules (
 line text
) SERVER advent_of_code
OPTIONS (filename '../../sample/monkeys_rules.txt');

CREATE UNLOGGED TABLE monkeys AS
WITH
 monkeys AS (
  SELECT ROW_NUMBER() OVER () - 1 AS line_number,
  	 line
  FROM monkey_rules
 )
SELECT line_number / 7 AS monkey_id,
       STRING_TO_ARRAY((ARRAY_AGG(REGEXP_SUBSTR(line, '[0-9].+$')) FILTER (WHERE line LIKE '  Starting items:%'))[1], ', ')::bigint[] AS items_worry_levels,
       REGEXP_REPLACE(
        REGEXP_REPLACE(
         (ARRAY_AGG(REGEXP_SUBSTR(line, ' = .+$')) FILTER (WHERE line LIKE '  Operation:%'))[1], 'old', '$1', 'g'),
	' = ', 'SELECT '
       ) AS operation,
       (ARRAY_AGG(REGEXP_SUBSTR(line, '[0-9]+')) FILTER (WHERE line LIKE '  Test:%'))[1]::bigint AS divisible_by,
       (ARRAY_AGG(REGEXP_SUBSTR(line, '[0-9]+')) FILTER (WHERE line LIKE '    If true:%'))[1]::int AS throw_to_if_true,
       (ARRAY_AGG(REGEXP_SUBSTR(line, '[0-9]+')) FILTER (WHERE line LIKE '    If false:%'))[1]::int AS throw_to_if_false,
       0::bigint AS inspect_count
FROM monkeys
GROUP BY line_number / 7;

CREATE UNLOGGED TABLE items AS
SELECT
 ROW_NUMBER() OVER () AS item_id,
 monkey_id,
 worry_level
FROM monkeys
CROSS JOIN LATERAL UNNEST(monkeys.items_worry_levels) AS worry_level;

CREATE AGGREGATE product(bigint)
(
 SFUNC = int8mul,
 STYPE = int8
);

CREATE FUNCTION monkey_business(rounds integer, worry_level_decay integer)
RETURNS bigint AS
$f$
DECLARE
 monkey record;
 item record;
 new_level bigint;
 modulo bigint;
BEGIN
 SELECT product(DISTINCT divisible_by) INTO modulo FROM monkeys;
 FOR round IN 1..rounds
 LOOP
  FOR monkey IN SELECT * FROM monkeys ORDER BY monkey_id
  LOOP
   FOR item IN SELECT * FROM items WHERE monkey_id = monkey.monkey_id
   LOOP
    EXECUTE monkey.operation USING item.worry_level INTO new_level;
    new_level = (new_level / worry_level_decay) % modulo;
    IF new_level % monkey.divisible_by = 0
    THEN
     UPDATE items SET monkey_id = monkey.throw_to_if_true, worry_level = new_level WHERE item_id = item.item_id;
    ELSE
     UPDATE items SET monkey_id = monkey.throw_to_if_false, worry_level = new_level WHERE item_id = item.item_id;
    END IF;
    UPDATE monkeys SET inspect_count = inspect_count + 1 WHERE monkey_id = monkey.monkey_id;
   END LOOP;
  END LOOP;
  IF round IN (1,20,1000,2000,3000,4000,5000,6000,7000,8000,9000,10000)
  THEN
   RAISE NOTICE 'round: % at %', round, clock_timestamp();
   FOR monkey IN SELECT * FROM monkeys ORDER BY monkey_id
   LOOP
    RAISE NOTICE 'monkey % inspected %', monkey.monkey_id, monkey.inspect_count;
   END LOOP;
  END IF;
 END LOOP;
 RETURN (SELECT inspect_count FROM monkeys ORDER BY inspect_count DESC LIMIT 1)
        * (SELECT inspect_count FROM monkeys ORDER BY inspect_count DESC OFFSET 1 LIMIT 1);
END
$f$ LANGUAGE plpgsql;

--SELECT monkey_business(20, 3);

SELECT monkey_business(10000, 1);

ROLLBACK;
