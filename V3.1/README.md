# rpi_hal
Free Pascal Hardware abstraction library for the Raspberry Pi
This Unit, with more than 3000 Lines of Code, delivers procedures and functions to access the rpi HW I2C, SPI and GPIO:

Just an excerpt of the available functions and procedures:

procedure gpio_set_pin (pin:longword;highlevel:boolean); { Set RPi GPIO pin to high or low level }
function gpio_get_PIN (pin:longword):boolean; { Get RPi GPIO pin Level is true when Pin level is '1'; false when '0'}
procedure gpio_set_input (pin:longword); { Set RPi GPIO pin to input direction }
procedure gpio_set_output(pin:longword); { Set RPi GPIO pin to output direction }
procedure gpio_set_alt (pin,altfunc:longword); { Set RPi GPIO pin to alternate function nr. 0..5 }
procedure gpio_set_gppud (mask:longword); { set RPi GPIO Pull-up/down Register (GPPUD) with mask }
...
function rpi_snr :string; { delivers SNR: 0000000012345678 }
function rpi_hw  :string; { delivers Processor Type: BCM2708 or BCM2709 }
...
function i2c_bus_write(baseadr,reg:word; var data:databuf_t; lgt:byte; testnr:integer) : integer;
function i2c_bus_read (baseadr,reg:word; var data:databuf_t; lgt:byte; testnr:integer) : integer;
function i2c_string_read(baseadr,reg:word; var data:databuf_t; lgt:byte; testnr:integer) : string;
function i2c_string_write(baseadr,reg:word; s:string; testnr:integer) : integer;
...
procedure SPI_Write(devnum:byte; reg,data:word);
function SPI_Read(devnum:byte; reg:word) : byte;
procedure SPI_BurstRead2Buffer (devnum,start_reg:byte; xferlen:longword);
procedure SPI_BurstWriteBuffer (devnum,start_reg:byte; xferlen:longword); { Write 'len' Bytes from Buffer SPI Dev startig at address 'reg' } 
