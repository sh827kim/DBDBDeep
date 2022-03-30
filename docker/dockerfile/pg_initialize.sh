#!/bin/bash

FILE="/var/lib/pgsql/14/data/postgresql.auto.conf"

__init_postgres() {
localectl set-locale LANG=en_US.UTF-8
if [ ! -e $FILE ]; then
  chown -v postgres.postgres /pgconf/postgresql.conf
  chown -v postgres.postgres /pgconf/pg_hba.conf
  /usr/pgsql-14/bin/postgresql-14-setup initdb
  rm -rf /var/lib/pgsql/14/data/pg_hba.conf
  rm -rf /var/lib/pgsql/14/data/postgresql.conf
  mv /pgconf/pg_hba.conf /var/lib/pgsql/14/data/
  mv /pgconf/postgresql.conf /var/lib/pgsql/14/data/
fi
systemctl enable postgresql-14
systemctl start postgresql-14
}


__init_postgres

