#define _GNU_SOURCE
#include <sched.h>
#include <stdio.h>
#include <stdlib.h>
#include <errno.h>

int main(void) {
    printf("Försöker skapa en ny user namespace med unshare(CLONE_NEWUSER)...\n");

    // Detta är det exakta systemsamtalet som rootless Podman behöver.
    if (unshare(CLONE_NEWUSER) == -1) {
        // Om det misslyckas, kommer perror() att översätta den interna
        // felkoden (errno) från kärnan till ett mänskligt läsbart meddelande.
        perror("unshare misslyckades");
        return 1;
    }

    printf("Lyckades! Ditt system stödjer unprivileged user namespaces.\n");
    
    return 0;
}
