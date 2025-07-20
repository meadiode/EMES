
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
	$(COMPILE) -c demo.S -o $(BUILD_DIR)/demo.o
	$(COMPILE) -nostdlib -o $(BUILD_DIR)/demo.elf $(BUILD_DIR)/demo.o
	$(OBJCOPY) -j .text -j .data -O ihex $(BUILD_DIR)/demo.elf $(BUILD_DIR)/demo.hex
	$(SIZE) --format=avr --mcu=$(DEVICE) $(BUILD_DIR)/demo.elf

demo_upload: demo
	$(DRIVER) -v -p $(DEVICE) -c $(PROGRAMMER) -P $(PORT) -U flash:w:$(BUILD_DIR)/demo.hex:i
.PHONY: demo_upload

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


clean:
	$(RM) -rf $(BUILD_DIR)
.PHONY: clean
