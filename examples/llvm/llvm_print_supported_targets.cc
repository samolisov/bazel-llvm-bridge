#include <iostream>

int main(int argc, char** argv) {
    std::cout << "Installed LLVM supports the following targets:" << std::endl;
#ifdef LLVM_SUPPORTS_TARGET_AARCH64
    std::cout << " - AArch64" << std::endl;
#endif
#ifdef LLVM_SUPPORTS_TARGET_AMDGPU
    std::cout << " - AMDGPU" << std::endl;
#endif
#ifdef LLVM_SUPPORTS_TARGET_ARM
    std::cout << " - ARM" << std::endl;
#endif
#ifdef LLVM_SUPPORTS_TARGET_BPF
    std::cout << " - BPF" << std::endl;
#endif
#ifdef LLVM_SUPPORTS_TARGET_HEXAGON
    std::cout << " - Hexagon" << std::endl;
#endif
#ifdef LLVM_SUPPORTS_TARGET_LANAI
    std::cout << " - Lanai" << std::endl;
#endif
#ifdef LLVM_SUPPORTS_TARGET_MIPS
    std::cout << " - Mips" << std::endl;
#endif
#ifdef LLVM_SUPPORTS_TARGET_MSP430
    std::cout << " - MSP430" << std::endl;
#endif
#ifdef LLVM_SUPPORTS_TARGET_NVPTX
    std::cout << " - NVPTX" << std::endl;
#endif
#ifdef LLVM_SUPPORTS_TARGET_POWERPC
    std::cout << " - PowerPC" << std::endl;
#endif
#ifdef LLVM_SUPPORTS_TARGET_RISCV
    std::cout << " - RISCV" << std::endl;
#endif
#ifdef LLVM_SUPPORTS_TARGET_SPARC
    std::cout << " - Sparc" << std::endl;
#endif
#ifdef LLVM_SUPPORTS_TARGET_SYSTEMZ
    std::cout << " - SystemZ" << std::endl;
#endif
#ifdef LLVM_SUPPORTS_TARGET_WEBASSEMBLY
    std::cout << " - WebAssembly" << std::endl;
#endif
#ifdef LLVM_SUPPORTS_TARGET_X86
    std::cout << " - X86" << std::endl;
#endif
#ifdef LLVM_SUPPORTS_TARGET_XCORE
    std::cout << " - XCore" << std::endl;
#endif
    return 0;
}
