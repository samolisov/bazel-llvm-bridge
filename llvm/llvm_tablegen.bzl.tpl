# -*- Python -*-
"""Skylark rule for running %{NAME} Tablegen.

Example:
%{PREFIX}tablegen(
    name = "mlir_toyc_td_decl",
    src  = "mlir/toy/include/toy/Ops.td",
    out  = "toy/Ops.h.inc",
    opts = ["-gen-op-decls"],
    deps = ["@local_llvm//:ml_headers"],
    visibility = ["//visibility:private"],
)
"""

def _get_transitive_hdrs(srcs, deps):
    """Obtain the source files for a target and header files for its
       transitive dependencies.

    Args:
      srcs: a list of source files
      deps: a list of targets that are direct dependencies
    Returns:
      a collection of the sources and transitive headers
    """
    return depset(
        srcs,
        transitive = [dep[CcInfo].compilation_context.headers for dep in deps],
    )

def _get_transitive_includes(srcs, includes, deps):
    """Obtain the list of include directories for a target
       and its transitive dependencies.

    Args:
        srcs: a list of source files
        includes: a list of include directories
        deps: a list of targets that are direct dependencies
    Returns:
        a list of transitive include directories for a target
    """
    return depset(
        [src.dirname for src in srcs] + includes,
        transitive
            = depset(
                [dep[CcInfo].compilation_context.system_includes for dep in deps],
                    transitive
                        = [dep[CcInfo].compilation_context.includes for dep in deps])
                            .to_list())

def _tablegen_impl(ctx):
    # Collect the list of srcs (required for a sandboxed build)
    srcs = ctx.files.srcs + ctx.files.src
    sources_list = _get_transitive_hdrs(srcs, ctx.attr.deps).to_list()

    # Collect the list of includes
    includes = ["-I" + i for i in _get_transitive_includes(srcs,
        ctx.attr.includes, ctx.attr.deps).to_list()]

    # Combine the arguments together
    args = ctx.attr.opts + includes + ["-o", ctx.outputs.out.path]
    args += [s.path for s in ctx.files.src]

    # Action to call the tablegen
    ctx.actions.run(
        inputs = sources_list,
        outputs = [ctx.outputs.out],
        arguments = args,
        progress_message = "%{NAME} Tablegen for %s" % ctx.files.src[0].short_path,
        executable = ctx.executable._tablegen,
    )

    return [
        CcInfo(
            compilation_context = cc_common.create_compilation_context(
                includes = depset([ctx.outputs.out.dirname]),
                headers = depset([ctx.outputs.out])
            )
        )
    ]

%{PREFIX}tablegen = rule(
    implementation = _tablegen_impl,
    attrs = {
        "srcs": attr.label_list(allow_files = True),
        "src": attr.label(mandatory = True, allow_files = True),
        "out": attr.output(mandatory = True),
        "opts": attr.string_list(mandatory = True),
        "includes": attr.string_list(),
        "deps": attr.label_list(),
        "_tablegen": attr.label(
            executable = True,
            cfg = "host",
            allow_files = True,
            default = Label("//:%{PREFIX}tablegen_tool"),
        )
    }
)
