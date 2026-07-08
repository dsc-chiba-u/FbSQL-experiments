# 開発ログ(進捗共有用)

ChatGPT に進捗を共有するための要約ログ。最新の作業を一番上に追記する。
形式・運用は本体リポジトリ `../FbSQL/docs/dev-log.md` と同じ。

---

## 2026-07-08: Apache MADlib 最小比較パイプライン(Tier 1)

### Summary

- MADlib 環境を Docker で固定: `madlib/postgres_11:jenkins`(MADlib プロジェクト自身の
  CI イメージ、PostgreSQL 11)をベースに、Apache アーカイブの **MADlib 1.21.0 を
  ソースビルド**する `docker/madlib/Dockerfile` を作成。ビルド・madpack インストール・
  `madlib.version()` まで**実機で成功**
- Running Example 相当(churn の logistic 回帰)を MADlib で実行(20番台スクリプト)。
  gender は**手動 one-hot**(FbSQL の formula との対比が目的)
- FbSQL との数値比較: **係数4件・予測3件が4桁一致**。設計差2件を注記付きで記録:
  (1) novel level 'Nonbinary' を MADlib は**無言で参照水準として 0.2020 と予測**
  (FbSQL は error / NULL)、(2) `(Intercept)` の std_err が4桁目のみ相違
  (IRLS 許容差。3桁까지一致)
- NULL 行の扱い: fit 時は MADlib も complete case(`num_missing_rows_skipped=1` を
  実測)、predict 時は NULL 特徴量 → NULL(c104 で実測)
- モデル表現の観測: fit は **void を返し2テーブルを副作用で生成**(モデル本体は
  並列配列で term 名なし、`<out>_summary` は呼び出し文字列を保存)。
  Relation-in / Relation-out・metadata 表現の差が実測で裏付けられた
- `data/related_work.csv` の MADlib 行の TBD を実測ベースで解消(offset / weight /
  reproducibility は未調査のため TBD のまま)

### Changed Files

- `docker/madlib/Dockerfile`: MADlib 1.21.0 ソースビルド環境(新規)
- `scripts/20_madlib_smoke.sh` / `21_madlib_running_example.sh` /
  `sql/21_madlib_running_example.sql` / `22_compare_fbsql_madlib.R`: 新規
- `results/raw/running_example_{model,predictions}_madlib.csv`: 実測出力
- `results/summary/madlib_running_example_summary.csv`: 数値比較(13行、注記付き)
- `results/summary/madlib_api_design_notes.csv`: API 設計比較15観点(手保守)
- `data/related_work.csv` + `results/tables/related_work.md`: MADlib 行更新・再生成
- `README.md`: MADlib 比較セクション追加

### Validation

- `20_madlib_smoke.sh` → MADlib 1.21.0 installed successfully / version 応答
- `21_madlib_running_example.sh` → fit・predict・CSV 出力まで成功
- `22_compare_fbsql_madlib.R` → 11値一致、想定内の設計差2件(注記付き)、
  想定外の不一致 0

### Known Issues

- madpack は root 実行不可(pg_ctl を呼ぶため)→ `docker exec -u postgres` で解決済み
- コンテナ起動のたびに madpack install が走る(約1分)。頻繁になれば DB 焼き込みを検討
- MADlib の offset / weight 対応と reproducibility 方針は未調査(related_work.csv は TBD)
- PostgreSQL 11 + MADlib 1.21 の組(API 比較には十分だが、最新 PG との組は未検証)

### Next Step

- Tier 2 の PostgresML(同じ PostgreSQL extension 同士の比較として次に価値が高い)
  の最小環境固定と Running Example 相当の実行、または MADlib 行の残 TBD
  (offset / weight)の文書調査

Commit: `Add MADlib running example comparison`(本エントリを含むコミット)。
push 後の `git status`: clean。

---

## 2026-07-08: FbSQL-experiments リポジトリの立ち上げ

### Summary

- companion repository として立ち上げ(fbrglm-experiments の型を踏襲)。役割分担を
  固定: 論文原稿は `FbSQL/paper/`、本リポジトリは再現実験・比較・論文用素材の生成
- 比較対象を Tier で固定: Tier 1 = Apache MADlib(実験必須)、Tier 2 = Spark MLlib /
  PostgresML(可能なら実験)、Tier 3 = Hivemall / H2O-3 + Sparkling Water(文献比較)。
  BigQuery ML は非 OSS のため比較対象から除外
- Related Work 比較表の雛形を作成(`data/related_work.csv`、19列 × 6システム。
  FbSQL 行のみ記入済み、他は TBD)+ Markdown 生成スクリプト(script 50)
- Running Example 再現パイプラインの骨格を作成し、**通しで動作確認済み**:
  00(環境チェック)→ 10(fbsql-dev コンテナで fit→predict、CSV 出力)→
  11(R 参照値)→ 12(パリティ比較、不一致で非ゼロ終了)
- パリティ結果: **全13値(係数4 + SE4 + 予測5)で FbSQL と R が一致**
  (`results/summary/running_example_parity.csv` にコミット済み)
- スクリプト番号体系を確立(00-09 env / 10-19 running example / 20-29 MADlib /
  30-39 Spark / 40-49 PostgresML / 50-59 比較表 / 60-69 図 / 70-79 論文テーブル)

### Changed Files

- `README.md`: 全面改訂(役割分担、Tier、構成、番号体系、実行手順、再現性の規律)
- `CLAUDE.md`: 新規(本体 CLAUDE.md を正とし、experiments 固有の文脈のみ)
- `data/customer.csv`: Running Example データ(2025年12行 + 2026年5行、決定的)
- `data/related_work.csv`: 比較表の編集元(手保守の唯一の情報源)
- `scripts/00_check_environment.sh` / `10_running_example_fbsql.sh` /
  `sql/10_running_example.sql` / `11_running_example_r_reference.R` /
  `12_running_example_parity.R` / `50_make_related_work_table.R`
- `results/raw/*.csv`, `results/summary/running_example_parity.csv`,
  `results/tables/related_work.md`: 生成物をコミット
- `R/`, `results/figures/`: .gitkeep で予約

### Validation

- `00_check_environment.sh` → OK(docker / fbsql-dev イメージ / FbSQL リポジトリ検出)
- 10 → 11 → 12 の通し実行で全13値一致(c104 の NULL age → NULL、c105 の novel level
  'Nonbinary' → on_new_levels='na' で NULL、R 側は既知水準のみ predict + NA で模擬)
- R ステップはコンテナ内 R 4.2.2 で実行(ホスト R 不使用)。
  非 root 実行(`docker run -u`)で権限問題がないことを確認

### Known Issues

- MADlib / Spark / PostgresML の環境構築は未着手(各 Tier 着手時に Docker で固定)
- `data/related_work.csv` の FbSQL 以外の行はほぼ TBD(調査タスク)
- CI は意図的に置かない(fbrglm-experiments と同方針)

### Next Step

- Tier 1: Apache MADlib の Docker 環境固定と、Running Example 相当
  (logistic 回帰の fit → predict)を MADlib API で書いた比較スクリプト(20番台)
- `data/related_work.csv` の MADlib 行を実験・文書調査で埋める

Commit: `Initialize FbSQL experiments repository`(本エントリを含むコミット)。
push 後の `git status`: clean。
