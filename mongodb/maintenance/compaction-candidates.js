// ╔══════════════════════════════════════════════════════════════════╗
// ║  DMC DBA Toolkit                                                 ║
// ╠══════════════════════════════════════════════════════════════════╣
// ║  Script        : compaction-candidates                           ║
// ║  Engine        : MongoDB 5.0+ │ Atlas │ self-hosted              ║
// ║  Category      : maintenance                                     ║
// ║  Impact        : 🟡 Medium  (collStats per collection)            ║
// ║  Permissions   : read on the target database (or clusterMonitor) ║
// ║  Output schema : see docs/OUTPUT_SCHEMAS.md#mongo-compaction-candidates ║
// ║  Inspired by   : MongoDB Manual — collStats / compact command    ║
// ║  Maintainer    : Çağlar Özenç — DMC Bilgi Teknolojileri          ║
// ║  Last updated  : 2026-06-11                                      ║
// ║  Level         : 🌳 Middle  (compact reclaims, but it locks)     ║
// ║  Version       : 1.0.0                                           ║
// ║  License       : MIT                                             ║
// ╚══════════════════════════════════════════════════════════════════╝
//
// 🇹🇷 Türkçe özet:
//   WiredTiger freeStorageSize'ı storageSize'a oranlayıp parçalanmış
//   collection'ları bulur. Yüksek oran = delete/update sonrası geri
//   kazanılabilir disk. >%20 ve >256 MB boşluk olanlar compact adayı
//   olarak işaretlenir. compact birincil node'da bloklayıcıdır; tercih
//   edilen yol secondary'lerde rolling resync'tir. Salt-okunur: önerilen
//   komut yalnızca metindir, hiçbir şey çalıştırılmaz.
//
// What this is for:
//   "Storage keeps growing but our document count is flat." That gap is
//   usually free space WiredTiger is holding after deletes and updates.
//   This script ranks collections by fragmentation — freeStorageSize as a
//   share of storageSize — and flags the ones where reclaiming is worth
//   the disruption. It does NOT run compact(); the command is text.
//
// The trade-off you must know before acting:
//   compact() takes a database lock on the node it runs on. The safe
//   pattern is a rolling operation on secondaries, then a stepdown — not
//   compact() on a busy primary. The verdict reflects that.

const dbName = (typeof DB === "string") ? DB : db.getName();
const targetDb = db.getSiblingDB(dbName);

const FREE_MIN_BYTES = 256 * 1048576; // ignore anything under 256 MB reclaimable
const FREE_MIN_RATIO = 0.20;          // and under 20% of storage

const rows = targetDb.getCollectionInfos({ type: "collection" }).map(info => {
    let s;
    try {
        s = targetDb.runCommand({ collStats: info.name });
    } catch (e) {
        return { collection: info.name, error: e.message };
    }

    const free = s.freeStorageSize || 0;
    const storage = s.storageSize || 0;
    const ratio = storage ? free / storage : 0;
    const candidate = free >= FREE_MIN_BYTES && ratio >= FREE_MIN_RATIO;

    let verdict;
    if (s.freeStorageSize === undefined) {
        verdict = "⚪ freeStorageSize unavailable on this tier — can't assess";
    } else if (candidate) {
        verdict = "🔴 fragmented — reclaim via rolling resync, or compact() in a window";
    } else if (free > FREE_MIN_BYTES) {
        verdict = "🟠 some free space — watch as it grows";
    } else {
        verdict = "🟢 compact enough";
    }

    return {
        collection: info.name,
        storage_size_mb: storage ? +(storage / 1048576).toFixed(1) : null,
        free_storage_mb: free ? +(free / 1048576).toFixed(1) : null,
        fragmentation_pct: storage ? Math.round(100 * ratio) : null,
        suggested_action: candidate
            ? `db.getSiblingDB("${dbName}").runCommand({ compact: "${info.name}" })  // run on a SECONDARY`
            : null,
        verdict: verdict
    };
});

rows.sort((a, b) => (b.fragmentation_pct || 0) - (a.fragmentation_pct || 0));

print(`db=${dbName}, collections=${rows.length}, ranked by fragmentation_pct:`);
printjson(rows.slice(0, 25));
