# CLAUDE.md — FbSQL-experiments プロジェクトコンテキスト

このファイルは本リポジトリの開発者向けコンテキストの主要な情報源である。
プロジェクト全体の背景・設計原則は **本体リポジトリ `../FbSQL` の `CLAUDE.md`** を
先に読むこと(FbSQL とは何か、5つの設計原則、Non-goals はそちらが正)。

## 役割分担(固定)

- **`FbSQL/`(本体)**: PostgreSQL Extension 本体、README、docs、CI、PGXN 公開用
  ファイル、そして **`paper/` 配下の JSS 論文原稿**。
- **`FbSQL-experiments/`(本リポジトリ)**: 再現実験、smoke tests、
  MADlib / Spark MLlib / PostgresML 等との比較、論文用の表・図・CSV 生成、
  結果ファイル、実験環境固定。

論文原稿は本体側に置く。本リポジトリは原稿が参照する**素材(数値・表・図)を
生成する側**であり、投稿時に JSS replication material として Zenodo で DOI
アーカイブする(fbrglm-experiments の型を踏襲)。

## 比較対象(固定)

- **Tier 1(実験必須)**: Apache MADlib
- **Tier 2(可能なら実験)**: Apache Spark MLlib、PostgresML
- **Tier 3(文献比較中心)**: Apache Hivemall、H2O-3 + Sparkling Water
- **BigQuery ML は OSS でないため OSS 比較対象から除外**。論文 Discussion で
  非 OSS の SQL-ML 例として触れる程度に留める。

Related Work 比較表の**編集元は `data/related_work.csv`**(手で保守する唯一の
情報源)。`scripts/50_make_related_work_table.R` が Markdown 表
(`results/tables/related_work.md`)を生成する。未評価セルは `TBD`。
比較は機能の有無ではなく **SQL 言語設計の観点**(formula・閉包性・順序独立性・
Named Arguments・NULL・モデル表現)で行う。

## スクリプト番号体系(fbrglm-experiments の思想を踏襲)

- `00-09`: environment / install / smoke tests
- `10-19`: FbSQL Running Example と R parity テスト
- `20-29`: Apache MADlib 比較
- `30-39`: Spark MLlib 比較
- `40-49`: PostgresML 比較
- `50-59`: 設計比較表
- `60-69`: 図
- `70-79`: 論文用テーブル

## 実験環境

- 実行環境は**本体リポジトリの Docker イメージ `fbsql-dev`**(PostgreSQL 16 +
  PL/R 8.4.8.6 + R 4.2.2)に固定する。R のステップも同イメージ内で実行し、
  ホスト側の R には依存しない。
- 本体リポジトリの場所は環境変数 `FBSQL_ROOT`、無指定なら兄弟ディレクトリ
  `../FbSQL` で解決する。開発者固有パスをコミットしない。
- MADlib / Spark / PostgresML の環境は各 Tier の実験に着手する時に Docker で
  固定する(本リポジトリに compose 定義等を置く)。

## 再現性の規律(fbrglm-experiments を踏襲)

1. 入力データは手書きの決定的データ(現状 RNG 不使用。将来ジェネレータを書く
   場合は必ずシード固定)。
2. `results/` 配下の生成物を git にコミットし、変更は diff で追跡する。
3. パリティ検証(script 12)は不一致で非ゼロ終了し、チェックとして機能する。
4. 数値は生成元で4桁丸めしてから比較・保存する(FbSQL 本体の pg_regress と同じ)。

## 運用・規約(本体リポジトリと共通)

- **コミット**: 英語・命令形・大文字始まりの1行サマリ。接頭辞なし、本文なし。
- **公開成果物(README・スクリプト内コメント・生成表)は英語**。本ファイルと
  `docs/dev-log.md` は例外的に日本語。
- **作業のたびに `docs/dev-log.md` へ追記し、`main` に push する**(本体と同じ運用)。
- CI は置かない(fbrglm-experiments と同じ方針)。環境固定は Docker イメージで行う。

## Non-goals

- 統計計算の性能改善・大規模分散実行の主張(本体 CLAUDE.md の Non-goals 参照)。
  ベンチマークは「SQL 言語設計の比較」を裏付ける最小限に留める。
- 本リポジトリに論文原稿を置くこと(原稿は `FbSQL/paper/`)。

## 現状(2026-07-08)

立ち上げ直後: Running Example 再現パイプライン(00 / 10 / 11 / 12)と
Related Work 比較表の雛形(data/related_work.csv + script 50)のみ。
MADlib 等の比較実験は未着手。
