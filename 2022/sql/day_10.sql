BEGIN;

CREATE EXTENSION file_fdw;

CREATE SERVER advent_of_code FOREIGN DATA WRAPPER file_fdw;

CREATE FOREIGN TABLE cpu_instructions (
 command text
) SERVER advent_of_code
OPTIONS (filename '../../sample/cpu_instructions.txt');

CREATE TABLE cycle_strengths AS
WITH
 ordered_instructions AS (
  SELECT
   command,
   ROW_NUMBER() OVER () AS cycle_number,
   CASE
    WHEN LAG(command) OVER () LIKE 'addx%' AND LAG(instruction_cycle) OVER () = 2
     THEN REGEXP_SUBSTR(LAG(command) OVER (), '(-*\d+)')
   END::int AS stack
  FROM cpu_instructions
  CROSS JOIN LATERAL GENERATE_SERIES(1, CASE WHEN command = 'noop' THEN 1 ELSE 2 END) AS instruction_cycle
 )
SELECT command,
       cycle_number,
       SUM(
        CASE
	 WHEN cycle_number = 1 THEN 1
	 ELSE stack
	END
       ) OVER (ORDER BY cycle_number) AS signal_strength
FROM ordered_instructions;

SELECT SUM(cycle_number * signal_strength) AS signal_strength_sum
FROM cycle_strengths
WHERE cycle_number IN (20,60,100,140,180,220);

SELECT
 (cycle_number - 1) / 40 AS row,
 STRING_AGG(
  CASE
   WHEN (cycle_number - 1) % 40 BETWEEN signal_strength - 1 AND signal_strength + 1 THEN '#'
   ELSE '.'
  END,
  '' ORDER BY (cycle_number - 1) % 40
 ) AS line
FROM cycle_strengths
GROUP BY row;

ROLLBACK;
