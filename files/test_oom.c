#define _GNU_SOURCE
#include <sched.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <errno.h>
#include <fcntl.h>
#include <unistd.h>

int main(void) {
    // Steg 1: Försök skapa en ny user namespace.
    printf("Försöker skapa user namespace (unshare)...\n");
    if (unshare(CLONE_NEWUSER) == -1) {
        perror("FATALT FEL: unshare misslyckades");
        printf("Detta betyder att ditt system INTE stödjer rootless containers.\n");
        return 1;
    }
    printf("Framgång! User namespace skapad.\n");

    // Steg 2: Försök skriva till oom_score_adj inuti den nya namnrymden.
    printf("Försöker skriva '-1000' till /proc/self/oom_score_adj...\n");
    
    int fd = open("/proc/self/oom_score_adj", O_WRONLY);
    if (fd < 0) {
        perror("FATALT FEL: kunde inte öppna oom_score_adj");
        return 1;
    }

    const char* score = "-1000";
    if (write(fd, score, strlen(score)) < 0) {
        perror("FATALT FEL: kunde inte skriva till oom_score_adj");
        close(fd);
        return 1;
    }

    close(fd);
    printf("FRAMGÅNG! Operationen lyckades.\n");
    
    return 0;
}
