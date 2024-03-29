**Due to the LLVM community's planes to add the Bazel build files in the project's monorepo
[[1]](https://lists.llvm.org/pipermail/llvm-dev/2021-March/149220.html), I see no intent for
the project.**

# Bazel to the LLVM Compiler Infrastructure bridge

[Bazel](https://docs.bazel.build/versions/master/bazel-overview.html) is an open-source
build and test tool similar to Make, Maven, and Gradle. It uses a human-readable,
high-level build language. Bazel supports projects in multiple languages and builds outputs
for multiple platforms. For example, Tensorflow - end-to-end open-source platform for
machine learning - uses Bazel as the build system.

[LLVM](https://llvm.org/) is a collection of modular and reusable compiler and toolchain
technologies. The LLVM Core libraries provide a modern source- and target-independent
optimizer and code generator that makes it easy to invent a new programming language or
port an existing compiler. Also LLVM provides its own native C/C++ compiler - Clang,
debugger - LLDB, an implementation of the C++ Standard Library, and many other interesting
things. The full list of LLVM's primary sub-projects is available on the official web-site.

**bazel-llvm-bridge** provides a bridge that let you use static libraries from a local
installation or kindly downloaded archive of LLVM in your projects when Bazel is used
as a building tool. Each library from LLVM/Clang (including the special 'headers' library
that provides LLVM's and Clang's headers) is available as a `@local_llvm//:llvm_<library_name>`
dependency (`@local_llvm//:llvm_headers` for the headers library), where `@local_llvm` is
the name of the used `llvm_configure`
[repository rule](https://docs.bazel.build/versions/master/skylark/repository_rules.html)
while `llvm_`, `clang_` and `mlir_` are the default prefixes for LLVM, Clang and MLIR specific
rules, all these parameters can be configured in your `WORKSPACE`. Notice that a library will
bring also its dependencies exactly how the *CMake* build works.

Platform-provided libraries such as "ncurses", "tinfo", "pthreads", "Z3" will be detected
automatically using the `*.cmake` files generated by CMake during the LLVM build process.

Notice: The minimum supported version of Bazel is
[**0.25.0**](https://github.com/bazelbuild/bazel/releases/tag/0.25.0).


### How to leverage the bridge in your project

In order to use any LLVM libraries in your targets, add the following to your
`WORKSPACE` file:

```bzl
load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")

http_archive(
    name = "bazel_llvm_bridge",
    sha256 = "0e0971ec02d5e061c2c472d185e390597a4d7842e3e457cfcda2f04c1839c05e",
    strip_prefix = "bazel-llvm-bridge-release-11-05",
    url = "https://github.com/samolisov/bazel-llvm-bridge/archive/release/11-05.zip",
)

load("@bazel_llvm_bridge//llvm:llvm_configure.bzl", "llvm_configure")

llvm_configure(
    name = "local_llvm",
    llvm_prefix = "llvm_",
    clang_prefix = "clang_",
    libcxx_prefix = "libcxx_",
    mlir_prefix = "mlir_",
    add_headers_to_deps = False,
)
```

Where `name` is whatever you want, default values for `llvm_prefix`, `clang_prefix`,
`libcxx_prefix` and `mlir_prefix` may be omitted. By default, the header libraries will be
automatically included as dependency to the generated targets (the LLVM header library to
LLVM's, Clang's and other project's targets, the Clang header library to Clang's targets, etc.)
If you would like to manually put the header libraries to dependencies, set up the
`add_headers_to_deps` attribute of the reporitory rule to `False`.

The LLVM libraries are fetched from a local installation so the `LLVM_INSTALL_PREFIX`
environment variable **must** point to the local installation.

The library's version number is matched to the version of LLVM and can be found in the
`release/<version>-<build>` tag or `release/<version>.x` branch. For example:

```bash
$ git clone https://github.com/samolisov/bazel-llvm-bridge.git
$ git checkout release/9.x
$ git log --oneline -1
```

shows you the latest commit in the release branch. The commit can be used as a value of the `commit`
attribute of the `git_repository` rule to checkout the compatible version of **bazel-llvm-bridge** for
the used version of **LLVM**:

```bzl
git_repository(
    name = "bazel_llvm_bridge",
    commit = "<THE LATEST COMMIT HERE>",
    remote = "https://github.com/samolisov/bazel-llvm-bridge.git",
)
```

Now the desired libraries can be added as dependencies (the `deps` attribute) to targets for
your libraries and binaries (through the `@local_llvm` repository):

```bzl
cc_binary(
    name = 'llvm_bb_counter',
    srcs = [
        "llvm/llvm_bb_counter.cc",
    ],
    deps = [
        "@local_llvm//:llvm_headers",
        "@local_llvm//:llvm_bit_reader",
    ] + if_cxx_linked([
        "@local_llvm//:libcxx_shared",
        "@local_llvm//:libcxx_abi_shared",
    ]),
    visibility = ["//visibility:private"],
)
```

### How to build the project

To build your targets, do the following:

 0. Build from sources or download from http://releases.llvm.org/download.html an
    archive with an LLVM package for your platform. The package must be unarchived
    into a local directory.

 1. Set up the `LLVM_INSTALL_PREFIX` environment variable. The variable must
    contain a path to a local LLVM installation:

    ```bash
    $ export LLVM_INSTALL_PREFIX=~/dev/llvm_master
    ```

    or, on Windows:

    ```bash
    $ set LLVM_INSTALL_PREFIX=C:\Dev\llvm_master
    ```

 2. Run the build:

    ```bash
    $ bazel build //:llvm_bb_counter
    ```

    alternatively, the environment variables may be passed directly to the build
    command:

    ```bash
    $ bazel build --action_env LLVM_INSTALL_PREFIX=C:\Dev\llvm_master //:clang_list_methods
    ```

### How to deal with targets

The **bazel-llvm-bridge** supports all out-of-the-box provided LLVM targets:
 * AArch64
 * AMDGPU
 * ARM
 * AVR
 * BPF
 * Hexagon
 * Lanai
 * Mips
 * MSP430
 * NVPTX
 * PowerPC
 * RISCV
 * Sparc
 * SystemZ
 * WebAssembly
 * X86
 * XCore

To link against a target, the user should to check whether the target is supported by the used
local installation of LLVM. A set of `if_has_<TARGET>` functions are provided by
`@local_llvm//:llvm_config.bzl` generated skylark file. Every function returns its first argument
when the target `<TARGET>` is supported, otherwise it returns the second argument. The function
is usable through the following way (see the `//:llvm_print_supported_targets` target in
the `examples/BUILD` file):

```bzl
load("@local_llvm//:llvm_config.bzl",
    "llvm_copts",
    "if_has_aarch64",
    ...
    "if_has_x86")

cc_binary(
    name = "llvm_print_supported_targets",
    srcs = [
        ...
    ],
    copts = llvm_copts()
        + if_has_aarch64(["-DLLVM_SUPPORTS_TARGET_AARCH64"])
        ...
        + if_has_x86(["-DLLVM_SUPPORTS_TARGET_X86"]),
    deps = if_has_aarch64([
        "@local_llvm//:llvm_aarch64_asm_parser",
        "@local_llvm//:llvm_aarch64_code_gen",
        "@local_llvm//:llvm_aarch64_disassembler",
    ]) +
    ...
       + if_has_x86([
        "@local_llvm//:llvm_x86_asm_parser",
        "@local_llvm//:llvm_x86_code_gen",
        "@local_llvm//:llvm_x86_disassembler",
    ])
)
```

### How to deal with tablegen

LLVM, Clang and MLIR are very intensive users of the [tablegen](https://llvm.org/docs/TableGen/) tool.
For example, MLIR's Table-driven
[Declarative Rewrite Rule](https://github.com/llvm/llvm-project/blob/master/mlir/docs/DeclarativeRewrites.md)
is based upon tablegen. Fortunately, **bazel-llvm-bridge** provides a rule to run the tablegen
tools for LLVM as well as for MLIR (`llvm-tblgen` and `mlir-tblgen` respectively). The rules are defined
in the `llvm_tablegen.bzl` and `mlir_tablegen.bzl` files.

To run the tablegen tool, the user should define one or more targets based on the `<prefix>_tablegen`
rule in a BUILD file. The targets can be used by any other `cc_` ones as dependencies and also
can depend on any `cc_library` (the tablegen tool will use includes and headers provided by such
libraries). For example:

```bzl
load("@local_llvm//:llvm_tablegen.bzl", "tablegen")

cc_binary(
    name = 'llvm_print_physical_registers',
    ...
    deps = [
        ...
        ":tablegen_registers",
    ],
    visibility = ["//visibility:private"],
)

tablegen(
    name = "tablegen_registers",
    srcs = [
        "llvm/target/custom_register_class.td",
    ],
    src = "llvm/target/custom_register_info.td",
    out = "target/custom_register_info.inc",
    opts = ["-gen-register-info"],
    deps = ["@local_llvm//:headers"],
    visibility = ["//visibility:private"],
)
```

Notice: a target should be defined for every tablegen invocation.

The `<prefix>_tablegen` rule has the following attributes:
 * name - the target's name.
 * src - the tablegen (.td) file to be the input of the tablegen tool.
 * srcs - the tablegen and other files used by the 'src' file. This attribute may be
   required for sandboxing.
 * out - the generated file's name. Can be prefixed with any number of folders
   (for example, `toy/Ops.h.inc`).
 * opts - command line options for the tablegen tool.
 * deps - the list of libraries that provide includes for the .td file.
 * includes - the list of include dirs to be added to the command line.

### How to deal with Clang/LLVM/MLIR shared libraries

Important note for users of the `libclang`, `libclang-cpp` and `LLVM-C` shared
libraries. There are three rules to bring these libraries from the LLVM
installation into the `bazel-bin`: `clang_copy_libclang`, `clang_copy_libclang_cpp`
and `llvm_copy_c`. Just add the targets into the `data` attribute of a rule and
they will appear in a `bazel-bin/external/<name of llvm_configure repository rule>`
directory. Then the libraries can be copied into the `bazel-bin` (see genrules
in the `examples/BUILD` file) and be used for running your applications.

### Linking against the libc++ standard library

Archives hosted on the http://releases.llvm.org/download.html official website
are usually built against the libc++ standard library. A configuration has been
added to the `examples/.bazelrc` file to make Bazel link the targets against
libc++. To enable the configuration, an `examples/libcxx.bazelrc` file must
be generated, the file contains a set of `BAZEL_...` repository environment
variable to let Bazel know where to look for libc++'s headers and the shared
library file.

To generate the file, a python script, `generate_libcxx_bazelrc.py`, was
developed and placed into the `examples` directory. The script accepts two
parameters: `-I<path to libc++ headers such as iostream or string>` and
`-L<path to libc++ shared library, libc++.so.1>`. For example:

```bash
$ python3 generate_libcxx_bazelrc.py -L/home/user/llvm/lib -I/home/user/llvm/include/c++/v1
```

Once a `libcxx.bazelrc` file has been generated, a build can be started with `--config=libc++`
option:

```bash
$ bazel build --repo_env LLVM_INSTALL_PREFIX=/home/user/llvm --config=libc++ //:clang_list_methods
```
