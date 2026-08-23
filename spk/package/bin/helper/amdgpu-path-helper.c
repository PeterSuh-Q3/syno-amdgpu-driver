#include <stdio.h>
#include <string.h>
#include <errno.h>
#include <sys/stat.h>
#include <unistd.h>

#define TARGET "/var/packages/syno-amdgpu-runtime/target/bin/amdgpu_top"
#define SHIM   "/usr/bin/amdgpu_top"

int main(int argc, char *argv[]) {
    struct stat st;
    char target[512];
    ssize_t n;
    if (argc != 2 || (strcmp(argv[1], "install") && strcmp(argv[1], "remove"))) {
        fprintf(stderr, "usage: amdgpu-path-helper {install|remove}\n");
        return 2;
    }
    if (setuid(0) != 0) {
        perror("amdgpu-path-helper: setuid");
        return 1;
    }
    if (lstat(SHIM, &st) == 0) {
        if (!S_ISLNK(st.st_mode) || (n = readlink(SHIM, target, sizeof(target) - 1)) < 0) {
            fprintf(stderr, "amdgpu-path-helper: refusing to replace non-runtime path %s\n", SHIM);
            return 1;
        }
        target[n] = '\0';
        if (strcmp(target, TARGET) != 0) {
            fprintf(stderr, "amdgpu-path-helper: refusing to replace non-runtime link %s\n", SHIM);
            return 1;
        }
    } else if (errno != ENOENT) {
        perror("amdgpu-path-helper: lstat");
        return 1;
    }
    if (!strcmp(argv[1], "remove")) {
        if (lstat(SHIM, &st) != 0 && errno == ENOENT)
            return 0;
        if (unlink(SHIM) != 0) {
            perror("amdgpu-path-helper: unlink");
            return 1;
        }
        return 0;
    }
    if (lstat(SHIM, &st) == 0)
        return 0;
    if (errno != ENOENT) {
        perror("amdgpu-path-helper: replace");
        return 1;
    }
    if (symlink(TARGET, SHIM) != 0) {
        perror("amdgpu-path-helper: symlink");
        return 1;
    }
    return 0;
}
