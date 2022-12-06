BEGIN;

CREATE EXTENSION file_fdw;

CREATE SERVER advent_of_code FOREIGN DATA WRAPPER file_fdw;

CREATE FOREIGN TABLE rps_strategy (
 him char,
 me char
) SERVER advent_of_code
OPTIONS (filename '../../sample/strategy_guide.txt', FORMAT 'csv', DELIMITER ' ');

CREATE TYPE rps_type AS ENUM ('Rock', 'Paper', 'Scissor');
CREATE TYPE rps_result AS ENUM ('Loss', 'Draw', 'Win');

CREATE FUNCTION rps_type_cast (c char)
RETURNS rps_type
IMMUTABLE
AS $f$
SELECT CASE
        WHEN c IN ('A','X') THEN 'Rock'
	WHEN c IN ('B','Y') THEN 'Paper'
	WHEN c IN ('C','Z') THEN 'Scissor'
       END::rps_type
$f$ LANGUAGE SQL;

CREATE CAST (char AS rps_type) WITH FUNCTION rps_type_cast AS IMPLICIT;

CREATE FUNCTION rps_result_cast (c char)
RETURNS rps_result
IMMUTABLE
AS $f$
SELECT CASE c
        WHEN 'X' THEN 'Loss'
	WHEN 'Y' THEN 'Draw'
	WHEN 'Z' THEN 'Win'
       END::rps_result
$f$ LANGUAGE SQL;

CREATE CAST (char AS rps_result) WITH FUNCTION rps_result_cast AS ASSIGNMENT;

CREATE FUNCTION rps_score(him rps_type, me rps_type)
RETURNS smallint
IMMUTABLE AS $f$
 SELECT CASE me WHEN 'Rock' THEN 1 WHEN 'Paper' THEN 2 WHEN 'Scissor' THEN 3 END
 	+ CASE
	   WHEN (him, me) IN (('Rock','Paper'),('Paper','Scissor'),('Scissor','Rock')) THEN 6
	   WHEN him = me THEN 3
	   ELSE 0
	  END
$f$ LANGUAGE SQL;

CREATE FUNCTION rps_score(him rps_type, me rps_result)
RETURNS smallint
IMMUTABLE AS $f$
 SELECT CASE me WHEN 'Loss' THEN 0 WHEN 'Draw' THEN 3 WHEN 'Win' THEN 6 END
 	+ CASE
	   WHEN (him, me) IN (('Rock','Draw'),('Scissor','Win'), ('Paper','Loss')) THEN 1
	   WHEN (him, me) IN (('Rock','Win'), ('Scissor','Loss'),('Paper','Draw')) THEN 2
	   WHEN (him, me) IN (('Rock','Loss'),('Scissor','Draw'),('Paper','Win'))  THEN 3
	  END
$f$ LANGUAGE SQL;

SELECT SUM(rps_score(him, me)) FROM rps_strategy;

SELECT SUM(rps_score(him, CAST(me AS rps_result))) FROM rps_strategy;

ROLLBACK;
