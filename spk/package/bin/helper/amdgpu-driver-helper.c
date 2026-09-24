#define _GNU_SOURCE
#include <errno.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

int main(int argc, char **argv) {
    if (argc != 2 || (strcmp(argv[1], "install") != 0 &&
                      strcmp(argv[1], "restore") != 0 &&
                      strcmp(argv[1], "load") != 0)) {
        return 2;
    }
    if (geteuid() != 0) return 1;
    clearenv();
    setenv("PATH", "/bin:/sbin:/usr/bin:/usr/sbin", 1);
    char *const args[] = {
        "/bin/sh",
        "-p",
        "/var/packages/syno-amdgpu-runtime/target/bin/helper/amdgpu-driver-assets",
        argv[1],
        NULL
    };
    execv(args[0], args);
    return errno ? 111 : 112;
}
