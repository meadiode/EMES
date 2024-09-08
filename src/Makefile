
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


all: pong

$(BUILD_DIR):
	$(MKDIR) -p $@

disable_reset_fuse:
	$(DRIVER) -c $(PROGRAMMER) -p $(DEVICE) -U fuse:w:0xFE:m
.PHONY: disable_reset_fuse

demo: $(BUILD_DIR)
	$(COMPILE) -c demo.c -o $(BUILD_DIR)/demo.o
	$(COMPILE) -S -c demo.c -o $(BUILD_DIR)/demo.s
	$(COMPILE) -o $(BUILD_DIR)/demo.elf $(BUILD_DIR)/demo.o
	$(OBJCOPY) -j .text -j .data -O ihex $(BUILD_DIR)/demo.elf $(BUILD_DIR)/demo.hex
	$(SIZE) --format=avr --mcu=$(DEVICE) $(BUILD_DIR)/demo.elf

demo_upload: demo
	$(DRIVER) -v -p $(DEVICE) -c $(PROGRAMMER) -P $(PORT) -U flash:w:$(BUILD_DIR)/demo.hex:i
.PHONY: demo_upload


pong: $(BUILD_DIR)
	$(COMPILE) -c pong.c -o $(BUILD_DIR)/pong.o
	$(COMPILE) -S -c pong.c -o $(BUILD_DIR)/pong.s
	$(COMPILE) -o $(BUILD_DIR)/pong.elf $(BUILD_DIR)/pong.o
	$(OBJCOPY) -j .text -j .data -O ihex $(BUILD_DIR)/pong.elf $(BUILD_DIR)/pong.hex
	$(SIZE) --format=avr --mcu=$(DEVICE) $(BUILD_DIR)/pong.elf

pong_upload: pong
	$(DRIVER) -v -p $(DEVICE) -c $(PROGRAMMER) -P $(PORT) -U flash:w:$(BUILD_DIR)/pong.hex:i
.PHONY: pong_upload


pong_s: $(BUILD_DIR)
	$(COMPILE) -c pong.S -o $(BUILD_DIR)/pong_s.o
	$(COMPILE) -nostdlib -o $(BUILD_DIR)/pong_s.elf $(BUILD_DIR)/pong_s.o
	$(OBJCOPY) -j .text -j .data -O ihex $(BUILD_DIR)/pong_s.elf $(BUILD_DIR)/pong_s.hex
	$(SIZE) --format=avr --mcu=$(DEVICE) $(BUILD_DIR)/pong_s.elf

pong_s_upload: pong_s
	$(DRIVER) -v -p $(DEVICE) -c $(PROGRAMMER) -P $(PORT) -U flash:w:$(BUILD_DIR)/pong_s.hex:i
.PHONY: pong_s_upload


snake: $(BUILD_DIR)
	$(COMPILE) -c snake.S -o $(BUILD_DIR)/snake.o
	$(COMPILE) -nostdlib -o $(BUILD_DIR)/snake.elf $(BUILD_DIR)/snake.o
	$(OBJCOPY) -j .text -j .data -O ihex $(BUILD_DIR)/snake.elf $(BUILD_DIR)/snake.hex
	$(SIZE) --format=avr --mcu=$(DEVICE) $(BUILD_DIR)/snake.elf

snake_upload: snake
	$(DRIVER) -v -p $(DEVICE) -c $(PROGRAMMER) -P $(PORT) -U flash:w:$(BUILD_DIR)/snake.hex:i
.PHONY: snake_upload



clean:
	$(RM) -rf $(BUILD_DIR)
.PHONY: clean

