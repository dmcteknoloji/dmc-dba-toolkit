# Grafana dashboards · Hazır panolar

Bu klasör, `monitoring/` snapshot scriptlerinin **hedef tablolarına** yazdığı zaman serisini gösteren örnek Grafana dashboard JSON'larını içerir. Her motor için bir tane.

This folder ships example Grafana dashboard JSONs that visualise the time-series produced by the `monitoring/` snapshot scripts. One per engine.

---

## Hızlı başlangıç · Quick start

1. **Hedef tablonu hazırla.** Snapshot scriptini cron / SQL Agent / pgAgent / mongosh ile periyodik çalıştır ve sonucu bir tabloya yaz. Detaylı kurulum: [`docs/MONITORING_GUIDE.md`](../../docs/MONITORING_GUIDE.md).

2. **Grafana'ya data source ekle.** Engine'ine göre native plugin yeterli:
   - SQL Server → "Microsoft SQL Server" plugin
   - PostgreSQL → "PostgreSQL" plugin
   - MySQL → "MySQL" plugin
   - MongoDB → "MongoDB" plugin (Grafana 9+)

3. **Dashboard JSON'unu import et.** Grafana → Dashboards → New → Import → Upload JSON file → bu klasörden uygun olanı seç.

4. **Data source seçimini doğrula.** Import dialog'unda Grafana sana hangi data source'u kullanacağını soracak — az önce eklediğini seç. Schema/database adı `dmc_monitor` olarak varsayıldı; sende farklıysa panellerin sorgusunu güncelle.

---

## Dashboard'lar · Dashboards

| Dosya | Motor | Beslendiği tablo | Ana paneller |
|---|---|---|---|
| [`mssql-health.json`](./mssql-health.json) | SQL Server | `dmc_monitor.health_snapshot` | CPU signal wait %, sessions, blocked sessions, batch req/sec, page life expectancy |
| [`postgresql-health.json`](./postgresql-health.json) | PostgreSQL | `dmc_monitor.health_snapshot` | Connections (active/idle/idle-in-xact), cache hit %, oldest xact age, replay lag |
| [`mysql-innodb-pressure.json`](./mysql-innodb-pressure.json) | MySQL | `dmc_monitor.innodb_pressure_snapshot` | Buffer pool fill, dirty page %, row-lock waits, replication lag |
| [`mongodb-replica-lag.json`](./mongodb-replica-lag.json) | MongoDB | `dmc_monitor.replication_lag_snapshot` | Per-secondary lag, oplog window, secondaries healthy count |

---

## Notlar · Notes

- **Bunlar production'a hazır değil — başlangıç noktasıdır.** Eşikler örnek; kendi workload'una göre ayarlanmalı.
- **JSON'lar kasıtlı olarak minimal.** Grafana her sürümde dashboard JSON şemasını biraz değiştirir; karmaşık panel'lerin sürümler arasında bozulma riski var. Bu örnekler `Stat`, `Time series`, `Table` gibi kararlı panel tipleriyle yazıldı.
- **Sentinel DB 360** — tüm bunları (ve çok daha fazlasını) hazır olarak verir. Manuel kurulumla yorulan ekipler için doğal bir sonraki adım: [sentineldb360.com](https://sentineldb360.com).

> Pull request açıkken: kendi ekibinde kullandığın daha iyi bir dashboard varsa paylaş. Hashtag'ler `#grafana #dashboard` veya `examples/grafana/<engine>-<topic>.json` deseniyle PR aç.
