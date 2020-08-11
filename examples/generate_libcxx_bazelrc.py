import sys

FILE = "libcxx.bazelrc"

def main():
    lib, include = parse_command_line()
    if not lib or not include:
        print_usage()
        exit(1)
    with open(FILE, "w") as f:
        f.write("build:libc++ --repo_env BAZEL_CXXOPTS=\"--stdlib=libc++:-isystem%s\"\n" % include)
        f.write("build:libc++ --repo_env BAZEL_LINKOPTS=\"--stdlib=libc++\"\n")
        f.write("build:libc++ --repo_env BAZEL_LINKLIBS=\"-L%s:-Wl,-rpath,%s:-lc++\"\n" % (lib, lib))

def print_usage():
    print("This script generates a libcxx.bazelrc file in the current directory")
    print("Usage: python[3] generate_libcxx_bazelrc.py -L<path to libc++.so.1> -I<path to libc++ headers: iostream, etc.>")

def parse_command_line():

    def is_lib_param(arg):
        return len(arg) > 2 and arg.startswith("-L")

    def is_include_param(arg):
        return len(arg) > 2 and arg.startswith("-I")

    def parse_param(arg):
        return arg[2:].strip()

    args = sys.argv
    if len(args) >= 3 and ((is_lib_param(args[1]) and is_include_param(args[2]))
            or (is_include_param(args[1]) and is_lib_param(args[2]))):
        lib = parse_param(args[1] if is_lib_param(args[1]) else args[2])
        include = parse_param(args[1] if is_include_param(args[1]) else args[2])
        return (lib, include)

    return (None, None)

if __name__ == "__main__":
    main()
