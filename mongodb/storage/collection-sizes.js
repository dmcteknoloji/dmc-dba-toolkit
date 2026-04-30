// ╔══════════════════════════════════════════════════════════════════╗
// ║  DMC DBA Toolkit                                                 ║
// ╠══════════════════════════════════════════════════════════════════╣
// ║  Script        : collection-sizes                                ║
// ║  Engine        : MongoDB 5.0+ │ Atlas │ self-hosted              ║
// ║  Category      : storage                                         ║
// ║  Impact        : 🟡 Medium  (collStats per collection)            ║
// ║  Permissions   : read on the target database (or clusterMonitor) ║
// ║  Output schema : see docs/OUTPUT_SCHEMAS.md#mongo-collection-sizes║
// ║  Inspired by   : MongoDB Manual — collStats command              ║
// ║  Maintainer    : Çağlar Özenç — DMC Bilgi Teknolojileri          ║
// ║  Last updated  : 2025-12-05                                      ║
// ║  Version       : 1.0.0                                           ║
// ║  License       : MIT                                             ║
// ╚══════════════════════════════════════════════════════════════════╝
//
// What this is for:
//   You have a 1.2 TB MongoDB and the storage bill is going up. Where is
//   the data? collStats per collection is the answer, but running it
//   one-by-one in mongosh is tedious and the default fields don't tell
//   you what you actually need to know.
//
//   This script reports, per collection in a database:
//     - logical document size  (size)
//     - on-disk storage size   (storageSize)
//     - total index size       (totalIndexSize)
//     - free storage           (freeStorageSize, WT only — fragmentation)
//     - average doc size       (avgObjSize)
//     - document count
//
// The key insight:
//   storageSize ≠ size. WiredTiger compresses on disk; storageSize is
//   what you see on the volume. freeStorageSize is the gap left behind
//   by deletes — high values mean you'd benefit from compact() (offline)
//   or, less disruptively, a rolling resync of secondaries.
//
// Atlas note:
//   On Atlas Shared / Free tiers, db.runCommand({ collStats: ... })
//   may return a subset of fields. We tolerate missing fields rather
//   than throwing, so the script remains usable across tiers.

const dbName = (typeof DB === "string") ? DB : db.getName();
const targetDb = db.getSiblingDB(dbName);

const collInfos = targetDb.getCollectionInfos({ type: "collection" });

const rows = collInfos.map(info => {
    let s;
    try {
        s = targetDb.runCommand({ collStats: info.name });
    } catch (e) {
        return { collection: info.name, error: e.message };
    }
    const fragPct = (s.storageSize && s.freeStorageSize)
        ? Math.round(100 * s.freeStorageSize / s.storageSize)
        : null;
    return {
        collection: info.name,
        document_count: s.count,
        avg_doc_size_bytes: s.avgObjSize ? Math.round(s.avgObjSize) : null,
        size_mb: s.size ? +(s.size / 1048576).toFixed(2) : null,
        storage_size_mb: s.storageSize
            ? +(s.storageSize / 1048576).toFixed(2)
            : null,
        index_size_mb: s.totalIndexSize
            ? +(s.totalIndexSize / 1048576).toFixed(2)
            : null,
        free_storage_mb: s.freeStorageSize
            ? +(s.freeStorageSize / 1048576).toFixed(2)
            : null,
        fragmentation_pct: fragPct,
        capped: !!s.capped,
        sharded: !!s.sharded
    };
});

// Sort by storage_size_mb desc — that's the bill payer.
rows.sort((a, b) =>
    (b.storage_size_mb || 0) - (a.storage_size_mb || 0)
);

print(`db=${dbName}, collections=${rows.length}, top 25 by storage_size_mb:`);
printjson(rows.slice(0, 25));
