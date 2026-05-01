// ╔══════════════════════════════════════════════════════════════════╗
// ║  DMC DBA Toolkit                                                 ║
// ╠══════════════════════════════════════════════════════════════════╣
// ║  Script        : replication-lag-snapshot                        ║
// ║  Engine        : MongoDB 5.0+ │ Atlas │ self-hosted              ║
// ║  Category      : monitoring                                      ║
// ║  Impact        : 🟢 Light  (rs.status admin command)              ║
// ║  Permissions   : clusterMonitor                                  ║
// ║  Output schema : see docs/OUTPUT_SCHEMAS.md#mongo-replication-lag-snapshot ║
// ║  Inspired by   : MongoDB Manual — rs.status() reference,         ║
// ║                  oplog window guidance.                           ║
// ║  Maintainer    : Çağlar Özenç — DMC Bilgi Teknolojileri          ║
// ║  Last updated  : 2026-05-01                                      ║
// ║  Version       : 1.0.0                                           ║
// ║  License       : MIT                                             ║
// ╚══════════════════════════════════════════════════════════════════╝
//
// Why this exists / Neden var:
//   EN: One document per call: per-secondary lag in seconds, plus
//       a few derived values (worst lag, oplog window minutes,
//       any member with a stuck optime). Run on the primary every
//       30 seconds. The result is a clean replica-set health
//       time-series ready for Grafana, Power BI, or your Sentinel-
//       compatible TSDB.
//   TR: Çağrı başına tek doküman: secondary başına lag saniye
//       cinsinden + birkaç türetilmiş değer (en kötü lag, oplog
//       penceresi dakika, optime'ı sıkışmış üye var mı). Primary'de
--      30 saniyede bir çalıştır. Sonuç temiz bir replica set
//       sağlık zaman serisi — Grafana, Power BI veya Sentinel-
//       uyumlu TSDB'in için hazır.
//
// Beyond this script / Bunun ötesinde:
//   Sentinel DB 360 ingests this every 30 seconds, learns each
//   member's normal lag baseline, and alerts on anomalies versus
//   that baseline — far fewer false positives than a static
//   threshold. See https://github.com/dmcteknoloji.

const adminDb = db.getSiblingDB("admin");
function safe(fn, fallback) {
    try { return fn(); } catch (e) { return fallback; }
}

const rs = safe(() => adminDb.runCommand({ replSetGetStatus: 1 }), null);

if (!rs || !rs.members) {
    print(JSON.stringify({
        sample_utc: new Date(),
        deployment: "standalone or no rs access",
        error: rs && rs.error ? rs.error : "replSetGetStatus unavailable"
    }, null, 2));
    quit();
}

const now = rs.date || new Date();
const primary = rs.members.find(m => m.state === 1);
const secondaries = rs.members.filter(m => m.state === 2);

// Per-secondary lag in seconds.
const perSecondary = secondaries.map(m => {
    const lag = primary && m.optimeDate
        ? Math.round((primary.optimeDate - m.optimeDate) / 1000)
        : null;
    const optimeStuckSecs = m.optimeDate && m.lastHeartbeatRecv
        ? Math.round((m.lastHeartbeatRecv - m.optimeDate) / 1000)
        : null;
    return {
        member_id:           m._id,
        name:                m.name,
        state:               m.stateStr,
        health:              m.health,
        uptime_secs:         m.uptime,
        lag_secs:            lag,
        optime_stuck_secs:   optimeStuckSecs,
        last_heartbeat:      m.lastHeartbeat,
        last_heartbeat_recv: m.lastHeartbeatRecv,
        sync_source:         m.syncSourceHost
    };
});

// Oplog window — predicts whether a behind secondary can catch up
// without a full resync. Useful: if (worst lag) approaches (oplog window),
// you have minutes to act.
const local = db.getSiblingDB("local");
let oplogWindowMins = null;
let oplogSizeMb = null;
try {
    const first = local.oplog.rs.find().sort({ $natural:  1 }).limit(1).next();
    const last  = local.oplog.rs.find().sort({ $natural: -1 }).limit(1).next();
    if (first && last) {
        oplogWindowMins = Math.round((last.ts.getTime() - first.ts.getTime()) / 60);
    }
    const stats = local.oplog.rs.stats();
    oplogSizeMb = stats.maxSize ? Math.round(stats.maxSize / 1048576) : null;
} catch (e) {
    // Atlas Free / Shared tiers restrict access to local.* — leave NULL.
}

const lags = perSecondary.map(m => m.lag_secs).filter(l => l !== null);
const worstLag = lags.length ? Math.max.apply(null, lags) : null;
const stuckOptimeMembers = perSecondary.filter(m =>
    (m.optime_stuck_secs || 0) > 30
);

const snapshot = {
    sample_utc: now,
    rs_set: rs.set,
    primary_name: primary ? primary.name : null,
    secondaries_total: secondaries.length,
    secondaries_healthy: secondaries.filter(m => m.health === 1).length,
    worst_lag_secs: worstLag,
    oplog_window_mins: oplogWindowMins,
    oplog_size_mb: oplogSizeMb,
    stuck_optime_count: stuckOptimeMembers.length,
    per_secondary: perSecondary,
    verdict:
        oplogWindowMins !== null && worstLag !== null && worstLag > oplogWindowMins * 60
            ? "🔴 worst lag exceeds oplog window — full resync incoming"
        : stuckOptimeMembers.length > 0
            ? `🟠 ${stuckOptimeMembers.length} member(s) with stuck optime behind a healthy heartbeat`
        : worstLag !== null && worstLag > 60
            ? "🟠 worst lag > 60s"
        : null
};

printjson(snapshot);
