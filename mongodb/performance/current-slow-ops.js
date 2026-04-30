// ╔══════════════════════════════════════════════════════════════════╗
// ║  DMC DBA Toolkit                                                 ║
// ╠══════════════════════════════════════════════════════════════════╣
// ║  Script        : current-slow-ops                                ║
// ║  Engine        : MongoDB 5.0+ │ Atlas │ self-hosted              ║
// ║  Category      : performance                                     ║
// ║  Impact        : 🟢 Light  ($currentOp aggregation, in-memory)    ║
// ║  Permissions   : inprog action — clusterMonitor / dbAdmin role    ║
// ║  Output schema : see docs/OUTPUT_SCHEMAS.md#mongo-current-slow-ops║
// ║  Inspired by   : MongoDB Manual — db.currentOp() and $currentOp  ║
// ║  Maintainer    : Çağlar Özenç — DMC Bilgi Teknolojileri          ║
// ║  Last updated  : 2025-08-03                                      ║
// ║  Version       : 1.0.0                                           ║
// ║  License       : MIT                                             ║
// ╚══════════════════════════════════════════════════════════════════╝
//
// Returns currently active operations that have been running longer
// than a threshold (default 1 second). Uses the $currentOp aggregation
// stage — the modern, structured replacement for the legacy
// db.currentOp() shell helper.
//
// Run as a mongosh script:
//   mongosh "<connection-uri>" --quiet --file current-slow-ops.js
//
// The threshold is read from the SECS_RUNNING shell variable if set,
// otherwise defaults to 1 second.

const thresholdSecs = (typeof SECS_RUNNING === "number") ? SECS_RUNNING : 1;

const result = db.getSiblingDB("admin").aggregate([
    { $currentOp: { allUsers: true, idleConnections: false } },
    {
        $match: {
            active: true,
            secs_running: { $gte: thresholdSecs },
            // Exclude internal threads and replication oplog appliers from
            // the noisy default view. The vendor docs document these op
            // names; a DBA debugging replication can drop this filter.
            "command.$truncated": { $exists: false },
            ns: { $not: /^(local\.|config\.|admin\.\$cmd\.aggregate)/ }
        }
    },
    {
        $project: {
            _id: 0,
            opid: 1,
            secs_running: 1,
            microsecs_running: 1,
            op: 1,
            ns: 1,
            "client": 1,
            "appName": 1,
            "desc": 1,
            "currentOpTime": 1,
            "waitingForLock": 1,
            "numYields": 1,
            "lockStats": 1,
            // Truncate the command document to a stable preview to avoid
            // overwhelming the terminal on large pipelines.
            commandPreview: {
                $substrCP: [{ $toString: "$command" }, 0, 400]
            }
        }
    },
    { $sort: { secs_running: -1 } },
    { $limit: 50 }
]).toArray();

print(`current-slow-ops (>= ${thresholdSecs}s): ${result.length} op(s)`);
printjson(result);
