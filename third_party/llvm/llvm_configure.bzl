"""Setup LLVM and Clang as external dependencies

   The file has been adopted for a local LLVM (and, optionally, Clang)
   installation.

   Some methods have been borrowed from the NGraph-Tensorflow bridge:
   https://github.com/tensorflow/ngraph-bridge/blob/master/bazel/tf_configure/tf_configure.bzl
"""

_LLVM_INSTALL_PREFIX = "LLVM_INSTALL_PREFIX"

def _tpl(repository_ctx, tpl, substitutions = {}, out = None):
    """Generate a build file for bazel based upon the `tpl` template."""
    if not out:
        out = tpl
    repository_ctx.template(
        out,
        Label("//third_party/llvm:%s.tpl" % tpl),
        substitutions,
    )

def _fail(msg):
    """Output failure message when auto configuration fails."""
    red = "\033[0;31m"
    no_color = "\033[0m"
    fail("%sPython Configuration Error:%s %s\n" % (red, no_color, msg))

def _is_windows(repository_ctx):
    """Returns true if the host operating system is Windows."""
    os_name = repository_ctx.os.name.lower()
    return os_name.find("windows") != -1

def _execute(
        repository_ctx,
        cmdline,
        error_msg = None,
        error_details = None,
        empty_stdout_fine = False):
    """Executes an arbitrary shell command.

    Helper for executes an arbitrary shell command.

    Args:
      repository_ctx: the repository_ctx object.
      cmdline: list of strings, the command to execute.
      error_msg: string, a summary of the error if the command fails.
      error_details: string, details about the error or steps to fix it.
      empty_stdout_fine: bool, if True, an empty stdout result is fine, otherwise
        it's an error.

    Returns:
      The result of repository_ctx.execute(cmdline).
    """
    result = repository_ctx.execute(cmdline)
    if result.stderr or not (empty_stdout_fine or result.stdout):
        _fail("\n".join([
            error_msg.strip() if error_msg else "Repository command failed",
            result.stderr.strip(),
            error_details if error_details else "",
        ]))
    return result

def _read_dir(repository_ctx, src_dir):
    """Returns a string with all files in a directory.

    Finds all files inside a directory, traversing subfolders and following
    symlinks. The returned string contains the full path of all files
    separated by line breaks.

    Args:
        repository_ctx: the repository_ctx object.
        src_dir: directory to find files from.

    Returns:
        A string of all files inside the given dir.
    """
    if _is_windows(repository_ctx):
        src_dir = src_dir.replace("/", "\\")
        find_result = _execute(
            repository_ctx,
            ["cmd.exe", "/c", "dir", src_dir, "/b", "/s", "/a-d"],
            empty_stdout_fine = True,
        )
        # src_files could be used in genrule.outs where the paths must
        # use forward slashes.
        result = find_result.stdout.replace("\\", "/")
    else:
        find_result = _execute(
            repository_ctx,
            ["find", src_dir, "-follow", "-type", "f"],
            empty_stdout_fine = True,
        )
        result = find_result.stdout
    return result

def _norm_path(path):
    """Returns a path with '/' and remove the trailing slash."""
    path = path.replace("\\", "/")
    if path[-1] == "/":
        path = path[:-1]
    return path

def _file_is_allowed(file_name, exts):
    """Returns true if the extension of 'file_name' is in the 'exts' list
       of allowed extensions. Allowed extensions must start from '.'.
    """
    for ext in exts:
        if file_name.endswith(ext):
            return True
    return False

def _cc_library(
        name,
        srcs,
        includes = [],
        deps = [],
        visibility = None):
    """Returns a string with a cc_library rule.
    cc_library defines a library with the given sources, optional dependencies,
    and visibility. If the library is a header library, an optional attribute
    'includes' can be specified.

    Args:
        name: A unique name for cc_library.
        srcs: A list of source files that form the library.
        includes: names of include directories to be added to the compile line.
        deps: names of other libraries to be linked in.
        visibility: the value of the 'visibility' attribute of the rule.
    Returns:
        A cc_library target
    """
    fmt_srcs = []
    for src in srcs:
        fmt_srcs.append('        "' + src + '",')

    fmt_includes = []
    for include in includes:
        fmt_includes.append('        "' + include + '",')

    fmt_deps = []
    for dep in deps:
        fmt_deps.append('        "' + dep + '",')

    return (
        "cc_library(\n" +
        '    name = "' + name + '",\n' +
        "    srcs = [\n" +
        "\n".join(fmt_srcs) +
        "\n    ],\n" +
        ("    includes = [\n" +
         "\n".join(fmt_includes) +
        "\n    ],\n" if len(fmt_includes) > 0 else "") +
        ("    deps = [\n" +
         "\n".join(fmt_deps) +
        "\n    ],\n" if len(fmt_deps) > 0 else "") +
        ('    visibility = ["' + visibility + '"],\n'
            if visibility else "") +
        ")\n"
    )

def _get_library_for_dirs(
        repository_ctx,
        name,
        src_dirs,
        allowed_exts = [],
        includes = [],
        deps = []):
    """Returns a cc_library that includes all files from the given list
       of directories.

    Args:
        repository_ctx: the repository_ctx object.
        name: rule name.
        src_dirs: names of directories files from which to be added to
                  the 'srcs' attribute of the generated target.
        allowed_exts: expected extensions of files from the src_dirs. Only files
                  with allowed extensions will be included into the 'srcs'
                  attribute of the target.
        includes: names of include directories to be added to the compile line.
        deps: names of other libraries to be linked in.
    Returns:
        cc_library target that defines the library.
    """
    # define all the allowed Bazel cc_library srcs extensions
    if not allowed_exts or len(allowed_exts) == 0:
        allowed_exts = [".cc", ".cpp", ".cxx", ".c++", ".C", ".c", ".h", ".hh",
                        ".hpp", ".ipp", ".hxx", ".h++", ".inc", ".inl", ".tlh",
                        ".tli", ".H", ".S", ".s", ".asm", ".a", ".lib", ".pic.a",
                        ".lo", ".lo.lib", ".pic.lo", ".so", ".dylib", ".dll", ".o",
                        ".obj", ".pic.o"]
    srcs = []
    for src_dir in src_dirs:
        src_dir = _norm_path(src_dir)
        files = sorted(_read_dir(repository_ctx, src_dir).splitlines())
        # Create a list with the src_dir stripped to use for srcs.
        for current_file in files:
            src_file = current_file[current_file.find(src_dir):]
            if src_file != "" and _file_is_allowed(src_file, allowed_exts):
                srcs.append(src_file)
    return _cc_library(
        name,
        srcs,
        includes,
        deps)

def _llvm_get_include_rule(
        repository_ctx,
        name,
        include_local_dirs):
    """Returns a cc_library to include an LLVM header directory

    Args:
        repository_ctx: the repository_ctx object.
        name: rule name.
        include_local_dirs: names of local directories inside the 'include' one
                            of the local LLVM installation.
    Returns:
        cc_library target that defines the header library.
    """
    llvm_include_dirs = []
    for include_local_dir in include_local_dirs:
        llvm_include_dir = "include/%s" % include_local_dir
        if repository_ctx.path(llvm_include_dir).exists:
            llvm_include_dirs.append(llvm_include_dir)
    if len(llvm_include_dirs) > 0:
        llvm_include_rule = _get_library_for_dirs(
            repository_ctx,
            name,
            llvm_include_dirs,
            [".h", ".inc"],
            ["include"]
        )
    else:
        llvm_include_rule = "# directories '%s' are not found inside\
 'include'.\n" % ", ".join(include_local_dirs)

    return llvm_include_rule

def _llvm_get_library_rule(
        repository_ctx,
        name,
        llvm_library_file,
        deps = []):
    """Returns a cc_library to include an LLVM library with dependencies

    Args:
        repository_ctx: the repository_ctx object.
        name: rule name.
        llvm_library_file: an LLVM library file name without extension.
        deps: names of cc_library targets this one depends on.
    Returns:
        cc_library target that defines the library.
    """
    if _is_windows(repository_ctx):
        library_ext = "lib"
        library_prefix = ""
    else:
        library_ext = "a"
        library_prefix = "lib"
# TODO add a check for MacOS X
    library_file = "lib/%s%s.%s" % (library_prefix, llvm_library_file, library_ext)
    if repository_ctx.path(library_file).exists:
        llvm_library_rule = _cc_library(
            name = name,
            srcs = [library_file],
            deps = deps,
            )
    else:
        llvm_library_rule = "# file '%s' is not found.\n" % library_file
    return llvm_library_rule

def _llvm_installed_impl(repository_ctx):
    ctx = repository_ctx
    llvm_path = repository_ctx.os.environ[_LLVM_INSTALL_PREFIX]
    repository_ctx.symlink("%s/include" % llvm_path, "include")
    repository_ctx.symlink("%s/lib" % llvm_path, "lib")
    _tpl(repository_ctx, "BUILD", {
        "%{LLVM_HEADERS_LIB}":
            _llvm_get_include_rule(ctx, "llvm_headers", ["llvm", "llvm-c"]),

        "%{LLVM_AGGRESSIVEINSTCOMBINE_LIB}":
            _llvm_get_library_rule(ctx, "llvm_aggressive_inst_combine", "LLVMAggressiveInstCombine",
                ["llvm_analysis", "llvm_core", "llvm_support", "llvm_transform_utils"]),
        "%{LLVM_ANALYSIS_LIB}":
            _llvm_get_library_rule(ctx, "llvm_analysis", "LLVMAnalysis",
                ["llvm_binary_format", "llvm_core", "llvm_object", "llvm_profile_data",
                 "llvm_support"]),
        "%{LLVM_ASMPRARSER_LIB}":
            _llvm_get_library_rule(ctx, "llvm_asm_parser", "LLVMAsmParser",
                ["llvm_binary_format", "llvm_core", "llvm_support"]),
        "%{LLVM_ASMPRINTER_LIB}":
            _llvm_get_library_rule(ctx, "llvm_asm_printer", "LLVMAsmPrinter",
                ["llvm_analysis", "llvm_binary_format", "llvm_code_gen", "llvm_core",
                 "llvm_debug_info_codeview", "llvm_debug_info_dwarf", "llvm_debug_info_msf",
                 "llvm_mc", "llvm_mc_parser", "llvm_remarks", "llvm_support", "llvm_target"]),
        "%{LLVM_BINARYFORMAT_LIB}":
            _llvm_get_library_rule(ctx, "llvm_binary_format", "LLVMBinaryFormat",
                ["llvm_support"]),
        "%{LLVM_BITREADER_LIB}":
            _llvm_get_library_rule(ctx, "llvm_bit_reader", "LLVMBitReader",
                ["llvm_bitstream_reader", "llvm_core", "llvm_support"]),
        "%{LLVM_BITWRITER_LIB}":
            _llvm_get_library_rule(ctx, "llvm_bit_writer", "LLVMBitWriter",
                ["llvm_analysis", "llvm_core", "llvm_mc", "llvm_object", "llvm_support"]),
        "%{LLVM_BITSTREAMREADER_LIB}":
            _llvm_get_library_rule(ctx, "llvm_bitstream_reader", "LLVMBitstreamReader",
                ["llvm_support"]),
        "%{LLVM_C_LIB}":
            _llvm_get_library_rule(ctx, "llvm_c", "LLVM-C"),
        "%{LLVM_CODEGEN_LIB}":
            _llvm_get_library_rule(ctx, "llvm_code_gen", "LLVMCodeGen",
                ["llvm_analysis", "llvm_bit_reader", "llvm_bit_writer", "llvm_core",
                 "llvm_mc", "llvm_profile_data", "llvm_scalar_opts", "llvm_support",
                 "llvm_target", "llvm_transform_utils"]),
        "%{LLVM_CORE_LIB}":
            _llvm_get_library_rule(ctx, "llvm_core", "LLVMCore",
                ["llvm_binary_format", "llvm_remarks", "llvm_support"]),
        "%{LLVM_COROUTINES_LIB}":
            _llvm_get_library_rule(ctx, "llvm_coroutines", "LLVMCoroutines",
                ["llvm_analysis", "llvm_core", "llvm_scalar_opts", "llvm_support",
                 "llvm_transform_utils", "llvm_ipo"]),
        "%{LLVM_COVERAGE_LIB}":
            _llvm_get_library_rule(ctx, "llvm_coverage", "LLVMCoverage",
                ["llvm_core", "llvm_object", "llvm_profile_data", "llvm_support"]),
        "%{LLVM_DEBUGINFOCODEVIEW_LIB}":
            _llvm_get_library_rule(ctx, "llvm_debug_info_codeview", "LLVMDebugInfoCodeView",
                ["llvm_debug_info_msf", "llvm_support"]),
        "%{LLVM_DEBUGINFODWARF_LIB}":
            _llvm_get_library_rule(ctx, "llvm_debug_info_dwarf", "LLVMDebugInfoDWARF",
                ["llvm_binary_format", "llvm_mc", "llvm_object", "llvm_support"]),
        "%{LLVM_DEBUGINFOGSYM_LIB}":
            _llvm_get_library_rule(ctx, "llvm_debug_info_gsym", "LLVMDebugInfoGSYM",
                ["llvm_support"]),
        "%{LLVM_DEBUGINFOMSF_LIB}":
            _llvm_get_library_rule(ctx, "llvm_debug_info_msf", "LLVMDebugInfoMSF",
                ["llvm_support"]),
        "%{LLVM_DEBUGINFOPDB_LIB}":
            _llvm_get_library_rule(ctx, "llvm_debug_info_pdb", "LLVMDebugInfoPDB",
                ["llvm_debug_info_codeview", "llvm_debug_info_msf", "llvm_object",
                 "llvm_support"]),
        "%{LLVM_DEMANGLE_LIB}":
            _llvm_get_library_rule(ctx, "llvm_demangle", "LLVMDemangle"),
        "%{LLVM_DLLTOOLDRIVER_LIB}":
            _llvm_get_library_rule(ctx, "llvm_dll_tool_driver", "LLVMDlltoolDriver",
                ["llvm_object", "llvm_option", "llvm_support"]),
        "%{LLVM_EXECUTION_ENGINE_LIB}":
            _llvm_get_library_rule(ctx, "llvm_execution_engine", "LLVMExecutionEngine",
                ["llvm_core", "llvm_mc", "llvm_object", "llvm_runtime_dy_ld",
                 "llvm_support", "llvm_target"]),
        "%{LLVM_FUZZMUTATE_LIB}":
            _llvm_get_library_rule(ctx, "llvm_fuzz_mutate", "LLVMFuzzMutate",
                ["llvm_analysis", "llvm_bit_reader", "llvm_bit_writer", "llvm_core",
                 "llvm_scalar_opts", "llvm_support", "llvm_target"]),
        "%{LLVM_GLOBALISEL_LIB}":
            _llvm_get_library_rule(ctx, "llvm_global_isel", "LLVMGlobalISel",
                ["llvm_analysis", "llvm_code_gen", "llvm_core", "llvm_mc",
                 "llvm_selection_dag", "llvm_support", "llvm_target",
                 "llvm_transform_utils"]),
        "%{LLVM_INSTCOMBINE_LIB}":
            _llvm_get_library_rule(ctx, "llvm_inst_combine", "LLVMInstCombine",
                ["llvm_analysis", "llvm_core", "llvm_support", "llvm_transform_utils"]),
        "%{LLVM_INSTRUMENTATION_LIB}":
            _llvm_get_library_rule(ctx, "llvm_instrumentation", "LLVMInstrumentation",
                ["llvm_analysis", "llvm_core", "llvm_mc", "llvm_profile_data",
                 "llvm_support", "llvm_transform_utils"]),
        "%{LLVM_INTERPRETER_LIB}":
            _llvm_get_library_rule(ctx, "llvm_interpreter", "LLVMInterpreter",
                ["llvm_code_gen", "llvm_core", "llvm_execution_engine", "llvm_support"]),
        "%{LLVM_IRPARSER_LIB}":
            _llvm_get_library_rule(ctx, "llvm_ir_parser", "LLVMMIRParser",
                ["llvm_asm_parser", "llvm_binary_format", "llvm_code_gen", "llvm_core",
                 "llvm_mc", "llvm_support", "llvm_target"]),
        "%{LLVM_IRREADER_LIB}":
            _llvm_get_library_rule(ctx, "llvm_ir_reader", "LLVMIRReader",
                ["llvm_asm_parser", "llvm_bit_reader", "llvm_core", "llvm_support"]),
        "%{LLVM_IPO_LIB}":
            _llvm_get_library_rule(ctx, "llvm_ipo", "LLVMipo",
                ["llvm_aggressive_inst_combine", "llvm_analysis", "llvm_bit_reader",
                 "llvm_bit_writer", "llvm_core", "llvm_ir_reader", "llvm_inst_combine",
                 "llvm_instrumentation", "llvm_linker", "llvm_object", "llvm_profile_data",
                 "llvm_scalar_opts", "llvm_support", "llvm_transform_utils",
                 "llvm_vectorize"]),
        "%{LLVM_JITLINK_LIB}":
            _llvm_get_library_rule(ctx, "llvm_jit_link", "LLVMJITLink",
                ["llvm_binary_format", "llvm_object", "llvm_support"]),
        "%{LLVM_LIBDRIVER_LIB}":
            _llvm_get_library_rule(ctx, "llvm_lib_driver", "LLVMLibDriver",
                ["llvm_binary_format", "llvm_bit_reader", "llvm_object",
                 "llvm_option", "llvm_support"]),
        "%{LLVM_LINEEDITOR_LIB}":
            _llvm_get_library_rule(ctx, "llvm_line_editor", "LLVMLineEditor",
                ["llvm_support"]),
        "%{LLVM_LINKER_LIB}":
            _llvm_get_library_rule(ctx, "llvm_linker", "LLVMLinker",
                ["llvm_core", "llvm_support", "llvm_transform_utils"]),
        "%{LLVM_LTO_LIB}":
            _llvm_get_library_rule(ctx, "llvm_lto", "LLVMLTO",
                ["llvm_aggressive_inst_combine", "llvm_analysis", "llvm_bit_reader",
                 "llvm_bit_writer", "llvm_code_gen", "llvm_core", "llvm_inst_combine",
                 "llvm_linker", "llvm_mc", "llvm_objc_arc_opts", "llvm_object",
                 "llvm_passes", "llvm_remarks", "llvm_scalar_opts", "llvm_support",
                 "llvm_target", "llvm_transform_utils", "llvm_ipo"]),
        "%{LLVM_MC_LIB}":
            _llvm_get_library_rule(ctx, "llvm_mc", "LLVMMC",
                ["llvm_binary_format", "llvm_debug_info_codeview", "llvm_support"]),
        "%{LLVM_MCA_LIB}":
            _llvm_get_library_rule(ctx, "llvm_mca", "LLVMMCA",
                ["llvm_mc", "llvm_support"]),
        "%{LLVM_MCJIT_LIB}":
            _llvm_get_library_rule(ctx, "llvm_mc_jit", "LLVMMCJIT",
                ["llvm_core", "llvm_execution_engine", "llvm_object", "llvm_runtime_dy_ld",
                 "llvm_support", "llvm_target"]),
        "%{LLVM_MCPARSER_LIB}":
            _llvm_get_library_rule(ctx, "llvm_mc_parser", "LLVMMCParser",
                ["llvm_mc", "llvm_support"]),
        "%{LLVM_MCDISASSEMBLER_LIB}":
            _llvm_get_library_rule(ctx, "llvm_mc_disassembler", "LLVMMCDisassembler",
                ["llvm_mc", "llvm_support"]),
        "%{LLVM_OBJCARCOPTS_LIB}":
            _llvm_get_library_rule(ctx, "llvm_objc_arc_opts", "LLVMObjCARCOpts",
                ["llvm_analysis", "llvm_core", "llvm_support", "llvm_transform_utils"]),
        "%{LLVM_OBJECT_LIB}":
            _llvm_get_library_rule(ctx, "llvm_object", "LLVMObject",
                ["llvm_binary_format", "llvm_bit_reader", "llvm_core", "llvm_mc",
                 "llvm_mc_parser", "llvm_support"]),
       "%{LLVM_OBJECTYAML_LIB}":
            _llvm_get_library_rule(ctx, "llvm_object_yaml", "LLVMObjectYAML",
                ["llvm_debug_info_codeview", "llvm_object", "llvm_support"]),
       "%{LLVM_OPTION_LIB}":
            _llvm_get_library_rule(ctx, "llvm_option", "LLVMOption",
                ["llvm_support"]),
       "%{LLVM_ORCJIT_LIB}":
            _llvm_get_library_rule(ctx, "llvm_orc_jit", "LLVMOrcJIT",
                ["llvm_core", "llvm_execution_engine", "llvm_jit_link", "llvm_mc",
                 "llvm_object", "llvm_runtime_dy_ld", "llvm_support", "llvm_target",
                 "llvm_transform_utils"]),
        "%{LLVM_PASSES_LIB}":
            _llvm_get_library_rule(ctx, "llvm_passes", "LLVMPasses",
                ["llvm_aggressive_inst_combine", "llvm_analysis", "llvm_code_gen",
                 "llvm_core", "llvm_inst_combine", "llvm_instrumentation",
                 "llvm_scalar_opts", "llvm_support", "llvm_target", "llvm_transform_utils",
                 "llvm_vectorize", "llvm_ipo"]),
        "%{LLVM_PROFILEDATA_LIB}":
            _llvm_get_library_rule(ctx, "llvm_profile_data", "LLVMProfileData",
                ["llvm_core", "llvm_support"]),
        "%{LLVM_REMARKS_LIB}":
            _llvm_get_library_rule(ctx, "llvm_remarks", "LLVMRemarks",
                ["llvm_support"]),
        "%{LLVM_RUNTIMEDYLD_LIB}":
            _llvm_get_library_rule(ctx, "llvm_runtime_dy_ld", "LLVMRuntimeDyld",
                ["llvm_mc", "llvm_object", "llvm_support"]),
        "%{LLVM_SCALAROPTS_LIB}":
            _llvm_get_library_rule(ctx, "llvm_scalar_opts", "LLVMScalarOpts",
                ["llvm_aggressive_inst_combine", "llvm_analysis", "llvm_core",
                 "llvm_inst_combine", "llvm_support", "llvm_transform_utils"]),
        "%{LLVM_SELECTIONDAG_LIB}":
            _llvm_get_library_rule(ctx, "llvm_selection_dag", "LLVMSelectionDAG",
                ["llvm_analysis", "llvm_code_gen", "llvm_core", "llvm_mc", "llvm_support",
                 "llvm_target", "llvm_transform_utils"]),
        "%{LLVM_SUPPORT_LIB}":
            _llvm_get_library_rule(ctx, "llvm_support", "LLVMSupport",
                ["llvm_demangle"]),
        "%{LLVM_SYMBOLIZE_LIB}":
            _llvm_get_library_rule(ctx, "llvm_symbolize", "LLVMSymbolize",
                ["llvm_debug_info_dwarf", "llvm_debug_info_pdb", "llvm_demangle",
                 "llvm_object", "llvm_support"]),
        "%{LLVM_TABLEGEN_LIB}":
            _llvm_get_library_rule(ctx, "llvm_table_gen", "LLVMTableGen",
                ["llvm_support"]),
        "%{LLVM_TARGET_LIB}":
            _llvm_get_library_rule(ctx, "llvm_target", "LLVMTarget",
                ["llvm_analysis", "llvm_core", "llvm_mc", "llvm_support"]),
        "%{LLVM_TEXTAPI_LIB}":
            _llvm_get_library_rule(ctx, "llvm_text_api", "LLVMTextAPI",
                ["llvm_binary_format", "llvm_support"]),
        "%{LLVM_TRANSFORMUTILS_LIB}":
            _llvm_get_library_rule(ctx, "llvm_transform_utils", "LLVMTransformUtils",
                ["llvm_analysis", "llvm_core", "llvm_support"]),
        "%{LLVM_VECTORIZE_LIB}":
            _llvm_get_library_rule(ctx, "llvm_vectorize", "LLVMVectorize",
                ["llvm_analysis", "llvm_core", "llvm_support", "llvm_transform_utils"]),
        "%{LLVM_WINDOWS_MANIFEST_LIB}":
            _llvm_get_library_rule(ctx, "llvm_windows_manifest", "LLVMWindowsManifest",
                ["llvm_support"]),
        "%{LLVM_X86ASMPARSER_LIB}":
            _llvm_get_library_rule(ctx, "llvm_x86_asm_parser", "LLVMX86AsmParser",
                ["llvm_mc", "llvm_mc_parser", "llvm_support", "llvm_x86_desc",
                 "llvm_x86_info"]),
        "%{LLVM_X86CODEGEN_LIB}":
            _llvm_get_library_rule(ctx, "llvm_x86_code_gen", "LLVMX86CodeGen",
                ["llvm_analysis", "llvm_asm_printer", "llvm_code_gen", "llvm_core",
                 "llvm_global_isel", "llvm_mc", "llvm_profile_data", "llvm_selection_dag",
                 "llvm_support", "llvm_target", "llvm_x86_desc", "llvm_x86_info",
                 "llvm_x86_utils"]),
        "%{LLVM_X86DESC_LIB}":
            _llvm_get_library_rule(ctx, "llvm_x86_desc", "LLVMX86Desc",
                ["llvm_mc", "llvm_mc_disassembler", "llvm_object", "llvm_support",
                 "llvm_x86_info", "llvm_x86_utils"]),
        "%{LLVM_X86DISASSEMBLER_LIB}":
            _llvm_get_library_rule(ctx, "llvm_x86_disassembler", "LLVMX86Disassembler",
                ["llvm_mc_disassembler", "llvm_support", "llvm_x86_info"]),
        "%{LLVM_X86INFO_LIB}":
            _llvm_get_library_rule(ctx, "llvm_x86_info", "LLVMX86Info",
                ["llvm_support"]),
        "%{LLVM_X86UTILS_LIB}":
            _llvm_get_library_rule(ctx, "llvm_x86_utils", "LLVMX86Utils",
                ["llvm_support"]),
        "%{LLVM_XRAY_LIB}":
            _llvm_get_library_rule(ctx, "llvm_xray", "LLVMXRay",
                ["llvm_object", "llvm_support"]),
    })

llvm_configure = repository_rule(
    implementation = _llvm_installed_impl,
    environ = [
        _LLVM_INSTALL_PREFIX,
    ],
)
