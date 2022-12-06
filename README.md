# advent-of-code

Advent of Code Resolutions in programming languages I like

[SQL]

To run the SQL scripts it was used a PostgreSQL 15 instance.
It can be setup inside the sql directory (using Debian):

/usr/lib/postgresql/15/bin/initdb -D db
sed -i -e "s.unix_socket_directories = '/[^']+'.unix_socket_directories = '/tmp'." db/postgresql.conf
/usr/lib/postgresql/15/bin/pg_ctl start -D db/ -l db/postgresql.log
createdb adventofcode -h localhost

To run a script, also inside sql directory:

psql adventofcode -h localhost -f day_1.sql
