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
    "if_cxx_linked",
    "if_has_aarch64",
    "if_has_amdgpu",
    "if_has_arm",
    "if_has_avr",
    "if_has_bpf",
    "if_has_hexagon",
    "if_has_lanai",
    "if_has_mips",
    "if_has_msp430",
    "if_has_nvptx",
    "if_has_powerpc",
    "if_has_riscv",
    "if_has_sparc",
    "if_has_system_z",
    "if_has_web_assembly",
    "if_has_x86",
    "if_has_x_core")

load("@local_llvm//:llvm_tablegen.bzl", "tablegen")

llvm_copts = select({
    ":linux_x86_64": llvm_nix_copts,
    ":macos_x86_64": llvm_nix_copts,
    ":windows_x86_64": llvm_win_copts,
    "//conditions:default": [],
})

# Example: do nothing, just link a cc-file with all the LLVM libraries.
# This example checks the dependency chain for each library.
# Usage: llvm_check_dependencies
cc_binary(
    name = 'llvm_check_dependencies',
    srcs = [
        "llvm/llvm_empty_main.cc",
    ],
    copts = llvm_copts,
    deps = [
        "@local_llvm//:config_headers",
        "@local_llvm//:headers",
        "@local_llvm//:aggressive_inst_combine",
        "@local_llvm//:analysis",
        "@local_llvm//:asm_parser",
        "@local_llvm//:asm_printer",
        "@local_llvm//:binary_format",
        "@local_llvm//:bit_reader",
        "@local_llvm//:bit_writer",
        "@local_llvm//:bitstream_reader",
        "@local_llvm//:cf_guard",
        "@local_llvm//:code_gen",
        "@local_llvm//:core",
        "@local_llvm//:coroutines",
        "@local_llvm//:coverage",
        "@local_llvm//:debug_info_code_view",
        "@local_llvm//:debug_info_dwarf",
        "@local_llvm//:debug_info_gsym",
        "@local_llvm//:debug_info_msf",
        "@local_llvm//:debug_info_pdb",
        "@local_llvm//:demangle",
        "@local_llvm//:dlltool_driver",
        "@local_llvm//:dwarf_linker",
        "@local_llvm//:execution_engine",
        "@local_llvm//:extensions",
        "@local_llvm//:frontend_open_mp",
        "@local_llvm//:fuzz_mutate",
        "@local_llvm//:global_i_sel",
        "@local_llvm//:inst_combine",
        "@local_llvm//:instrumentation",
        "@local_llvm//:interpreter",
        "@local_llvm//:ir_reader",
        "@local_llvm//:ipo",
        "@local_llvm//:jit_link",
        "@local_llvm//:lib_driver",
        "@local_llvm//:line_editor",
        "@local_llvm//:linker",
        "@local_llvm//:lto",
        "@local_llvm//:mc",
        "@local_llvm//:mca",
        "@local_llvm//:mc_disassembler",
        "@local_llvm//:mcjit",
        "@local_llvm//:mc_parser",
        "@local_llvm//:mir_parser",
        "@local_llvm//:objc_arc",
        "@local_llvm//:object",
        "@local_llvm//:object_yaml",
        "@local_llvm//:option",
        "@local_llvm//:orc_error",
        "@local_llvm//:orc_jit",
        "@local_llvm//:passes",
        "@local_llvm//:profile_data",
        "@local_llvm//:remarks",
        "@local_llvm//:runtime_dyld",
        "@local_llvm//:scalar",
        "@local_llvm//:selection_dag",
        "@local_llvm//:support",
        "@local_llvm//:symbolize",
        "@local_llvm//:tablegen",
        "@local_llvm//:target",
        "@local_llvm//:text_api",
        "@local_llvm//:transform_utils",
        "@local_llvm//:vectorize",
        "@local_llvm//:windows_manifest",
        "@local_llvm//:x_ray",       
    ] + if_has_aarch64([
        "@local_llvm//:aarch64_asm_parser",
        "@local_llvm//:aarch64_code_gen",
        "@local_llvm//:aarch64_desc",
        "@local_llvm//:aarch64_disassembler",
        "@local_llvm//:aarch64_info",
        "@local_llvm//:aarch64_utils",
    ]) + if_has_amdgpu([
        "@local_llvm//:amdgpu_asm_parser",
        "@local_llvm//:amdgpu_code_gen",
        "@local_llvm//:amdgpu_desc",
        "@local_llvm//:amdgpu_disassembler",
        "@local_llvm//:amdgpu_info",
        "@local_llvm//:amdgpu_utils",
    ]) + if_has_arm([
        "@local_llvm//:arm_asm_parser",
        "@local_llvm//:arm_code_gen",
        "@local_llvm//:arm_desc",
        "@local_llvm//:arm_disassembler",
        "@local_llvm//:arm_info",
        "@local_llvm//:arm_utils",
    ]) + if_has_avr([
        "@local_llvm//:avr_asm_parser",
        "@local_llvm//:avr_code_gen",
        "@local_llvm//:avr_desc",
        "@local_llvm//:avr_disassembler",
        "@local_llvm//:avr_info",
    ]) + if_has_bpf([
        "@local_llvm//:bpf_asm_parser",
        "@local_llvm//:bpf_code_gen",
        "@local_llvm//:bpf_desc",
        "@local_llvm//:bpf_disassembler",
        "@local_llvm//:bpf_info",
    ]) + if_has_hexagon([
        "@local_llvm//:hexagon_asm_parser",
        "@local_llvm//:hexagon_code_gen",
        "@local_llvm//:hexagon_desc",
        "@local_llvm//:hexagon_disassembler",
        "@local_llvm//:hexagon_info",
    ]) + if_has_lanai([
        "@local_llvm//:lanai_asm_parser",
        "@local_llvm//:lanai_code_gen",
        "@local_llvm//:lanai_desc",
        "@local_llvm//:lanai_disassembler",
        "@local_llvm//:lanai_info",
    ]) + if_has_mips([
        "@local_llvm//:mips_asm_parser",
        "@local_llvm//:mips_code_gen",
        "@local_llvm//:mips_desc",
        "@local_llvm//:mips_disassembler",
        "@local_llvm//:mips_info",
    ]) + if_has_msp430([
        "@local_llvm//:msp430_asm_parser",
        "@local_llvm//:msp430_code_gen",
        "@local_llvm//:msp430_desc",
        "@local_llvm//:msp430_disassembler",
        "@local_llvm//:msp430_info",
    ]) + if_has_nvptx([
        "@local_llvm//:nvptx_code_gen",
        "@local_llvm//:nvptx_desc",
        "@local_llvm//:nvptx_info",
    ]) + if_has_powerpc([
        "@local_llvm//:powerpc_asm_parser",
        "@local_llvm//:powerpc_code_gen",
        "@local_llvm//:powerpc_desc",
        "@local_llvm//:powerpc_disassembler",
        "@local_llvm//:powerpc_info",
    ]) + if_has_riscv([
        "@local_llvm//:riscv_asm_parser",
        "@local_llvm//:riscv_code_gen",
        "@local_llvm//:riscv_desc",
        "@local_llvm//:riscv_disassembler",
        "@local_llvm//:riscv_info",
        "@local_llvm//:riscv_utils",
    ]) + if_has_sparc([
        "@local_llvm//:sparc_asm_parser",
        "@local_llvm//:sparc_code_gen",
        "@local_llvm//:sparc_desc",
        "@local_llvm//:sparc_disassembler",
        "@local_llvm//:sparc_info",
    ]) + if_has_system_z([
        "@local_llvm//:system_z_asm_parser",
        "@local_llvm//:system_z_code_gen",
        "@local_llvm//:system_z_desc",
        "@local_llvm//:system_z_disassembler",
        "@local_llvm//:system_z_info",
    ]) + if_has_web_assembly([
        "@local_llvm//:web_assembly_asm_parser",
        "@local_llvm//:web_assembly_code_gen",
        "@local_llvm//:web_assembly_desc",
        "@local_llvm//:web_assembly_disassembler",
        "@local_llvm//:web_assembly_info",
    ]) + if_has_x86([
        "@local_llvm//:x86_asm_parser",
        "@local_llvm//:x86_code_gen",
        "@local_llvm//:x86_desc",
        "@local_llvm//:x86_disassembler",
        "@local_llvm//:x86_info",
    ]) + if_has_x_core([
        "@local_llvm//:x_core_code_gen",
        "@local_llvm//:x_core_desc",
        "@local_llvm//:x_core_disassembler",
        "@local_llvm//:x_core_info",
    ]) + if_cxx_linked([
        "@local_llvm//:cxx_shared",
        "@local_llvm//:cxx_abi_shared",
    ]),
    visibility = ["//visibility:private"],
)

# Example: taking the bit_reader library as well as LLVM's headers into
# account. The 'llvm_bb_counter' application returns how many basic blocks
# has every function in a bit code file.
# Usage: llvm_bb_counter <path to a .bc file>
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

# Example: taking the core library as well as LLVM's headers into
# account. Some custom IR passes are combined into a static library.
# The 'alwayslink' flag is required to demonstrate how dependencies
# are used. Without the flag, symbols not used by an application
# linked against will just be ignored.
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

# Example: an application is just developed to be linked against the
# 'llvm_exp_passes' static library. The application does nothing but
# all dependencies must be satisfied to let the application be linked.
# Usage: llvm_exp_passes_linked
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

# Example: taking supported by the local installation of LLVM targets into
# account. The example uses many provided 'if_has_<TARGET>' functions to
# define required compiler flags and be linked against required target
# libraries.
# Usage: llvm_print_supported_targets
cc_binary(
    name = "llvm_print_supported_targets",
    srcs = [
        "llvm/llvm_print_supported_targets.cc",
    ],
    copts = llvm_copts,
    defines = if_has_aarch64(["LLVM_SUPPORTS_TARGET_AARCH64"])
        + if_has_amdgpu(["LLVM_SUPPORTS_TARGET_AMDGPU"])
        + if_has_arm(["LLVM_SUPPORTS_TARGET_ARM"])
        + if_has_avr(["LLVM_SUPPORTS_TARGET_AVR"])
        + if_has_bpf(["LLVM_SUPPORTS_TARGET_BPF"])
        + if_has_hexagon(["LLVM_SUPPORTS_TARGET_HEXAGON"])
        + if_has_lanai(["LLVM_SUPPORTS_TARGET_LANAI"])
        + if_has_mips(["LLVM_SUPPORTS_TARGET_MIPS"])
        + if_has_msp430(["LLVM_SUPPORTS_TARGET_MSP430"])
        + if_has_nvptx(["LLVM_SUPPORTS_TARGET_NVPTX"])
        + if_has_powerpc(["LLVM_SUPPORTS_TARGET_POWERPC"])
        + if_has_riscv(["LLVM_SUPPORTS_TARGET_RISCV"])
        + if_has_sparc(["LLVM_SUPPORTS_TARGET_SPARC"])
        + if_has_system_z(["LLVM_SUPPORTS_TARGET_SYSTEMZ"])
        + if_has_web_assembly(["LLVM_SUPPORTS_TARGET_WEBASSEMBLY"])
        + if_has_x86(["LLVM_SUPPORTS_TARGET_X86"])
        + if_has_x_core(["LLVM_SUPPORTS_TARGET_XCORE"]),
    deps = if_has_aarch64([
        "@local_llvm//:aarch64_asm_parser",
        "@local_llvm//:aarch64_code_gen",
        "@local_llvm//:aarch64_disassembler",
    ]) + if_has_amdgpu([
        "@local_llvm//:amdgpu_asm_parser",
        "@local_llvm//:amdgpu_code_gen",
        "@local_llvm//:amdgpu_disassembler",
    ]) + if_has_arm([
        "@local_llvm//:arm_asm_parser",
        "@local_llvm//:arm_code_gen",
        "@local_llvm//:arm_disassembler",
    ]) + if_has_avr([
        "@local_llvm//:avr_asm_parser",
        "@local_llvm//:avr_code_gen",
        "@local_llvm//:avr_disassembler",
    ]) + if_has_bpf([
        "@local_llvm//:bpf_asm_parser",
        "@local_llvm//:bpf_code_gen",
        "@local_llvm//:bpf_disassembler",
    ]) + if_has_hexagon([
        "@local_llvm//:hexagon_asm_parser",
        "@local_llvm//:hexagon_code_gen",
        "@local_llvm//:hexagon_disassembler",
    ]) + if_has_lanai([
        "@local_llvm//:lanai_asm_parser",
        "@local_llvm//:lanai_code_gen",
        "@local_llvm//:lanai_disassembler",
    ]) + if_has_mips([
        "@local_llvm//:mips_asm_parser",
        "@local_llvm//:mips_code_gen",
        "@local_llvm//:mips_disassembler",
    ]) + if_has_msp430([
        "@local_llvm//:msp430_asm_parser",
        "@local_llvm//:msp430_code_gen",
        "@local_llvm//:msp430_disassembler",
    ]) + if_has_nvptx([
        "@local_llvm//:nvptx_code_gen",
    ]) + if_has_powerpc([
        "@local_llvm//:powerpc_asm_parser",
        "@local_llvm//:powerpc_code_gen",
        "@local_llvm//:powerpc_disassembler",
    ]) + if_has_riscv([
        "@local_llvm//:riscv_asm_parser",
        "@local_llvm//:riscv_code_gen",
        "@local_llvm//:riscv_disassembler",
    ]) + if_has_sparc([
        "@local_llvm//:sparc_asm_parser",
        "@local_llvm//:sparc_code_gen",
        "@local_llvm//:sparc_disassembler",
    ]) + if_has_system_z([
        "@local_llvm//:system_z_asm_parser",
        "@local_llvm//:system_z_code_gen",
        "@local_llvm//:system_z_disassembler",
    ]) + if_has_web_assembly([
        "@local_llvm//:web_assembly_asm_parser",
        "@local_llvm//:web_assembly_code_gen",
        "@local_llvm//:web_assembly_disassembler",
    ]) + if_has_x86([
        "@local_llvm//:x86_asm_parser",
        "@local_llvm//:x86_code_gen",
        "@local_llvm//:x86_disassembler",
    ]) + if_has_x_core([
        "@local_llvm//:x_core_code_gen",
        "@local_llvm//:x_core_disassembler",
    ]) + if_cxx_linked([
        "@local_llvm//:cxx_shared",
        "@local_llvm//:cxx_abi_shared",
    ]),
)

# Example: print physical registers for an imaginary custom target.
# This example demonstrates how to use llvm-tablegen as a dependency.
# Usage: llvm_print_physical_registers
cc_binary(
    name = 'llvm_print_physical_registers',
    srcs = [
        "llvm/target/custom_frame_lowering.h",
        "llvm/target/custom_register_info.h",
        "llvm/target/custom_frame_lowering.cc",
        "llvm/target/custom_mc_target_desc.cc",
        "llvm/target/custom_register_info.cc",
        "llvm/llvm_print_physical_registers.cc",
    ],
    copts = llvm_copts,
    deps = [
        "@local_llvm//:headers",
        "@local_llvm//:code_gen",
        "@local_llvm//:support",
        ":tablegen_registers",
    ] + if_cxx_linked([
        "@local_llvm//:cxx_shared",
        "@local_llvm//:cxx_abi_shared",
    ]),
    visibility = ["//visibility:private"],
)

# Generates a custom_register_class.inc include using the llvm_tablegen
# rule and llvm-tblgen tool.
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

# Example: taking a platform specific libclang shared library
# into account. The example uses automatically defined
# 'copy_local_llvm_shared_<PLATFORM>' dependency to make a copy of the
# libclang library in the 'bazel-bin' directory. On *nix platforms
# the example linked so that to look for the library in the current directory.
# The application reads function declaration and definition from a c/c++ code.
# Usage: cd ./bazel-bin/ && ./clang_list_methods <path to a c/c++ code file>
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

# Example: do nothing, just link a cc-file with all the Clang libraries.
# This example checks the dependency chain for each library.
# Usage: clang_check_dependencies
cc_binary(
    name = 'clang_check_dependencies',
    srcs = [
        "clang/clang_empty_main.cc",
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
        "@local_llvm//:config_headers",
        "@local_llvm//:cl_headers",
        "@local_llvm//:cl_analysis",
        "@local_llvm//:cl_arc_migrate",
        "@local_llvm//:cl_ast",
        "@local_llvm//:cl_ast_matchers",
        "@local_llvm//:cl_basic",
        "@local_llvm//:cl_code_gen",
        "@local_llvm//:cl_cross_tu",
        "@local_llvm//:cl_dependency_scanning",
        "@local_llvm//:cl_directory_watcher",
        "@local_llvm//:cl_driver",
        "@local_llvm//:cl_dynamic_ast_matchers",
        "@local_llvm//:cl_edit",
        "@local_llvm//:cl_format",
        "@local_llvm//:cl_frontend",
        "@local_llvm//:cl_frontend_tool",
        "@local_llvm//:cl_handle_cxx",
        "@local_llvm//:cl_handle_llvm",
        "@local_llvm//:cl_index",
        "@local_llvm//:cl_lex",
        "@local_llvm//:cl_libclang",
        "@local_llvm//:cl_parse",
        "@local_llvm//:cl_rewrite",
        "@local_llvm//:cl_rewrite_frontend",
        "@local_llvm//:cl_sema",
        "@local_llvm//:cl_serialization",
        "@local_llvm//:cl_static_analyzer_checkers",
        "@local_llvm//:cl_static_analyzer_core",
        "@local_llvm//:cl_static_analyzer_frontend",
        "@local_llvm//:cl_tooling",
        "@local_llvm//:cl_tooling_ast_diff",
        "@local_llvm//:cl_tooling_core",
        "@local_llvm//:cl_tooling_inclusions",
        "@local_llvm//:cl_tooling_refactoring",
        "@local_llvm//:cl_tooling_syntax",
        "@local_llvm//:cl_transformer",
    ] + select({
        ":linux_x86_64": ["@local_llvm//:cl_libclang_cpp"],
        ":macos_x86_64": ["@local_llvm//:cl_libclang_cpp"],
        "//conditions:default": [],
    }) + if_cxx_linked([
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

# Example: do nothing, just link a cc-file with all the MLIR libraries.
# This example checks the dependency chain for each library.
# Usage: mlir_check_dependencies
cc_binary(
    name = 'mlir_check_dependencies',
    srcs = [
        "mlir/mlir_empty_main.cc",
    ],
    copts = llvm_copts,
    data = select({
        ":linux_x86_64": [
            "copy_mlir_runner_shared_lin",
        ],
        ":macos_x86_64": [
            "copy_mlir_runner_shared_mac",
        ],
        ":windows_x86_64": [
            "copy_mlir_runner_shared_win",
        ],
        "//conditions:default": [],
    }),
    deps = [
        "@local_llvm//:headers",
        "@local_llvm//:ml_headers",
        "@local_llvm//:ml_affine_ops",
        "@local_llvm//:ml_affine_edsc",
        "@local_llvm//:ml_affine_to_standard",
        "@local_llvm//:ml_affine_transforms",
        "@local_llvm//:ml_affine_transforms_test_passes",
        "@local_llvm//:ml_affine_utils",
        "@local_llvm//:ml_analysis",
        "@local_llvm//:ml_avx512",
        "@local_llvm//:ml_avx512_to_llvm",
        "@local_llvm//:ml_c_runner_utils",
        "@local_llvm//:ml_c_runner_utils_static",
        "@local_llvm//:ml_call_interfaces",
        "@local_llvm//:ml_control_flow_interfaces",
        "@local_llvm//:ml_derived_attribute_op_interface",
        "@local_llvm//:ml_dialect",
        "@local_llvm//:ml_edsc",
        "@local_llvm//:ml_edsc_interface",
        "@local_llvm//:ml_execution_engine",
        "@local_llvm//:ml_gpu",
        "@local_llvm//:ml_gpu_to_gpu_runtime_transforms",
        "@local_llvm//:ml_gpu_to_nvvm_transforms",
        "@local_llvm//:ml_gpu_to_rocdl_transforms",
        "@local_llvm//:ml_gpu_to_spirv_transforms",
        "@local_llvm//:ml_gpu_to_vulkan_transforms",
        "@local_llvm//:ml_infer_type_op_interface",
        "@local_llvm//:ml_ir",
        "@local_llvm//:ml_jit_runner",
        "@local_llvm//:ml_linalg_analysis",
        "@local_llvm//:ml_linalg_edsc",
        "@local_llvm//:ml_linalg_ops",
        "@local_llvm//:ml_linalg_to_llvm",
        "@local_llvm//:ml_linalg_to_spirv_transforms",
        "@local_llvm//:ml_linalg_to_standard",
        "@local_llvm//:ml_linalg_transforms",
        "@local_llvm//:ml_linalg_utils",
        "@local_llvm//:ml_llvm_avx512",
        "@local_llvm//:ml_llvm_ir",
        "@local_llvm//:ml_llvm_ir_transforms",
        "@local_llvm//:ml_loop_analysis",
        "@local_llvm//:ml_loop_like_interface",
        "@local_llvm//:ml_mlir_opt_main",
        "@local_llvm//:ml_nvvm_ir",
        "@local_llvm//:ml_open_mp",
        "@local_llvm//:ml_opt_lib",
        "@local_llvm//:ml_parser",
        "@local_llvm//:ml_pass",
        "@local_llvm//:ml_quant",
        "@local_llvm//:ml_rocdl_ir",
        "@local_llvm//:ml_runner_utils",
        "@local_llvm//:ml_scf",
        "@local_llvm//:ml_scf_to_gpu",
        "@local_llvm//:ml_scf_to_standard",
        "@local_llvm//:ml_scf_transforms",
        "@local_llvm//:ml_sdbm",
        "@local_llvm//:ml_shape",
        "@local_llvm//:ml_side_effect_interfaces",
        "@local_llvm//:ml_spirv",
        "@local_llvm//:ml_spirv_serialization",
        "@local_llvm//:ml_spirv_test_passes",
        "@local_llvm//:ml_spirv_transforms",
        "@local_llvm//:ml_standard_ops",
        "@local_llvm//:ml_standard_ops_transforms",
        "@local_llvm//:ml_standard_to_llvm",
        "@local_llvm//:ml_standard_to_spirv_transforms",
        "@local_llvm//:ml_support",
        "@local_llvm//:ml_target_avx512",
        "@local_llvm//:ml_target_llvm_ir",
        "@local_llvm//:ml_target_llvm_ir_module_translation",
        "@local_llvm//:ml_target_nvvm_ir",
        "@local_llvm//:ml_target_rocdl_ir",
        "@local_llvm//:ml_test_dialect",
        "@local_llvm//:ml_test_ir",
        "@local_llvm//:ml_test_pass",
        "@local_llvm//:ml_test_transforms",
        "@local_llvm//:ml_transforms",
        "@local_llvm//:ml_transform_utils",
        "@local_llvm//:ml_translation",
        "@local_llvm//:ml_vector",
        "@local_llvm//:ml_vector_to_llvm",
        "@local_llvm//:ml_vector_to_scf",
        "@local_llvm//:ml_view_like_interface",
    ]  + if_has_nvptx([
        "@local_llvm//:ml_gpu_to_cuda_transforms",
    ]) + if_cxx_linked([
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

# Copies the libclang and libclang_cpp shared libraries to the
# 'bazel-bin' directory on Linux.
genrule(
    name = "copy_local_llvm_shared_lin",
    srcs = [
        "@local_llvm//:cl_copy_libclang",
        "@local_llvm//:cl_copy_libclang_cpp",
    ],
    outs = [
        "libclang.so.11git",
        "libclang-cpp.so.11git",
    ],
    cmd = """
        cp -f $(location @local_llvm//:cl_copy_libclang) $(@D)/libclang.so.11git
        cp -f $(location @local_llvm//:cl_copy_libclang_cpp) $(@D)/libclang-cpp.so.11git
    """,
    output_to_bindir = 1,
    visibility = ["//visibility:private"],
)

# Copies the libclang and libclang_cpp shared libraries to the
# 'bazel-bin' directory on MacOS X.
genrule(
    name = "copy_local_llvm_shared_mac",
    srcs = [
        "@local_llvm//:cl_copy_libclang",
        "@local_llvm//:cl_copy_libclang_cpp",
    ],
    outs = [
        "libclang.dylib",
        "libclang-cpp.dylib",
    ],
    cmd = """
        cp -f $(location @local_llvm//:cl_copy_libclang) $(@D)
        cp -f $(location @local_llvm//:cl_copy_libclang_cpp) $(@D)
    """,
    output_to_bindir = 1,
    visibility = ["//visibility:private"],
)

# Copies the libclang and llvm-c shared libraries to the
# 'bazel-bin' directory on Windows.
genrule(
    name = "copy_local_llvm_shared_win",
    srcs = [
        "@local_llvm//:cl_copy_libclang",
        "@local_llvm//:copy_c",
    ],
    outs = [
        "libclang.dll",
        "LLVM-C.dll",
    ],
    cmd = """
        cp -f $(location @local_llvm//:cl_copy_libclang) $(@D)
        cp -f $(location @local_llvm//:copy_c) $(@D)
    """,
    output_to_bindir = 1,
    visibility = ["//visibility:private"],
)

# Copies the mlir_runner_utils shared libraries to the
# 'bazel-bin' directory on Linux.
genrule(
    name = "copy_mlir_runner_shared_lin",
    srcs = [
        "@local_llvm//:ml_copy_runner_utils",
        "@local_llvm//:ml_copy_c_runner_utils",
    ],
    outs = [
        "libmlir_runner_utils.so.11git",
        "libmlir_c_runner_utils.so.11git",
    ],
    cmd = """
        cp -f $(location @local_llvm//:ml_copy_runner_utils) $(@D)/libmlir_runner_utils.so.11git
        cp -f $(location @local_llvm//:ml_copy_c_runner_utils) $(@D)/libmlir_c_runner_utils.so.11git
    """,
    output_to_bindir = 1,
    visibility = ["//visibility:private"],
)

# Copies the mlir_runner_utils shared libraries to the
# 'bazel-bin' directory on MacOS X.
genrule(
    name = "copy_mlir_runner_shared_mac",
    srcs = [
        "@local_llvm//:ml_copy_runner_utils",
        "@local_llvm//:ml_copy_c_runner_utils",
    ],
    outs = [
        "libmlir_runner_utils.dylib",
        "libmlir_c_runner_utils.dylib",
    ],
    cmd = """
        cp -f $(location @local_llvm//:ml_copy_runner_utils) $(@D)
        cp -f $(location @local_llvm//:ml_copy_c_runner_utils) $(@D)
    """,
    output_to_bindir = 1,
    visibility = ["//visibility:private"],
)

# Copies the mlir_runner_utils shared libraries to the
# 'bazel-bin' directory on Windows.
genrule(
    name = "copy_mlir_runner_shared_win",
    srcs = [
        "@local_llvm//:ml_copy_runner_utils",
        "@local_llvm//:ml_copy_c_runner_utils",
    ],
    outs = [
        "mlir_runner_utils.dll",
        "mlir_c_runner_utils.dll",
    ],
    cmd = """
        cp -f $(location @local_llvm//:ml_copy_runner_utils) $(@D)
        cp -f $(location @local_llvm//:ml_copy_c_runner_utils) $(@D)
    """,
    output_to_bindir = 1,
    visibility = ["//visibility:private"],
)

# Platform to enable the clang-cl compiler on Windows
platform(
    name = "x64_windows-clang-cl",
    constraint_values = [
        "@platforms//cpu:x86_64",
        "@platforms//os:windows",
        "@bazel_tools//tools/cpp:clang-cl",
    ],
)
