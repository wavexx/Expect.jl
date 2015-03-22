#include <termios.h>
#include <errno.h>

extern int jl_uv_handle(void*);
extern int uv_tty_set_mode(void*, int);

int tty_makeraw(void* tty, int mode) {
  struct termios tmp;
  int fd;

  if (mode == 0)
    return uv_tty_set_mode(tty, 0);

  /* Change the internal mode of the tty struct anyway: this is done in
     order to make uv_tty_* functions work correctly */
  uv_tty_set_mode(tty, 1);

  /* Use cfmakeraw() directly on the handler */
  fd = jl_uv_handle(tty);

  if (tcgetattr(fd, &tmp))
    return -errno;

  cfmakeraw(&tmp);

  if (tcsetattr(fd, TCSADRAIN, &tmp))
    return -errno;

  return 0;
}
