# rpi_hal
Free Pascal Hardware abstraction library for the Raspberry Pi
This Unit, with more than 7500 Lines of Code, 
delivers procedures and functions to access the rpi HW

- I2C
- SPI
- GPIO (input, output, SW-PWM, HW-PWM, timer, frequency output)
- Bitbang functions for Powerswitches (ELRO, Intertechno, Sartano, Nexa)
- Morse functions
- Rotational Encoders implemented with Threads (e.g. Keyes KY-040 Rotary Encoder)
- Servo functions
- PID Algorithmus
- functions to access PiFace Board
- Bidirectional serial device access in User space /dev/yourdevice 
- USB Reset and Access
- Maintain INI-Files for parameter management
- RPI HAT access
- Thread Management
- Timing functions (e.g. SetTimeOut, TimeElapsed)
- StringManipulation (e.g. Select_Item for handling .csv files)
- call external OS program and receive answer with multiple lines (e.g. directory list)
- extensive Logging functions
- CURL wrapper 
- SW Maintenance-/Service-functions:
  Upload Logfiles to FTP-Server
  Download new SW from FTP-Server
  Install new SW on rpi
- many examples, how to use the rpi_hal 
  
!! Since V4.5 new startup strategy, rpi_hal will not bring up HW automatically. 
!! pls. start rpi_hal with e.g. RPI_HW_Start for all components in your main program, 
!! or use explicit start procedures: GPIO_Start, I2C_Start, SPI_Start

Discussion forum:
http://forum.lazarus.freepascal.org/index.php/topic,20991.60.html

Just an excerpt of the available functions and procedures:

GPIO Functions:
- procedure gpio_set_pin (pin:longword;highlevel:boolean); // Set RPi GPIO pin to high or low level
- function  gpio_get_PIN (pin:longword):boolean; // Get RPi GPIO pin Level is true when Pin level is '1'; false when '0'
- procedure gpio_set_input (pin:longword); // Set RPi GPIO pin to input direction
- procedure gpio_set_output(pin:longword); // Set RPi GPIO pin to output direction
- procedure gpio_set_alt (pin,altfunc:longword); // Set RPi GPIO pin to alternate function nr. 0..5
- procedure gpio_set_gppud (mask:longword); // set RPi GPIO Pull-up/down Register (GPPUD) with mask

- function rpi_snr:string; // delivers SNR: 0000000012345678
- function rpi_hw:string;  // delivers Processor Type: BCM2708 or BCM2709

I2C Functions:
- function i2c_bus_write(baseadr,reg:word; var data:databuf_t; lgt:byte; testnr:integer) : integer;
- function i2c_bus_read (baseadr,reg:word; var data:databuf_t; lgt:byte; testnr:integer) : integer;
- function i2c_string_read(baseadr,reg:word; var data:databuf_t; lgt:byte; testnr:integer) : string;
- function i2c_string_write(baseadr,reg:word; s:string; testnr:integer) : integer;

SPI Functions:
- procedure SPI_Write(devnum:byte; reg,data:word);
- function  SPI_Read(devnum:byte; reg:word) : byte;
- procedure SPI_BurstRead2Buffer (devnum,start_reg:byte; xferlen:longword);
- procedure SPI_BurstWriteBuffer (devnum,start_reg:byte; xferlen:longword); // Write 'len' Bytes from Buffer SPI Dev startig at address 'reg' 
