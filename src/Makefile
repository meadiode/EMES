
DEVICE        = attiny10
PROGRAMMER    = usbasp
DRIVER        = avrdude
PORT          = usb
BUILD_DIR     = build
CROSS_COMPILE = avr-

RM     = rm
ECHO   = @echo
CP     = cp
MKDIR  = mkdir
SED    = sed

AS      = $(CROSS_COMPILE)as
AR      = $(CROSS_COMPILE)ar
GCC     = $(CROSS_COMPILE)gcc
CC      = $(CROSS_COMPILE)gcc
LD      = $(CROSS_COMPILE)ld
OBJCOPY = $(CROSS_COMPILE)objcopy
SIZE    = $(CROSS_COMPILE)size
STRIP   = $(CROSS_COMPILE)strip

CFLAGS =
CFLAGS += -Wall
CFLAGS += -Os
CFLAGS += -mmcu=$(DEVICE)

COMPILE = $(GCC) $(CFLAGS)


all: demo

$(BUILD_DIR):
	$(MKDIR) -p $@

disable_reset_fuse:
	$(DRIVER) -c $(PROGRAMMER) -p $(DEVICE) -U fuse:w:0xFE:m
.PHONY: disable_reset_fuse

demo: $(BUILD_DIR)
	$(COMPILE) -c demo.c -o $(BUILD_DIR)/demo.o
	$(COMPILE) -o $(BUILD_DIR)/demo.elf $(BUILD_DIR)/demo.o
	$(OBJCOPY) -j .text -j .data -O ihex $(BUILD_DIR)/demo.elf $(BUILD_DIR)/demo.hex
	$(SIZE) --format=avr --mcu=$(DEVICE) $(BUILD_DIR)/demo.elf

demo_upload: demo
	$(DRIVER) -v -p $(DEVICE) -c $(PROGRAMMER) -P $(PORT) -U flash:w:$(BUILD_DIR)/demo.hex:i
.PHONY: demo_upload

clean:
	$(RM) -rf $(BUILD_DIR)
.PHONY: clean

