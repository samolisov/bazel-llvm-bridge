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

load("@local_llvm//:llvm_config.bzl",
    "llvm_copts",
    "if_has_aarch64",
    "if_has_amdgpu",
    "if_has_arm",
    "if_has_bpf",
    "if_has_hexagon",
    "if_has_lanai",
    "if_has_mips",
    "if_has_msp430",
    "if_has_nvptx",
    "if_has_powerpc",
    "if_has_sparc",
    "if_has_systemz",
    "if_has_webassembly",
    "if_has_x86",
    "if_has_xcore")

cc_binary(
    name = 'llvm_bb_counter',
    srcs = [
        "llvm/llvm_bb_counter.cc",
    ],
    copts = llvm_copts(),
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
    copts = llvm_copts(),
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
    name = "llvm_print_supported_targets",
    srcs = [
        "llvm/llvm_print_supported_targets.cc",
    ],
    copts = llvm_copts(),
    defines = if_has_aarch64(["LLVM_SUPPORTS_TARGET_AARCH64"])
        + if_has_amdgpu(["LLVM_SUPPORTS_TARGET_AMDGPU"])
        + if_has_arm(["LLVM_SUPPORTS_TARGET_ARM"])
        + if_has_bpf(["LLVM_SUPPORTS_TARGET_BPF"])
        + if_has_hexagon(["LLVM_SUPPORTS_TARGET_HEXAGON"])
        + if_has_lanai(["LLVM_SUPPORTS_TARGET_LANAI"])
        + if_has_mips(["LLVM_SUPPORTS_TARGET_MIPS"])
        + if_has_msp430(["LLVM_SUPPORTS_TARGET_MSP430"])
        + if_has_nvptx(["LLVM_SUPPORTS_TARGET_NVPTX"])
        + if_has_powerpc(["LLVM_SUPPORTS_TARGET_POWERPC"])
        + if_has_sparc(["LLVM_SUPPORTS_TARGET_SPARC"])
        + if_has_systemz(["LLVM_SUPPORTS_TARGET_SYSTEMZ"])
        + if_has_webassembly(["LLVM_SUPPORTS_TARGET_WEBASSEMBLY"])
        + if_has_x86(["LLVM_SUPPORTS_TARGET_X86"])
        + if_has_xcore(["LLVM_SUPPORTS_TARGET_XCORE"]),
    deps = if_has_aarch64([
        "@local_llvm//:llvm_aarch64_asm_parser",
        "@local_llvm//:llvm_aarch64_asm_printer",
        "@local_llvm//:llvm_aarch64_code_gen",
        "@local_llvm//:llvm_aarch64_disassembler",
    ]) + if_has_amdgpu([
        "@local_llvm//:llvm_amdgpu_asm_parser",
        "@local_llvm//:llvm_amdgpu_asm_printer",
        "@local_llvm//:llvm_amdgpu_code_gen",
        "@local_llvm//:llvm_amdgpu_disassembler",
    ]) + if_has_arm([
        "@local_llvm//:llvm_arm_asm_parser",
        "@local_llvm//:llvm_arm_asm_printer",
        "@local_llvm//:llvm_arm_code_gen",
        "@local_llvm//:llvm_arm_disassembler",
    ]) + if_has_bpf([
        "@local_llvm//:llvm_bpf_asm_parser",
        "@local_llvm//:llvm_bpf_asm_printer",
        "@local_llvm//:llvm_bpf_code_gen",
        "@local_llvm//:llvm_bpf_disassembler",
    ]) + if_has_hexagon([
        "@local_llvm//:llvm_hexagon_asm_parser",
        "@local_llvm//:llvm_hexagon_code_gen",
        "@local_llvm//:llvm_hexagon_disassembler",
    ]) + if_has_lanai([
        "@local_llvm//:llvm_lanai_asm_parser",
        "@local_llvm//:llvm_lanai_asm_printer",
        "@local_llvm//:llvm_lanai_code_gen",
        "@local_llvm//:llvm_lanai_disassembler",
    ]) + if_has_mips([
        "@local_llvm//:llvm_mips_asm_parser",
        "@local_llvm//:llvm_mips_asm_printer",
        "@local_llvm//:llvm_mips_code_gen",
        "@local_llvm//:llvm_mips_disassembler",
    ]) + if_has_msp430([
        "@local_llvm//:llvm_msp430_asm_parser",
        "@local_llvm//:llvm_msp430_asm_printer",
        "@local_llvm//:llvm_msp430_code_gen",
        "@local_llvm//:llvm_msp430_disassembler",
    ]) + if_has_nvptx([
        "@local_llvm//:llvm_nvptx_asm_printer",
        "@local_llvm//:llvm_nvptx_code_gen",
    ]) + if_has_powerpc([
        "@local_llvm//:llvm_powerpc_asm_parser",
        "@local_llvm//:llvm_powerpc_asm_printer",
        "@local_llvm//:llvm_powerpc_code_gen",
        "@local_llvm//:llvm_powerpc_disassembler",
    ]) + if_has_sparc([
        "@local_llvm//:llvm_sparc_asm_parser",
        "@local_llvm//:llvm_sparc_asm_printer",
        "@local_llvm//:llvm_sparc_code_gen",
        "@local_llvm//:llvm_sparc_disassembler",
    ]) + if_has_systemz([
        "@local_llvm//:llvm_systemz_asm_parser",
        "@local_llvm//:llvm_systemz_asm_printer",
        "@local_llvm//:llvm_systemz_code_gen",
        "@local_llvm//:llvm_systemz_disassembler",
    ]) + if_has_webassembly([
        "@local_llvm//:llvm_webassembly_asm_parser",
        "@local_llvm//:llvm_webassembly_asm_printer",
        "@local_llvm//:llvm_webassembly_code_gen",
        "@local_llvm//:llvm_webassembly_disassembler",
    ]) + if_has_x86([
        "@local_llvm//:llvm_x86_asm_parser",
        "@local_llvm//:llvm_x86_asm_printer",
        "@local_llvm//:llvm_x86_code_gen",
        "@local_llvm//:llvm_x86_disassembler",
    ]) + if_has_xcore([
        "@local_llvm//:llvm_xcore_asm_printer",
        "@local_llvm//:llvm_xcore_code_gen",
        "@local_llvm//:llvm_xcore_disassembler",
    ])
)

cc_binary(
    name = 'clang_list_methods',
    srcs = [
        "clang/clang_list_methods.cc",
    ],
    copts = llvm_copts(),
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
    ],
    outs = [
        "libclang.so.8",
    ],
    cmd = """
        cp -f $(location @local_llvm//:clang_copy_libclang) $(@D)/libclang.so.8
    """,
    output_to_bindir = 1,
    visibility = ["//visibility:private"],
)

genrule(
    name = "copy_local_llvm_shared_mac",
    srcs = [
        "@local_llvm//:clang_copy_libclang",
    ],
    outs = [
        "libclang.dylib",
    ],
    cmd = """
        cp -f $(location @local_llvm//:clang_copy_libclang) $(@D)
    """,
    output_to_bindir = 1,
    visibility = ["//visibility:private"],
)

genrule(
    name = "copy_local_llvm_shared_win",
    srcs = [
        "@local_llvm//:clang_copy_libclang",
    ],
    outs = [
        "libclang.dll",
    ],
    cmd = """
        cp -f $(location @local_llvm//:clang_copy_libclang) $(@D)
    """,
    output_to_bindir = 1,
    visibility = ["//visibility:private"],
)
