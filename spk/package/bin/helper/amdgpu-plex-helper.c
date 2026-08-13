#define _GNU_SOURCE
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <unistd.h>

#define BACKEND "/var/packages/syno-amdgpu-runtime/target/bin/amdgpu-plex-link.sh"

int main(int argc, char *argv[]) {
    if (argc != 2 || (strcmp(argv[1], "patch") && strcmp(argv[1], "restore") && strcmp(argv[1], "restart"))) {
        fprintf(stderr, "usage: amdgpu-plex-helper {patch|restore|restart}\n");
        return 2;
    }
    if (setuid(0) != 0) {
        perror("amdgpu-plex-helper: setuid");
        return 1;
    }
    if (clearenv() != 0) {
        fputs("amdgpu-plex-helper: clearenv failed\n", stderr);
        return 1;
    }
    setenv("PATH", "/usr/bin:/bin:/usr/sbin:/sbin", 1);
    execl("/bin/sh", "sh", BACKEND, argv[1], (char *)NULL);
    perror("amdgpu-plex-helper: execl");
    return 1;
}
