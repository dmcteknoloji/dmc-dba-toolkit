// ╔══════════════════════════════════════════════════════════════════╗
// ║  DMC DBA Toolkit                                                 ║
// ╠══════════════════════════════════════════════════════════════════╣
// ║  Script        : balancer-status                                 ║
// ║  Engine        : MongoDB 5.0+ (sharded clusters) │ Atlas         ║
// ║  Category      : sharding                                        ║
// ║  Impact        : 🟢 Light  (admin commands; mongos required)      ║
// ║  Permissions   : clusterMonitor on admin                         ║
// ║  Output schema : see docs/OUTPUT_SCHEMAS.md#mongo-balancer-status║
// ║  Inspired by   : sh.getBalancerState(), sh.balancerCollectionStatus║
// ║                  — MongoDB Manual public reference.               ║
// ║  Maintainer    : Çağlar Özenç — DMC Bilgi Teknolojileri          ║
// ║  Last updated  : 2026-04-21                                      ║
// ║  Level         : 🌳 Middle   (production-grade, assumes DBA familiarity)           ║
// ║  Version       : 1.0.0                                           ║
// ║  License       : MIT                                             ║
// ╚══════════════════════════════════════════════════════════════════╝
//
// Why this exists / Neden var:
//   EN: When the cluster slows down on a specific shard, the balancer
//       is the first place to look — but its state is split across
//       three different views: enabled flag, current run state, and
//       per-collection imbalance. This script returns all three plus
//       the active-window (so you don't blame the balancer for being
//       "off" when it's just outside its allowed hours).
//   TR: Cluster belirli bir shard'da yavaşladığında bakılacak ilk yer
//       balancer'dır — ama durumu üç farklı görünüme dağılmıştır:
//       enabled flag, anlık çalışma durumu ve collection-bazlı
//       dengesizlik. Bu script üçünü ve aktif-pencereyi de döner —
//       saatleri dışında çalışan bir balancer'ı suçlamayasın diye.
//
// Run on a mongos. On a non-sharded mongod, sharding admin commands
// will return a clear error rather than misleading results.

const adminDb = db.getSiblingDB("admin");

function safe(fn, label) {
    try { return fn(); }
    catch (e) { return { error: e.codeName || e.message, _label: label }; }
}

// ── 1. STATE FLAGS ─────────────────────────────────────────────────
const balancerStatus = safe(() => sh.getBalancerState(), "balancer_state");
const balancerRunning = safe(() => sh.isBalancerRunning(), "balancer_running");

// Active window: balancer can be enabled but only allowed to move
// chunks during certain hours. Stored in config.settings.
const activeWindow = safe(() =>
    db.getSiblingDB("config").settings.findOne({ _id: "balancer" }),
    "active_window"
);

print("═══ BALANCER STATE ═══");
print(JSON.stringify({
    enabled: balancerStatus,
    running_now: balancerRunning,
    active_window: (activeWindow && activeWindow.activeWindow) || "always",
    autoSplit: (activeWindow && activeWindow.autoSplit !== undefined)
        ? activeWindow.autoSplit
        : "default-true"
}, null, 2));

// ── 2. CHUNK MIGRATIONS — recent activity ──────────────────────────
const recentMoves = safe(() =>
    db.getSiblingDB("config").changelog
        .find(
            { what: { $in: ["moveChunk.start", "moveChunk.from",
                            "moveChunk.commit", "moveChunk.error"] } },
            { _id: 0, time: 1, what: 1, ns: 1, details: 1, server: 1 }
        )
        .sort({ time: -1 })
        .limit(20)
        .toArray()
);

print("\n═══ RECENT CHUNK MIGRATIONS (last 20) ═══");
printjson(recentMoves);

// ── 3. PER-COLLECTION BALANCE STATUS ───────────────────────────────
// Loops sharded collections and reports balancer's view of imbalance.
const shardedColls = safe(() =>
    db.getSiblingDB("config").collections
        .find({ dropped: false }, { _id: 1 })
        .toArray()
);

if (Array.isArray(shardedColls)) {
    print("\n═══ PER-COLLECTION BALANCE ═══");
    const out = [];
    shardedColls.forEach(c => {
        const ns = c._id;
        const status = safe(() =>
            adminDb.runCommand({ balancerCollectionStatus: ns }),
            ns
        );
        out.push({
            ns: ns,
            balancerCompliant: status.balancerCompliant,
            firstNonCompliantShard: status.firstNonCompliantShard,
            chunkCount: status.chunkCount,
            note:
                status.balancerCompliant === false
                    ? `🟠 imbalance reported on ${status.firstNonCompliantShard}`
                    : null
        });
    });
    printjson(out);
}

// ── 4. CHUNK COUNT PER SHARD ───────────────────────────────────────
print("\n═══ CHUNK COUNTS PER SHARD ═══");
printjson(
    safe(() =>
        db.getSiblingDB("config").chunks.aggregate([
            { $group: { _id: "$shard", chunks: { $sum: 1 } } },
            { $sort: { chunks: -1 } }
        ]).toArray()
    )
);
