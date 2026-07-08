# 開発ログ(進捗共有用)

ChatGPT に進捗を共有するための要約ログ。最新の作業を一番上に追記する。
形式・運用は本体リポジトリ `../FbSQL/docs/dev-log.md` と同じ。

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
