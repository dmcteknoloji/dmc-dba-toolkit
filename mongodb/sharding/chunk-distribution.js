// ╔══════════════════════════════════════════════════════════════════╗
// ║  DMC DBA Toolkit                                                 ║
// ╠══════════════════════════════════════════════════════════════════╣
// ║  Script        : chunk-distribution                              ║
// ║  Engine        : MongoDB 5.0+ (sharded clusters) │ Atlas         ║
// ║  Category      : sharding                                        ║
// ║  Impact        : 🟡 Medium  (config.chunks aggregation; large on  ║
// ║                              clusters with millions of chunks)   ║
// ║  Permissions   : clusterMonitor on admin                         ║
// ║  Output schema : see docs/OUTPUT_SCHEMAS.md#mongo-chunk-distribution ║
// ║  Inspired by   : config.chunks reference — MongoDB Manual         ║
// ║  Maintainer    : Çağlar Özenç — DMC Bilgi Teknolojileri          ║
// ║  Last updated  : 2026-04-26                                      ║
// ║  Level         : 🦅 Expert   (output requires deep DMV / internals knowledge)      ║
// ║  Version       : 1.0.0                                           ║
// ║  License       : MIT                                             ║
// ╚══════════════════════════════════════════════════════════════════╝
//
// Why this exists / Neden var:
//   EN: A balanced chunk count doesn't mean a balanced workload.
//       Hash-sharded collections distribute writes evenly, but
//       range-sharded collections often pile recent data on a single
//       shard ("hot shard" pattern with monotonically increasing
//       shard keys). This script reports per-collection chunk count
//       per shard, plus the shard-key shape — so you can spot the
//       hot shard before throughput dies.
//   TR: Eşit chunk sayısı eşit iş yükü demek değildir. Hash-sharded
//       koleksiyonlar yazıları dengeli dağıtır; range-sharded olanlar
//       ise tekdüze artan shard key kullanıldığında yeni datayı tek
//       bir shard'a yığar ("hot shard" paterni). Bu script
//       koleksiyon × shard chunk sayısını ve shard-key şeklini
//       döner — throughput çökmeden önce hot shard'ı yakalamak için.

const cfgDb = db.getSiblingDB("config");

// ── 1. CHUNKS PER COLLECTION × SHARD ───────────────────────────────
const distribution = cfgDb.chunks.aggregate([
    { $group: {
        _id: { ns: "$ns", shard: "$shard" },
        chunks: { $sum: 1 }
    } },
    { $group: {
        _id: "$_id.ns",
        per_shard: { $push: { shard: "$_id.shard", chunks: "$chunks" } },
        total_chunks: { $sum: "$chunks" }
    } },
    { $project: {
        _id: 0,
        ns: "$_id",
        total_chunks: 1,
        per_shard: 1
    } },
    { $sort: { total_chunks: -1 } }
]).toArray();

// Compute imbalance metric: max(shard) / mean(shard).
distribution.forEach(d => {
    const counts = d.per_shard.map(p => p.chunks);
    const max = Math.max.apply(null, counts);
    const mean = counts.reduce((a, b) => a + b, 0) / counts.length;
    d.max_to_mean_ratio = +(max / mean).toFixed(2);
    d.skew_flag = (d.max_to_mean_ratio > 2.0 && d.total_chunks > 20)
        ? "🟠 imbalance — one shard has >2x the mean"
        : null;
});

print("═══ CHUNK DISTRIBUTION PER COLLECTION ═══");
printjson(distribution.slice(0, 25));

// ── 2. SHARD-KEY SHAPES — what to look at when you see imbalance ──
print("\n═══ SHARD-KEY DEFINITIONS ═══");
printjson(
    cfgDb.collections.find(
        { dropped: false },
        { _id: 1, key: 1, unique: 1, lastmod: 1 }
    ).sort({ _id: 1 }).toArray()
);

// ── 3. JUMBO CHUNK CHECK ───────────────────────────────────────────
// jumbo chunks cannot be split or moved by the balancer; they're a
// classic root cause for "balancer reports OK but one shard fills up".
const jumbo = cfgDb.chunks.find({ jumbo: true }).toArray();
print(`\n═══ JUMBO CHUNKS: ${jumbo.length} ═══`);
if (jumbo.length > 0) {
    print("These chunks are flagged jumbo — they exceed chunkSize and the");
    print("balancer cannot move them. Investigate the shard key for");
    print("monotonic patterns or low cardinality. Refer to the official");
    print("\"Jumbo Chunks\" docs for resolution paths.");
    printjson(jumbo.slice(0, 10).map(c => ({
        ns: c.ns, shard: c.shard, min: c.min, max: c.max
    })));
}
