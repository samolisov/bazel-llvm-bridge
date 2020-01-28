#ifndef LLVM_TARGET_CUSTOMREGISTERINFO_H
#define LLVM_TARGET_CUSTOMREGISTERINFO_H

#include "llvm/CodeGen/TargetRegisterInfo.h"

#define GET_REGINFO_ENUM
#define GET_REGINFO_HEADER
#include "custom_register_info.inc"

namespace llvm {

class Triple;

class CustomRegisterInfo final : public CustomGenRegisterInfo {
public:
    explicit CustomRegisterInfo(const Triple &TT);

    // Must be implemented to not be abstract
    const MCPhysReg *
    getCalleeSavedRegs(const MachineFunction* MF) const override;

    BitVector getReservedRegs(const MachineFunction &MF) const override;

    void eliminateFrameIndex(MachineBasicBlock::iterator MI,
                             int SPAdj, unsigned FIOperandNum,
                             RegScavenger *RS = nullptr) const override;

    unsigned getFrameRegister(const MachineFunction &MF) const override;
};

} // End llvm namespace

#endif
