DEVICE     = attiny10
CLOCK      = 8000000
PROGRAMMER = usbasp
PORT	   = usb
BAUD       = 19200
FILENAME   = demo
COMPILE    = avr-gcc -Wall -Os -mmcu=$(DEVICE) -Wl,-Map,asm-code.map
 
all: build
 
build:
	$(COMPILE) -c $(FILENAME).c -o $(FILENAME).o
	$(COMPILE) -S $(FILENAME).c
	$(COMPILE) -o $(FILENAME).elf $(FILENAME).o
	avr-objcopy -j .text -j .data -O ihex $(FILENAME).elf $(FILENAME).hex
	avr-size --format=avr --mcu=$(DEVICE) $(FILENAME).elf

upload:
	avrdude -v -p $(DEVICE) -c $(PROGRAMMER) -P $(PORT) -U flash:w:$(FILENAME).hex:i 

clean:
	rm $(FILENAME).o
	rm $(FILENAME).elf
	rm $(FILENAME).hex
