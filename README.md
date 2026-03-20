# Spinel — AOT Compiler for Ruby

Spinel compiles Ruby source code to standalone C executables via
[Prism](https://github.com/ruby/prism) parsing and whole-program type inference.

- **Monomorphic code** (statically typed): classes → C structs, methods → direct C calls,
  arithmetic → native C operators. 20-57x faster than CRuby.
- **Polymorphic code** (dynamically typed): 8-byte NaN-boxed values with 3-tier dispatch
  (monomorphic → bimorphic inline switch → megamorphic dispatch function).
- **No runtime dependencies**: generated binaries need only libc and libm.
  Mark-and-sweep GC is generated inline. Regexp programs link with libonig.

~12200 lines of C. 54 test programs. 53/53 automated tests pass.

## Quick Start

```bash
# Build the compiler
make deps && make

# Compile a Ruby program
./spinel --source=app.rb --output=app.c
cc -O2 app.c -lm -o app

# Run the full test suite
make test-all
```

The generated C file includes a comment with the exact compile command.

## Benchmarks

| Benchmark | CRuby 3.2 | mruby | **Spinel AOT** | Speedup |
|-----------|-----------|-------|----------------|---------|
| mandelbrot (600x600) | 1.14s | 3.18s | **0.02s** | **57x** |
| ao_render (64x64 AO) | 3.55s | 13.69s | **0.07s** | **51x** |
| so_lists (300x10K) | 0.44s | 2.01s | **0.02s** | **22x** |
| fib(34) recursive | 0.55s | 2.78s | **0.01s** | **55x** |
| lc_fizzbuzz (Church) | 28.96s | — | **1.55s** | **19x** |

## How It Works

```
Ruby Source (.rb)
    |
    v
Prism (libprism)              -- parse to AST
    |
    v
Pass 1: Class Analysis        -- classes, modules, inheritance, mixins,
    |                            attr_accessor, Struct.new, yield detection,
    |                            require_relative (multi-file)
    v
Pass 2: Type Inference         -- whole-program: variables, ivars, params,
    |                            returns. Cross-function inference.
    |                            MONO (single type) vs POLY (union type)
    v
Pass 3: Code Generation        -- MONO: classes → C structs, methods → direct calls
    |                            POLY: sp_RbValue (8B NaN-boxed), 3-tier dispatch
    |                            Closures, blocks, regexp, exceptions
    v
Standalone C file              -- GC inline, exception handling inline
    |
    v
cc -O2 -lm → native binary
```

## Supported Language Features

| Category | Features |
|----------|----------|
| **OOP** | Classes, inheritance (`< Parent`), `super`, `include` (mixin), `attr_accessor`/`reader`/`writer`, class methods (`def self.foo`), `Struct.new` (incl. `keyword_init: true`), `alias`, `Comparable` (operator methods), module constants (`Module::CONST`) |
| **Blocks & Closures** | `yield`, `block_given?`, `&block`, `proc {}`, `Proc.new`, `Proc#call`, `method(:name)`, `Array#each/map/select/reject/reduce/count/sort_by/min_by/max_by`, `Hash#each`, `Integer#times/upto/downto`, lambda `-> x { }`, `Enumerable` |
| **Control Flow** | `if`/`elsif`/`else`, `unless`, `case`/`when`, **`case`/`in` (pattern matching)**, `while`, `until`, `loop`, `for..in`, `break`, `next`, `return`, `catch`/`throw`, ternary, `and`/`or`/`not`, `&.` (safe navigation) |
| **Exceptions** | `begin`/`rescue`/`ensure`/`retry`, `raise "msg"`, `raise ClassName, "msg"`, `rescue ClassName => e` (class hierarchy), custom exception classes |
| **Parameters** | Positional, default values, keyword (`name:, greeting: "Hello"`), rest/splat (`*args`) |
| **Polymorphism** | Variables holding multiple types, heterogeneous arrays `[1, "two", 3.0]`, heterogeneous Hash `{name: "Alice", age: 30}`, duck typing (bimorphic + megamorphic dispatch), `case/in` pattern matching |
| **Types** | Integer, Float, Boolean, String (immutable `const char *` + mutable `sp_String`), Symbol, nil, Range, Time |
| **Collections** | Integer arrays (push/pop/shift/sort/sort\_by/min/max/min\_by/max\_by/sum/reduce/count/join/uniq), Hash (String→Int, heterogeneous), String arrays (split results, count/find/any?/max\_by/filter\_map) |
| **Strings** | 35+ methods: length, upcase, downcase, strip, lstrip, rstrip, reverse, gsub, sub, split, capitalize, chomp, include?, start\_with?, end\_with?, count, ljust, rjust, center, tr, delete, squeeze, chars, bytes, to\_f, to\_i, hex, oct, slice, dup, freeze, frozen?, `+`, `<<`, `*`, `[]`, `[range]`, replace, clear, comparison (`==`/`<`) |
| **Regexp** | `/pattern/`, `=~`, `$1`-`$9`, `match?`, `gsub`, `sub`, `scan`, `split` (via oniguruma) |
| **Numeric** | `abs`, `even?`, `odd?`, `zero?`, `positive?`, `negative?`, `ceil`, `floor`, `round`, `**`, `to_f`, `to_i`, `to_s` |
| **I/O** | `puts`/`print`/`printf`/`putc`/`p`, `File.read/write/exist?/delete/open(block)`, `ARGV`, `$stderr.puts`, `exit`, `sleep` |
| **Introspection** | `is_a?` (compile-time), `respond_to?` (compile-time), `nil?`, `defined?`, `__LINE__`, `__FILE__`, `__method__`, `freeze`/`frozen?` |
| **Multi-file** | `require_relative` (compile-time file resolution and merging) |
| **Runtime** | Mark-and-sweep GC (shadow stack), arena allocator (closures), NaN-boxed polymorphic values (8 bytes) |

## Architecture

### 3-Tier Method Dispatch

| Polymorphism | Strategy | Speed |
|-------------|----------|-------|
| Monomorphic (1 type) | Direct C function call | Fastest |
| Bimorphic (2 types) | Inline if/else at call site | Fast |
| Megamorphic (3+ types) | Per-method dispatch function | Good |

### NaN-boxing (8-byte values)

Polymorphic values use favor-pointer NaN-boxing:
- Pointer: zero-cost extract (raw 48-bit address)
- Integer: shift + mask (48-bit signed, ±140 trillion)
- Double: subtract offset + bitcast
- Bool/Nil: special constants

Monomorphic code uses unboxed C types — zero overhead.

## Test Suite

```bash
make test-all    # 53 tests, all pass
make test        # quick: mandelbrot only
```

## Project Structure

```
spinel/
├── src/
│   ├── main.c          # CLI, file reading, Prism parsing, require resolution
│   ├── codegen.h       # Type system, class/method/module info structs
│   └── codegen.c       # Multi-pass code generator (~12200 lines)
├── examples/           # 54 test programs (53 automated)
├── prototype/
│   └── tools/          # RBS extraction, LumiTrace prototype tools
├── Makefile            # build, test, test-all
├── PLAN.md             # Implementation roadmap & design docs
└── ruby_aot_compiler_design.md
```

## Dependencies

- **Build time**: [Prism](https://github.com/ruby/prism) (fetched automatically by `make deps`)
- **Run time**: None for most programs. libc + libm only.
- **Regexp**: Programs using regex require [oniguruma](https://github.com/kkos/oniguruma) (`-lonig`).

## License

Spinel is released under the [MIT License](LICENSE).

### Note on License

mruby has chosen a MIT License due to its permissive license allowing
developers to target various environments such as embedded systems.
However, the license requires the display of the copyright notice and license
information in manuals for instance. Doing so for big projects can be
complicated or troublesome. This is why mruby has decided to display "mruby
developers" as the copyright name to make it simple conventionally.
In the future, mruby might ask you to distribute your new code
(that you will commit,) under the MIT License as a member of
"mruby developers" but contributors will keep their copyright.
(We did not intend for contributors to transfer or waive their copyrights,
actual copyright holder name (contributors) will be listed in the [AUTHORS](AUTHORS)
file.)

Please ask us if you want to distribute your code under another license.
