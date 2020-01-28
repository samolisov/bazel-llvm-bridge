#include "target/custom_register_info.h"

#include "llvm/ADT/Triple.h"
#include "llvm/Support/raw_os_ostream.h"

using namespace llvm;

int main(int argc, char** argv) {
    Triple TheTriple("custom-linux");
    CustomRegisterInfo TRI{TheTriple};

    for (auto rcit = TRI.regclass_begin(), rcite = TRI.regclass_end();
         rcit != rcite; ++rcit) {
        errs() << "Register Class #" << (*rcit)->getID() << " "
               << TRI.getRegClassName(*rcit)
               << " (" << (*rcit)->getNumRegs() << " regs"
               << ((*rcit)->isAllocatable() ? ", allocatable": "")
               << ") " << TRI.getRegSizeInBits(**rcit) << " bits:"
               << "\n";
        for (auto&& reg : **rcit) {
            errs() << TRI.getName(reg)
                   << (CustomRegisterInfo::isPhysicalRegister(reg) ?
                        " (physical)\n" : "\n");
        }
    }

    return 0;
}
