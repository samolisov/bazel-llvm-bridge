##
## Build - using an external prebuilt llvm
##

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
    data = [
        "@local_llvm//:clang_copy_libclang",
        "@local_llvm//:llvm_copy_c",
    ],
    deps = [
        "@local_llvm//:clang_headers",
        "@local_llvm//:clang_libclang",
        "@local_llvm//:llvm_config_headers",
        "@local_llvm//:llvm_headers",
        "@local_llvm//:llvm_support",
    ],
    visibility = ["//visibility:private"],
)
