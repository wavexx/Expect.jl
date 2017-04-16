all: constants.jl

constants.jl: constants
	./constants > $@

constants: constants.c
	$(CC) $(CPPFLAGS) $(CFLAGS) $(LDFLAGS) -o $@ $<
