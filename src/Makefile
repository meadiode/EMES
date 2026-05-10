
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


all: test_util

$(BUILD_DIR):
	$(MKDIR) -p $@

disable_reset_fuse:
	$(DRIVER) -c $(PROGRAMMER) -p $(DEVICE) -U fuse:w:0xFE:m
.PHONY: disable_reset_fuse


test_util: $(BUILD_DIR)
	$(COMPILE) -c test_util.S -o $(BUILD_DIR)/test_util.o
	$(COMPILE) -nostdlib -o $(BUILD_DIR)/test_util.elf $(BUILD_DIR)/test_util.o
	$(OBJCOPY) -j .text -j .data -O ihex $(BUILD_DIR)/test_util.elf $(BUILD_DIR)/test_util.hex
	$(SIZE) --format=avr --mcu=$(DEVICE) $(BUILD_DIR)/test_util.elf

test_util_upload: test_util
	$(DRIVER) -v -p $(DEVICE) -c $(PROGRAMMER) -P $(PORT) -U flash:w:$(BUILD_DIR)/test_util.hex:i
.PHONY: test_util_upload


pong: $(BUILD_DIR)
	$(COMPILE) -c pong.S -o $(BUILD_DIR)/pong.o
	$(COMPILE) -nostdlib -o $(BUILD_DIR)/pong.elf $(BUILD_DIR)/pong.o
	$(OBJCOPY) -j .text -j .data -O ihex $(BUILD_DIR)/pong.elf $(BUILD_DIR)/pong.hex
	$(SIZE) --format=avr --mcu=$(DEVICE) $(BUILD_DIR)/pong.elf

pong_upload: pong
	$(DRIVER) -v -p $(DEVICE) -c $(PROGRAMMER) -P $(PORT) -U flash:w:$(BUILD_DIR)/pong.hex:i
.PHONY: pong_upload

snek: $(BUILD_DIR)
	$(COMPILE) -c snek.S -o $(BUILD_DIR)/snek.o
	$(COMPILE) -nostdlib -o $(BUILD_DIR)/snek.elf $(BUILD_DIR)/snek.o
	$(OBJCOPY) -j .text -j .data -O ihex $(BUILD_DIR)/snek.elf $(BUILD_DIR)/snek.hex
	$(SIZE) --format=avr --mcu=$(DEVICE) $(BUILD_DIR)/snek.elf

snek_upload: snek
	$(DRIVER) -v -p $(DEVICE) -c $(PROGRAMMER) -P $(PORT) -U flash:w:$(BUILD_DIR)/snek.hex:i
.PHONY: snek_upload

brik: $(BUILD_DIR)
	$(COMPILE) -c brik.S -o $(BUILD_DIR)/brik.o
	$(COMPILE) -nostdlib -o $(BUILD_DIR)/brik.elf $(BUILD_DIR)/brik.o
	$(OBJCOPY) -j .text -j .data -O ihex $(BUILD_DIR)/brik.elf $(BUILD_DIR)/brik.hex
	$(SIZE) --format=avr --mcu=$(DEVICE) $(BUILD_DIR)/brik.elf

brik_upload: brik
	$(DRIVER) -v -p $(DEVICE) -c $(PROGRAMMER) -P $(PORT) -U flash:w:$(BUILD_DIR)/brik.hex:i
.PHONY: brik_upload

egg: $(BUILD_DIR)
	$(COMPILE) -c egg.S -o $(BUILD_DIR)/egg.o
	$(COMPILE) -nostdlib -o $(BUILD_DIR)/egg.elf $(BUILD_DIR)/egg.o
	$(OBJCOPY) -j .text -j .data -O ihex $(BUILD_DIR)/egg.elf $(BUILD_DIR)/egg.hex
	$(SIZE) --format=avr --mcu=$(DEVICE) $(BUILD_DIR)/egg.elf

egg_upload: egg
	$(DRIVER) -v -p $(DEVICE) -c $(PROGRAMMER) -P $(PORT) -U flash:w:$(BUILD_DIR)/egg.hex:i
.PHONY: egg_upload

simon: $(BUILD_DIR)
	$(COMPILE) -c simon.S -o $(BUILD_DIR)/simon.o
	$(COMPILE) -nostdlib -o $(BUILD_DIR)/simon.elf $(BUILD_DIR)/simon.o
	$(OBJCOPY) -j .text -j .data -O ihex $(BUILD_DIR)/simon.elf $(BUILD_DIR)/simon.hex
	$(SIZE) --format=avr --mcu=$(DEVICE) $(BUILD_DIR)/simon.elf

simon_upload: simon
	$(DRIVER) -v -p $(DEVICE) -c $(PROGRAMMER) -P $(PORT) -U flash:w:$(BUILD_DIR)/simon.hex:i
.PHONY: simon_upload

stak: $(BUILD_DIR)
	$(COMPILE) -c stak.S -o $(BUILD_DIR)/stak.o
	$(COMPILE) -nostdlib -o $(BUILD_DIR)/stak.elf $(BUILD_DIR)/stak.o
	$(OBJCOPY) -j .text -j .data -O ihex $(BUILD_DIR)/stak.elf $(BUILD_DIR)/stak.hex
	$(SIZE) --format=avr --mcu=$(DEVICE) $(BUILD_DIR)/stak.elf

stak_upload: stak
	$(DRIVER) -v -p $(DEVICE) -c $(PROGRAMMER) -P $(PORT) -U flash:w:$(BUILD_DIR)/stak.hex:i
.PHONY: stak_upload

birb: $(BUILD_DIR)
	$(COMPILE) -c birb.S -o $(BUILD_DIR)/birb.o
	$(COMPILE) -nostdlib -o $(BUILD_DIR)/birb.elf $(BUILD_DIR)/birb.o
	$(OBJCOPY) -j .text -j .data -O ihex $(BUILD_DIR)/birb.elf $(BUILD_DIR)/birb.hex
	$(SIZE) --format=avr --mcu=$(DEVICE) $(BUILD_DIR)/birb.elf

birb_upload: birb
	$(DRIVER) -v -p $(DEVICE) -c $(PROGRAMMER) -P $(PORT) -U flash:w:$(BUILD_DIR)/birb.hex:i
.PHONY: birb_upload


clean:
	$(RM) -rf $(BUILD_DIR)
.PHONY: clean
