# PLAN: Spinel AOT Compiler

Ruby source → Prism AST → whole-program type inference → standalone C executable.
No runtime dependencies (no mruby, no GC library — GC is generated inline).

詳細設計は `ruby_aot_compiler_design.md` を参照。

---

## 現状 (Status)

### コンパイラアーキテクチャ (~5800行のC)

- Prism (libprism) によるRubyパース
- 多パスコード生成:
  1. クラス/モジュール/関数解析 (継承チェーン解決含む)
  2. 全変数・パラメータ・戻り値の型推論 (関数間解析)
  3. C構造体・メソッド関数の生成 (GCスキャン関数含む)
  4. ラムダ/クロージャのキャプチャ解析・コード生成
  5. main()のトップレベルコード生成
- マーク&スイープGC (シャドウスタック、ファイナライザ)
- setjmp/longjmpベース例外処理
- アリーナアロケータ (ラムダ/クロージャ用)

### サポート済み言語機能

| カテゴリ | 機能 |
|---------|------|
| **OOP** | クラス定義、インスタンス変数、メソッド定義 |
| | 継承 (`class Dog < Animal`)、`super` |
| | getter/setter自動インライン化 |
| | コンストラクタ (`.new`)、型付きオブジェクトへのメソッド呼び出し |
| | モジュール (状態変数 + メソッド) |
| **ブロック/クロージャ** | `yield`、ブロック付きメソッド呼び出し |
| | `Array#each/map/select` (インライン化) |
| | `Integer#times` with block → C forループ |
| | `-> x { body }` ラムダ → Cクロージャ (キャプチャ解析) |
| | sp_Val タグ付きユニオン + アリーナアロケータ |
| **制御** | while, until, if/elsif/else, unless |
| | case/when/else (値、複数値、Range条件) |
| | break, next, return |
| | ternary, and/or/not |
| **例外処理** | begin/rescue/ensure/retry |
| | raise "message" (setjmp/longjmp) |
| | rescue => e (メッセージキャプチャ) |
| **型** | Integer, Float, Boolean, String, nil → アンボックスC型 |
| | Symbol → 文字列定数 |
| | 値型 (Vec: 3 floats → 値渡し) vs ポインタ型 |
| | デフォルト引数 (`def foo(x = 10)`) |
| **コレクション** | sp_IntArray (push/pop/shift/dup/reverse!/each/map/select) |
| | sp_StrIntHash (文字列キー→整数値、each/has_key?/delete) |
| | O(1) shift (デキュー方式のstartオフセット) |
| **演算** | 算術 (+, -, *, /, %, **), 比較, ビット演算 |
| | 単項マイナス, 複合代入 (+=, <<=) |
| | Math.sqrt/cos/sin → C math関数 |
| | Integer#abs/even?/odd?/zero? |
| | Float#abs/ceil/floor/round |
| **文字列** | リテラル、補間 → printf |
| | length, upcase, downcase, include?, + |
| | Integer#to_s, Integer#chr |
| **I/O** | puts, print, printf, putc, p → stdio |
| | puts: Integer, Float, Boolean, String対応 |
| **GC** | マーク&スイープ (非値型オブジェクト・配列・ハッシュ用) |
| | シャドウスタックルート管理, ファイナライザ |
| | GC不要なプログラムではGCコード省略 |

### ベンチマーク結果

| ベンチマーク | CRuby | mruby | Spinel AOT | 高速化 | メモリ |
|-------------|-------|-------|------------|--------|--------|
| mandelbrot (600×600) | 1.14s | 3.18s | 0.02s | 57× | <1MB |
| ao_render (64×64 AO) | 3.55s | 13.69s | 0.07s | 51× | 2MB |
| so_lists (300×10K) | 0.44s | 2.01s | 0.02s | 22× | 2MB |
| fib(34) | 0.55s | 2.78s | 0.01s | 55× | <1MB |
| lc_fizzbuzz (Church) | 28.96s | — | 1.55s | 19× | arena |
| mandel_term | 0.05s | 0.05s | ~0s | 50×+ | <1MB |

生成バイナリは完全スタンドアロン (libc + libm のみ、mruby不要)。

---

## 未サポート機能

### 高優先度

| 機能 | 備考 |
|------|------|
| `include` / `extend` (Mixin) | モジュール取り込み |
| `attr_accessor` / `attr_reader` マクロ | 手動getter/setterは対応済み |
| キーワード引数 | `def foo(name:, age:)` |
| スプラット (`*args`, `**kwargs`) | 可変長引数 |
| Regexp | パターンマッチ |
| String メソッド追加 (gsub, split, match等) | 文字列処理 |
| `Comparable`, `Enumerable` | モジュール組み込み |
| `for..in` + Range | while版は対応済み |
| `loop do` | while(1)で代替可 |
| 多値 Hash (任意型value) | 現在はString→Integerのみ |

### 中優先度

| 機能 | 備考 |
|------|------|
| 多段継承チェーン | 現在は1段のみテスト済み |
| Exception クラス定義 | 現在は文字列のみ |
| `Struct` / `Data` | 簡易データクラス |
| `Proc.new`, `proc {}`, `method(:name)` | lambda以外のProc |
| `respond_to?`, `is_a?`, `class` | 型イントロスペクション |
| クラスメソッド (`def self.foo`) | モジュールメソッドは対応済み |
| `alias` | メソッド別名 |

### 低優先度 (動的機能)

| 機能 | 備考 |
|------|------|
| `eval`, `instance_eval` | 静的解析不可 |
| `send`, `public_send` | 動的ディスパッチ |
| `define_method` | 動的メソッド定義 |
| `method_missing` | フォールバック |
| `require`, `load` | モジュールシステム |
| File I/O | OS依存 |
| グローバル変数 (`$stdout`等) | ランタイム依存 |
| クラス変数 (`@@var`) | 使用頻度低 |
| open class / monkey patching | 静的解析と相性悪 |

---

## アーキテクチャ

```
Ruby Source (.rb)
    |
    v
Prism (libprism)                -- パース → AST
    |
    v
Pass 1: クラス解析              -- クラス (継承チェーン)、メソッド、ivar検出
    |                              モジュール、トップレベル関数、yield検出
    v
Pass 2: 型推論                  -- 全変数・ivar・パラメータの型推論
    |                              (Integer/Float/Boolean/String/Object/Array/Hash/Proc)
    |                              関数間型推論、super型伝播、継承ivar伝播
    v
Pass 3: 構造体・メソッド生成    -- クラス → C構造体 (親フィールド先頭配置)
    |                              メソッド → C関数 (継承はcast-to-parent)
    |                              getter/setter → インラインフィールドアクセス
    |                              GCスキャン関数、ファイナライザ生成
    |                              ラムダ → キャプチャ解析 + C関数生成
    v
Pass 4: main() コード生成       -- トップレベルコード → main()
    |                              while/for/times/each → Cループ
    |                              yield → コールバック関数ポインタ
    |                              算術 → C演算子
    |                              rescue → setjmp/longjmp
    |                              puts/print/printf → stdio
    v
スタンドアロンCファイル           -- GC内蔵, 例外処理内蔵
    |
    v
cc -O2 -lm → ネイティブバイナリ  -- mruby不要、libc+libmのみ
```

## ビルドフロー

```bash
# コンパイラのビルド
make deps   # Prismを取得・ビルド
make        # spinelコンパイラをビルド

# Rubyプログラムのコンパイル
./spinel --source=examples/bm_fib.rb --output=fib.c
cc -O2 fib.c -lm -o fib
./fib   # → 5702887

# テスト
make test   # mandelbrotをコンパイル・実行・CRubyと出力比較
```

## プロジェクト構成

```
spinel/
├── src/
│   ├── main.c          # CLI、ファイル読み込み、Prismパース
│   ├── codegen.h       # 型システム、クラス/メソッド/モジュール情報構造体
│   └── codegen.c       # 多パスコード生成器 (~5800行)
├── examples/           # 13テストプログラム
│   ├── bm_so_mandelbrot.rb   # Mandelbrot集合 (whileループ、ビット演算)
│   ├── bm_ao_render.rb       # AOレイトレーサー (6クラス、モジュール)
│   ├── bm_so_lists.rb        # 配列操作 (push/pop/shift)
│   ├── bm_fib.rb             # 再帰フィボナッチ
│   ├── bm_app_lc_fizzbuzz.rb # λ計算FizzBuzz (1201クロージャ)
│   ├── bm_mandel_term.rb     # ターミナルMandelbrot (関数間呼び出し)
│   ├── bm_yield.rb           # yield/ブロック (each/map/select)
│   ├── bm_case.rb            # case/when, unless, next, デフォルト引数
│   ├── bm_inherit.rb         # 継承、super
│   ├── bm_rescue.rb          # rescue/raise/ensure/retry
│   ├── bm_hash.rb            # Hash操作
│   ├── bm_strings.rb         # Symbol、文字列メソッド
│   └── bm_numeric.rb         # 数値メソッド (abs, ceil, even?, **)
├── prototype/
│   └── tools/          # Step 0プロトタイプ (RBS抽出、LumiTrace等)
├── Makefile
├── PLAN.md             # 本文書
└── ruby_aot_compiler_design.md  # 詳細設計文書
```

## 次のステップ

1. **Mixin (`include`/`extend`)** — モジュールのメソッドをクラスに取り込み
2. **キーワード引数** — `def foo(name:, age:)` 形式
3. **スプラット** — `*args`, `**kwargs`
4. **Regexp** — 正規表現 (PCRE or oniguruma)
5. **String メソッド拡張** — gsub, split, match, sub, strip
6. **多値Hash** — 任意型のvalue対応
7. **LumiTraceプロファイル統合** — 型推論の精度向上
8. **複数ファイルコンパイル** — require/load対応

## 参考情報

- 詳細設計: `ruby_aot_compiler_design.md`
- プロトタイプツール: `prototype/`
