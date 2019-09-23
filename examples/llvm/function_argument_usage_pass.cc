#include "llvm/ADT/SmallVector.h"
#include "llvm/ADT/Statistic.h"
#include "llvm/Pass.h"
#include "llvm/IR/Argument.h"
#include "llvm/IR/Function.h"
#include "llvm/IR/Instructions.h"
#include "llvm/IR/Module.h"
#include "llvm/IR/Type.h"
#include "llvm/Support/Debug.h"
#include "llvm/Support/raw_ostream.h"

#define DEBUG_TYPE "ArgUsage"
STATISTIC(NumOfMismatches, "Number of type mismatches are found");

using namespace llvm;

namespace llvm {
    void initializeFunctionArgumentUsagePassPass(PassRegistry&);
}

namespace {
    class FunctionArgumentUsagePass
            : public FunctionPass {
        public:
            struct TypeMismatchRecord {
                const StringRef functionName;
                const unsigned line;
                const bool hasLine;
                const unsigned argNo;
                const Type* expectedType;
                const Type* actualType;

                TypeMismatchRecord(const StringRef functionName,
                        const unsigned line,
                        const bool hasLine,
                        const unsigned argNo,
                        const Type* expectedType,
                        const Type* actualType)
                    : functionName(functionName),
                      line(line),
                      hasLine(hasLine),
                      argNo(argNo),
                      expectedType(expectedType),
                      actualType(actualType)
                {}
            };
            using TypeMismatch = struct TypeMismatchRecord;

        private:
            using TypeMismatchVector = SmallVector<TypeMismatch, 32>;
            TypeMismatchVector typeMismatches;

            template<typename CallInst>
            void analyzeFunctionUsages(Function &F, CallInst *call);
        public:
            using const_iterator = TypeMismatchVector::const_iterator;
            static char ID;
            FunctionArgumentUsagePass() :
                FunctionPass(ID) {
            }

            virtual void getAnalysisUsage(AnalysisUsage &AU) const {
                AU.setPreservesAll();
            }

            virtual const_iterator begin() const {
                return typeMismatches.begin();
            }

            virtual const_iterator end() const {
                return typeMismatches.end();
            }

            virtual bool runOnFunction(Function &F);

            virtual void print(llvm::raw_ostream &O, const Module *M) const;

            virtual void releaseMemory();
    };
}

char FunctionArgumentUsagePass::ID = 0;

INITIALIZE_PASS(FunctionArgumentUsagePass, "fnargusage", "Function Argument Usage Pass",
        false /* Only looks at CFG */,
        false /* Analysis Pass */);

static void dumpFunctionArgs(const Function &F) {
    dbgs() << "function '";
    dbgs().write_escaped(F.getName());
    dbgs() << "' takes " << F.arg_size() << " parameters:\n";
    for (auto a = F.arg_begin(), e = F.arg_end(); a != e; ++a) {
        if (a->hasName()) {
            dbgs() << '\t' << a->getName();
        } else {
            dbgs() << "\tanonymous";
        }
        dbgs() << ": " << *a->getType() << '\n';
    }
}

template<typename CallInst>
void FunctionArgumentUsagePass::analyzeFunctionUsages(Function &F, CallInst *call) {
    bool hasLine = false;
    unsigned line = 0;
    LLVM_DEBUG({
        dbgs() << "and is used in the '";
        dbgs().write_escaped(call->getParent()->getParent()->getName());
        dbgs() << "' function";
        if (auto &debugLoc = call->getDebugLoc()) {
            line = call->getDebugLoc().getLine();
            hasLine = true;
            dbgs() << " (on line: " << line << ')';
        }
        dbgs() << ":\n";
    });
    // check on argument type mismatch
    //   fa - a function's formal argument (an argument from
    //        the signature of the function).
    //   pha - a physical argument, an argument the function
    //         is exactly executed with.
    auto fa = F.arg_begin(), fe = F.arg_end();
    for (auto pha = call->arg_begin(), phe = call->arg_end();
         (fa != fe && pha != phe); ++pha,++fa) {
        const Type *ftypeptr = fa->getType();
        const Type *phtypeptr = pha->get()->getType();

        LLVM_DEBUG({
            dbgs() << "\targ #" << fa->getArgNo();
            if (pha->get()->hasName()) {
                dbgs() << '(' << pha->get()->getName() << ')';
            }
            dbgs() << ": " << *phtypeptr << '\n';
        });
        if (ftypeptr->getTypeID() != phtypeptr->getTypeID()) {
            // type mismatch is here
            // ... register it:
            NumOfMismatches++;
            typeMismatches.emplace_back(F.getName(), line, hasLine,
                    fa->getArgNo(), ftypeptr, phtypeptr);
            LLVM_DEBUG({
                // ... and debug:
                dbgs() << "\ttype mismatch: expected '";
                dbgs() << *ftypeptr <<"' but argument is of type '";
                dbgs() << *phtypeptr << "'\n";
            });
        }
    }
}

bool FunctionArgumentUsagePass::runOnFunction(Function &F) {
    LLVM_DEBUG(dumpFunctionArgs(F));

    for (auto use = F.use_begin(), e = F.use_end(); use != e; ++use) {
        if (CallInst *call = dyn_cast<CallInst>(use->getUser())) {
            analyzeFunctionUsages(F, call);
        } else if (InvokeInst *call = dyn_cast<InvokeInst>(use->getUser())) {
            analyzeFunctionUsages(F, call);
        }
    }
    return false;
}

void FunctionArgumentUsagePass::print(llvm::raw_ostream &O, const Module *M) const {
    for (auto& mismatch : typeMismatches) {
        O << "Function '";
        O.write_escaped(mismatch.functionName);
        O << "'";
        if (mismatch.hasLine) {
            O << " call on line '" << mismatch.line << '\'';
        }
        O << ": argument type mismatch. ";
        O << "Argument #" << mismatch.argNo << ' ';
        O << "Expected '" << *mismatch.expectedType << "' ";
        O << "but argument is of type '" << *mismatch.actualType << "'\n";
    }
}

void FunctionArgumentUsagePass::releaseMemory() {
    LLVM_DEBUG(dbgs() << "Release memory" << '\n');
    // TODO reclaim memory, different functions have different number of users
    typeMismatches.clear();
}
