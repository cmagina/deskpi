DESTDIR ?= /usr/local/bin

all: pwmFanControl fanStop safecutoffpower

pwmFanControl: pwmControlFan.c
	$(CC) $(CFLAGS) $(LDFLAGS) -o $@ $^
fanStop: fanStop.c
	$(CC) $(CFLAGS) $(LDFLAGS) -o $@ $^
safecutoffpower: safecutoffpower.c 
	$(CC) $(CFLAGS) $(LDFLAGS) -o $@ $^

install: pwmFanControl fanStop safecutoffpower
	install --mode 0755 --context=system_u:object_r:bin_t:s0 -t $(DESTDIR) \
    	pwmFanControl \
    	fanStop \
		safecutoffpower

uninstall:
	$(RM) $(DESTDIR)/safecutoffpower $(DESTDIR)/pwmFanControl $(DESTDIR)/fanStop

.PHONY: clean
clean:
	$(RM) safecutoffpower pwmFanControl fanStop
