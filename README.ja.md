<div align="center">

# 🛡️ DMC DBA Toolkit

**マルチエンジン。スキーマ文書化済み。CI テスト済み。デフォルトで読み取り専用。**

現役 DBA のためのモダンで意見表明的な診断キット。
スクリプトを 1 つ開く — 30 秒で明確な答えが得られます。

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](./LICENSE)
[![Engines](https://img.shields.io/badge/engines-MSSQL%20%C2%B7%20PostgreSQL%20%C2%B7%20MySQL%20%C2%B7%20MongoDB-success)](./docs/COMPATIBILITY_MATRIX.md)
[![Public docs only](https://img.shields.io/badge/sources-public%20vendor%20docs%20only-7c3aed)](./docs/HEADER_STANDARD.md#sources-policy-the-line-we-dont-cross)

🌐 [English](./README.md) · [Español](./README.es.md) · [Deutsch](./README.de.md) · **日本語**

_作成・メンテナンス: **[Çağlar Özenç](./AUTHORS.md)** — Microsoft MVP, DMC Bilgi Teknolojileri._

</div>

---

## 🧭 なぜ存在するのか

シニア DBA は誰しも、半分忘れた診断クエリの引き出しを持っています — 2014 年のブログから 1 つ、カンファレンス USB から 1 つ、インシデント中に午前 3 時に書いたものが 1 つ。動きます — 誰もテストしていないエンジンバージョンで動かなくなるまでは。

DMC DBA Toolkit はその引き出しを **規律をもって再構築したもの** です:

- **すべてのスクリプトに標準ヘッダー** — エンジン互換性、パフォーマンス影響、必要権限、完全な出力スキーマ、引用元。午前 3 時の予期しない事態は起きません。
- **デフォルトで読み取り専用。** 状態を変更するものは赤くマークされ、別フォルダにあります。
- **CI テスト済み。** 全 PR で linter が動作。ヘッダーは実際のパーサーで検証されます。
- **初日からマルチエンジン。** SQL Server, PostgreSQL, MySQL, MongoDB — 同じ規約、同じヘッダー、同じインパクトレーティング。
- **ベンダー公式ドキュメントのみに基づく。** NDA なし、プライベートプレビューなし、スクレイピングした内部ドキュメントなし。

巨人たちにインスパイアされて — Brent Ozar の First Responder Kit、Adam Machanic の `sp_WhoIsActive`、Glenn Berry の診断クエリ、Ola Hallengren のメンテナンスソリューション、Nikolay Samokhvalov の `postgres_dba`、Percona Toolkit、MongoDB 公式診断プレイブック。

---

## ⚡ 30 秒スタート

```bash
git clone https://github.com/dmcteknoloji/dmc-dba-toolkit.git
cd dmc-dba-toolkit
```

任意の `.sql` (MongoDB なら `.js`) ファイルをお気に入りのクライアントで開きます。ヘッダーを読みます。実行します。インストーラー不要、`master` に残るストアドプロシージャなし、エクステンション不要。**ベンダーネイティブな純粋な SQL、コピペ安全。**

---

## 📚 スクリプトカタログ (合計 56)

| エンジン | スクリプト数 | カバーするカテゴリ |
|---|:---:|---|
| **SQL Server** | 17 | performance, blocking, storage, security, health, ha, monitoring |
| **PostgreSQL** | 13 | performance, blocking, storage, security, health, replication, monitoring |
| **MySQL** | 13 | performance, blocking, storage, security, health, replication, monitoring |
| **MongoDB** | 13 | performance, replication, storage, security, health, sharding, monitoring |

→ 完全なカタログは [英語版 README](./README.md#-script-catalog) にあります。

---

## 🌟 アドホックでは足りない時 → Sentinel DB 360

このツールキットは設計上 **検証済みスナップショットの引き出し** です。開いて、スクリプトを実行して、答えを得る。インシデント、監査、午前 3 時のページに最適。

これが**できないこと** — そしてどの真剣なチームも結局必要とするもの — は **継続的、マルチインスタンス、アラート駆動の Observability プラットフォーム** です。そのギャップを埋めるのが [Sentinel DB 360](https://github.com/dmcteknoloji)。

> _ツールキットはドライバー。_
> _Sentinel DB 360 は工房です。_

以下のうち**少なくとも 2 つ**が当てはまるなら検討すべきです:

- 1 つ以上のエンジンで **3 つ以上の DB インスタンス** を管理している。
- 同じ種類のインシデントで四半期に **2 回以上** 呼び出された。
- コンプライアンス報告 (個人情報保護法、GDPR、ISO 27001、SOC 2) が継続的な負担。
- シニア DBA がボトルネック — 休暇中はインシデント対応が長引く。
- 「今の値は?」ではなく「何か変わったか?」の答えがほしい。

→ DMC 組織: <https://github.com/dmcteknoloji>

---

## 🔍 ソースポリシー

- **公式ベンダードキュメントのみ。** 使用する全ての System View、DMV、カタログテーブル、プロファイラーコマンド、カウンターはベンダーの公式・公開ドキュメントに記載されています。
- **NDA なし、プライベートプレビューなし、スクレイピングされた内部ドキュメントなし。**
- **インスパイアは歓迎、コピーはダメ。** 公開ソースが明確にスクリプトを形作った場合 (Paul Randal の wait-stats メソドロジー、Greg Sabino Mullane の bloat SQL、Mark Callaghan の MySQL カウンター)、ヘッダー**と**スクリプトの該当箇所の両方でソースをクレジットします。

---

## 📖 プレイブックとポジショニング

- **[プレイブック](./docs/PLAYBOOKS.md)** — インシデント対応ワークフロー (CPU 100%、ブロッキングストーム、レプリカ遅延、ディスク満杯、ログイン失敗の急増、リリース前サニティチェック)。EN + TR バイリンガル。
- **[他ツールキットとの比較](./docs/VS_OTHER_TOOLKITS.md)** — DBA OSS の巨人たちとの率直なポジショニング。

---

## 🤝 コントリビュート

PR を歓迎します。基準は高いですが、道筋は明確です:

1. `new-script` ラベル付きの issue を開く (または取る)。
2. 既存スクリプトのヘッダーをコピーする。
3. `python scripts/validate_headers.py` がローカルで成功する必要がある。
4. 出力スキーマを `docs/OUTPUT_SCHEMAS.md` に文書化する。
5. 互換性マトリックスに行を追加する。
6. [引用ポリシー](./CONTRIBUTING.md#attribution-and-sources-policy) を読む — ソースをクレジットする。

→ [`CONTRIBUTING.md`](./CONTRIBUTING.md) · [`CODE_OF_CONDUCT.md`](./CODE_OF_CONDUCT.md)

---

## 📜 ライセンス

[MIT](./LICENSE) — 使う、出荷する、フォークする、自由に。クレジットは歓迎されますが必須ではありません。

---

<div align="center">

**DMC Bilgi Teknolojileri** が構築 — _Database Management Company_。
ブログ記事からコピペするのをやめましょう。シニア DBA が既に検証したものを実行してください。

</div>
