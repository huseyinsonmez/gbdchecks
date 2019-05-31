/**
*
* Bu dosyanın "CREATE EXTENSION" dışında kullanılmasını engeller.
* Düzen ve güvenilirlik açısından "CREATE EXTENSION" ile kullanmak daha yararlıdır
***/

\echo Bu dosyayi kullanmak icin lutfen "CREATE EXTENSION gbdchecks;" komutunu kullanin. \quit

---- KONTROL SORGULARI ----

-- En yavaş sorguları görüntülememizi sağlayan view (pg_stat_statements gerektirir)
CREATE OR REPLACE VIEW check_queries AS
SELECT
    substring(query, 1, 50) AS short_query,
    round(total_time::numeric, 2) AS total_time,
    calls,
    round(mean_time::numeric, 2) AS mean,
    round((100 * total_time / sum(total_time::numeric) OVER ())::numeric, 2) AS percentage_cpu
FROM pg_stat_statements
ORDER BY total_time DESC LIMIT 20;


-- Sunucudaki bloat oranlarını görüntülemek için görüntülememizi olan view
CREATE OR REPLACE VIEW check_bloat AS WITH constants AS (
    SELECT current_setting('block_size')::numeric AS bs, 23 AS hdr, 4 AS ma), bloat_info AS (
      SELECT ma, bs, schemaname, tablename, (datawidth + (hdr + ma - (
        CASE WHEN hdr % ma = 0 THEN ma ELSE hdr % ma END)))::numeric AS datahdr, (maxfracsum * (nullhdr + ma - (
          CASE WHEN nullhdr % ma = 0 THEN ma ELSE nullhdr % ma END))) AS nullhdr2 FROM (
            SELECT schemaname, tablename, hdr, ma, bs, SUM((1 - null_frac) * avg_width) AS datawidth, MAX(null_frac) AS maxfracsum, hdr + (
              SELECT 1 + count(*) / 8 FROM pg_stats s2 WHERE null_frac <> 0 AND s2.schemaname = s.schemaname AND s2.tablename = s.tablename) AS nullhdr FROM pg_stats s, constants GROUP BY 1, 2, 3, 4, 5) AS foo), table_bloat AS (
                SELECT schemaname, tablename, cc.relpages, bs, CEIL((cc.reltuples * ((datahdr + ma - (
                  CASE WHEN datahdr % ma = 0 THEN ma ELSE datahdr % ma END)) + nullhdr2 + 4)) / (bs - 20::float)) AS otta FROM bloat_info
                  JOIN pg_class cc ON cc.relname = bloat_info.tablename
                  JOIN pg_namespace nn ON cc.relnamespace = nn.oid AND nn.nspname = bloat_info.schemaname AND nn.nspname <> 'information_schema'), index_bloat AS (
                    SELECT schemaname, tablename, bs, COALESCE(c2.relname, '?') AS iname, COALESCE(c2.reltuples, 0) AS ituples, COALESCE(c2.relpages, 0) AS ipages, COALESCE(CEIL((c2.reltuples * (datahdr - 12)) / (bs - 20::float)), 0) AS iotta FROM bloat_info
                    JOIN pg_class cc ON cc.relname = bloat_info.tablename
                    JOIN pg_namespace nn ON cc.relnamespace = nn.oid AND nn.nspname = bloat_info.schemaname AND nn.nspname <> 'information_schema'
                    JOIN pg_index i ON indrelid = cc.oid
                    JOIN pg_class c2 ON c2.oid = i.indexrelid )
                    SELECT type, schemaname, object_name, bloat, pg_size_pretty(raw_waste) AS waste FROM (
                      SELECT 'table' AS type, schemaname, tablename as object_name, ROUND(
                        CASE WHEN otta = 0 THEN 0.0 ELSE table_bloat.relpages / otta::numeric END, 1) AS bloat,
                        CASE WHEN relpages < otta THEN '0' ELSE (bs * (table_bloat.relpages - otta)::bigint)::bigint END AS raw_waste FROM table_bloat
                        UNION
                        SELECT 'index' AS type, schemaname, tablename || '::' || iname as object_name, ROUND( CASE WHEN iotta = 0 OR ipages = 0 THEN 0.0 ELSE ipages / iotta::numeric END, 1) AS bloat,
                        CASE WHEN ipages < iotta THEN '0' ELSE (bs * (ipages - iotta))::bigint END AS raw_waste FROM index_bloat) bloat_summary ORDER BY raw_waste DESC, bloat DESC;


-- Engellenen sorguları görüntülememizi saglayan view
CREATE OR REPLACE VIEW check_blocked_statements AS
SELECT
    bl.pid AS blocked_pid,
    ka.query AS blocking_statement,
    now() - ka.query_start AS blocking_duration,
    kl.pid AS blocking_pid,
    a.query AS blocked_statement,
    now() - a.query_start AS blocked_duration
    FROM pg_catalog.pg_locks bl
    JOIN pg_catalog.pg_stat_activity a ON bl.pid = a.pid
    JOIN pg_catalog.pg_locks kl
    JOIN pg_catalog.pg_stat_activity ka ON kl.pid = ka.pid ON bl.transactionid = kl.transactionid
    AND bl.pid != kl.pid WHERE NOT bl.granted;


-- Hit Ratio değerlerini görütülememizi sağlayan view
CREATE OR REPLACE VIEW check_hit_ratio AS
SELECT
    sum(heap_blks_read) AS heap_read,
    sum(heap_blks_hit) AS heap_hit,
    sum(heap_blks_hit) / (sum(heap_blks_hit) + sum(heap_blks_read)) AS ratio
FROM pg_statio_user_tables;


-- Index boyutlarını görüntülememizi saglayan view
CREATE OR REPLACE VIEW check_index_sizes AS
SELECT
    c.relname AS name,
    pg_size_pretty(sum(c.relpages::bigint * 8192)::bigint) AS size
FROM pg_class c
    LEFT JOIN pg_namespace n ON (n.oid = c.relnamespace)
    WHERE n.nspname NOT IN ('pg_catalog', 'information_schema') AND n.nspname !~ '^pg_toast' AND c.relkind = 'i'
    GROUP BY c.relname ORDER BY sum(c.relpages) DESC;


-- Index kullanımını görüntülememizi saglayan view
CREATE OR REPLACE VIEW check_index_usage AS
SELECT
    relname,
    CASE idx_scan
    WHEN 0 THEN 'Insufficient data'
    ELSE (100 * idx_scan / (seq_scan + idx_scan))::text END percent_of_times_index_used, n_live_tup rows_in_table
    FROM pg_stat_user_tables ORDER BY n_live_tup DESC;


-- Lockları görüntülememizi saglayan view
CREATE OR REPLACE VIEW check_locks AS
SELECT t.relname, l.locktype, page, virtualtransaction, pid, mode, granted
FROM pg_locks l, pg_stat_all_tables t
WHERE l.relation = t.relid
ORDER BY relation asc;


-- Sequential Scan değerlerini görüntülememizi saglayan view
CREATE OR REPLACE VIEW check_seq_scans AS
SELECT relname AS name, seq_scan AS count
FROM pg_stat_user_tables
ORDER BY seq_scan DESC;


-- Kullanılmayan indexleri görüntülememizi saglayan view
CREATE OR REPLACE VIEW check_unused_indexes
AS
SELECT
    schemaname || '.' || relname AS table,
    indexrelname AS index, pg_size_pretty(pg_relation_size(i.indexrelid)) AS index_size, idx_scan AS index_scans
FROM pg_stat_user_indexes ui
    JOIN pg_index i ON ui.indexrelid = i.indexrelid
WHERE NOT indisunique AND idx_scan < 50 AND pg_relation_size(relid) > 5 * 8192
ORDER BY pg_relation_size(i.indexrelid) / nullif (idx_scan, 0) DESC NULLS FIRST, pg_relation_size(i.indexrelid) DESC;


-- Vacuum istatistiklerini görüntülememizi saglayan view
CREATE OR REPLACE VIEW check_vacuum_stats AS WITH table_opts AS (
    SELECT pg_class.oid, relname, nspname, array_to_string(reloptions, '') AS relopts
    FROM pg_class
    INNER JOIN pg_namespace ns ON relnamespace = ns.oid), vacuum_settings AS (
      SELECT oid, relname, nspname,
        CASE WHEN relopts LIKE '%autovacuum_vacuum_threshold%' THEN substring(relopts, '.*autovacuum_vacuum_threshold=([0-9.]+).*')::integer
        ELSE current_setting('autovacuum_vacuum_threshold')::integer END AS autovacuum_vacuum_threshold,
        CASE WHEN relopts LIKE '%autovacuum_vacuum_scale_factor%' THEN substring(relopts, '.*autovacuum_vacuum_scale_factor=([0-9.]+).*')::real
        ELSE current_setting('autovacuum_vacuum_scale_factor')::real END AS autovacuum_vacuum_scale_factor FROM table_opts
)
SELECT
    vacuum_settings.nspname AS schema,
    vacuum_settings.relname AS table,
    to_char(psut.last_vacuum, 'YYYY-MM-DD HH24:MI') AS last_vacuum,
    to_char(psut.last_autovacuum, 'YYYY-MM-DD HH24:MI') AS last_autovacuum,
    to_char(pg_class.reltuples, '9G999G999G999') AS rowcount,
    to_char(psut.n_dead_tup, '9G999G999G999') AS dead_rowcount,
    to_char(autovacuum_vacuum_threshold + (autovacuum_vacuum_scale_factor::numeric * pg_class.reltuples),
    '9G999G999G999') AS autovacuum_threshold,
    CASE WHEN autovacuum_vacuum_threshold + (autovacuum_vacuum_scale_factor::numeric * pg_class.reltuples) < psut.n_dead_tup THEN 'yes' END AS expect_autovacuum
    FROM pg_stat_user_tables psut
    INNER JOIN pg_class ON psut.relid = pg_class.oid
    INNER JOIN vacuum_settings ON pg_class.oid = vacuum_settings.oid
    ORDER BY 1;


---- YETKI KONTROL SORGULARI ----

-- Bir kullanıcının tablo yetkilerini görüntülememizi sağlayan fonksiyon
CREATE OR REPLACE FUNCTION table_privs(text) RETURNS table(username text, relname regclass, privileges text[])
AS
$$
  SELECT  $1,c.oid::regclass, array(select privs from unnest(ARRAY [
(CASE WHEN has_table_privilege($1,c.oid,'SELECT') THEN 'SELECT' ELSE NULL END),
(CASE WHEN has_table_privilege($1,c.oid,'INSERT') THEN 'INSERT' ELSE NULL END),
(CASE WHEN has_table_privilege($1,c.oid,'UPDATE') THEN 'UPDATE' ELSE NULL END),
(CASE WHEN has_table_privilege($1,c.oid,'DELETE') THEN 'DELETE' ELSE NULL END),
(CASE WHEN has_table_privilege($1,c.oid,'TRUNCATE') THEN 'TRUNCATE' ELSE NULL END),
(CASE WHEN has_table_privilege($1,c.oid,'REFERENCES') THEN 'REFERENCES' ELSE NULL END),
(CASE WHEN has_table_privilege($1,c.oid,'TRIGGER') THEN 'TRIGGER' ELSE NULL END)]) foo(privs) WHERE privs IS NOT NULL) FROM pg_class c JOIN pg_namespace n on c.relnamespace=n.oid where n.nspname not in ('information_schema','pg_catalog','sys')  and c.relkind='r' and
has_table_privilege($1,c.oid,'SELECT, INSERT,UPDATE,DELETE,TRUNCATE,REFERENCES,TRIGGER') AND has_schema_privilege($1,c.relnamespace,'USAGE')
$$ LANGUAGE SQL;


-- Bir kullanıcının veritabanı yetkilerini görüntülememizi sağlayan fonksiyon
CREATE OR REPLACE FUNCTION database_privs(text) RETURNS table(username text, dbname name, privileges text[])
AS
$$
  SELECT $1, datname, array(select privs from unnest(ARRAY[
(CASE WHEN has_database_privilege($1,c.oid,'CONNECT') THEN 'CONNECT' ELSE NULL END),
(CASE WHEN has_database_privilege($1,c.oid,'CREATE') THEN 'CREATE' ELSE NULL END),
(CASE WHEN has_database_privilege($1,c.oid,'TEMPORARY') THEN 'TEMPORARY' ELSE NULL END),
(CASE WHEN has_database_privilege($1,c.oid,'TEMP') THEN 'CONNECT' ELSE NULL END)])foo(privs) WHERE privs IS NOT NULL) FROM pg_database c WHERE
has_database_privilege($1,c.oid,'CONNECT,CREATE,TEMPORARY,TEMP') AND datname not in ('template0');
$$ LANGUAGE SQL;


-- Bir kullanıcının tablespace yetkilerini görüntülememizi sağlayan fonksiyon
CREATE OR REPLACE FUNCTION tablespace_privs(text) RETURNS table(username text, spcname name, privileges text[])
AS
$$
  SELECT $1, spcname, ARRAY[
(CASE WHEN has_tablespace_privilege($1,spcname,'CREATE') THEN 'CREATE' ELSE NULL END)] FROM pg_tablespace WHERE has_tablespace_privilege($1,spcname,'CREATE');
$$ LANGUAGE SQL;


-- Bir kullanıcının foreign data wrapper yetkilerini görüntülememizi sağlayan fonksiyon
CREATE OR REPLACE FUNCTION fdw_privs(text) RETURNS table(username text,fdwname name, privileges text[])
AS
$$
  SELECT $1, fdwname, ARRAY[
(CASE WHEN has_foreign_data_wrapper_privilege($1,fdwname,'USAGE') THEN 'USAGE' ELSE NULL END)] FROM pg_catalog.pg_foreign_data_wrapper WHERE has_foreign_data_wrapper_privilege($1,fdwname,'USAGE');
$$ LANGUAGE SQL;


-- Bir kullanıcının foreign server yetkilerini görüntülememizi sağlayan fonksiyon
CREATE OR REPLACE FUNCTION fsrv_privs(text) RETURNS table(username text, fsrvname name, privileges text[])
AS
$$
  SELECT $1, s.srvname ,  ARRAY[
(CASE WHEN has_server_privilege($1,srvname,'USAGE') THEN 'USAGE' ELSE NULL END)] from pg_catalog.pg_foreign_server s  WHERE has_server_privilege ($1,srvname,'USAGE');
$$ LANGUAGE SQL;


-- Bir kullanıcının language yetkilerini görüntülememizi sağlayan fonksiyon
CREATE OR REPLACE FUNCTION language_privs(text) RETURNS table(username text,langname name, privileges text[])
AS
$$
SELECT $1, l.lanname, ARRAY[(CASE WHEN has_language_privilege($1,lanname,'USAGE') THEN 'USAGE' ELSE NULL END)] FROM pg_catalog.pg_language l where has_language_privilege($1,lanname,'USAGE');
$$ LANGUAGE SQL;


-- Bir kullanıcının schema yetkilerini görüntülememizi sağlayan fonksiyon
CREATE OR REPLACE FUNCTION schema_privs(text) RETURNS table(username text, schemaname name, privileges text[])
AS
$$
  SELECT $1, c.nspname, array(select privs from unnest(ARRAY[
(CASE WHEN has_schema_privilege($1,c.oid,'CREATE') THEN 'CREATE' ELSE NULL END),
(CASE WHEN has_schema_privilege($1,c.oid,'USAGE') THEN 'USAGE' ELSE NULL END)])foo(privs) WHERE privs IS NOT NULL)
FROM pg_namespace c where has_schema_privilege($1,c.oid,'CREATE,USAGE');
$$ LANGUAGE SQL;


-- Bir kullanıcının view yetkilerini görüntülememizi sağlayan fonksiyon
CREATE OR REPLACE FUNCTION view_privs(text) returns table(username text, viewname regclass, privileges text[])
AS
$$
SELECT  $1, c.oid::regclass, array(SELECT privs FROM unnest(ARRAY [
( CASE WHEN has_table_privilege($1,c.oid,'SELECT') THEN 'SELECT' ELSE NULL END),
(CASE WHEN has_table_privilege($1,c.oid,'INSERT') THEN 'INSERT' ELSE NULL END),
(CASE WHEN has_table_privilege($1,c.oid,'UPDATE') THEN 'UPDATE' ELSE NULL END),
(CASE WHEN has_table_privilege($1,c.oid,'DELETE') THEN 'DELETE' ELSE NULL END),
(CASE WHEN has_table_privilege($1,c.oid,'TRUNCATE') THEN 'TRUNCATE' ELSE NULL END),
(CASE WHEN has_table_privilege($1,c.oid,'REFERENCES') THEN 'REFERENCES' ELSE NULL END),
(CASE WHEN has_table_privilege($1,c.oid,'TRIGGER') THEN 'TRIGGER' ELSE NULL END)]) foo(privs) WHERE privs IS NOT NULL) FROM pg_class c JOIN pg_namespace n on c.relnamespace=n.oid where n.nspname not in ('information_schema','pg_catalog','sys') and  c.relkind='v' and has_table_privilege($1,c.oid,'SELECT, INSERT,UPDATE,DELETE,TRUNCATE,REFERENCES,TRIGGER') AND has_schema_privilege($1,c.relnamespace,'USAGE')
$$ LANGUAGE SQL;


-- Bir kullanıcının sequence yetkilerini görüntülememizi sağlayan fonksiyon
CREATE OR REPLACE FUNCTION sequence_privs(text) RETURNS table(username text, seqname regclass, privileges text[])
AS
$$
  SELECT $1, c.oid::regclass, array(SELECT privs from unnest(ARRAY [
(CASE WHEN has_table_privilege($1,c.oid,'SELECT') THEN 'SELECT' ELSE NULL END),
(CASE WHEN has_table_privilege($1,c.oid,'UPDATE') THEN 'UPDATE' ELSE NULL END)]) foo(privs) where privs is not null) FROM pg_class c JOIN pg_namespace n on c.relnamespace=n.oid where n.nspname not in ('information_schema','pg_catalog','sys') and  c.relkind='S' and
has_table_privilege($1,c.oid,'SELECT,UPDATE')  AND has_schema_privilege($1,c.relnamespace,'USAGE')
$$ LANGUAGE SQL;


-- Bir kullanıcının tüm yetkilerini görüntülememizi sağlayan fonksiyon
CREATE OR REPLACE FUNCTION all_privs(text) RETURNS table(usename text, object_type text, object_name name, privileges text[])
AS
$$
SELECT * FROM (
SELECT username,'TABLE' as object_type, relname::name as object_name, privileges
    FROM @extschema@.table_privs($1)
 UNION ALL
SELECT username,'DATABASE' as object_type, dbname as object_name, privileges
 FROM @extschema@.database_privs($1)
 UNION ALL
SELECT username,'TABLESPACE' as object_type, spcname as object_name, privileges
 FROM @extschema@.tablespace_privs($1)
 UNION ALL
SELECT username,'FWD' as object_type, fdwname as object_name, privileges
 FROM @extschema@.fdw_privs($1)
 UNION ALL
SELECT username,'FSERVER' as object_type, fsrvname as object_name, privileges
 FROM @extschema@.fsrv_privs($1)
 UNION ALL
SELECT username,'LANGUAGE' as object_type, langname as object_name, privileges
 FROM @extschema@.language_privs($1)
 UNION ALL
SELECT username,'SCHEMA' as object_type, schemaname as object_name, privileges
 FROM @extschema@.schema_privs($1)
 UNION ALL
SELECT username,'VIEW' as object_type, viewname::name as object_name, privileges
 FROM @extschema@.view_privs($1)
 UNION ALL
SELECT username,'SEQ' as object_type, seqname::name as object_name, privileges
 FROM @extschema@.sequence_privs($1)
) AS text1 ORDER BY 2
$$ LANGUAGE SQL;


---- OLUŞTURULAN OBJELER İÇİN YORUMLAR ----
COMMENT ON SCHEMA @extschema@ IS 'GBD tarafindan kullanilan fonksiyon ve viewlarin bulundugu schema';
COMMENT ON VIEW check_queries IS 'En yavas sorgulari goruntulememizi saglayan view';
COMMENT ON VIEW check_bloat IS 'Sunucudaki bloat oranlarini goruntulememizi saglayan view';
COMMENT ON VIEW check_blocked_statements IS 'Engellenen sorgulari goruntulememizi saglayan view';
COMMENT ON VIEW check_hit_ratio IS 'Hit ratio degerlerini goruntulememizi saglayan view';
COMMENT ON VIEW check_index_sizes IS 'Index boyutlarini goruntulememizi saglayan view';
COMMENT ON VIEW check_index_usage IS 'Index kullanimini goruntulememizi saglayan view';
COMMENT ON VIEW check_locks IS 'Locklari goruntulememizi saglayan view';
COMMENT ON VIEW check_seq_scans IS 'Sequential Scan degerlerini goruntulememizi saglayan view';
COMMENT ON VIEW check_unused_indexes IS 'Kullanilmayan indexleri goruntulememizi saglayan view';
COMMENT ON VIEW check_vacuum_stats IS 'Vacuum istatistiklerini goruntulememizi saglayan view';
COMMENT ON FUNCTION table_privs IS 'Bir kullanıcının tablo yetkilerini goruntulememizi saglayan fonksiyon';
COMMENT ON FUNCTION database_privs IS 'Bir kullanıcının veritabani yetkilerini goruntulememizi saglayan fonksiyon';
COMMENT ON FUNCTION tablespace_privs IS 'Bir kullanıcının tablespace yetkilerini goruntulememizi saglayan fonksiyon';
COMMENT ON FUNCTION fdw_privs IS 'Bir kullanıcının foreign data wrapper yetkilerini goruntulememizi saglayan fonksiyon';
COMMENT ON FUNCTION fsrv_privs IS 'Bir kullanıcının foreign server yetkilerini goruntulememizi saglayan fonksiyon';
COMMENT ON FUNCTION language_privs IS 'Bir kullanıcının language yetkilerini goruntulememizi saglayan fonksiyon';
COMMENT ON FUNCTION schema_privs IS 'Bir kullanıcının schema yetkilerini goruntulememizi saglayan fonksiyon';
COMMENT ON FUNCTION view_privs IS 'Bir kullanıcının view yetkilerini goruntulememizi saglayan fonksiyon';
COMMENT ON FUNCTION sequence_privs IS 'Bir kullanıcının sequence yetkilerini goruntulememizi saglayan fonksiyon';
COMMENT ON FUNCTION all_privs IS 'Bir kullanıcının tüm yetkilerini goruntulememizi saglayan fonksiyon';

---- OLUŞTURULAN OBJELER İÇİN YETKİ KISITLAMALARI ----
REVOKE ALL ON SCHEMA @extschema@ FROM PUBLIC;
REVOKE ALL ON ALL FUNCTIONS IN SCHEMA @extschema@ FROM PUBLIC;
REVOKE ALL ON ALL TABLES IN SCHEMA @extschema@ FROM PUBLIC;
GRANT USAGE ON SCHEMA @extschema@ TO CURRENT_USER;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA @extschema@ TO CURRENT_USER;
GRANT SELECT ON ALL TABLES IN SCHEMA @extschema@ TO CURRENT_USER;
