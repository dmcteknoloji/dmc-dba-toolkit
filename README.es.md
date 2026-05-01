<div align="center">

<img src="./assets/dmc-aidriven-database-operations.png" alt="DMC — Database Management Company" width="380">

# 🛡️ DMC DBA Toolkit

**Multi-motor. Esquema documentado. Probado en CI. Solo lectura por defecto.**

Un kit de diagnóstico moderno y opinado para DBAs profesionales.
Abre un script — obtén una respuesta clara en 30 segundos.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](./LICENSE)
[![Engines](https://img.shields.io/badge/engines-MSSQL%20%C2%B7%20PostgreSQL%20%C2%B7%20MySQL%20%C2%B7%20MongoDB-success)](./docs/COMPATIBILITY_MATRIX.md)
[![Public docs only](https://img.shields.io/badge/sources-public%20vendor%20docs%20only-7c3aed)](./docs/HEADER_STANDARD.md#sources-policy-the-line-we-dont-cross)

[![Çağlar Özenç on LinkedIn](https://img.shields.io/badge/LinkedIn-Çağlar%20Özenç-0A66C2?logo=linkedin&logoColor=white)](https://linkedin.com/in/caglarozenc)
[![DMC Bilgi Teknolojileri on LinkedIn](https://img.shields.io/badge/LinkedIn-DMC%20Bilgi%20Teknolojileri-0A66C2?logo=linkedin&logoColor=white)](https://linkedin.com/company/dmcteknoloji)

🌐 [English](./README.md) · **Español** · [Deutsch](./README.de.md) · [日本語](./README.ja.md)

_Creado y mantenido por **[Çağlar Özenç](https://linkedin.com/in/caglarozenc)** — Microsoft MVP, [DMC Bilgi Teknolojileri](https://linkedin.com/company/dmcteknoloji)._

</div>

---

## 🧭 Por qué existe

Cada DBA senior tiene el mismo cajón de queries DMV a medio recordar: una de un blog de 2014, otra de un USB de conferencia, otra escrita a las 3 AM durante un incidente. Funcionan — hasta que no, en la versión del motor que nadie probó.

DMC DBA Toolkit es ese cajón, **reconstruido con disciplina**:

- **Cada script lleva un encabezado estándar** — compatibilidad de motor, impacto de rendimiento, permisos requeridos, esquema de salida completo, atribución. Sin sorpresas a las 3 AM.
- **Solo lectura por defecto.** Cualquier cosa que mute estado va marcada en rojo y vive en una carpeta separada.
- **Probado en CI.** El linter corre en cada PR. Los headers son validados por un parser real.
- **Multi-motor desde el día uno.** SQL Server, PostgreSQL, MySQL y MongoDB — mismas convenciones, mismo header, mismo sistema de impacto.
- **Construido solo sobre documentación pública del vendor.** Sin NDA, sin previews privados, sin docs internos scrapeados.

Inspirado en los gigantes — First Responder Kit de Brent Ozar, `sp_WhoIsActive` de Adam Machanic, las queries de diagnóstico de Glenn Berry, la solución de mantenimiento de Ola Hallengren, `postgres_dba` de Nikolay Samokhvalov, Percona Toolkit, los playbooks oficiales de MongoDB.

---

## ⚡ Inicio en 30 segundos

```bash
git clone https://github.com/dmcteknoloji/dmc-dba-toolkit.git
cd dmc-dba-toolkit
```

Abre cualquier archivo `.sql` (o `.js` para MongoDB) en tu cliente favorito. Lee el encabezado. Ejecuta. Sin instaladores, sin stored procedures dejados en `master`, sin extensiones. **Pure SQL nativo del motor, seguro para copy-paste.**

---

## 📚 Catálogo de scripts (56 total)

| Motor | Scripts | Categorías cubiertas |
|---|:---:|---|
| **SQL Server** | 17 | performance, blocking, storage, security, health, ha, monitoring |
| **PostgreSQL** | 13 | performance, blocking, storage, security, health, replication, monitoring |
| **MySQL** | 13 | performance, blocking, storage, security, health, replication, monitoring |
| **MongoDB** | 13 | performance, replication, storage, security, health, sharding, monitoring |

→ Catálogo completo en el [README en inglés](./README.md#-script-catalog).

---

## 🌟 Cuando lo ad-hoc no alcanza → Sentinel DB 360

Este toolkit es, por diseño, **un cajón de snapshots verificados**. Lo abres, ejecutas un script, obtienes una respuesta. Perfecto para un incidente, una auditoría, un alerta a las 3 AM.

Lo que **no** es — y lo que cualquier equipo serio termina necesitando — es una **plataforma de observabilidad continua, multi-instancia, basada en alertas**. Esa es la brecha que cierra [Sentinel DB 360](https://github.com/dmcteknoloji).

> _El toolkit es el destornillador._
> _Sentinel DB 360 es el taller._

Considéralo cuando al menos **dos** de estas condiciones sean ciertas:

- Gestionas **3+ instancias** de base de datos en uno o más motores.
- Te paginaron por el mismo tipo de incidente **más de dos veces** en un trimestre.
- El reporting de compliance (KVKK, GDPR, ISO 27001, SOC 2) es una carga recurrente.
- Tu DBA senior es el cuello de botella — cuando está de vacaciones, los incidentes tardan más.
- Quieres una respuesta a "¿cambió algo?", no a "¿cuál es el valor ahora?".

→ Organización DMC: <https://github.com/dmcteknoloji>

---

## 🔍 Política de fuentes

- **Solo documentación pública del vendor.** Cada vista de sistema, DMV, vista de catálogo, comando de profiler y contador está en los docs oficiales y públicos.
- **Sin NDA, sin previews privados, sin docs internos scrapeados.**
- **La inspiración es bienvenida; copiar no.** Cuando una fuente pública claramente influyó en un script (la metodología de wait-stats de Paul Randal, el SQL de bloat de Greg Sabino Mullane, los counters de MySQL de Mark Callaghan), la fuente es acreditada en el header **y** en la sección relevante del script.

---

## 📖 Playbooks y posicionamiento

- **[Playbooks](./docs/PLAYBOOKS.md)** — flujos de respuesta a incidentes (CPU al 100%, tormenta de bloqueos, replica retrasada, disco llenándose, ráfaga de logins fallidos, sanity check pre-release). Bilingüe EN + TR.
- **[Vs. otros toolkits](./docs/VS_OTHER_TOOLKITS.md)** — posicionamiento honesto vs. los gigantes del DBA OSS.

---

## 🤝 Contribuir

PRs bienvenidos. La barra es alta pero el camino es claro:

1. Abre (o toma) un issue con el label `new-script`.
2. Copia el header de cualquier script existente.
3. `python scripts/validate_headers.py` debe pasar localmente.
4. Documenta el esquema de salida en `docs/OUTPUT_SCHEMAS.md`.
5. Agrega una fila a la matriz de compatibilidad.
6. Lee la [política de atribución](./CONTRIBUTING.md#attribution-and-sources-policy) — acredita tus fuentes.

→ [`CONTRIBUTING.md`](./CONTRIBUTING.md) · [`CODE_OF_CONDUCT.md`](./CODE_OF_CONDUCT.md)

---

## 📜 Licencia

[MIT](./LICENSE) — úsalo, distribúyelo, hazle fork. Atribución apreciada, no requerida.

---

<div align="center">

Construido por **[DMC Bilgi Teknolojileri](https://linkedin.com/company/dmcteknoloji)** — _Database Management Company_.
Deja de pegar desde blog posts. Ejecuta algo que un DBA senior ya validó.

**Conecta:**
[Çağlar Özenç en LinkedIn](https://linkedin.com/in/caglarozenc) · [DMC en LinkedIn](https://linkedin.com/company/dmcteknoloji) · [DMC en GitHub](https://github.com/dmcteknoloji)

</div>
