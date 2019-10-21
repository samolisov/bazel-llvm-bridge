# -*- Python -*-
"""Skylark macros for bazel-llvm-bridge.

llvm_nix_copts is a convenient set of platform-dependent compiler options
to enable the building process of LLVM-dependent targets for *Nix platforms.
It can disable RTTI and enable the right level of C++.

llvm_win_copts is a convenient set of platform-dependent compiler options
to enable the building process of LLVM-dependent targets for Windows platform.
It can disable RTTI and enable the right level of C++.

llvm_cxx_copts is a convenient set of "libc++" specific compiler options.
May be used to enable "libc++" as a standard library for the build.

llvm_cxx_linked is a flag that displays if LLVM is linked against the "libc++"
standard library.

if_cxx_linked is a conditional to check if the LLVM installation
is built against the "libc++" standard library. If so, the first argument
will be returned, otherwise the second one.

llvm_targets is a list of supported targets ("AArch64", "ARM", "X86", etc.)

if_has_<TARGET> is a conditional to check if we are building with the target
<TARGET>. If the target is supported, the first argument will be returned,
otherwise the second one.
"""

llvm_nix_copts = [
    "-std=c++14",
    "-fno-rtti",
]

llvm_win_copts = [
]

llvm_targets = [
%{LLVM_TARGETS}
]

llvm_cxx_linked = %{LLVM_CXX_LINKED}

llvm_cxx_copts = [
    %{LLVM_CXX_COPT}
]

def if_cxx_linked(if_true, if_false = []):
    return if_true if llvm_cxx_linked else if_false

def if_has_aarch64(if_true, if_false = []):
    return if_true if "AArch64" in llvm_targets else if_false

def if_has_amdgpu(if_true, if_false = []):
    return if_true if "AMDGPU" in llvm_targets else if_false

def if_has_arm(if_true, if_false = []):
    return if_true if "ARM" in llvm_targets else if_false

def if_has_bpf(if_true, if_false = []):
    return if_true if "BPF" in llvm_targets else if_false

def if_has_hexagon(if_true, if_false = []):
    return if_true if "Hexagon" in llvm_targets else if_false

def if_has_lanai(if_true, if_false = []):
    return if_true if "Lanai" in llvm_targets else if_false

def if_has_mips(if_true, if_false = []):
    return if_true if "Mips" in llvm_targets else if_false

def if_has_msp430(if_true, if_false = []):
    return if_true if "MSP430" in llvm_targets else if_false

def if_has_nvptx(if_true, if_false = []):
    return if_true if "NVPTX" in llvm_targets else if_false

def if_has_powerpc(if_true, if_false = []):
    return if_true if "PowerPC" in llvm_targets else if_false

def if_has_riscv(if_true, if_false = []):
    return if_true if "RISCV" in llvm_targets else if_false

def if_has_sparc(if_true, if_false = []):
    return if_true if "Sparc" in llvm_targets else if_false

def if_has_system_z(if_true, if_false = []):
    return if_true if "SystemZ" in llvm_targets else if_false

def if_has_web_assembly(if_true, if_false = []):
    return if_true if "WebAssembly" in llvm_targets else if_false

def if_has_x86(if_true, if_false = []):
    return if_true if "X86" in llvm_targets else if_false

def if_has_x_core(if_true, if_false = []):
    return if_true if "XCore" in llvm_targets else if_false
