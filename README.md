# Spinel -- Ruby AOT Compiler

Spinel compiles Ruby source code into standalone native executables.
It performs whole-program type inference and generates optimized C code,
achieving 9x-4,000x speedup over CRuby.

Spinel is **self-hosting**: the compiler backend is written in Ruby and
compiles itself into a native binary.

## How It Works

```
Ruby (.rb)
    |
    v
spinel_parse           Parse with Prism (libprism), serialize AST
    |                  (C binary, or CRuby + Prism gem as fallback)
    v
AST text file
    |
    v
spinel_codegen         Type inference + C code generation
    |                  (self-hosted native binary)
    v
C source (.c)
    |
    v
cc -O2 -lm             Standard C compiler
    |
    v
Native binary           Standalone, no runtime dependencies
```

## Quick Start

```bash
# Build everything:
make

# Compile a Ruby program:
./spinel app.rb              # compiles to ./app
./spinel app.rb -o myapp     # compiles to ./myapp
./spinel app.rb -c           # generates app.c only
./spinel app.rb -S           # prints C to stdout

# Or step by step with CRuby:
ruby spinel_parse.rb app.rb > app.ast
ruby spinel_codegen.rb app.ast app.c
cc -O2 app.c -lm -o app
```

## Self-Hosting

Spinel compiles its own backend. The bootstrap chain:

```
CRuby + spinel_parse.rb → AST
CRuby + spinel_codegen.rb → gen1.c → bin1
bin1 + AST → gen2.c → bin2
bin2 + AST → gen3.c
gen2.c == gen3.c   (bootstrap loop closed)
```

## Benchmarks

39/39 benchmarks pass. 59/60 tests pass.

| Benchmark | Spinel | CRuby 3.x | Speedup |
|-----------|--------|-----------|---------|
| attr_accessor_bench | 0.4 ms | 1,690 ms | **4,225x** |
| life (Game of Life) | 0.4 ms | 1,500 ms | **3,750x** |
| inline | 0.4 ms | 1,560 ms | **3,900x** |
| send_cfunc_block | 0.4 ms | 1,400 ms | **3,500x** |
| send_bmethod | 0.5 ms | 600 ms | **1,200x** |
| nested_loop | 0.4 ms | 330 ms | **825x** |
| keyword_args | 0.4 ms | 290 ms | **725x** |
| str_concat | 0.5 ms | 60 ms | **120x** |
| ruby_xor | 10 ms | 1,490 ms | **149x** |
| ackermann | 4.4 ms | 380 ms | **86x** |
| mandelbrot | 20 ms | 1,160 ms | **58x** |
| fib(34) | 10 ms | 560 ms | **56x** |
| spectralnorm | 20 ms | 1,010 ms | **50x** |
| nqueens | 800 ms | 25,050 ms | **31x** |
| sudoku | 4.9 ms | 150 ms | **31x** |
| so_lists | 20 ms | 530 ms | **26x** |
| splay | 10 ms | 240 ms | **24x** |
| fizzbuzz (lambda) | 1,630 ms | 32,180 ms | **20x** |
| gcbench | 480 ms | 4,320 ms | **9x** |

## Supported Ruby Features

**Core**: Classes, inheritance, `super`, `include` (mixin), `attr_accessor`,
`Struct.new`, `alias`, module constants, open classes for built-in types.

**Control Flow**: `if`/`elsif`/`else`, `unless`, `case`/`when`,
`case`/`in` (pattern matching), `while`, `until`, `loop`, `for..in`,
`break`, `next`, `return`, `catch`/`throw`, `&.` (safe navigation).

**Blocks**: `yield`, `block_given?`, `&block`, `proc {}`, `Proc.new`,
lambda `-> x { }`, `method(:name)`. Block methods: `each`, `map`,
`select`, `reject`, `reduce`, `sort_by`, `any?`, `all?`, `none?`.

**Exceptions**: `begin`/`rescue`/`ensure`/`retry`, `raise`,
custom exception classes.

**Types**: Integer, Float, String (immutable + mutable), Array, Hash,
Range, Time, StringIO, File, Regexp. Polymorphic values via tagged unions.

**Strings**: `<<` automatically promotes to mutable strings (`sp_String`)
for O(n) in-place append. `+`, interpolation, and methods work on both.

**Regexp**: Built-in NFA regexp engine (no external dependency).
`=~`, `$1`-`$9`, `match?`, `gsub(/re/, str)`, `sub(/re/, str)`,
`scan(/re/)`, `split(/re/)`.

**Memory**: Mark-and-sweep GC with explicit roots, conservative stack
scanning, and adaptive threshold. Arrays track GC-managed memory for
accurate collection.

**I/O**: `puts`, `print`, `printf`, `p`, `gets`, `ARGV`, `ENV[]`,
`File.read/write/open`, `system()`, backtick.

## Architecture

```
spinel              One-command wrapper script (POSIX shell)
spinel_parse.rb     CRuby frontend: Prism AST → text format (715 lines)
spinel_parse.c      C frontend: libprism → text format (915 lines)
spinel_codegen.rb   Compiler backend: AST → C code (14,498 lines)
lib/regexp/         Built-in regexp engine (1,759 lines)
lib/                Stub libraries (stringio, strscan, optparse, etc.)
test/               60 test programs
benchmark/          39 benchmark programs
Makefile            Build automation
```

The compiler backend (`spinel_codegen.rb`) is written in a Ruby subset
that Spinel itself can compile: classes, `def`, `attr_accessor`,
`if`/`case`/`while`, `each`/`map`/`select`, `yield`, `begin`/`rescue`,
String/Array/Hash operations, File I/O.

No metaprogramming, no `eval`, no `require` in the backend.

The parser has two implementations:
- **spinel_parse.c** links libprism directly (no CRuby needed)
- **spinel_parse.rb** uses the Prism gem (CRuby fallback)

Both produce identical AST output. The `spinel` wrapper prefers the
C binary if available.

## Building

```bash
make              # build parser + regexp library + bootstrap compiler
make test         # run 60 tests
make bench        # run 39 benchmarks
make clean        # remove build artifacts
```

Requires [Prism](https://github.com/ruby/prism) gem installed (for
libprism source). Override with `PRISM_DIR=/path/to/prism`.

CRuby is needed only for the initial bootstrap. After `make`, the
entire pipeline runs without Ruby.

## Limitations

- **No eval**: `eval`, `instance_eval`, `class_eval`
- **No metaprogramming**: `send`, `method_missing`, `define_method` (dynamic)
- **No threads**: `Thread`, `Fiber`, `Mutex`
- **No encoding**: assumes UTF-8/ASCII

## Dependencies

- **Build time**: [libprism](https://github.com/ruby/prism) (C library),
  CRuby (bootstrap only)
- **Run time**: None. Generated binaries need only libc + libm.
- **Regexp**: Built-in engine, no external library needed.

## History

Spinel was originally implemented in C (18K lines, branch `c-version`),
then rewritten in Ruby (branch `ruby-v1`), and finally rewritten in a
self-hosting Ruby subset (current `master`).

## License

MIT License. See [LICENSE](LICENSE).
