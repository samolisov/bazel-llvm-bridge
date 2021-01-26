package(default_visibility = ["//visibility:public"])

exports_files(["LICENSE.TXT"])

%{CLANG_HEADERS_LIB}
%{CLANG_ANALYSIS_LIB}
%{CLANG_APINOTES_LIB}
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
%{CLANG_INDEXSERIALIZATION_LIB}
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
%{CLANG_TESTING_LIB}
%{CLANG_TOOLING_LIB}
%{CLANG_TOOLINGASTDIFF_LIB}
%{CLANG_TOOLINGCORE_LIB}
%{CLANG_TOOLINGINCLUSIONS_LIB}
%{CLANG_TOOLINGREFACTORING_LIB}
%{CLANG_TOOLINGSYNTAX_LIB}
%{CLANG_TRANSFORMER_LIB}

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
%{LLVM_CFGUARD_LIB}
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
%{LLVM_DWARFLINKER_LIB}
%{LLVM_EXECUTION_ENGINE_LIB}
%{LLVM_EXTENSIONS}
%{LLVM_FILECHECK_LIB}
%{LLVM_FRONTEND_OPENACC_LIB}
%{LLVM_FRONTEND_OPENMP_LIB}
%{LLVM_FUZZMUTATE_LIB}
%{LLVM_GLOBALISEL_LIB}
%{LLVM_INSTCOMBINE_LIB}
%{LLVM_INSTRUMENTATION_LIB}
%{LLVM_INTERFACESTUB_LIB}
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
%{LLVM_MCDISASSEMBLER_LIB}
%{LLVM_MCJIT_LIB}
%{LLVM_MCPARSER_LIB}
%{LLVM_MIRPARSER_LIB}
%{LLVM_OBJCARC_LIB}
%{LLVM_OBJECT_LIB}
%{LLVM_OBJECTYAML_LIB}
%{LLVM_OPTION_LIB}
%{LLVM_ORCJIT_LIB}
%{LLVM_ORCSHARED_LIB}
%{LLVM_ORCTARGETPROCESS_LIB}
%{LLVM_PASSES_LIB}
%{LLVM_PROFILEDATA_LIB}
%{LLVM_REMARKS_LIB}
%{LLVM_RUNTIMEDYLD_LIB}
%{LLVM_SCALAR_LIB}
%{LLVM_SELECTIONDAG_LIB}
%{LLVM_SUPPORT_LIB}
%{LLVM_SYMBOLIZE_LIB}
%{LLVM_TABLEGEN_LIB}
%{LLVM_TABLEGEN_TOOL}
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
%{LLVM_AVR_ASMPARSER_LIB}
%{LLVM_AVR_CODEGEN_LIB}
%{LLVM_AVR_DESC_LIB}
%{LLVM_AVR_DISASSEMBLER_LIB}
%{LLVM_AVR_INFO_LIB}
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
%{LLVM_XCORE_CODEGEN_LIB}
%{LLVM_XCORE_DESC_LIB}
%{LLVM_XCORE_DISASSEMBLER_LIB}
%{LLVM_XCORE_INFO_LIB}
%{LLVM_CONFIG_GENRULE}
%{LLVM_CONFIG_LIB}

%{MLIR_HEADERS_LIB}
%{MLIR_AFFINE_LIB}
%{MLIR_AFFINEEDSC_LIB}
%{MLIR_AFFINETOSTANDARD_LIB}
%{MLIR_AFFINETRANSFORMS_LIB}
%{MLIR_AFFINEUTILS_LIB}
%{MLIR_ANALYSIS_LIB}
%{MLIR_ARMNEON_LIB}
%{MLIR_ARMNEONTOLLVM_LIB}
%{MLIR_ARMSVE_LIB}
%{MLIR_ARMSVETOLLVM_LIB}
%{MLIR_ASYNC_LIB}
%{MLIR_ASYNCRUNTIME_LIB}
%{MLIR_ASYNCRUNTIME_COPY_GENRULE}
%{MLIR_ASYNCTOLLVM_LIB}
%{MLIR_ASYNCTRANSFORMS_LIB}
%{MLIR_AVX512_LIB}
%{MLIR_AVX512TOLLVM_LIB}
%{MLIR_C_RUNNERUTILS_LIB}
%{MLIR_C_RUNNERUTILS_COPY_GENRULE}
%{MLIR_C_RUNNERUTILS_STATIC_LIB}
%{MLIR_CALLINTERFACES_LIB}
%{MLIR_CAPIIR_LIB}
%{MLIR_CAPIREGISTRATION_LIB}
%{MLIR_CAPISTANDARD_LIB}
%{MLIR_CAPITRANSFORMS_LIB}
%{MLIR_CONTROLFLOWINTERFACES_LIB}
%{MLIR_COPYOPINTERFACE_LIB}
%{MLIR_DERIVEDATTRIBUTEOPINTERFACE_LIB}
%{MLIR_DIALECT_LIB}
%{MLIR_EDSC_LIB}
%{MLIR_EXECUTIONENGINE_LIB}
%{MLIR_GPU_LIB}
%{MLIR_GPUTOGPURUNTIMETRANSFORMS_LIB}
%{MLIR_GPUTONVVMTRANSFORMS_LIB}
%{MLIR_GPUTOROCDLTRANSFORMS_LIB}
%{MLIR_GPUTOSPIRV_LIB}
%{MLIR_GPUTOVULKANTRANSFORMS_LIB}
%{MLIR_INFERTYPEOPINTERFACE_LIB}
%{MLIR_IR_LIB}
%{MLIR_JITRUNNER_LIB}
%{MLIR_LINALG_LIB}
%{MLIR_LINALGANALYSIS_LIB}
%{MLIR_LINALGEDSC_LIB}
%{MLIR_LINALGTOLLVM_LIB}
%{MLIR_LINALGTOSPIRV_LIB}
%{MLIR_LINALGTOSTANDARD_LIB}
%{MLIR_LINALGTRANSFORMS_LIB}
%{MLIR_LINALGUTILS_LIB}
%{MLIR_LLVMARMNEON_LIB}
%{MLIR_LLVMARMSVE_LIB}
%{MLIR_LLVMAVX512_LIB}
%{MLIR_LLVMIR_LIB}
%{MLIR_LLVMIRTRANSFORMS_LIB}
%{MLIR_LOOPANALYSIS_LIB}
%{MLIR_LOOPLIKEINTERFACE_LIB}
%{MLIR_MLIROPTMAIN_LIB}
%{MLIR_NVVMIR_LIB}
%{MLIR_OPENACC_LIB}
%{MLIR_OPENMP_LIB}
%{MLIR_OPENMPTOLLVM_LIB}
%{MLIR_OPTLIB_LIB}
%{MLIR_PARSER_LIB}
%{MLIR_PASS_LIB}
%{MLIR_PDL_LIB}
%{MLIR_PDLINTERP_LIB}
%{MLIR_PDLTOPDLINTERP_LIB}
%{MLIR_PRESBURGER_LIB}
%{MLIR_PUBLICAPI_LIB}
%{MLIR_PUBLICAPI_COPY_GENRULE}
%{MLIR_QUANT_LIB}
%{MLIR_REDUCE_LIB}
%{MLIR_REWRITE_LIB}
%{MLIR_ROCDLIR_LIB}
%{MLIR_RUNNERUTILS_LIB}
%{MLIR_RUNNERUTILS_COPY_GENRULE}
%{MLIR_SCF_LIB}
%{MLIR_SCFTOGPU_LIB}
%{MLIR_SCFTOOPENMP_LIB}
%{MLIR_SCFTOSPIRV_LIB}
%{MLIR_SCFTOSTANDARD_LIB}
%{MLIR_SCFTRANSFORMS_LIB}
%{MLIR_SDBM_LIB}
%{MLIR_SHAPE_LIB}
%{MLIR_SHAPEOPSTRANSFORMS_LIB}
%{MLIR_SHAPETOSTANDARD_LIB}
%{MLIR_SIDEEFFECTINTERFACES_LIB}
%{MLIR_SPIRV_LIB}
%{MLIR_SPIRVBINARYUTILS_LIB}
%{MLIR_SPIRVCONVERSION_LIB}
%{MLIR_SPIRVDESERIALIZATION_LIB}
%{MLIR_SPIRVMODULECOMBINER_LIB}
%{MLIR_SPIRVSERIALIZATION_LIB}
%{MLIR_SPIRVTOLLVM_LIB}
%{MLIR_SPIRVTRANSFORMS_LIB}
%{MLIR_SPIRVTRANSLATEREGISTRATION_LIB}
%{MLIR_SPIRVUTILS_LIB}
%{MLIR_STANDARD_LIB}
%{MLIR_STANDARDOPSTRANSFORMS_LIB}
%{MLIR_STANDARDTOLLVM_LIB}
%{MLIR_STANDARDTOSPIRV_LIB}
%{MLIR_SUPPORT_LIB}
%{MLIR_SUPPORTINDENTEDOSTREAM_LIB}
%{MLIR_TABLEGEN_LIB}
%{MLIR_TABLEGEN_TOOL}
%{MLIR_TARGETARMNEON_LIB}
%{MLIR_TARGETARMSVE_LIB}
%{MLIR_TARGETAVX512_LIB}
%{MLIR_TARGETLLVMIR_LIB}
%{MLIR_TARGETLLVMIRMODULETRANSLATION_LIB}
%{MLIR_TARGETNVVMIR_LIB}
%{MLIR_TARGETROCDLIR_LIB}
%{MLIR_TENSOR_LIB}
%{MLIR_TENSORTRANSFORMS_LIB}
%{MLIR_TOSA_LIB}
%{MLIR_TOSATRANSFORMS_LIB}
%{MLIR_TRANSFORMS_LIB}
%{MLIR_TRANSFORMUTILS_LIB}
%{MLIR_TRANSLATION_LIB}
%{MLIR_VECTOR_LIB}
%{MLIR_VECTORTOLLVM_LIB}
%{MLIR_VECTORTOROCDL_LIB}
%{MLIR_VECTORTOSCF_LIB}
%{MLIR_VECTORTOSPIRV_LIB}
%{MLIR_VECTORINTERFACES_LIB}
%{MLIR_VIEWLIKEINTERFACE_LIB}

%{DEBUG_DEP_LIBS}
%{DEP_LIBS}

%{LIBCXX_HEADERS_LIB}
%{LIBCXX_STATIC_LIB}
%{LIBCXX_SHARED_LIB}
%{LIBCXX_SHARED_COPY_GENRULE}
%{LIBCXX_ABI_STATIC_LIB}
%{LIBCXX_ABI_SHARED_LIB}
%{LIBCXX_ABI_SHARED_COPY_GENRULE}
