#!/bin/sh

export PATH=/Applications/Postgres.app/Contents/Versions/15/bin:$PATH
psql -f part0.sql
psql -f part1_1_config.sql
psql -f part1_2_constraints.sql
psql -f part1_3_tables.sql
psql -f part1_4_utils.sql
psql -f part2_1_customers.sql
psql -f part2_2_purchase_history.sql
psql -f part2_3_periods.sql
psql -f part2_4_groups.sql
psql -f part3.sql
psql -f part4.sql
psql -f part5.sql
#psql -f part6.sql
