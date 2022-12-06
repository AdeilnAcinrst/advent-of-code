BEGIN;

CREATE EXTENSION file_fdw;

CREATE SERVER advent_of_code FOREIGN DATA WRAPPER file_fdw;

CREATE FOREIGN TABLE assignments (
 section_a text,
 section_b text
) SERVER advent_of_code
OPTIONS (filename '../../sample/assignments.txt', format 'csv');

CREATE FUNCTION section_to_range(sections text)
RETURNS numrange
IMMUTABLE
AS $f$
 SELECT numrange(r[1]::numeric, r[2]::numeric, '[]')
   FROM STRING_TO_ARRAY(sections, '-') AS r
$f$ LANGUAGE SQL;

CREATE CAST (text AS numrange) WITH FUNCTION section_to_range AS ASSIGNMENT;

SELECT COUNT(*)
  FROM assignments
 WHERE CAST(section_a AS numrange) @> CAST(section_b AS numrange) OR
       CAST(section_a AS numrange) <@ CAST(section_b AS numrange);

SELECT COUNT(*)
  FROM assignments
 WHERE CAST(section_a AS numrange) && CAST(section_b AS numrange);

ROLLBACK;
