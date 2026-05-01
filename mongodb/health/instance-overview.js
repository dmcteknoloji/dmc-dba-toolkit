// ╔══════════════════════════════════════════════════════════════════╗
// ║  DMC DBA Toolkit                                                 ║
// ╠══════════════════════════════════════════════════════════════════╣
// ║  Script        : instance-overview                               ║
// ║  Engine        : MongoDB 5.0+ │ Atlas │ self-hosted              ║
// ║  Category      : health                                          ║
// ║  Impact        : 🟢 Light  (a handful of admin commands)          ║
// ║  Permissions   : clusterMonitor (or read+listDatabases on admin) ║
// ║  Output schema : see docs/OUTPUT_SCHEMAS.md#mongo-instance-overview║
// ║  Inspired by   : MongoDB Manual — serverStatus, hostInfo, isMaster║
// ║  Maintainer    : Çağlar Özenç — DMC Bilgi Teknolojileri          ║
// ║  Last updated  : 2026-02-09                                      ║
// ║  Level         : 🌱 Newborn  (safe to run blind, output is self-explanatory)       ║
// ║  Version       : 1.0.0                                           ║
// ║  License       : MIT                                             ║
// ╚══════════════════════════════════════════════════════════════════╝
//
// 🇹🇷 Türkçe özet:
//   MongoDB için "hiç görmediğim cluster'da ilk 5 dakika" scripti.
//   Kimlik, role, sürüm, host, uptime, bağlantı sayısı, anlık op baskısı,
//   replica set / sharding durumu — tek printout, incident kanalına yapıştır.
//   Atlas tier'larına ve sharded mongos endpoint'lerine karşı defansif yazılmıştır.
//
// What this is for:
//   The "I just got paged on a Mongo cluster I've never seen before"
//   first-five-minutes script. Identity, role, version, host, uptime,
//   connection count, current operation pressure, replica set / sharding
//   state — all in one printout, ready to paste into the incident
//   channel.
//
//   Built to be defensive: every command is wrapped because Atlas
//   tiers, sharded mongos endpoints, and standalone mongod each forbid
//   different things. Anything we can't read shows as "<n/a>" rather
//   than throwing.

function safe(fn, fallback) {
    try { return fn(); } catch (e) { return fallback || `<n/a: ${e.codeName || e.message}>`; }
}

const adminDb = db.getSiblingDB("admin");

const ss   = safe(() => adminDb.runCommand({ serverStatus: 1 }), {});
const host = safe(() => adminDb.runCommand({ hostInfo: 1 }), {});
const hello = safe(() => adminDb.runCommand({ hello: 1 }), {});
const buildInfo = safe(() => adminDb.runCommand({ buildInfo: 1 }), {});
const dbList = safe(() => adminDb.runCommand({ listDatabases: 1, nameOnly: true }), { databases: [] });

const overview = {
    IDENTITY: {
        version: buildInfo.version || "<n/a>",
        gitVersion: (buildInfo.gitVersion || "").substring(0, 7),
        modules: buildInfo.modules || [],
        deployment: hello.msg === "isdbgrid" ? "mongos / sharded" : (hello.setName ? `replica set: ${hello.setName}` : "standalone"),
        rs_role: hello.isWritablePrimary === true
            ? "primary"
            : hello.secondary === true
                ? "secondary"
                : (hello.arbiterOnly ? "arbiter" : "<unknown>"),
        host: ss.host || hello.me || "<n/a>",
        os: host.os ? `${host.os.name} ${host.os.version}` : "<n/a>",
        cpu_arch: host.system ? host.system.cpuArch : "<n/a>"
    },
    UPTIME: {
        uptime_secs: ss.uptime || null,
        local_time: ss.localTime ? ss.localTime.toISOString() : "<n/a>"
    },
    WORKLOAD: {
        connections_current: ss.connections ? ss.connections.current : null,
        connections_available: ss.connections ? ss.connections.available : null,
        active_clients_total: ss.globalLock && ss.globalLock.activeClients
            ? ss.globalLock.activeClients.total : null,
        op_inserts_per_sec: ss.opcounters ? ss.opcounters.insert : null,
        op_queries_per_sec: ss.opcounters ? ss.opcounters.query : null,
        op_updates_per_sec: ss.opcounters ? ss.opcounters.update : null,
        op_deletes_per_sec: ss.opcounters ? ss.opcounters.delete : null,
        // Note: opcounters are *cumulative since startup*, not "per sec".
        // Sample twice with a gap for an actual rate; this is the snapshot.
        opcounter_note: "values above are cumulative since startup, not /sec"
    },
    DATABASES: {
        count: dbList.databases ? dbList.databases.length : null,
        names: dbList.databases
            ? dbList.databases.map(d => d.name).filter(n => n !== "admin" && n !== "config" && n !== "local")
            : []
    },
    STORAGE_ENGINE: {
        name: ss.storageEngine ? ss.storageEngine.name : "<n/a>",
        supportsCommittedReads: ss.storageEngine ? ss.storageEngine.supportsCommittedReads : null,
        readOnly: ss.storageEngine ? ss.storageEngine.readOnly : null
    }
};

printjson(overview);
