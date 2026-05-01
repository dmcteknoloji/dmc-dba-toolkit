// ╔══════════════════════════════════════════════════════════════════╗
// ║  DMC DBA Toolkit                                                 ║
// ╠══════════════════════════════════════════════════════════════════╣
// ║  Script        : user-audit                                      ║
// ║  Engine        : MongoDB 5.0+ │ Atlas (limited) │ self-hosted    ║
// ║  Category      : security                                        ║
// ║  Impact        : 🟢 Light  (admin commands)                       ║
// ║  Permissions   : userAdminAnyDatabase OR clusterMonitor + read   ║
// ║                  on admin                                         ║
// ║  Output schema : see docs/OUTPUT_SCHEMAS.md#mongo-user-audit     ║
// ║  Inspired by   : usersInfo, rolesInfo commands — MongoDB Manual  ║
// ║  Maintainer    : Çağlar Özenç — DMC Bilgi Teknolojileri          ║
// ║  Last updated  : 2026-04-29                                      ║
// ║  Level         : 🌳 Middle   (production-grade, assumes DBA familiarity)           ║
// ║  Version       : 1.0.0                                           ║
// ║  License       : MIT                                             ║
// ╚══════════════════════════════════════════════════════════════════╝
//
// Why this exists / Neden var:
//   EN: Mongo's role model is more nuanced than most realise: built-in
//       roles like root/dbOwner/userAdminAnyDatabase grant escalation
//       paths that aren't visible from a quick `usersInfo`. This script
//       lists every user, expands their inherited privileges, and flags
//       the ones that effectively own the cluster — including custom
//       roles that nest one of the dangerous built-ins.
//   TR: Mongo'nun rol modeli görünenden derindir; root/dbOwner/
//       userAdminAnyDatabase gibi built-in roller hızlı bir
//       `usersInfo` çıktısında görünmeyen yetki yükselme yolları
//       sunar. Bu script tüm kullanıcıları listeler, miras alınmış
//       yetkilerini açar ve cluster'ı fiilen kontrol edenleri —
//       built-in tehlikelilerden birini iç içe içeren custom roller
//       dahil — işaretler.

const adminDb = db.getSiblingDB("admin");

// Roles considered "effective superuser" — listed in the official docs
// as granting cluster-wide privileged actions.
const dangerousRoles = new Set([
    "root",
    "__system",
    "userAdminAnyDatabase",
    "dbAdminAnyDatabase",
    "readWriteAnyDatabase",
    "clusterAdmin",
    "restore",
    "backup"
]);

function safe(fn) {
    try { return fn(); }
    catch (e) { return { error: e.codeName || e.message }; }
}

// ── 1. ALL USERS ACROSS ALL DBs ────────────────────────────────────
const usersResult = safe(() =>
    adminDb.runCommand({
        usersInfo: 1,
        showCredentials: false,
        showPrivileges: true
    })
);

if (!usersResult.users) {
    print("usersInfo returned no users — likely insufficient privilege.");
    print(JSON.stringify(usersResult, null, 2));
    quit();
}

const findings = usersResult.users.map(u => {
    // Flatten role list into role names (ignoring db scope for the flag).
    const roles = u.roles.map(r => r.role);

    // Did any role hit the dangerous list?
    const dangerous = roles.filter(r => dangerousRoles.has(r));

    // Auth mechanism — flag accounts still on legacy SCRAM-SHA-1.
    const mech = (u.mechanisms || []).join(",") || "<unknown>";

    return {
        user: u.user,
        db: u.db,
        roles: u.roles.map(r => `${r.role}@${r.db}`).join(", "),
        auth_mechanisms: mech,
        custom_data_keys: u.customData ? Object.keys(u.customData) : [],
        verdict: [
            dangerous.length > 0
                ? `🔴 holds ${dangerous.join(", ")} — effective cluster admin`
                : null,
            mech.includes("SCRAM-SHA-1") && !mech.includes("SCRAM-SHA-256")
                ? "🟠 only SCRAM-SHA-1 — upgrade auth"
                : null,
            u.user === "root" || u.user === "admin"
                ? "ℹ️ named 'root'/'admin' — common but worth verifying scope"
                : null
        ].filter(Boolean).join(" | ") || "🟢 standard"
    };
});

print(`═══ MONGO USER AUDIT (${findings.length} users) ═══`);
printjson(findings);

// ── 2. CUSTOM ROLES — do any nest dangerous roles? ─────────────────
const rolesResult = safe(() =>
    adminDb.runCommand({
        rolesInfo: 1,
        showBuiltinRoles: false,
        showPrivileges: false
    })
);

if (rolesResult.roles && rolesResult.roles.length > 0) {
    const customAudit = rolesResult.roles.map(r => {
        const inherited = (r.inheritedRoles || []).map(ir => ir.role);
        const dangerous = inherited.filter(x => dangerousRoles.has(x));
        return {
            role: r.role,
            db: r.db,
            inherited: r.inheritedRoles
                ? r.inheritedRoles.map(ir => `${ir.role}@${ir.db}`).join(", ")
                : "",
            verdict: dangerous.length > 0
                ? `🔴 nests ${dangerous.join(", ")} — anyone with this role is admin`
                : "🟢 standard"
        };
    });
    print(`\n═══ CUSTOM ROLES (${customAudit.length}) ═══`);
    printjson(customAudit);
}
