// ╔══════════════════════════════════════════════════════════════════╗
// ║  DMC DBA Toolkit                                                 ║
// ╠══════════════════════════════════════════════════════════════════╣
// ║  Script        : getting-started                                 ║
// ║  Engine        : MongoDB 5.0+ │ Atlas │ self-hosted              ║
// ║  Category      : health                                          ║
// ║  Impact        : 🟢 Light  (admin commands; read-only)            ║
// ║  Permissions   : clusterMonitor (or read on admin) recommended    ║
// ║  Output schema : see docs/OUTPUT_SCHEMAS.md#mongo-getting-started  ║
// ║  Inspired by   : MongoDB Manual — Diagnostic Commands tutorial    ║
// ║  Maintainer    : Çağlar Özenç — DMC Bilgi Teknolojileri          ║
// ║  Last updated  : 2026-05-01                                      ║
// ║  Level         : 🌱 Newborn  (your first MongoDB diagnostic — tutorial style) ║
// ║  Version       : 1.0.0                                           ║
// ║  License       : MIT                                             ║
// ╚══════════════════════════════════════════════════════════════════╝
//
// Why this exists / Neden var:
//   EN: Your very first MongoDB diagnostic, with extensive comments.
//       Run with `mongosh "<uri>" --quiet --file getting-started.js`.
//       By the end you'll know what `serverStatus` is, what
//       `replSetGetStatus` tells you, and why we use admin commands
//       instead of "queries" for diagnostics.
//   TR: İlk MongoDB tanı sorgun, bol açıklamalı. Çalıştırma:
//       `mongosh "<uri>" --quiet --file getting-started.js`. Sonunda
//       `serverStatus` nedir, `replSetGetStatus` neyi söyler ve tanı
//       için neden "sorgu" yerine admin komutu kullandığımızı
//       bileceksin.
//
// Admin commands vs queries / Admin komutları vs sorgular:
//   EN: MongoDB exposes server state through *commands* run against
//       the `admin` database — `serverStatus`, `hostInfo`, `hello`,
//       `replSetGetStatus`. These are not collection queries; they
//       are RPC-style requests to the server itself.
//   TR: MongoDB, sunucu durumunu `admin` veritabanına karşı çalışan
//       *komutlar* aracılığıyla açar — `serverStatus`, `hostInfo`,
//       `hello`, `replSetGetStatus`. Bunlar collection sorgusu
//       değildir; sunucuya RPC tarzı isteklerdir.

const adminDb = db.getSiblingDB("admin");

// safe() wraps a command so a permission error doesn't crash the
// whole script. Atlas tiers and limited roles forbid different
// commands, so we tolerate failures gracefully.
function safe(fn, label) {
    try { return fn(); }
    catch (e) { return { error: e.codeName || e.message, _what: label }; }
}

// ── 1. WHERE AM I? · NEREDEYİM? ────────────────────────────────────
const buildInfo = safe(() => adminDb.runCommand({ buildInfo: 1 }), "buildInfo");
const hello     = safe(() => adminDb.runCommand({ hello: 1 }), "hello");
const hostInfo  = safe(() => adminDb.runCommand({ hostInfo: 1 }), "hostInfo");

print("═══ IDENTITY ═══");
print(`MongoDB version : ${buildInfo.version || "<n/a>"}`);
print(`Git revision    : ${(buildInfo.gitVersion || "").substring(0, 7)}`);
print(`Host            : ${hello.me || "<n/a>"}`);
print(`Deployment      : ${hello.msg === "isdbgrid"
    ? "mongos (sharded cluster)"
    : (hello.setName ? `replica set: ${hello.setName}` : "standalone")}`);
print(`This member is  : ${hello.isWritablePrimary === true
    ? "PRIMARY (accepts writes)"
    : hello.secondary === true ? "SECONDARY (read-only)"
    : "<unknown>"}`);
if (hostInfo.os) {
    print(`OS              : ${hostInfo.os.name} ${hostInfo.os.version}`);
}

// ── 2. HOW LONG HAS THIS BEEN UP? · NE KADAR SÜREDİR AÇIK? ────────
const ss = safe(() => adminDb.runCommand({ serverStatus: 1 }), "serverStatus");

print("");
print("═══ UPTIME ═══");
if (ss.uptime !== undefined) {
    const days = Math.floor(ss.uptime / 86400);
    const hours = Math.floor((ss.uptime % 86400) / 3600);
    const minutes = Math.floor((ss.uptime % 3600) / 60);
    print(`Uptime          : ${days}d ${hours}h ${minutes}m  (${ss.uptime}s)`);
    print(`Local time      : ${ss.localTime ? ss.localTime.toISOString() : "<n/a>"}`);
}

// ── 3. CONNECTIONS · BAĞLANTILAR ──────────────────────────────────
print("");
print("═══ CONNECTIONS ═══");
if (ss.connections) {
    print(`Current         : ${ss.connections.current}`);
    print(`Available       : ${ss.connections.available}`);
    print(`Total created   : ${ss.connections.totalCreated}  (cumulative since startup)`);
}
if (ss.globalLock && ss.globalLock.activeClients) {
    print(`Active readers  : ${ss.globalLock.activeClients.readers}`);
    print(`Active writers  : ${ss.globalLock.activeClients.writers}`);
}

// ── 4. DATABASES · VERİTABANLARI ──────────────────────────────────
const dbs = safe(() => adminDb.runCommand({
    listDatabases: 1, nameOnly: false
}), "listDatabases");

print("");
print("═══ DATABASES ═══");
if (dbs.databases) {
    dbs.databases
        .filter(d => !["admin", "config", "local"].includes(d.name))
        .sort((a, b) => (b.sizeOnDisk || 0) - (a.sizeOnDisk || 0))
        .forEach(d => {
            const mb = ((d.sizeOnDisk || 0) / 1048576).toFixed(2);
            print(`  ${d.name.padEnd(40)} ${mb.padStart(12)} MB`);
        });
}

// ── 5. STORAGE ENGINE · DEPOLAMA MOTORU ───────────────────────────
print("");
print("═══ STORAGE ENGINE ═══");
if (ss.storageEngine) {
    print(`Name            : ${ss.storageEngine.name}`);
    print(`Persistent      : ${ss.storageEngine.persistent}`);
    if (ss.storageEngine.name === "wiredTiger") {
        print(`Note            : ✅ WiredTiger — what you expect on modern MongoDB`);
    }
}

// Next steps / Sıradaki adımlar:
print("");
print("───────────────────────────────────────────────────────────");
print("Next steps · Sıradaki adımlar:");
print("  EN: Read mongodb/health/instance-overview.js for the polished");
print("      version, then mongodb/performance/current-slow-ops.js.");
print("  TR: Cilalı sürüm: mongodb/health/instance-overview.js,");
print("      sonra mongodb/performance/current-slow-ops.js.");
