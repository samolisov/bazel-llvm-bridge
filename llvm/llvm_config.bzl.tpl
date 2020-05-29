# -*- Python -*-
"""Skylark macros for bazel-llvm-bridge.

llvm_enables_eh is a flag that displays if LLVM is built with exception
support.

if_llvm_enables_eh is a condition to check if the LLVM installation
is built with enabled exception support. If so, the first argument will
be returned, otherwise the second one.

llvm_enables_rtti is a flag that displays if LLVM is built with enabled
RTTI.

if_llvm_enables_rtti is a condition to check if the LLVM installation
is built with enabled RTTI. If so, the first argument will be returned,
otherwise the second one.

llvm_nix_copts is a convenient set of platform-dependent compiler options
to enable the building process of LLVM-dependent targets for *Nix platforms.
It can disable RTTI and enable the right level of C++.

llvm_win_copts is a convenient set of platform-dependent compiler options
to enable the building process of LLVM-dependent targets for Windows platform.
It can disable RTTI and enable the right level of C++.

llvm_cxx_linked is a flag that displays if LLVM is linked against the "libc++"
standard library.

if_cxx_linked is a condition to check if the LLVM installation
is built against the "libc++" standard library. If so, the first argument
will be returned, otherwise the second one.

llvm_targets is a list of supported targets ("AArch64", "ARM", "X86", etc.)

if_has_<TARGET> is a condition to check if we are building with the target
<TARGET>. If the target is supported, the first argument will be returned,
otherwise the second one.
"""

llvm_enables_eh = %{LLVM_ENABLE_EH}

def if_llvm_enables_eh(if_true, if_false = []):
    return if_true if llvm_enables_eh else if_false

llvm_enables_rtti = %{LLVM_ENABLE_RTTI}

def if_llvm_enables_rtti(if_true, if_false = []):
    return if_true if llvm_enables_rtti else if_false

llvm_nix_copts = [
    "-Wno-unused-member-function",
    "-Wno-unused-parameter",
    "-Wno-unused-private-field",
    "-Wno-unused-variable",
    "-Wno-used-but-marked-unused",
] + if_llvm_enables_rtti(["-frtti"], ["-fno-rtti"]
) + if_llvm_enables_eh(["-fexceptions"], ["-fno-exceptions"])

llvm_win_copts = [
    "/bigobj",
    "-wd4141",
    "-wd4146",
    "-wd4244",
    "-wd4267",
    "-wd4624",
    "-w14062",
    "-we4238",
] + if_llvm_enables_rtti(["/GR"], ["/GR-"])
  # Bazel currently pass /EHsc to enable exception by default.
  # We cannot disable exceptions: a lot of warnings D9025 will be generated.
#+ if_llvm_enables_eh(
#        ["/EHsc"],
#        ["/EHs-c-", "/D_HAS_EXCEPTIONS=0"])

llvm_cxx_linked = %{LLVM_CXX_LINKED}

llvm_targets = [
%{LLVM_TARGETS}
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
