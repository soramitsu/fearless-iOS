#include <ed25519/ed25519/randombytes.h>
#include <ed25519/ed25519/errcode.h>
#include <fcntl.h>   // for open
#include <unistd.h>  // for read, ssize_t
int randombytes(unsigned char *p, int len) {
  int source = open("/dev/urandom", O_RDONLY);
  if (source < 0) {
    return ED25519_ERROR; /* something went wrong */
  } else {
    ssize_t result = read(source, p, len);
    if (result < 0) {
      close(source);
      return ED25519_ERROR; /* something went wrong */
    }
  }

  close(source);

  return ED25519_SUCCESS;
}
