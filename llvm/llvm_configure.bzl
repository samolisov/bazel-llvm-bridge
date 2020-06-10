"""Setup LLVM and Clang as external dependencies

   The file has been adopted for a local LLVM (and, optionally, Clang)
   installation.

   Some methods have been borrowed from the NGraph-Tensorflow bridge:
   https://github.com/tensorflow/ngraph-bridge/blob/master/bazel/tf_configure/tf_configure.bzl
"""

_LLVM_LICENSE_FILE_PATH = "https://raw.githubusercontent.com/llvm/llvm-project/master/llvm/LICENSE.TXT"
_LLVM_LICENSE_FILE_SHA256 = "8d85c1057d742e597985c7d4e6320b015a9139385cff4cbae06ffc0ebe89afee"
_LLVM_INSTALL_PREFIX = "LLVM_INSTALL_PREFIX"

def _tpl(repository_ctx, tpl, substitutions = {}, out = None):
    """Generate a build file for bazel based upon the `tpl` template."""
    if not out:
        out = tpl
    repository_ctx.template(
        out,
        Label("//llvm:%s.tpl" % tpl),
        substitutions,
    )

def _fail(msg):
    """Output failure message when auto configuration fails."""
    red = "\033[0;31m"
    no_color = "\033[0m"
    fail("%sPython Configuration Error:%s %s\n" % (red, no_color, msg))

def _warn(warning, msg = ""):
    """Output warning message."""
    red = "\033[0;31m"
    no_color = "\033[0m"
    print("%s%s%s %s\n" % (red, warning, no_color, msg))

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

def _static_library_file_params(repository_ctx):
    """Returns a tuple with platform-dependent parameters of
       a static library.

    Args:
        repository_ctx: the repository_ctx object.

    Returns:
        A tuple in the following format:
        - prefix
        - extension
    """

    # TODO add a check for MacOS X
    return ("", "lib") if _is_windows(repository_ctx) else ("lib", "a")


def _executable_file_params(repository_ctx):
    """Returns a tuple with platform-dependent parameters of
       an executable file.

    Args:
        repository_ctx: the repository_ctx object.

    Returns:
        A tuple in the following format:
        - extension
    """

    # TODO add a check for MacOS X
    return (".exe") if _is_windows(repository_ctx) else ("")

def _import_library_file_params(repository_ctx):
    """Returns a tuple with platform-dependent parameters of
       an import library. While on *Nix, an *.so file is an import
       library itself, on Windows a separated .lib file must
       be present.

    Args:
        repository_ctx: the repository_ctx object.

    Returns:
        A tuple in the following format:
        - prefix
        - extension
    """

    # TODO add a check for MacOS X
    return ("", "lib") if _is_windows(repository_ctx) else ("lib", "so")

def _shared_library_file_params(repository_ctx):
    """Returns a tuple with platform-dependent parameters of
       a shared library.

    Args:
        repository_ctx: the repository_ctx object.

    Returns:
        A tuple in the following format:
        - prefix
        - extension
        - directory where to search for the library file.
    """

    # TODO add a check for MacOS X
    return ("", "dll", "bin") if _is_windows(
        repository_ctx) else ("lib", "so", "lib")

def _cc_library(
        name,
        srcs,
        hdrs = [],
        includes = [],
        deps = [],
        copts = [],
        linkopts = [],
        linkstatic = None,
        visibility = None):
    """Returns a string with a cc_library rule.
    cc_library defines a library with the given sources, headers, optional
    dependencies, and visibility. If the library is a header library,
    an optional attribute 'includes' can be specified.

    Args:
        name: A unique name for cc_library.
        srcs: A list of source files that form the library.
        hdrs: A list of header files published by this library to be directly included
              by sources in dependent rules.
        includes: Names of include directories to be added to the compile line.
        deps: Names of other libraries to be linked in.
        copts: Options for the compiler to compile a target, which uses
               this library.
        linkopts: Options for the linker to link this library into a target.
        linkstatic: If not None, the boolean value will be passed as the value
                    for the linkstatic attribute of the rule
        visibility: The value of the 'visibility' attribute of the rule.
    Returns:
        A cc_library target
    """
    fmt_srcs = []
    for src in srcs:
        fmt_srcs.append('        "' + src + '",')

    fmt_hdrs = []
    for hdr in hdrs:
        fmt_hdrs.append('        "' + hdr + '",')

    fmt_includes = []
    for include in includes:
        fmt_includes.append('        "' + include + '",')

    fmt_deps = []
    for dep in deps:
        fmt_deps.append('        "' + dep + '",')

    fmt_copts = []
    for copt in copts:
        fmt_copts.append('        "' + copt + '",')

    fmt_linkopts = []
    for linkopt in linkopts:
        fmt_linkopts.append('        "' + linkopt + '",')

    return (
        "cc_library(\n" +
        '    name = "' + name + '",\n' +
        ("    srcs = [\n" +
         "\n".join(fmt_srcs) +
         "\n    ],\n" if len(fmt_srcs) > 0 else "") +
        ("    hdrs = [\n" +
         "\n".join(fmt_hdrs) +
         "\n    ],\n" if len(fmt_hdrs) > 0 else "") +
        ("    includes = [\n" +
         "\n".join(fmt_includes) +
         "\n    ],\n" if len(fmt_includes) > 0 else "") +
        ("    deps = [\n" +
         "\n".join(fmt_deps) +
         "\n    ],\n" if len(fmt_deps) > 0 else "") +
        ("    copts = [\n" +
         "\n".join(fmt_copts) +
         "\n    ],\n" if len(fmt_copts) > 0 else "") +
        ("    linkopts = [\n" +
         "\n".join(fmt_linkopts) +
         "\n    ],\n" if len(fmt_linkopts) > 0 else "") +
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
        hdr_dirs,
        includes = [],
        deps = [],
        copts = [],
        linkopts = []):
    """Returns a cc_library that includes all files from the given list
       of directories.

    Args:
        repository_ctx: the repository_ctx object.
        name: rule name.
        src_dirs: names of directories files from which to be added to
                  the 'srcs' attribute of the generated target.
        hdr_dirs: names of directories files from which to be added to
                  the 'hdrs' attribute of the generated target.
        includes: names of include directories to be added to the compile line.
        deps: names of other libraries to be linked in.
        copts: options for the compiler to compile a target, which uses
               this library.
        linkopts: options for the linker to link this library into a target.
    Returns:
        cc_library target that defines the library.
    """
    srcs = []
    for src_dir in src_dirs:
        src_dir = _norm_path(src_dir)
        files = sorted(_read_dir(repository_ctx, src_dir).splitlines())
        # Create a list with the src_dir stripped to use for srcs.
        for current_file in files:
            src_file = current_file[current_file.find(src_dir):]
            if src_file != "":
                srcs.append(src_file)
    hdrs = []
    for hdr_dir in hdr_dirs:
        hdr_dir = _norm_path(hdr_dir)
        files = sorted(_read_dir(repository_ctx, hdr_dir).splitlines())
        # Create a list with the src_dir stripped to use for srcs.
        for current_file in files:
            hdr_file = current_file[current_file.find(hdr_dir):]
            if hdr_file != "":
                hdrs.append(hdr_file)
    return _cc_library(
        name,
        srcs,
        hdrs,
        includes,
        deps,
        copts,
        linkopts)


def _symlink_library(
        repository_ctx,
        library_path,
        target):
    """Symlink a library into the bazel building directory. If library path
       is 'some_path/library.ext' and target is 'tgt', the library will be
       symlinked into 'tgt/library.ext'.

    Args:
        repository_ctx: the repository_ctx object.
        library_path: full path to the library file.
        target: the symlink target.
    Returns:
        True if the library is found or False otherwise.
    """

    if repository_ctx.path(library_path).exists:
        file_name = library_path[library_path.rfind("/") + 1:]
        repository_ctx.symlink(library_path, "%s/%s" % (target, file_name))
        return True
    else:
        return False

def _is_ignored(
        library_name,
        ignored):
    """Checks if the library name is in the list of ignored libraries.

    Args:
        library_name: the library name to check
        ignored: the list of ignored libraries
    Returns:
        True if the library is found in the ignored list or False otherwise.
    """
    for ignored_postfix in ignored:
        if library_name.endswith(ignored_postfix):
            return True
    return False

def _is_shared_library(
        repository_ctx,
        library_file):
    """Returns True if the extension of the 'library_file' says it is
       a shared library.

    Args:
        repository_ctx: the repository_ctx object.
        library_file: the library file to check
    Returns:
        True if the library_file is a shared library.
    """
    _, shared_library_ext, _ = _shared_library_file_params(repository_ctx)
    ext = library_file[library_file.rfind(".") + 1:]
    return ext == shared_library_ext

def _llvm_get_rule_name(
        prefix_dict,
        name):
    """Returns a customized name of a rule. When the prefix matches a key
       from 'prefix_dict', the prefix will be replaced with the
       'prefix_dict[key]' value.

    Args:
        prefix_dict: the dictionary of library name prefixes.
        name: rule name.
    Returns:
        customized name when the prefix is replaces with a value from
        'prefix_dict'.
    """
    concat_format = "%s%s"
    for old_prefix, new_prefix in prefix_dict.items():
        if name.startswith(old_prefix):
            return concat_format % (new_prefix, name[len(old_prefix) + 1:])
    return name

def _llvm_get_rule_names(
        prefix_dict,
        names):
    """Returns a list of customized rule names. When the prefix
       of an element of the list matches a key from 'prefix_dict',
       the prefix will be replaced with the 'prefix_dict[key]' value.

    Args:
        prefix_dict: the dictionary of library name prefixes.
        names: list of rule names.
    Returns:
        customized names when the prefix is replaces with a value from
        'prefix_dict'.
    """
    return [_llvm_get_rule_name(prefix_dict, name) for name in names]


def _llvm_check_duplicated_prefixes(prefix_dict):
    """Fails when 'prefix_dict' contains keys with the same
       values.

    Args:
        prefix_dict: the dictionary of library name prefixes.
    """
    for a_key in prefix_dict:
        for b_key in prefix_dict:
            if a_key == b_key:
                break
            if prefix_dict[a_key] == prefix_dict[b_key]:
                _fail("\n".join([
                    "Each component of clang/llvm stack must have a unique prefix.",
                    "Prefixes for '%s' and '%s' are the same." % (a_key, b_key)
                ]))

def _llvm_get_include_rule(
        repository_ctx,
        prefix_dict,
        name,
        include_local_dirs,
        includes = ["include"]):
    """Returns a cc_library to include an LLVM header directory

    Args:
        repository_ctx: the repository_ctx object.
        prefix_dict: the dictionary of library name prefixes.
        name: rule name.
        include_local_dirs: names of local directories inside the 'include' one
                            of the local LLVM installation.
        includes: the value of the 'includes' argument.
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
            _llvm_get_rule_name(prefix_dict, name),
            [],  # LLVM's include is the public interface
            llvm_include_dirs,
            includes
        )
    else:
        llvm_include_rule = "# directories '%s' are not found inside\
 'include'.\n" % ", ".join(include_local_dirs)

    return llvm_include_rule

def _llvm_get_library_rule(
        repository_ctx,
        prefix_dict,
        name,
        llvm_library_file,
        deps = [],
        linkopts = [],
        ignore_prefix = False,
        directory = "lib"):
    """Returns a cc_library to include an LLVM library with dependencies

    Args:
        repository_ctx: the repository_ctx object.
        prefix_dict: the dictionary of library name prefixes.
        name: rule name.
        llvm_library_file: an LLVM library file name without extension.
        deps: names of cc_library targets this one depends on.
        linkopts: options for the linker to link this library into the target.
        ignore_prefix: if True, no lib prefix must be added on any host OS.
        directory: where to search the llvm_library_file, 'lib' by default.
    Returns:
        cc_library target that defines the library.
    """
    library_prefix, library_ext = _static_library_file_params(repository_ctx)
    library_prefix = library_prefix if not ignore_prefix else ""
    library_file = "%s/%s%s.%s" % (directory, library_prefix, llvm_library_file, library_ext)
    if repository_ctx.path(library_file).exists:
        llvm_library_rule = _cc_library(
            name = _llvm_get_rule_name(prefix_dict, name),
            srcs = [library_file],
            deps = _llvm_get_rule_names(prefix_dict, deps),
            linkopts = linkopts,
            )
    else:
        llvm_library_rule = "# file '%s' is not found.\n" % library_file
    return llvm_library_rule

def _llvm_get_shared_library_rule(
        repository_ctx,
        prefix_dict,
        name,
        llvm_library_file,
        deps = [],
        ignore_prefix = False,
        nix_only = False,
        win_only = False,
        directory = "lib"):
    """Returns a cc_library to include an LLVM shared library (or its interface
       library on Windows) with dependencies.

    Args:
        repository_ctx: the repository_ctx object.
        prefix_dict: the dictionary of library name prefixes.
        name: rule name.
        llvm_library_file: an LLVM library file name without extension.
        deps: names of cc_library targets this one depends on.
        ignore_prefix: if True, no lib prefix must be added on any host OS.
        nix_only: the library is available only on *nix systems.
        win_only: the library is available only on Windows.
        directory: where to search the llvm_library_file, 'lib' by default.

    Returns:
        cc_library target that defines the library.
    """
    if _is_windows(repository_ctx) and nix_only:
        return "# library '%s' is available on *Nix only\n" % llvm_library_file
    if not _is_windows(repository_ctx) and win_only:
        return "# library '%s' is available on Windows only\n" % llvm_library_file

    library_prefix, library_ext = _import_library_file_params(repository_ctx)
    library_prefix = library_prefix if not ignore_prefix else ""
    library_file = "%s/%s%s.%s" % (directory, library_prefix, llvm_library_file, library_ext)
    if repository_ctx.path(library_file).exists:
        llvm_library_rule = _cc_library(
            name = _llvm_get_rule_name(prefix_dict, name),
            srcs = [library_file],
            deps = _llvm_get_rule_names(prefix_dict, deps),
            )
    else:
        llvm_library_rule = "# file '%s' is not found.\n" % library_file
    return llvm_library_rule

def _llvm_get_config_genrule(
        repository_ctx,
        prefix_dict,
        name,
        config_file_dir,
        config_file_name):
    """Returns a genrule to generate a header with LLVM's config

    Genrule executes the given command and produces the given outputs.

    Args:
        repository_ctx: the repository_ctx object.
        prefix_dict: the dictionary of library name prefixes.
        name: rule name.
        config_file_dir: the directory where the header will appear.
        config_file_name: the name of the generated header.
    Returns:
        A genrule target.
    """
    current_dir = repository_ctx.path(".")
    llvm_include_dir = "%s/include" % current_dir
    llvm_library_dir = "%s/lib" % current_dir
    clang_include_parent_dir = "%s/clang" % llvm_library_dir
    clang_include_parent_path = repository_ctx.path(clang_include_parent_dir)
    clang_exists = clang_include_parent_path.exists
    if clang_exists:
        clang_subdirs = clang_include_parent_path.readdir()
        if len(clang_subdirs) > 0:
            clang_include_dir = "%s/include" % clang_subdirs[0]
        else:
            clang_exists = False
    config_file_path = config_file_dir + '/' + config_file_name
    command = ("echo '/* This generated file is for internal use. " +
        "Do not include it from headers. */\n" +
        "#ifdef LLVM_BRIDGE_CONFIG_H\n" +
        "#error " + config_file_name + " can only be included once\n" +
        "#else\n" +
        "#define LLVM_BRIDGE_CONFIG_H\n" +
        "#define LLVM_INCLUDE_DIR \"" + llvm_include_dir + "\"\n" +
        "#define LLVM_INCLUDE_COMMAND_ARG \"-I" + llvm_include_dir + "\"\n" +
        "#define LLVM_LIBRARY_DIR \"" + llvm_library_dir + "\"\n" +
        ("#define CLANG_LIB_INCLUDE_DIR \"" + clang_include_dir + "\"\n" +
         "#define CLANG_LIB_INCLUDE_COMMAND_ARG \"-I" + clang_include_dir + "\"\n"
         if clang_exists else "") +
        "#endif /* LLVM_BRIDGE_CONFIG_H */\n' > $@")

    return (
        "genrule(\n" +
        '    name = "' +
        _llvm_get_rule_name(prefix_dict, name) + '",\n' +
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
        prefix_dict,
        name,
        config_rule_name,
        config_file_dir):
    """Returns a cc_library to include a generated LLVM config
       header file.

    Args:
        repository_ctx: the repository_ctx object.
        prefix_dict: the dictionary of library name prefixes.
        name: rule name.
        config_rule_name: the name of the rule that generates the file.
        config_file_dir: the directory where the header will appear.
    Returns:
        cc_library target that defines the library.
    """
    return _cc_library(
        name = _llvm_get_rule_name(prefix_dict, name),
        srcs = [":" + _llvm_get_rule_name(prefix_dict, config_rule_name)],
        includes = [config_file_dir],
        linkstatic = True
        )

def _llvm_get_shared_lib_genrule(
        repository_ctx,
        prefix_dict,
        name,
        llvm_path,
        shared_library,
        ignore_prefix = False,
        nix_only = False,
        win_only = False):
    """Returns a genrule to copy a file with the given shared library.

    Args:
        repository_ctx: the repository_ctx object.
        prefix_dict: the dictionary of library name prefixes.
        name: rule name.
        llvm_path: a path to a local LLVM installation.
        shared_library: an LLVM shared library file name without extension.
        ignore_prefix: if True, no lib prefix must be added on any host OS.
        nix_only: the library is available only on *nix systems.
        win_only: the library is available only on Windows.
    Returns:
        A genrule target.
    """
    if _is_windows(repository_ctx) and nix_only:
        return "# library '%s' is available on *Nix only\n" % shared_library
    if not _is_windows(repository_ctx) and win_only:
        return "# library '%s' is available on Windows only\n" % shared_library

    library_prefix, library_ext, shlib_folder = _shared_library_file_params(
        repository_ctx)
    library_prefix = library_prefix if not ignore_prefix else ""
    library_file = "%s%s.%s" % (library_prefix, shared_library, library_ext)
    shared_library_path = _norm_path("%s/%s/%s" % (llvm_path, shlib_folder,
        library_file))
    command = 'cp -f "%s" "%s"' % (shared_library_path, "$(@D)")
    return (
        "genrule(\n" +
        '    name = "' +
        _llvm_get_rule_name(prefix_dict, name) + '",\n' +
        "    outs = [\n" +
        '        "' + library_file + '",' +
        "\n    ],\n" +
        '    cmd = """\n' +
        command +
        '\n    """,\n' +
        "    output_to_bindir = 1\n" +
        ")\n"
    )

def _llvm_get_executable_file_rule(
        repository_ctx,
        prefix_dict,
        name,
        llvm_executable_file,
        directory = "bin"):
    """Returns a 'filegroup' to make a reference to an executable file

    Args:
        repository_ctx: the repository_ctx object.
        prefix_dict: the dictionary of library name prefixes.
        name: rule name.
        llvm_executable_file: an LLVM executable file name without extension.
        directory: where to search the llvm_executable_file, 'bin' by default.
    Returns:
        filegroup target that defines a reference to the executable file
    """
    ext = _executable_file_params(repository_ctx)
    exec_file = "%s/%s%s" % (directory, llvm_executable_file, ext)
    if repository_ctx.path(exec_file).exists:
        return (
            "filegroup(\n" +
            '    name = "' +
                 _llvm_get_rule_name(prefix_dict, name) + '",\n' +
            "    srcs = [\n" +
            '        "' + exec_file + '",' +
            "\n    ],\n" +
            ")\n"
        )
    else:
        return "# file '%s' is not found.\n" % exec_file

def _llvm_get_linked_libraries(repository_ctx):
    """Returns a tuple of two lists of dependencies: the first one is
       the platform-provided dependencies and should be usied as a value
       of the 'linkopts' rule parameter while the second one is a
       dictionary library_name:library_path - libraries the llvm installation
       is linked against.

       Implementation notes: the method uses the
       "lib/cmake/llvm/LLVMExports.cmake" file and grabs the
       dependencies of the LLVMSupport library excluded all
       started with LLVM. Windows platform-provided libraries
       will be ignored.

    Args:
        repository_ctx: the repository_ctx object.
    Returns:
        ([platform-provided libraries], {library_name : library_path})
    """

    # The algorithm is following: read the export file, read libraries
    # for llvm_support, remove started with LLVM, and convert them into
    # an array of "-l<library>" positions or put into the dictionary.
    skip_linkopts = _is_windows(repository_ctx) # no linkopts on Windows
    ignored_libraries = ["shell32.dll", "ole32.dll"]
    exportpath = repository_ctx.path("lib/cmake/llvm/LLVMExports.cmake")
    if not exportpath.exists:
        return ([], dict())
    config = repository_ctx.read(exportpath)
    libraries_line = ""
    lines = config.splitlines()
    for idx, line in enumerate(lines):
        # looking for dependencies for LLVMSupport
        if line.startswith("set_target_properties(LLVMSupport"):
            if idx + 1 < len(lines):
                libraries_line = lines[idx + 1]
            break

    if len(libraries_line) == 0:
        return ([], dict())
    start = libraries_line.find('"')
    end = libraries_line.find('"', start + 1)
    libraries_line = libraries_line[start + 1:end]
    linkopts = []
    deps = dict()
    for lib in libraries_line.split(";"):
        if lib.startswith("LLVM"): # if LLVM<smth> this is a dependency, no linkopt
            continue
        if lib.find(".") > -1: # there is an extension, so it is no linkopt
            if _is_ignored(lib, ignored_libraries):
                continue
            library_name = lib[lib.rfind("/") + 1:]
            library_name = library_name[:library_name.find(".")]
            deps[library_name] = lib
            continue
        if not skip_linkopts:
            linkopts.append("-l" + lib if not lib.startswith("-l") else lib)

    return (linkopts, deps)

def _llvm_get_debug_linked_libraries(repository_ctx):
    """Returns a list of dependencies in the form of a dictionary
       library_name:library_path - debug specific libraries the
       llvm installation is linked against.

       The function works on Windows only.

       Implementation notes: the method uses the
       "lib/cmake/llvm/LLVMExports.cmake" file and grabs the
       dependencies of the LLVMDebugInfoPDB library excluded all
       started with LLVM.

    Args:
        repository_ctx: the repository_ctx object.
    Returns:
        {library_name : library_path}
    """
    if not _is_windows(repository_ctx):
        return dict()

    # The algorithm is following: read the export file, read libraries
    # for LLVMDebugInfoPDB, remove started with LLVM, and put them
    # into the dictionary.
    exportpath = repository_ctx.path("lib/cmake/llvm/LLVMExports.cmake")
    if not exportpath.exists:
        return dict()
    config = repository_ctx.read(exportpath)
    libraries_line = ""
    lines = config.splitlines()
    for idx, line in enumerate(lines):
        # looking for dependencies for LLVMSupport
        if line.startswith("set_target_properties(LLVMDebugInfoPDB"):
            if idx + 1 < len(lines):
                libraries_line = lines[idx + 1]
            break

    if len(libraries_line) == 0:
        return dict()
    start = libraries_line.find('"')
    end = libraries_line.find('"', start + 1)
    libraries_line = libraries_line[start + 1:end]
    deps = dict()
    for lib in libraries_line.split(";"):
        if lib.startswith("LLVM"): # if LLVM<smth> this is a dependency, no linkopt
            continue
        if lib.find(".") > -1: # there is an extension
            library_name = lib[lib.rfind("/") + 1:]
            library_name = library_name[:library_name.find(".")]
            deps[library_name] = lib
            continue

    return deps

def _llvm_get_installation_options(repository_ctx):
    """Returns a tuple with build options of the LLVM installation:
       whether RTTI and EH are enabled as well as the list of
       supported targets.

       Implementation notes: the method uses the
       "lib/cmake/llvm/LLVMConfig.cmake" file and reads the
       value of the 'LLVM_ENABLE_RTTI', 'LLVM_ENABLE_EH', and
       'LLVM_TARGETS_TO_BUILD' properties.

    Args:
        repository_ctx: the repository_ctx object.
    Returns:
        A tuple with the following LLVM options:
         - The LLVM_ENABLE_RTTI flag,
         - The LLVM_ENABLE_EH flag,
         - A list of targets supported by installation.
    """
    configpath = repository_ctx.path("lib/cmake/llvm/LLVMConfig.cmake")
    if not configpath.exists:
        return []
    config = repository_ctx.read("lib/cmake/llvm/LLVMConfig.cmake")
    targets_line = ""
    rtti_enable_line = ""
    eh_enable_line = ""
    lines = config.splitlines()
    for line in lines:
        if line.startswith("set(LLVM_TARGETS_TO_BUILD"):
            targets_line = line
        elif line.startswith("set(LLVM_ENABLE_RTTI"):
            rtti_enable_line = line
        elif line.startswith("set(LLVM_ENABLE_EH"):
            eh_enable_line = line

        if len(rtti_enable_line) > 0 and len(eh_enable_line) > 0 and len(targets_line) > 0:
            break

    enable_rtti = False
    if len(rtti_enable_line) > 0:
        start = rtti_enable_line.find(' ')
        end = rtti_enable_line.find(')', start + 1)
        enable_rtti = rtti_enable_line[start + 1:end] == 'ON'

    enable_eh = False
    if len(eh_enable_line) > 0:
        start = eh_enable_line.find(' ')
        end = eh_enable_line.find(')', start + 1)
        enable_eh = eh_enable_line[start + 1:end] == 'ON'

    targets = []
    if len(targets_line) > 0:
        start = targets_line.find(' ')
        end = targets_line.find(')', start + 1)
        targets_line = targets_line[start + 1:end]
        targets = targets_line.split(";")

    return (enable_rtti, enable_eh, targets)

def _llvm_get_formatted_target_list(repository_ctx, targets):
    """Returns a list of formatted 'targets': a comma separated list of targets
       ready to insert in a template.

    Args:
        repository_ctx: the repository_ctx object.
        targets: a list of supported targets.
    Returns:
        A formatted list of targets.
    """
    fmt_targets = []
    for target in targets:
        fmt_targets.append('    "' + target + '",')

    return "\n".join(fmt_targets)

def _llvm_local_enabled(repository_ctx):
    """Returns True if a path to a local LLVM installation is passed in
       the '_LLVM_INSTALL_PREFIX' environment variable. Fails if the variable
       is not defined and the 'urls' attribute is empty.

    Args:
        repository_ctx: the repository_ctx object.
    Returns:
        Whether the local LLVM installation must be used.
    """
    enabled = _LLVM_INSTALL_PREFIX in repository_ctx.os.environ
    if not enabled and len(repository_ctx.attr.urls) < 1:
        _fail("\n".join([
            "The 'urls' attribute is empty so that the path to a local LLVM installation",
            "must be assigned to the '%s' environment variable." % _LLVM_INSTALL_PREFIX
        ]))
    return enabled

def _llvm_is_linked_against_cxx(repository_ctx, directory = "lib"):
    """Returns whether the LLVM installation is linked against the libc++
       standard library.

    Args:
        repository_ctx: the repository_ctx object.
        directory: where to search the libc++ files, 'lib' by default.
    Returns:
        True if any of the libc++ binaries presents in the
        local LLVM installation, False otherwise.
    """
    library_files_params = [
        _static_library_file_params(repository_ctx),
        _import_library_file_params(repository_ctx)
    ]

    for library_prefix, library_ext in library_files_params:
        libcxx_file = "%s/%s%s.%s" % (directory, library_prefix, "c++", library_ext)
        if repository_ctx.path(libcxx_file).exists:
            return True

    return False

def _llvm_get_install_path(repository_ctx):
    """Returns a path to a local LLVM installation passed in
       the '_LLVM_INSTALL_PREFIX' environment variable.
       Fails if the variable is not defined or the path doesn't exist.

    Args:
        repository_ctx: the repository_ctx object.
    Returns:
        A path to a local LLVM installation if the path exists otherwise fails.
    """
    if not _LLVM_INSTALL_PREFIX in repository_ctx.os.environ:
        _fail("\n".join([
            "The path to a local LLVM installation must be assigned to",
            "the '%s' environment variable." % _LLVM_INSTALL_PREFIX
        ]))
    llvm_install_path = repository_ctx.os.environ[_LLVM_INSTALL_PREFIX]
    if not repository_ctx.path(llvm_install_path).exists:
        _fail("\n".join([
            "The path to a local LLVM installation",
            "'%s' is not found." % llvm_install_path
        ]))
    return llvm_install_path

def _llvm_symlink_dependencies(repository_ctx):
    """Symlinks dependencies for LLVM and returns a tuple with
       a list of flags for the 'linkopt' parameter and a dictionary
       in the form of ('library name', 'is this is a shared library')
       for the required LLVM dependencies (can be used to form the 'deps'
       attribute). Fails if any dependency is not found on the host.

    Args:
        repository_ctx: the repository_ctx object.
    Returns:
        ([platform-provided libraries], {library_name : True if shared})
        Fails id any dependency is not found on the host.
    """
    llvm_linkopts, llvm_deps = _llvm_get_linked_libraries(repository_ctx)
    llvm_dep_types = dict()
    for dep_lib_name, dep_lib_path in llvm_deps.items():
        linked = _symlink_library(repository_ctx, dep_lib_path, dep_lib_name)
        if not linked:
            _fail("The path to a required dependency '%s' is not found." % dep_lib_path)
        llvm_dep_types[dep_lib_name] = _is_shared_library(repository_ctx,
            dep_lib_path)
    return (llvm_linkopts, llvm_dep_types)

def _llvm_symlink_debug_dependencies(repository_ctx):
    """Symlinks debug specific dependencies for LLVM and returns
       a list of ('library name') for the required debug specific
       LLVM dependencies (e.g. DIA SDK on Windows). Fails if any
       dependency is not found on the host.

    Args:
        repository_ctx: the repository_ctx object.
    Returns:
        list of library names.
        Fails id any dependency is not found on the host.
    """
    llvm_debug_deps = _llvm_get_debug_linked_libraries(repository_ctx)
    llvm_debug_dep_list = []
    for dep_lib_name, dep_lib_path in llvm_debug_deps.items():
        linked = _symlink_library(repository_ctx, dep_lib_path, dep_lib_name)
        if not linked:
            _fail("The path to a required dependency '%s' is not found." % dep_lib_path)
        llvm_debug_dep_list.append(dep_lib_name)
    return llvm_debug_dep_list

def _llvm_symlink_tablegens(repository_ctx, llvm_path):
    """Symlinks tablegen executable files for LLVM and MLIR.

    Args:
        repository_ctx: the repository_ctx object.
        llvm_path: path to the local LLVM installation
    """
    executable_ext = _executable_file_params(repository_ctx)
    tablegens = [
        "llvm-tblgen%s" % executable_ext,
        "mlir-tblgen%s" % executable_ext
    ]

    for tablegen in tablegens:
        tablegen_path = repository_ctx.path("%s/bin/%s" % (llvm_path, tablegen))
        if tablegen_path.exists:
            repository_ctx.symlink(tablegen_path, "bin/%s" % tablegen)

def _llvm_if_tablegen(repository_ctx, prefix):
    """Checks if an executable file with name '<prefix>-tblgen'(.exe if Windows)
       exists in the 'bin' subdirectory.

    Args:
        repository_ctx: the repository_ctx object.
        prefix: the prefix to check a file '<prefix>-tblgen'
    Returns:
        True if the file exists, False otherwise.
    """
    executable_ext = _executable_file_params(repository_ctx)
    return repository_ctx.path("bin/%s-tblgen%s" % (prefix, executable_ext)).exists

def _llvm_installed_impl(repository_ctx):
    # dictionary of prefixes, all targets will be named prefix_dictionary["llvm"]<target>
    # for LLVM, prefix_dictionary["clang"]<target> for clang, etc.
    prefix_dictionary = {
        "llvm": repository_ctx.attr.llvm_prefix,
        "clang": repository_ctx.attr.clang_prefix,
        "libcxx": repository_ctx.attr.libcxx_prefix,
        "mlir": repository_ctx.attr.mlir_prefix,
    }
    # if there are duplicated prefixes, fail.
    _llvm_check_duplicated_prefixes(prefix_dictionary)

    if _llvm_local_enabled(repository_ctx):
        # setup local LLVM repository
        llvm_path = _llvm_get_install_path(repository_ctx)
        repository_ctx.symlink("%s/include" % llvm_path, "include")
        repository_ctx.symlink("%s/lib" % llvm_path, "lib")
        _llvm_symlink_tablegens(repository_ctx, llvm_path)
    else:
        # setup remote LLVM repository.
        repository_ctx.download_and_extract(
            repository_ctx.attr.urls,
            sha256 = repository_ctx.attr.sha256,
            stripPrefix = repository_ctx.attr.strip_prefix,
        )

        if repository_ctx.attr.build_file:
            # Also setup BUILD file if it is specified. If the file is specified,
            # we should not generate it, exit. Notice: the BUILD file must provide
            # the same set of targets as this repository rule does.
            repository_ctx.symlink(repository_ctx.attr.build_file, "BUILD")
            # Also config file can be specified. If so, the file will be symlinked
            # to llvm_config.bzl
            if repository_ctx.attr.config_file:
                repository_ctx.symlink(repository_ctx.attr.config_file, "llvm_config.bzl")
            return

        llvm_path = repository_ctx.path(".") # points to the root of the repository

    # Anyway download the LICENSE file
    repository_ctx.download(
        url = _LLVM_LICENSE_FILE_PATH,
        output = "./LICENSE.TXT",
        sha256 = _LLVM_LICENSE_FILE_SHA256)

    # Symlink LLVM dependencies
    llvm_linkopts, llvm_deps = _llvm_symlink_dependencies(repository_ctx)

    # Symlink debug specific dependencies
    llvm_debug_deps = _llvm_symlink_debug_dependencies(repository_ctx)

    # LLVM installation options
    enable_rtti, enable_eh, supported_targets = _llvm_get_installation_options(
        repository_ctx)
    ctx = repository_ctx
    prx = prefix_dictionary
    add_hdrs = repository_ctx.attr.add_headers_to_deps
    _tpl(repository_ctx, "BUILD", {
        "%{CLANG_HEADERS_LIB}":
             _llvm_get_include_rule(ctx, prx, "clang_headers",
                ["clang", "clang-c"]),
        "%{LLVM_HEADERS_LIB}":
            _llvm_get_include_rule(ctx, prx, "llvm_headers",
                ["llvm", "llvm-c"]),
        "%{MLIR_HEADERS_LIB}":
            _llvm_get_include_rule(ctx, prx, "mlir_headers",
                ["mlir", "mlir-c"]),
        "%{LIBCXX_HEADERS_LIB}":
            _llvm_get_include_rule(ctx, prx, "libcxx_headers",
                ["c++/v1"],
                ["include/c++/v1"]),

        "%{CLANG_ANALYSIS_LIB}":
            _llvm_get_library_rule(ctx, prx, "clang_analysis",
                "clangAnalysis",
                ["clang_ast", "clang_ast_matchers", "clang_basic",
                 "clang_lex", "llvm_frontend_open_mp", "llvm_support"] +
                  (["clang_headers"] if add_hdrs else [])),
        "%{CLANG_ARCMIGRATE_LIB}":
            _llvm_get_library_rule(ctx, prx, "clang_arc_migrate",
                "clangARCMigrate",
                ["clang_ast", "clang_analysis", "clang_basic", "clang_edit",
                 "clang_frontend", "clang_lex", "clang_rewrite", "clang_sema",
                 "clang_serialization", "llvm_support"] +
                  (["clang_headers"] if add_hdrs else [])),
        "%{CLANG_AST_LIB}":
            _llvm_get_library_rule(ctx, prx, "clang_ast",
                "clangAST",
                ["clang_basic", "clang_lex", "llvm_binary_format", "llvm_core",
                 "llvm_frontend_open_mp", "llvm_support"] +
                  (["clang_headers"] if add_hdrs else [])),
        "%{CLANG_ASTMATCHERS_LIB}":
            _llvm_get_library_rule(ctx, prx, "clang_ast_matchers",
                "clangASTMatchers",
                ["clang_ast", "clang_basic", "clang_lex",
                 "llvm_frontend_open_mp", "llvm_support"] +
                  (["clang_headers"] if add_hdrs else [])),
        "%{CLANG_BASIC_LIB}":
            _llvm_get_library_rule(ctx, prx, "clang_basic",
                "clangBasic",
                ["llvm_core", "llvm_mc", "llvm_support"] +
                  (["clang_headers"] if add_hdrs else [])),
        "%{CLANG_CODEGEN_LIB}":
            _llvm_get_library_rule(ctx, prx, "clang_code_gen",
                "clangCodeGen",
                ["clang_analysis", "clang_ast", "clang_ast_matchers",
                 "clang_basic", "clang_frontend", "clang_lex",
                 "clang_serialization", "llvm_analysis", "llvm_bit_reader",
                 "llvm_bit_writer", "llvm_core", "llvm_coroutines",
                 "llvm_coverage", "llvm_extensions", "llvm_frontend_open_mp",
                 "llvm_ipo", "llvm_ir_reader", "llvm_aggressive_inst_combine",
                 "llvm_inst_combine", "llvm_instrumentation", "llvm_lto",
                 "llvm_linker", "llvm_mc", "llvm_objc_arc", "llvm_object",
                 "llvm_passes", "llvm_profile_data", "llvm_remarks",
                 "llvm_scalar", "llvm_support", "llvm_target",
                 "llvm_transform_utils"] +
                  (["clang_headers"] if add_hdrs else [])),
        "%{CLANG_CROSSTU_LIB}":
            _llvm_get_library_rule(ctx, prx, "clang_cross_tu",
                "clangCrossTU",
                ["clang_ast", "clang_basic", "clang_frontend", "clang_index",
                 "llvm_support"] +
                  (["clang_headers"] if add_hdrs else [])),
        "%{CLANG_DEPENDENCYSCANNING_LIB}":
            _llvm_get_library_rule(ctx, prx, "clang_dependency_scanning",
                "clangDependencyScanning",
                ["clang_ast", "clang_basic", "clang_driver", "clang_frontend",
                 "clang_frontend_tool", "clang_lex", "clang_parse",
                 "clang_serialization", "clang_tooling",
                 "llvm_core", "llvm_support"] +
                  (["clang_headers"] if add_hdrs else [])),
        "%{CLANG_DIRECTORYWATCHER_LIB}":
            _llvm_get_library_rule(ctx, prx, "clang_directory_watcher",
                "clangDirectoryWatcher",
                ["llvm_support"] +
                  (["clang_headers"] if add_hdrs else [])),
        "%{CLANG_DRIVER_LIB}":
            _llvm_get_library_rule(ctx, prx, "clang_driver",
                "clangDriver",
                ["clang_basic", "llvm_binary_format", "llvm_option",
                 "llvm_profile_data", "llvm_support"] +
                  (["clang_headers"] if add_hdrs else []),
                ["-DEFAULTLIB:version.lib"] if _is_windows(ctx) else []),
        "%{CLANG_DYNAMICASTMATCHERS_LIB}":
            _llvm_get_library_rule(ctx, prx, "clang_dynamic_ast_matchers",
                "clangDynamicASTMatchers",
                ["clang_ast", "clang_ast_matchers", "clang_basic",
                 "llvm_frontend_open_mp", "llvm_support"] +
                  (["clang_headers"] if add_hdrs else [])),
        "%{CLANG_EDIT_LIB}":
            _llvm_get_library_rule(ctx, prx, "clang_edit",
                "clangEdit",
                ["clang_ast", "clang_basic", "clang_lex", "llvm_support"] +
                  (["clang_headers"] if add_hdrs else [])),
        "%{CLANG_FORMAT_LIB}":
            _llvm_get_library_rule(ctx, prx, "clang_format",
                "clangFormat",
                ["clang_basic", "clang_lex", "clang_tooling_core",
                 "clang_tooling_inclusions", "llvm_support"] +
                  (["clang_headers"] if add_hdrs else [])),
        "%{CLANG_FRONTEND_LIB}":
            _llvm_get_library_rule(ctx, prx, "clang_frontend",
                "clangFrontend",
                ["clang_ast", "clang_basic", "clang_driver", "clang_edit",
                 "clang_lex", "clang_parse", "clang_sema", "clang_serialization",
                 "llvm_bit_reader", "llvm_bitstream_reader", "llvm_option",
                 "llvm_profile_data", "llvm_support"] +
                  (["clang_headers"] if add_hdrs else [])),
        "%{CLANG_FRONTENDTOOL_LIB}":
            _llvm_get_library_rule(ctx, prx, "clang_frontend_tool",
                "clangFrontendTool",
                ["clang_basic", "clang_code_gen", "clang_driver", "clang_frontend",
                 "clang_rewrite_frontend", "clang_arc_migrate",
                 "clang_static_analyzer_frontend", "llvm_option", "llvm_support"] +
                  (["clang_headers"] if add_hdrs else [])),
        "%{CLANG_HANDLECXX_LIB}":
            _llvm_get_library_rule(ctx, prx, "clang_handle_cxx",
                "clangHandleCXX",
                ["clang_basic", "clang_code_gen", "clang_frontend", "clang_lex",
                 "clang_serialization", "clang_tooling", "llvm_support"
                ] + (["llvm_aarch64_code_gen", "llvm_aarch64_asm_parser",
                      "llvm_aarch64_desc", "llvm_aarch64_disassembler",
                      "llvm_aarch64_info", "llvm_aarch64_utils"
                     ] if "AArch64" in supported_targets else [])
                  + (["llvm_amdgpu_code_gen", "llvm_amdgpu_asm_parser",
                      "llvm_amdgpu_desc", "llvm_amdgpu_disassembler",
                      "llvm_amdgpu_info", "llvm_amdgpu_utils"
                     ] if "AMDGPU" in supported_targets else [])
                  + (["llvm_arm_code_gen", "llvm_arm_asm_parser",
                      "llvm_arm_desc", "llvm_arm_disassembler",
                      "llvm_arm_info", "llvm_arm_utils"
                     ] if "ARM" in supported_targets else [])
                  + (["llvm_avr_code_gen", "llvm_avr_asm_parser",
                      "llvm_avr_desc", "llvm_avr_disassembler",
                      "llvm_avr_info"
                     ] if "AVR" in supported_targets else [])
                  + (["llvm_bpf_code_gen", "llvm_bpf_asm_parser",
                      "llvm_bpf_desc", "llvm_bpf_disassembler",
                      "llvm_bpf_info"] if "BPF" in supported_targets else [])
                  + (["llvm_hexagon_code_gen", "llvm_hexagon_asm_parser",
                      "llvm_hexagon_desc", "llvm_hexagon_disassembler",
                      "llvm_hexagon_info"
                     ] if "Hexagon" in supported_targets else [])
                  + (["llvm_lanai_code_gen", "llvm_lanai_asm_parser",
                      "llvm_lanai_desc", "llvm_lanai_disassembler",
                      "llvm_lanai_info"
                     ] if "Lanai" in supported_targets else [])
                  + (["llvm_mips_code_gen", "llvm_mips_asm_parser",
                      "llvm_mips_desc", "llvm_mips_disassembler",
                      "llvm_mips_info"
                     ] if "Mips" in supported_targets else [])
                  + (["llvm_msp430_code_gen", "llvm_msp430_asm_parser",
                      "llvm_msp430_desc", "llvm_msp430_disassembler",
                      "llvm_msp430_info"
                     ] if "MSP430" in supported_targets else [])
                  + (["llvm_nvptx_code_gen", "llvm_nvptx_desc",
                      "llvm_nvptx_info"
                     ] if "NVPTX" in supported_targets else [])
                  + (["llvm_powerpc_code_gen", "llvm_powerpc_asm_parser",
                      "llvm_powerpc_desc", "llvm_powerpc_disassembler",
                      "llvm_powerpc_info"
                     ] if "PowerPC" in supported_targets else [])
                  + (["llvm_riscv_code_gen", "llvm_riscv_asm_parser",
                      "llvm_riscv_desc", "llvm_riscv_disassembler",
                      "llvm_riscv_info", "llvm_riscv_utils"
                     ] if "RISCV" in supported_targets else [])
                  + (["llvm_sparc_code_gen", "llvm_sparc_asm_parser",
                      "llvm_sparc_desc", "llvm_sparc_disassembler",
                      "llvm_sparc_info"
                     ] if "Sparc" in supported_targets else [])
                  + (["llvm_system_z_code_gen", "llvm_system_z_asm_parser",
                      "llvm_system_z_desc", "llvm_system_z_disassembler",
                      "llvm_system_z_info"
                     ] if "SystemZ" in supported_targets else [])
                  + (["llvm_web_assembly_code_gen",
                      "llvm_web_assembly_asm_parser",
                      "llvm_web_assembly_desc",
                      "llvm_web_assembly_disassembler",
                      "llvm_web_assembly_info"
                     ] if "WebAssembly" in supported_targets else [])
                  + (["llvm_x86_code_gen", "llvm_x86_asm_parser",
                      "llvm_x86_desc", "llvm_x86_disassembler",
                      "llvm_x86_info"
                     ] if "X86" in supported_targets else [])
                  + (["llvm_x_core_code_gen", "llvm_x_core_desc",
                      "llvm_x_core_disassembler", "llvm_x_core_info"
                     ] if "XCore" in supported_targets else [])
                  + (["clang_headers"] if add_hdrs else [])),
        "%{CLANG_HANDLELLVM_LIB}":
            _llvm_get_library_rule(ctx, prx, "clang_handle_llvm",
                "clangHandleLLVM",
                ["llvm_analysis", "llvm_code_gen", "llvm_core",
                 "llvm_execution_engine", "llvm_ipo", "llvm_ir_reader",
                 "llvm_mc", "llvm_mcjit", "llvm_object", "llvm_runtime_dyld",
                 "llvm_selection_dag", "llvm_support", "llvm_target",
                 "llvm_transform_utils"
                ] + (["llvm_x86_code_gen", "llvm_x86_asm_parser",
                      "llvm_x86_desc", "llvm_x86_disassembler",
                      "llvm_x86_info"
                     ] if "X86" in supported_targets else [])
                  + (["clang_headers"] if add_hdrs else [])),
        "%{CLANG_INDEX_LIB}":
            _llvm_get_library_rule(ctx, prx, "clang_index",
                "clangIndex",
                ["clang_ast", "clang_basic", "clang_format", "clang_frontend",
                 "clang_lex", "clang_rewrite", "clang_serialization",
                 "clang_tooling_core", "llvm_core", "llvm_support"] +
                  (["clang_headers"] if add_hdrs else [])),
        "%{CLANG_LEX_LIB}":
            _llvm_get_library_rule(ctx, prx, "clang_lex",
                "clangLex",
                ["clang_basic", "llvm_support"] +
                  (["clang_headers"] if add_hdrs else [])),
        "%{CLANG_LIBCLANG_LIB}":
            _llvm_get_shared_library_rule(ctx, prx, "clang_libclang",
                "libclang",
                ["clang_headers", "llvm_headers"] if add_hdrs else [],
                ignore_prefix = True),
        "%{CLANG_LIBCLANG_COPY_GENRULE}":
            _llvm_get_shared_lib_genrule(ctx, prx, "clang_copy_libclang",
                llvm_path, "libclang", ignore_prefix = True),
        "%{CLANG_LIBCLANGCPP_LIB}":
            _llvm_get_shared_library_rule(ctx, prx, "clang_libclang_cpp",
                "libclang-cpp",
                ["clang_headers", "llvm_headers"] if add_hdrs else [],
                ignore_prefix = True, nix_only = True),
        "%{CLANG_LIBCLANGCPP_COPY_GENRULE}":
            _llvm_get_shared_lib_genrule(ctx, prx, "clang_copy_libclang_cpp",
                llvm_path, "libclang-cpp", ignore_prefix = True, nix_only=True),
        "%{CLANG_PARSE_LIB}":
            _llvm_get_library_rule(ctx, prx, "clang_parse",
                "clangParse",
                ["clang_ast", "clang_basic", "clang_lex", "clang_sema",
                 "llvm_frontend_open_mp", "llvm_mc", "llvm_mc_parser",
                 "llvm_support"] + (["clang_headers"] if add_hdrs else [])),
        "%{CLANG_REWRITE_LIB}":
            _llvm_get_library_rule(ctx, prx, "clang_rewrite",
                "clangRewrite",
                ["clang_basic", "clang_lex", "llvm_support"] +
                  (["clang_headers"] if add_hdrs else [])),
        "%{CLANG_REWRITEFRONTEND_LIB}":
            _llvm_get_library_rule(ctx, prx, "clang_rewrite_frontend",
                "clangRewriteFrontend",
                ["clang_ast", "clang_basic", "clang_edit", "clang_frontend",
                 "clang_lex", "clang_rewrite", "clang_serialization",
                 "llvm_support"] +
                  (["clang_headers"] if add_hdrs else [])),
        "%{CLANG_SEMA_LIB}":
            _llvm_get_library_rule(ctx, prx, "clang_sema",
                "clangSema",
                ["clang_ast", "clang_analysis", "clang_basic",
                 "clang_edit", "clang_lex", "llvm_frontend_open_mp",
                 "llvm_support"] +
                  (["clang_headers"] if add_hdrs else [])),
        "%{CLANG_SERIALIZATION_LIB}":
            _llvm_get_library_rule(ctx, prx, "clang_serialization",
                "clangSerialization",
                ["clang_ast", "clang_basic", "clang_lex", "clang_sema",
                 "llvm_bit_reader", "llvm_bitstream_reader", "llvm_support"] +
                  (["clang_headers"] if add_hdrs else [])),
        "%{CLANG_STATICANALYZERCHECKERS_LIB}":
            _llvm_get_library_rule(ctx, prx, "clang_static_analyzer_checkers",
                "clangStaticAnalyzerCheckers",
                ["clang_ast", "clang_ast_matchers", "clang_analysis", "clang_basic",
                 "clang_lex", "clang_static_analyzer_core", "llvm_frontend_open_mp",
                 "llvm_support"] + (["clang_headers"] if add_hdrs else [])),
        "%{CLANG_STATICANALYZERCORE_LIB}":
            _llvm_get_library_rule(ctx, prx, "clang_static_analyzer_core",
                "clangStaticAnalyzerCore",
                ["clang_ast", "clang_ast_matchers", "clang_analysis", "clang_basic",
                 "clang_cross_tu", "clang_frontend", "clang_lex", "clang_rewrite",
                 "clang_tooling_core", "llvm_frontend_open_mp", "llvm_support"] +
                  (["clang_headers"] if add_hdrs else [])),
        "%{CLANG_STATICANALYZERFRONTEND_LIB}":
            _llvm_get_library_rule(ctx, prx, "clang_static_analyzer_frontend",
                "clangStaticAnalyzerFrontend",
                ["clang_ast", "clang_ast_matchers", "clang_analysis", "clang_basic",
                 "clang_cross_tu", "clang_frontend", "clang_lex",
                 "clang_static_analyzer_checkers", "clang_static_analyzer_core",
                 "llvm_support"] + (["clang_headers"] if add_hdrs else [])),
        "%{CLANG_TOOLING_LIB}":
            _llvm_get_library_rule(ctx, prx, "clang_tooling",
                "clangTooling",
                ["clang_ast", "clang_ast_matchers", "clang_basic", "clang_driver",
                 "clang_format", "clang_frontend", "clang_lex", "clang_rewrite",
                 "clang_serialization", "clang_tooling_core",
                 "llvm_option", "llvm_frontend_open_mp", "llvm_support"] +
                  (["clang_headers"] if add_hdrs else [])),
        "%{CLANG_TOOLINGASTDIFF_LIB}":
            _llvm_get_library_rule(ctx, prx, "clang_tooling_ast_diff",
                "clangToolingASTDiff",
                ["clang_ast", "clang_basic", "clang_lex", "llvm_support"] +
                  (["clang_headers"] if add_hdrs else [])),
        "%{CLANG_TOOLINGCORE_LIB}":
            _llvm_get_library_rule(ctx, prx, "clang_tooling_core",
                "clangToolingCore",
                ["clang_ast", "clang_basic", "clang_lex", "clang_rewrite",
                 "llvm_support"] +
                  (["clang_headers"] if add_hdrs else [])),
        "%{CLANG_TOOLINGINCLUSIONS_LIB}":
            _llvm_get_library_rule(ctx, prx, "clang_tooling_inclusions",
                "clangToolingInclusions",
                ["clang_basic", "clang_lex", "clang_rewrite",
                 "clang_tooling_core", "llvm_support"] +
                  (["clang_headers"] if add_hdrs else [])),
        "%{CLANG_TOOLINGREFACTORING_LIB}":
            _llvm_get_library_rule(ctx, prx, "clang_tooling_refactoring",
                "clangToolingRefactoring",
                ["clang_ast", "clang_ast_matchers", "clang_basic", "clang_format",
                 "clang_index", "clang_lex", "clang_rewrite",
                 "clang_tooling_core", "llvm_support"] +
                  (["clang_headers"] if add_hdrs else [])),
        "%{CLANG_TOOLINGSYNTAX_LIB}":
            _llvm_get_library_rule(ctx, prx, "clang_tooling_syntax",
                "clangToolingSyntax",
                ["clang_ast", "clang_basic", "clang_frontend", "clang_lex",
                 "clang_tooling_core", "llvm_support"] +
                  (["clang_headers"] if add_hdrs else [])),
        "%{CLANG_TRANSFORMER_LIB}":
            _llvm_get_library_rule(ctx, prx, "clang_transformer",
                "clangTransformer",
                ["clang_ast", "clang_ast_matchers", "clang_basic", "clang_lex",
                 "clang_tooling_core", "clang_tooling_refactoring",
                 "llvm_frontend_open_mp", "llvm_support"] +
                  (["clang_headers"] if add_hdrs else [])),

        "%{LLVM_AGGRESSIVEINSTCOMBINE_LIB}":
            _llvm_get_library_rule(ctx, prx, "llvm_aggressive_inst_combine",
                "LLVMAggressiveInstCombine",
                ["llvm_analysis", "llvm_core", "llvm_support",
                 "llvm_transform_utils"]),
        "%{LLVM_ANALYSIS_LIB}":
            _llvm_get_library_rule(ctx, prx, "llvm_analysis",
                "LLVMAnalysis",
                ["llvm_binary_format", "llvm_core", "llvm_object", "llvm_profile_data",
                 "llvm_support"]),
        "%{LLVM_ASMPRARSER_LIB}":
            _llvm_get_library_rule(ctx, prx, "llvm_asm_parser",
                "LLVMAsmParser",
                ["llvm_binary_format", "llvm_core", "llvm_support"]),
        "%{LLVM_ASMPRINTER_LIB}":
            _llvm_get_library_rule(ctx, prx, "llvm_asm_printer",
                "LLVMAsmPrinter",
                ["llvm_analysis", "llvm_binary_format", "llvm_code_gen", "llvm_core",
                 "llvm_debug_info_code_view", "llvm_debug_info_dwarf", "llvm_debug_info_msf",
                 "llvm_mc", "llvm_mc_parser", "llvm_remarks", "llvm_support", "llvm_target"]),
        "%{LLVM_BINARYFORMAT_LIB}":
            _llvm_get_library_rule(ctx, prx, "llvm_binary_format",
                "LLVMBinaryFormat", ["llvm_support"]),
        "%{LLVM_BITREADER_LIB}":
            _llvm_get_library_rule(ctx, prx, "llvm_bit_reader",
                "LLVMBitReader",
                ["llvm_bitstream_reader", "llvm_core", "llvm_support"]),
        "%{LLVM_BITWRITER_LIB}":
            _llvm_get_library_rule(ctx, prx, "llvm_bit_writer",
                "LLVMBitWriter",
                ["llvm_analysis", "llvm_core", "llvm_mc", "llvm_object",
                 "llvm_support"]),
        "%{LLVM_BITSTREAMREADER_LIB}":
            _llvm_get_library_rule(ctx, prx, "llvm_bitstream_reader",
                "LLVMBitstreamReader", ["llvm_support"]),
        "%{LLVM_C_LIB}":
            _llvm_get_shared_library_rule(ctx, prx, "llvm_c", "LLVM-C",
                ["llvm_headers"] if add_hdrs else [],
                win_only = True),
        "%{LLVM_C_COPY_GENRULE}":
            _llvm_get_shared_lib_genrule(ctx, prx, "llvm_copy_c",
                llvm_path, "LLVM-C", win_only = True),
        "%{LLVM_CFGUARD_LIB}":
            _llvm_get_library_rule(ctx, prx, "llvm_cf_guard",
                "LLVMCFGuard",
                ["llvm_core", "llvm_support"]),
        "%{LLVM_CODEGEN_LIB}":
            _llvm_get_library_rule(ctx, prx, "llvm_code_gen",
                "LLVMCodeGen",
                ["llvm_analysis", "llvm_bit_reader", "llvm_bit_writer",
                 "llvm_core", "llvm_mc", "llvm_profile_data",
                 "llvm_scalar", "llvm_support", "llvm_target",
                 "llvm_transform_utils"]),
        "%{LLVM_CORE_LIB}":
            _llvm_get_library_rule(ctx, prx, "llvm_core",
                "LLVMCore",
                ["llvm_binary_format", "llvm_remarks", "llvm_support"]),
        "%{LLVM_COROUTINES_LIB}":
            _llvm_get_library_rule(ctx, prx, "llvm_coroutines",
                "LLVMCoroutines",
                ["llvm_analysis", "llvm_core", "llvm_scalar", "llvm_support",
                 "llvm_transform_utils", "llvm_ipo"]),
        "%{LLVM_COVERAGE_LIB}":
            _llvm_get_library_rule(ctx, prx, "llvm_coverage",
                "LLVMCoverage",
                ["llvm_core", "llvm_object", "llvm_profile_data", "llvm_support"]),
        "%{LLVM_DEBUGINFOCODEVIEW_LIB}":
            _llvm_get_library_rule(ctx, prx, "llvm_debug_info_code_view",
                "LLVMDebugInfoCodeView",
                ["llvm_debug_info_msf", "llvm_support"]),
        "%{LLVM_DEBUGINFODWARF_LIB}":
            _llvm_get_library_rule(ctx, prx, "llvm_debug_info_dwarf",
                "LLVMDebugInfoDWARF",
                ["llvm_binary_format", "llvm_mc", "llvm_object", "llvm_support"]),
        "%{LLVM_DEBUGINFOGSYM_LIB}":
            _llvm_get_library_rule(ctx, prx, "llvm_debug_info_gsym",
                "LLVMDebugInfoGSYM",
                ["llvm_debug_info_dwarf", "llvm_mc", "llvm_object",
                 "llvm_support"]),
        "%{LLVM_DEBUGINFOMSF_LIB}":
            _llvm_get_library_rule(ctx, prx, "llvm_debug_info_msf",
                "LLVMDebugInfoMSF", ["llvm_support"]),
        "%{LLVM_DEBUGINFOPDB_LIB}":
            _llvm_get_library_rule(ctx, prx, "llvm_debug_info_pdb",
                "LLVMDebugInfoPDB",
                ["llvm_binary_format", "llvm_debug_info_code_view",
                 "llvm_debug_info_msf", "llvm_object",
                 "llvm_support"] + llvm_debug_deps),
        "%{LLVM_DEMANGLE_LIB}":
            _llvm_get_library_rule(ctx, prx, "llvm_demangle",
                "LLVMDemangle"),
        "%{LLVM_DLLTOOLDRIVER_LIB}":
            _llvm_get_library_rule(ctx, prx, "llvm_dlltool_driver",
                "LLVMDlltoolDriver",
                ["llvm_object", "llvm_option", "llvm_support"]),
        "%{LLVM_DWARFLINKER_LIB}":
            _llvm_get_library_rule(ctx, prx, "llvm_dwarf_linker",
                "LLVMDWARFLinker",
                ["llvm_asm_printer", "llvm_code_gen", "llvm_debug_info_dwarf",
                 "llvm_mc", "llvm_object", "llvm_support"]),
        "%{LLVM_EXECUTION_ENGINE_LIB}":
            _llvm_get_library_rule(ctx, prx, "llvm_execution_engine",
                "LLVMExecutionEngine",
                ["llvm_core", "llvm_mc", "llvm_object", "llvm_runtime_dyld",
                 "llvm_support", "llvm_target"]),
        "%{LLVM_EXTENSIONS}":
            _llvm_get_library_rule(ctx, prx, "llvm_extensions",
                "LLVMExtensions"),
        "%{LLVM_FRONTEND_OPENMP_LIB}":
            _llvm_get_library_rule(ctx, prx, "llvm_frontend_open_mp",
                "LLVMFrontendOpenMP",
                ["llvm_core", "llvm_support", "llvm_transform_utils"]),
        "%{LLVM_FUZZMUTATE_LIB}":
            _llvm_get_library_rule(ctx, prx, "llvm_fuzz_mutate",
                "LLVMFuzzMutate",
                ["llvm_analysis", "llvm_bit_reader", "llvm_bit_writer",
                 "llvm_core", "llvm_scalar", "llvm_support",
                 "llvm_target"]),
        "%{LLVM_GLOBALISEL_LIB}":
            _llvm_get_library_rule(ctx, prx, "llvm_global_i_sel",
                "LLVMGlobalISel",
                ["llvm_analysis", "llvm_code_gen", "llvm_core", "llvm_mc",
                 "llvm_selection_dag", "llvm_support", "llvm_target",
                 "llvm_transform_utils"]),
        "%{LLVM_INSTCOMBINE_LIB}":
            _llvm_get_library_rule(ctx, prx, "llvm_inst_combine",
                "LLVMInstCombine",
                ["llvm_analysis", "llvm_core", "llvm_support",
                 "llvm_transform_utils"]),
        "%{LLVM_INSTRUMENTATION_LIB}":
            _llvm_get_library_rule(ctx, prx, "llvm_instrumentation",
                "LLVMInstrumentation",
                ["llvm_analysis", "llvm_core", "llvm_mc", "llvm_profile_data",
                 "llvm_support", "llvm_transform_utils"]),
        "%{LLVM_INTERPRETER_LIB}":
            _llvm_get_library_rule(ctx, prx, "llvm_interpreter",
                "LLVMInterpreter",
                ["llvm_code_gen", "llvm_core", "llvm_execution_engine",
                 "llvm_support"]),
        "%{LLVM_IRREADER_LIB}":
            _llvm_get_library_rule(ctx, prx, "llvm_ir_reader",
                "LLVMIRReader",
                ["llvm_asm_parser", "llvm_bit_reader", "llvm_core",
                 "llvm_support"]),
        "%{LLVM_IPO_LIB}":
            _llvm_get_library_rule(ctx, prx, "llvm_ipo",
                "LLVMipo",
                ["llvm_aggressive_inst_combine", "llvm_analysis",
                 "llvm_bit_reader", "llvm_bit_writer", "llvm_core",
                 "llvm_frontend_open_mp", "llvm_ir_reader",
                 "llvm_inst_combine", "llvm_instrumentation",
                 "llvm_linker", "llvm_object", "llvm_profile_data",
                 "llvm_scalar", "llvm_support", "llvm_transform_utils",
                 "llvm_vectorize"]),
        "%{LLVM_JITLINK_LIB}":
            _llvm_get_library_rule(ctx, prx, "llvm_jit_link",
                "LLVMJITLink",
                ["llvm_binary_format", "llvm_object", "llvm_support"]),
        "%{LLVM_LIBDRIVER_LIB}":
            _llvm_get_library_rule(ctx, prx, "llvm_lib_driver",
                "LLVMLibDriver",
                ["llvm_binary_format", "llvm_bit_reader", "llvm_object",
                 "llvm_option", "llvm_support"]),
        "%{LLVM_LINEEDITOR_LIB}":
            _llvm_get_library_rule(ctx, prx, "llvm_line_editor",
                "LLVMLineEditor", ["llvm_support"]),
        "%{LLVM_LINKER_LIB}":
            _llvm_get_library_rule(ctx, prx, "llvm_linker",
                "LLVMLinker",
                ["llvm_core", "llvm_support", "llvm_transform_utils"]),
        "%{LLVM_LTO_LIB}":
            _llvm_get_library_rule(ctx, prx, "llvm_lto",
                "LLVMLTO",
                ["llvm_aggressive_inst_combine", "llvm_analysis",
                 "llvm_binary_format", "llvm_bit_reader", "llvm_bit_writer",
                 "llvm_code_gen", "llvm_core", "llvm_extensions",
                 "llvm_inst_combine", "llvm_linker", "llvm_mc",
                 "llvm_objc_arc", "llvm_object", "llvm_passes",
                 "llvm_remarks", "llvm_scalar", "llvm_support",
                 "llvm_target", "llvm_transform_utils", "llvm_ipo"]),
        "%{LLVM_MC_LIB}":
            _llvm_get_library_rule(ctx, prx, "llvm_mc",
                "LLVMMC",
                ["llvm_binary_format", "llvm_debug_info_code_view",
                 "llvm_support"]),
        "%{LLVM_MCA_LIB}":
            _llvm_get_library_rule(ctx, prx, "llvm_mca",
                "LLVMMCA",
                ["llvm_mc", "llvm_support"]),
        "%{LLVM_MCDISASSEMBLER_LIB}":
            _llvm_get_library_rule(ctx, prx, "llvm_mc_disassembler",
                "LLVMMCDisassembler",
                ["llvm_mc", "llvm_support"]),
        "%{LLVM_MCJIT_LIB}":
            _llvm_get_library_rule(ctx, prx, "llvm_mcjit",
                "LLVMMCJIT",
                ["llvm_core", "llvm_execution_engine", "llvm_object",
                 "llvm_runtime_dyld", "llvm_support", "llvm_target"]),
        "%{LLVM_MCPARSER_LIB}":
            _llvm_get_library_rule(ctx, prx, "llvm_mc_parser",
                "LLVMMCParser",
                ["llvm_mc", "llvm_support"]),
        "%{LLVM_MIRPARSER_LIB}":
            _llvm_get_library_rule(ctx, prx, "llvm_mir_parser",
                "LLVMMIRParser",
                ["llvm_asm_parser", "llvm_binary_format", "llvm_code_gen",
                 "llvm_core", "llvm_mc", "llvm_support", "llvm_target"]),
        "%{LLVM_OBJCARC_LIB}":
            _llvm_get_library_rule(ctx, prx, "llvm_objc_arc",
                "LLVMObjCARCOpts",
                ["llvm_analysis", "llvm_core", "llvm_support",
                 "llvm_transform_utils"]),
        "%{LLVM_OBJECT_LIB}":
            _llvm_get_library_rule(ctx, prx, "llvm_object",
                "LLVMObject",
                ["llvm_binary_format", "llvm_bit_reader", "llvm_core",
                 "llvm_mc", "llvm_mc_parser", "llvm_support", "llvm_text_api"]),
       "%{LLVM_OBJECTYAML_LIB}":
            _llvm_get_library_rule(ctx, prx, "llvm_object_yaml",
                "LLVMObjectYAML",
                ["llvm_debug_info_code_view", "llvm_mc", "llvm_object",
                 "llvm_support"]),
       "%{LLVM_OPTION_LIB}":
            _llvm_get_library_rule(ctx, prx, "llvm_option",
                "LLVMOption", ["llvm_support"]),
       "%{LLVM_ORCERROR_LIB}":
            _llvm_get_library_rule(ctx, prx, "llvm_orc_error",
                "LLVMOrcError", ["llvm_support"]),
       "%{LLVM_ORCJIT_LIB}":
            _llvm_get_library_rule(ctx, prx, "llvm_orc_jit",
                "LLVMOrcJIT",
                ["llvm_analysis", "llvm_bit_reader", "llvm_bit_writer",
                 "llvm_core", "llvm_execution_engine", "llvm_jit_link",
                 "llvm_mc", "llvm_object", "llvm_orc_error",
                 "llvm_passes", "llvm_runtime_dyld", "llvm_support",
                 "llvm_target", "llvm_transform_utils"]),
        "%{LLVM_PASSES_LIB}":
            _llvm_get_library_rule(ctx, prx, "llvm_passes",
                "LLVMPasses",
                ["llvm_aggressive_inst_combine", "llvm_analysis",
                 "llvm_code_gen", "llvm_core", "llvm_coroutines",
                 "llvm_inst_combine", "llvm_instrumentation",
                 "llvm_scalar", "llvm_support", "llvm_target",
                 "llvm_transform_utils", "llvm_vectorize",
                 "llvm_ipo"]),
        "%{LLVM_PROFILEDATA_LIB}":
            _llvm_get_library_rule(ctx, prx, "llvm_profile_data",
                "LLVMProfileData",
                ["llvm_core", "llvm_support"]),
        "%{LLVM_REMARKS_LIB}":
            _llvm_get_library_rule(ctx, prx, "llvm_remarks",
                "LLVMRemarks",
                ["llvm_bitstream_reader", "llvm_support"]),
        "%{LLVM_RUNTIMEDYLD_LIB}":
            _llvm_get_library_rule(ctx, prx, "llvm_runtime_dyld",
                "LLVMRuntimeDyld",
                ["llvm_mc", "llvm_object", "llvm_support"]),
        "%{LLVM_SCALAR_LIB}":
            _llvm_get_library_rule(ctx, prx, "llvm_scalar",
                "LLVMScalarOpts",
                ["llvm_aggressive_inst_combine", "llvm_analysis",
                 "llvm_core", "llvm_inst_combine", "llvm_support",
                 "llvm_transform_utils"]),
        "%{LLVM_SELECTIONDAG_LIB}":
            _llvm_get_library_rule(ctx, prx, "llvm_selection_dag",
                "LLVMSelectionDAG",
                ["llvm_analysis", "llvm_code_gen", "llvm_core", "llvm_mc",
                 "llvm_support", "llvm_target", "llvm_transform_utils"]),
        "%{LLVM_SUPPORT_LIB}":
            _llvm_get_library_rule(ctx, prx, "llvm_support",
                "LLVMSupport",
                ["llvm_demangle"] + (["llvm_headers"] if add_hdrs else [])
                    + llvm_deps.keys(),
                llvm_linkopts),
        "%{LLVM_SYMBOLIZE_LIB}":
            _llvm_get_library_rule(ctx, prx, "llvm_symbolize",
                "LLVMSymbolize",
                ["llvm_debug_info_dwarf", "llvm_debug_info_pdb",
                 "llvm_demangle", "llvm_object", "llvm_support"]),
        "%{LLVM_TABLEGEN_LIB}":
            _llvm_get_library_rule(ctx, prx, "llvm_tablegen",
                "LLVMTableGen",
                ["llvm_support"]),
        "%{LLVM_TABLEGEN_TOOL}":
            _llvm_get_executable_file_rule(ctx, prx, "llvm_tablegen_tool",
                "llvm-tblgen"),
        "%{LLVM_TARGET_LIB}":
            _llvm_get_library_rule(ctx, prx, "llvm_target",
                "LLVMTarget",
                ["llvm_analysis", "llvm_core", "llvm_mc", "llvm_support"]),
        "%{LLVM_TEXTAPI_LIB}":
            _llvm_get_library_rule(ctx, prx, "llvm_text_api",
                "LLVMTextAPI",
                ["llvm_binary_format", "llvm_support"]),
        "%{LLVM_TRANSFORMUTILS_LIB}":
            _llvm_get_library_rule(ctx, prx, "llvm_transform_utils",
                "LLVMTransformUtils",
                ["llvm_analysis", "llvm_core", "llvm_support"]),
        "%{LLVM_VECTORIZE_LIB}":
            _llvm_get_library_rule(ctx, prx, "llvm_vectorize",
                "LLVMVectorize",
                ["llvm_analysis", "llvm_core", "llvm_support",
                 "llvm_transform_utils"]),
        "%{LLVM_WINDOWS_MANIFEST_LIB}":
            _llvm_get_library_rule(ctx, prx, "llvm_windows_manifest",
                "LLVMWindowsManifest",
                ["llvm_support"]),
        "%{LLVM_XRAY_LIB}":
            _llvm_get_library_rule(ctx, prx, "llvm_x_ray",
                "LLVMXRay",
                ["llvm_object", "llvm_support"]),
        "%{LLVM_AARCH64_ASMPARSER_LIB}":
            _llvm_get_library_rule(ctx, prx, "llvm_aarch64_asm_parser",
                "LLVMAArch64AsmParser",
                ["llvm_aarch64_desc", "llvm_aarch64_info", "llvm_aarch64_utils",
                 "llvm_mc", "llvm_mc_parser", "llvm_support"]),
        "%{LLVM_AARCH64_CODEGEN_LIB}":
            _llvm_get_library_rule(ctx, prx, "llvm_aarch64_code_gen",
                "LLVMAArch64CodeGen",
                ["llvm_aarch64_desc", "llvm_aarch64_info", "llvm_aarch64_utils",
                 "llvm_analysis", "llvm_asm_printer", "llvm_cf_guard",
                 "llvm_code_gen", "llvm_core", "llvm_global_i_sel", "llvm_mc",
                 "llvm_scalar", "llvm_selection_dag", "llvm_support",
                 "llvm_target", "llvm_transform_utils"]),
         "%{LLVM_AARCH64_DESC_LIB}":
            _llvm_get_library_rule(ctx, prx, "llvm_aarch64_desc",
                "LLVMAArch64Desc",
                ["llvm_aarch64_info", "llvm_aarch64_utils", "llvm_binary_format",
                 "llvm_mc", "llvm_support"]),
        "%{LLVM_AARCH64_DISASSEMBLER_LIB}":
            _llvm_get_library_rule(ctx, prx, "llvm_aarch64_disassembler",
                "LLVMAArch64Disassembler",
                ["llvm_aarch64_desc", "llvm_aarch64_info", "llvm_aarch64_utils",
                 "llvm_mc", "llvm_mc_disassembler", "llvm_support"]),
         "%{LLVM_AARCH64_INFO_LIB}":
            _llvm_get_library_rule(ctx, prx, "llvm_aarch64_info",
                "LLVMAArch64Info",
                ["llvm_support"]),
         "%{LLVM_AARCH64_UTILS_LIB}":
            _llvm_get_library_rule(ctx, prx, "llvm_aarch64_utils",
                "LLVMAArch64Utils",
                ["llvm_support"]),
        "%{LLVM_AMDGPU_ASMPARSER_LIB}":
            _llvm_get_library_rule(ctx, prx, "llvm_amdgpu_asm_parser",
                "LLVMAMDGPUAsmParser",
                ["llvm_amdgpu_desc", "llvm_amdgpu_info", "llvm_amdgpu_utils",
                 "llvm_mc", "llvm_mc_parser", "llvm_support"]),
        "%{LLVM_AMDGPU_CODEGEN_LIB}":
            _llvm_get_library_rule(ctx, prx, "llvm_amdgpu_code_gen",
                "LLVMAMDGPUCodeGen",
                ["llvm_amdgpu_desc", "llvm_amdgpu_info", "llvm_amdgpu_utils",
                 "llvm_analysis", "llvm_asm_printer", "llvm_binary_format",
                 "llvm_code_gen", "llvm_core", "llvm_global_i_sel", "llvm_mc",
                 "llvm_mir_parser", "llvm_scalar", "llvm_selection_dag",
                 "llvm_support", "llvm_target", "llvm_transform_utils",
                 "llvm_vectorize", "llvm_ipo"]),
        "%{LLVM_AMDGPU_DESC_LIB}":
            _llvm_get_library_rule(ctx, prx, "llvm_amdgpu_desc",
                "LLVMAMDGPUDesc",
                ["llvm_amdgpu_info", "llvm_amdgpu_utils", "llvm_binary_format",
                 "llvm_core", "llvm_mc", "llvm_support"]),
        "%{LLVM_AMDGPU_DISASSEMBLER_LIB}":
            _llvm_get_library_rule(ctx, prx, "llvm_amdgpu_disassembler",
                "LLVMAMDGPUDisassembler",
                ["llvm_amdgpu_desc", "llvm_amdgpu_info", "llvm_amdgpu_utils",
                 "llvm_mc", "llvm_mc_disassembler", "llvm_support"]),
        "%{LLVM_AMDGPU_INFO_LIB}":
            _llvm_get_library_rule(ctx, prx, "llvm_amdgpu_info",
                "LLVMAMDGPUInfo",
                ["llvm_support"]),
        "%{LLVM_AMDGPU_UTILS_LIB}":
            _llvm_get_library_rule(ctx, prx, "llvm_amdgpu_utils",
                "LLVMAMDGPUUtils",
                ["llvm_binary_format", "llvm_core", "llvm_mc",
                 "llvm_support"]),
        "%{LLVM_ARM_ASMPARSER_LIB}":
            _llvm_get_library_rule(ctx, prx, "llvm_arm_asm_parser",
                "LLVMARMAsmParser",
                ["llvm_arm_desc", "llvm_arm_info", "llvm_arm_utils",
                 "llvm_mc", "llvm_mc_parser", "llvm_support"]),
        "%{LLVM_ARM_CODEGEN_LIB}":
            _llvm_get_library_rule(ctx, prx, "llvm_arm_code_gen",
                "LLVMARMCodeGen",
                ["llvm_arm_desc", "llvm_arm_info", "llvm_arm_utils",
                 "llvm_analysis", "llvm_asm_printer", "llvm_cf_guard",
                 "llvm_code_gen", "llvm_core", "llvm_global_i_sel",
                 "llvm_mc", "llvm_scalar", "llvm_selection_dag",
                 "llvm_support", "llvm_target", "llvm_transform_utils"]),
        "%{LLVM_ARM_DESC_LIB}":
            _llvm_get_library_rule(ctx, prx, "llvm_arm_desc",
                "LLVMARMDesc",
                ["llvm_arm_info", "llvm_arm_utils", "llvm_binary_format",
                 "llvm_mc", "llvm_mc_disassembler", "llvm_support"]),
        "%{LLVM_ARM_DISASSEMBLER_LIB}":
            _llvm_get_library_rule(ctx, prx, "llvm_arm_disassembler",
                "LLVMARMDisassembler",
                ["llvm_arm_desc", "llvm_arm_info", "llvm_arm_utils",
                 "llvm_mc_disassembler", "llvm_support"]),
        "%{LLVM_ARM_INFO_LIB}":
            _llvm_get_library_rule(ctx, prx, "llvm_arm_info",
                "LLVMARMInfo",
                ["llvm_support"]),
        "%{LLVM_ARM_UTILS_LIB}":
            _llvm_get_library_rule(ctx, prx, "llvm_arm_utils",
                "LLVMARMUtils",
                ["llvm_support"]),
        "%{LLVM_AVR_ASMPARSER_LIB}":
            _llvm_get_library_rule(ctx, prx, "llvm_avr_asm_parser",
                "LLVMAVRAsmParser",
                ["llvm_avr_desc", "llvm_avr_info", "llvm_mc",
                 "llvm_mc_parser", "llvm_support"]),
        "%{LLVM_AVR_CODEGEN_LIB}":
            _llvm_get_library_rule(ctx, prx, "llvm_avr_code_gen",
                "LLVMAVRCodeGen",
                ["llvm_avr_desc", "llvm_avr_info", "llvm_asm_printer",
                 "llvm_code_gen", "llvm_core", "llvm_mc",
                 "llvm_selection_dag", "llvm_support", "llvm_target"]),
        "%{LLVM_AVR_DESC_LIB}":
            _llvm_get_library_rule(ctx, prx, "llvm_avr_desc",
                "LLVMAVRDesc",
                ["llvm_avr_info", "llvm_mc", "llvm_support"]),
        "%{LLVM_AVR_DISASSEMBLER_LIB}":
            _llvm_get_library_rule(ctx, prx, "llvm_avr_disassembler",
                "LLVMAVRDisassembler",
                ["llvm_avr_info", "llvm_mc_disassembler",
                 "llvm_support"]),
        "%{LLVM_AVR_INFO_LIB}":
            _llvm_get_library_rule(ctx, prx, "llvm_avr_info",
                "LLVMAVRInfo",
                ["llvm_support"]),
        "%{LLVM_BPF_ASMPARSER_LIB}":
            _llvm_get_library_rule(ctx, prx, "llvm_bpf_asm_parser",
                "LLVMBPFAsmParser",
                ["llvm_bpf_desc", "llvm_bpf_info", "llvm_mc",
                 "llvm_mc_parser", "llvm_support"]),
        "%{LLVM_BPF_CODEGEN_LIB}":
            _llvm_get_library_rule(ctx, prx, "llvm_bpf_code_gen",
                "LLVMBPFCodeGen",
                ["llvm_asm_printer", "llvm_bpf_desc", "llvm_bpf_info",
                 "llvm_code_gen", "llvm_core", "llvm_mc",
                 "llvm_selection_dag", "llvm_support",
                 "llvm_target"]),
        "%{LLVM_BPF_DESC_LIB}":
            _llvm_get_library_rule(ctx, prx, "llvm_bpf_desc",
                "LLVMBPFDesc",
                ["llvm_bpf_info", "llvm_mc", "llvm_support"]),
        "%{LLVM_BPF_DISASSEMBLER_LIB}":
            _llvm_get_library_rule(ctx, prx, "llvm_bpf_disassembler",
                "LLVMBPFDisassembler",
                ["llvm_bpf_info", "llvm_mc_disassembler", "llvm_support"]),
        "%{LLVM_BPF_INFO_LIB}":
            _llvm_get_library_rule(ctx, prx, "llvm_bpf_info",
                "LLVMBPFInfo",
                ["llvm_support"]),
        "%{LLVM_HEXAGON_ASMPARSER_LIB}":
            _llvm_get_library_rule(ctx, prx, "llvm_hexagon_asm_parser",
                "LLVMHexagonAsmParser",
                ["llvm_hexagon_desc", "llvm_hexagon_info",
                 "llvm_mc", "llvm_mc_parser", "llvm_support"]),
        "%{LLVM_HEXAGON_CODEGEN_LIB}":
            _llvm_get_library_rule(ctx, prx, "llvm_hexagon_code_gen",
                "LLVMHexagonCodeGen",
                ["llvm_analysis", "llvm_asm_printer", "llvm_code_gen",
                 "llvm_core", "llvm_hexagon_asm_parser",
                 "llvm_hexagon_desc", "llvm_hexagon_info",
                 "llvm_mc", "llvm_scalar", "llvm_selection_dag",
                 "llvm_support", "llvm_target", "llvm_transform_utils",
                 "llvm_ipo"]),
        "%{LLVM_HEXAGON_DESC_LIB}":
            _llvm_get_library_rule(ctx, prx, "llvm_hexagon_desc",
                "LLVMHexagonDesc",
                ["llvm_hexagon_info", "llvm_mc", "llvm_support"]),
        "%{LLVM_HEXAGON_DISASSEMBLER_LIB}":
            _llvm_get_library_rule(ctx, prx, "llvm_hexagon_disassembler",
                "LLVMHexagonDisassembler",
                ["llvm_hexagon_desc", "llvm_hexagon_info",
                 "llvm_mc", "llvm_mc_disassembler", "llvm_support"]),
        "%{LLVM_HEXAGON_INFO_LIB}":
            _llvm_get_library_rule(ctx, prx, "llvm_hexagon_info",
                "LLVMHexagonInfo",
                ["llvm_support"]),
        "%{LLVM_LANAI_ASMPARSER_LIB}":
            _llvm_get_library_rule(ctx, prx, "llvm_lanai_asm_parser",
                "LLVMLanaiAsmParser",
                ["llvm_lanai_desc", "llvm_lanai_info", "llvm_mc",
                 "llvm_mc_parser", "llvm_support"]),
        "%{LLVM_LANAI_CODEGEN_LIB}":
            _llvm_get_library_rule(ctx, prx, "llvm_lanai_code_gen",
                "LLVMLanaiCodeGen",
                ["llvm_analysis", "llvm_asm_printer", "llvm_code_gen",
                 "llvm_core", "llvm_lanai_asm_parser", "llvm_lanai_desc",
                 "llvm_lanai_info", "llvm_mc", "llvm_selection_dag",
                 "llvm_support", "llvm_target", "llvm_transform_utils"]),
        "%{LLVM_LANAI_DESC_LIB}":
            _llvm_get_library_rule(ctx, prx, "llvm_lanai_desc",
                "LLVMLanaiDesc",
                ["llvm_lanai_info", "llvm_mc", "llvm_mc_disassembler",
                 "llvm_support"]),
        "%{LLVM_LANAI_DISASSEMBLER_LIB}":
            _llvm_get_library_rule(ctx, prx, "llvm_lanai_disassembler",
                "LLVMLanaiDisassembler",
                ["llvm_lanai_desc", "llvm_lanai_info", "llvm_mc",
                 "llvm_mc_disassembler", "llvm_support"]),
        "%{LLVM_LANAI_INFO_LIB}":
            _llvm_get_library_rule(ctx, prx, "llvm_lanai_info",
                "LLVMLanaiInfo",
                ["llvm_support"]),
        "%{LLVM_MIPS_ASMPARSER_LIB}":
            _llvm_get_library_rule(ctx, prx, "llvm_mips_asm_parser",
                "LLVMMipsAsmParser",
                ["llvm_mc", "llvm_mc_parser", "llvm_mips_desc",
                 "llvm_mips_info", "llvm_support"]),
        "%{LLVM_MIPS_CODEGEN_LIB}":
            _llvm_get_library_rule(ctx, prx, "llvm_mips_code_gen",
                "LLVMMipsCodeGen",
                ["llvm_analysis", "llvm_asm_printer", "llvm_code_gen",
                 "llvm_core", "llvm_global_i_sel", "llvm_mc",
                 "llvm_mips_desc", "llvm_mips_info",
                 "llvm_selection_dag", "llvm_support",
                 "llvm_target"]),
        "%{LLVM_MIPS_DESC_LIB}":
            _llvm_get_library_rule(ctx, prx, "llvm_mips_desc",
                "LLVMMipsDesc",
                ["llvm_mc", "llvm_mips_info", "llvm_support"]),
        "%{LLVM_MIPS_DISASSEMBLER_LIB}":
            _llvm_get_library_rule(ctx, prx, "llvm_mips_disassembler",
                "LLVMMipsDisassembler",
                ["llvm_mc_disassembler", "llvm_mips_info", "llvm_support"]),
        "%{LLVM_MIPS_INFO_LIB}":
            _llvm_get_library_rule(ctx, prx, "llvm_mips_info",
                "LLVMMipsInfo",
                ["llvm_support"]),
        "%{LLVM_MSP430_ASMPARSER_LIB}":
            _llvm_get_library_rule(ctx, prx, "llvm_msp430_asm_parser",
                "LLVMMSP430AsmParser",
                ["llvm_mc", "llvm_mc_parser", "llvm_msp430_desc",
                 "llvm_msp430_info", "llvm_support"]),
        "%{LLVM_MSP430_CODEGEN_LIB}":
            _llvm_get_library_rule(ctx, prx, "llvm_msp430_code_gen",
                "LLVMMSP430CodeGen",
                ["llvm_asm_printer", "llvm_code_gen", "llvm_core",
                 "llvm_mc", "llvm_msp430_desc", "llvm_msp430_info",
                 "llvm_selection_dag", "llvm_support", "llvm_target"]),
        "%{LLVM_MSP430_DESC_LIB}":
            _llvm_get_library_rule(ctx, prx, "llvm_msp430_desc",
                "LLVMMSP430Desc",
                ["llvm_mc", "llvm_msp430_info", "llvm_support"]),
        "%{LLVM_MSP430_DISASSEMBLER_LIB}":
            _llvm_get_library_rule(ctx, prx, "llvm_msp430_disassembler",
                "LLVMMSP430Disassembler",
                ["llvm_mc_disassembler", "llvm_msp430_info",
                "llvm_support"]),
        "%{LLVM_MSP430_INFO_LIB}":
            _llvm_get_library_rule(ctx, prx, "llvm_msp430_info",
                "LLVMMSP430Info",
                ["llvm_support"]),
        "%{LLVM_NVPTX_CODEGEN_LIB}":
            _llvm_get_library_rule(ctx, prx, "llvm_nvptx_code_gen",
                "LLVMNVPTXCodeGen",
                ["llvm_analysis", "llvm_asm_printer", "llvm_code_gen",
                 "llvm_core", "llvm_mc", "llvm_nvptx_desc",
                 "llvm_nvptx_info", "llvm_scalar", "llvm_selection_dag",
                 "llvm_support", "llvm_target", "llvm_transform_utils",
                 "llvm_vectorize", "llvm_ipo"]),
        "%{LLVM_NVPTX_DESC_LIB}":
            _llvm_get_library_rule(ctx, prx, "llvm_nvptx_desc",
                "LLVMNVPTXDesc",
                ["llvm_mc", "llvm_nvptx_info", "llvm_support"]),
        "%{LLVM_NVPTX_INFO_LIB}":
            _llvm_get_library_rule(ctx, prx, "llvm_nvptx_info",
                "LLVMNVPTXInfo",
                ["llvm_support"]),
        "%{LLVM_POWERPC_ASMPARSER_LIB}":
            _llvm_get_library_rule(ctx, prx, "llvm_powerpc_asm_parser",
                "LLVMPowerPCAsmParser",
                ["llvm_mc", "llvm_mc_parser", "llvm_powerpc_desc",
                 "llvm_powerpc_info", "llvm_support"]),
        "%{LLVM_POWERPC_CODEGEN_LIB}":
            _llvm_get_library_rule(ctx, prx, "llvm_powerpc_code_gen",
                "LLVMPowerPCCodeGen",
                ["llvm_analysis", "llvm_asm_printer", "llvm_code_gen",
                 "llvm_core", "llvm_mc", "llvm_powerpc_desc",
                 "llvm_powerpc_info", "llvm_scalar", "llvm_selection_dag",
                 "llvm_support", "llvm_target", "llvm_transform_utils"]),
        "%{LLVM_POWERPC_DESC_LIB}":
            _llvm_get_library_rule(ctx, prx, "llvm_powerpc_desc",
                "LLVMPowerPCDesc",
                ["llvm_binary_format", "llvm_mc", "llvm_powerpc_info",
                 "llvm_support"]),
        "%{LLVM_POWERPC_DISASSEMBLER_LIB}":
            _llvm_get_library_rule(ctx, prx, "llvm_powerpc_disassembler",
                "LLVMPowerPCDisassembler",
                ["llvm_mc_disassembler", "llvm_powerpc_info", "llvm_support"]),
        "%{LLVM_POWERPC_INFO_LIB}":
            _llvm_get_library_rule(ctx, prx, "llvm_powerpc_info",
                "LLVMPowerPCInfo",
                ["llvm_support"]),
        "%{LLVM_RISCV_ASMPARSER_LIB}":
            _llvm_get_library_rule(ctx, prx, "llvm_riscv_asm_parser",
                "LLVMRISCVAsmParser",
                ["llvm_mc", "llvm_mc_parser", "llvm_riscv_desc",
                 "llvm_riscv_info", "llvm_riscv_utils", "llvm_support"]),
        "%{LLVM_RISCV_CODEGEN_LIB}":
            _llvm_get_library_rule(ctx, prx, "llvm_riscv_code_gen",
                "LLVMRISCVCodeGen",
                ["llvm_analysis", "llvm_asm_printer", "llvm_code_gen",
                 "llvm_core", "llvm_global_i_sel", "llvm_mc",
                 "llvm_riscv_desc", "llvm_riscv_info", "llvm_riscv_utils",
                 "llvm_selection_dag", "llvm_support", "llvm_target"]),
        "%{LLVM_RISCV_DESC_LIB}":
            _llvm_get_library_rule(ctx, prx, "llvm_riscv_desc",
                "LLVMRISCVDesc",
                ["llvm_mc", "llvm_riscv_info", "llvm_riscv_utils",
                 "llvm_support"]),
        "%{LLVM_RISCV_DISASSEMBLER_LIB}":
            _llvm_get_library_rule(ctx, prx, "llvm_riscv_disassembler",
                "LLVMRISCVDisassembler",
                ["llvm_mc_disassembler", "llvm_riscv_info", "llvm_support"]),
        "%{LLVM_RISCV_INFO_LIB}":
            _llvm_get_library_rule(ctx, prx, "llvm_riscv_info",
                "LLVMRISCVInfo",
                ["llvm_support"]),
        "%{LLVM_RISCV_UTILS_LIB}":
            _llvm_get_library_rule(ctx, prx, "llvm_riscv_utils",
                "LLVMRISCVUtils",
                ["llvm_support"]),
        "%{LLVM_SPARC_ASMPARSER_LIB}":
            _llvm_get_library_rule(ctx, prx, "llvm_sparc_asm_parser",
                "LLVMSparcAsmParser",
                ["llvm_mc", "llvm_mc_parser", "llvm_sparc_desc",
                 "llvm_sparc_info", "llvm_support"]),
        "%{LLVM_SPARC_CODEGEN_LIB}":
            _llvm_get_library_rule(ctx, prx, "llvm_sparc_code_gen",
                "LLVMSparcCodeGen",
                ["llvm_asm_printer", "llvm_code_gen", "llvm_core", "llvm_mc",
                 "llvm_selection_dag", "llvm_sparc_desc", "llvm_sparc_info",
                 "llvm_support", "llvm_target"]),
        "%{LLVM_SPARC_DESC_LIB}":
            _llvm_get_library_rule(ctx, prx, "llvm_sparc_desc",
                "LLVMSparcDesc",
                ["llvm_mc", "llvm_sparc_info", "llvm_support"]),
        "%{LLVM_SPARC_DISASSEMBLER_LIB}":
            _llvm_get_library_rule(ctx, prx, "llvm_sparc_disassembler",
                "LLVMSparcDisassembler",
                ["llvm_mc_disassembler", "llvm_sparc_info", "llvm_support"]),
        "%{LLVM_SPARC_INFO_LIB}":
            _llvm_get_library_rule(ctx, prx, "llvm_sparc_info",
                "LLVMSparcInfo",
                ["llvm_support"]),
        "%{LLVM_SYSTEMZ_ASMPARSER_LIB}":
            _llvm_get_library_rule(ctx, prx, "llvm_system_z_asm_parser",
                "LLVMSystemZAsmParser",
                ["llvm_mc", "llvm_mc_parser", "llvm_support",
                 "llvm_system_z_desc", "llvm_system_z_info"]),
        "%{LLVM_SYSTEMZ_CODEGEN_LIB}":
            _llvm_get_library_rule(ctx, prx, "llvm_system_z_code_gen",
                "LLVMSystemZCodeGen",
                ["llvm_analysis", "llvm_asm_printer", "llvm_code_gen",
                 "llvm_core", "llvm_mc", "llvm_scalar",
                 "llvm_selection_dag", "llvm_support", "llvm_system_z_desc",
                 "llvm_system_z_info", "llvm_target"]),
        "%{LLVM_SYSTEMZ_DESC_LIB}":
            _llvm_get_library_rule(ctx, prx, "llvm_system_z_desc",
                "LLVMSystemZDesc",
                ["llvm_mc", "llvm_support", "llvm_system_z_info"]),
        "%{LLVM_SYSTEMZ_DISASSEMBLER_LIB}":
            _llvm_get_library_rule(ctx, prx, "llvm_system_z_disassembler",
                "LLVMSystemZDisassembler",
                ["llvm_mc", "llvm_mc_disassembler", "llvm_support",
                 "llvm_system_z_desc", "llvm_system_z_info"]),
        "%{LLVM_SYSTEMZ_INFO_LIB}":
            _llvm_get_library_rule(ctx, prx, "llvm_system_z_info",
                "LLVMSystemZInfo",
                ["llvm_support"]),
        "%{LLVM_WEBASSEMBLY_ASMPARSER_LIB}":
            _llvm_get_library_rule(ctx, prx, "llvm_web_assembly_asm_parser",
                "LLVMWebAssemblyAsmParser",
                ["llvm_mc", "llvm_mc_parser", "llvm_support",
                 "llvm_web_assembly_info"]),
        "%{LLVM_WEBASSEMBLY_CODEGEN_LIB}":
            _llvm_get_library_rule(ctx, prx, "llvm_web_assembly_code_gen",
                "LLVMWebAssemblyCodeGen",
                ["llvm_analysis", "llvm_asm_printer", "llvm_binary_format",
                 "llvm_code_gen", "llvm_core", "llvm_mc", "llvm_scalar",
                 "llvm_selection_dag", "llvm_support", "llvm_target",
                 "llvm_transform_utils", "llvm_web_assembly_desc",
                 "llvm_web_assembly_info"]),
        "%{LLVM_WEBASSEMBLY_DESC_LIB}":
            _llvm_get_library_rule(ctx, prx, "llvm_web_assembly_desc",
                "LLVMWebAssemblyDesc",
                ["llvm_mc", "llvm_support", "llvm_web_assembly_info"]),
        "%{LLVM_WEBASSEMBLY_DISASSEMBLER_LIB}":
            _llvm_get_library_rule(ctx, prx, "llvm_web_assembly_disassembler",
                "LLVMWebAssemblyDisassembler",
                ["llvm_mc", "llvm_mc_disassembler", "llvm_support",
                 "llvm_web_assembly_desc", "llvm_web_assembly_info"]),
        "%{LLVM_WEBASSEMBLY_INFO_LIB}":
            _llvm_get_library_rule(ctx, prx, "llvm_web_assembly_info",
                "LLVMWebAssemblyInfo",
                ["llvm_support"]),
        "%{LLVM_X86_ASMPARSER_LIB}":
            _llvm_get_library_rule(ctx, prx, "llvm_x86_asm_parser",
                "LLVMX86AsmParser",
                ["llvm_mc", "llvm_mc_parser", "llvm_support", "llvm_x86_desc",
                 "llvm_x86_info"]),
        "%{LLVM_X86_CODEGEN_LIB}":
            _llvm_get_library_rule(ctx, prx, "llvm_x86_code_gen",
                "LLVMX86CodeGen",
                ["llvm_analysis", "llvm_asm_printer", "llvm_cf_guard",
                 "llvm_code_gen", "llvm_core", "llvm_global_i_sel", "llvm_mc",
                 "llvm_profile_data", "llvm_selection_dag", "llvm_support",
                 "llvm_target", "llvm_x86_desc", "llvm_x86_info"]),
        "%{LLVM_X86_DESC_LIB}":
            _llvm_get_library_rule(ctx, prx, "llvm_x86_desc",
                "LLVMX86Desc",
                ["llvm_binary_format", "llvm_mc", "llvm_mc_disassembler",
                 "llvm_support", "llvm_x86_info"]),
        "%{LLVM_X86_DISASSEMBLER_LIB}":
            _llvm_get_library_rule(ctx, prx, "llvm_x86_disassembler",
                "LLVMX86Disassembler",
                ["llvm_mc_disassembler", "llvm_support", "llvm_x86_info"]),
        "%{LLVM_X86_INFO_LIB}":
            _llvm_get_library_rule(ctx, prx, "llvm_x86_info",
                "LLVMX86Info",
                ["llvm_support"]),
        "%{LLVM_XCORE_CODEGEN_LIB}":
            _llvm_get_library_rule(ctx, prx, "llvm_x_core_code_gen",
                "LLVMXCoreCodeGen",
                ["llvm_analysis", "llvm_asm_printer", "llvm_code_gen",
                 "llvm_core", "llvm_mc", "llvm_selection_dag", "llvm_support",
                 "llvm_target", "llvm_transform_utils", "llvm_x_core_desc",
                 "llvm_x_core_info"]),
        "%{LLVM_XCORE_DESC_LIB}":
            _llvm_get_library_rule(ctx, prx, "llvm_x_core_desc",
                "LLVMXCoreDesc",
                ["llvm_mc", "llvm_support", "llvm_x_core_info"]),
        "%{LLVM_XCORE_DISASSEMBLER_LIB}":
            _llvm_get_library_rule(ctx, prx, "llvm_x_core_disassembler",
                "LLVMXCoreDisassembler",
                ["llvm_mc_disassembler", "llvm_support", "llvm_x_core_info"]),
        "%{LLVM_XCORE_INFO_LIB}":
            _llvm_get_library_rule(ctx, prx, "llvm_x_core_info",
                "LLVMXCoreInfo",
                ["llvm_support"]),
        "%{LLVM_CONFIG_GENRULE}":
            _llvm_get_config_genrule(ctx, prx, "llvm_config_files",
                "generated/include", "llvm_config.h"),
        "%{LLVM_CONFIG_LIB}":
            _llvm_get_config_library_rule(ctx, prx, "llvm_config_headers",
                "llvm_config_files", "generated/include"),

        "%{LIBCXX_STATIC_LIB}":
            _llvm_get_library_rule(ctx, prx, "libcxx_static", "c++",
                (["libcxx_headers"] if add_hdrs else [])),
        "%{LIBCXX_SHARED_LIB}":
            _llvm_get_shared_library_rule(ctx, prx, "libcxx_shared", "c++"),
        "%{LIBCXX_SHARED_COPY_GENRULE}":
            _llvm_get_shared_lib_genrule(ctx, prx, "libcxx_copy_shared",
                llvm_path, "c++"),
        "%{LIBCXX_ABI_STATIC_LIB}":
            _llvm_get_library_rule(ctx, prx, "libcxx_abi_static", "c++abi",
                (["libcxx_headers"] if add_hdrs else [])),
        "%{LIBCXX_ABI_SHARED_LIB}":
            _llvm_get_shared_library_rule(ctx, prx, "libcxx_abi_shared",
                "c++abi"),
        "%{LIBCXX_ABI_SHARED_COPY_GENRULE}":
            _llvm_get_shared_lib_genrule(ctx, prx, "libcxx_copy_abi_shared",
                llvm_path, "c++abi"),

        "%{MLIR_AFFINEOPS_LIB}":
            _llvm_get_library_rule(ctx, prx, "mlir_affine_ops",
                "MLIRAffineOps",
                ["mlir_edsc", "mlir_ir", "mlir_loop_like_interface",
                 "mlir_side_effect_interfaces", "mlir_standard_ops",
                 "llvm_support"] +
                  (["mlir_headers", "llvm_headers"] if add_hdrs else [])),
        "%{MLIR_AFFINEEDSC_LIB}":
            _llvm_get_library_rule(ctx, prx, "mlir_affine_edsc",
                "MLIRAffineEDSC",
                ["mlir_affine_ops", "mlir_edsc", "mlir_ir",
                 "mlir_loop_like_interface", "mlir_side_effect_interfaces",
                 "mlir_standard_ops", "llvm_support"] +
                  (["mlir_headers", "llvm_headers"] if add_hdrs else [])),
        "%{MLIR_AFFINETRANSFORMS_LIB}":
            _llvm_get_library_rule(ctx, prx, "mlir_affine_transforms",
                "MLIRAffineTransforms",
                ["mlir_affine_ops", "mlir_edsc", "mlir_ir", "mlir_pass",
                 "mlir_side_effect_interfaces", "mlir_standard_ops",
                 "mlir_transform_utils", "mlir_vector", "mlir_vector_to_llvm",
                 "llvm_support"] +
                  (["mlir_headers", "llvm_headers"] if add_hdrs else [])),
        "%{MLIR_AFFINETRANSFORMSTESTPASSES_LIB}":
            _llvm_get_library_rule(ctx, prx,
                "mlir_affine_transforms_test_passes",
                "MLIRAffineTransformsTestPasses",
                ["mlir_ir", "mlir_pass", "mlir_affine_transforms",
                 "mlir_support", "mlir_affine_utils", "llvm_core",
                 "llvm_support"] +
                  (["mlir_headers", "llvm_headers"] if add_hdrs else [])),
        "%{MLIR_AFFINETOSTANDARD_LIB}":
            _llvm_get_library_rule(ctx, prx, "mlir_affine_to_standard",
                "MLIRAffineToStandard",
                ["mlir_affine_ops", "mlir_scf", "mlir_pass", "mlir_standard_ops",
                 "mlir_transforms", "mlir_ir", "llvm_core", "llvm_support"] +
                  (["mlir_headers", "llvm_headers"] if add_hdrs else [])),
        "%{MLIR_AFFINEUTILS_LIB}":
            _llvm_get_library_rule(ctx, prx, "mlir_affine_utils",
                "MLIRAffineUtils",
                ["mlir_affine_ops", "mlir_transform_utils", "llvm_support"] +
                  (["mlir_headers", "llvm_headers"] if add_hdrs else [])),
        "%{MLIR_ANALYSIS_LIB}":
            _llvm_get_library_rule(ctx, prx, "mlir_analysis",
                "MLIRAnalysis",
                ["mlir_affine_ops", "mlir_call_interfaces",
                 "mlir_control_flow_interfaces", "mlir_infer_type_op_interface",
                 "mlir_scf", "llvm_support"] +
                  (["mlir_headers", "llvm_headers"] if add_hdrs else [])),
        "%{MLIR_AVX512_LIB}":
            _llvm_get_library_rule(ctx, prx, "mlir_avx512",
                "MLIRAVX512",
                ["mlir_ir", "mlir_side_effect_interfaces",
                 "mlir_vector_to_llvm", "llvm_support"] +
                  (["mlir_headers", "llvm_headers"] if add_hdrs else [])),
        "%{MLIR_AVX512TOLLVM_LIB}":
            _llvm_get_library_rule(ctx, prx, "mlir_avx512_to_llvm",
                "MLIRAVX512ToLLVM",
                ["mlir_avx512", "mlir_llvm_avx512", "mlir_llvm_ir",
                 "mlir_standard_to_llvm", "mlir_transforms", "llvm_core",
                 "llvm_support"] +
                  (["mlir_headers", "llvm_headers"] if add_hdrs else [])),
        "%{MLIR_C_RUNNERUTILS_LIB}":
            _llvm_get_shared_library_rule(ctx, prx, "mlir_c_runner_utils",
                "mlir_c_runner_utils",
                ["mlir_headers", "llvm_headers"] if add_hdrs else []),
        "%{MLIR_C_RUNNERUTILS_COPY_GENRULE}":
            _llvm_get_shared_lib_genrule(ctx, prx, "mlir_copy_c_runner_utils",
                llvm_path, "mlir_c_runner_utils"),
        "%{MLIR_C_RUNNERUTILS_STATIC_LIB}":
            _llvm_get_library_rule(ctx, prx, "mlir_c_runner_utils_static",
                "mlir_c_runner_utils_static", ["llvm_support"] +
                  (["mlir_headers", "llvm_headers"] if add_hdrs else [])),
        "%{MLIR_CALLINTERFACES_LIB}":
            _llvm_get_library_rule(ctx, prx, "mlir_call_interfaces",
                "MLIRCallInterfaces",
                ["mlir_ir", "llvm_support"] +
                  (["mlir_headers", "llvm_headers"] if add_hdrs else [])),
        "%{MLIR_CONTROLFLOWINTERFACES_LIB}":
            _llvm_get_library_rule(ctx, prx, "mlir_control_flow_interfaces",
                "MLIRControlFlowInterfaces",
                ["mlir_ir", "llvm_support"] +
                  (["mlir_headers", "llvm_headers"] if add_hdrs else [])),
        "%{MLIR_DERIVEDATTRIBUTEOPINTERFACE_LIB}":
            _llvm_get_library_rule(ctx, prx, "mlir_derived_attribute_op_interface",
                "MLIRDerivedAttributeOpInterface",
                ["mlir_ir", "llvm_support"] +
                  (["mlir_headers", "llvm_headers"] if add_hdrs else [])),
        "%{MLIR_DIALECT_LIB}":
            _llvm_get_library_rule(ctx, prx, "mlir_dialect",
                "MLIRDialect", ["mlir_ir", "llvm_support"] +
                  (["mlir_headers", "llvm_headers"] if add_hdrs else [])),
        "%{MLIR_EDSC_LIB}":
            _llvm_get_library_rule(ctx, prx, "mlir_edsc",
                "MLIREDSC",
                ["mlir_ir", "mlir_support", "llvm_support"] +
                  (["mlir_headers", "llvm_headers"] if add_hdrs else [])),
        "%{MLIR_EDSCINTERFACE_LIB}":
            _llvm_get_library_rule(ctx, prx, "mlir_edsc_interface",
                "MLIREDSCInterface",
                ["mlir_ir", "mlir_support", "mlir_parser", "llvm_support"] +
                  (["mlir_headers", "llvm_headers"] if add_hdrs else [])),
        "%{MLIR_EXECUTIONENGINE_LIB}":
            _llvm_get_library_rule(ctx, prx, "mlir_execution_engine",
                "MLIRExecutionEngine",
                ["mlir_llvm_ir", "mlir_target_llvm_ir",
                 "llvm_core", "llvm_execution_engine", "llvm_object",
                 "llvm_orc_jit", "llvm_jit_link", "llvm_analysis",
                 "llvm_aggressive_inst_combine", "llvm_inst_combine",
                 "llvm_mc", "llvm_scalar", "llvm_target",
                 "llvm_vectorize", "llvm_transform_utils",
                 "llvm_ipo", "llvm_support"] +
                  (["llvm_x86_code_gen", "llvm_x86_desc", "llvm_x86_info"]
                     if "X86" in supported_targets else []) +
                  (["mlir_headers", "llvm_headers"] if add_hdrs else [])),
        "%{MLIR_GPU_LIB}":
            _llvm_get_library_rule(ctx, prx, "mlir_gpu",
                "MLIRGPU",
                ["mlir_edsc", "mlir_ir", "mlir_llvm_ir", "mlir_scf",
                 "mlir_pass", "mlir_side_effect_interfaces",
                 "mlir_standard_ops", "mlir_support",
                 "mlir_transform_utils", "llvm_support"] +
                  (["mlir_headers", "llvm_headers"] if add_hdrs else [])),
        "%{MLIR_GPUTOGPURUNTIMETRANSFORMS_LIB}":
            _llvm_get_library_rule(ctx, prx, "mlir_gpu_to_gpu_runtime_transforms",
                "MLIRGPUtoGPURuntimeTransforms",
                ["mlir_gpu", "mlir_ir", "mlir_llvm_ir", "mlir_pass",
                 "mlir_support", "llvm_core", "llvm_mc", "llvm_support"] +
                  (["llvm_amdgpu_code_gen", "llvm_amdgpu_desc",
                    "llvm_amdgpu_info"] if "AMDGPU" in supported_targets else []) +
                  (["llvm_nvptx_code_gen", "llvm_nvptx_desc",
                    "llvm_nvptx_info"] if "NVPTX" in supported_targets else []) +
                  (["mlir_headers", "llvm_headers"] if add_hdrs else [])),
        "%{MLIR_GPUTONVVMTRANSFORMS_LIB}":
            _llvm_get_library_rule(ctx, prx, "mlir_gpu_to_nvvm_transforms",
                "MLIRGPUtoNVVMTransforms",
                ["mlir_gpu", "mlir_llvm_ir", "mlir_nvvm_ir", "mlir_pass",
                 "mlir_standard_to_llvm", "mlir_transform_utils",
                 "llvm_support"] +
                  (["mlir_headers", "llvm_headers"] if add_hdrs else [])),
        "%{MLIR_GPUTOROCDLTRANSFORMS_LIB}":
            _llvm_get_library_rule(ctx, prx, "mlir_gpu_to_rocdl_transforms",
                "MLIRGPUtoROCDLTransforms",
                ["mlir_gpu", "mlir_llvm_ir", "mlir_rocdl_ir", "mlir_pass",
                 "mlir_standard_to_llvm", "llvm_support"] +
                  (["mlir_headers", "llvm_headers"] if add_hdrs else [])),
        "%{MLIR_GPUTOSPIRVTRANSFORMS_LIB}":
            _llvm_get_library_rule(ctx, prx, "mlir_gpu_to_spirv_transforms",
                "MLIRGPUtoSPIRVTransforms",
                ["mlir_gpu", "mlir_ir", "mlir_pass", "mlir_spirv",
                 "mlir_standard_ops", "mlir_standard_to_spirv_transforms",
                 "mlir_support", "mlir_transforms", "llvm_support"] +
                  (["mlir_headers", "llvm_headers"] if add_hdrs else [])),
        "%{MLIR_GPUTOVULKANTRANSFORMS_LIB}":
            _llvm_get_library_rule(ctx, prx, "mlir_gpu_to_vulkan_transforms",
                "MLIRGPUtoVulkanTransforms",
                ["mlir_gpu", "mlir_ir", "mlir_llvm_ir", "mlir_pass",
                 "mlir_spirv", "mlir_spirv_serialization", "mlir_standard_ops",
                 "mlir_support", "mlir_transforms", "mlir_translation",
                 "llvm_support"] +
                  (["mlir_headers", "llvm_headers"] if add_hdrs else [])),
        "%{MLIR_INFERTYPEOPINTERFACE_LIB}":
            _llvm_get_library_rule(ctx, prx, "mlir_infer_type_op_interface",
                "MLIRInferTypeOpInterface",
                ["mlir_ir", "llvm_support"] +
                  (["mlir_headers", "llvm_headers"] if add_hdrs else [])),
        "%{MLIR_IR_LIB}":
            _llvm_get_library_rule(ctx, prx, "mlir_ir",
                "MLIRIR",
                ["mlir_support", "llvm_support"] +
                  (["mlir_headers", "llvm_headers"] if add_hdrs else [])),
        "%{MLIR_JITRUNNER_LIB}":
            _llvm_get_library_rule(ctx, prx, "mlir_jit_runner",
                "MLIRJitRunner",
                ["mlir_execution_engine", "mlir_ir", "mlir_parser",
                 "mlir_standard_ops", "mlir_target_llvm_ir",
                 "mlir_transforms", "mlir_standard_to_llvm",
                 "mlir_support", "llvm_core", "llvm_orc_jit",
                 "llvm_jit_link", "llvm_support"] +
                  (["mlir_headers", "llvm_headers"] if add_hdrs else [])),
        "%{MLIR_LINALGANALYSIS_LIB}":
            _llvm_get_library_rule(ctx, prx, "mlir_linalg_analysis",
                "MLIRLinalgAnalysis",
                ["mlir_ir", "mlir_linalg_ops", "mlir_standard_ops",
                 "llvm_support"] +
                 (["mlir_headers", "llvm_headers"] if add_hdrs else [])),
        "%{MLIR_LINALGEDSC_LIB}":
            _llvm_get_library_rule(ctx, prx, "mlir_linalg_edsc",
                "MLIRLinalgEDSC",
                ["mlir_edsc", "mlir_ir", "mlir_affine_ops", "mlir_affine_edsc",
                 "mlir_linalg_ops", "mlir_scf", "mlir_standard_ops",
                 "llvm_support"] +
                 (["mlir_headers", "llvm_headers"] if add_hdrs else [])),
        "%{MLIR_LINALGOPS_LIB}":
            _llvm_get_library_rule(ctx, prx, "mlir_linalg_ops",
                "MLIRLinalgOps",
                ["mlir_ir", "mlir_side_effect_interfaces",
                 "mlir_view_like_interface", "mlir_standard_ops",
                 "llvm_support"] +
                 (["mlir_headers", "llvm_headers"] if add_hdrs else [])),
        "%{MLIR_LINALGTOLLVM_LIB}":
            _llvm_get_library_rule(ctx, prx, "mlir_linalg_to_llvm",
                "MLIRLinalgToLLVM",
                ["mlir_affine_to_standard", "mlir_edsc", "mlir_ir",
                 "mlir_linalg_ops", "mlir_llvm_ir", "mlir_scf_to_standard",
                 "mlir_standard_to_llvm", "mlir_transforms",
                 "mlir_vector_to_llvm", "mlir_vector_to_scf",
                 "llvm_core", "llvm_support"] +
                  (["mlir_headers", "llvm_headers"] if add_hdrs else [])),
        "%{MLIR_LINALGTOSPIRVTRANSFORMS_LIB}":
            _llvm_get_library_rule(ctx, prx, "mlir_linalg_to_spirv_transforms",
                "MLIRLinalgToSPIRVTransforms",
                ["mlir_ir", "mlir_linalg_ops", "mlir_linalg_utils",
                 "mlir_pass", "mlir_spirv", "mlir_support", "llvm_support"] +
                  (["mlir_headers", "llvm_headers"] if add_hdrs else [])),
        "%{MLIR_LINALGTOSTANDARD_LIB}":
            _llvm_get_library_rule(ctx, prx, "mlir_linalg_to_standard",
                "MLIRLinalgToStandard",
                ["mlir_edsc", "mlir_ir", "mlir_linalg_ops", "mlir_pass",
                 "mlir_scf", "mlir_transforms", "llvm_core", "llvm_support"] +
                  (["mlir_headers", "llvm_headers"] if add_hdrs else [])),
        "%{MLIR_LINALGTRANSFORMS_LIB}":
            _llvm_get_library_rule(ctx, prx, "mlir_linalg_transforms",
                "MLIRLinalgTransforms",
                ["mlir_affine_ops", "mlir_analysis", "mlir_edsc", "mlir_ir",
                 "mlir_linalg_analysis", "mlir_linalg_edsc", "mlir_linalg_ops",
                 "mlir_linalg_utils", "mlir_scf", "mlir_scf_transforms",
                 "mlir_pass", "mlir_standard_ops", "mlir_standard_to_llvm",
                 "mlir_transform_utils", "mlir_vector", "llvm_support"] +
                 (["mlir_headers", "llvm_headers"] if add_hdrs else [])),
        "%{MLIR_LINALGUTILS_LIB}":
            _llvm_get_library_rule(ctx, prx, "mlir_linalg_utils",
                "MLIRLinalgUtils",
                ["mlir_affine_ops", "mlir_edsc", "mlir_ir", "mlir_linalg_edsc",
                 "mlir_linalg_ops", "mlir_scf", "mlir_pass", "mlir_standard_ops",
                 "mlir_transform_utils", "llvm_support"] +
                 (["mlir_headers", "llvm_headers"] if add_hdrs else [])),
        "%{MLIR_LLVMAVX512_LIB}":
            _llvm_get_library_rule(ctx, prx, "mlir_llvm_avx512",
                "MLIRLLVMAVX512",
                ["mlir_ir", "mlir_llvm_ir", "mlir_side_effect_interfaces",
                 "llvm_asm_parser", "llvm_core", "llvm_support"] +
                  (["mlir_headers", "llvm_headers"] if add_hdrs else [])),
        "%{MLIR_LLVMIR_LIB}":
            _llvm_get_library_rule(ctx, prx, "mlir_llvm_ir",
                "MLIRLLVMIR",
                ["mlir_call_interfaces", "mlir_control_flow_interfaces",
                 "mlir_open_mp", "mlir_ir", "mlir_side_effect_interfaces",
                 "mlir_support", "llvm_asm_parser", "llvm_bit_reader",
                 "llvm_bit_writer", "llvm_core", "llvm_frontend_open_mp",
                 "llvm_support"] +
                  (["mlir_headers", "llvm_headers"] if add_hdrs else [])),
        "%{MLIR_LLVMIRTRANSFORMS_LIB}":
            _llvm_get_library_rule(ctx, prx, "mlir_llvm_ir_transforms",
                "MLIRLLVMIRTransforms",
                ["mlir_ir", "mlir_llvm_ir", "mlir_pass", "llvm_support"] +
                  (["mlir_headers", "llvm_headers"] if add_hdrs else [])),
        "%{MLIR_LOOPANALYSIS_LIB}":
            _llvm_get_library_rule(ctx, prx, "mlir_loop_analysis",
                "MLIRLoopAnalysis",
                ["mlir_affine_ops", "mlir_call_interfaces",
                 "mlir_control_flow_interfaces", "mlir_infer_type_op_interface",
                 "mlir_scf", "llvm_support"] +
                  (["mlir_headers", "llvm_headers"] if add_hdrs else [])),
        "%{MLIR_LOOPLIKEINTERFACE_LIB}":
            _llvm_get_library_rule(ctx, prx, "mlir_loop_like_interface",
                "MLIRLoopLikeInterface",
                ["mlir_ir", "llvm_support"] +
                  (["mlir_headers", "llvm_headers"] if add_hdrs else [])),
        "%{MLIR_MLIROPTMAIN_LIB}":
            _llvm_get_library_rule(ctx, prx, "mlir_mlir_opt_main",
                "MLIRMlirOptMain",
                ["mlir_affine_ops", "mlir_affine_edsc",
                 "mlir_affine_transforms", "mlir_affine_utils",
                 "mlir_avx512", "mlir_gpu", "mlir_linalg_analysis",
                 "mlir_linalg_edsc", "mlir_linalg_ops",
                 "mlir_linalg_transforms", "mlir_linalg_utils",
                 "mlir_llvm_ir_transforms", "mlir_llvm_ir",
                 "mlir_llvm_avx512", "mlir_nvvm_ir", "mlir_rocdl_ir",
                 "mlir_open_mp", "mlir_quant", "mlir_scf",
                 "mlir_scf_transforms", "mlir_sdbm", "mlir_shape",
                 "mlir_spirv", "mlir_spirv_serialization",
                 "mlir_spirv_transforms", "mlir_standard_ops",
                 "mlir_standard_ops_transforms", "mlir_vector",
                 "mlir_affine_to_standard", "mlir_avx512_to_llvm",
                 "mlir_gpu_to_gpu_runtime_transforms",
                 "mlir_gpu_to_nvvm_transforms",
                 "mlir_gpu_to_rocdl_transforms",
                 "mlir_gpu_to_spirv_transforms",
                 "mlir_gpu_to_vulkan_transforms",
                 "mlir_linalg_to_llvm", "mlir_linalg_to_spirv_transforms",
                 "mlir_linalg_to_standard", "mlir_scf_to_gpu",
                 "mlir_scf_to_standard", "mlir_shape_to_standard",
                 "mlir_standard_to_llvm", "mlir_standard_to_spirv_transforms",
                 "mlir_vector_to_llvm", "mlir_vector_to_scf",
                 "mlir_affine_transforms_test_passes",
                 "mlir_spirv_test_passes", "mlir_test_dialect",
                 "mlir_test_ir", "mlir_test_pass", "mlir_test_transforms",
                 "mlir_loop_analysis", "mlir_analysis", "mlir_dialect",
                 "mlir_edsc", "mlir_opt_lib", "mlir_parser", "mlir_pass",
                 "mlir_transforms", "mlir_transform_utils",
                 "mlir_support", "mlir_ir", "llvm_core",
                 "llvm_asm_parser", "llvm_support"] +
                  (["mlir_headers", "llvm_headers"] if add_hdrs else [])),
        "%{MLIR_NVVMIR_LIB}":
            _llvm_get_library_rule(ctx, prx, "mlir_nvvm_ir",
                "MLIRNVVMIR",
                ["mlir_ir", "mlir_llvm_ir", "mlir_side_effect_interfaces",
                 "llvm_asm_parser", "llvm_core", "llvm_support"] +
                  (["mlir_headers", "llvm_headers"] if add_hdrs else [])),
        "%{MLIR_OPENMP_LIB}":
            _llvm_get_library_rule(ctx, prx, "mlir_open_mp",
                "MLIROpenMP",
                ["mlir_ir", "llvm_support"] +
                  (["mlir_headers", "llvm_headers"] if add_hdrs else [])),
        "%{MLIR_OPTLIB_LIB}":
            _llvm_get_library_rule(ctx, prx, "mlir_opt_lib",
                "MLIROptLib",
                ["mlir_pass", "mlir_parser", "mlir_support",
                 "llvm_support"] +
                  (["mlir_headers", "llvm_headers"] if add_hdrs else [])),
        "%{MLIR_PARSER_LIB}":
            _llvm_get_library_rule(ctx, prx, "mlir_parser",
                "MLIRParser",
                ["mlir_ir", "llvm_support"] +
                  (["mlir_headers", "llvm_headers"] if add_hdrs else [])),
        "%{MLIR_PASS_LIB}":
            _llvm_get_library_rule(ctx, prx, "mlir_pass",
                "MLIRPass",
                ["mlir_analysis", "mlir_ir", "llvm_support"] +
                  (["mlir_headers", "llvm_headers"] if add_hdrs else [])),
        "%{MLIR_QUANT_LIB}":
            _llvm_get_library_rule(ctx, prx, "mlir_quant",
                "MLIRQuant",
                ["mlir_ir", "mlir_pass", "mlir_side_effect_interfaces",
                 "mlir_support", "mlir_standard_ops", "mlir_transform_utils",
                 "llvm_support"] +
                  (["mlir_headers", "llvm_headers"] if add_hdrs else [])),
        "%{MLIR_ROCDLIR_LIB}":
            _llvm_get_library_rule(ctx, prx, "mlir_rocdl_ir",
                "MLIRROCDLIR",
                ["mlir_ir", "mlir_side_effect_interfaces",
                 "mlir_vector_to_llvm", "llvm_asm_parser", "llvm_core",
                 "llvm_support"] +
                  (["mlir_headers", "llvm_headers"] if add_hdrs else [])),
        "%{MLIR_RUNNERUTILS_LIB}":
            _llvm_get_shared_library_rule(ctx, prx, "mlir_runner_utils",
                "mlir_runner_utils",
                ["mlir_c_runner_utils_static", "llvm_support"] +
                  (["mlir_headers", "llvm_headers"] if add_hdrs else [])),
        "%{MLIR_RUNNERUTILS_COPY_GENRULE}":
            _llvm_get_shared_lib_genrule(ctx, prx, "mlir_copy_runner_utils",
                llvm_path, "mlir_runner_utils"),
        "%{MLIR_SCF_LIB}":
            _llvm_get_library_rule(ctx, prx, "mlir_scf",
                "MLIRSCF",
                ["mlir_edsc", "mlir_ir", "mlir_loop_like_interface",
                 "mlir_side_effect_interfaces", "mlir_standard_ops",
                 "llvm_support"] +
                  (["mlir_headers", "llvm_headers"] if add_hdrs else [])),
        "%{MLIR_SCFTOGPU_LIB}":
            _llvm_get_library_rule(ctx, prx, "mlir_scf_to_gpu",
                "MLIRSCFToGPU",
                ["mlir_affine_ops", "mlir_affine_to_standard", "mlir_gpu",
                 "mlir_ir", "mlir_linalg_ops", "mlir_pass",
                 "mlir_standard_ops", "mlir_support", "mlir_transforms",
                 "llvm_support"] +
                  (["mlir_headers", "llvm_headers"] if add_hdrs else [])),
        "%{MLIR_SCFTOSTANDARD_LIB}":
            _llvm_get_library_rule(ctx, prx, "mlir_scf_to_standard",
                "MLIRSCFToStandard",
                ["mlir_scf", "mlir_transforms", "llvm_core", "llvm_support"] +
                  (["mlir_headers", "llvm_headers"] if add_hdrs else [])),
        "%{MLIR_SCFTRANSFORMS_LIB}":
            _llvm_get_library_rule(ctx, prx, "mlir_scf_transforms",
                "MLIRSCFTransforms",
                ["mlir_affine_ops", "mlir_ir", "mlir_pass", "mlir_scf",
                 "mlir_standard_ops", "mlir_support", "llvm_support"] +
                  (["mlir_headers", "llvm_headers"] if add_hdrs else [])),
        "%{MLIR_SDBM_LIB}":
            _llvm_get_library_rule(ctx, prx, "mlir_sdbm",
                "MLIRSDBM", ["mlir_ir", "llvm_support"] +
                  (["mlir_headers", "llvm_headers"] if add_hdrs else [])),
        "%{MLIR_SHAPE_LIB}":
            _llvm_get_library_rule(ctx, prx, "mlir_shape",
                "MLIRShape",
                ["mlir_control_flow_interfaces", "mlir_dialect",
                 "mlir_infer_type_op_interface", "mlir_ir",
                 "mlir_side_effect_interfaces", "llvm_support"] +
                  (["mlir_headers", "llvm_headers"] if add_hdrs else [])),
        "%{MLIR_SHAPETOSTANDARD_LIB}":
            _llvm_get_library_rule(ctx, prx, "mlir_shape_to_standard",
                "MLIRShapeToStandard",
                ["mlir_edsc", "mlir_ir", "mlir_shape", "mlir_pass",
                 "mlir_scf", "mlir_transforms", "llvm_core",
                 "llvm_support"] +
                  (["mlir_headers", "llvm_headers"] if add_hdrs else [])),
        "%{MLIR_SIDEEFFECTINTERFACES_LIB}":
            _llvm_get_library_rule(ctx, prx, "mlir_side_effect_interfaces",
                "MLIRSideEffectInterfaces",
                ["mlir_ir", "llvm_support"] +
                  (["mlir_headers", "llvm_headers"] if add_hdrs else [])),
        "%{MLIR_SPIRV_LIB}":
            _llvm_get_library_rule(ctx, prx, "mlir_spirv",
                "MLIRSPIRV",
                ["mlir_control_flow_interfaces", "mlir_ir",
                 "mlir_parser", "mlir_side_effect_interfaces",
                 "mlir_support", "mlir_transforms", "llvm_support"] +
                  (["mlir_headers", "llvm_headers"] if add_hdrs else [])),
        "%{MLIR_SPIRVSERIALIZATION_LIB}":
            _llvm_get_library_rule(ctx, prx, "mlir_spirv_serialization",
                "MLIRSPIRVSerialization",
                ["mlir_ir", "mlir_spirv", "mlir_support", "mlir_translation",
                 "llvm_support"] +
                  (["mlir_headers", "llvm_headers"] if add_hdrs else [])),
        "%{MLIR_SPIRVTESTPASSES_LIB}":
            _llvm_get_library_rule(ctx, prx, "mlir_spirv_test_passes",
                "MLIRSPIRVTestPasses",
                ["mlir_ir", "mlir_pass", "mlir_spirv", "mlir_support",
                 "llvm_support"] +
                  (["mlir_headers", "llvm_headers"] if add_hdrs else [])),
        "%{MLIR_SPIRVTRANSFORMS_LIB}":
            _llvm_get_library_rule(ctx, prx, "mlir_spirv_transforms",
                "MLIRSPIRVTransforms",
                ["mlir_pass", "mlir_spirv", "llvm_support"] +
                  (["mlir_headers", "llvm_headers"] if add_hdrs else [])),
        "%{MLIR_STANDARDOPS_LIB}":
            _llvm_get_library_rule(ctx, prx, "mlir_standard_ops",
                "MLIRStandardOps",
                ["mlir_call_interfaces", "mlir_control_flow_interfaces",
                 "mlir_edsc", "mlir_ir", "mlir_side_effect_interfaces",
                 "mlir_view_like_interface", "llvm_support"] +
                  (["mlir_headers", "llvm_headers"] if add_hdrs else [])),
        "%{MLIR_STANDARDOPSTRANSFORMS_LIB}":
            _llvm_get_library_rule(ctx, prx, "mlir_standard_ops_transforms",
                "MLIRStandardOpsTransforms",
                ["mlir_ir", "mlir_pass", "mlir_standard_ops",
                 "mlir_transforms", "llvm_support"] +
                  (["mlir_headers", "llvm_headers"] if add_hdrs else [])),
        "%{MLIR_STANDARDTOLLVM_LIB}":
            _llvm_get_library_rule(ctx, prx, "mlir_standard_to_llvm",
                "MLIRStandardToLLVM",
                ["mlir_llvm_ir", "mlir_transforms", "llvm_core",
                 "llvm_support"] +
                  (["mlir_headers", "llvm_headers"] if add_hdrs else [])),
        "%{MLIR_STANDARDTOSPIRVTRANSFORMS_LIB}":
            _llvm_get_library_rule(ctx, prx, "mlir_standard_to_spirv_transforms",
                "MLIRStandardToSPIRVTransforms",
                ["mlir_ir", "mlir_pass", "mlir_spirv", "mlir_support",
                 "mlir_transform_utils", "mlir_standard_ops", "llvm_support"] +
                  (["mlir_headers", "llvm_headers"] if add_hdrs else [])),
        "%{MLIR_SUPPORT_LIB}":
            _llvm_get_library_rule(ctx, prx, "mlir_support",
                "MLIRSupport",
                ["llvm_support"] +
                  (["mlir_headers", "llvm_headers"] if add_hdrs else [])),
        "%{MLIR_TABLEGEN_TOOL}":
            _llvm_get_executable_file_rule(ctx, prx, "mlir_tablegen_tool",
                "mlir-tblgen"),
        "%{MLIR_TARGETAVX512_LIB}":
            _llvm_get_library_rule(ctx, prx, "mlir_target_avx512",
                "MLIRTargetAVX512",
                ["mlir_ir", "mlir_llvm_avx512", "mlir_llvm_ir",
                 "mlir_target_llvm_ir_module_translation",
                 "llvm_core", "llvm_support"] +
                  (["mlir_headers", "llvm_headers"] if add_hdrs else [])),
        "%{MLIR_TARGETLLVMIR_LIB}":
            _llvm_get_library_rule(ctx, prx, "mlir_target_llvm_ir",
                "MLIRTargetLLVMIR",
                ["mlir_target_llvm_ir_module_translation",
                 "llvm_core", "llvm_ir_reader", "llvm_support"] +
                  (["mlir_headers", "llvm_headers"] if add_hdrs else [])),
        "%{MLIR_TARGETLLVMIRMODULETRANSLATION_LIB}":
            _llvm_get_library_rule(ctx, prx,
                "mlir_target_llvm_ir_module_translation",
                "MLIRTargetLLVMIRModuleTranslation",
                ["mlir_llvm_ir", "mlir_llvm_ir_transforms", "mlir_translation",
                 "llvm_core", "llvm_frontend_open_mp", "llvm_transform_utils",
                 "llvm_support", ] +
                  (["mlir_headers", "llvm_headers"] if add_hdrs else [])),
        "%{MLIR_TARGETNVVMIR_LIB}":
            _llvm_get_library_rule(ctx, prx, "mlir_target_nvvm_ir",
                "MLIRTargetNVVMIR",
                ["mlir_gpu", "mlir_ir", "mlir_llvm_ir", "mlir_nvvm_ir",
                 "mlir_target_llvm_ir_module_translation",
                 "llvm_core", "llvm_support"] +
                  (["mlir_headers", "llvm_headers"] if add_hdrs else [])),
        "%{MLIR_TARGETROCDLIR_LIB}":
            _llvm_get_library_rule(ctx, prx, "mlir_target_rocdl_ir",
                "MLIRTargetROCDLIR",
                ["mlir_gpu", "mlir_ir", "mlir_llvm_ir", "mlir_rocdl_ir",
                 "mlir_target_llvm_ir_module_translation",
                 "llvm_core", "llvm_support"] +
                  (["mlir_headers", "llvm_headers"] if add_hdrs else [])),
        "%{MLIR_TESTDIALECT_LIB}":
            _llvm_get_library_rule(ctx, prx, "mlir_test_dialect",
                "MLIRTestDialect",
                ["mlir_control_flow_interfaces",
                 "mlir_derived_attribute_op_interface", "mlir_dialect",
                 "mlir_ir", "mlir_infer_type_op_interface",
                 "mlir_linalg_transforms", "mlir_pass", "mlir_standard_ops",
                 "mlir_standard_ops_transforms", "mlir_transform_utils",
                 "mlir_transforms", "llvm_support"] +
                  (["mlir_headers", "llvm_headers"] if add_hdrs else [])),
        "%{MLIR_TESTIR_LIB}":
            _llvm_get_library_rule(ctx, prx, "mlir_test_ir",
                "MLIRTestIR",
                ["mlir_pass", "mlir_test_dialect", "llvm_support"] +
                  (["mlir_headers", "llvm_headers"] if add_hdrs else [])),
        "%{MLIR_TESTPASS_LIB}":
            _llvm_get_library_rule(ctx, prx, "mlir_test_pass",
                "MLIRTestPass",
                ["mlir_ir", "mlir_pass", "llvm_support"] +
                  (["mlir_headers", "llvm_headers"] if add_hdrs else [])),
        "%{MLIR_TESTTRANSFORMS_LIB}":
            _llvm_get_library_rule(ctx, prx, "mlir_test_transforms",
                "MLIRTestTransforms",
                ["mlir_affine_ops", "mlir_analysis", "mlir_edsc", "mlir_gpu",
                 "mlir_gpu_to_gpu_runtime_transforms", "mlir_linalg_ops",
                 "mlir_linalg_transforms", "mlir_nvvm_ir", "mlir_scf",
                 "mlir_scf_transforms", "mlir_pass", "mlir_rocdl_ir",
                 "mlir_standard_ops_transforms", "mlir_target_nvvm_ir",
                 "mlir_target_rocdl_ir", "mlir_test_dialect",
                 "mlir_transform_utils", "mlir_vector_to_scf", "mlir_vector",
                 "llvm_support"] +
                  (["mlir_headers", "llvm_headers"] if add_hdrs else [])),
        "%{MLIR_TRANSFORMS_LIB}":
            _llvm_get_library_rule(ctx, prx, "mlir_transforms",
                "MLIRTransforms",
                ["mlir_affine_ops", "mlir_analysis",
                 "mlir_loop_like_interface", "mlir_scf", "mlir_pass",
                 "mlir_transform_utils", "mlir_vector", "llvm_support"] +
                  (["mlir_headers", "llvm_headers"] if add_hdrs else [])),
        "%{MLIR_TRANSFORMUTILS_LIB}":
            _llvm_get_library_rule(ctx, prx, "mlir_transform_utils",
                "MLIRTransformUtils",
                ["mlir_affine_ops", "mlir_analysis", "mlir_loop_analysis",
                 "mlir_scf", "mlir_pass", "mlir_standard_ops",
                 "llvm_support"] +
                  (["mlir_headers", "llvm_headers"] if add_hdrs else [])),
        "%{MLIR_TRANSLATION_LIB}":
            _llvm_get_library_rule(ctx, prx, "mlir_translation",
                "MLIRTranslation",
                ["mlir_ir", "mlir_parser", "llvm_support"] +
                  (["mlir_headers", "llvm_headers"] if add_hdrs else [])),
        "%{MLIR_VECTOR_LIB}":
            _llvm_get_library_rule(ctx, prx, "mlir_vector",
                "MLIRVector",
                ["mlir_edsc", "mlir_ir", "mlir_standard_ops", "mlir_affine_ops",
                 "mlir_scf", "mlir_loop_analysis", "mlir_side_effect_interfaces",
                 "llvm_support"] +
                  (["mlir_headers", "llvm_headers"] if add_hdrs else [])),
        "%{MLIR_VECTORTOLLVM_LIB}":
            _llvm_get_library_rule(ctx, prx, "mlir_vector_to_llvm",
                "MLIRVectorToLLVM",
                ["mlir_llvm_ir", "mlir_standard_to_llvm", "mlir_vector",
                 "mlir_transforms", "llvm_core", "llvm_support"] +
                  (["mlir_headers", "llvm_headers"] if add_hdrs else [])),
        "%{MLIR_VECTORTOSCF_LIB}":
            _llvm_get_library_rule(ctx, prx, "mlir_vector_to_scf",
                "MLIRVectorToSCF",
                ["mlir_edsc", "mlir_affine_edsc", "mlir_llvm_ir",
                 "mlir_transforms", "llvm_core", "llvm_support"] +
                  (["mlir_headers", "llvm_headers"] if add_hdrs else [])),
        "%{MLIR_VIEWLIKEINTERFACE_LIB}":
            _llvm_get_library_rule(ctx, prx, "mlir_view_like_interface",
                "MLIRViewLikeInterface",
                ["mlir_ir", "llvm_support"] +
                  (["mlir_headers", "llvm_headers"] if add_hdrs else [])),

        "%{DEBUG_DEP_LIBS}":
            "\n".join([_llvm_get_library_rule(ctx, prx, dep_name, dep_name,
                            ignore_prefix = True, directory = dep_name)
                for dep_name in llvm_debug_deps]),

        "%{DEP_LIBS}":
            "\n".join([_llvm_get_shared_library_rule(ctx, prx, dep_name, dep_name,
                            ignore_prefix = True, directory = dep_name)
                       if dep_shared else
                       _llvm_get_library_rule(ctx, prx, dep_name, dep_name,
                            ignore_prefix = True, directory = dep_name)
                for dep_name, dep_shared in llvm_deps.items()]),
    })

    _tpl(repository_ctx, "llvm_config.bzl", {
        "%{LLVM_ENABLE_RTTI}": str(enable_rtti),
        "%{LLVM_ENABLE_EH}": str(enable_eh),
        "%{LLVM_TARGETS}": _llvm_get_formatted_target_list(repository_ctx,
            supported_targets),
        "%{LLVM_CXX_LINKED}": str(_llvm_is_linked_against_cxx(repository_ctx)),
    })

    if _llvm_if_tablegen(repository_ctx, "llvm"):
        _tpl(repository_ctx, "llvm_tablegen.bzl", {
            "%{NAME}": "LLVM",
            "%{PREFIX}": prefix_dictionary["llvm"],
        },
        "llvm_tablegen.bzl")

    if _llvm_if_tablegen(repository_ctx, "mlir"):
        _tpl(repository_ctx, "llvm_tablegen.bzl", {
            "%{NAME}": "MLIR",
            "%{PREFIX}": prefix_dictionary["mlir"],
        },
        "mlir_tablegen.bzl")

llvm_configure = repository_rule(
    implementation = _llvm_installed_impl,
    attrs = {
        "build_file": attr.label(),
        "config_file": attr.label(), # Taken into account only if build_file is specified
        "urls": attr.string_list(default = []),
        "sha256": attr.string(default = ""),
        "strip_prefix": attr.string(default = ""),
        "llvm_prefix": attr.string(default = "llvm_"),
        "clang_prefix": attr.string(default = "clang_"),
        "libcxx_prefix": attr.string(default = "libcxx_"),
        "mlir_prefix": attr.string(default = "mlir_"),
        "add_headers_to_deps": attr.bool(default = True),
    },
    environ = [
        _LLVM_INSTALL_PREFIX,
    ],
)
