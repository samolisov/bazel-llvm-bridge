#include "custom_register_info.h"
#include "custom_frame_lowering.h"

#include "llvm/ADT/BitVector.h"
#include "llvm/CodeGen/MachineFunction.h"
#include "llvm/CodeGen/TargetSubtargetInfo.h"

namespace llvm {
class Triple;
} // namespace llvm

using namespace llvm;

#define GET_REGINFO_TARGET_DESC
#include "custom_register_info.inc"

CustomRegisterInfo::CustomRegisterInfo(const Triple &TT)
    : CustomGenRegisterInfo(custom::WRA) {}

const MCPhysReg *
CustomRegisterInfo::getCalleeSavedRegs(const MachineFunction* MF) const {
    llvm_unreachable("Method getCalleeSavedRegs is not implemented for custom");
    return nullptr;
}

BitVector
CustomRegisterInfo::getReservedRegs(const MachineFunction &MF) const {
    llvm_unreachable("Method getReservedRegs is not implemented for custom");
    return BitVector(getNumRegs());
}

void
CustomRegisterInfo::eliminateFrameIndex(MachineBasicBlock::iterator MI,
                                        int SPAdj, unsigned FIOperandNum,
                                        RegScavenger *RS) const {
    llvm_unreachable("Method eliminateFrameIndex is not implemented for custom");
}

Register
CustomRegisterInfo::getFrameRegister(const MachineFunction &MF) const {
    llvm_unreachable("Method getFrameRegister is not implemented for custom");
    return custom::WRA;
}
