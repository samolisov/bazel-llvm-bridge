#include "custom_frame_lowering.h"

namespace llvm {
class Triple;
} // namespace llvm

using namespace llvm;

bool CustomFrameLowering::hasFP(const MachineFunction &MF) const {
    llvm_unreachable("Method hasFP is not implemented for custom");
    return false;
}

void CustomFrameLowering::emitPrologue(MachineFunction &MF,
                                       MachineBasicBlock &MBB) const {
    llvm_unreachable("Method emitPrologue is not implemented for custom");
}

void CustomFrameLowering::emitEpilogue(MachineFunction &MF,
                                       MachineBasicBlock &MBB) const {
    llvm_unreachable("Method emitEpilogue is not implemented for custom");
}
