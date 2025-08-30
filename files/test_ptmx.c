#define _XOPEN_SOURCE 600
#include <stdlib.h>
#include <fcntl.h>
#include <stdio.h>
#include <errno.h>

int main(void) {
    int master_fd;

    printf("Försöker öppna /dev/ptmx via posix_openpt()...\n");

    master_fd = posix_openpt(O_RDWR | O_NOCTTY);

    if (master_fd < 0) {
        // Detta är den viktiga raden: perror() kommer att översätta
        // den interna felkoden (errno) till ett mänskligt läsbart meddelande.
        perror("posix_openpt misslyckades");
        return 1;
    }

    printf("Lyckades! Fick master pseudo-terminal med fil-deskriptor: %d\n", master_fd);
    
    return 0;
}
