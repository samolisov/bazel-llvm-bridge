package(default_visibility = ["//visibility:public"])

%{CLANG_HEADERS_LIB}
%{CLANG_ANALYSIS_LIB}
%{CLANG_ARCMIGRATE_LIB}
%{CLANG_AST_LIB}
%{CLANG_ASTMATCHERS_LIB}
%{CLANG_BASIC_LIB}
%{CLANG_CODEGEN_LIB}
%{CLANG_CROSSTU_LIB}
%{CLANG_DEPENDENCYSCANNING_LIB}
%{CLANG_DIRECTORYWATCHER_LIB}
%{CLANG_DRIVER_LIB}
%{CLANG_DYNAMICASTMATCHERS_LIB}
%{CLANG_EDIT_LIB}
%{CLANG_FORMAT_LIB}
%{CLANG_FRONTEND_LIB}
%{CLANG_FRONTENDTOOL_LIB}
%{CLANG_HANDLECXX_LIB}
%{CLANG_HANDLELLVM_LIB}
%{CLANG_INDEX_LIB}
%{CLANG_LEX_LIB}
%{CLANG_LIBCLANG_LIB}
%{CLANG_LIBCLANG_COPY_GENRULE}
%{CLANG_LIBCLANGCPP_LIB}
%{CLANG_LIBCLANGCPP_COPY_GENRULE}
%{CLANG_PARSE_LIB}
%{CLANG_REWRITE_LIB}
%{CLANG_REWRITEFRONTEND_LIB}
%{CLANG_SEMA_LIB}
%{CLANG_SERIALIZATION_LIB}
%{CLANG_STATICANALYZERCHECKERS_LIB}
%{CLANG_STATICANALYZERCORE_LIB}
%{CLANG_STATICANALYZERFRONTEND_LIB}
%{CLANG_TOOLING_LIB}
%{CLANG_TOOLINGASTDIFF_LIB}
%{CLANG_TOOLINGCORE_LIB}
%{CLANG_TOOLINGINCLUSIONS_LIB}
%{CLANG_TOOLINGREFACTORING_LIB}
%{CLANG_TOOLINGSYNTAX_LIB}

%{LLVM_HEADERS_LIB}
%{LLVM_AGGRESSIVEINSTCOMBINE_LIB}
%{LLVM_ANALYSIS_LIB}
%{LLVM_ASMPRARSER_LIB}
%{LLVM_ASMPRINTER_LIB}
%{LLVM_BINARYFORMAT_LIB}
%{LLVM_BITREADER_LIB}
%{LLVM_BITWRITER_LIB}
%{LLVM_BITSTREAMREADER_LIB}
%{LLVM_C_LIB}
%{LLVM_C_COPY_GENRULE}
%{LLVM_CODEGEN_LIB}
%{LLVM_CORE_LIB}
%{LLVM_COROUTINES_LIB}
%{LLVM_COVERAGE_LIB}
%{LLVM_DEBUGINFOCODEVIEW_LIB}
%{LLVM_DEBUGINFODWARF_LIB}
%{LLVM_DEBUGINFOGSYM_LIB}
%{LLVM_DEBUGINFOMSF_LIB}
%{LLVM_DEBUGINFOPDB_LIB}
%{LLVM_DEMANGLE_LIB}
%{LLVM_DLLTOOLDRIVER_LIB}
%{LLVM_EXECUTION_ENGINE_LIB}
%{LLVM_FUZZMUTATE_LIB}
%{LLVM_GLOBALISEL_LIB}
%{LLVM_INSTCOMBINE_LIB}
%{LLVM_INSTRUMENTATION_LIB}
%{LLVM_INTERPRETER_LIB}
%{LLVM_IRREADER_LIB}
%{LLVM_IPO_LIB}
%{LLVM_JITLINK_LIB}
%{LLVM_LIBDRIVER_LIB}
%{LLVM_LINEEDITOR_LIB}
%{LLVM_LINKER_LIB}
%{LLVM_LTO_LIB}
%{LLVM_MC_LIB}
%{LLVM_MCA_LIB}
%{LLVM_MCJIT_LIB}
%{LLVM_MCPARSER_LIB}
%{LLVM_MCDISASSEMBLER_LIB}
%{LLVM_MIRPARSER_LIB}
%{LLVM_OBJCARCOPTS_LIB}
%{LLVM_OBJECT_LIB}
%{LLVM_OBJECTYAML_LIB}
%{LLVM_OPTION_LIB}
%{LLVM_ORCJIT_LIB}
%{LLVM_PASSES_LIB}
%{LLVM_PROFILEDATA_LIB}
%{LLVM_REMARKS_LIB}
%{LLVM_RUNTIMEDYLD_LIB}
%{LLVM_SCALAROPTS_LIB}
%{LLVM_SELECTIONDAG_LIB}
%{LLVM_SUPPORT_LIB}
%{LLVM_SYMBOLIZE_LIB}
%{LLVM_TABLEGEN_LIB}
%{LLVM_TARGET_LIB}
%{LLVM_TEXTAPI_LIB}
%{LLVM_TRANSFORMUTILS_LIB}
%{LLVM_VECTORIZE_LIB}
%{LLVM_WINDOWS_MANIFEST_LIB}
%{LLVM_XRAY_LIB}
%{LLVM_AARCH64_ASMPARSER_LIB}
%{LLVM_AARCH64_CODEGEN_LIB}
%{LLVM_AARCH64_DESC_LIB}
%{LLVM_AARCH64_DISASSEMBLER_LIB}
%{LLVM_AARCH64_INFO_LIB}
%{LLVM_AARCH64_UTILS_LIB}
%{LLVM_AMDGPU_ASMPARSER_LIB}
%{LLVM_AMDGPU_CODEGEN_LIB}
%{LLVM_AMDGPU_DESC_LIB}
%{LLVM_AMDGPU_DISASSEMBLER_LIB}
%{LLVM_AMDGPU_INFO_LIB}
%{LLVM_AMDGPU_UTILS_LIB}
%{LLVM_ARM_ASMPARSER_LIB}
%{LLVM_ARM_CODEGEN_LIB}
%{LLVM_ARM_DESC_LIB}
%{LLVM_ARM_DISASSEMBLER_LIB}
%{LLVM_ARM_INFO_LIB}
%{LLVM_ARM_UTILS_LIB}
%{LLVM_BPF_ASMPARSER_LIB}
%{LLVM_BPF_CODEGEN_LIB}
%{LLVM_BPF_DESC_LIB}
%{LLVM_BPF_DISASSEMBLER_LIB}
%{LLVM_BPF_INFO_LIB}
%{LLVM_HEXAGON_ASMPARSER_LIB}
%{LLVM_HEXAGON_CODEGEN_LIB}
%{LLVM_HEXAGON_DESC_LIB}
%{LLVM_HEXAGON_DISASSEMBLER_LIB}
%{LLVM_HEXAGON_INFO_LIB}
%{LLVM_LANAI_ASMPARSER_LIB}
%{LLVM_LANAI_CODEGEN_LIB}
%{LLVM_LANAI_DESC_LIB}
%{LLVM_LANAI_DISASSEMBLER_LIB}
%{LLVM_LANAI_INFO_LIB}
%{LLVM_MIPS_ASMPARSER_LIB}
%{LLVM_MIPS_CODEGEN_LIB}
%{LLVM_MIPS_DESC_LIB}
%{LLVM_MIPS_DISASSEMBLER_LIB}
%{LLVM_MIPS_INFO_LIB}
%{LLVM_MSP430_ASMPARSER_LIB}
%{LLVM_MSP430_CODEGEN_LIB}
%{LLVM_MSP430_DESC_LIB}
%{LLVM_MSP430_DISASSEMBLER_LIB}
%{LLVM_MSP430_INFO_LIB}
%{LLVM_NVPTX_CODEGEN_LIB}
%{LLVM_NVPTX_DESC_LIB}
%{LLVM_NVPTX_INFO_LIB}
%{LLVM_POWERPC_ASMPARSER_LIB}
%{LLVM_POWERPC_CODEGEN_LIB}
%{LLVM_POWERPC_DESC_LIB}
%{LLVM_POWERPC_DISASSEMBLER_LIB}
%{LLVM_POWERPC_INFO_LIB}
%{LLVM_RISCV_ASMPARSER_LIB}
%{LLVM_RISCV_CODEGEN_LIB}
%{LLVM_RISCV_DESC_LIB}
%{LLVM_RISCV_DISASSEMBLER_LIB}
%{LLVM_RISCV_INFO_LIB}
%{LLVM_RISCV_UTILS_LIB}
%{LLVM_SPARC_ASMPARSER_LIB}
%{LLVM_SPARC_CODEGEN_LIB}
%{LLVM_SPARC_DESC_LIB}
%{LLVM_SPARC_DISASSEMBLER_LIB}
%{LLVM_SPARC_INFO_LIB}
%{LLVM_SYSTEMZ_ASMPARSER_LIB}
%{LLVM_SYSTEMZ_CODEGEN_LIB}
%{LLVM_SYSTEMZ_DESC_LIB}
%{LLVM_SYSTEMZ_DISASSEMBLER_LIB}
%{LLVM_SYSTEMZ_INFO_LIB}
%{LLVM_WEBASSEMBLY_ASMPARSER_LIB}
%{LLVM_WEBASSEMBLY_CODEGEN_LIB}
%{LLVM_WEBASSEMBLY_DESC_LIB}
%{LLVM_WEBASSEMBLY_DISASSEMBLER_LIB}
%{LLVM_WEBASSEMBLY_INFO_LIB}
%{LLVM_X86_ASMPARSER_LIB}
%{LLVM_X86_CODEGEN_LIB}
%{LLVM_X86_DESC_LIB}
%{LLVM_X86_DISASSEMBLER_LIB}
%{LLVM_X86_INFO_LIB}
%{LLVM_X86_UTILS_LIB}
%{LLVM_XCORE_CODEGEN_LIB}
%{LLVM_XCORE_DESC_LIB}
%{LLVM_XCORE_DISASSEMBLER_LIB}
%{LLVM_XCORE_INFO_LIB}

%{LLVM_CONFIG_GENRULE}
%{LLVM_CONFIG_LIB}

%{Z3_SOLVER_LIB}
