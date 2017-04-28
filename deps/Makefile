all: libexjl.so

libexjl.so: libexjl.c
	$(CC) $(CPPFLAGS) $(CFLAGS) $(CWARN) -shared -fPIC -o $@ $<
