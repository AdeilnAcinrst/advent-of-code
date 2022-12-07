BEGIN;

CREATE EXTENSION file_fdw;

CREATE SERVER advent_of_code FOREIGN DATA WRAPPER file_fdw;

CREATE FOREIGN TABLE terminal_output (
 line text
) SERVER advent_of_code
OPTIONS (filename '../../sample/terminal_output.txt', format 'csv');

CREATE TYPE filesystem_object_type AS ENUM ('dir','file');

CREATE TEMP TABLE filesystem (
 id serial PRIMARY KEY,
 name text NOT NULL,
 type filesystem_object_type NOT NULL,
 size integer,
 parent integer,
 tree integer[]
);

INSERT INTO filesystem (name, type, tree) VALUES ('/', 'dir', ARRAY[CURRVAL('filesystem_id_seq')]);

CREATE FUNCTION insert_file (_name text, _size integer, _type filesystem_object_type, _parent integer)
RETURNS integer
AS $f$
INSERT INTO filesystem (name, size, type, parent, tree)
VALUES (_name, _size, _type, _parent, (SELECT tree FROM filesystem WHERE id = _parent) || ARRAY[CURRVAL('filesystem_id_seq')])
RETURNING _parent
$f$ LANGUAGE SQL;

CREATE FUNCTION insert_dir (_name text, _type filesystem_object_type, _parent integer)
RETURNS integer
AS $f$
INSERT INTO filesystem (name, type, parent, tree)
VALUES (_name, _type, _parent, (SELECT tree FROM filesystem WHERE id = _parent) || ARRAY[CURRVAL('filesystem_id_seq')])
RETURNING _parent
$f$ LANGUAGE SQL;

CREATE FUNCTION terminal_parser(current_dir integer, line text)
RETURNS integer
AS $f$
SELECT
 CASE
  WHEN line ~ '^\$ cd /' -- changing to root
   THEN (SELECT id FROM filesystem WHERE name = '/')
  WHEN line ~ '^\$ cd \.\.' -- changing to parent
   THEN (SELECT parent FROM filesystem WHERE id = current_dir)
  WHEN line ~ '^\$ cd' -- changing dir
   THEN (SELECT id FROM filesystem WHERE name = REGEXP_SUBSTR(line, '[^ ]+$') AND parent = current_dir)
  WHEN line ~ '^\$ ls' -- listing dir, keep current directory
   THEN current_dir
  WHEN line ~ '^dir' -- new directory found
   THEN insert_dir(REGEXP_SUBSTR(line, '[^ ]+$'), 'dir', current_dir)
  WHEN line ~ '^[0-9]+' -- new file found
   THEN insert_file(REGEXP_SUBSTR(line, '[^ ]+$'), REGEXP_SUBSTR(line, '^[0-9]+')::int, 'file', current_dir)
 END
$f$ LANGUAGE SQL;

CREATE AGGREGATE parse_output(text)
(
 SFUNC = terminal_parser,
 STYPE = integer,
 INITCOND = 1
);

SELECT parse_output(line)
FROM terminal_output;

UPDATE filesystem AS dirs
   SET size = (SELECT SUM(size)
       	       FROM filesystem AS files
	       WHERE files.type = 'file' AND
	       	     files.tree @> dirs.tree)
 WHERE type = 'dir';

SELECT SUM(size)
FROM filesystem
WHERE type = 'dir' AND
      size <= 100000;

SELECT size
FROM filesystem
WHERE type = 'dir' AND
      size >= (SELECT size - 40000000 FROM filesystem WHERE id = 1)
ORDER BY size
LIMIT 1;

ROLLBACK;
