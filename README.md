## littlefs-c89-w2c2

This was an experiment to try using [w2c2][w2c2] to transpile
[littlefs][littlefs] to c89.

littlefs only support c99, and that isn't likely to change anytime soon, but
c89 is still a very common standard in the embedded space, especially for older
compilers.

## Results

As it is right now, w2c2 is not really usable as a c99-&gt;c89 transpiler for
littlefs.

The main issue is API. w2c2 runs in WebAssembly's memory space, which presents
challenges for marshalling structs through the existing littlefs APIs.

WebAssembly's memory model is also too coarse granularity for
microcontroller-scale systems, as the output from w2c2 requires an allocation
of 128 KiB to run, which is ~91x the current RAM requirements of littlefs.

I will ignore these problems for now, as it may be possible to work around them
by modifying w2c2. As is the following numbers are an addition to this upfront
128 KiB RAM cost.

It's worth mentioning w2c2, and WebAssembly in general, is primarily concerned
with performance, and w2c2 at the time of writing notes only a ~7% slowdown from
native. But in microcontroller-scale systems, code/RAM cost is often more
important. This means I'm measuring w2c2 for something it wasn't really
optimized for, but this measurement is important for the microcontroller space.

So how does w2c2-transpiled c89 littlefs compare to the original?

See the [to-reproduce](#to-reproduce) section below to reproduce these results.
These results are using GCC 11.4 targeting Thumb with -Os:

|                |    code |  stack |
|:---------------|--------:|-------:|
| native c99     |   16486 |   1432 |
| transpiled c89 |   44824 |   1960 |
| percent diff   | +171.9% | +36.9% |

## To reproduce

First clone this repo recursively to get the littlefs and w2c2 submodules.

Download [wasi-sdk][wasi-sdk] and [wabt][wabt] so you can compile WebAssembly.
The Makefile has a shortcut for this:

``` bash
$ make tools
```

Then, with any luck, you should be able to transpile littlefs to c89:

``` bash
$ make c89
```

This generates `littlefs-c89/lfs_c89.h` and `littlefs-c89/lfs_c89.c`, which
contain the transpiled code.

If the `arm-linux-gnueabi-gcc` is installed, we can then compare the c99 and
c89 versions of littlefs. This is where I got the above numbers:

``` bash
$ make diff
```

[littlefs]: https://github.com/littlefs-project/littlefs
[w2c2]: https://github.com/turbolent/w2c2
[wasi-sdk]: https://github.com/WebAssembly/wasi-sdk
[wabt]: https://github.com/WebAssembly/wabt
