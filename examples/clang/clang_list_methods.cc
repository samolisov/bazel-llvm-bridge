#include "llvm_config.h"

extern "C" {
#include "clang-c/Index.h"
}

#include "llvm/Support/CommandLine.h"
#include <iostream>
#include <sstream>
#include <string>

#define ENDLINE "\n"
#define EMPTY ""
#define SPACE " "
#define DEFINITION_MARKER "{}"

namespace llvmdemo {
// Demo class just to show how method declaration works if the source file is assigned as an argument of the program.
class A {
    public:
        A();
        A(const int &);
        void dome(const A& self, int i, long long j);
    private:
        ~A() {}; // We don't intend to inherit from A
};
}

std::string justAFunction();

using namespace llvm;

static cl::opt<std::string>
FileName(cl::Positional, cl::desc("Input file"), cl::Required);

std::string str(const CXString& s) {
    std::string result = clang_getCString(s);
    clang_disposeString(s);
    return result;
}

std::string isDefinition(const CXCursor& cursor) {
    return clang_isCursorDefinition(cursor) ? DEFINITION_MARKER : EMPTY;
}

std::string getFullQualifiedName(const CXCursor& cursor) {
    std::string qualifiedName = str(clang_getCursorSpelling(cursor));
    auto semanticParent = clang_getCursorSemanticParent(cursor);
    if (clang_getCursorKind(semanticParent) == CXCursor_TranslationUnit) {
        return qualifiedName;
    } else {
        return getFullQualifiedName(semanticParent) + "::" + qualifiedName;
    }
}

std::string getFunctionPrototype(const CXCursor& cursor) {
    std::ostringstream resultstream;

    auto type = clang_getCursorType(cursor);
    auto result_type = str(clang_getTypeSpelling(clang_getResultType(type)));
    auto function_name = getFullQualifiedName(cursor);

    resultstream << result_type.c_str() << SPACE << function_name.c_str() << '(';

    int num_args = clang_Cursor_getNumArguments(cursor);
    for (int i = 0; i < num_args; ++i) {
        auto arg_cursor = clang_Cursor_getArgument(cursor, i);
        auto arg_name = str(clang_getCursorSpelling(arg_cursor));
        if (arg_name.empty()) {
            arg_name = "no type";
        }
        auto arg_data_type = str(clang_getTypeSpelling(clang_getArgType(type, i)));

        resultstream << arg_data_type.c_str() << SPACE << arg_name.c_str();
        if (i < num_args - 1) {
            resultstream << ',' << SPACE;
        }
    }
    resultstream << ')' << SPACE << isDefinition(cursor).c_str() << ENDLINE;

    return resultstream.str();
}

std::string getFunctionLocation(const CXCursor& cursor) {
    std::ostringstream resultstream;
    auto location = clang_getCursorLocation(cursor);
    CXString fName;
    unsigned line = 0, col = 0;
    clang_getPresumedLocation(location, &fName, &line, &col);
    resultstream << str(fName).c_str() << ":" << line << ":" << col << "\n";
    return resultstream.str();
}

enum CXChildVisitResult visitFunction(CXCursor cursor, CXCursor parent, CXClientData client_data) {
    if (clang_Location_isFromMainFile(clang_getCursorLocation(cursor)) == 0)
        return CXChildVisit_Continue;

    CXCursorKind kind = clang_getCursorKind(cursor);
    if (kind == CXCursor_CXXMethod    ||
        kind == CXCursor_FunctionDecl ||
        kind == CXCursor_Constructor  ||
        kind == CXCursor_Destructor   ||
        kind == CXCursor_FunctionTemplate)
    {
        std::cout << getFunctionLocation(cursor) << getFunctionPrototype(cursor) << "\n";
        return CXChildVisit_Continue;
    }
    return CXChildVisit_Recurse;
}

int main(int argc, char** argv) {
    cl::ParseCommandLineOptions(argc, argv, "AST Traversal Example");
    CXIndex index = clang_createIndex(0, 0);
    const char *args[] = {
        CLANG_LIB_INCLUDE_COMMAND_ARG,
        LLVM_INCLUDE_COMMAND_ARG,
        "-I./include"
    };

    CXTranslationUnit translationUnit = clang_parseTranslationUnit(index, FileName.c_str(), args, 3,
        NULL, 0, CXTranslationUnit_None); // CXTranslationUnit_SkipFunctionBodies doesn't parse bodies and we
                                          // won't able to recognize if a function is a definition.
    CXCursor cursor = clang_getTranslationUnitCursor(translationUnit);
    clang_visitChildren(cursor, visitFunction, NULL);
    clang_disposeTranslationUnit(translationUnit);
    clang_disposeIndex(index);

    // TODO: get all functions without definitions using clang_getCursorDefinition(CXCursor)
    return 0;
}
