BEGIN;

CREATE EXTENSION file_fdw;

CREATE SERVER advent_of_code FOREIGN DATA WRAPPER file_fdw;

CREATE FOREIGN TABLE elves_items (
 cal numeric
) SERVER advent_of_code
OPTIONS (filename '../../sample/elves_items.txt', FORMAT 'csv');

CREATE FUNCTION elves_stock_rollup(stock numeric[], item numeric, top int)
RETURNS numeric[]
AS $f$
 SELECT
  CASE
   WHEN stock IS NULL THEN ARRAY[item] -- first item
   WHEN item IS NULL THEN (SELECT ARRAY_AGG(greatest_stock)
   	     	     	   FROM (SELECT greatest_stock
			   	 FROM UNNEST(stock) AS greatest_stock
				 ORDER BY greatest_stock DESC
				 LIMIT top) AS stock_ordered) || ARRAY[0] -- new elf
   ELSE COALESCE(TRIM_ARRAY(stock, 1), '{}')
   	 || ARRAY[stock[ARRAY_LENGTH(stock,1)] + item] -- add item
  END
$f$ LANGUAGE SQL;

CREATE FUNCTION elves_stock_sum(stock numeric[])
RETURNS numeric
AS $f$
 SELECT SUM(ordered_stock)
 FROM (SELECT ordered_stock
       FROM UNNEST(stock) AS ordered_stock
       ORDER BY ordered_stock DESC
       LIMIT ARRAY_LENGTH(stock, 1) - 1) AS remove_smallest
$f$ LANGUAGE SQL;

CREATE AGGREGATE elves_stock(numeric, int)
(
 SFUNC = elves_stock_rollup,
 STYPE = numeric[],
 FINALFUNC = elves_stock_sum
);

SELECT elves_stock(cal, 1) AS stock
FROM elves_items;

SELECT elves_stock(cal, 3) AS stock
FROM elves_items;

ROLLBACK;
