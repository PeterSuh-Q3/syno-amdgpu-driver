#include <stdio.h>
#include <string.h>
#include <unistd.h>

#define TARGET "/var/packages/syno-amdgpu-runtime/target/bin/amdgpu_top"
#define SHIM   "/usr/bin/amdgpu_top"

int main(int argc, char *argv[]) {
    if (argc != 2 || (strcmp(argv[1], "install") && strcmp(argv[1], "remove"))) {
        fprintf(stderr, "usage: amdgpu-path-helper {install|remove}\n");
        return 2;
    }
    if (setuid(0) != 0) {
        perror("amdgpu-path-helper: setuid");
        return 1;
    }
    if (!strcmp(argv[1], "remove")) {
        if (unlink(SHIM) != 0 && access(SHIM, F_OK) == 0) {
            perror("amdgpu-path-helper: unlink");
            return 1;
        }
        return 0;
    }
    if (unlink(SHIM) != 0 && access(SHIM, F_OK) == 0) {
        perror("amdgpu-path-helper: replace");
        return 1;
    }
    if (symlink(TARGET, SHIM) != 0) {
        perror("amdgpu-path-helper: symlink");
        return 1;
    }
    return 0;
}
