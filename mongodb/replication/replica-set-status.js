// ╔══════════════════════════════════════════════════════════════════╗
// ║  DMC DBA Toolkit                                                 ║
// ╠══════════════════════════════════════════════════════════════════╣
// ║  Script        : replica-set-status                              ║
// ║  Engine        : MongoDB 5.0+ │ Atlas │ self-hosted              ║
// ║  Category      : replication                                     ║
// ║  Impact        : 🟢 Light  (rs.status() command)                  ║
// ║  Permissions   : clusterMonitor role                              ║
// ║  Output schema : see docs/OUTPUT_SCHEMAS.md#mongo-replica-set-status║
// ║  Inspired by   : MongoDB Manual — rs.status(), oplog primer      ║
// ║  Maintainer    : Çağlar Özenç — DMC Bilgi Teknolojileri          ║
// ║  Last updated  : 2025-11-11                                      ║
// ║  Level         : 🌱 Newborn  (safe to run blind, output is self-explanatory)       ║
// ║  Version       : 1.0.0                                           ║
// ║  License       : MIT                                             ║
// ╚══════════════════════════════════════════════════════════════════╝
//
// What this is for:
//   `rs.status()` returns a deeply nested document that's hard to read on
//   a phone at 2 AM. This script extracts the four things that actually
//   matter during an incident:
//     1. Who is primary, who is secondary, who is unreachable.
//     2. How far behind each secondary is (oplog lag, in seconds).
//     3. What the configured priorities and votes are (so you can
//        predict the outcome of a manual stepDown).
//     4. The oplog window — how many minutes of history you have before
//        an unreachable secondary will need a full resync.
//
// Production note:
//   We've seen "lag = 0" reported on a secondary that was actually wedged
//   for hours, because lastHeartbeatRecv kept ticking but
//   optimeDate didn't move. We compare *both* to flag stuck members.

const status = rs.status();
print(`replica set: ${status.set}  (myState=${status.myState})`);
print(`now: ${status.date.toISOString()}`);
print("");

// Member summary table
print("members:");
status.members.forEach(m => {
    const lag = m.optimeDate
        ? Math.round((status.date - m.optimeDate) / 1000)
        : null;
    const stale = m.lastHeartbeatRecv && m.optimeDate
        ? Math.round((m.lastHeartbeatRecv - m.optimeDate) / 1000)
        : null;
    const flag = (lag !== null && lag > 60) ? " ⚠️ lag>60s"
              : (stale !== null && stale > 30) ? " ⚠️ optime stuck"
              : "";
    print(
        `  [${m._id}] ${m.name}` +
        `  state=${m.stateStr}` +
        `  health=${m.health}` +
        `  uptime=${m.uptime}s` +
        `  lag=${lag === null ? "-" : lag + "s"}` +
        flag
    );
});

// Oplog window — useful for "can we afford a resync?"
print("");
const local = db.getSiblingDB("local");
const first = local.oplog.rs.find().sort({ $natural:  1 }).limit(1).next();
const last  = local.oplog.rs.find().sort({ $natural: -1 }).limit(1).next();
const oplogMinutes = Math.round(
    (last.ts.getTime() - first.ts.getTime()) / 60
);
print(`oplog window: ${oplogMinutes} minute(s) — first=${new Date(first.ts.getTime() * 1000).toISOString()}, last=${new Date(last.ts.getTime() * 1000).toISOString()}`);
print(`oplog size:   ${local.oplog.rs.stats().maxSize / 1024 / 1024} MB capped`);

// Election readiness summary — votes, priority. People always forget
// that a 2-of-3 majority can still elect when one node has priority 0.
print("");
print("election config:");
const config = rs.conf();
config.members.forEach(m => {
    print(
        `  [${m._id}] ${m.host}` +
        `  priority=${m.priority}` +
        `  votes=${m.votes}` +
        `  hidden=${!!m.hidden}` +
        `  arbiter=${!!m.arbiterOnly}`
    );
});
