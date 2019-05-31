# GBDchecks

# KURULUM


1) Öncelikle eğer CentOS kullanıyorsanız "contrib ve devel" paketlerini kurmalısınız (devel paketi pgxs'in kullanımı için gereklidir):
```bash
yum install postgresql11-contrib postgresql11-devel
```

2) Bu eklenti "postgresql11-contrib" paketi ile birlikte gelen "pg_stat_statements" eklentisinin kurulumunu gerektirir:
```bash
CREATE EXTENSION pg_stat_statements;
```

3) postgresql.conf dosyasındaki "shared_preload_libraries = '' " bölümü aşağıdaki gibi değiştirilmelidir(restart gerektirir):
```bash
shared_preload_libraries = 'pg_stat_statements'
```

BILGI: Eğer "check_queries" view'ını kullanmayacaksanız sunucuyu yeniden başlatmadan eklentiyi kullanmaya devam edebilirsiniz.


4) Kurulum yapmak için git deposunu klonlamalısınız:
```bash
git clone https://gitlab.com/huseynsnmz/gbdchecks.git
```

5) Dosyaların gerekli yerlere ulaşması için klonladığınız "gbdchecks" dizine girip aşağıdaki komutu çalıştırmalısınız:
```bash
make install
```

BİLGİ: Bu eklenti ile oluşturulan tüm objelerlerden kullanıcıların yetkileri alınır ve sadece komutun çalıştırıldığı kullanıcıya verilir.


6) Eklentiyi aşağıdaki komut ile oluşturabilirsiniz:
```bash
CREATE EXTENSION gbdchecks;
```

BİLGİ: Eğer birden fazla kullanıcının bu objeleri kullanmasını istiyorsanız aşağıdaki sorguları kullanabilirsiniz:
```bash
GRANT USAGE ON SCHEMA gbdchecks TO <KULLANICI>;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA gbdchecks TO <KULLANICI>;
GRANT SELECT ON ALL TABLES IN SCHEMA gbdchecks TO <KULLANICI>;
```

# KONTROL SORGULARI

Sunucudaki bloat oranlarını görüntülemek için gerekli olan fonksiyon:
```bash
SELECT * FROM check_bloat;
```

Engellenen sorguları görüntüleyebileceğimiz view:
```bash
SELECT * FROM check_blocked_statements;
```

Hit Ratio değerlerini görüntüleyebileceğimiz view:
```bash
SELECT * FROM check_hit_ratio;
```

Index boyutlarını görüntüleyebileceğimiz view:
```bash
SELECT * FROM check_index_sizes;
```

Index kullanımını görüntüleyebileceğimiz view:
```bash
SELECT * FROM check_index_usage;
```

Lockları görüntüleyebileceğimiz view:
```bash
SELECT * FROM check_locks;
```

En yavaş sorguları görüntüleyebileceğimiz view:
```bash
SELECT * FROM check_queries;
```

Sequential Scan değerlerini görüntüleyebileceğimiz view:
```bash
SELECT * FROM check_seq_scans;
```

Kullanılmayan indexleri görüntüleyebileceğimiz view:
```bash
SELECT * FROM check_unused_indexes;
```

Vacuum istatistiklerini görüntüleyebileceğimiz view:
```bash
SELECT * FROM check_vacuum_stats;
```



# YETKI KONTROL SORGULARI

Bir kullanıcının tablo yetkilerini görüntüleyebileceğimiz fonksiyon:
```bash
SELECT * FROM table_privs('KULLANICI_ADI');
```

Bir kullanıcının veritabanı yetkilerini görüntüleyebileceğimiz fonksiyon:
```bash
SELECT * FROM database_privs('KULLANICI_ADI');
```

Bir kullanıcının tablespace yetkilerini görütülemek için gerekli fonksiyon
```bash
SELECT * FROM tablespace_privs('KULLANICI_ADI');
```

Bir kullanıcının foreign data wrapper yetkilerini görüntüleyebileceğimiz fonksiyon:
```bash
SELECT * FROM fdw_privs('KULLANICI_ADI');
```

Bir kullanıcının foreign server yetkilerini görüntüleyebileceğimiz fonksiyon:
```bash
SELECT * FROM fsrv_privs('KULLANICI_ADI');
```

Bir kullanıcının language yetkilerini görüntüleyebileceğimiz fonksiyon:
```bash
SELECT * FROM language_privs('KULLANICI_ADI');
```
Bir kullanıcının schema yetkilerini görüntüleyebileceğimiz fonksiyon:
```bash
SELECT * FROM schema_privs('KULLANICI_ADI');
```

Bir kullanıcının view yetkilerini görüntüleyebileceğimiz fonksiyon:
```bash
SELECT * FROM view_privs('KULLANICI_ADI');
```

Bir kullanıcının sequence yetkilerini ggörüntüleyebileceğimiz fonksiyon:
```bash
SELECT * FROM sequence_privs('KULLANICI_ADI');
```

Bir kullanıcının tüm yetkilerini görüntüleyebileceğimiz fonksiyon:
```bash
SELECT * FROM all_privs('KULLANICI_ADI');
```
