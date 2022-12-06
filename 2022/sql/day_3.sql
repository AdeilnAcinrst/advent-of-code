BEGIN;

CREATE EXTENSION file_fdw;

CREATE SERVER advent_of_code FOREIGN DATA WRAPPER file_fdw;

CREATE FOREIGN TABLE rucksacks (
 priorities text
) SERVER advent_of_code
OPTIONS (filename '../../sample/rucksacks.txt', format 'csv');

CREATE FUNCTION priority_value(p char)
RETURNS smallint
IMMUTABLE AS $f$
 SELECT n
 FROM REGEXP_SPLIT_TO_TABLE('abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ', '\s*') WITH ORDINALITY AS l (x, n)
 WHERE
  x = p
$f$ LANGUAGE SQL;

SELECT SUM(priority_value(
        (SELECT REGEXP_SPLIT_TO_TABLE(LEFT(priorities, LENGTH(priorities) / 2), '\s*')
         INTERSECT
	 SELECT REGEXP_SPLIT_TO_TABLE(RIGHT(priorities, LENGTH(priorities) / 2),'\s*')))
       )
FROM rucksacks;

SELECT SUM(priority_value(
        (SELECT REGEXP_SPLIT_TO_TABLE(elf_group[1], '\s*')
         INTERSECT
	 SELECT REGEXP_SPLIT_TO_TABLE(elf_group[2], '\s*')
         INTERSECT
	 SELECT REGEXP_SPLIT_TO_TABLE(elf_group[3], '\s*')))
       )
FROM (SELECT ARRAY_AGG(priorities) AS elf_group
      FROM (SELECT priorities, ROW_NUMBER() OVER ()
      	    FROM rucksacks) AS numbered
      GROUP BY (row_number - 1) / 3) AS grouped;

ROLLBACK;
