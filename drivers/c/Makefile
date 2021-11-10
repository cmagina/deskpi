all: pwmControlFan fanStop safecutoffpower

pwmControlFan: pwmControlFan.c
	$(CC) $(CFLAGS) $(LDFLAGS) -o $@ $^
fanStop: fanStop.c
	$(CC) $(CFLAGS) $(LDFLAGS) -o $@ $^
safecutoffpower: safecutoffpower.c 
	$(CC) $(CFLAGS) $(LDFLAGS) -o $@ $^

install: pwmControlFan fanStop safecutoffpower
	$(INSTALL) --mode 0755 --context=system_u:object_r:bin_t:s0 -t /usr/bin \
    	pwmFanControl \
    	fanStop \
		safecutoffpower

.PHONY: clean
clean:
	$(RM) safecutoffpower pwmControlFan fanStop
