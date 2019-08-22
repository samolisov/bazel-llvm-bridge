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
        linkstatic = None,
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
        linkstatic: if not None, the boolean value will be passed as the value
                    for the linkstatic attribute of the rule
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
        ("    linkstatic = " + ('1' if linkstatic else '0') +
         ",\n" if linkstatic != None else "") +
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

def _llvm_get_config_genrule(
        repository_ctx,
        name,
        config_file_dir,
        config_file_name):
    """Returns a genrule to generate a header with LLVM's config

    Genrule executes the given command and produces the given outputs.

    Args:
        repository_ctx: the repository_ctx object.
        name: rule name.
        config_file_dir: the directory where the header will appear.
        config_file_name: the name of the generated header.
    Returns:
        A genrule target.
    """
    current_dir = repository_ctx.path(".")
    llvm_include_dir = "%s/include" % current_dir
    llvm_library_dir = "%s/lib" % current_dir
    config_file_path = config_file_dir + '/' + config_file_name
    command = ("echo '/* This generated file is for internal use. " +
        "Do not include it from headers. */\n" +
        "#ifdef LLVM_CONFIG_H\n" +
        "#error " + config_file_name + " can only be included once\n" +
        "#else\n" +
        "#define LLVM_CONFIG_H\n" +
        "#define LLVM_INCLUDE_DIR \"" + llvm_include_dir + "\"\n" +
        "#define LLVM_LIBRARY_DIR \"" + llvm_library_dir + "\"\n" +
        "#endif /* LLVM_CONFIG_H */\n' > $@")

    return (
        "genrule(\n" +
        '    name = "' +
        name + '",\n' +
        "    outs = [\n" +
        '        "' + config_file_path + '",' +
        "\n    ],\n" +
        '    cmd = """\n' +
        command +
        '\n    """,\n' +
        ")\n"
    )

def _llvm_get_config_library_rule(
        repository_ctx,
        name,
        config_rule_name,
        config_file_dir):
    """Returns a cc_library to include a generated LLVM config
       header file.

    Args:
        repository_ctx: the repository_ctx object.
        name: rule name.
        config_rule_name: the name of the rule that generates the file.
        config_file_dir: the directory where the header will appear.
    Returns:
        cc_library target that defines the library.
    """
    return _cc_library(
        name = name,
        srcs = [":" + config_rule_name],
        includes = [config_file_dir],
        linkstatic = True
        )

def _llvm_get_shared_lib_genrule(
        repository_ctx,
        name,
        llvm_path,
        shared_library,
        ignore_prefix = False):
    """Returns a genrule to copy a file with the given shared library.

    Args:
        repository_ctx: the repository_ctx object.
        name: rule name.
        llvm_path: a path to a local LLVM installation.
        shared_library: an LLVM shared library file name without extension.
        ignore_prefix: if True, no lib prefix must be added on any host OS.
    Returns:
        A genrule target.
    """
    if _is_windows(repository_ctx):
        library_ext = "dll"
        library_prefix = ""
    else:
        library_ext = "so"
        library_prefix = "lib" if not ignore_prefix else ""
# TODO add a check for MacOS X

    library_file = "%s%s.%s" % (library_prefix, shared_library, library_ext)
    shared_library_path = _norm_path("%s/bin/%s" % (llvm_path, library_file))
    command = 'cp -f "%s" "%s"' % (shared_library_path, "$(@D)")
    return (
        "genrule(\n" +
        '    name = "' +
        name + '",\n' +
        "    outs = [\n" +
        '        "' + library_file + '",' +
        "\n    ],\n" +
        '    cmd = """\n' +
        command +
        '\n    """,\n' +
        "output_to_bindir = 1\n" +
        ")\n"
    )

def _llvm_installed_impl(repository_ctx):
    ctx = repository_ctx
    llvm_path = repository_ctx.os.environ[_LLVM_INSTALL_PREFIX]
    repository_ctx.symlink("%s/include" % llvm_path, "include")
    repository_ctx.symlink("%s/lib" % llvm_path, "lib")
    _tpl(repository_ctx, "BUILD", {
        "%{CLANG_HEADERS_LIB}":
             _llvm_get_include_rule(ctx, "clang_headers", ["clang", "clang-c"]),
        "%{LLVM_HEADERS_LIB}":
            _llvm_get_include_rule(ctx, "llvm_headers", ["llvm", "llvm-c"]),

        "%{CLANG_ANALYSIS_LIB}":
            _llvm_get_library_rule(ctx, "clang_analysis", "clangAnalysis",
                ["clang_ast", "clang_ast_matchers", "clang_basic",
                 "clang_lex", "llvm_support"]),
        "%{CLANG_ARCMIGRATE_LIB}":
            _llvm_get_library_rule(ctx, "clang_arc_migrate", "clangARCMigrate",
                ["clang_ast", "clang_analysis", "clang_basic", "clang_edit",
                 "clang_frontend", "clang_lex", "clang_rewrite", "clang_sema",
                 "clang_serialization", "llvm_support"]),
        "%{CLANG_AST_LIB}":
            _llvm_get_library_rule(ctx, "clang_ast", "clangAST",
                ["clang_basic", "clang_lex", "llvm_binary_format", "llvm_core",
                 "llvm_support"]),
        "%{CLANG_ASTMATCHERS_LIB}":
            _llvm_get_library_rule(ctx, "clang_ast_matchers", "clangASTMatchers",
                ["clang_ast", "clang_basic", "llvm_support"]),
        "%{CLANG_BASIC_LIB}":
            _llvm_get_library_rule(ctx, "clang_basic", "clangBasic",
                ["llvm_core", "llvm_mc", "llvm_support"]),
        "%{CLANG_CODEGEN_LIB}":
            _llvm_get_library_rule(ctx, "clang_code_gen", "clangCodeGen",
                ["clang_analysis", "clang_ast", "clang_ast_matchers",
                 "clang_basic", "clang_frontend", "clang_lex",
                 "clang_serialization", "llvm_analysis", "llvm_bit_reader",
                 "llvm_bit_writer", "llvm_core", "llvm_coroutines",
                 "llvm_coverage", "llvm_ipo", "llvm_ir_reader",
                 "llvm_aggressive_inst_combine", "llvm_inst_combine",
                 "llvm_instrumentation", "llvm_lto", "llvm_linker",
                 "llvm_mc", "llvm_objc_arc_opts", "llvm_object",
                 "llvm_passes", "llvm_profile_data", "llvm_remarks",
                 "llvm_scalar_opts", "llvm_support", "llvm_target",
                 "llvm_transform_utils"]),
        "%{CLANG_CROSSTU_LIB}":
            _llvm_get_library_rule(ctx, "clang_cross_tu", "clangCrossTU",
                ["clang_ast", "clang_analysis", "clang_basic", "clang_edit",
                 "clang_lex", "llvm_support"]),
        "%{CLANG_DEPENDENCYSCANNING_LIB}":
            _llvm_get_library_rule(ctx, "clang_dependency_scanning",
                "clangDependencyScanning",
                ["clang_ast", "clang_basic", "clang_driver", "clang_frontend",
                 "clang_frontend_tool", "clang_lex", "clang_parse",
                 "clang_serialization", "clang_tooling",
                 "llvm_core", "llvm_support"]),
        "%{CLANG_DIRECTORYWATCHER_LIB}":
            _llvm_get_library_rule(ctx, "clang_directory_watcher",
                "clangDirectoryWatcher",
                ["llvm_support"]),
        "%{CLANG_DRIVER_LIB}":
            _llvm_get_library_rule(ctx, "clang_driver", "clangDriver",
                ["clang_basic", "llvm_binary_format", "llvm_option",
                 "llvm_support"]),
        "%{CLANG_DYNAMICASTMATCHERS_LIB}":
            _llvm_get_library_rule(ctx, "clang_dynamic_ast_matchers",
                "clangDynamicASTMatchers",
                ["clang_ast", "clang_ast_matchers", "clang_basic",
                 "llvm_support"]),
        "%{CLANG_EDIT_LIB}":
            _llvm_get_library_rule(ctx, "clang_edit", "clangEdit",
                ["clang_ast", "clang_basic", "clang_lex", "llvm_support"]),
        "%{CLANG_FORMAT_LIB}":
            _llvm_get_library_rule(ctx, "clang_format", "clangFormat",
                ["clang_basic", "clang_lex", "clang_tooling_core",
                 "clang_tooling_inclusions", "llvm_support"]),
        "%{CLANG_FRONTEND_LIB}":
            _llvm_get_library_rule(ctx, "clang_frontend", "clangFrontend",
                ["clang_ast", "clang_basic", "clang_driver", "clang_edit",
                 "clang_lex", "clang_parse", "clang_sema", "clang_serialization",
                 "llvm_bit_reader", "llvm_bitstream_reader", "llvm_option",
                 "llvm_profile_data", "llvm_support"]),
        "%{CLANG_FRONTENDTOOL_LIB}":
            _llvm_get_library_rule(ctx, "clang_frontend_tool", "clangFrontendTool",
                ["clang_basic", "clang_code_gen", "clang_driver", "clang_frontend",
                 "clang_rewrite_frontend", "clang_arc_migrate",
                 "clang_static_analyzer_frontend", "llvm_option", "llvm_support"]),
        "%{CLANG_HANDLECXX_LIB}":
            _llvm_get_library_rule(ctx, "clang_handle_cxx", "clangHandleCXX",
                ["clang_basic", "clang_code_gen", "clang_frontend", "clang_lex",
                 "clang_serialization", "clang_tooling", "llvm_x86_code_gen",
                 "llvm_x86_asm_parser", "llvm_x86_desc", "llvm_x86_disassembler",
                 "llvm_x86_info", "llvm_x86_utils", "llvm_support"]),
        "%{CLANG_HANDLELLVM_LIB}":
            _llvm_get_library_rule(ctx, "clang_handle_llvm", "clangHandleLLVM",
                ["llvm_analysis", "llvm_code_gen", "llvm_core",
                 "llvm_execution_engine", "llvm_ipo", "llvm_ir_reader",
                 "llvm_mc", "llvm_mc_jit", "llvm_object", "llvm_runtime_dy_ld",
                 "llvm_selection_dag", "llvm_support", "llvm_target",
                 "llvm_transform_utils", "llvm_x86_code_gen",
                 "llvm_x86_asm_parser", "llvm_x86_desc",
                 "llvm_x86_disassembler", "llvm_x86_info", "llvm_x86_utils"]),
        "%{CLANG_INDEX_LIB}":
            _llvm_get_library_rule(ctx, "clang_index", "clangIndex",
                ["clang_ast", "clang_basic", "clang_format", "clang_frontend",
                 "clang_lex", "clang_rewrite", "clang_serialization",
                 "clang_tooling_core", "llvm_core", "llvm_support"]),
        "%{CLANG_LEX_LIB}":
            _llvm_get_library_rule(ctx, "clang_lex", "clangLex",
                ["clang_basic", "llvm_support"]),
        "%{CLANG_LIBCLANG_LIB}":
            _llvm_get_library_rule(ctx, "clang_libclang", "libclang"),
        "%{CLANG_LIBCLANG_COPY_GENRULE}":
            _llvm_get_shared_lib_genrule(ctx, "clang_copy_libclang",
                llvm_path, "libclang", ignore_prefix = True),
        "%{CLANG_PARSE_LIB}":
            _llvm_get_library_rule(ctx, "clang_parse", "clangParse",
                ["clang_ast", "clang_basic", "clang_lex", "clang_sema",
                 "llvm_mc", "llvm_mc_parser", "llvm_support"]),
        "%{CLANG_REWRITE_LIB}":
            _llvm_get_library_rule(ctx, "clang_rewrite", "clangRewrite",
                ["clang_basic", "clang_lex", "llvm_support"]),
        "%{CLANG_REWRITEFRONTEND_LIB}":
            _llvm_get_library_rule(ctx, "clang_rewrite_frontend",
                "clangRewriteFrontend",
                ["clang_ast", "clang_basic", "clang_edit", "clang_frontend",
                 "clang_lex", "clang_rewrite", "clang_serialization",
                 "llvm_support"]),
        "%{CLANG_SEMA_LIB}":
            _llvm_get_library_rule(ctx, "clang_sema", "clangSema",
                ["clang_ast", "clang_analysis", "clang_basic",
                 "clang_edit", "clang_lex", "llvm_support"]),
        "%{CLANG_SERIALIZATION_LIB}":
            _llvm_get_library_rule(ctx, "clang_serialization", "clangSerialization",
                ["clang_ast", "clang_basic", "clang_lex", "clang_sema",
                 "llvm_bit_reader", "llvm_bitstream_reader", "llvm_support"]),
        "%{CLANG_STATICANALYZERCHECKERS_LIB}":
            _llvm_get_library_rule(ctx, "clang_static_analyzer_checkers",
                "clangStaticAnalyzerChechers",
                ["clang_ast", "clang_ast_matchers", "clang_analysis", "clang_basic",
                 "clang_lex", "clang_static_analyzer_core", "llvm_support"]),
        "%{CLANG_STATICANALYZERCORE_LIB}":
            _llvm_get_library_rule(ctx, "clang_static_analyzer_core",
                "clangStaticAnalyzerCore",
                ["clang_ast", "clang_ast_matchers", "clang_analysis", "clang_basic",
                 "clang_cross_tu", "clang_frontend", "clang_lex", "clang_rewrite",
                 "llvm_support"]),
        "%{CLANG_STATICANALYZERFRONTEND_LIB}":
            _llvm_get_library_rule(ctx, "clang_static_analyzer_frontend",
                "clangStaticAnalyzerFrontend",
                ["clang_ast", "clang_analysis", "clang_basic", "clang_cross_tu",
                 "clang_frontend", "clang_lex", "clang_static_analyzer_chechers",
                 "clang_static_analyzer_core", "llvm_support"]),
        "%{CLANG_TOOLING_LIB}":
            _llvm_get_library_rule(ctx, "clang_tooling", "clangTooling",
                ["clang_ast", "clang_ast_matchers", "clang_basic", "clang_driver",
                 "clang_format", "clang_frontend", "clang_lex", "clang_rewrite",
                 "clang_serialization", "clang_tooling_core",
                 "llvm_option", "llvm_support"]),
        "%{CLANG_TOOLINGASTDIFF_LIB}":
            _llvm_get_library_rule(ctx, "clang_tooling_ast_diff",
                "clangToolingASTDiff",
                ["clang_ast", "clang_basic", "clang_lex", "llvm_support"]),
        "%{CLANG_TOOLINGCORE_LIB}":
            _llvm_get_library_rule(ctx, "clang_tooling_core", "clangToolingCore",
                ["clang_ast", "clang_basic", "clang_lex", "clang_rewrite",
                 "llvm_support"]),
        "%{CLANG_TOOLINGINCLUSIONS_LIB}":
            _llvm_get_library_rule(ctx, "clang_tooling_inclusions",
                "clangToolingInclusions",
                ["clang_basic", "clang_lex", "clang_rewrite",
                 "clang_tooling_core", "llvm_support"]),
        "%{CLANG_TOOLINGREFACTORING_LIB}":
            _llvm_get_library_rule(ctx, "clang_tooling_refactoring",
                "clangToolingRefactoring",
                ["clang_ast", "clang_ast_matchers", "clang_basic", "clang_format",
                 "clang_index", "clang_lex", "clang_rewrite",
                 "clang_tooling_core", "llvm_support"]),
        "%{CLANG_TOOLINGSYNTAX_LIB}":
            _llvm_get_library_rule(ctx, "clang_tooling_syntax", "clangToolingSyntax",
                ["clang_ast", "clang_basic", "clang_frontend", "clang_lex",
                 "clang_tooling_core", "llvm_support"]),

        "%{LLVM_AGGRESSIVEINSTCOMBINE_LIB}":
            _llvm_get_library_rule(ctx, "llvm_aggressive_inst_combine",
                "LLVMAggressiveInstCombine",
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
        "%{LLVM_C_COPY_GENRULE}":
            _llvm_get_shared_lib_genrule(ctx, "llvm_copy_c", llvm_path, "LLVM-C"),
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
        "%{LLVM_CONFIG_GENRULE}":
            _llvm_get_config_genrule(ctx, "llvm_config_files", "generated/include",
                "llvm_config.h"),
        "%{LLVM_CONFIG_LIB}":
            _llvm_get_config_library_rule(ctx, "llvm_config_headers", "llvm_config_files",
                "generated/include"),
    })

llvm_configure = repository_rule(
    implementation = _llvm_installed_impl,
    environ = [
        _LLVM_INSTALL_PREFIX,
    ],
)
