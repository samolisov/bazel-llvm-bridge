#include "llvm/Bitcode/BitcodeReader.h"
#include "llvm/IR/Function.h"
#include "llvm/IR/Module.h"
#include "llvm/Support/CommandLine.h"
#include "llvm/Support/Error.h"
#include "llvm/Support/ErrorOr.h"
#include "llvm/Support/MemoryBuffer.h"
#include "llvm/Support/raw_os_ostream.h"
#include <iostream>

using namespace llvm;

static cl::opt<std::string> FileName(cl::Positional, cl::desc("Bitcode file"), cl::Required);

int main(int argc, char** argv) {
    cl::ParseCommandLineOptions(argc, argv, "LLVM Hello World\n");
    LLVMContext context;

    ErrorOr<std::unique_ptr<MemoryBuffer>> mb = MemoryBuffer::getFile(FileName);
    if (std::error_code ec = mb.getError()) {
        errs() << ec.message();
        return -1;
    }

    Expected<std::unique_ptr<Module>> m = parseBitcodeFile(mb->get()->getMemBufferRef(), context);
    if (std::error_code ec = errorToErrorCode(m.takeError())) {
        errs() << "Error reading bitcode: " << ec.message() << "\n";
        return -1;
    }

    for (Module::const_iterator I = (*m)->getFunctionList().begin(),
            E = (*m)->getFunctionList().end(); I != E; ++I) {
        if (!I->isDeclaration()) {
            outs() << I->getName() << " has " << I->size() << " basic block(s).\n";
        }
    }

    return 0;
}
