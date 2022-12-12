BEGIN;

CREATE EXTENSION file_fdw;
CREATE SERVER advent_of_code FOREIGN DATA WRAPPER file_fdw;

/* WORKAROUND: table bloat when updating the temp tables
   We need to setup a memcached server on your localhost and update data in it */

CREATE EXTENSION pgmemcache;
SELECT memcache_server_add('localhost');

CREATE FOREIGN TABLE monkey_rules (
 line text
) SERVER advent_of_code
OPTIONS (filename '../../sample/monkeys_rules.txt');

CREATE TEMP TABLE monkeys AS
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
       (ARRAY_AGG(REGEXP_SUBSTR(line, '[0-9]+')) FILTER (WHERE line LIKE '  Test:%'))[1]::integer AS divisible_by,
       (ARRAY_AGG(REGEXP_SUBSTR(line, '[0-9]+')) FILTER (WHERE line LIKE '    If true:%'))[1]::integer AS throw_to_if_true,
       (ARRAY_AGG(REGEXP_SUBSTR(line, '[0-9]+')) FILTER (WHERE line LIKE '    If false:%'))[1]::integer AS throw_to_if_false,
       0::bigint AS inspect_count
FROM monkeys
GROUP BY line_number / 7;

SELECT COUNT(*) AS monkeys_cached
FROM monkeys
CROSS JOIN LATERAL memcache_set(FORMAT('monkey_%s', monkey_id), monkeys::text);

CREATE TEMP TABLE items AS
SELECT
 ROW_NUMBER() OVER () AS item_id,
 monkey_id,
 worry_level
FROM monkeys
CROSS JOIN LATERAL UNNEST(monkeys.items_worry_levels) AS worry_level;

SELECT COUNT(*) AS items_cached
FROM items
CROSS JOIN LATERAL memcache_set(FORMAT('item_%s', item_id), items::text);

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
 least_common_multiple integer;
BEGIN
 SELECT product(DISTINCT divisible_by) INTO least_common_multiple FROM monkeys; -- only primes were given, just multiply them
 FOR round IN 1..rounds
 LOOP
  FOR monkey IN SELECT ((memcache_get(FORMAT('monkey_%s', monkey_id)))::monkeys).* FROM monkeys ORDER BY monkey_id
  LOOP
   FOR item IN SELECT cached_items.*
       	       FROM items
	       CROSS JOIN LATERAL CAST(memcache_get(FORMAT('item_%s', item_id)) AS items) AS cached_items
	       WHERE cached_items.monkey_id = monkey.monkey_id
   LOOP
    EXECUTE monkey.operation USING item.worry_level INTO new_level;
    new_level = (new_level / worry_level_decay) % least_common_multiple;
    IF new_level % monkey.divisible_by = 0
    THEN
     item.monkey_id = monkey.throw_to_if_true;
     item.worry_level = new_level;
    ELSE
     item.monkey_id = monkey.throw_to_if_false;
     item.worry_level = new_level;
    END IF;
    PERFORM memcache_set(FORMAT('item_%s', item.item_id), item::text);
    monkey.inspect_count = monkey.inspect_count + 1;
   END LOOP;
   PERFORM memcache_set(FORMAT('monkey_%s', monkey.monkey_id), monkey::text);
  END LOOP;
 END LOOP;
 RETURN (SELECT ((memcache_get(FORMAT('monkey_%s', monkey_id)))::monkeys).inspect_count
 	 FROM monkeys ORDER BY inspect_count DESC LIMIT 1)
        * (SELECT ((memcache_get(FORMAT('monkey_%s', monkey_id)))::monkeys).inspect_count
	   FROM monkeys ORDER BY inspect_count DESC OFFSET 1 LIMIT 1);
END
$f$ LANGUAGE plpgsql;

SELECT monkey_business(20, 3);

SELECT COUNT(*) AS monkeys_cached
FROM monkeys
CROSS JOIN LATERAL memcache_set(FORMAT('monkey_%s', monkey_id), monkeys::text);

SELECT COUNT(*) AS items_cached
FROM items
CROSS JOIN LATERAL memcache_set(FORMAT('item_%s', item_id), items::text);

SELECT monkey_business(10000, 1);

ROLLBACK;
