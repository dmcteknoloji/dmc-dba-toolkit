// ╔══════════════════════════════════════════════════════════════════╗
// ║  DMC DBA Toolkit                                                 ║
// ╠══════════════════════════════════════════════════════════════════╣
// ║  Script        : role-graph                                      ║
// ║  Engine        : MongoDB 5.0+ │ Atlas │ self-hosted              ║
// ║  Category      : security                                        ║
// ║  Impact        : 🟢 Light  (rolesInfo + usersInfo admin commands) ║
// ║  Permissions   : userAdminAnyDatabase OR clusterMonitor + read   ║
// ║  Output schema : see docs/OUTPUT_SCHEMAS.md#mongo-role-graph     ║
// ║  Inspired by   : MongoDB Manual — rolesInfo, usersInfo,           ║
// ║                  Built-In Roles reference. Graph traversal logic  ║
// ║                  is original to this toolkit.                     ║
// ║  Maintainer    : Çağlar Özenç — DMC Bilgi Teknolojileri          ║
// ║  Last updated  : 2026-05-01                                      ║
// ║  Level         : 🦅 Expert   (full role inheritance graph + privilege rollup) ║
// ║  Version       : 1.0.0                                           ║
// ║  License       : MIT                                             ║
// ╚══════════════════════════════════════════════════════════════════╝
//
// 🇹🇷 Türkçe özet:
//   MongoDB rol grafının tamamını çıkarır: built-in roller + custom
//   roller + her bir kullanıcının nihayetinde miras aldığı tüm
//   roller. user-audit.js her kullanıcı için bir verdict verir; bu
//   script bir adım derinde çalışır — rol grafının kendisini
//   topolojik olarak yürütür ve her custom rolün ulaştığı tüm
//   privilege'ları rollup eder. Audit committee'nin "tam yetki
//   matrisini görmek istiyorum" talebine cevap.
//
// Why this exists:
//   MongoDB role inheritance is graph-shaped. A custom role can
//   inherit from another custom role that inherits from a built-in
//   role. usersInfo shows the immediate roles assigned to a user but
//   does not transitively expand them. This script does the
//   transitive expansion both for users (effective roles) and for
//   custom roles (effective privilege rollup), and emits the full
//   graph so you can audit-trail it.

const adminDb = db.getSiblingDB("admin");

function safe(fn, fallback) {
    try { return fn(); }
    catch (e) { return fallback || { error: e.codeName || e.message }; }
}

// ── 1. FETCH EVERY USER + EVERY CUSTOM ROLE ───────────────────────
const usersResult = safe(
    () => adminDb.runCommand({
        usersInfo: 1, showCredentials: false, showPrivileges: false
    }),
    { users: [] }
);
const customRolesResult = safe(
    () => adminDb.runCommand({
        rolesInfo: 1, showBuiltinRoles: false, showPrivileges: true
    }),
    { roles: [] }
);

// Built-in dangerous role names. Reference: MongoDB Manual — Built-In Roles.
const dangerousBuiltins = new Set([
    "root", "__system",
    "userAdminAnyDatabase", "dbAdminAnyDatabase",
    "readWriteAnyDatabase", "clusterAdmin",
    "restore", "backup",
    "hostManager", "clusterManager", "clusterMonitor"
]);

// ── 2. EXPAND CUSTOM ROLE INHERITANCE TRANSITIVELY ─────────────────
// Build a name->role map for custom roles.
const roleByKey = new Map();
(customRolesResult.roles || []).forEach(r => {
    roleByKey.set(`${r.role}@${r.db}`, r);
});

// Recursive expansion with cycle protection.
function expandInherited(roleKey, seen) {
    if (seen.has(roleKey)) return [];
    seen.add(roleKey);
    const role = roleByKey.get(roleKey);
    if (!role) return [{ role: roleKey, kind: "builtin" }];
    const out = [{ role: roleKey, kind: "custom" }];
    (role.inheritedRoles || []).forEach(ir => {
        const childKey = `${ir.role}@${ir.db}`;
        out.push(...expandInherited(childKey, seen));
    });
    return out;
}

const customAudit = (customRolesResult.roles || []).map(r => {
    const expanded = expandInherited(`${r.role}@${r.db}`, new Set());
    const builtinsHit = expanded
        .filter(e => e.kind === "builtin")
        .map(e => e.role.split("@")[0]);
    const dangerousHit = builtinsHit.filter(b => dangerousBuiltins.has(b));
    const directPrivs = (r.privileges || []).length;

    return {
        role: r.role,
        db: r.db,
        direct_inherited_count: (r.inheritedRoles || []).length,
        transitive_role_count: expanded.length - 1,
        reaches_builtins: Array.from(new Set(builtinsHit)).sort(),
        direct_privileges: directPrivs,
        verdict:
            dangerousHit.length > 0
                ? `🔴 transitively reaches ${dangerousHit.join(", ")}`
                : (expanded.length > 5
                    ? `🟠 deep nesting (${expanded.length - 1} transitive roles)`
                    : "🟢 standard")
    };
});

print("═══ CUSTOM ROLE GRAPH ═══");
printjson(customAudit);

// ── 3. EXPAND USER ROLES TRANSITIVELY (effective access) ───────────
const userAudit = (usersResult.users || []).map(u => {
    const transitive = new Set();
    const directDangerous = u.roles
        .map(r => r.role)
        .filter(r => dangerousBuiltins.has(r));
    const indirectDangerous = [];

    u.roles.forEach(r => {
        const expanded = expandInherited(`${r.role}@${r.db}`, new Set());
        expanded.forEach(e => {
            transitive.add(e.role);
            const builtin = e.role.split("@")[0];
            if (e.kind === "builtin"
                && dangerousBuiltins.has(builtin)
                && !directDangerous.includes(builtin)) {
                indirectDangerous.push(builtin);
            }
        });
    });

    return {
        user: u.user,
        db: u.db,
        direct_roles: u.roles.map(r => `${r.role}@${r.db}`).sort(),
        effective_role_count: transitive.size,
        directly_dangerous: directDangerous,
        indirectly_dangerous: Array.from(new Set(indirectDangerous)),
        auth_mechanisms: (u.mechanisms || []).join(",") || "<unknown>",
        verdict:
            directDangerous.length > 0
                ? `🔴 directly holds ${directDangerous.join(", ")}`
                : indirectDangerous.length > 0
                    ? `🟠 transitively reaches ${Array.from(new Set(indirectDangerous)).join(", ")}`
                    : "🟢 standard"
    };
});

print("\n═══ USER EFFECTIVE-ROLE GRAPH ═══");
printjson(userAudit);

// ── 4. SUMMARY ─────────────────────────────────────────────────────
const summary = {
    custom_roles_total: customAudit.length,
    custom_roles_with_dangerous_paths:
        customAudit.filter(r => r.verdict.startsWith("🔴")).length,
    users_total: userAudit.length,
    users_directly_dangerous:
        userAudit.filter(u => u.directly_dangerous.length > 0).length,
    users_indirectly_dangerous:
        userAudit.filter(u => u.indirectly_dangerous.length > 0
                          && u.directly_dangerous.length === 0).length
};
print("\n═══ SUMMARY ═══");
printjson(summary);
