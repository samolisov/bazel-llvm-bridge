##
## Build - examples of using an external prebuilt llvm
##

config_setting(
    name = "linux_x86_64",
    constraint_values = [
        "@bazel_tools//platforms:linux",
        "@bazel_tools//platforms:x86_64",
    ],
    visibility = ["//visibility:public"],
)

config_setting(
    name = "macos",
    constraint_values = [
        "@bazel_tools//platforms:osx",
        "@bazel_tools//platforms:x86_64",
    ],
    visibility = ["//visibility:public"],
)

config_setting(
    name = "windows",
    constraint_values = ["@bazel_tools//platforms:windows"],
    visibility = ["//visibility:public"],
)

cc_binary(
    name = 'llvm_bb_counter',
    srcs = [
        "llvm/llvm_bb_counter.cc",
    ],
    copts = select({
        ":linux_x86_64": [
            "-std=c++14",
            "-fno-rtti",
        ],
        ":macos": [
            "-std=c++14",
            "-fno-rtti",
        ],
        ":windows": [],
        "//conditions:default": [],
    }),
    deps = [
        "@local_llvm//:llvm_headers",
        "@local_llvm//:llvm_bit_reader",
    ],
    visibility = ["//visibility:private"],
)

cc_library(
    name = "llvm_exp_passes",
    srcs = [
        "llvm/function_argument_usage_pass.cc",
    ],
    copts = select({
        ":linux_x86_64": [
            "-std=c++14",
            "-fno-rtti",
        ],
        ":macos": [
            "-std=c++14",
            "-fno-rtti",
        ],
        ":windows": [],
        "//conditions:default": [],
    }),
    deps = [
        "@local_llvm//:llvm_headers",
        "@local_llvm//:llvm_core",
    ],
    alwayslink = 1, # this is required to get a link error when
                    # a dependency has been missed
    visibility = ["//visibility:public"],
)

cc_binary(
    name = "llvm_exp_passes_linked",
    srcs = [
        "llvm/llvm_empty_main.cc",
    ],
    deps = [
        ":llvm_exp_passes",
    ],
    visibility = ["//visibility:private"],
)

cc_binary(
    name = 'clang_list_methods',
    srcs = [
        "clang/clang_list_methods.cc",
    ],
    copts = select({
        ":linux_x86_64": [
            "-std=c++14",
            "-fno-rtti",
        ],
        ":macos": [
            "-std=c++14",
            "-fno-rtti",
        ],
        ":windows": [],
        "//conditions:default": [],
    }),
    data = select({
        ":linux_x86_64": [
            "copy_local_llvm_shared_lin",
        ],
        ":macos": [
            "copy_local_llvm_shared_mac",
        ],
        ":windows": [
            "copy_local_llvm_shared_win",
        ],
        "//conditions:default": [],
    }),
    deps = [
        "@local_llvm//:clang_headers",
        "@local_llvm//:clang_libclang",
        "@local_llvm//:llvm_config_headers",
        "@local_llvm//:llvm_headers",
        "@local_llvm//:llvm_support",
    ],
    linkopts = select({
        ":linux_x86_64": [
            "-Wl,-R -Wl,."
        ],
        ":macos": [
            "-Wl,-R -Wl,."
        ],
        ":windows": [
        ],
        "//conditions:default": [],
    }),
    visibility = ["//visibility:private"],
)

genrule(
    name = "copy_local_llvm_shared_lin",
    srcs = [
        "@local_llvm//:clang_copy_libclang",
        "@local_llvm//:clang_copy_libclang_cpp",
    ],
    outs = [
        "libclang.so.10svn",
        "libclang-cpp.so.10svn",
    ],
    cmd = """
        cp -f $(location @local_llvm//:clang_copy_libclang) $(@D)/libclang.so.10svn
        cp -f $(location @local_llvm//:clang_copy_libclang_cpp) $(@D)/libclang-cpp.so.10svn
    """,
    output_to_bindir = 1,
    visibility = ["//visibility:private"],
)

genrule(
    name = "copy_local_llvm_shared_mac",
    srcs = [
        "@local_llvm//:clang_copy_libclang",
        "@local_llvm//:clang_copy_libclang_cpp",
    ],
    outs = [
        "libclang.dylib",
        "libclang-cpp.dylib",
    ],
    cmd = """
        cp -f $(location @local_llvm//:clang_copy_libclang) $(@D)
        cp -f $(location @local_llvm//:clang_copy_libclang_cpp) $(@D)
    """,
    output_to_bindir = 1,
    visibility = ["//visibility:private"],
)

genrule(
    name = "copy_local_llvm_shared_win",
    srcs = [
        "@local_llvm//:clang_copy_libclang",
        "@local_llvm//:llvm_copy_c",
    ],
    outs = [
        "libclang.dll",
        "LLVM-C.dll",
    ],
    cmd = """
        cp -f $(location @local_llvm//:clang_copy_libclang) $(@D)
        cp -f $(location @local_llvm//:llvm_copy_c) $(@D)
    """,
    output_to_bindir = 1,
    visibility = ["//visibility:private"],
)
