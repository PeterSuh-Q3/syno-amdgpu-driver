#define _GNU_SOURCE
#include <errno.h>
#include <fcntl.h>
#include <stdio.h>
#include <string.h>
#include <sys/stat.h>
#include <unistd.h>

#define PLEX_DIR "/var/packages/PlexMediaServer/target"
#define TRANSCODER "Plex Transcoder"
#define BACKUP "Plex Transcoder.pre-amdgpu-runtime.bak"
#define MARKER "# Synology AMDGPU Runtime Plex Transcoder wrapper"

/*
 * Migration-only helper.  Earlier releases replaced Plex Transcoder from a
 * root helper, which means a package-owned Plex directory was in a privileged
 * write path.  Never create a wrapper again.  This helper only atomically
 * restores an existing regular-file backup, refuses symlinks, and performs no
 * shell execution.
 */
int main(void) {
    int dirfd, fd;
    struct stat st;
    char buf[256] = {0};
    ssize_t n;

    if (setuid(0) != 0) {
        perror("amdgpu-plex-restore-helper: setuid");
        return 1;
    }
    dirfd = open(PLEX_DIR, O_RDONLY | O_DIRECTORY | O_CLOEXEC | O_NOFOLLOW);
    if (dirfd < 0)
        return errno == ENOENT ? 0 : 1;

    fd = openat(dirfd, TRANSCODER, O_RDONLY | O_CLOEXEC | O_NOFOLLOW);
    if (fd < 0) {
        close(dirfd);
        return errno == ENOENT ? 0 : 1;
    }
    if (fstat(fd, &st) != 0 || !S_ISREG(st.st_mode)) {
        close(fd);
        close(dirfd);
        return 1;
    }
    n = read(fd, buf, sizeof(buf) - 1);
    close(fd);
    if (n < 0 || !strstr(buf, MARKER)) {
        close(dirfd);
        return 0;
    }

    fd = openat(dirfd, BACKUP, O_RDONLY | O_CLOEXEC | O_NOFOLLOW);
    if (fd < 0 || fstat(fd, &st) != 0 || !S_ISREG(st.st_mode)) {
        if (fd >= 0) close(fd);
        close(dirfd);
        return 1;
    }
    close(fd);
    if (renameat(dirfd, BACKUP, dirfd, TRANSCODER) != 0) {
        perror("amdgpu-plex-restore-helper: renameat");
        close(dirfd);
        return 1;
    }
    close(dirfd);
    return 0;
}
