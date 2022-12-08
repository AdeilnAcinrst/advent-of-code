BEGIN;

CREATE EXTENSION file_fdw;

CREATE SERVER advent_of_code FOREIGN DATA WRAPPER file_fdw;

CREATE FOREIGN TABLE tree_heights (
 tree_row text
) SERVER advent_of_code
OPTIONS (filename '../../data/tree_heights.txt');

CREATE TABLE forest AS
WITH
 forest_rows AS (
  SELECT tree_row,
  	 ROW_NUMBER() OVER () AS r
  FROM tree_heights
 ),
 forest_grid AS (
  SELECT r,
  	 c,
	 height[1]::int
  FROM forest_rows
  CROSS JOIN REGEXP_MATCHES(tree_row, '(.)', 'g') WITH ORDINALITY AS trees (height, c)
 )
SELECT r,
       c,
       height,
       COALESCE(height > ALL(ARRAY_AGG(height) OVER (PARTITION BY c ORDER BY r ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING)), true) OR -- heights_from_the_top
       COALESCE(height > ALL(ARRAY_AGG(height) OVER (PARTITION BY c ORDER BY r DESC ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING)), true) OR -- heights_from_the_bottom
       COALESCE(height > ALL(ARRAY_AGG(height) OVER (PARTITION BY r ORDER BY c ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING)), true) OR -- heights_from_the_left
       COALESCE(height > ALL(ARRAY_AGG(height) OVER (PARTITION BY r ORDER BY c DESC ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING)), true) -- heights_from_the_right
       AS visible
FROM forest_grid;

SELECT r,
       c,
       FORMAT('%1s%1s', height, CASE WHEN visible THEN '*' END)
FROM forest \crosstabview

SELECT COUNT(*) FROM forest WHERE visible;

CREATE FUNCTION array_rev(xs anyarray)
RETURNS anyarray
IMMUTABLE AS $f$
SELECT ARRAY_AGG(x ORDER BY n DESC)
FROM UNNEST(xs) WITH ORDINALITY AS numbered_xs (x, n)
$f$ LANGUAGE SQL;

CREATE FUNCTION view_score(tree_heights int[])
RETURNS int
IMMUTABLE AS $f$
WITH
 tree_view AS (
  SELECT distance - 1 AS distance,
  	 MAX(height) OVER (ORDER BY distance) AS max_height
  FROM UNNEST(tree_heights) WITH ORDINALITY AS heights (height, distance)
  WHERE distance > 1
 )
SELECT LEAST(
        (SELECT distance
	 FROM tree_view
	 WHERE max_height >= tree_heights[1]
	 ORDER BY distance
	 LIMIT 1),
	(SELECT distance
	 FROM tree_view
	 WHERE max_height = (SELECT MAX(max_height) FROM tree_view)
	 ORDER BY distance DESC
	 LIMIT 1)
       )
$f$ LANGUAGE SQL;

WITH
 tree_scores AS (
  SELECT r,
  	 c,
         COALESCE(view_score(array_rev(ARRAY_AGG(height) OVER (PARTITION BY c ORDER BY r))),0) *
         COALESCE(view_score(array_rev(ARRAY_AGG(height) OVER (PARTITION BY r ORDER BY c))),0) *
         COALESCE(view_score(array_rev(ARRAY_AGG(height) OVER (PARTITION BY c ORDER BY r DESC))),0) *
         COALESCE(view_score(array_rev(ARRAY_AGG(height) OVER (PARTITION BY r ORDER BY c DESC))),0) AS scene_score
  FROM forest
 )
SELECT MAX(scene_score) AS max_scene_score
FROM tree_scores;

ROLLBACK;
