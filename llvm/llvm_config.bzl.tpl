# -*- Python -*-
"""Skylark macros for bazel-llvm-bridge.

llvm_copts is a convenient set of platform-dependent compiler options
to enable the building process of LLVM-dependent targets. It can disable
RTTI and enable the right level of C++.

llvm_targets is a list of supported targets ("AArch64", "ARM", "X86", etc.)

if_has_<TARGET> is a conditional to check if we are building with the target
<TARGET>. If the target is supported, the first argument will be returned,
otherwise the second one.
"""

def _if_not_windows(a):
    return select({
        "//:windows": [],
        "//conditions:default": a,
    })

def _get_non_win_copts():
    return [
        "-fno-rtti",
    ]

def llvm_copts():
    return _if_not_windows(_get_non_win_copts())

llvm_targets = [
%{LLVM_TARGETS}
]

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

def if_has_sparc(if_true, if_false = []):
    return if_true if "Sparc" in llvm_targets else if_false

def if_has_systemz(if_true, if_false = []):
    return if_true if "SystemZ" in llvm_targets else if_false

def if_has_webassembly(if_true, if_false = []):
    return if_true if "WebAssembly" in llvm_targets else if_false

def if_has_x86(if_true, if_false = []):
    return if_true if "X86" in llvm_targets else if_false

def if_has_xcore(if_true, if_false = []):
    return if_true if "XCore" in llvm_targets else if_false
