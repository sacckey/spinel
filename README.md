# Spinel -- Ruby AOT Compiler

Spinel compiles Ruby source code into standalone C executables.
It parses Ruby with [Prism](https://github.com/ruby/prism),
performs whole-program type inference, and generates a single C file
that compiles to a native binary with no runtime dependencies.

```
Ruby (.rb) --> Prism AST --> Type Inference --> C Source --> Native Binary
```

## Features

- **Fast**: 10x--200x faster than CRuby on computation-heavy benchmarks
- **Small**: generated binaries are 15--20 KB, needing only libc + libm
- **Single file output**: one `.c` file, one `cc` invocation
- **No runtime**: no VM, no interpreter, no mruby -- pure AOT compilation
- **Mark-and-sweep GC**: generated inline, only when needed
- **Polymorphism**: NaN-boxed 8-byte values with 3-tier dispatch

## Quick Start

```bash
make deps    # fetch and build Prism
make         # build the spinel compiler

./spinel --source=hello.rb --output=hello.c
cc -O2 hello.c -lm -o hello
./hello
```

Programs using regular expressions need `-lonig` (oniguruma).

## Benchmarks

Measured on Linux x86_64 (best of 3 runs):

| Benchmark | Spinel | CRuby 3.x | Speedup | Spinel RSS |
|-----------|--------|-----------|---------|-----------|
| life (Game of Life) | 7 ms | 1,462 ms | **208x** | 7 MB |
| nested_loop | 2 ms | 332 ms | **179x** | 1 MB |
| spectralnorm | 15 ms | 1,024 ms | **69x** | 2 MB |
| ackermann | 6 ms | 389 ms | **67x** | 1 MB |
| mandelbrot | 25 ms | 1,150 ms | **47x** | 1 MB |
| fib(34) | 12 ms | 560 ms | **48x** | 1 MB |
| nqueens | 727 ms | 24,833 ms | **34x** | 2 MB |
| sudoku | 6 ms | 150 ms | **25x** | 3 MB |
| matmul | 4 ms | 323 ms | **77x** | 2 MB |
| splay | 13 ms | 236 ms | **18x** | 5 MB |
| partial_sums | 82 ms | 1,270 ms | **16x** | 2 MB |
| so_lists | 25 ms | 506 ms | **20x** | 2 MB |
| sieve | 45 ms | 443 ms | **10x** | 35 MB |

60 tests and 39 benchmarks pass.

## Supported Ruby Features

### Core Language

Classes, inheritance, `super`, `include` (mixin), `attr_accessor`/`reader`/`writer`,
class methods, `Struct.new` (with `keyword_init:`), `alias`, `Comparable`,
module constants, open classes for built-in types.

### Control Flow

`if`/`elsif`/`else`, `unless`, `case`/`when`, `case`/`in` (pattern matching),
`while`, `until`, `loop`, `for..in`, `break`, `next`, `return`,
`catch`/`throw`, ternary, `and`/`or`/`not`, `&.` (safe navigation).

### Blocks and Closures

`yield`, `block_given?`, `&block`, `proc {}`, `Proc.new`, `Proc#call`,
`method(:name)`, lambda `-> x { }` with capture.
Block methods: `each`, `map`, `select`, `reject`, `reduce`, `find`, `any?`,
`all?`, `none?`, `count`, `sort_by`, `min_by`, `max_by`, `filter_map`, `flat_map`.

### Exception Handling

`begin`/`rescue`/`ensure`/`retry`, `raise`, custom exception classes,
`rescue ClassName => e` with class hierarchy checking.

### Parameters

Positional, default values, keyword arguments (`name:`, `greeting: "Hello"`),
rest/splat (`*args`), block parameters (`&block`).

### Polymorphism

Variables holding multiple types, heterogeneous arrays and hashes,
duck typing with 3-tier dispatch (monomorphic / bimorphic / megamorphic),
NaN-boxed 8-byte values.

### Built-in Types

| Type | Implementation | Key Methods |
|------|---------------|-------------|
| Integer | `int64_t` (unboxed) | `abs`, `even?`, `odd?`, `gcd`, `lcm`, `bit_length`, `pow`, `clamp`, `times`, `upto`, `downto`, `to_f`, `to_s`, `chr`, `[]` |
| Float | `double` (unboxed) | `abs`, `ceil`, `floor`, `round`, `truncate`, `infinite?`, `nan?`, `clamp`, `to_i`, `to_s` |
| String | `const char *` (immutable) | 45+ methods: `length`, `upcase`, `downcase`, `strip`, `gsub`, `sub`, `split`, `index`, `rindex`, `include?`, `start_with?`, `end_with?`, `tr`, `chop`, `swapcase`, `[]`, `slice`, `chars`, `bytes`, `to_i`, `to_f`, ... |
| sp_String | mutable string | `<<`, `replace`, `clear`, `dup` + all immutable String methods via delegation |
| Array | `sp_IntArray` (int64) | `push`, `pop`, `shift`, `[]`, `[]=`, `sort`, `reverse`, `uniq`, `map`, `select`, `reject`, `reduce`, `find`, `any?`, `all?`, `none?`, `+`, `-`, `take`, `drop`, `delete`, `sample`, ... |
| FloatArray | `sp_FloatArray` | `push`, `[]`, `[]=`, `length`, `dup` |
| Hash | `sp_StrIntHash` | `[]`, `[]=`, `fetch`, `delete`, `keys`, `values`, `each`, `merge`, `transform_values`, `empty?`, `include?`, `clear` |
| Range | `sp_Range` | `first`, `last`, `each`, `include?`, `to_a`, `sum`, `map` |
| Regexp | oniguruma | `/pattern/`, `=~`, `$1`--`$9`, `match?`, `gsub`, `sub`, `scan`, `split` |
| Time | `time_t` wrapper | `Time.now`, `Time.at`, `to_i`, arithmetic |
| StringIO | inline C | `read`, `write`, `puts`, `gets`, `string`, `pos`, `seek`, `eof?`, ... |
| File | inline C | `File.read`, `File.write`, `File.exist?`, `File.open { ... }`, `File.join`, ... |

Method tables in `src/methods.c` serve as single source of truth for
type inference, `respond_to?` resolution, and argument type information.

### I/O and System

`puts`, `print`, `printf`, `p`, `gets`, `ARGV`, `ENV[]`,
`system()`, backtick, `exit`, `sleep`, `$stdin`, `$stdout`, `$stderr`.

### Introspection

`is_a?` (compile-time), `respond_to?` (compile-time for monomorphic,
runtime type-tag dispatch for polymorphic), `nil?`, `defined?`,
`__LINE__`, `__FILE__`, `__method__`.

### Multi-file

`require_relative` resolves files at compile time.
`require "name"` searches `lib/` paths for stub libraries.

## Architecture

```
src/
  main.c       -- CLI, file I/O, Prism setup
  codegen.h    -- type system, struct definitions, shared API
  codegen.c    -- orchestrator, class analysis, lambda, require
  methods.c    -- built-in method tables (return types, arg types)
  type.c       -- type inference and resolution
  expr.c       -- expression code generation
  stmt.c       -- statement code generation
  emit.c       -- C code emission (headers, structs, runtime helpers)

lib/           -- stub libraries for require resolution
  stringio.rb/c, strscan.rb/c, optparse.rb, erb.rb, set.rb, forwardable.rb

test/          -- 60 test programs (automated)
benchmark/     -- 39 benchmark programs
vendor/prism/  -- Prism parser (fetched by make deps)
```

### Compilation Passes

1. **Require resolution** -- parse required files, merge ASTs
2. **Class analysis** -- classes, modules, inheritance, mixins, Struct, open classes
3. **Type inference** -- whole-program: variables, ivars, params, returns
4. **Needs detection** -- scan for used types, emit only required runtime helpers
5. **Code emission** -- C structs, method functions, GC, exception handling
6. **Top-level codegen** -- main() with variable declarations and statements

### Generated Code Style

- 2-space indentation
- Newline before `else`
- Only used runtime helpers are emitted (unused types produce zero code)
- `puts "hello"` generates 61 lines of C

## Library Support

Spinel includes stub libraries for commonly-used gems:

| Library | Status |
|---------|--------|
| stringio | Built-in type (full API) |
| strscan | Ruby stub + C implementation |
| optparse | Minimal pure-Ruby implementation |
| erb | Placeholder (eval-based ERB is AOT-incompatible) |
| set | Array-backed approximation |
| forwardable | Compile-time delegation |

Pure Ruby libraries work via `--lib=DIR` search paths.

## Limitations

- **No eval**: `eval`, `instance_eval`, `class_eval` are not supported
- **No metaprogramming**: `send`, `method_missing`, `define_method` (dynamic names)
- **No threads**: `Thread`, `Fiber`, `Mutex`
- **No encoding**: assumes UTF-8 / ASCII throughout
- **No ObjectSpace**: no runtime heap introspection

## Building

```bash
make deps      # fetch and build Prism (one-time)
make           # build spinel compiler
make test-all  # run 60 tests
make bench-verify  # verify 39 benchmarks produce correct output
```

## License

MIT License. See [LICENSE](LICENSE) for details.
