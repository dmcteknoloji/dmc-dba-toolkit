// ╔══════════════════════════════════════════════════════════════════╗
// ║  DMC DBA Toolkit                                                 ║
// ╠══════════════════════════════════════════════════════════════════╣
// ║  Script        : index-usage                                     ║
// ║  Engine        : MongoDB 5.0+ │ Atlas │ self-hosted              ║
// ║  Category      : performance                                     ║
// ║  Impact        : 🟡 Medium  (iterates collections in target DB)   ║
// ║  Permissions   : read on the target database                     ║
// ║  Output schema : see docs/OUTPUT_SCHEMAS.md#mongo-index-usage    ║
// ║  Inspired by   : MongoDB Manual — $indexStats aggregation stage  ║
// ║  Maintainer    : Çağlar Özenç — DMC Bilgi Teknolojileri          ║
// ║  Last updated  : 2026-01-18                                      ║
// ║  Level         : 🌳 Middle   (production-grade, assumes DBA familiarity)           ║
// ║  Version       : 1.0.0                                           ║
// ║  License       : MIT                                             ║
// ╚══════════════════════════════════════════════════════════════════╝
//
// 🇹🇷 Türkçe özet:
//   Hedef DB'deki tüm collection'lar için $indexStats agregasyonu — hangi
//   indeks ne kadar erişim almış. Counter'lar mongod restart'ta sıfırlanır
//   (BÜYÜK uyarı). Replica set'te primary VE her secondary'de çalıştır;
//   okuma trafiği secondary'ye düşmüş olabilir.
//
// What this is for:
//   Every Mongo deployment over a year old has indexes nobody remembers
//   creating. They cost RAM in the working set and write amplification
//   on every insert/update. This script runs $indexStats against every
//   collection in the chosen database and surfaces:
//     - Indexes with zero accesses since the last mongod restart
//       (strong "drop me" candidates — but read the caveat).
//     - Indexes accessed less than N times relative to collection size.
//     - The age of the access counter — to know if "zero" means "really
//       not used" or "we restarted ten minutes ago, ask me again next
//       week".
//
// The big caveat:
//   $indexStats counters reset on every mongod restart. A node that
//   restarted last night will say every index is unused. Always check
//   the `since` field — and on a replica set, run on the primary AND
//   each secondary, because read traffic might hit a secondary.

const dbName = (typeof DB === "string") ? DB : db.getName();
const targetDb = db.getSiblingDB(dbName);

const minSinceHours = (typeof MIN_SINCE_HOURS === "number") ? MIN_SINCE_HOURS : 24;
const cutoff = new Date(Date.now() - minSinceHours * 3600 * 1000);

const collections = targetDb.getCollectionInfos({ type: "collection" })
    .map(c => c.name)
    .filter(n => !n.startsWith("system."));

const findings = [];

collections.forEach(coll => {
    let stats;
    try {
        stats = targetDb.getCollection(coll).aggregate([{ $indexStats: {} }]).toArray();
    } catch (e) {
        // Views and some special collections don't support $indexStats.
        return;
    }

    stats.forEach(s => {
        const since = s.accesses && s.accesses.since;
        const ops = s.accesses && s.accesses.ops || 0;
        const tooFresh = since && new Date(since) > cutoff;

        // Skip the _id_ index — you can never drop it, no point flagging.
        if (s.name === "_id_") return;

        findings.push({
            collection: coll,
            index_name: s.name,
            ops_since_reset: ops,
            counter_since: since,
            counter_age_hours: since
                ? Math.round((Date.now() - new Date(since).getTime()) / 3600000)
                : null,
            verdict: ops === 0 && !tooFresh
                ? "candidate-for-drop"
                : ops === 0 && tooFresh
                ? "zero-but-counter-too-fresh"
                : ops < 100
                ? "low-usage"
                : "active"
        });
    });
});

// Sort: drop candidates first, then low usage, then active. Keep the
// list short — if you have hundreds of collections, you'll need this
// surfaced to a dashboard, not a terminal.
const order = ["candidate-for-drop", "zero-but-counter-too-fresh", "low-usage", "active"];
findings.sort((a, b) =>
    order.indexOf(a.verdict) - order.indexOf(b.verdict)
    || a.ops_since_reset - b.ops_since_reset
);

print(`db=${dbName}, collections scanned=${collections.length}, findings=${findings.length}`);
printjson(findings.slice(0, 50));
