"""Setup LLVM and Clang as external dependencies

   The file has been adopted for a local LLVM (and, optionally, Clang)
   installation.

   Some methods have been borrowed from the NGraph-Tensorflow bridge:
   https://github.com/tensorflow/ngraph-bridge/blob/master/bazel/tf_configure/tf_configure.bzl
"""

_LLVM_LICENSE_FILE_PATH = "https://raw.githubusercontent.com/llvm/llvm-project/master/llvm/LICENSE.TXT"
_LLVM_LICENSE_FILE_SHA256 = "8d85c1057d742e597985c7d4e6320b015a9139385cff4cbae06ffc0ebe89afee"
_LLVM_INSTALL_PREFIX = "LLVM_INSTALL_PREFIX"
_Z3_INSTALL_PREFIX = "Z3_INSTALL_PREFIX"

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
    if name.startswith("llvm_"):
        return concat_format % (prefix_dict["llvm"], name[len("llvm_"):])
    if name.startswith("clang_"):
        return concat_format % (prefix_dict["clang"], name[len("clang_"):])
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
        include_local_dirs):
    """Returns a cc_library to include an LLVM header directory

    Args:
        repository_ctx: the repository_ctx object.
        prefix_dict: the dictionary of library name prefixes.
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
            _llvm_get_rule_name(prefix_dict, name),
            [],  # LLVM's include is the public interface
            llvm_include_dirs,
            ["include"]
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
        ignore_prefix = False,
        nix_only = False,
        win_only = False):
    """Returns a cc_library to include an LLVM shared library (or its interface
       library on Windows) with dependencies.

    Args:
        repository_ctx: the repository_ctx object.
        prefix_dict: the dictionary of library name prefixes.
        name: rule name.
        llvm_library_file: an LLVM library file name without extension.
        ignore_prefix: if True, no lib prefix must be added on any host OS.
        nix_only: the library is available only on *nix systems.
        win_only: the library is available only on Windows.):

    Returns:
        cc_library target that defines the library.
    """
    if _is_windows(repository_ctx) and nix_only:
        return "# library '%s' is available on *Nix only\n" % llvm_library_file
    if not _is_windows(repository_ctx) and win_only:
        return "# library '%s' is available on Windows only\n" % llvm_library_file

    library_prefix, library_ext = _import_library_file_params(repository_ctx)
    library_prefix = library_prefix if not ignore_prefix else ""
    library_file = "lib/%s%s.%s" % (library_prefix, llvm_library_file, library_ext)
    if repository_ctx.path(library_file).exists:
        llvm_library_rule = _cc_library(
            name = _llvm_get_rule_name(prefix_dict, name),
            srcs = [library_file],
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
        "#ifdef LLVM_CONFIG_H\n" +
        "#error " + config_file_name + " can only be included once\n" +
        "#else\n" +
        "#define LLVM_CONFIG_H\n" +
        "#define LLVM_INCLUDE_DIR \"" + llvm_include_dir + "\"\n" +
        "#define LLVM_INCLUDE_COMMAND_ARG \"-I" + llvm_include_dir + "\"\n" +
        "#define LLVM_LIBRARY_DIR \"" + llvm_library_dir + "\"\n" +
        ("#define CLANG_LIB_INCLUDE_DIR \"" + clang_include_dir + "\"\n" +
         "#define CLANG_LIB_INCLUDE_COMMAND_ARG \"-I" + clang_include_dir + "\"\n"
         if clang_exists else "") +
        "#endif /* LLVM_CONFIG_H */\n' > $@")

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

def _llvm_get_link_opts(repository_ctx):
    """Returns a list of platform-provided dependencies.
       The list should be used as a value of the 'linkopts'
       rule parameter.

       Implementation notes: the method uses the
       "lib/cmake/llvm/LLVMExports.cmake" file and grabs the
       dependencies of the LLVMSupport library excluded all
       started with LLVM or contains dot (so, being a real file).

    Args:
        repository_ctx: the repository_ctx object.
    Returns:
        A list of platform-provided dependencies.
    """

    # No link opts on Windows
    if _is_windows(repository_ctx):
        return []

    # The algorithm is following: read the export file, read libraries
    # for llvm_support, remove started with LLVM, and convert them into
    # an array of "-l<library>" positions.
    exportpath = repository_ctx.path("lib/cmake/llvm/LLVMExports.cmake")
    if not exportpath.exists:
        return []
    config = repository_ctx.read("lib/cmake/llvm/LLVMExports.cmake")
    libraries_line = ""
    lines = config.splitlines()
    for idx, line in enumerate(lines):
        # looking for dependencies for LLVMSupport
        if line.startswith("set_target_properties(LLVMSupport"):
            if idx + 1 < len(lines):
                libraries_line = lines[idx + 1]
            break

    if len(libraries_line) == 0:
        return []
    start = libraries_line.find('"')
    end = libraries_line.find('"', start + 1)
    libraries_line = libraries_line[start + 1:end]
    libs = []
    for lib in libraries_line.split(";"):
        if lib.startswith("LLVM"): # if LLVM<smth> this is a dependency, no linkopt
            continue
        if lib.find(".") > -1: # there is an extension, so it is no linkopt
            continue
        libs.append("-l" + lib if not lib.startswith("-l") else lib)

    return libs

def _llvm_get_target_list(repository_ctx):
    """Returns a list of supported targets.

       Implementation notes: the method uses the
       "lib/cmake/llvm/LLVMConfig.cmake" file and reads the
       value of the 'LLVM_TARGETS_TO_BUILD' property.

    Args:
        repository_ctx: the repository_ctx object.
    Returns:
        A list of targets supported by installation.
    """
    configpath = repository_ctx.path("lib/cmake/llvm/LLVMConfig.cmake")
    if not configpath.exists:
        return []
    config = repository_ctx.read("lib/cmake/llvm/LLVMConfig.cmake")
    targets_line = ""
    lines = config.splitlines()
    for line in lines:
        if line.startswith("set(LLVM_TARGETS_TO_BUILD"):
            targets_line = line
            break

    if len(targets_line) == 0:
        return []

    start = targets_line.find(' ')
    end = targets_line.find(')', start + 1)
    targets_line = targets_line[start + 1:end]
    return targets_line.split(";")

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

def _enable_local_z3(repository_ctx):
    """Returns whether the Z3 Solver is enabled. The solver is
       enabled if the _Z3_INSTALL_PREFIX environment variable
       is defined.

    Args:
        repository_ctx: the repository_ctx object.
    Returns:
        True if the Z3 Solver is enabled.
    """

    return _Z3_INSTALL_PREFIX in repository_ctx.os.environ

def _z3_symlink_library(
        repository_ctx,
        z3_path,
        subfolder,
        library_file,
        target):
    """Symlink the Z3 Solver's static library into the bazel building directory.

    Args:
        repository_ctx: the repository_ctx object.
        z3_path: full path to the Z3 Solver's installation.
        subfolder: where to search for the 'library_file'.
        library_file: the name of the Z3 library file.
        target: the symlink target.
    Returns:
        True if the Z3 librart is found in the subfolder or False otherwise.
    """

    library_file_path = "%s/%s/%s" % (z3_path, subfolder, library_file)
    if repository_ctx.path(library_file_path).exists:
        repository_ctx.symlink(library_file_path, target)
        return True
    else:
        return False

def _z3_get_libraries(repository_ctx, z3_path):
    """Symlink the Z3 Solver's libraries into the bazel building directory.

    Args:
        repository_ctx: the repository_ctx object.
        z3_path: full path to the Z3 Solver's installation.
    """

    _, library_ext = _static_library_file_params(repository_ctx)
    static_library = "libz3.%s" % library_ext
    target = "z3/lib/%s" % static_library # Notice! even if libz3 is a shared library,
                                          # the symlink will have extension .a
    if not _is_windows(repository_ctx):
        _, library_ext = _import_library_file_params(repository_ctx)
        import_library = "libz3.%s" % library_ext
        variants = [("lib64", static_library),
                    ("lib64", import_library),
                    ("lib", static_library),
                    ("lib", import_library),
                    ("bin", static_library),
                    ("bin", import_library),
                   ]
    else:
        variants = [("lib", static_library),
                    ("bin", static_library),
                   ]
    for folder, library_file in variants:
        if _z3_symlink_library(repository_ctx, z3_path, folder, library_file, target):
            return

def _llvm_installed_impl(repository_ctx):
    # dictionary of prefixes, all targets will be named prefix_dictionary["llvm"]<target>
    # for LLVM, prefix_dictionary["clang"]<target> for clang, etc.
    prefix_dictionary = {
        "llvm": repository_ctx.attr.llvm_prefix,
        "clang": repository_ctx.attr.clang_prefix,
    }
    # if there are duplicated prefixes, fail.
    _llvm_check_duplicated_prefixes(prefix_dictionary)

    if _llvm_local_enabled(repository_ctx):
        # setup local LLVM repository
        llvm_path = _llvm_get_install_path(repository_ctx)
        repository_ctx.symlink("%s/include" % llvm_path, "include")
        repository_ctx.symlink("%s/lib" % llvm_path, "lib")
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

    if _enable_local_z3(repository_ctx):
        z3_path = repository_ctx.os.environ[_Z3_INSTALL_PREFIX]
        _z3_get_libraries(repository_ctx, z3_path)
    else:
        _warn("Z3 Solver is not enabled.",
            " ".join(["To enable the solver, set the environment variable",
             "'%s' to the full path of the solver's local installation." % _Z3_INSTALL_PREFIX,
            ]))

    supported_targets = _llvm_get_target_list(repository_ctx)
    ctx = repository_ctx
    prx = prefix_dictionary
    _tpl(repository_ctx, "BUILD", {
        "%{CLANG_HEADERS_LIB}":
             _llvm_get_include_rule(ctx, prx, "clang_headers",
                ["clang", "clang-c"]),
        "%{LLVM_HEADERS_LIB}":
            _llvm_get_include_rule(ctx, prx, "llvm_headers",
                ["llvm", "llvm-c"]),

        "%{CLANG_ANALYSIS_LIB}":
            _llvm_get_library_rule(ctx, prx, "clang_analysis",
                "clangAnalysis",
                ["clang_ast", "clang_ast_matchers", "clang_basic",
                 "clang_lex", "llvm_support"]),
        "%{CLANG_ARCMIGRATE_LIB}":
            _llvm_get_library_rule(ctx, prx, "clang_arc_migrate",
                "clangARCMigrate",
                ["clang_ast", "clang_analysis", "clang_basic", "clang_edit",
                 "clang_frontend", "clang_lex", "clang_rewrite", "clang_sema",
                 "clang_serialization", "llvm_support"]),
        "%{CLANG_AST_LIB}":
            _llvm_get_library_rule(ctx, prx, "clang_ast",
                "clangAST",
                ["clang_basic", "clang_lex", "llvm_binary_format", "llvm_core",
                 "llvm_support"]),
        "%{CLANG_ASTMATCHERS_LIB}":
            _llvm_get_library_rule(ctx, prx, "clang_ast_matchers",
                "clangASTMatchers",
                ["clang_ast", "clang_basic", "llvm_support"]),
        "%{CLANG_BASIC_LIB}":
            _llvm_get_library_rule(ctx, prx, "clang_basic",
                "clangBasic",
                ["llvm_core", "llvm_mc", "llvm_support"]),
        "%{CLANG_CODEGEN_LIB}":
            _llvm_get_library_rule(ctx, prx, "clang_code_gen",
                "clangCodeGen",
                ["clang_analysis", "clang_ast", "clang_ast_matchers",
                 "clang_basic", "clang_frontend", "clang_lex",
                 "clang_serialization", "llvm_analysis", "llvm_bit_reader",
                 "llvm_bit_writer", "llvm_core", "llvm_coroutines",
                 "llvm_coverage", "llvm_ipo", "llvm_ir_reader",
                 "llvm_aggressive_inst_combine", "llvm_inst_combine",
                 "llvm_instrumentation", "llvm_lto", "llvm_linker",
                 "llvm_mc", "llvm_objc_arc", "llvm_object",
                 "llvm_passes", "llvm_profile_data", "llvm_remarks",
                 "llvm_scalar", "llvm_support", "llvm_target",
                 "llvm_transform_utils"]),
        "%{CLANG_CROSSTU_LIB}":
            _llvm_get_library_rule(ctx, prx, "clang_cross_tu",
                "clangCrossTU",
                ["clang_ast", "clang_basic", "clang_frontend", "clang_index",
                 "llvm_support"]),
        "%{CLANG_DEPENDENCYSCANNING_LIB}":
            _llvm_get_library_rule(ctx, prx, "clang_dependency_scanning",
                "clangDependencyScanning",
                ["clang_ast", "clang_basic", "clang_driver", "clang_frontend",
                 "clang_frontend_tool", "clang_lex", "clang_parse",
                 "clang_serialization", "clang_tooling",
                 "llvm_core", "llvm_support"]),
        "%{CLANG_DIRECTORYWATCHER_LIB}":
            _llvm_get_library_rule(ctx, prx, "clang_directory_watcher",
                "clangDirectoryWatcher",
                ["llvm_support"]),
        "%{CLANG_DRIVER_LIB}":
            _llvm_get_library_rule(ctx, prx, "clang_driver",
                "clangDriver",
                ["clang_basic", "llvm_binary_format", "llvm_option",
                 "llvm_support"],
                ["-DEFAULTLIB:version.lib"] if _is_windows(ctx) else []),
        "%{CLANG_DYNAMICASTMATCHERS_LIB}":
            _llvm_get_library_rule(ctx, prx, "clang_dynamic_ast_matchers",
                "clangDynamicASTMatchers",
                ["clang_ast", "clang_ast_matchers", "clang_basic",
                 "llvm_support"]),
        "%{CLANG_EDIT_LIB}":
            _llvm_get_library_rule(ctx, prx, "clang_edit",
                "clangEdit",
                ["clang_ast", "clang_basic", "clang_lex", "llvm_support"]),
        "%{CLANG_FORMAT_LIB}":
            _llvm_get_library_rule(ctx, prx, "clang_format",
                "clangFormat",
                ["clang_basic", "clang_lex", "clang_tooling_core",
                 "clang_tooling_inclusions", "llvm_support"]),
        "%{CLANG_FRONTEND_LIB}":
            _llvm_get_library_rule(ctx, prx, "clang_frontend",
                "clangFrontend",
                ["clang_ast", "clang_basic", "clang_driver", "clang_edit",
                 "clang_lex", "clang_parse", "clang_sema", "clang_serialization",
                 "llvm_bit_reader", "llvm_bitstream_reader", "llvm_option",
                 "llvm_profile_data", "llvm_support"]),
        "%{CLANG_FRONTENDTOOL_LIB}":
            _llvm_get_library_rule(ctx, prx, "clang_frontend_tool",
                "clangFrontendTool",
                ["clang_basic", "clang_code_gen", "clang_driver", "clang_frontend",
                 "clang_rewrite_frontend", "clang_arc_migrate",
                 "clang_static_analyzer_frontend", "llvm_option", "llvm_support"]),
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
                      "llvm_x86_info", "llvm_x86_utils"
                     ] if "X86" in supported_targets else [])
                  + (["llvm_x_core_code_gen", "llvm_x_core_desc",
                      "llvm_x_core_disassembler", "llvm_x_core_info"
                     ] if "XCore" in supported_targets else [])),
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
                      "llvm_x86_info", "llvm_x86_utils"
                     ] if "X86" in supported_targets else [])),
        "%{CLANG_INDEX_LIB}":
            _llvm_get_library_rule(ctx, prx, "clang_index",
                "clangIndex",
                ["clang_ast", "clang_basic", "clang_format", "clang_frontend",
                 "clang_lex", "clang_rewrite", "clang_serialization",
                 "clang_tooling_core", "llvm_core", "llvm_support"]),
        "%{CLANG_LEX_LIB}":
            _llvm_get_library_rule(ctx, prx, "clang_lex",
                "clangLex",
                ["clang_basic", "llvm_support"]),
        "%{CLANG_LIBCLANG_LIB}":
            _llvm_get_shared_library_rule(ctx, prx, "clang_libclang",
                "libclang",
                ignore_prefix = True),
        "%{CLANG_LIBCLANG_COPY_GENRULE}":
            _llvm_get_shared_lib_genrule(ctx, prx, "clang_copy_libclang",
                llvm_path, "libclang", ignore_prefix = True),
        "%{CLANG_LIBCLANGCPP_LIB}":
            _llvm_get_shared_library_rule(ctx, prx, "clang_libclang_cpp",
                "libclang-cpp", ignore_prefix = True, nix_only = True),
        "%{CLANG_LIBCLANGCPP_COPY_GENRULE}":
            _llvm_get_shared_lib_genrule(ctx, prx, "clang_copy_libclang_cpp",
                llvm_path, "libclang-cpp", ignore_prefix = True, nix_only=True),
        "%{CLANG_PARSE_LIB}":
            _llvm_get_library_rule(ctx, prx, "clang_parse",
                "clangParse",
                ["clang_ast", "clang_basic", "clang_lex", "clang_sema",
                 "llvm_mc", "llvm_mc_parser", "llvm_support"]),
        "%{CLANG_REWRITE_LIB}":
            _llvm_get_library_rule(ctx, prx, "clang_rewrite",
                "clangRewrite",
                ["clang_basic", "clang_lex", "llvm_support"]),
        "%{CLANG_REWRITEFRONTEND_LIB}":
            _llvm_get_library_rule(ctx, prx, "clang_rewrite_frontend",
                "clangRewriteFrontend",
                ["clang_ast", "clang_basic", "clang_edit", "clang_frontend",
                 "clang_lex", "clang_rewrite", "clang_serialization",
                 "llvm_support"]),
        "%{CLANG_SEMA_LIB}":
            _llvm_get_library_rule(ctx, prx, "clang_sema",
                "clangSema",
                ["clang_ast", "clang_analysis", "clang_basic",
                 "clang_edit", "clang_lex", "llvm_support"]),
        "%{CLANG_SERIALIZATION_LIB}":
            _llvm_get_library_rule(ctx, prx, "clang_serialization",
                "clangSerialization",
                ["clang_ast", "clang_basic", "clang_lex", "clang_sema",
                 "llvm_bit_reader", "llvm_bitstream_reader", "llvm_support"]),
        "%{CLANG_STATICANALYZERCHECKERS_LIB}":
            _llvm_get_library_rule(ctx, prx, "clang_static_analyzer_checkers",
                "clangStaticAnalyzerCheckers",
                ["clang_ast", "clang_ast_matchers", "clang_analysis", "clang_basic",
                 "clang_lex", "clang_static_analyzer_core", "llvm_support"]),
        "%{CLANG_STATICANALYZERCORE_LIB}":
            _llvm_get_library_rule(ctx, prx, "clang_static_analyzer_core",
                "clangStaticAnalyzerCore",
                ["clang_ast", "clang_ast_matchers", "clang_analysis", "clang_basic",
                 "clang_cross_tu", "clang_frontend", "clang_lex", "clang_rewrite",
                 "llvm_support"]),
        "%{CLANG_STATICANALYZERFRONTEND_LIB}":
            _llvm_get_library_rule(ctx, prx, "clang_static_analyzer_frontend",
                "clangStaticAnalyzerFrontend",
                ["clang_ast", "clang_analysis", "clang_basic", "clang_cross_tu",
                 "clang_frontend", "clang_lex", "clang_static_analyzer_checkers",
                 "clang_static_analyzer_core", "llvm_support"]),
        "%{CLANG_TOOLING_LIB}":
            _llvm_get_library_rule(ctx, prx, "clang_tooling",
                "clangTooling",
                ["clang_ast", "clang_ast_matchers", "clang_basic", "clang_driver",
                 "clang_format", "clang_frontend", "clang_lex", "clang_rewrite",
                 "clang_serialization", "clang_tooling_core",
                 "llvm_option", "llvm_support"]),
        "%{CLANG_TOOLINGASTDIFF_LIB}":
            _llvm_get_library_rule(ctx, prx, "clang_tooling_ast_diff",
                "clangToolingASTDiff",
                ["clang_ast", "clang_basic", "clang_lex", "llvm_support"]),
        "%{CLANG_TOOLINGCORE_LIB}":
            _llvm_get_library_rule(ctx, prx, "clang_tooling_core",
                "clangToolingCore",
                ["clang_ast", "clang_basic", "clang_lex", "clang_rewrite",
                 "llvm_support"]),
        "%{CLANG_TOOLINGINCLUSIONS_LIB}":
            _llvm_get_library_rule(ctx, prx, "clang_tooling_inclusions",
                "clangToolingInclusions",
                ["clang_basic", "clang_lex", "clang_rewrite",
                 "clang_tooling_core", "llvm_support"]),
        "%{CLANG_TOOLINGREFACTORING_LIB}":
            _llvm_get_library_rule(ctx, prx, "clang_tooling_refactoring",
                "clangToolingRefactoring",
                ["clang_ast", "clang_ast_matchers", "clang_basic", "clang_format",
                 "clang_index", "clang_lex", "clang_rewrite",
                 "clang_tooling_core", "llvm_support"]),
        "%{CLANG_TOOLINGSYNTAX_LIB}":
            _llvm_get_library_rule(ctx, prx, "clang_tooling_syntax",
                "clangToolingSyntax",
                ["clang_ast", "clang_basic", "clang_frontend", "clang_lex",
                 "clang_tooling_core", "llvm_support"]),

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
                win_only = True),
        "%{LLVM_C_COPY_GENRULE}":
            _llvm_get_shared_lib_genrule(ctx, prx, "llvm_copy_c",
                llvm_path, "LLVM-C", win_only = True),
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
                "LLVMDebugInfoGSYM", ["llvm_support"]),
        "%{LLVM_DEBUGINFOMSF_LIB}":
            _llvm_get_library_rule(ctx, prx, "llvm_debug_info_msf",
                "LLVMDebugInfoMSF", ["llvm_support"]),
        "%{LLVM_DEBUGINFOPDB_LIB}":
            _llvm_get_library_rule(ctx, prx, "llvm_debug_info_pdb",
                "LLVMDebugInfoPDB",
                ["llvm_debug_info_code_view", "llvm_debug_info_msf",
                 "llvm_object", "llvm_support"]),
        "%{LLVM_DEMANGLE_LIB}":
            _llvm_get_library_rule(ctx, prx, "llvm_demangle",
                "LLVMDemangle"),
        "%{LLVM_DLLTOOLDRIVER_LIB}":
            _llvm_get_library_rule(ctx, prx, "llvm_dlltool_driver",
                "LLVMDlltoolDriver",
                ["llvm_object", "llvm_option", "llvm_support"]),
        "%{LLVM_EXECUTION_ENGINE_LIB}":
            _llvm_get_library_rule(ctx, prx, "llvm_execution_engine",
                "LLVMExecutionEngine",
                ["llvm_core", "llvm_mc", "llvm_object", "llvm_runtime_dyld",
                 "llvm_support", "llvm_target"]),
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
                 "llvm_ir_reader", "llvm_inst_combine","llvm_instrumentation",
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
                 "llvm_bit_reader", "llvm_bit_writer", "llvm_code_gen",
                 "llvm_core", "llvm_inst_combine", "llvm_linker", "llvm_mc",
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
        "%{LLVM_MCJIT_LIB}":
            _llvm_get_library_rule(ctx, prx, "llvm_mcjit",
                "LLVMMCJIT",
                ["llvm_core", "llvm_execution_engine", "llvm_object",
                 "llvm_runtime_dyld", "llvm_support", "llvm_target"]),
        "%{LLVM_MCPARSER_LIB}":
            _llvm_get_library_rule(ctx, prx, "llvm_mc_parser",
                "LLVMMCParser",
                ["llvm_mc", "llvm_support"]),
        "%{LLVM_MCDISASSEMBLER_LIB}":
            _llvm_get_library_rule(ctx, prx, "llvm_mc_disassembler",
                "LLVMMCDisassembler",
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
                 "llvm_mc", "llvm_mc_parser", "llvm_support"]),
       "%{LLVM_OBJECTYAML_LIB}":
            _llvm_get_library_rule(ctx, prx, "llvm_object_yaml",
                "LLVMObjectYAML",
                ["llvm_debug_info_code_view", "llvm_object", "llvm_support"]),
       "%{LLVM_OPTION_LIB}":
            _llvm_get_library_rule(ctx, prx, "llvm_option",
                "LLVMOption", ["llvm_support"]),
       "%{LLVM_ORCJIT_LIB}":
            _llvm_get_library_rule(ctx, prx, "llvm_orc_jit",
                "LLVMOrcJIT",
                ["llvm_core", "llvm_execution_engine", "llvm_jit_link",
                 "llvm_mc", "llvm_object", "llvm_runtime_dyld",
                 "llvm_support", "llvm_target", "llvm_transform_utils"]),
        "%{LLVM_PASSES_LIB}":
            _llvm_get_library_rule(ctx, prx, "llvm_passes",
                "LLVMPasses",
                ["llvm_aggressive_inst_combine", "llvm_analysis",
                 "llvm_code_gen", "llvm_core", "llvm_inst_combine",
                 "llvm_instrumentation", "llvm_scalar", "llvm_support",
                 "llvm_target", "llvm_transform_utils", "llvm_vectorize",
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
                ["llvm_demangle"] + (["z3_solver"] if _enable_local_z3(ctx) else []),
                _llvm_get_link_opts(ctx)),
        "%{LLVM_SYMBOLIZE_LIB}":
            _llvm_get_library_rule(ctx, prx, "llvm_symbolize",
                "LLVMSymbolize",
                ["llvm_debug_info_dwarf", "llvm_debug_info_pdb",
                 "llvm_demangle", "llvm_object", "llvm_support"]),
        "%{LLVM_TABLEGEN_LIB}":
            _llvm_get_library_rule(ctx, prx, "llvm_tablegen",
                "LLVMTableGen",
                ["llvm_support"]),
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
                 "llvm_analysis", "llvm_asm_printer", "llvm_code_gen", "llvm_core",
                 "llvm_global_i_sel", "llvm_mc", "llvm_scalar",
                 "llvm_selection_dag", "llvm_support", "llvm_target",
                 "llvm_transform_utils"]),
         "%{LLVM_AARCH64_DESC_LIB}":
            _llvm_get_library_rule(ctx, prx, "llvm_aarch64_desc",
                "LLVMAArch64Desc",
                ["llvm_aarch64_info", "llvm_aarch64_utils", "llvm_mc",
                 "llvm_support"]),
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
                ["llvm_binary_format", "llvm_core", "llvm_mc", "llvm_support"]),
        "%{LLVM_ARM_ASMPARSER_LIB}":
            _llvm_get_library_rule(ctx, prx, "llvm_arm_asm_parser",
                "LLVMARMAsmParser",
                ["llvm_arm_desc", "llvm_arm_info", "llvm_arm_utils",
                 "llvm_mc", "llvm_mc_parser", "llvm_support"]),
        "%{LLVM_ARM_CODEGEN_LIB}":
            _llvm_get_library_rule(ctx, prx, "llvm_arm_code_gen",
                "LLVMARMCodeGen",
                ["llvm_arm_desc", "llvm_arm_info", "llvm_arm_utils",
                 "llvm_analysis", "llvm_asm_printer", "llvm_code_gen",
                 "llvm_core", "llvm_global_i_sel", "llvm_mc",
                 "llvm_scalar", "llvm_selection_dag",
                 "llvm_support", "llvm_target", "llvm_transform_utils"]),
        "%{LLVM_ARM_DESC_LIB}":
            _llvm_get_library_rule(ctx, prx, "llvm_arm_desc",
                "LLVMARMDesc",
                ["llvm_arm_info", "llvm_arm_utils", "llvm_mc",
                 "llvm_mc_disassembler", "llvm_support"]),
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
                ["llvm_mc", "llvm_powerpc_info", "llvm_support"]),
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
                ["llvm_mc", "llvm_mc_parser", "llvm_riscv_desc", "llvm_riscv_info",
                 "llvm_riscv_utils", "llvm_support"]),
        "%{LLVM_RISCV_CODEGEN_LIB}":
            _llvm_get_library_rule(ctx, prx, "llvm_riscv_code_gen",
                "LLVMRISCVCodeGen",
                ["llvm_analysis", "llvm_asm_printer", "llvm_code_gen", "llvm_core",
                 "llvm_global_i_sel", "llvm_mc", "llvm_riscv_desc", "llvm_riscv_info",
                 "llvm_riscv_utils", "llvm_selection_dag", "llvm_support",
                 "llvm_target"]),
        "%{LLVM_RISCV_DESC_LIB}":
            _llvm_get_library_rule(ctx, prx, "llvm_riscv_desc",
                "LLVMRISCVDesc",
                ["llvm_mc", "llvm_riscv_info", "llvm_riscv_utils", "llvm_support"]),
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
                ["llvm_mc_disassembler", "llvm_support",
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
                ["llvm_analysis", "llvm_asm_printer", "llvm_code_gen",
                 "llvm_core", "llvm_global_i_sel", "llvm_mc", "llvm_profile_data",
                 "llvm_selection_dag", "llvm_support", "llvm_target",
                 "llvm_x86_desc", "llvm_x86_info", "llvm_x86_utils"]),
        "%{LLVM_X86_DESC_LIB}":
            _llvm_get_library_rule(ctx, prx, "llvm_x86_desc",
                "LLVMX86Desc",
                ["llvm_mc", "llvm_mc_disassembler", "llvm_object", "llvm_support",
                 "llvm_x86_info", "llvm_x86_utils"]),
        "%{LLVM_X86_DISASSEMBLER_LIB}":
            _llvm_get_library_rule(ctx, prx, "llvm_x86_disassembler",
                "LLVMX86Disassembler",
                ["llvm_mc_disassembler", "llvm_support", "llvm_x86_info"]),
        "%{LLVM_X86_INFO_LIB}":
            _llvm_get_library_rule(ctx, prx, "llvm_x86_info",
                "LLVMX86Info",
                ["llvm_support"]),
        "%{LLVM_X86_UTILS_LIB}":
            _llvm_get_library_rule(ctx, prx, "llvm_x86_utils",
                "LLVMX86Utils",
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
        "%{Z3_SOLVER_LIB}":
            _llvm_get_library_rule(ctx, prx, "z3_solver", "libz3",
                ignore_prefix = True, directory = "z3/lib"),
    })

    _tpl(repository_ctx, "llvm_config.bzl", {
        "%{LLVM_TARGETS}": _llvm_get_formatted_target_list(repository_ctx,
            supported_targets),
    })

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
    },
    environ = [
        _LLVM_INSTALL_PREFIX,
        _Z3_INSTALL_PREFIX,
    ],
)
