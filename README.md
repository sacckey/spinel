# Spinel -- Ruby AOT Compiler

Spinel compiles Ruby source code into standalone native executables.
It performs whole-program type inference and generates optimized C code,
achieving 10x-200x speedup over CRuby.

Spinel is **self-hosting**: the compiler is written in Ruby and compiles
itself into a native binary.

## How It Works

```
Ruby (.rb)
    |
    v
spinel_parse.rb        Parse with Prism, serialize AST
    |
    v
AST text file (.ast)
    |
    v
spinel_codegen.rb      Type inference + C code generation
    |                  (runs under CRuby or as native binary)
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
# Compile a Ruby program
ruby spinel_parse.rb hello.rb > hello.ast
ruby spinel_codegen.rb hello.ast hello.c
cc -O2 hello.c -lm -o hello
./hello

# Or with the self-hosted binary (46x faster):
./spinel_codegen hello.ast hello.c
```

Programs using regular expressions need `-lonig` (oniguruma).

## Self-Hosting

Spinel compiles itself. The bootstrap chain:

```
CRuby + spinel_parse.rb → AST
CRuby + spinel_codegen.rb → gen1.c → bin1
bin1 + AST → gen2.c → bin2
bin2 + AST → gen3.c
gen2.c == gen3.c   (bootstrap loop closed)
```

bin2 compiles Ruby programs 46x faster than CRuby running spinel_codegen.rb.

## Benchmarks

| Benchmark | Spinel | CRuby 3.x | Speedup |
|-----------|--------|-----------|---------|
| life (Game of Life) | 37 ms | 1,462 ms | **40x** |
| nested_loop | 2 ms | 332 ms | **166x** |
| spectralnorm | 15 ms | 1,024 ms | **68x** |
| ackermann | 6 ms | 389 ms | **65x** |
| mandelbrot | 25 ms | 1,150 ms | **46x** |
| fib(34) | 12 ms | 560 ms | **47x** |
| nqueens | 710 ms | 24,833 ms | **35x** |
| sudoku | 7 ms | 150 ms | **21x** |
| splay | 13 ms | 236 ms | **18x** |

58/59 tests pass. 39/39 benchmarks pass.

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

**Types**: Integer, Float, String, Array, Hash, Range, Time, StringIO,
File, Regexp. Polymorphic values via tagged unions.

**I/O**: `puts`, `print`, `printf`, `p`, `gets`, `ARGV`, `ENV[]`,
`File.read/write/open`, `system()`, backtick.

## Architecture

```
spinel_parse.rb     CRuby frontend: Prism AST → text format (715 lines)
spinel_codegen.rb   Compiler backend: AST → C code (14,074 lines)
lib/                Stub libraries (stringio, strscan, optparse, etc.)
test/               59 test programs
benchmark/          39 benchmark programs
```

The compiler is written in a Ruby subset that Spinel itself can compile:
classes, `def`, `attr_accessor`, `if`/`case`/`while`, `each`/`map`/`select`,
`yield`, `begin`/`rescue`, String/Array/Hash operations, File I/O.

No metaprogramming, no `eval`, no `require` in the backend.

## Limitations

- **No eval**: `eval`, `instance_eval`, `class_eval`
- **No metaprogramming**: `send`, `method_missing`, `define_method` (dynamic)
- **No threads**: `Thread`, `Fiber`, `Mutex`
- **No encoding**: assumes UTF-8/ASCII

## Dependencies

- **Parse time**: [Prism](https://github.com/ruby/prism) gem (CRuby)
- **Run time**: None. Generated binaries need only libc + libm.
- **Regexp**: Programs using regex link with [oniguruma](https://github.com/kkos/oniguruma)

## History

Spinel was originally implemented in C (18K lines, branch `c-version`),
then rewritten in Ruby (branch `ruby-v1`), and finally rewritten in a
self-hosting Ruby subset (current `master`).

## License

MIT License. See [LICENSE](LICENSE).
