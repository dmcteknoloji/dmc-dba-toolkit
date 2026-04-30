// ╔══════════════════════════════════════════════════════════════════╗
// ║  DMC DBA Toolkit                                                 ║
// ╠══════════════════════════════════════════════════════════════════╣
// ║  Script        : profiler-summary                                ║
// ║  Engine        : MongoDB 5.0+ │ Atlas │ self-hosted              ║
// ║  Category      : performance                                     ║
// ║  Impact        : 🟢 Light  (capped collection scan)               ║
// ║  Permissions   : read on the target database (system.profile)    ║
// ║  Output schema : see docs/OUTPUT_SCHEMAS.md#mongo-profiler-summary║
// ║  Inspired by   : MongoDB Manual — Database Profiler              ║
// ║  Maintainer    : Çağlar Özenç — DMC Bilgi Teknolojileri          ║
// ║  Last updated  : 2025-09-14                                      ║
// ║  Version       : 1.0.0                                           ║
// ║  License       : MIT                                             ║
// ╚══════════════════════════════════════════════════════════════════╝
//
// What this is for:
//   When the app team comes to you saying "Mongo is slow today" — but
//   currentOp is empty because the slow ops finished before you logged
//   in — system.profile is what saves you. It is a capped collection
//   that retains slow ops the profiler captured. This script aggregates
//   it by namespace + operation shape so you walk away with a short list
//   of "these five queries account for 90% of pain", not 50,000 lines.
//
// Pre-flight:
//   In the target database:  db.getProfilingStatus()
//   To enable level 1:       db.setProfilingLevel(1, { slowms: 100 })
//   The profiler must already be on; this script does not enable it.
//
// Production note:
//   system.profile is capped (default 1MB). On a busy cluster it rotates
//   in seconds. Make it 64MB if you want a useful retention window:
//     db.runCommand({ collMod: "system.profile", capSize: 67108864 })
//   (You must turn the profiler off, drop, recreate, then re-enable.)

const dbName = (typeof DB === "string") ? DB : db.getName();
const targetDb = db.getSiblingDB(dbName);

const status = targetDb.getProfilingStatus();
print(`profiler level=${status.was}, slowms=${status.slowms}, db=${dbName}`);

if (!targetDb.system.profile.findOne()) {
    print("system.profile is empty — profiler not running, or capped collection rotated already.");
    quit();
}

const summary = targetDb.system.profile.aggregate([
    {
        $match: {
            // Filter out noise: profiler entries about the profiler itself,
            // and the most common chatty system commands.
            ns: { $not: /\.system\.profile$/ },
            op: { $in: ["query", "command", "update", "remove", "getmore", "insert"] }
        }
    },
    {
        $group: {
            _id: {
                ns: "$ns",
                op: "$op",
                // Group by the keysExamined-to-keys ratio bucket — quick
                // way to spot "scans a lot, returns little" patterns.
                hasIndex: { $cond: [{ $gt: ["$planSummary", null] }, true, false] }
            },
            samples: { $sum: 1 },
            total_millis: { $sum: "$millis" },
            avg_millis: { $avg: "$millis" },
            max_millis: { $max: "$millis" },
            avg_keys_examined: { $avg: "$keysExamined" },
            avg_docs_examined: { $avg: "$docsExamined" },
            avg_nreturned: { $avg: "$nreturned" },
            // Pick a representative example so you know what the shape is.
            example_planSummary: { $first: "$planSummary" }
        }
    },
    {
        $project: {
            _id: 0,
            ns: "$_id.ns",
            op: "$_id.op",
            hasIndex: "$_id.hasIndex",
            samples: 1,
            total_millis: 1,
            avg_millis: { $round: ["$avg_millis", 1] },
            max_millis: 1,
            avg_keys_examined: { $round: ["$avg_keys_examined", 0] },
            avg_docs_examined: { $round: ["$avg_docs_examined", 0] },
            avg_nreturned: { $round: ["$avg_nreturned", 0] },
            example_planSummary: 1
        }
    },
    { $sort: { total_millis: -1 } },
    { $limit: 25 }
]).toArray();

print(`top ${summary.length} pattern(s) by cumulative time:`);
printjson(summary);
