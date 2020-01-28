//===- custom_register_class.td - Describe the Custom Register Classes --*- tablegen -*-==//

// General Purpose Registers
def GR8 : RegisterClass<"custom", [i8],  8,
        (add R1, R2, R3, R4, R1H, R2H, R3H, R4H)> {
  let AltOrders = [(sub GR8, R1H, R2H, R3H, R4H)];
}

def GR16 : RegisterClass<"custom", [i16], 16,
        (add RX, RY, RZ, RA)>;

let isAllocatable = 0 in
def GRH16 : RegisterClass<"custom", [i16], 16,
        (add HRX, HRY, HRZ, HRA)>;

def GR32 : RegisterClass<"custom", [i32], 32,
        (add WRX, WRY, WRZ, WRA)>;

def GR64 : RegisterClass<"custom", [i64], 64,
        (add SRX, SRY, SRZ, SRA)>;

def GR128 : RegisterClass<"custom", [i128], 128,
        (add ZRX, ZRY, ZRZ, ZRA)>;
