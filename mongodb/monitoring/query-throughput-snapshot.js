// ╔══════════════════════════════════════════════════════════════════╗
// ║  DMC DBA Toolkit                                                 ║
// ╠══════════════════════════════════════════════════════════════════╣
// ║  Script        : query-throughput-snapshot                       ║
// ║  Engine        : MongoDB 5.0+ │ Atlas │ self-hosted              ║
// ║  Category      : monitoring                                      ║
// ║  Impact        : 🟢 Light  (serverStatus admin command)           ║
// ║  Permissions   : clusterMonitor                                  ║
// ║  Output schema : see docs/OUTPUT_SCHEMAS.md#mongo-query-throughput-snapshot ║
// ║  Inspired by   : MongoDB Manual — serverStatus opcounters,       ║
// ║                  network section.                                 ║
// ║  Maintainer    : Çağlar Özenç — DMC Bilgi Teknolojileri          ║
// ║  Last updated  : 2026-05-01                                      ║
// ║  Level         : 🌳 Middle   (production-grade, assumes DBA familiarity)           ║
// ║  Version       : 1.0.0                                           ║
// ║  License       : MIT                                             ║
// ╚══════════════════════════════════════════════════════════════════╝
//
// Why this exists / Neden var:
//   EN: A periodic single-document throughput snapshot for MongoDB.
//       opcounters and network bytes are cumulative since startup;
//       feed periodic samples into your TSDB and diff client-side
//       for instantaneous rates. This script returns the values
//       Sentinel DB 360 collects every 60 seconds.
//   TR: MongoDB için periyodik tek-dokümanlı throughput snapshot'ı.
//       opcounter'lar ve network byte'ları başlangıçtan beri
//       kümülatiftir; periyodik örnekleri TSDB'ne besle ve client
//       tarafında diff'le anlık oranları al. Bu script Sentinel
//       DB 360'ın 60 saniyede bir topladığı değerleri döner.
//
// Beyond this script / Bunun ötesinde:
//   Sentinel DB 360 ingests this every 60 seconds across every
//   replica set member and shard, computes per-second rates, and
//   correlates with currentOp findings — see
//   https://github.com/dmcteknoloji.

const adminDb = db.getSiblingDB("admin");
function safe(fn, fallback) {
    try { return fn(); } catch (e) { return fallback; }
}

const ss = safe(() => adminDb.runCommand({ serverStatus: 1 }), {});

const snapshot = {
    sample_utc: new Date(),
    host: ss.host,
    uptime_secs: ss.uptime,

    // opcounters (cumulative since startup)
    op_insert_cum:  ss.opcounters ? ss.opcounters.insert  : null,
    op_query_cum:   ss.opcounters ? ss.opcounters.query   : null,
    op_update_cum:  ss.opcounters ? ss.opcounters.update  : null,
    op_delete_cum:  ss.opcounters ? ss.opcounters.delete  : null,
    op_command_cum: ss.opcounters ? ss.opcounters.command : null,
    op_getmore_cum: ss.opcounters ? ss.opcounters.getmore : null,

    // Replica set replication ops (cumulative)
    op_repl_insert_cum:  ss.opcountersRepl ? ss.opcountersRepl.insert  : null,
    op_repl_query_cum:   ss.opcountersRepl ? ss.opcountersRepl.query   : null,
    op_repl_update_cum:  ss.opcountersRepl ? ss.opcountersRepl.update  : null,
    op_repl_delete_cum:  ss.opcountersRepl ? ss.opcountersRepl.delete  : null,
    op_repl_command_cum: ss.opcountersRepl ? ss.opcountersRepl.command : null,

    // Network counters (cumulative)
    net_bytes_in_cum:    ss.network ? ss.network.bytesIn        : null,
    net_bytes_out_cum:   ss.network ? ss.network.bytesOut       : null,
    net_num_requests_cum: ss.network ? ss.network.numRequests   : null,

    // Asserts (cumulative) — high warning rate often points at config issues
    assert_warning_cum: ss.asserts ? ss.asserts.warning : null,
    assert_user_cum:    ss.asserts ? ss.asserts.user    : null,

    // Live workload right now
    conn_current:       ss.connections ? ss.connections.current   : null,
    conn_available:     ss.connections ? ss.connections.available : null,
    active_clients_now: ss.globalLock && ss.globalLock.activeClients
        ? ss.globalLock.activeClients.total : null,
    active_writers_now: ss.globalLock && ss.globalLock.activeClients
        ? ss.globalLock.activeClients.writers : null,
    active_readers_now: ss.globalLock && ss.globalLock.activeClients
        ? ss.globalLock.activeClients.readers : null,

    // Average rates (cumulative / uptime). Use only as a baseline; for
    // accurate instant rates, diff cumulative values across two samples.
    op_query_per_sec_avg:   ss.opcounters && ss.uptime
        ? +(ss.opcounters.query / ss.uptime).toFixed(2) : null,
    op_insert_per_sec_avg:  ss.opcounters && ss.uptime
        ? +(ss.opcounters.insert / ss.uptime).toFixed(2) : null,
    op_update_per_sec_avg:  ss.opcounters && ss.uptime
        ? +(ss.opcounters.update / ss.uptime).toFixed(2) : null,
    op_delete_per_sec_avg:  ss.opcounters && ss.uptime
        ? +(ss.opcounters.delete / ss.uptime).toFixed(2) : null,

    note: "All *_cum fields are cumulative since startup; diff across two samples for instantaneous per-second rates."
};

printjson(snapshot);
