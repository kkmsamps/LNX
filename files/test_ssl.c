#include <stdio.h>
#include <openssl/ssl.h>
#include <openssl/opensslv.h>

int main() {
    // Försök anropa en grundläggande funktion från libssl
    SSL_library_init();
    
    // Skriv ut den version som rapporteras av header-filen
    printf("OpenSSL version enligt header: %s\n", OPENSSL_VERSION_TEXT);

    // Skriv ut den version som rapporteras av det länkade biblioteket
    printf("OpenSSL version enligt bibliotek: %s\n", SSLeay_version(SSLEAY_VERSION));

    printf("Om du ser detta, fungerar kompilering och länkning mot OpenSSL!\n");

    return 0;
}
