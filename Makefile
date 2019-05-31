EXTENSION = gbdchecks
DATA = sql/gbdchecks--1.1.sql
PG_CONFIG = pg_config
PGXS := $(shell $(PG_CONFIG) --pgxs)
include $(PGXS)
