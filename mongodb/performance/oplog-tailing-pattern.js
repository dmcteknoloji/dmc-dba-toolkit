// ╔══════════════════════════════════════════════════════════════════╗
// ║  DMC DBA Toolkit                                                 ║
// ╠══════════════════════════════════════════════════════════════════╣
// ║  Script        : oplog-tailing-pattern                           ║
// ║  Engine        : MongoDB 5.0+ (replica set member required)      ║
// ║  Category      : performance                                     ║
// ║  Impact        : 🟡 Medium  (reads local.oplog.rs, may iterate    ║
// ║                              recent ops on large clusters)        ║
// ║  Permissions   : read on local; clusterMonitor                    ║
// ║  Output schema : see docs/OUTPUT_SCHEMAS.md#mongo-oplog-tailing-pattern ║
// ║  Inspired by   : MongoDB Manual — Replica Set Oplog reference,    ║
// ║                  tailable cursors, change streams.                 ║
// ║  Maintainer    : Çağlar Özenç — DMC Bilgi Teknolojileri          ║
// ║  Last updated  : 2026-05-01                                      ║
// ║  Level         : 🦅 Expert   (oplog internals + write-pattern decoding) ║
// ║  Version       : 1.0.0                                           ║
// ║  License       : MIT                                             ║
// ╚══════════════════════════════════════════════════════════════════╝
//
// Why this exists / Neden var:
//   EN: Atlas activity feed and currentOp show what's running now.
//       The oplog is the only source of truth for what was actually
//       written across the recent past. This script reads the last
//       N seconds of oplog and aggregates by namespace + op type to
//       produce the question every senior MongoDB DBA wants answered:
//       "what writes are dominating this replica set right now?".
//       Bonus: identifies large transactions (multi-document writes)
//       and noisy collections.
//   TR: Atlas activity feed ve currentOp şu an çalışanı gösterir.
//       Oplog, yakın geçmişte gerçekten yazılmış olanın tek doğruluk
//       kaynağıdır. Bu script son N saniyenin oplog'unu okur, namespace
//       + op türüne göre toplar ve her kıdemli MongoDB DBA'in cevap
//       beklediği soruyu üretir: "şu an bu replica set'i hangi yazımlar
//       domine ediyor?". Bonus: büyük transaction'ları (çoklu doküman
//       yazımları) ve gürültülü collection'ları tespit eder.
//
// On Atlas: Free / Shared tiers restrict access to local.* — this
// script will print a clear notice rather than failing.

const adminDb = db.getSiblingDB("admin");
const local   = db.getSiblingDB("local");

// Window in seconds (default 60) — set OPLOG_WINDOW_SECS to override.
const windowSecs = (typeof OPLOG_WINDOW_SECS === "number")
    ? OPLOG_WINDOW_SECS : 60;

// ── 1. AM I ON A REPLICA SET? ───────────────────────────────────────
let rs;
try {
    rs = adminDb.runCommand({ replSetGetStatus: 1 });
} catch (e) {
    print("Cannot read replSetGetStatus — this script requires a replica set member.");
    quit();
}

print(`Replica set : ${rs.set}`);
print(`Member state: ${rs.members.find(m => m.self === true).stateStr}`);
print(`Window      : last ${windowSecs}s`);

// ── 2. CHECK OPLOG ACCESS ──────────────────────────────────────────
let oplog;
try {
    oplog = local.oplog.rs;
    oplog.findOne();   // permission probe
} catch (e) {
    print("\nlocal.oplog.rs is not readable on this deployment (Atlas Shared/Free).");
    print("On a dedicated tier, run this script with read access to local.");
    quit();
}

// ── 3. AGGREGATE THE WINDOW ────────────────────────────────────────
// Cutoff Timestamp from N seconds ago; oplog ts is a BSON Timestamp,
// which the driver compares correctly against another Timestamp built
// from the unix-second-aligned now().
const cutoffSec = Math.floor((Date.now() - windowSecs * 1000) / 1000);
const cutoff = new Timestamp(cutoffSec, 0);

const summary = oplog.aggregate([
    { $match: { ts: { $gte: cutoff } } },
    {
        // Op codes:
        //   "i" = insert      "u" = update      "d" = delete
        //   "c" = command     "n" = no-op       "t" = txn (multi-doc)
        $group: {
            _id: { ns: "$ns", op: "$op" },
            count: { $sum: 1 },
            // For "u" updates, $set wins — peek at the first one.
            firstTs: { $min: "$ts" },
            lastTs:  { $max: "$ts" }
        }
    },
    { $project: {
        _id: 0,
        ns:    "$_id.ns",
        op:    "$_id.op",
        count: 1,
        first_ts: "$firstTs",
        last_ts:  "$lastTs"
    } },
    { $sort: { count: -1 } }
], { allowDiskUse: true }).toArray();

print(`\n═══ WRITE PATTERN — last ${windowSecs}s ═══`);
const totalOps = summary.reduce((s, r) => s + r.count, 0);
print(`Total ops in window: ${totalOps}`);
print(`Estimated rate     : ${(totalOps / windowSecs).toFixed(2)} ops/sec`);
printjson(summary.slice(0, 25));

// ── 4. LARGE / TXN OPS — drill into "t" entries ────────────────────
const largeTxns = oplog.find(
    { ts: { $gte: cutoff }, op: "t" },
    { ts: 1, ns: 1, "o.applyOps": 0 }   // hide the bulky payload
).limit(10).toArray();

if (largeTxns.length > 0) {
    print("\n═══ MULTI-DOC TRANSACTIONS IN WINDOW ═══");
    print("These are oplog entries representing committed multi-document");
    print("transactions. Each has an applyOps array (suppressed here).");
    printjson(largeTxns);
}

// ── 5. NOISIEST NAMESPACES ─────────────────────────────────────────
const byNs = oplog.aggregate([
    { $match: { ts: { $gte: cutoff }, ns: { $ne: "" } } },
    { $group: { _id: "$ns", ops: { $sum: 1 } } },
    { $project: { _id: 0, ns: "$_id", ops: 1 } },
    { $sort: { ops: -1 } },
    { $limit: 10 }
]).toArray();

print("\n═══ TOP 10 NOISY NAMESPACES ═══");
printjson(byNs);

// ── 6. SAMPLE EXECUTION SHAPES ─────────────────────────────────────
// For the top noisy namespace, show 3 representative ops so you can
// see what the writes actually look like.
if (byNs.length > 0) {
    const topNs = byNs[0].ns;
    const samples = oplog.find(
        { ts: { $gte: cutoff }, ns: topNs },
        { ts: 1, op: 1, ns: 1, o: 1, o2: 1 }
    ).limit(3).toArray();

    print(`\n═══ SAMPLES FROM ${topNs} ═══`);
    samples.forEach(s => {
        const preview = JSON.stringify(s, null, 0);
        print(preview.length > 600 ? preview.substring(0, 600) + "..." : preview);
    });
}
