##
## Workspace - using an external prebuilt llvm
##

workspace(name = "llvm_bazel_bridge")

load("//third_party/llvm:llvm_configure.bzl", "llvm_configure")

llvm_configure(
    name = "local_llvm",
    # The LLVM_INSTALL_PREFIX environment variable must point to
    # a local llvm/clang installation.
)
