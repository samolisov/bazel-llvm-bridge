##
## Build - examples of using an external prebuilt llvm
##

config_setting(
    name = "linux_x86_64",
    constraint_values = [
        "@platforms//os:linux",
        "@platforms//cpu:x86_64",
    ],
    visibility = ["//visibility:public"],
)

config_setting(
    name = "macos_x86_64",
    constraint_values = [
        "@platforms//os:osx",
        "@platforms//cpu:x86_64",
    ],
    visibility = ["//visibility:public"],
)

config_setting(
    name = "windows_x86_64",
    constraint_values = [
        "@platforms//os:windows",
        "@platforms//cpu:x86_64",
    ],
    visibility = ["//visibility:public"],
)

load("@local_llvm//:llvm_config.bzl",
    "llvm_nix_copts",
    "llvm_win_copts",
    "llvm_cxx_copts",
    "if_cxx_linked",
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
    "if_has_system_z",
    "if_has_web_assembly",
    "if_has_x86",
    "if_has_x_core")

llvm_copts = select({
    ":linux_x86_64": llvm_nix_copts + llvm_cxx_copts,
    ":macos_x86_64": llvm_nix_copts + llvm_cxx_copts,
    ":windows_x86_64": llvm_win_copts,
    "//conditions:default": [],
})

cc_binary(
    name = 'llvm_bb_counter',
    srcs = [
        "llvm/llvm_bb_counter.cc",
    ],
    copts = llvm_copts,
    deps = [
        "@local_llvm//:headers",
        "@local_llvm//:bit_reader",
    ] + if_cxx_linked([
        "@local_llvm//:cxx_static",
        "@local_llvm//:cxx_abi_static",
    ]),
    visibility = ["//visibility:private"],
)

cc_library(
    name = "llvm_exp_passes",
    srcs = [
        "llvm/function_argument_usage_pass.cc",
    ],
    copts = llvm_copts,
    deps = [
        "@local_llvm//:headers",
        "@local_llvm//:core",
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
    ] + if_cxx_linked([
        "@local_llvm//:cxx_shared",
        "@local_llvm//:cxx_abi_shared",
    ]),
    visibility = ["//visibility:private"],
)

cc_binary(
    name = "llvm_print_supported_targets",
    srcs = [
        "llvm/llvm_print_supported_targets.cc",
    ],
    copts = llvm_copts,
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
        + if_has_system_z(["LLVM_SUPPORTS_TARGET_SYSTEMZ"])
        + if_has_web_assembly(["LLVM_SUPPORTS_TARGET_WEBASSEMBLY"])
        + if_has_x86(["LLVM_SUPPORTS_TARGET_X86"])
        + if_has_x_core(["LLVM_SUPPORTS_TARGET_XCORE"]),
    deps = if_has_aarch64([
        "@local_llvm//:aarch64_asm_parser",
        "@local_llvm//:aarch64_asm_printer",
        "@local_llvm//:aarch64_code_gen",
        "@local_llvm//:aarch64_disassembler",
    ]) + if_has_amdgpu([
        "@local_llvm//:amdgpu_asm_parser",
        "@local_llvm//:amdgpu_asm_printer",
        "@local_llvm//:amdgpu_code_gen",
        "@local_llvm//:amdgpu_disassembler",
    ]) + if_has_arm([
        "@local_llvm//:arm_asm_parser",
        "@local_llvm//:arm_asm_printer",
        "@local_llvm//:arm_code_gen",
        "@local_llvm//:arm_disassembler",
    ]) + if_has_bpf([
        "@local_llvm//:bpf_asm_parser",
        "@local_llvm//:bpf_asm_printer",
        "@local_llvm//:bpf_code_gen",
        "@local_llvm//:bpf_disassembler",
    ]) + if_has_hexagon([
        "@local_llvm//:hexagon_asm_parser",
        "@local_llvm//:hexagon_code_gen",
        "@local_llvm//:hexagon_disassembler",
    ]) + if_has_lanai([
        "@local_llvm//:lanai_asm_parser",
        "@local_llvm//:lanai_asm_printer",
        "@local_llvm//:lanai_code_gen",
        "@local_llvm//:lanai_disassembler",
    ]) + if_has_mips([
        "@local_llvm//:mips_asm_parser",
        "@local_llvm//:mips_asm_printer",
        "@local_llvm//:mips_code_gen",
        "@local_llvm//:mips_disassembler",
    ]) + if_has_msp430([
        "@local_llvm//:msp430_asm_parser",
        "@local_llvm//:msp430_asm_printer",
        "@local_llvm//:msp430_code_gen",
        "@local_llvm//:msp430_disassembler",
    ]) + if_has_nvptx([
        "@local_llvm//:nvptx_asm_printer",
        "@local_llvm//:nvptx_code_gen",
    ]) + if_has_powerpc([
        "@local_llvm//:powerpc_asm_parser",
        "@local_llvm//:powerpc_asm_printer",
        "@local_llvm//:powerpc_code_gen",
        "@local_llvm//:powerpc_disassembler",
    ]) + if_has_sparc([
        "@local_llvm//:sparc_asm_parser",
        "@local_llvm//:sparc_asm_printer",
        "@local_llvm//:sparc_code_gen",
        "@local_llvm//:sparc_disassembler",
    ]) + if_has_system_z([
        "@local_llvm//:system_z_asm_parser",
        "@local_llvm//:system_z_asm_printer",
        "@local_llvm//:system_z_code_gen",
        "@local_llvm//:system_z_disassembler",
    ]) + if_has_web_assembly([
        "@local_llvm//:web_assembly_asm_parser",
        "@local_llvm//:web_assembly_asm_printer",
        "@local_llvm//:web_assembly_code_gen",
        "@local_llvm//:web_assembly_disassembler",
    ]) + if_has_x86([
        "@local_llvm//:x86_asm_parser",
        "@local_llvm//:x86_asm_printer",
        "@local_llvm//:x86_code_gen",
        "@local_llvm//:x86_disassembler",
    ]) + if_has_x_core([
        "@local_llvm//:x_core_asm_printer",
        "@local_llvm//:x_core_code_gen",
        "@local_llvm//:x_core_disassembler",
    ]) + if_cxx_linked([
        "@local_llvm//:cxx_shared",
        "@local_llvm//:cxx_abi_shared",
    ]),
)

cc_binary(
    name = 'clang_list_methods',
    srcs = [
        "clang/clang_list_methods.cc",
    ],
    copts = llvm_copts,
    data = select({
        ":linux_x86_64": [
            "copy_local_llvm_shared_lin",
        ],
        ":macos_x86_64": [
            "copy_local_llvm_shared_mac",
        ],
        ":windows_x86_64": [
            "copy_local_llvm_shared_win",
        ],
        "//conditions:default": [],
    }),
    deps = [
        "@local_llvm//:cl_headers",
        "@local_llvm//:cl_libclang",
        "@local_llvm//:config_headers",
        "@local_llvm//:headers",
        "@local_llvm//:support",
    ] + if_cxx_linked([
        "@local_llvm//:cxx_shared",
        "@local_llvm//:cxx_abi_shared",
    ]),
    linkopts = select({
        ":linux_x86_64": [
            "-Wl,-R -Wl,."
        ],
        ":macos_x86_64": [
            "-Wl,-R -Wl,."
        ],
        ":windows_x86_64": [
        ],
        "//conditions:default": [],
    }),
    visibility = ["//visibility:private"],
)

genrule(
    name = "copy_local_llvm_shared_lin",
    srcs = [
        "@local_llvm//:cl_copy_libclang",
    ],
    outs = [
        "libclang.so.8",
    ],
    cmd = """
        cp -f $(location @local_llvm//:cl_copy_libclang) $(@D)/libclang.so.8
    """,
    output_to_bindir = 1,
    visibility = ["//visibility:private"],
)

genrule(
    name = "copy_local_llvm_shared_mac",
    srcs = [
        "@local_llvm//:cl_copy_libclang",
    ],
    outs = [
        "libclang.dylib",
    ],
    cmd = """
        cp -f $(location @local_llvm//:cl_copy_libclang) $(@D)
    """,
    output_to_bindir = 1,
    visibility = ["//visibility:private"],
)

genrule(
    name = "copy_local_llvm_shared_win",
    srcs = [
        "@local_llvm//:cl_copy_libclang",
    ],
    outs = [
        "libclang.dll",
    ],
    cmd = """
        cp -f $(location @local_llvm//:cl_copy_libclang) $(@D)
    """,
    output_to_bindir = 1,
    visibility = ["//visibility:private"],
)
