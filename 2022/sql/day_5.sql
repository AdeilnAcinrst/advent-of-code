BEGIN;

CREATE EXTENSION file_fdw;

CREATE SERVER advent_of_code FOREIGN DATA WRAPPER file_fdw;

CREATE FOREIGN TABLE crate_state_and_plan (
 line text
) SERVER advent_of_code
OPTIONS (filename '../../sample/crate_stacks.txt', format 'csv');

CREATE TEMP TABLE crate_state_and_plan_numbered_and_classified AS
SELECT line,
       ROW_NUMBER() OVER (),
       NULL::text AS type
FROM crate_state_and_plan;

WITH divide AS (SELECT row_number AS blank_line_number
     	        FROM crate_state_and_plan_numbered_and_classified
		WHERE line IS NULL)
UPDATE crate_state_and_plan_numbered_and_classified
   SET type = CASE
       	       WHEN row_number > blank_line_number THEN 'procedure'
	       WHEN row_number = blank_line_number THEN 'divide'
	       WHEN row_number < blank_line_number - 1 THEN 'stacks'
	       WHEN row_number = blank_line_number - 1 THEN 'stack numbers'
	      END
  FROM divide;

CREATE TEMP TABLE crate_stacks AS
SELECT stack_number,
       SUBSTRING(line, 4 * (stack_number - 1) + 2, 1) AS crate,
       ROW_NUMBER() OVER (PARTITION BY stack_number ORDER BY row_number DESC) AS pile_number
FROM crate_state_and_plan_numbered_and_classified
CROSS JOIN GENERATE_SERIES(
      	    1,
	    (SELECT UNNEST(REGEXP_MATCHES(line, '\d', 'g')::int[]) AS stack_number
	     FROM crate_state_and_plan_numbered_and_classified
	     WHERE type = 'stack numbers'
	     ORDER BY stack_number DESC
	     LIMIT 1)
	   ) AS stack_number
WHERE type = 'stacks' AND
      SUBSTRING(line, 4 * (stack_number - 1) + 2, 1) <> ' ';

SELECT pile_number, stack_number, crate
FROM crate_stacks
ORDER BY pile_number, stack_number \crosstabview

SAVEPOINT cratemover_9000;

CREATE FUNCTION move_crate(from_stack int, to_stack int)
RETURNS void
AS $f$
UPDATE crate_stacks
   SET stack_number = to_stack,
       pile_number = COALESCE((SELECT MAX(pile_number) + 1
       		    	       FROM crate_stacks
			       WHERE stack_number = to_stack), 1)
 WHERE stack_number = from_stack AND
       pile_number = (SELECT MAX(pile_number)
       		      FROM crate_stacks
		      WHERE stack_number = from_stack)
$f$ LANGUAGE SQL;

WITH
 movement_ordered AS (
  SELECT REGEXP_MATCH(SUBSTRING(line FROM POSITION('from' IN line)), '(\d) to (\d)')::int[] AS movement
  FROM crate_state_and_plan_numbered_and_classified
  CROSS JOIN LATERAL GENERATE_SERIES(1, REGEXP_SUBSTR(line, '\d+')::int)
  WHERE type = 'procedure'
  ORDER BY row_number
 )
SELECT move_crate(movement[1], movement[2])
FROM movement_ordered;

SELECT pile_number, stack_number, crate
FROM crate_stacks
ORDER BY pile_number, stack_number \crosstabview

SELECT QUOTE_LITERAL(STRING_AGG(crate, '' ORDER BY stack_number)) AS top_crates
FROM (SELECT DISTINCT ON (stack_number)
     	     stack_number,
	     COALESCE(crate, ' ') AS crate
      FROM GENERATE_SERIES(
      	    1,
	    (SELECT UNNEST(REGEXP_MATCHES(line, '\d', 'g')::int[]) AS stack_number
	     FROM crate_state_and_plan_numbered_and_classified
	     WHERE type = 'stack numbers'
	     ORDER BY stack_number DESC
	     LIMIT 1)
	   ) AS stack_number
      LEFT JOIN crate_stacks USING (stack_number)
      ORDER BY stack_number,
      	       pile_number DESC) AS top_crates;

ROLLBACK TO cratemover_9000;

CREATE FUNCTION move_stack(from_stack int, to_stack int, crates int)
RETURNS void
AS $f$
WITH
 destination_pile_number AS (
  SELECT MAX(pile_number) AS pile_number
  FROM crate_stacks
  WHERE stack_number = to_stack
 ),
 origin_remaining_pile_number AS (
  SELECT MAX(pile_number) - crates AS pile_number
  FROM crate_stacks
  WHERE stack_number = from_stack
 )
UPDATE crate_stacks
   SET stack_number = to_stack,
       pile_number = crate_stacks.pile_number
       		      - origin_remaining_pile_number.pile_number
		      + COALESCE(destination_pile_number.pile_number, 0)
  FROM destination_pile_number,
       origin_remaining_pile_number
 WHERE stack_number = from_stack AND
       crate_stacks.pile_number > origin_remaining_pile_number.pile_number
$f$ LANGUAGE SQL;

WITH
 movement_ordered AS (
  SELECT REGEXP_MATCH(line, 'move (\d+) from (\d+) to (\d+)')::int[] AS movement
  FROM crate_state_and_plan_numbered_and_classified
  WHERE type = 'procedure'
  ORDER BY row_number
 )
SELECT move_stack(movement[2], movement[3], movement[1])
FROM movement_ordered;

SELECT pile_number, stack_number, crate
FROM crate_stacks
ORDER BY pile_number, stack_number \crosstabview

SELECT QUOTE_LITERAL(STRING_AGG(crate, '' ORDER BY stack_number)) AS top_crates
FROM (SELECT DISTINCT ON (stack_number)
     	     stack_number,
	     COALESCE(crate, ' ') AS crate
      FROM GENERATE_SERIES(
      	    1,
	    (SELECT UNNEST(REGEXP_MATCHES(line, '\d', 'g')::int[]) AS stack_number
	     FROM crate_state_and_plan_numbered_and_classified
	     WHERE type = 'stack numbers'
	     ORDER BY stack_number DESC
	     LIMIT 1)
	   ) AS stack_number
      LEFT JOIN crate_stacks USING (stack_number)
      ORDER BY stack_number,
      	       pile_number DESC) AS top_crates;

ROLLBACK;
