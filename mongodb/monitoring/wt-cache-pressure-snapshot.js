// ╔══════════════════════════════════════════════════════════════════╗
// ║  DMC DBA Toolkit                                                 ║
// ╠══════════════════════════════════════════════════════════════════╣
// ║  Script        : wt-cache-pressure-snapshot                      ║
// ║  Engine        : MongoDB 5.0+ (WiredTiger) │ Atlas │ self-hosted ║
// ║  Category      : monitoring                                      ║
// ║  Impact        : 🟢 Light  (serverStatus admin command)           ║
// ║  Permissions   : clusterMonitor                                  ║
// ║  Output schema : see docs/OUTPUT_SCHEMAS.md#mongo-wt-cache-pressure-snapshot ║
// ║  Inspired by   : MongoDB Manual — serverStatus.wiredTiger.cache  ║
// ║                  reference.                                       ║
// ║  Maintainer    : Çağlar Özenç — DMC Bilgi Teknolojileri          ║
// ║  Last updated  : 2026-05-01                                      ║
// ║  Version       : 1.0.0                                           ║
// ║  License       : MIT                                             ║
// ╚══════════════════════════════════════════════════════════════════╝
//
// Why this exists / Neden var:
//   EN: WiredTiger's cache is to MongoDB what the buffer pool is to
//       MySQL — the most important single tunable. When it gets
//       overcommitted, WT triggers application-thread eviction,
//       which means user queries pause to evict pages. This is
//       invisible from the application side until query latency
//       randomly spikes. The "pages evicted from app threads"
//       counter is the canonical leading indicator. This snapshot
//       returns that, plus the cache fill, dirty bytes, and read
//       latency, in one document per call.
//   TR: WiredTiger cache'i MongoDB için ne demekse, MySQL'de buffer
//       pool da odur — en önemli tek tunable. Aşırı yüklendiğinde
//       WT, application-thread eviction tetikler; yani kullanıcı
//       sorguları sayfa eviction yapmak için durur. Uygulama
--      tarafından bu görünmez ta ki sorgu latency'si rastgele
//       sıçrayana kadar. "Pages evicted from app threads" sayacı
//       canonical erken göstergedir. Bu snapshot bunu + cache
//       dolumu + dirty byte + read latency'yi çağrı başına tek
//       doküman olarak döner.
//
// Beyond this script / Bunun ötesinde:
//   Sentinel DB 360 collects this every 60 seconds and surfaces
//   the "app-thread eviction starting to climb" pattern hours
//   before query latency degrades — see
//   https://github.com/dmcteknoloji.

const adminDb = db.getSiblingDB("admin");
function safe(fn, fallback) {
    try { return fn(); } catch (e) { return fallback; }
}

const ss = safe(() => adminDb.runCommand({ serverStatus: 1 }), {});

if (!ss.wiredTiger) {
    print("WiredTiger storage engine not in use on this node.");
    quit();
}

const cache = ss.wiredTiger.cache || {};
const concurrency = ss.wiredTiger.concurrentTransactions || {};

const used = cache["bytes currently in the cache"] || 0;
const max = cache["maximum bytes configured"] || 0;
const dirty = cache["tracked dirty bytes in the cache"] || 0;

const snapshot = {
    sample_utc: new Date(),
    host: ss.host,
    uptime_secs: ss.uptime,

    // Cache fill
    cache_used_bytes:  used,
    cache_max_bytes:   max,
    cache_used_pct:    max ? +(100 * used / max).toFixed(2) : null,
    cache_dirty_bytes: dirty,
    cache_dirty_pct:   used ? +(100 * dirty / used).toFixed(2) : null,

    // Eviction signals — these are the leading indicators of pressure.
    // App-thread eviction means user queries are paying the cost; ideally
    // close to zero on a healthy node.
    pages_read_into_cache_cum:
        cache["pages read into cache"] || 0,
    pages_written_from_cache_cum:
        cache["pages written from cache"] || 0,
    eviction_pages_evicted_cum:
        cache["pages evicted by application threads"] || 0,
    eviction_unmodified_pages_cum:
        cache["unmodified pages evicted"] || 0,
    eviction_modified_pages_cum:
        cache["modified pages evicted"] || 0,

    // Concurrent transaction tickets — pressure indicator
    read_tickets_available:  concurrency.read  ? concurrency.read.available  : null,
    read_tickets_out:        concurrency.read  ? concurrency.read.out        : null,
    write_tickets_available: concurrency.write ? concurrency.write.available : null,
    write_tickets_out:       concurrency.write ? concurrency.write.out       : null,

    // Verdict — single-line for an alert subject
    verdict:
        max && (100 * used / max) > 95
            ? "🔴 cache > 95% full — app-thread eviction imminent"
        : (cache["pages evicted by application threads"] || 0) > 0
              && cache["unmodified pages evicted"] !== undefined
              && (cache["pages evicted by application threads"] /
                  Math.max(cache["unmodified pages evicted"], 1)) > 0.1
            ? "🟠 app-thread eviction climbing — user queries paying the cost"
        : used && (100 * dirty / used) > 20
            ? "🟡 dirty bytes > 20% of cache — IO not keeping up"
            : null
};

printjson(snapshot);
