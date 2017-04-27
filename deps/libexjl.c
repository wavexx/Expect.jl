#include <termios.h>
#include <sys/ioctl.h>
#include <unistd.h>
#include <stdio.h>
#include <stdint.h>
#include <string.h>

extern int jl_uv_handle(void*);


int exjl_set_cloexec(int fd)
{
  return ioctl(fd, FIOCLEX);
}


int exjl_sendeof(void* tty)
{
  struct termios buf;
  int fd, ret;
  uint8_t seq[2];

  // fetch current discipline
  fd = jl_uv_handle(tty);
  tcgetattr(fd, &buf);
  if(ret != 0) return -1;

  // enable ICANON processing without ECHO
  buf.c_lflag |= ICANON;
  buf.c_lflag &= ~(ECHO | ECHONL);
  tcsetattr(fd, TCSADRAIN, &buf);
  if(ret != 0) return -1;

  // send EOF
  seq[0] = '\n';
  seq[1] = buf.c_cc[VEOF];
  ret = write(fd, seq, 2);
  if(ret != 2) return -1;

  return 0;
}
