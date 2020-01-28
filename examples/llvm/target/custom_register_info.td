//===- custom_register_info.td - Describe the Custom Register File --*- tablegen -*-==//

include "llvm/Target/Target.td"

def CustomInstrInfo : InstrInfo;

def Custom : Target {
    // Information about the instructions...
    let InstructionSet = CustomInstrInfo;
    let AllowRegisterRenaming = 1;
}

class CustomReg<string n, bits<16> Enc, list<Register> subregs = []> : Register<n> {
    let Namespace = "custom";
    let HWEncoding = Enc;
    let SubRegs = subregs;
}

let Namespace = "custom" in {
    def sub_8bit     : SubRegIndex<8>;
    def sub_8bit_hi  : SubRegIndex<8, 8>;
    def sub_16bit    : SubRegIndex<16>;
    def sub_16bit_hi : SubRegIndex<16, 16>;
    def sub_32bit    : SubRegIndex<32>;
    def sub_64bit    : SubRegIndex<64>;
}

// 8-bit registers
// Low registers
def R1 : CustomReg<"r1", 0>;
def R2 : CustomReg<"r2", 1>;
def R3 : CustomReg<"r3", 2>;
def R4 : CustomReg<"r4", 3>;

// High registers.
def R1H : CustomReg<"r1h", 4>;
def R2H : CustomReg<"r2h", 5>;
def R3H : CustomReg<"r3h", 6>;
def R4H : CustomReg<"r4h", 7>;

// 16-bit registers
let SubRegIndices = [sub_8bit, sub_8bit_hi], CoveredBySubRegs = 1 in {
def RX : CustomReg<"rx", 0, [R1,R1H]>;
def RY : CustomReg<"ry", 1, [R2,R2H]>;
def RZ : CustomReg<"rz", 2, [R3,R3H]>;
def RA : CustomReg<"ra", 3, [R4,R4H]>;
}
def IP : CustomReg<"ip", 0>;

let isArtificial = 1 in {
// High word of the low 32 bits of the super-register:
def HRX   : CustomReg<"", -1>;
def HRY   : CustomReg<"", -1>;
def HRZ   : CustomReg<"", -1>;
def HRA   : CustomReg<"", -1>;
}

// 32-bit registers
let SubRegIndices = [sub_16bit, sub_16bit_hi], CoveredBySubRegs = 1 in {
def WRX : CustomReg<"wrx", 0, [RX, HRX]>;
def WRY : CustomReg<"wry", 1, [RY, HRY]>;
def WRZ : CustomReg<"wrz", 2, [RZ, HRZ]>;
def WRA : CustomReg<"wra", 3, [RA, HRA]>;
}

// 64-bit registers
let SubRegIndices = [sub_32bit] in {
def SRX : CustomReg<"srx", 0, [WRX]>;
def SRY : CustomReg<"sry", 1, [WRY]>;
def SRZ : CustomReg<"srz", 2, [WRZ]>;
def SRA : CustomReg<"sra", 3, [WRA]>;
}

// 128-bit registers
let SubRegIndices = [sub_64bit] in {
def ZRX : CustomReg<"zrz", 0, [SRX]>;
def ZRY : CustomReg<"zry", 1, [SRY]>;
def ZRZ : CustomReg<"zrz", 2, [SRZ]>;
def ZRA : CustomReg<"zra", 3, [SRA]>;
}

include "custom_register_class.td"
