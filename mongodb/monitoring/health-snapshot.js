// ╔══════════════════════════════════════════════════════════════════╗
// ║  DMC DBA Toolkit                                                 ║
// ╠══════════════════════════════════════════════════════════════════╣
// ║  Script        : health-snapshot                                 ║
// ║  Engine        : MongoDB 5.0+ │ Atlas │ self-hosted              ║
// ║  Category      : monitoring                                      ║
// ║  Impact        : 🟢 Light  (designed for periodic execution)      ║
// ║  Permissions   : clusterMonitor                                  ║
// ║  Output schema : see docs/OUTPUT_SCHEMAS.md#mongo-health-snapshot ║
// ║  Inspired by   : serverStatus and replSetGetStatus reference —   ║
// ║                  MongoDB Manual public docs.                      ║
// ║  Maintainer    : Çağlar Özenç — DMC Bilgi Teknolojileri          ║
// ║  Last updated  : 2026-04-30                                      ║
// ║  Level         : 🌱 Newborn  (safe to run blind, output is self-explanatory)       ║
// ║  Version       : 1.0.0                                           ║
// ║  License       : MIT                                             ║
// ╚══════════════════════════════════════════════════════════════════╝
//
// Why this exists / Neden var:
//   EN: A periodic single-document snapshot for MongoDB monitoring.
//       Insert it into a capped collection or pipe to your TSDB. Each
//       call returns connections, opcounters (cumulative), repl lag if
//       this is a replica set member, and the WT cache pressure
//       indicators. This is intentionally minimal — production-grade
//       continuous monitoring is what Sentinel DB 360 is for.
//   TR: MongoDB izleme için periyodik tek-dokümanlı snapshot. Capped
//       collection'a insert edebilir veya TSDB'ye pipe edebilirsiniz.
//       Her çağrı bağlantılar, opcounter'lar (kümülatif), replica
//       set üyesiyse repl lag ve WT cache baskı göstergelerini döner.
//       Bilinçli olarak minimaldir — production-grade sürekli
//       izleme için Sentinel DB 360 vardır.
//
// Beyond this script / Bunun ötesinde:
//   For continuous, multi-instance monitoring with alerting,
//   persistence, dashboards, and AI-assisted findings, see
//   DMC's Sentinel DB 360 — https://github.com/dmcteknoloji

const adminDb = db.getSiblingDB("admin");

function safe(fn, fallback) {
    try { return fn(); }
    catch (e) { return fallback; }
}

const ss = safe(() => adminDb.runCommand({ serverStatus: 1 }), {});
const rs = safe(() => adminDb.runCommand({ replSetGetStatus: 1 }), null);

// Compute replica lag if this is a replica set member.
let replicaLagSecs = null;
if (rs && rs.members) {
    const primary = rs.members.find(m => m.state === 1);
    const me = rs.members.find(m => m.self === true);
    if (primary && me && me.state === 2) {  // 2 = SECONDARY
        replicaLagSecs = (primary.optimeDate - me.optimeDate) / 1000;
    }
}

const snapshot = {
    sample_utc: new Date(),
    host: ss.host,
    deployment: rs ? `replicaSet:${rs.set}` : "standalone",
    rs_role: rs && rs.myState !== undefined
        ? (rs.myState === 1 ? "primary"
           : rs.myState === 2 ? "secondary"
           : `state-${rs.myState}`)
        : null,
    uptime_secs: ss.uptime || null,
    // Connections
    conn_current: ss.connections ? ss.connections.current : null,
    conn_available: ss.connections ? ss.connections.available : null,
    conn_active: ss.globalLock && ss.globalLock.activeClients
        ? ss.globalLock.activeClients.total : null,
    // Opcounters — cumulative since startup; diff externally for rate
    op_insert_cumulative: ss.opcounters ? ss.opcounters.insert : null,
    op_query_cumulative:  ss.opcounters ? ss.opcounters.query  : null,
    op_update_cumulative: ss.opcounters ? ss.opcounters.update : null,
    op_delete_cumulative: ss.opcounters ? ss.opcounters.delete : null,
    op_command_cumulative: ss.opcounters ? ss.opcounters.command : null,
    // Replica lag (NULL on primary or standalone)
    replica_lag_secs: replicaLagSecs,
    // WiredTiger cache pressure — three numbers that matter
    wt_cache_used_bytes: ss.wiredTiger && ss.wiredTiger.cache
        ? ss.wiredTiger.cache["bytes currently in the cache"] : null,
    wt_cache_max_bytes: ss.wiredTiger && ss.wiredTiger.cache
        ? ss.wiredTiger.cache["maximum bytes configured"] : null,
    wt_cache_dirty_bytes: ss.wiredTiger && ss.wiredTiger.cache
        ? ss.wiredTiger.cache["tracked dirty bytes in the cache"] : null,
    // Network
    network_bytes_in_cumulative: ss.network ? ss.network.bytesIn : null,
    network_bytes_out_cumulative: ss.network ? ss.network.bytesOut : null
};

printjson(snapshot);
