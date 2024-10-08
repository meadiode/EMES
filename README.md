
# EMES - Epic Minimalist Entertainment System

**EMES** - is a very minimalistic DIY handheld game console. 

Work in progress.

EMES has the following specifications:

 - Screen: 10x7 pixels, LED
 - Input: four button keyboard
 - Sound: Magnetic buzzer
 - Physical dimensions(approx): 25x24x18mm 
 - Removeable 8-pin cartridges

![EMES](images/EMES_01.png)

The console doesn't have an onboard CPU/MCU, instead an MCU is placed on every removable cartridge.

![Cartridges](images/EMES_02.png)

Each cartridge features an ATTiny10 MCU with the following specs:

 - Speed 8MHz
 - Peogram/data flash: 1KB
 - RAM: 32 bytes
 - IO: 4
 - ADC: 8bit

## Games

Currently, two games are implemented and playable - variations of Pong and Snake. 

![EMES jif](images/EMES_03.gif)
![EMES jif](images/EMES_04.gif)


## Planned games

Variations of these classics are planned to be implemented: **Simon says**, **Breakout/Arkanoid**

## Other things to do

 - Additional PCB for battery powering/charging
 - Plastic 3d-printed case

