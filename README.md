# gbdchecks


# KONTROL SORGULARI

Sunucudaki bloat oranlarını görüntülemek için gerekli olan fonksiyon:
```bash
SELECT * FROM check_bloat;
```

Engellenen sorguları görüntülemek için gerekli olan fonksiyon:
```bash
SELECT * FROM check_blocked_statements;
```

Hit Ratio değerlerini görümtülemek için gerekli olan fonksiyon:
```bash
SELECT * FROM check_hit_ratio;
```

Index boyutlarını görümtülemek için gerekli olan fonksiyon:
```bash
SELECT * FROM check_index_sizes;
```

Index kullanımını görümtülemek için gerekli olan fonksiyon
```bash
SELECT * FROM check_index_usage;
```

Lockları görümtülemek için gerekli olan fonksiyon
```bash
SELECT * FROM check_locks;
```

En yavaş sorguları görümtülemek için gerekli olan fonksiyon (pg_stat_statements eklentisi olmadan hata alır)
```bash
SELECT * FROM check_queries;
```

Sequential Scan değerlerini görümtülemek için gerekli olan fonksiyon
```bash
SELECT * FROM check_seq_scans
```

Kullanılmayan indexleri görümtülemek için gerekli olan fonksiyon
```bash
SELECT * FROM check_unused_indexes;
```

Vacuum istatistiklerini görümtülemek için gerekli olan fonksiyon
```bash
SELECT * FROM check_vacuum_stats;
```



# YETKI KONTROL SORGULARI

Bir kullanıcının Tablo yetkilerini görüntülemek için gerekli fonksiyon
```bash
SELECT * FROM table_privs('KULLANICI_ADI')
```

Bir kullanıcının Veritabanı yetkilerini görütülemek için gerekli fonksiyon
```bash
SELECT * FROM database_privs('KULLANICI_ADI')
```

Bir kullanıcının Tablespace yetkilerini görütülemek için gerekli fonksiyon
```bash
SELECT * FROM tablespace_privs('KULLANICI_ADI')
```

Bir kullanıcının Foreign Data Wrapper yetkilerini görütülemek için gerekli fonksiyon
```bash
SELECT * FROM fdw_privs('KULLANICI_ADI')
```

Bir kullanıcının Foreign Server yetkilerini görüntülemek için gerekli fonksiyon
```bash
SELECT * FROM fsrv_privs('KULLANICI_ADI')
```

Bir kullanıcının Language yetkileri için gerekli fonksiyon
```bash
SELECT * FROM language_privs('KULLANICI_ADI')
```
Bir kullanıcının Schema yetkileri için gerekli fonksiyon
```bash
SELECT * FROM schema_privs('KULLANICI_ADI')
```

Bir kullanıcının View yetkilerini görüntülemek için gerekli fonksiyon
```bash
SELECT * FROM view_privs('KULLANICI_ADI')
```

Bir kullanıcının Sequence yetkilerini görüntülemek için gerekli fonksiyon
```bash
SELECT * FROM sequence_privs('KULLANICI_ADI')
```

Bir kullanıcının tüm yetkileri görütülemek için gerekli fonksiyon
```bash
SELECT * FROM all_privs('KULLANICI_ADI')
```
