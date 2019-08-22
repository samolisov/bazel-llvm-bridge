##
## Build - using an external prebuilt llvm
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
        "src/llvm_bb_counter.cc",
    ],
    deps = [
        "@local_llvm//:llvm_headers",
        "@local_llvm//:llvm_bit_reader",
    ],
    visibility = ["//visibility:private"],
)

cc_library(
    name = "llvm_exp_passes",
    srcs = [
        "src/passes/function_argument_usage_pass.cc",
    ],
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
        "src/llvm_empty_main.cc",
    ],
    deps = [
        ":llvm_exp_passes",
    ],
    visibility = ["//visibility:private"],
)

cc_binary(
    name = 'clang_list_methods',
    srcs = [
        "src/clang_list_methods.cc",
    ],
    data = select({
        "@llvm_bazel_bridge//:linux_x86_64": [
            "copy_local_llvm_shared_lin",
        ],
        "@llvm_bazel_bridge//:macos": [
            "copy_local_llvm_shared_mac",
        ],
        "@llvm_bazel_bridge//:windows": [
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
    visibility = ["//visibility:private"],
)

genrule(
    name = "copy_local_llvm_shared_lin",
    srcs = [
        "@local_llvm//:clang_copy_libclang",
        "@local_llvm//:llvm_copy_c",
    ],
    outs = [
        "libclang.so",
        "libLLVM-C.so",
    ],
    cmd = """
        cp -f $(location @local_llvm//:clang_copy_libclang) $(@D)
        cp -f $(location @local_llvm//:llvm_copy_c) $(@D)
    """,
    output_to_bindir = 1,
    visibility = ["//visibility:private"],
)

genrule(
    name = "copy_local_llvm_shared_max",
    srcs = [
        "@local_llvm//:clang_copy_libclang",
        "@local_llvm//:llvm_copy_c",
    ],
    outs = [
        "libclang.dylib",
        "libLLVM-C.dylib",
    ],
    cmd = """
        cp -f $(location @local_llvm//:clang_copy_libclang) $(@D)
        cp -f $(location @local_llvm//:llvm_copy_c) $(@D)
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
