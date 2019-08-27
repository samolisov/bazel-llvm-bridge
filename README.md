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

This project provides a bridge that let you use static libraries from a local installation
of LLVM in your projects when Bazel is used for building. Each library from LLVM/Clang
(including the special 'headers' library that provides LLVM's and Clang's headers)
is available as a `@local_llvm//:llvm_<library_name>` dependency (`@local_llvm//:llvm_headers`
for the headers library, `clang` as the prefix for Clang's libraries), where `@local_llvm`
is the name of the used `llvm_configure`
[repository rule](https://docs.bazel.build/versions/master/skylark/repository_rules.html)
and can be edited in your `WORKSPACE`. Notice that a library will bring also its dependencies
exactly how the CMake build works.

In order to use any LLVM libraries in you targets, do the following steps:

 0. Checkout the corresponding version of the bridge. A version number
    is matched to the version of LLVM and can be found in the `release/<version>.x`
    branch. For example:

    ```bash
    $ git clone https://github.com/samolisov/bazel-llvm-bridge.git
    $ git checkout release/9.x
    ```

 1. Borrow the `third_party/llvm` directory to the same folder of
    your project.

 2. Add an `llvm_configure` repository rule into the `WORKSPACE` file:

    ```bzl
    llvm_configure(
        name = "local_llvm",
    )
    ```

 `name` is whatever you want.

 3. Add desired libraries as dependencies (the `deps` attribute) to targets for
    your libraries and binaries:

    ```bzl
    cc_binary(
        name = 'llvm_bb_counter',
        srcs = [
            "src/llvm_bb_counter.cc",
        ],
        deps = [
            "@local_llvm//:llvm_headers",
            "@local_llvm//:llvm_bit_reader",
        ],
        visibility = ["//visibility:private"],
    )
    ```

To build your targets, do the following:

 0. Build from sources or download from http://releases.llvm.org/download.html an
    archive with an LLVM package for your platform. The package must be unarchived
    into a local directory.

 1. Set up the `LLVM_INSTALL_PREFIX` environment-variable. The variable must
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

Important note for users of the `libclang`, `libclang-cpp` and `LLVM-C` shared
libraries. There are three rules to bring these libraries from the LLVM
installation into the `bazel-bin`: `clang_copy_libclang`, `clang_copy_libclang_cpp`
and `llvm_copy_c`. Just add the targets into the `data` attribute of a rule and
they will appear in a `bazel-bin/external/<name of llvm_configure repository rule>`
directory. Then the libraries can be copied into the `bazel-bin` (see genrules
in the BUILD file) and be used for running your applications.
