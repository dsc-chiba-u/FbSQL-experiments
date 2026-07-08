# 開発ログ(進捗共有用)

ChatGPT に進捗を共有するための要約ログ。最新の作業を一番上に追記する。
形式・運用は本体リポジトリ `../FbSQL/docs/dev-log.md` と同じ。

---

## 2026-07-08: Apache Spark MLlib 最小比較パイプライン(Tier 2)

### Summary

- Spark 環境を固定: 公式イメージ(Spark 3.5.1 / Java 17 / python3)+ numpy のみ追加
  する `docker/spark/Dockerfile`(公式イメージの python3 には numpy がなく
  pyspark.ml が import 不能 — 実測)。smoke → fit → predict まで**実機で成功**
- Running Example を `spark.sql`(relation定義)→ `RFormula("churn_flag ~ age +
  gender")` + `GeneralizedLinearRegression(binomial/logit)` の Pipeline で実行
- **最重要の発見: RFormula は formula の形をしているが R の意味論ではない**。
  StringIndexer が水準を頻度順に並べ最頻でない水準を参照にするため、参照水準が
  'F'(Rのソート第1水準)ではなく 'Other' になる。**同一モデルの別パラメータ化**で
  あることを数値検証(intercept_spark = intercept_fbsql + genderOther_fbsql 等が
  丸め誤差内で成立、予測は4桁で完全一致: 0.0406 / 0.9794 / 0.4280)。
  R ワークフロー移植時の危険点として記録
- **NULL / novel level は単一スイッチ `handleInvalid`**: 既定 'error' は NULL 特徴量で
  transform が失敗(実測)、'skip' は**行を黙って落とす**(実測: 5行入力→3行出力。
  FbSQL の「行を保持して NULL 予測」に相当する選択肢がない)
- term 名(`gender_F` 形式)は ML attribute metadata からプログラムで抽出する必要が
  あった — metadata がオブジェクト束縛である証左
- `data/related_work.csv` の Spark 行を実測+公式ドキュメント(offset/weight は GLR の
  offsetCol/weightCol、interaction は RFormula の ':'/'*')で更新

### Changed Files

- `docker/spark/Dockerfile`: 公式イメージ + numpy(新規)
- `scripts/30_spark_smoke.sh` / `31_spark_running_example.{sh,py}` /
  `32_compare_fbsql_spark.R`: 新規
- `results/raw/running_example_{model,predictions}_spark.csv`: 実測出力
- `results/summary/spark_running_example_summary.csv`(再パラメータ化の数値検証
  付き15行)+ `spark_api_design_notes.csv`(17観点): 新規
- `data/related_work.csv` + `results/tables/related_work.md`: Spark 行更新
- `README.md`: Spark 比較セクション追加

### Validation

- smoke → SPARK_VERSION 3.5.1 / RFormula import OK
- 31 実行 → 既定でのNULL失敗観測 + skip での予測出力
- 32 比較 → **7値一致**(age 係数・SE、予測5件)+ 想定内の設計差8件
  (参照水準の再パラメータ化を数値検証済み)、想定外の不一致 0

### Known Issues

- handleInvalid='keep'(未知水準のバケット化)は未実測(文書ベースで記録)
- spark-submit は stdin を JAR 扱いするため、スモークはコンテナ内 .py 書き出し方式

### Next Step

- Tier 3(Apache Hivemall / H2O-3 + Sparkling Water)の文献調査で related_work.csv を
  完成させる(実験不要、公式ドキュメントベース)。これで比較表が論文 Related Work
  の下書きとして揃う

Commit: `Add Spark MLlib running example comparison`(本エントリを含むコミット)。
push 後の `git status`: clean。

---

## 2026-07-08: PostgresML 最小比較パイプライン(Tier 2)

### Summary

- PostgresML 環境を固定: 公式イメージ `ghcr.io/postgresml/postgresml:2.7.12`
  (約15GB、pgml 拡張 + PostgreSQL 15 + Python ML ランタイム同梱)。
  **smoke → fit → predict まで実機で成功**
- 判明した起動の癖2つを解決してスクリプト化: (1) CMD が空だと entrypoint が即終了
  (`tail -f /dev/null` を渡す)、(2) pgml 拡張の初期化が非同期のため readiness は
  `SELECT 1` ではなく `pgml.version()` で判定
- Running Example 相当(churn 分類、まず age のみ)を `pgml.train` / `pgml.predict` で実行
- **主要な観測**:
  - API は family/link ではなく **task + algorithm 名中心**(SE・p値・CI は存在しない。
    metrics は roc_auc / f1 / accuracy 等の ML 指標)
  - fit はテーブル名を snapshot 化し、**自動で 25% test 分割・metrics 計算・デプロイ**
    まで行う。モデルは**シリアライズ済みバイナリ**(本例 686 bytes)として
    `pgml.files` に保存され、**ユーザーから見える relation としては存在しない**
  - predict は **project 名文字列**参照(デプロイ状態というミュータブルな間接参照)で、
    分類では**クラスラベル(0/1)**を返す。確率は `pgml.predict_proba`(別関数)
  - **NULL 特徴量は `ERROR: array contains NULL` のハードエラー**(実測。CASE での
    手動ガードが必要)
  - **text 列は受理されるが既定でordinalラベルエンコード**(実測: F=1, M=2, Other=3)
    — 線形モデルに人工的な順序を持ち込む。treatment contrast との統計的意味論の差
  - test 分割が単一クラスになると**学習自体が失敗**(実測)。estimator の乱数シードは
    未公開 — 再現性の設計差
  - snapshot に列型・preprocessor・カテゴリ写像が保存される(構造化 metadata は
    存在するが pgml のシステムカタログ内)
- `data/related_work.csv` の PostgresML 行を実測+公式情報(MIT ライセンス)で更新。
  MADlib 行の残 TBD も公式ドキュメントで解消(offset / weight: glm()/logregr_train()
  のパラメータに存在せず。IRLS は決定的で RNG 不使用)

### Changed Files

- `scripts/40_postgresml_smoke.sh` / `41_postgresml_running_example.sh` /
  `sql/41_postgresml_running_example.sql` / `42_compare_fbsql_postgresml.R`: 新規
- `results/raw/running_example_predictions_postgresml.csv` +
  `postgresml_null_probe.log` + `postgresml_categorical_probe.log`: 実測出力
- `results/summary/postgresml_running_example_summary.csv` +
  `postgresml_api_design_notes.csv`(15観点): 新規
- `data/related_work.csv` + `results/tables/related_work.md`: PostgresML 行更新 +
  MADlib 行の TBD 解消
- `README.md`: PostgresML 比較セクション追加

### Validation

- `40_postgresml_smoke.sh` → pgml 2.7.12 応答、カタログ5テーブル確認
- `41_postgresml_running_example.sh` → fit・predict・プローブ2種まで成功
- 予測(参考値): c101→0, c102→1, c103→1, c104→NULL(手動ガード), c105→0。
  数値一致は設計上期待しない(異なる推定器・出力スケール)ことを summary に明記

### Known Issues

- PostgresML の novel level 予測挙動(ROW 形式での text 入力)は未検証(TBD として記録)
- interaction / offset / weight は PostgresML では概念として存在しない可能性が高いが
  未確認のため TBD のまま
- イメージが 15GB と巨大(CI に載せる場合は要検討。現状 experiments に CI なしで問題なし)

### Next Step

- Tier 2 残りの Spark MLlib(RFormula があるため formula interface の比較として重要)
  の最小環境固定と Running Example 相当、または Tier 3(Hivemall / H2O)の文献調査で
  related_work.csv を完成させる

Commit: `Add PostgresML running example comparison`(本エントリを含むコミット)。
push 後の `git status`: clean。

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
