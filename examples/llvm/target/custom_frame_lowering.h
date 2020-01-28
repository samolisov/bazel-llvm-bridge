#ifndef LLVM_TARGET_CUSTOMFRAMELOWERING_H
#define LLVM_TARGET_CUSTOMFRAMELOWERING_H

#include "llvm/CodeGen/TargetFrameLowering.h"

namespace llvm {

class CustomFrameLowering final : public TargetFrameLowering {
    bool hasFP(const MachineFunction &MF) const override;

    void emitPrologue(MachineFunction &MF,
                      MachineBasicBlock &MBB) const override;

    void emitEpilogue(MachineFunction &MF,
                      MachineBasicBlock &MBB) const override;
};

} // End llvm namespace

#endif
