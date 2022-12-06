BEGIN;

CREATE EXTENSION file_fdw;

CREATE SERVER advent_of_code FOREIGN DATA WRAPPER file_fdw;

CREATE FOREIGN TABLE communication_stream (
 stream text
) SERVER advent_of_code
OPTIONS (filename '../../sample/communication_stream.txt', format 'csv');

WITH
 quads AS (
  SELECT stream,
  	 n,
	 ARRAY_AGG(c) OVER (PARTITION BY stream ORDER BY n ROWS BETWEEN 3 PRECEDING AND CURRENT ROW) AS chars
  FROM (SELECT stream, c[1] AS c, n
        FROM communication_stream
	CROSS JOIN REGEXP_MATCHES(stream, '(.)', 'g') WITH ORDINALITY AS chars (c, n)) AS split_stream
 )
SELECT DISTINCT ON (stream)
       stream,
       n,
       chars
FROM quads
WHERE (SELECT COUNT(DISTINCT c) FROM UNNEST(chars) AS c) = 4;

WITH
 tenquads AS (
  SELECT stream,
  	 n,
	 ARRAY_AGG(c) OVER (PARTITION BY stream ORDER BY n ROWS BETWEEN 13 PRECEDING AND CURRENT ROW) AS chars
  FROM (SELECT stream, c[1] AS c, n
        FROM communication_stream
	CROSS JOIN REGEXP_MATCHES(stream, '(.)', 'g') WITH ORDINALITY AS chars (c, n)) AS split_stream
 )
SELECT DISTINCT ON (stream)
       stream,
       n,
       chars
FROM tenquads
WHERE (SELECT COUNT(DISTINCT c) FROM UNNEST(chars) AS c) = 14;

ROLLBACK;
