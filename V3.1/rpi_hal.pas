unit rpi_hal; { V3.1 }
{$MODE OBJFPC}
{ rpi_hal:
* Free Pascal Hardware abstraction library for the Raspberry Pi
* Copyright (c) 2012-2014 Stefan Fischer
***********************************************************************
*
* rpi_hal is free software: you can redistribute it and/or modify
* it under the terms of the GNU Lesser General Public License as 
* published by the Free Software Foundation, either version 3 
* of the License, or (at your option) any later version.
*
* rpi_hal is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
* GNU Lesser General Public License for more details.
*
* You should have received a copy of the GNU Lesser General Public License
* along with rpi_hal. If not, see <http://www.gnu.org/licenses/>.
*
*********************************************************************** 
//Info:  http://wiki.freepascal.org/Lazarus_on_Raspberry_Pi
//pls. report bugs and discuss code enhancements here:
//Forum: http://www.lazarus.freepascal.org/index.php/topic,20991.0.html 
//Simple Test program, which is using rpi_hal. compile it on rpi with '#fpc testrpi.pas' and run it '#./testrpi'
//Tested on Raspbian Wheezy. Distro was occidentalis.
//#uname -a
//#Linux raspberrypi 3.6.11+ #399 PREEMPT Sun Mar 24 19:22:58 GMT 2013 armv6l GNU/Linux
  program testrpi;
  uses rpi_hal;
  const piggyback=1; piface=2; board_installed=piggyback;
  begin
    writeln('Show CPU-Info, RPI-HW-Info and Registers:');
    rpi_show_all_info;
	writeln('Let Status LED Blink. Using GPIO functions:');
	GPIO_PIN_TOGGLE_TEST;
	case board_installed of
	  piggyback : begin
                    writeln('Test SPI Read function. (piggy back board with installed RFM22B Module is required!)');
                    Test_SPI;
				  end;
	  piface :    begin
                    writeln('Test SPI function. (PiFace board needs to be installed)');
					pfio_init(0);
                    pfio_test(0);
				  end;
	end;
  end.
}

  { $F+} { $A+}
  { $R-} { $S-}
  { $G-} 
  {$H+}  (* NO Ansistrings *)
  {$packrecords C} 

Interface 
uses {$IFDEF UNIX}    cthreads,cmem,BaseUnix,Unix,unixutil, {$ENDIF} 
     {$IFDEF WINDOWS} windows, {$ENDIF} 
	 typinfo,sysutils,dateutils,Classes,Process;
  
const
  AN=true; AUS=false;
  CR=#$0d; LF=#$0a;
  pfio_devnum_default  = 1; // SPI Devicenumber for PiFace Board1 (Default)
  rpi_status_led_GPIO  =16; // GPIO16 -> Status LED on RPi PCB  }
  gpio_path_c='/sys/class/gpio';
  gpio_INPUT=0;
  gpio_OUTPUT=1;
  gpio_ALT=2;
  gpio_PWM_OUTPUT=3;
// Maps  Pin-Nr on HW Header P1 to GPIO-Nr
  gpiomax_map_idx_c=3;
  gpiomax_c = 40;
  gpio_hdr_map_c   : array[1..gpiomax_map_idx_c] of array[1..gpiomax_c] of integer = //      -> !! <- Delta rev1 and rev2 
  ( { HW-PIN           1     2     3     4     5     6     7      8     9     10    11    12    13    14    15    16    17    18    19    20    21    22    23    24    25    26    27    28    29    30    31    32    33    34    35    36    37    38    39    40 }
    { Desc          3.3V    5V   I2C    5V   I2C   GND  1Wire   TxD   GND    RxD    11    12    13    14    15    16  3.3V    18   SPI   GND   SPI    22   SPI   SPI   GND   SPI  ID_SD ID_SC   29   GND    31    32    33   GND    35    36    37    38   GND    40 }
    { rev1 GPIO } ( (-99),(-99),(-99),(-99),( -1),(-99),(  4),( -14),(-99),( -15),( 17),( 18),( 21),(-99),( 22),( 23),(-99),( 24),(-10),(-99),( -9),( 25),(-11),( -8),(-99),( -7),(-99),(-99),(  5),(-99),(  6),( 12),( 13),(-99),( 19),( 16),( 26),( 20),(-99),( 21) ),
    { rev2 GPIO } ( (-99),(-99),( -2),(-99),( -3),(-99),(  4),( -14),(-99),( -15),( 17),( 18),( 27),(-99),( 22),( 23),(-99),( 24),(-10),(-99),( -9),( 25),(-11),( -8),(-99),( -7),(-99),(-99),(  5),(-99),(  6),( 12),( 13),(-99),( 19),( 16),( 26),( 20),(-99),( 21) ),
	{ B+ GPIO   } ( (-99),(-99),( -2),(-99),( -3),(-99),(  4),( -14),(-99),( -15),( 17),( 18),( 27),(-99),( 22),( 23),(-99),( 24),(-10),(-99),( -9),( 25),(-11),( -8),(-99),( -7),(-99),(-99),(  5),(-99),(  6),( 12),( 13),(-99),( 19),( 16),( 26),( 20),(-99),( 21) )
  );
  
  { Pin-Nr on HW Header P1; definitions for piggy-back board }
  Int_Pin_on_RPI_Header=15; // =GPIO22 -> PIN Number on rpi HW Header P1  ref: http://elinux.org/RPi_Low-level_peripherals
  Ena_Pin_on_RPI_Header=22; // =GPIO25 -> RFM22_SD
  OOK_Pin_on_RPI_Header=11; // =GPIO17 -> RFM22_OOK
  IO1_Pin_on_RPI_Header=13; // =GPIO21/GPIO27 -> TLP434A OOK
  ITX_Pin_on_RPI_Header=12; // =GPIO18 -> IR TX
  IRX_Pin_on_RPI_Header=16; // =GPIO23 -> IR RX
  W1__Pin_on_RPI_Header=07; // =GPIO4  -> 1Wire BitBang
  Int_SPI_01_RPI_Header=18; // =GPIO24 -> Int Pin SPI1 on JP1 Pin5

 { Physical addresses range from 0x20000000 to 0x20FFFFFF for peripherals. 
    The bus addresses for peripherals are set up to map onto the peripheral 
	bus address range starting at 0x7E000000. 
	Thus a peripheral advertised here at bus address 0x7Ennnnnn is available 
	at physical address 0x20nnnnnn. }
	
  PAGE_SIZE			= 4096;	
  BCM2708_PBASE_pag	= $20000; { Peripheral Base in pages }
  
  TIMR_BASE_in_pages= (BCM2708_PBASE_pag + $00B);
  PADS_BASE_in_pages= (BCM2708_PBASE_pag + $100); 
  CLK_BASE_in_pages = (BCM2708_PBASE_pag + $101); // Docu Page 107ff
  GPIO_BASE_in_pages= (BCM2708_PBASE_pag + $200); // Docu Page  90ff GPIO controller page start (1 page = 4096 Bytes 
  PWM_BASE_in_pages = (BCM2708_PBASE_pag + $20c); // Docu Page 138ff
    
//0x 7E20 0000
//Indexes		(each addresses 4 Bytes)  
  GPIO_BASE			= 0;
  GPFSEL			= GPIO_BASE+$00;
  GPSET				= GPIO_BASE+$07; { Register Index: set   bits which are 1 ignores bits which are 0 } 
  GPCLR				= GPIO_BASE+$0a; { Register Index: clear bits which are 1 ignores bits which are 0 } 
  GPLEV				= GPIO_BASE+$0d;
  GPEDS				= GPIO_BASE+$10; { Pin Event Detection }
  GPREN				= GPIO_BASE+$13; { Pin RisingEdge  Detection }
  GPFEN				= GPIO_BASE+$16; { Pin FallingEdge Detection }
  GPHEN				= GPIO_BASE+$19; { Pin High Detection }
  GPLEN				= GPIO_BASE+$1c; { Pin Low  Detection }
  GPAREN			= GPIO_BASE+$1f; { Pin Async. RisigngEdge  Detection }
  GPAFEN			= GPIO_BASE+$22; { Pin Async. FallingEdge Detection }
  GPPUD				= GPIO_BASE+$25; { Pin Pull-up/down Enable }
  GPPUDCLK			= GPIO_BASE+$26; { Pin Pull-up/down Enable Clock }
  GPIO_BASE_LAST	= GPPUDCLK;

  PWM_BASE			= 0;
  PWMCTL 			= PWM_BASE+$00;	//  0
  PWMSTA	  		= PWM_BASE+$01; //  4
  PWMDMAC	  		= PWM_BASE+$02; //  8
  PWMRNG1 	 		= PWM_BASE+$04; // 16
  PWMDAT1   		= PWM_BASE+$05; // 20
  PWMFIF1   		= PWM_BASE+$06; // 24
  PWMRNG2	  		= PWM_BASE+$08; // 32
  PWMDAT2   		= PWM_BASE+$09; // 36
  PWM_BASE_LAST		= PWMDAT2;
 
  GMGPxCTL_BASE		= 0; 				// Manual Page 107ff
  GMGP0CTL			= GMGPxCTL_BASE+$1c;// 0x2010 1070
  GMGP0DIV			= GMGPxCTL_BASE+$1d;// 0x2010 1074
  GMGP1CTL			= GMGPxCTL_BASE+$1e;// 0x2010 1078
  GMGP1DIV			= GMGPxCTL_BASE+$1f;// 0x2010 107c
  GMGP2CTL			= GMGPxCTL_BASE+$20;// 0x2010 1080
  GMGP2DIV			= GMGPxCTL_BASE+$21;// 0x2010 1084

  PWMCLK_BASE		= 0;				// Manual Page 107ff
  PWMCLK_CNTL 		= PWMCLK_BASE+$28; //160 0xA0
  PWMCLK_DIV  		= PWMCLK_BASE+$29; //164 0xA4
  PWMCLK_BASE_LAST	= PWMCLK_DIV;
  
  PWM1_MS_MODE    	= $8000;  // Run in MS mode
  PWM1_USEFIFO    	= $2000; // Data from FIFO
  PWM1_REVPOLAR   	= $1000;  // Reverse polarity
  PWM1_OFFSTATE   	= $0800;  // Ouput Off state
  PWM1_REPEATFF   	= $0400;  // Repeat last value if FIFO empty
  PWM1_SERIAL     	= $0200;  // Run in serial mode
  PWM1_ENABLE     	= $0100;  // Channel Enable
 
  PWM0_MS_MODE    	= $0080;  // Run in MS mode
  PWM0_USEFIFO    	= $0020;  // Data from FIFO
  PWM0_REVPOLAR   	= $0010;  // Reverse polarity
  PWM0_OFFSTATE   	= $0008;  // Ouput Off state
  PWM0_REPEATFF   	= $0004;  // Repeat last value if FIFO empty
  PWM0_SERIAL     	= $0002;  // Run in serial mode
  PWM0_ENABLE     	= $0001;  // Channel Enable
  
  BCM_PWD			= $5A000000;
 
//  LOG_All =1; LOG_DEBUG = 2; LOG_INFO =  10; Log_NOTICE = 20; Log_WARNING = 50; Log_ERROR = 100; Log_URGENT = 250; LOG_NONE = 254;   

  { source: http://i2c-tools.sourcearchive.com/documentation/3.0.3-5/i2c-dev_8h_source.html }
  i2c_max_bus        = 1;
  i2c_max_buffer     = 32;
  I2C_M_TEN          = $0010;  { we have a ten bit chip address }
  I2C_M_RD           = $0001;
  I2C_M_NOSTART      = $4000;
  I2C_M_REV_DIR_ADDR = $2000;
  I2C_M_IGNORE_NAK   = $1000;
  I2C_M_NO_RD_ACK    = $0800;
  
  I2C_RETRIES        = $0701;  { number of times a device address should be polled when not acknowledging       }
  I2C_TIMEOUT        = $0702;  { set timeout - call with int            }
  I2C_SLAVE          = $0703;  { Change slave address                   }
                               { Attn.: Slave address is 7 or 10 bits   }
  I2C_SLAVE_FORCE    = $0706;  { Change slave address                   
                                 Attn.: Slave address is 7 or 10 bits   
                                 This changes the address, even if it 
                                 is already taken!                      }
  I2C_TENBIT         = $0704;  { 0 for 7 bit addrs, != 0 for 10 bit     }

  I2C_FUNCS          = $0705;  { Get the adapter functionality          }
  I2C_RDWR           = $0707;  { Combined R/W transfer (one stop only)  }
  I2C_PEC            = $0708;  { != 0 for SMBus PEC                     }
  I2C_SMBUS          = $0720;  { SMBus-level access                     }
    
  I2C_CTRL_REG		 =  0; { Register Indexes } 
  I2C_STATUS_REG	 =  1;
  I2C_DLEN_REG		 =  2;
  I2C_A_REG			 =  3;
  I2C_FIFO_REG		 =  4;
  I2C_DIV_REG		 =  5;
  I2C_DEL_REG		 =  6;
  I2C_CLKT_REG		 =  7;
  
  { To determine what functionality is present }
  I2C_FUNC_I2C                    = $00000001;
  I2C_FUNC_10BIT_ADDR             = $00000002;
  I2C_FUNC_PROTOCOL_MANGLING      = $00000004; { I2C_M_[REV_DIR_ADDR,NOSTART,..] }
  I2C_FUNC_SMBUS_PEC              = $00000008;
  I2C_FUNC_SMBUS_BLOCK_PROC_CALL  = $00008000; { SMBus 2.0 }
  I2C_FUNC_SMBUS_QUICK            = $00010000; 
  I2C_FUNC_SMBUS_READ_BYTE        = $00020000; 
  I2C_FUNC_SMBUS_WRITE_BYTE       = $00040000; 
  I2C_FUNC_SMBUS_READ_BYTE_DATA   = $00080000; 
  I2C_FUNC_SMBUS_WRITE_BYTE_DATA  = $00100000; 
  I2C_FUNC_SMBUS_READ_WORD_DATA   = $00200000; 
  I2C_FUNC_SMBUS_WRITE_WORD_DATA  = $00400000; 
  I2C_FUNC_SMBUS_PROC_CALL        = $00800000; 
  I2C_FUNC_SMBUS_READ_BLOCK_DATA  = $01000000; 
  I2C_FUNC_SMBUS_WRITE_BLOCK_DATA = $02000000; 
  I2C_FUNC_SMBUS_READ_I2C_BLOCK   = $04000000; { I2C-like block xfer  }
  I2C_FUNC_SMBUS_WRITE_I2C_BLOCK  = $08000000; { w/ 1-byte reg. addr. } 
  I2C_FUNC_SMBUS_BYTE             = I2C_FUNC_SMBUS_READ_BYTE       or I2C_FUNC_SMBUS_WRITE_BYTE;
  I2C_FUNC_SMBUS_BYTE_DATA        = I2C_FUNC_SMBUS_READ_BYTE_DATA  or I2C_FUNC_SMBUS_WRITE_BYTE_DATA;
  I2C_FUNC_SMBUS_WORD_DATA        = I2C_FUNC_SMBUS_READ_WORD_DATA  or I2C_FUNC_SMBUS_WRITE_WORD_DATA;
  I2C_FUNC_SMBUS_BLOCK_DATA       = I2C_FUNC_SMBUS_READ_BLOCK_DATA or I2C_FUNC_SMBUS_WRITE_BLOCK_DATA;
  I2C_FUNC_SMBUS_I2C_BLOCK        = I2C_FUNC_SMBUS_READ_I2C_BLOCK  or I2C_FUNC_SMBUS_WRITE_I2C_BLOCK;   
    
  SPI_IOC_MAGIC     = 'k';
  SPI_CPHA			= $01;
  SPI_CPOL			= $02;
  SPI_MODE_0		= $00;
  SPI_MODE_1		= SPI_CPHA;
  SPI_MODE_2		= SPI_CPOL;
  SPI_MODE_3		= SPI_CPOL or SPI_CPHA;
  
  spi_max_bus    	= 1;
  spi_max_dev	 	= 1; 
  SPI_BUF_SIZE_c 	= 64;
  
  _IOC_NONE   	 	=$00; _IOC_WRITE 	 =$01; _IOC_READ	  =$02;
  _IOC_NRBITS    	=  8; _IOC_TYPEBITS  =  8; _IOC_SIZEBITS  = 14; _IOC_DIRBITS  =  2;
  _IOC_NRSHIFT   	=  0; 
  _IOC_TYPESHIFT 	= (_IOC_NRSHIFT+  _IOC_NRBITS); 
  _IOC_SIZESHIFT 	= (_IOC_TYPESHIFT+_IOC_TYPEBITS);
  _IOC_DIRSHIFT  	= (_IOC_SIZESHIFT+_IOC_SIZEBITS);
  
  c_max_Buffer   	= 128;  { was 024  }
  
  rpi_i2c_general_purpose_bus_c=1;
  
  NO_TEST        	= 0;
  
  RTC_RD_TIME 		= -2145095671;
  RTC_SET_TIME 		= 1076129802;
  
  // Port configuration for PIFace Board
  pfio_IODIRA=$00; 	// I/O direction A
  pfio_IODIRB=$01; 	// I/O direction B
  pfio_IOCON=$0A; 	// I/O config
  pfio_GPIOA=$12; 	// port A
  pfio_GPIOB=$13; 	// port B
  pfio_GPPUA=$0C; 	// port A pullups
  pfio_GPPUB=$0D; 	// port B pullups
  pfio_OUTPUT_PORT=pfio_GPIOA;
  pfio_INPUT_PORT= pfio_GPIOB;
  
//consts for PseudoTerminal IO (/dev/ptmx)
  Terminal_MaxBuf = 1024; 
  NCCS 		=32;
  
  TCSANOW 	=0; 			{ make change immediate }
  TCSADRAIN =1; 			{ drain output, then change }
  TCSAFLUSH =2; 			{ drain output, flush input }
  TCSASOFT 	=$10; 			{ flag - don't alter h.w. state }
  
  ECHOKE 	= $1; 			{ visual erase for line kill }
  ECHOE 	= $2; 			{ visually erase chars }
  ECHOK 	= $4; 			{ echo NL after line kill }
  ECHO 		= $8; 			{ enable echoing }
  ECHONL 	= $10; 			{ echo NL even if ECHO is off }
  ECHOPRT 	= $20; 			{ visual erase mode for hardcopy }
  ECHOCTL 	= $40; 			{ echo control chars as ^(Char) }
  ISIG 		= $80; 			{ enable signals INTR, QUIT, [D]SUSP }
  ICANON 	= $100; 		{ canonicalize input lines }
  ALTWERASE = $200; 		{ use alternate WERASE algorithm }
  IEXTEN 	= $400; 		{ enable DISCARD and LNEXT }
  EXTPROC 	= $800; 		{ external processing }
  TOSTOP 	= $400000; 		{ stop background jobs from output }
  FLUSHO 	= $800000; 		{ output being flushed (state) }
  NOKERNINFO= $2000000; 	{ no kernel output from VSTATUS }
  PENDIN 	= $20000000; 	{ XXX retype pending input (state) }
  NOFLSH 	= $80000000;	{ don't flush after interrupt }
  
type
  T_ErrorLevel=(LOG_All,LOG_DEBUG,LOG_INFO,Log_NOTICE,Log_WARNING,Log_ERROR,Log_URGENT,LOG_NONE); 
  T_PowerSwitch		= (ELRO,Sartano,Nexa,Intertechno,FS20);
  t_MemoryMapPtr = ^t_MemoryMap;
  t_MemoryMap=array[0..(PAGE_SIZE div SizeOf(Longword))-1] of Longword; { for 32 Bit access }  
      
  buftype = array[0..c_max_Buffer-1] of byte;
  
  cint = longint;
  cuint= longword;
	
  databuf_t = record
    lgt : longword;
    hdl : cint;
    busnum : integer;
    reg : byte;
    buf : array[0..c_max_Buffer-1] of byte;
  end;  

  rtc_time_t = record
    tm_sec,tm_min,tm_hour,tm_mday,tm_mon,tm_year,tm_wday,tm_yday,tm_isdst : longint;
  end;
    
  TProcedureOneArgCall = procedure(i:integer);
  TFunctionOneArgCall  = function (i:integer):integer;
  
  isr_t = record
    devnum					: byte;
    enter_isr_routine,
	gpio,fd 				: longint;
	func_ptr 				: TFunctionOneArgCall;
	ThreadId				: TThreadID;
	ThreadPrio,
	flag,
	rslt 					: integer;
	rising_edge,
    int_enable 				: boolean; { if INT occures, INT Routine will be started or not }
	int_cnt,
    int_cnt_raw				: longword;
	enter_isr_time			: TDateTime;
	last_isr_servicetime	: int64;
  end;
  
   spi_databuf_t = record
    reg			: byte;
    buf			: array[0..SPI_BUF_SIZE_c-1] of byte;
	posidx,
	endidx		: longint;
  end;
  
  spi_ioc_transfer_t = record  (* sizeof(spi_ioc_transfer_t) = 32 *)
    tx_buf_ptr		: qword;
    rx_buf_ptr		: qword;
    len				: longword;
	speed_hz    	: longword;
    delay_usecs		: word;
    bits_per_word	: byte;
    cs_change		: byte;
    pad				: longword;
  end;
  
  SPI_Bus_Info_t = record
    spi_busnum		: integer;
    spi_path 		: string[20];
	spi_fd   		: cint;
	spi_opened 		: boolean;
  end;
 	
  SPI_Device_Info_t = record
	spi_busnum		: integer;
	spi_LSB_FIRST	: byte;     { Zero indicates MSB-first; other values indicate the less common LSB-first encoding.  }
	spi_bpw  		: byte; 	{ bits per word }
	spi_delay 		: word; 	{ delay usec }
	spi_speed 		: longword;	{ spi speed in Hz }
	spi_mode  		: byte;     { 0..3 }
	spi_IOC_mode	: longword; {  }
	dev_gpio_ook,
	dev_gpio_en 	: integer;
	isr_enable		: boolean;  { decides, establish and prepare INT-Environment. If false, then polling }
	isr				: isr_t;
  end;  
  
  tcflag_t = cuint;
  cc_t = cchar;
  speed_t = cuint;
  size_t = cuint;
  ssize_t = cint;
   
  Ptermios = ^termios;
  termios = record
     c_iflag : tcflag_t;
     c_oflag : tcflag_t;
     c_cflag : tcflag_t;
     c_lflag : tcflag_t;
     c_line : cc_t;
     c_cc : array[0..(NCCS)-1] of cc_t;
     c_ispeed : speed_t;
     c_ospeed : speed_t;
  end;
   
  Terminal_device_t = record
	fdmaster,fdslave,ridx,rlgt:longint; 
	masterpath,slavepath,linkpath:string;   
	si : array [1..Terminal_MaxBuf] of char; 
  end;
  
  Konv_small = record
	case typus : byte of
	     $00 : (w:word);
		 $01 : (blsb,bmsb:byte);
		 $02 : (i:integer);
		 $03 : (a:array[0..1] of byte)
  end; { Konv_small }  
	 
  Konv = record { for typeconversion. longint <-> word <-> bytes }
    case typus : char of
         'p' : (pt : pointer);
	{  	 'P' : (pc : Pchar); }
         'l' : (l  : longint);
         'L' : (lw : longword);
         's' : (s  : single);
		 'i' : (ilsb,imsb : integer);
         'w' : (wlsb,wmsb : word);
         'b' : (blsblsb,blsbmsb,bmsblsb,bmsbmsb : byte);
		 'a' : (a: array[0..3] of byte)
   end; {  Konv  }
  	       
var 
  testnr,mem_fd : integer; _TZLocal:longint; _TZOffsetString:string[10];
  mmap_arr_gpio,mmap_arr_pwm,mmap_arr_clk : t_MemoryMapPtr; 

  i2c_buf   : array[0..i2c_max_bus] of databuf_t; 
  
  SPI_IOC_RD_MODE,SPI_IOC_WR_MODE,SPI_IOC_RD_LSB_FIRST,SPI_IOC_WR_LSB_FIRST,
  SPI_IOC_RD_BITS_PER_WORD,SPI_IOC_WR_BITS_PER_WORD,SPI_IOC_RD_MAX_SPEED_HZ,SPI_IOC_WR_MAX_SPEED_HZ : longword;
  spi_bus 	: array[0..spi_max_bus]	of SPI_Bus_Info_t;
  spi_dev 	: array[1..spi_max_dev] of SPI_Device_Info_t;
  spi_buf 	: array[1..spi_max_dev] of spi_databuf_t; 
  
  HighPrecisionMillisecondFactor : Int64 = 1000; HighPrecisionTimerInit : Boolean = False;
 
{$IFDEF UNIX} procedure gpio_int_test; {$ENDIF}	{ only for test }  
procedure GPIO_PIN_TOGGLE_TEST;                 { just for demo reasons, call it from your own program. Be careful, it toggles GPIO pin 16 -> StatusLED }
procedure Test_SPI; 	
procedure i2c_test; 
	 
function  RPI_Piggyback_board_available  : boolean;  
function  RPI_PiFace_board_available(devadr:byte) : boolean;  
function  rpi_run_on_known_hw:boolean;  
function  rpi_platform_ok:boolean;   			
function  rpi_mmap_run_on_unix:boolean;  
function  rpi_run_on_ARM:boolean; 
function  rpi_mmap_get_info (modus:longint)  : longword;
procedure rpi_show_all_info;

function  gpio_MAP_GPIO_NUM_2_HDR_PIN(pin:longword; mapidx:byte):longint; { Maps GPIO Number to the HDR_PIN }
function  gpio_MAP_GPIO_NUM_2_HDR_PIN(pin:longword):longint;
function  gpio_MAP_HDR_PIN_2_GPIO_NUM(hdr_pin_number:longword; mapidx:byte):longint; { Maps HDR_PIN to the GPIO Number }
function  gpio_MAP_HDR_PIN_2_GPIO_NUM(hdr_pin_number:longword):longint;

procedure gpio_set_HDR_PIN(hw_pin_number:longword;highlevel:boolean); { Maps PIN to the GPIO Header }
function  gpio_get_HDR_PIN(hw_pin_number:longword):boolean; { Maps PIN to the GPIO Header }

procedure gpio_set_pin   (pin:longword;highlevel:boolean); { Set RPi GPIO pin to high or low level; Speed @ 700MHz ->  0.65MHz }
function  gpio_get_PIN   (pin:longword):boolean; { Get RPi GPIO pin Level is true when Pin level is '1'; false when '0'; Speed @ 700MHz ->  1.17MHz }  
function  gpio_get_PIN	 (pin,idx,mask:longword):boolean;

procedure Toggle_Pin16_very_fast;
procedure Toggle_Pin23_very_fast;

procedure LED_Status     (ein:boolean); 		 { Switch Status-LED on or off }

procedure gpio_set_input (pin:longword);         { Set RPi GPIO pin to input  direction }
procedure gpio_set_output(pin:longword);         { Set RPi GPIO pin to output direction }
procedure gpio_set_alt   (pin,altfunc:longword); { Set RPi GPIO pin to alternate function nr. 0..5 }
procedure gpio_set_PINMODE(pin,mode:longword);
procedure gpio_set_gppud (mask:longword);        { set RPi GPIO Pull-up/down Register (GPPUD) with mask }
procedure gpio_get_mask_and_idx(pin:longword; var idx,mask:longword);
procedure gpio_set_PULLUP (pin:longword; enable:boolean); 
procedure gpio_set_edge_rising (pin:longword; enable:boolean); { Pin RisingEdge  Detection Register (GPREN) }
procedure gpio_set_edge_falling(pin:longword; enable:boolean); { Pin FallingEdge Detection Register (GPFEN) }
{$IFDEF UNIX} 
function  gpio_set_int    (var isr:isr_t; gpio_num:longint; isr_proc:TFunctionOneArgCall; rising_edge:boolean) : integer; // set up isr routine, gpio_number, int_routine which have to be executed, rising or falling_edge
function  gpio_int_release(var isr:isr_t) : integer;
procedure gpio_int_enable (var isr:isr_t); 
procedure gpio_int_disable(var isr:isr_t); 
function  gpio_int_active (var isr:isr_t):boolean;
{$ENDIF}
procedure gpio_show_regs;
procedure pwm_show_regs;
function  gpio_get_desc(regidx,regcontent:longword) : string;  
  
function  rpi_snr :string; { delivers: 0000000012345678 }
function  rpi_hw  :string; { delivers: BCM2708 }
function  rpi_proc:string; { ARMv6-compatible processor rev 7 (v6l) }
function  rpi_mips:string; { 697.95 }
function  rpi_feat:string; { swp half thumb fastmult vfp edsp java tls }
function  rpi_rev :string; { rev1;256MB;1000002 }
function  rpi_freq :string;{ 700000;700000;900000;Hz }
function  rpi_revnum:byte; { 1:rev1; 2:rev2; 0:error }
function  rpi_gpiomapidx:byte; { 1:rev1; 2:rev2; 3:B+; 0:error }
function  rpi_i2c_busnum(func:byte):byte; { get the i2c busnumber, where e.g. the geneneral purpose devices are connected. This depends on rev1 or rev2 board . e.g. rpi_i2c_busnum(rpi_i2c_general_purpose_bus_c) }

procedure rpi_show_cpu_info;
  
procedure rpi_set_testnr  (testnumber:integer); 

function  rtc_func(fkt:longint; fpath:string; var dattime:TDateTime) : longint;

procedure i2c_CleanBuffer(busnumber:byte);
function  i2c_bus_write(baseadr,reg:word; var data:databuf_t; lgt:byte; testnr:integer) : integer;
function  i2c_bus_read (baseadr,reg:word; var data:databuf_t; lgt:byte; testnr:integer) : integer;
function  i2c_string_read(baseadr,reg:word; lgt:byte; testnr:integer) : string;   // read from the i2c general purpose bus e.g. s:=i2c_string_read ($68,$00,7,NO_TEST)
function  i2c_string_write(baseadr,reg:word; s:string; testnr:integer) : integer; // write to the  i2c general purpose bus e.g.    i2c_string_write($68,$00,#$01+#$02+#$03)
//procedure Show_Buffer(var data:databuf_t);
procedure show_i2c_struct(var data:databuf_t);
procedure Display_i2c_struct(var data:databuf_t; comment:string);

procedure SPI_Write(devnum:byte; reg,data:word);
function  SPI_Read(devnum:byte; reg:word) : byte;
procedure SPI_BurstRead2Buffer (devnum,start_reg:byte; xferlen:longword);
procedure SPI_BurstWriteBuffer (devnum,start_reg:byte; xferlen:longword);  { Write 'len' Bytes from Buffer SPI Dev startig at address 'reg'  }
procedure SPI_StartBurst(devnum:byte; reg:word; writeing:byte; len:longint);
procedure SPI_EndBurst(devnum:byte);
procedure SPI_SetMode(devnum:byte);
function  SPI_BurstRead(devnum:byte) : byte;
procedure show_spi_struct(var spi_strct:spi_ioc_transfer_t);
procedure show_spi_dev_info_struct(var spi_dev_info_strct:SPI_Device_Info_t; devnum:byte);
procedure show_spi_buffer(var spi_buff:spi_databuf_t);
procedure show_spi_bus_info_struct(var spi_bus_info_strct:SPI_Bus_Info_t; busnum:byte);

procedure pfio_init  (devadr:byte);						// 'devadr' [0..3] MCP23S17SP Address determined by A2 A1 A0 Pins.					
procedure pfio_RELAY (devadr, num:byte; state:boolean);	// set Relay 		'devadr' [0..3]		'num' 		[1..2]	ON or OFF e.g. pfio_RELAY(2, AN); 
procedure pfio_OUTPUT(devadr, num:byte; state:boolean);	// set LED   		'devadr' [0..3]		'num' 		[1..4]	ON or OFF
function  pfio_ISTAT (devadr, bitnum:byte):boolean;		// Is Input State	'devadr' [0..3]		'bitnum' 	[1..8]	ON or OFF
function  pfio_OSTAT (devadr, bitnum:byte):boolean;		// Is Output State	'devadr' [0..3]		'bitnum'	[1..8]  ON or OFF // Whats the current state of Output pin, without setting it  
function  pfio_digital_read (devadr, pin_number:byte):boolean;
procedure pfio_digital_write(devadr, pin_number:byte; value:byte);
function  pfio_read_input (devadr:byte):byte;
function  pfio_read_output(devadr:byte):byte;
procedure pfio_write_output(devadr, value:byte);
function  pfio_get_pin_bit_mask(pin_number:byte):byte;
function  pfio_get_pin_number  (bit_pattern:byte):byte; 
procedure pfio_test(devadr:byte);

procedure BB_OOK_PIN(state:boolean);
procedure BB_SetPin(pinnr:longint); 
function  BB_GetPin:longint; 
procedure BB_SendCode(switch_type:T_PowerSwitch; adr,id,desc:string; ein:boolean);
procedure BB_InitPin(id:string); // e.g. id:'TLP434A' or id:'13'  (direct RPI Pin on HW Header P1 )
procedure morse_speed(speed:integer); // 1..5, -1=default_speed
procedure morse_tx(s:string);
procedure morse_test;
procedure ELRO_TEST;

procedure delay_nanos(Nanoseconds:longword);
procedure delay_us   (Microseconds:Int64);	
procedure delay_msec (Milliseconds:longword);  
procedure Log_Write  (typ:T_ErrorLevel;msg:string); 
procedure Log_Writeln(typ:T_ErrorLevel;msg:string); 
function  LOG_Get_Level : T_ErrorLevel; 
procedure LOG_Save_Level;   
procedure Log_Set_Level(level:T_ErrorLevel); 
procedure LOG_Restore_Level; 

function  ReadBits (in_byte,bitStart,lgt:byte):byte;  { bitnum 8..1 }
function  WriteBits(in_byte,bitStart,lgt,inplant:byte) : byte; { bitnum 8..1 }
function  BitSet(q:qword;nr:byte) : Boolean; {.c checks if Bit 'nr' is set. (nr: 1 to 64) }
function  Bool2Str(b:boolean) : string; 
function  Num2Str(num : byte;    lgt:byte) : String;
function  Num2Str(num : word;    lgt:byte) : String; 
//function  Num2Str(num : integer; lgt:byte) : String; // OBJFPC
function  Num2Str(num : longint; lgt:byte) : String; 
function  Num2Str(num : longword;lgt:byte) : String; 
function  Num2Str(num : int64;   lgt:byte) : String; 
function  Real2Str(r:single;lgt,nk:byte) : string; 
function  Real2Str(r:real;lgt,nk:byte) : string;
function  Real2Str(r:extended;lgt,nk:byte) : string;
function  Str2Num(s:string; var num : byte) : boolean;
function  Str2Num(s:string; var num : word) : boolean;
//function  Str2Num(s:string; var num : integer) : boolean; // OBJFPC
function  Str2Num(s:string; var num : longint) : boolean;
function  Str2Num(s:string; var num : longword) : boolean;
function  Str2Real(s:string; var num : single) : boolean;
function  Str2Real(s:string; var num : real) : boolean; 
function  Str2Real(s:string; var num : extended) : boolean;
function  Hex   (nr:qword;lgt:byte) : string; 
function  HexStr(s:string):string;
procedure ShowStringList(StrList:TStringList); 
procedure MemCopy(src, dest:pointer; size:longint);
procedure MemCopy2(src, dest : pointer; size,src_offs,dest_offs : longint);
function  DeltaTime_in_ms(dt1,dt2:TDateTime):int64;
function  CRC8(s:string):byte;
function  Bit_Set_OR_Mask(BitNr:byte) : byte;
function  Bit_Reset_AND_Mask(BitNr:byte) : byte;
procedure Set_stty_speed(tty,speed:string);
procedure SetUTCOffset; // time Offset in minutes form GMT to localTime
function  GetUTCOffsetString(offset_Minutes:longint):string; { e.g. '+02:00' } 
function  GetDateTimeUTC   : TDateTime;
function  GetDateTimeLocal : TDateTime; 

{$IFDEF UNIX}
function  getpt            :cint; cdecl;external 'c'; // name 'getpt';
function  grantpt (fd:cint):cint; cdecl;external 'c';
function  unlockpt(fd:cint):cint; cdecl;external 'c';
function  ptsname (fd:cint):pchar;cdecl;external 'c'; 
function  tcgetattr(fd:cint; termios_p:Ptermios):cint;cdecl;external 'c';
function  tcsetattr(fd:cint; optional_actions:cint; termios_p:Ptermios):cint;cdecl;external 'c';
procedure cfmakeraw(termios_p:Ptermios);cdecl;external 'c';
function  tcsendbreak(fd:cint; duration:cint):cint;cdecl;external 'c';
function  tcdrain(fd:cint):cint;cdecl;external 'c';
function  tcflush(fd:cint; queue_selector:cint):cint;cdecl;external 'c';

function  Term_ptmx(var termio:Terminal_device_t; link:string; menablemask,mdisablemask:longint):boolean;
function  TermIO_Read(var term:Terminal_device_t; rawmode:boolean):string;
procedure TermIO_Write(var term:Terminal_device_t; str:string);
procedure Test_BiDirectionDevice_in_UserSpace; // write and read from /dev/testbidir
{$ENDIF}

implementation  

const int_filn_c='/tmp/gpio_int_setup.sh'; 
var OldExitProc : Pointer;
    LOG_Level,LOG_OLD_Level:T_ErrorLevel;
    cpu_rev_num,gpio_map_idx:byte;
    cpu_snr,cpu_hw,cpu_proc,cpu_rev,cpu_mips,cpu_feat,cpu_fmin,cpu_fcur,cpu_fmax:string;
	HighPrecisionMicrosecondFactor : Int64 = 1; 
	BB_pin	: longint;
	morse_dit_lgt:word;

procedure delay_msec (Milliseconds:longword);  begin sysutils.sleep(Milliseconds); end;

function  CRC8(s:string):byte; var i,crc:byte; begin crc:=$00; for i := 1 to Length(s) do crc:=crc xor ord(s[i]); CRC8:=crc; end;

{$IFDEF WINDOWS}
  function  CPUClockFrequency: Int64; var rslt:Int64; begin if not QueryPerformanceFrequency(rslt) then rslt:=-1; CPUClockFrequency:=rslt; end;
  procedure InitHighPrecisionTimer; var F : Int64; begin F := CPUClockFrequency; HighPrecisionMillisecondFactor := F div 1000; HighPrecisionMicrosecondFactor := F div 1000000; HighPrecisionTimerInit := True; end;
  function  GetHighPrecisionCounter: Int64; var rslt:Int64; begin if not HighPrecisionTimerInit then InitHighPrecisionTimer; QueryPerformanceCounter(rslt); GetHighPrecisionCounter:=rslt; end;
  procedure delay_nanos(Nanoseconds:longword); begin end;
{$ELSE}
  function  GetHighPrecisionCounter: Int64; var rslt:Int64; TV : TTimeVal; TZ : PTimeZone; begin TZ := nil; fpGetTimeOfDay(@TV, TZ); rslt := Int64(TV.tv_sec) * 1000000 + Int64(TV.tv_usec); GetHighPrecisionCounter:=rslt; end;

  procedure delay_nanos(Nanoseconds:longword);
  var sleeper,dummy : timespec;
  begin
    sleeper.tv_sec  := 0;
    sleeper.tv_nsec := Nanoseconds;
    fpnanosleep(@sleeper,@dummy);
  end;
{$ENDIF}
procedure delay_us(Microseconds:Int64);
var I, J, F : Int64; 
begin
  if Microseconds>0 then
  begin
    I := GetHighPrecisionCounter;
    if Microseconds >= 1000 then sysutils.sleep(Microseconds div 1000);
    F := Int64(Microseconds * HighPrecisionMicrosecondFactor);
    repeat J := GetHighPrecisionCounter; until Int64(J - I) >= F;
  end;
end;

function  CalcUTCOffsetString:string; { e.g. '+02:00' }
var sh,sh1:string; mins,hours:longint;
begin
  if _TZLocal<0 then sh:='-' else sh:='+'; mins:=abs(_TZLocal) mod 60; hours:=abs(_TZLocal) div 60;
  sh1:='00'+Num2Str(hours,0); sh:=sh+copy(sh1,Length(sh1)-1,2)+':'; sh1:='00'+Num2Str(mins,0); sh:=sh+copy(sh1,Length(sh1)-1,2);
//if sh='+00:00' then sh:='Z';
  CalcUTCOffsetString:=sh;
end;

procedure SetUTCOffset; // time Offset in minutes form GMT to localTime 
{$IFDEF MSWINDOWS} var BiasType: Byte; TZInfo: TTimeZoneInformation; {$ENDIF}
begin
  _TZLocal:=0;
  {$IFDEF WINDOWS}
    BiasType := GetTimeZoneInformation(TZInfo);
	case BiasType of // Determine offset 
	   0 : _TZLocal := 0;
       2 : _TZLocal := -(TZInfo.Bias + TZInfo.DaylightBias);	   
	  else _TZLocal := -(TZInfo.Bias + TZInfo.StandardBias);
	end;
    //writeln('Bias ',BiasType,' ',TZInfo.Bias,' ',TZInfo.DaylightBias,' ',TZInfo.StandardBias);
  {$ENDIF}
  {$IFDEF UNIX} 
    _TZLocal := Tzseconds div 60; 
  {$ENDIF}
  _TZOffsetString:=CalcUTCOffsetString;
end;

function  GetUTCOffsetString(offset_Minutes:longint):string; { e.g. '+02:00' } begin GetUTCOffsetString:=_TZOffsetString; end;

function  GetDateTimeLocal : TDateTime; begin GetDateTimeLocal:=now; end;
function  GetDateTimeUTC   : TDateTime; begin GetDateTimeUTC  :=IncMinute(now,-_TZLocal); end;

function  LOG_Get_LevelStringShort(lvl:T_ErrorLevel) : string;
var  s:string;
begin
  s:='   '; 
  case lvl of
    LOG_ERROR   : begin s:='ERR'; end;
    LOG_WARNING : begin s:='WRN'; end;
    LOG_NOTICE  : begin s:='SUC'; end;
    LOG_INFO    : begin s:='INF'; end;
    LOG_DEBUG   : begin s:='DBG'; end;
	Log_URGENT  : begin s:='URG'; end;
    else          begin s:='   '; end;
  end;
  LOG_Get_LevelStringShort:=s;
end;

function Get_LogString(host,processname,processnr:string;typ:T_ErrorLevel):string;
{.c delivers LogString Header with format: YEAR-MM-DD hh:mm:ss host processname[processnr] }
var  s:string;
begin
  s:=FormatDateTime('YYYY-MM-DD hh:mm:ss',now);
  if host        <>'' then s:=s+' '+host;
  if processname <>'' then s:=s+' '+processname;
  if processnr   <>'' then s:=s+' ['+processnr+']';
  s:=s+' '; 
 (* s:=s+' NC'+' ['+host+'] '; *)
 (*	s:=s+' '+host+' ['+processnr+'] '; *)
  s:=s+LOG_Get_LevelStringShort(typ)+' ';
  Get_LogString:=s;
end;

procedure Log_Write  (typ:T_ErrorLevel;msg:string); begin if typ >= LOG_Level then write  (ErrOutput,Get_LogString('','','',typ)+msg); end;
procedure Log_Writeln(typ:T_ErrorLevel;msg:string); begin if typ >= LOG_Level then writeln(ErrOutput,Get_LogString('','','',typ)+msg); end;
function  LOG_Get_Level : T_ErrorLevel; begin LOG_Get_Level:=LOG_Level; end;
procedure LOG_Save_Level;    begin LOG_OLD_Level:=LOG_Get_Level; end;
procedure Log_Set_Level(level:T_ErrorLevel); begin LOG_Save_Level; LOG_Level:=level; end;
procedure LOG_Restore_Level; begin LOG_Set_Level(LOG_OLD_Level); end;

function  Bool2Str(b:boolean) : string; 	 begin if b then Bool2Str:='TRUE' else Bool2Str:='FALSE'; end;

function  Num2Str(num : byte;lgt:byte)     : String; Var S : String; begin Str (num:lgt,s); Num2Str:=s; end;
function  Num2Str(num : word;lgt:byte)     : String; Var S : String; begin Str (num:lgt,s); Num2Str:=s; end;
//function  Num2Str(num : integer;lgt:byte)  : String; Var S : String; begin Str (num:lgt,s); Num2Str:=s; end; // OBJFPC
function  Num2Str(num : longint;lgt:byte)  : string; var s : string; begin str (num:lgt,s); Num2Str:=s; end;
function  Num2Str(num : longword;lgt:byte) : String; Var S : String; begin Str (num:lgt,s); Num2Str:=s; end;
function  Num2Str(num : int64;lgt:byte)    : String; Var S : String; begin Str (num:lgt,s); Num2Str:=s; end;

function  Str2Num  (s:string; var num : byte)    : boolean; var code:integer; begin val(StringReplace(s,'0x','$',[rfReplaceAll,rfIgnoreCase]),num,code); Str2Num  :=(code = 0); end;
function  Str2Num  (s:string; var num : word)    : boolean; var code:integer; begin val(StringReplace(s,'0x','$',[rfReplaceAll,rfIgnoreCase]),num,code); Str2Num  :=(code = 0); end;
//function  Str2Num  (s:string; var num : integer) : boolean; var code:integer; begin val(StringReplace(s,'0x','$',[rfReplaceAll,rfIgnoreCase]),num,code); Str2Num  :=(code = 0); end;
function  Str2Num  (s:string; var num : longword): boolean; var code:integer; begin val(StringReplace(s,'0x','$',[rfReplaceAll,rfIgnoreCase]),num,code); Str2Num  :=(code = 0); end;
function  Str2Num  (s:string; var num : longint) : boolean; var code:integer; begin val(StringReplace(s,'0x','$',[rfReplaceAll,rfIgnoreCase]),num,code); Str2Num  :=(code = 0); end;
function  Str2Num  (s:string; var num : int64)   : boolean; var code:integer; begin val(StringReplace(s,'0x','$',[rfReplaceAll,rfIgnoreCase]),num,code); Str2Num  :=(code = 0); end;

function  Real2Str(r:single;lgt,nk:byte)   : string; var s : string; begin str(r:lgt:nk,s); Real2Str := s; end; 
function  Real2Str(r:real;lgt,nk:byte)     : string; var s : string; begin str(r:lgt:nk,s); Real2Str := s; end; 
function  Real2Str(r:extended;lgt,nk:byte) : string; var s : string; begin str(r:lgt:nk,s); Real2Str := s; end; 

function  Str2Real (s:string; var num : single)   : boolean; var code:integer; begin val(s,num,code); Str2Real:=(code = 0); end;
function  Str2Real (s:string; var num : real)     : boolean; var code:integer; begin val(s,num,code); Str2Real:=(code = 0); end;
function  Str2Real (s:string; var num : extended) : boolean; var code:integer; begin val(s,num,code); Str2Real:=(code = 0); end;

function  Hex  (nr:qword;lgt:byte) : string; begin Hex:=Format('%0:-*.*x',[lgt,lgt,nr]); end;
function  HexStr(s:string):string; var sh:string; i:longint; begin sh:=''; for i := 1 to Length(s) do sh:=sh+Hex(ord(s[i]),2); HexStr:=sh; end;
function  LeadingZero(w : Word) : String;    begin LeadingZero:=Format('%0:-*.*d',[2,2,w]); end;
function  Get_FixedStringLen(s:string;cnt:word;leading:boolean):string; var fmt:string; begin fmt:='%0:'; if not leading then fmt:=fmt+'-'; fmt:=fmt+'*.*s'; Get_FixedStringLen:=Format(fmt,[cnt,cnt,s]); end;
function  Upper(const s : string) : String; var sh : String; i:word; begin sh:=''; for i := 1 to Length(s) do sh := sh+Upcase(s[i]); Upper:=sh; end;
function  CharPrintable(c:char):string; begin if ord(c)<$20 then CharPrintable:=#$5e+char(ord(c) xor $40) else CharPrintable:=c; end;
function  StringPrintable(s:string):string; var sh : string; i : longint; begin sh:=''; for i:=1 to Length(s) do sh:=sh+CharPrintable(s[i]); StringPrintable:=sh; end;
procedure ShowStringList(StrList:TStringList); var n : longint; begin for n := 0 to StrList.Count - 1 do writeln(StrList[n]); end;

function FilterChar(s,filter:string):string;
{.c filtert aus string s alle char die in filter angegeben sind. }
var sh:string; i,j:integer;
begin
  sh:=s; 
  if Length(filter) > 0 then
  begin
    sh:='';
	for i := 1 to Length(s) do
	begin
      for j := 1 to Length(filter) do
      begin
	    if s[i]=filter[j] then sh:=sh+s[i];
	  end;
	end;
  end;
  FilterChar:=sh;
end;

function  Select_Item(const strng,trenner,trenner2:string;itemno:longint) : string; 
const esc_char='\';
var   str,hs,tr1,tr2 : string; bcnt,trcnt : longint; dhk_start,esc_start,xx,ende : boolean;
  function detsep(s,seporig,notuse1,notuse2:string):string;
  (* find unique Byte as Seperator *)
  const sep_start=#$8f; sep_end=#$ff; 
  var   sep : char; ende : boolean;
  begin
    sep := sep_start; ende := false;
	while (ord(sep)<ord(sep_end)) and not ende do
	begin
	  if (Pos(sep,s)=0) and (sep<>notuse1) and (sep<>notuse2) then ende := true else sep:=char(ord(sep)+1);
	end;
	if not ende then detsep:=seporig else detsep:=sep;
  end; (* detsep *)
begin
  xx:=Length(trenner2)>0; 
  if Length(trenner) <=1 then tr1:=trenner  else tr1:=detsep(strng,trenner, ' ',' ');
  if Length(trenner2)<=1 then tr2:=trenner2 else tr2:=detsep(strng,trenner2,tr1,' '); 
  (* if not xx then tr2:=''; *) 
  str:=StringReplace(strng,trenner, tr1,[rfReplaceAll,rfIgnoreCase]);
  str:=StringReplace(str,  trenner2,tr2,[rfReplaceAll,rfIgnoreCase]);
  hs := ''; bcnt := 1; dhk_start := false; ende := false; esc_start := false;
  if Length(strng)>0 then trcnt := 1 else trcnt:=0;
  while (bcnt <= Length(str)) and not ende do
  begin
    if (xx) and ( (str[bcnt] = tr2) ) and (not esc_start) then dhk_start := not dhk_start;
    if (str[bcnt] = tr1) and (not dhk_start) then INC(trcnt);
	if (str[bcnt] <> esc_char) then esc_start := false;
    if (trcnt=itemno) and 
       ( ( str[bcnt] <> tr1)  or dhk_start) then hs:=hs+str[bcnt];
(* writeln(str[bcnt],' ',bcnt:2,' ',trcnt:2,'    '); *) 
	   INC(bcnt);
	if (itemno > 0) and (trcnt > itemno) then ende := true;
  end;
  hs:=StringReplace(hs,tr1,trenner, [rfReplaceAll,rfIgnoreCase]);
  if xx then hs:=StringReplace(hs,tr2,'',      [rfReplaceAll,rfIgnoreCase])
        else hs:=StringReplace(hs,tr2,trenner2,[rfReplaceAll,rfIgnoreCase]);
  if itemno <= 0 then system.Str(trcnt:0,hs);
  Select_Item := hs;
end; 

function  Anz_Item(const strng,trenner,trenner2:string): longint;
var anz:longint; 
begin
  if Length(strng)>0 then
  begin if not Str2Num(Select_Item(strng,trenner,trenner2,0),anz) then anz:=0; end
  else anz := 0;
  Anz_Item := anz;
end;

procedure MemCopy(src, dest:pointer; size:longint);  begin if size > 0 then Move(src^, dest^, size); end; 

procedure MemCopy2(src, dest : pointer; size,src_offs,dest_offs : longint);
var psrc,pdest:pointer;
begin
  if size > 0 then
  begin
    psrc:=src; pdest:=dest;
    inc(longint(psrc),src_offs); inc(longint(pdest),dest_offs); // !! ?? !!
    Move(psrc^, pdest^, size);
  end;
end;

function GetVZ(dt1,dt2:TDateTime):integer; var vz:integer; begin if dt1>=dt2 then vz:=1 else vz:=-1; GetVZ:=vz; end;

function DeltaTime_in_ms(dt1,dt2:TDateTime):int64;
begin                                 
  DeltaTime_in_ms:=GetVZ(dt1,dt2)*MilliSecondsBetween(dt1,dt2);
end;

function call_external_prog(cmdline:string; receivelist:TStringList) : integer;
const READ_BYTES = 2048; test=false;
var M:TMemoryStream; P:TProcess; n:LongInt; BytesRead,exitStat:LongInt; ourcommand:string;
begin
  { We cannot use poWaitOnExit here since we don't
    know the size of the output. On Linux the size of the
    output pipe is 2 kB. If the output data is more, we 
    need to read the data. This isn't possible since we are 
    waiting. So we get a deadlock here.
    A temp Memorystream is used to buffer the output }  
  exitStat:=-1;
  {$warnings off} if test then writeln('cmdline: ',cmdline); {$warnings on}
  if (cmdline<>'')  then 
  begin
    M := TMemoryStream.Create;
    BytesRead := 0; 
    P := TProcess.Create(nil);
	OurCommand:='';
	P.Options := [poUsePipes]; 
	{$IFDEF Windows}
//    Can't use dir directly, it's built in
//    so we just use the shell:
      OurCommand:='cmd.exe /c '+cmdline;
	  P.CommandLine := OurCommand;
    {$ENDIF Windows}
    {$IFDEF Unix}
	  OurCommand := cmdline;
      p.Executable := '/bin/sh';
	  p.Parameters.Add('-c'); 
	  p.Parameters.Add(OurCommand);  
    {$ENDIF Unix}
	if OurCommand<>'' then
	begin
      P.Execute;
      while P.Running do 
      begin          
        { make sure we have room }
        M.SetSize(BytesRead + READ_BYTES);
        n := P.Output.Read((M.Memory + BytesRead)^, READ_BYTES);
        if n > 0 then Inc(BytesRead, n) else Sleep(100) { no data, wait for it }; 
      end; 
      exitStat:=P.exitStatus;
      { writeln('###',exitStat,'###'); }
      repeat { read last part of data }
        M.SetSize(BytesRead + READ_BYTES);
        n := P.Output.Read((M.Memory + BytesRead)^, READ_BYTES);
        if n > 0 then Inc(BytesRead, n);
      until n <= 0;
      M.SetSize(BytesRead);  
//    receivelist := TStringList.Create; /////////////////create it externally !!!!!!!!!!!!
      receivelist.LoadFromStream(M);
      {$warnings off} if test then showstringlist(receivelist); {$warnings on}
	end;
	P.Free;
    M.Free;
    {$warnings off} if test then writeln('Leave call_external_prog '); {$warnings on}
  end
  else LOG_Writeln(LOG_ERROR,'call_external_prog: empty cmdline '+cmdline);
  call_external_prog:=exitStat;
end;
 
procedure Set_stty_speed(tty,speed:string);
var ts:TStringlist; _speed,_tty:string; lw:longword;
begin
  ts:=TStringList.Create;
  if not Str2Num(speed,lw) then _speed:='9600'         else _speed:=speed;
  if tty=''                then _tty  :='/dev/ttyAMA0' else _tty:=  tty; 
  if call_external_prog('stty -F '+_tty+' '+_speed, ts) =0 then ;
  ts.free; 
end;

{$IFDEF UNIX}  
function  Term_ptmx(var termio:Terminal_device_t; link:string; menablemask,mdisablemask:longint):boolean;
// opens pseudo terminal.
// returns master and slave filedescriptor, and slavename for usage. link, links slavename to link
// masks: Term_ptmx(x,x,x,x, 0,ECHO) -> disables TerminalECHO // 0=noEnableAnything,disable ECHO
const ptmx_c='/dev/ptmx';
var snp:pchar; linkflag:boolean; tl:TStringList; newsettings:termios; 
begin 
  with termio do
  begin
    slavepath:=''; masterpath:=ptmx_c; linkpath:=link; fdslave:=-1; rlgt:=-1; ridx:=0; linkflag:=true; 
    fdmaster := fpopen (ptmx_c, Open_RDWR or O_NONBLOCK);
    if fdmaster>=0 then
    begin
      if grantpt(fdmaster)>=0 then
      begin
	    if unlockpt(fdmaster)>=0 then
        begin
	      snp:=ptsname(fdmaster);
          if snp<>nil then
          begin
		    slavepath:=snp;
		    fdslave:=fpopen(snp, Open_RDWR or O_NONBLOCK);
            if fdslave>=0 then 
		    begin
		      if FileExists(slavepath) then
			  begin
		        if link<>'' then
			    begin
			      tl:=TStringList.create;
			      if FileExists(link) then call_external_prog('unlink '+link,tl);
			      if (not FileExists(link)) then
			      begin
			        call_external_prog('ln -s '+slavepath+' '+link,tl);
				    linkflag:=FileExists(link);
				    if not linkflag then LOG_WRITELN(LOG_ERROR,'ptmx: cannot create link '+link+' (ln -s '+slavepath+' '+link);
//	                if master_termioflags_AND_mask<>0 then
				    begin
	                  tcgetattr(fdmaster, @newsettings);  			// pmtx(x,x,x,x, 0,ECHO) -> disables TerminalECHO
	                  newsettings.c_lflag:=(newsettings.c_lflag or menablemask) and (not mdisablemask); // &= ~(ECHO | ICANON | IEXTEN | ISIG);
	                  tcsetattr(fdmaster, TCSANOW, @newsettings); 	// was TCSADRAIN
                    end;				  
 		          end 
			      else LOG_WRITELN(LOG_ERROR,'ptmx: link already exists: '+link);
			      tl.free;
			    end;
			  end
			  else LOG_WRITELN(LOG_ERROR,'ptmx: not created '+slavepath);
		    end
		    else LOG_WRITELN(LOG_ERROR,'ptmx: cannot open '+slavepath);
          end
		  else LOG_WRITELN(LOG_ERROR,'ptmx: cannot get slavepath');
	    end
	    else LOG_WRITELN(LOG_ERROR,'ptmx: cannot unlockpt');
	  end
	  else LOG_WRITELN(LOG_ERROR,'ptmx: cannot grantpt');
    end
    else LOG_WRITELN(LOG_ERROR,'ptmx: cannot open '+ptmx_c);
//  writeln('ptmx fd: ',fdmaster,' ',fdslave,' ',((fdmaster>=0) and (fdslave>=0) and (slavepath<>'') and linkflag),' ',slavename);
    Term_ptmx:=((fdmaster>=0) and (fdslave>=0) and (slavepath<>'') and linkflag);
  end; // with
end;

function  TermIO_Read(var term:Terminal_device_t; rawmode:boolean):string;
var i:longint; str:string; ende:boolean;
begin
  str:=''; ende:=false;
  with term do
  begin
    if (fdmaster>=0) then
    begin
      if ridx<=0 then begin rlgt:=fpread(fdmaster,@si,Terminal_MaxBuf); ridx:=0; end;
	  if rawmode then
	  begin
	    for i := 1 to rlgt do str:=str+si[i];
		ridx:=0;
	  end
	  else
	  begin
		while (ridx<rlgt) and (not ende) do
	    begin
		  inc(ridx);
	      if (si[ridx]=LF) then ende:=true
                           else if (si[ridx]<>CR) then str:=str+si[ridx]; 
	    end;
		if ridx>=rlgt then ridx:=0;
	  end;
	end;
  end; // with
  TermIO_Read:=str;
end;

procedure TermIO_Write(var term:Terminal_device_t; str:string);
begin
  with term do
  begin
    if (fdmaster>=0) then
    begin
      fpwrite(fdmaster,str[1],length(str));
	end;
  end;
end;

procedure DoActionOnReceivedInput(s:string); 
// just for Demo. Process can react on InputCommands, written to our device /dev/testbidir
begin writeln('Received: ',s); end;

procedure Test_BiDirectionDevice_in_UserSpace; // write and read from /dev/testbidir
const maxloops=100;
var termio:Terminal_device_t; loop:longint; str:string;
begin
  loop:=1;
  with termio do
  begin
    writeln('Start of Test_BiDirectionDevice_in_UserSpace, do ',maxloops:0,' loops (user root)');
    if Term_ptmx(termio,'/dev/testbidir',0,ECHO) then
    begin
	  fpclose(fdslave);
	  writeln('Screen1: pls. open 2 additional screens (e.g. with putty to your pi user:root)');
	  writeln('filedescriptor master: ',fdmaster,'   fdslave: ',fdslave);
	  writeln('masterpath: ',masterpath);
	  writeln('slavepath:  ',slavepath);
	  writeln('linkpath:   ',linkpath,' linked to ',slavepath);
	  writeln('do a cat ',linkpath,' on screen2, to see data which was written to master device');
	  writeln('do a echo xxxxx >> ',linkpath,' on screen3 to pass data which the master can read');
	  sleep(5000); 
	  writeln('Start to write Hello#<nr> to master device');
      repeat   
	    str:=TermIO_Read(termio,false); 					// async read from master device
		if str<>'' then DoActionOnReceivedInput(str);		// process input data, if something was red
	    TermIO_Write(termio,'Hello#'+Num2Str(loop,0)+LF);	// write to  master device
        sleep(1000); inc(loop);
      until loop>maxloops;
	  writeln('closing '+linkpath);
	  fpclose(fdmaster);
	  writeln('End of Test_BiDirectionDevice_in_UserSpace (you should get an Input/output error on screen2)');
    end
    else writeln('ptmx init failed');
  end;
end;
{$ENDIF}

procedure Get_CPU_INFO_Init;   
{cat /proc/cpuinfo
Code: Select all
    revision        : 100000f
Ignore the top 8 bits (which includes warranty bit). You want:
if ((revision & 0xffffff) >= 4) then rev2 else rev1.
Also:
if ((revision & 0xffffff) >= 10) then 512M else 256M.

												sudo cat /sys/devices/system/cpu/cpu0/cpufreq/cpuinfo_max_freq
minimum CPU frequence (when your CPU is idle): 	sudo cat /sys/devices/system/cpu/cpu0/cpufreq/cpuinfo_min_freq
current CPU frequence:							sudo cat /sys/devices/system/cpu/cpu0/cpufreq/cpuinfo_cur_freq

}  
const proc1_c='cat /proc/cpuinfo';  proc2_c='cat /sys/devices/system/cpu/cpu0/cpufreq/cpuinfo';  
var ts:TStringlist; sh:string; lw:longword; code:integer;

  function cpuinfo_unix(infoline:string):string;
  var s:string; i:integer;
  begin
    s:=''; i:=1; while i<=ts.count do begin if Pos(Upper(infoline),Upper(ts[i-1]))=1 then begin s:=ts[i-1]; i:=ts.count+1 end; inc(i); end;
	cpuinfo_unix:=copy(s,Pos(':',s)+2,Length(s));
  end;

begin 
   cpu_snr:='';  cpu_hw:='';   cpu_proc:=''; cpu_rev:=''; cpu_mips:=''; cpu_feat:=''; cpu_rev_num:=0;
   cpu_fmin:=''; cpu_fcur:=''; cpu_fmax:='';
  {$IFDEF UNIX}  
	ts:=TStringList.Create;
	if call_external_prog(proc2_c+'_min_freq',ts)=0 then begin if ts.count>0 then cpu_fmin:=ts[0]; end; ts.clear;
	if call_external_prog(proc2_c+'_cur_freq',ts)=0 then begin if ts.count>0 then cpu_fcur:=ts[0]; end; ts.clear;
	if call_external_prog(proc2_c+'_max_freq',ts)=0 then begin if ts.count>0 then cpu_fmax:=ts[0]; end; ts.clear;
//  writeln('CPU Freq: ',cpu_fmin,' ',cpu_fcur,' ',cpu_fmax);
	if call_external_prog(proc1_c,ts)=0 then
    begin
	  cpu_snr:= cpuinfo_unix('Serial');
	  cpu_hw:=  cpuinfo_unix('Hardware');
	  cpu_proc:=cpuinfo_unix('Processor');
	  cpu_mips:=cpuinfo_unix('BogoMIPS');
	  cpu_feat:=cpuinfo_unix('Features');
	  
	  cpu_rev:= cpuinfo_unix('Revision');
      cpu_rev_num:=0; gpio_map_idx:=cpu_rev_num; sh:=''; val('$'+cpu_rev,lw,code); if code<>0 then lw:=0;
//  writeln('cpuinfo ',hex(lw,8));
      case (lw and $ffffff) of
        $00..$03 : begin sh:='rev1;256MB;B';  cpu_rev_num:=1; gpio_map_idx:=cpu_rev_num; end;
	    $04..$06 : begin sh:='rev2;256MB;B';  cpu_rev_num:=2; gpio_map_idx:=cpu_rev_num; end;
		$07..$09 : begin sh:='rev2;256MB;A';  cpu_rev_num:=2; gpio_map_idx:=cpu_rev_num; end;
		$0d..$0f : begin sh:='rev2;512MB;B';  cpu_rev_num:=2; gpio_map_idx:=cpu_rev_num; end;
		$10      : begin sh:='rev1;512MB;B+'; cpu_rev_num:=1; gpio_map_idx:=3; end;
		$11      : begin sh:='rev1;512MB;CM'; cpu_rev_num:=1; gpio_map_idx:=3; end;
		$12      : begin sh:='rev1;256MB;A+'; cpu_rev_num:=1; gpio_map_idx:=3; end;
      end;
      cpu_rev :=sh+';'+cpu_rev;  
//writeln(sh,' ',cpu_rev_num);	  
    end;	
	ts.free;   
  {$ENDIF}
end;

function Bit_Set_OR_Mask(BitNr:byte) : byte;
{.c gibt Maske zurueck, um Bit an Stelle 'BitNr' [1..8] zu setzen }
var b:byte;
begin
  if (BitNr>=1) and (BitNr<=8) then b:=(1 shl (BitNr-1)) else b:=0;
  Bit_Set_OR_Mask:=b;
end; { Bit_Set_OR_Mask }

function Bit_Reset_AND_Mask(BitNr:byte) : byte;
{.c gibt Maske zurueck, um Bit an Stelle 'BitNr' zurueckzusetzen }
begin
  Bit_Reset_AND_Mask := not Bit_Set_OR_Mask(BitNr);
end; { Bit_Reset_AND_Mask }

function  Bit_Set_OR_Mask32(BitNr:byte) : longword;
{.c return Mask, to set Bit on position 'BitNr' [1..32] }
var lw:longword;
begin
  if (BitNr>=1) and (BitNr<=32) then lw:=(1 shl (BitNr-1)) else lw:=0;
  Bit_Set_OR_Mask32:=lw;
end; { Bit_Set_OR_Mask32 }

function  BitSlice32(data:longword; bitstartpos,slicelgt:byte) : longword;  
{.c returns Bit slice area (Bit Nr. from  1 to 32) 
i.e. data(bin) = 00101100; startpos=6; slicelgt=4; rslt:= 00001011 }
var rslt,msk : longword; i:longint;
begin
  rslt := 0; msk:=0;
  for i:= bitstartpos downto (bitstartpos-slicelgt+1) do msk := msk or Bit_Set_OR_Mask32(i);
  rslt:= data and msk;
  rslt:=rslt shr (bitstartpos-slicelgt);
  BitSlice32 := rslt;
end;

function  BitMsk(bitstartpos,slicelgt:byte):longword;
var msk:longword;
begin
  if slicelgt>bitstartpos then msk:=0 else msk:=($ffffffff shr ((SizeOf(msk)*8)-slicelgt)) shl (bitstartpos-slicelgt);
  BitMsk:=msk;
end;

function  BitSet(q:qword;nr:byte) : Boolean; {.c checks if Bit 'nr' is set. (nr: 1 to 64) } begin BitSet:=((q and (1 shl (nr-1)))>0); end; { BitSet }

function  Bin(q:qword;lgt:Byte) : string;
{.c shows q in binary representation: bbbb bbbb ... }
var h : string; i : Byte;
begin
  h := '';
  for i := (lgt-1) downto 0 do
  begin
    if BitSet(q,i+1) then h:=h+'1' else h:=h+'0';
	if ((i mod 4)=0) and (i>0) then h:=h+' ';
  end;
  Bin:=h;
end; { Bin }

function  WriteBits(in_byte,bitStart,lgt,inplant:byte) : byte; { bitnum 8..1 }
var b,mask,data:byte;
begin
    // 87654321 bit numbers
    //      010 value to inplant in given in_byte
    //    xxx   args: bitStart=5, lgt=3
    // 00011100 mask
    // 10101111 original value (in_byte)
    // 10100011 original & ~mask
    // 10101011 masked | value -> return value
  b:=in_byte; data:=inplant;
  if (bitStart<=8) and (lgt<=8) then 
  begin
	if lgt>0 then
	begin
      mask := ((1 shl lgt) - 1) shl (bitStart - lgt);
      data := data shl (bitStart - lgt); // shift data into correct position
      data := data and mask; // zero all non-important bits in data
      b:=     b and (not mask); // zero all important bits in existing byte
      b:=     b or data; // combine data with existing byte
    end;
  end;
  WriteBits:=b;
end;

function  ReadBits(in_byte,bitStart,lgt:byte):byte;  { bitnum 8..1 }
var b,mask:byte;
begin                  
  // 87654321 bit numbers                       
  // 01101001 in_byte
  //    xxx   args: bitStart=5, length=3
  //    010   masked
  //   -> 010 shifted -> return value
  b:=0;
  if (bitStart<=8) and (lgt<=8) then 
  begin
    if (in_byte <> 0) then 
    begin
      mask := ((1 shl lgt) - 1) shl (bitStart - lgt);
      b := b and mask;
      b := b shr (bitStart - lgt);
    end;
  end;
  ReadBits:=b;
end;

procedure i2c_Fill_Test_Buffer(var data:databuf_t; testnr:integer; baseadr,reg,busnumber:byte); begin i2c_CleanBuffer(busnumber); end;

function  rpi_mmap_get_info (modus:longint)  : longword;
var valu:longword;
begin 
  valu:=0;
  case modus of
	 1,2 : valu:=PAGE_SIZE;
	 3	 : valu:=GPIO_BASE_in_pages;
	 4   : begin {$IFDEF UNIX} valu:=1; {$ELSE} valu:=0; {$ENDIF} end;      (* if run_on_unix ->1 else 0 *)
	 5   : if (Upper({$i %FPCTARGETCPU%})='ARM') then valu:=1 else valu:=0; (* if run_on_ARM  ->1 else 0 *)
	 6	 : begin valu:=1; end;												(* if RPI_Piggyback_board_available -> 1 dummy, for future use *)
	 7   : if ((rpi_mmap_get_info(5)=1) and 
	           (Upper(rpi_hw)='BCM2708')) then valu:=1;		   			    (* runs on known rpi HW *)  
	 8	 : begin valu:=1; end;												(* if PiFaceBoard_board_available -> 1 dummy, for future use *)
  end;
  rpi_mmap_get_info:=valu;
end;

function rpi_mmap_run_on_unix:boolean; 						begin rpi_mmap_run_on_unix:=(rpi_mmap_get_info(4)=1); end;
function rpi_run_on_ARM:boolean;       						begin rpi_run_on_ARM :=     (rpi_mmap_get_info(5)=1); end;
function RPI_Piggyback_board_available  : boolean; 			begin RPI_Piggyback_board_available:=(rpi_mmap_get_info(6)=1); end;
function RPI_PiFace_board_available(devadr:byte): boolean; 	begin RPI_PiFace_board_available:=   (rpi_mmap_get_info(8)=1); end;
function rpi_run_on_known_hw:boolean;     					begin rpi_run_on_known_hw := (rpi_mmap_get_info(7)=1); end;
function rpi_platform_ok:boolean; 							begin rpi_platform_ok:= ((rpi_revnum<>0) and (rpi_run_on_known_hw)) end;

function  rpi_mmap_gpio_reg_read (adr:longword) : longword; 
var lw:longword;
begin 
  if mmap_arr_gpio<>nil then lw:=mmap_arr_gpio^[adr] else lw:=0;
  rpi_mmap_gpio_reg_read:=lw;
end;

function  rpi_mmap_pwm_reg_read (adr:longword) : longword; 
var lw:longword;
begin 
  if mmap_arr_pwm<>nil then lw:=mmap_arr_pwm^[adr] else lw:=0;
  rpi_mmap_pwm_reg_read:=lw;
end;

function  rpi_mmap_clk_reg_read (adr:longword) : longword; 
var lw:longword;
begin 
  if mmap_arr_clk<>nil then lw:=mmap_arr_clk^[adr] else lw:=0;
  rpi_mmap_clk_reg_read:=lw;
end;

function  rpi_mmap_gpio_reg_write(adr,value: longword) : longword;
var rslt:longword; 
begin 
  rslt:=0;
  if mmap_arr_gpio<>nil then
  begin
    mmap_arr_gpio^[adr]:=value; //if mmap_arr_gpio^[adr]=value then rslt:=0;
  //writeln('rpi_mmap_gpio_reg_write (get adr and mask)',adr,' ',Hex(value,8)); 
  end;
  rpi_mmap_gpio_reg_write:=rslt; 
end;

function  rpi_mmap_pwm_reg_write(adr,value: longword) : longword;
var rslt:longword; 
begin 
  rslt:=0;
  if mmap_arr_pwm<>nil then
  begin
    mmap_arr_pwm^[adr]:=value; //if mmap_arr_pwm^[adr]=value then rslt:=0;
  //writeln('rpi_mmap_pwm_reg_write (get adr and mask)',adr,' ',Hex(value,8)); 
  end;
  rpi_mmap_pwm_reg_write:=rslt; 
end;

function  rpi_mmap_clk_reg_write(adr,value: longword) : longword;
var rslt:longword; 
begin 
  rslt:=0;
  if mmap_arr_clk<>nil then
  begin
    mmap_arr_clk^[adr]:=value; //if mmap_arr_clk^[adr]=value then rslt:=0;
  //writeln('rpi_mmap_clk_reg_write (get adr and mask)',adr,' ',Hex(value,8)); 
  end;
  rpi_mmap_clk_reg_write:=rslt; 
end;

procedure Toggle_Pin_very_fast(pin,cnt:longword);
{ just to show how fast (without overhead) we can toggle PINxx. Result 5.88MHz @ 700Mhz rpi clock freq }
var i:longint; idx,mask:longword; s,e:TDateTime;	
begin
  i:=0; gpio_set_OUTPUT(pin); gpio_get_mask_and_idx(pin,idx,mask); // get PinMask
  {start measureing time} 
    s:=now; writeln('Start: ',FormatDateTime('yyyy-mm-dd hh:nn:ss',s),' (',cnt:0,' samples, Pin: ',pin:0,' PinMask: 0x',Hex(mask,8),')');
    repeat mmap_arr_gpio^[GPSET]:=mask; mmap_arr_gpio^[GPCLR]:=mask; inc(i); until (i>=cnt);
    e:=now; writeln('End:   ',FormatDateTime('yyyy-mm-dd hh:nn:ss',e),' (',(cnt div MilliSecondsBetween(e,s)):0,' kHz)');
  {end   measureing time} 
end;

procedure Toggle_Pin16_very_fast; begin Toggle_Pin_very_fast(16,1000000); end;	// Status LED
procedure Toggle_Pin23_very_fast; begin Toggle_Pin_very_fast(23,1000000); end;

procedure gpio_start;
{ Set up a memory region to access GPIO }
var rslt,errno:longint;
begin
  rslt:=-1; errno:=0;
  {$IFDEF UNIX}
    if rpi_run_on_ARM and (mmap_arr_gpio=nil) then 
    begin 
      mem_fd := fpOpen('/dev/mem',(O_RDWR or O_SYNC));   { open /dev/mem } 
      if mem_fd >= 0 then 
      begin { mmap GPIO }
	    rslt:=-2;
        mmap_arr_gpio:=fpMMap(pointer(0),PAGE_SIZE,(PROT_READ or PROT_WRITE),(MAP_SHARED {or MAP_FIXED}),mem_fd,GPIO_BASE_in_pages); 
		mmap_arr_pwm :=fpMMap(pointer(0),PAGE_SIZE,(PROT_READ or PROT_WRITE),(MAP_SHARED {or MAP_FIXED}),mem_fd,PWM_BASE_in_pages); 
		mmap_arr_clk :=fpMMap(pointer(0),PAGE_SIZE,(PROT_READ or PROT_WRITE),(MAP_SHARED {or MAP_FIXED}),mem_fd,CLK_BASE_in_pages); 
        {$warnings off} 
		  if (longint(mmap_arr_gpio)=-1) or 
		     (longint(mmap_arr_pwm) =-1) or 
			 (longint(mmap_arr_clk) =-1) then errno:=fpgeterrno else rslt:=0; 
		{$warnings on}
      end;
    end;
  {$ENDIF}
  case rslt of
     0 : Log_writeln(Log_INFO, 'rpi_mmap_init, init successful');
    -1 : Log_writeln(Log_ERROR,'rpi_mmap_init, can not open /dev/mem on target CPU '+{$i %FPCTARGETCPU%}+', result: '+Num2Str(rslt,0));
    -2 : Log_writeln(Log_ERROR,'rpi_mmap_init, mmap fpgeterrno: '+Num2Str(errno,0)+' result: '+Num2Str(rslt,0));
	else Log_writeln(Log_ERROR,'rpi_mmap_init, unknown error, result: '+Num2Str(rslt,0));
  end;
  if rslt<>0 then begin mmap_arr_gpio:=nil;	mmap_arr_pwm:=nil; mmap_arr_clk:=nil; end;
end;

procedure gpio_end;
var rslt:longint;
begin
  rslt:=0;
  {$IFDEF UNIX}
    if mem_fd  >= 0  then fpclose(mem_fd); 
    if mmap_arr_gpio<>nil then if fpMUnMap(mmap_arr_gpio,PAGE_SIZE)<>0 then ;
    if mmap_arr_pwm <>nil then if fpMUnMap(mmap_arr_pwm, PAGE_SIZE)<>0 then ;
    if mmap_arr_clk <>nil then if fpMUnMap(mmap_arr_clk, PAGE_SIZE)<>0 then ;
  {$ENDIF}
  mmap_arr_gpio:=nil; mmap_arr_pwm:=nil; mmap_arr_clk:=nil;	
  case rslt of
     0 : Log_writeln(Log_INFO, 'rpi_mmap_close, successful '+Num2Str(rslt,0));
    -1 : Log_writeln(Log_ERROR,'rpi_mmap_close, un-mmapping '+Num2Str(rslt,0));
    else Log_writeln(Log_ERROR,'rpi_mmap_close, unknown error '+Num2Str(rslt,0));	
  end;
end;

function  gpio_get_desc(regidx,regcontent:longword) : string;
  function get_reg_desc(regidx:longword):string;
  var s:string;
  begin
    s:='';
	case regidx of
	  GPFSEL..GPFSEL+5 		: s:='GPFSEL'+  Num2Str((regidx-GPFSEL),0); 
	  GPSET ..GPSET+1		: s:='GPSET'+   Num2Str((regidx-GPSET),0); 
      GPCLR ..GPCLR+1		: s:='GPCLR'+   Num2Str((regidx-GPCLR),0);
	  GPLEV ..GPLEV+1		: s:='GPLEV'+   Num2Str((regidx-GPLEV),0);
	  GPEDS ..GPEDS+1		: s:='GPEDS'+   Num2Str((regidx-GPEDS),0);
	  GPREN	..GPREN+1		: s:='GPREN'+   Num2Str((regidx-GPREN),0); 	
	  GPFEN ..GPFEN+1		: s:='GPFEN'+   Num2Str((regidx-GPFEN),0); 
	  GPHEN	..GPHEN+1		: s:='GPHEN'+   Num2Str((regidx-GPHEN),0);
	  GPLEN	..GPLEN+1		: s:='GPLEN'+   Num2Str((regidx-GPLEN),0); 
	  GPAREN..GPAREN+1		: s:='GPAREN'+  Num2Str((regidx-GPAREN),0);
	  GPAFEN..GPAFEN+1		: s:='GPAFEN'+  Num2Str((regidx-GPAFEN),0);
	  GPPUD			   		: s:='GPPUD'+   Num2Str((regidx-GPPUD),0);
	  GPPUDCLK..GPPUDCLK+1	: s:='GPPUDCLK'+Num2Str((regidx-GPPUDCLK),0);
	  else                    s:='Reg['+    Num2Str((regidx-GPIO_BASE),0)+']';
	end;
    get_reg_desc:=s;
  end;
  function pinfkt(value:byte):string;
  var s:string;
  begin
    case value of
	  $00 : s:='I '; $01 : s:='O '; $02 : s:='A5'; $03 : s:='A4';
	  $04 : s:='A0'; $05 : s:='A1'; $06 : s:='A2'; $07 : s:='A3';
	  else  s:='';
    end;
   pinfkt:=s;
  end;
var s:string; pin:integer;
begin
  s:=Get_FixedStringLen(get_reg_desc(regidx),9,false)+': '+Bin(regcontent,32)+' ';
  case regidx of
    GPFSEL..GPFSEL+5 : begin
                         for pin:= 9 downto 0 do
						   s:=s+'P'+LeadingZero(pin+(regidx-GPFSEL)*10)+':'+pinfkt(Byte(BitSlice32(regcontent,(pin*3)+3,3)))+' ';					 
	                   end;
				 else  s:=s+'0x'+Hex(regcontent,8);
  end;
  gpio_get_desc:=s;
end;

function  pwm_get_desc(regidx,regcontent:longword) : string;
  function get_reg_desc(regidx:longword):string;
  var s:string;
  begin
    s:='';
	case regidx of
	  PWMCTL  : s:='PWMCTL'; 
	  PWMSTA  : s:='PWMSTA';
	  PWMDMAC : s:='PWMDMAC';
	  PWMRNG1 : s:='PWMRNG1';
	  PWMDAT1 : s:='PWMDAT1';
	  PWMFIF1 : s:='PWMFIF1';
	  PWMRNG2 : s:='PWMRNG2';
	  PWMDAT2 : s:='PWMDAT2';
	  else      s:='Reg['+    Num2Str((regidx-PWM_BASE),0)+']';
	end;
    get_reg_desc:=s;
  end;
var s:string;
begin
  s:=Get_FixedStringLen(get_reg_desc(regidx),9,false)+': '+Bin(regcontent,32)+' 0x'+Hex(regcontent,8);
  pwm_get_desc:=s;
end;

function get_regidx(regidx,pin:longint):longint;
var idx:longword;
begin
  idx:=maxint;
  case regidx of
	GPFSEL : idx:=regidx+((pin mod 54) div 10);
    GPPUD  : idx:=regidx;
    else     idx:=regidx+((pin mod 54) div 32);
  end;
  get_regidx:=idx;
end;

function  gpio_get_reg(regidx:longword) : longword;       begin gpio_get_reg:=rpi_mmap_gpio_reg_read (regidx);       end;
function  gpio_set_reg(regidx,value:longword) : longword; begin gpio_set_reg:=rpi_mmap_gpio_reg_write(regidx,value); end;
function  clk_get_reg(regidx:longword) : longword;        begin clk_get_reg:= rpi_mmap_clk_reg_read  (regidx);       end;
function  clk_set_reg(regidx,value:longword) : longword;  begin clk_set_reg:= rpi_mmap_clk_reg_write (regidx,value); end;
function  pwm_get_reg(regidx:longword) : longword;        begin pwm_get_reg:= rpi_mmap_pwm_reg_read  (regidx);       end;
function  pwm_set_reg(regidx,value:longword) : longword;  begin pwm_set_reg:= rpi_mmap_pwm_reg_write (regidx,value); end;

procedure gpio_set_register(regidx,pin,mask:longword;and_mask,readmodifywrite:boolean);
var idx,value:longword;
begin
  if (pin>=0) and (pin<=53) then
  begin
    idx:=get_regidx(regidx,pin);
	value:=mask;
	if (idx<>maxint) and (mmap_arr_gpio<>nil) then
	begin
	  value:=mask;
      if readmodifywrite then
	  begin
	    if and_mask then value:=rpi_mmap_gpio_reg_read(idx) and mask else value:=rpi_mmap_gpio_reg_read(idx) or  mask;
      end;
	  if rpi_mmap_gpio_reg_write(idx,value) <> 0 then Log_Writeln(LOG_ERROR,'gpio_set_register mmap_reg_write error');
	                                       {else Log_Writeln(LOG_INFO, 'gpio_set_register mmap_reg_write success'); }
    end
	else
	begin
	  Log_Writeln(LOG_ERROR,  'gpio_set_register['+LeadingZero(idx)+']:=0x'+hex(value,8)+'  '+Bin(value,32));
	end;
  end
  else
  begin
    Log_Writeln(LOG_ERROR,  'gpio_set_register Pin does not exist: '+Num2Str(pin,0)); 
  end;
end;

function  gpio_get_Mask(pin,altfunc,mode:longword):longword;
var res:longword;
begin
  case mode of
    gpio_INPUT: 	 res:=(not (7 shl ((pin mod 10)*3)));
	gpio_OUTPUT:	 res:=(1 shl ((pin mod 10)*3));
    gpio_ALT: 		 begin
	                   res:=2; if altfunc<=3 then res:=altfunc+4 else if altfunc=4 then res:=3;
                       res:=(res shl ((pin mod 10)*3));
	                 end;
	else res:=0;
  end;
  gpio_get_Mask:=res;
end;
  
procedure gpio_set_INPUT (pin:longword); 
begin 
  Log_Writeln(LOG_DEBUG,'gpio_set_INPUT: Pin '+Num2Str(pin,0)); 
  gpio_set_register(GPFSEL,pin,gpio_get_Mask(pin,0,gpio_INPUT),true,true); 
end;

procedure gpio_set_OUTPUT(pin:longword); 
begin 
  Log_Writeln(LOG_DEBUG,'gpio_set_OUTPUT: Pin '+Num2Str(pin,0)); 
  gpio_set_INPUT (pin); { Always use gpio_set_INPUT(x) before using gpio_set_OUTPUT(x) or gpio_set_ALT(x,y)  }  
  gpio_set_register(GPFSEL,pin,gpio_get_Mask(pin,0,gpio_OUTPUT),false,true); 
end; 

procedure gpio_set_ALT   (pin,altfunc:longword);
begin
  Log_Writeln(LOG_DEBUG,'gpio_set_ALT: Pin '+Num2Str(pin,0)+' AltFunc '+Num2Str(altfunc,0)); 
  gpio_set_INPUT (pin); 
  gpio_set_register(GPFSEL,pin,gpio_get_Mask(pin,altfunc,gpio_ALT),false,true);
end;

procedure pwm_SetRangeWPi(range1,range2:word);		
begin
  pwm_set_reg(PWMRNG1,range1);  delay_us(10);	
  pwm_set_reg(PWMRNG2,range2);  delay_us(10);	
end;

procedure pwm_SetModeWPi(PWM_MODE_MS:boolean);		
begin
  if PWM_MODE_MS then pwm_set_reg(PWMCTL,PWM0_ENABLE or PWM1_ENABLE or PWM0_MS_MODE or PWM1_MS_MODE)
                 else pwm_set_reg(PWMCTL,PWM0_ENABLE or PWM1_ENABLE);
end;

procedure gpio_set_PINMODE(pin,mode:longword);
//http://wiki.freepascal.org/Lazarus_on_Raspberry_Pi#5._PiGpio_Low-level_native_pascal_unit_.28GPIO_control_instead_of_wiringPi_c_library.29
var alt:byte; regsav:longword; DIVI,DIVF:word;
begin
  Log_Writeln(LOG_DEBUG,'gpio_set_PINMODE: Pin: '+Num2Str(pin,0)+' Mode: '+Num2Str(mode,0)); 
  case mode of
    gpio_INPUT : 		gpio_set_INPUT (pin);
    gpio_OUTPUT: 		gpio_set_OUTPUT(pin); 	
	gpio_PWM_OUTPUT:
	  begin
	    alt:=$ff; 
        case pin of
          12,13,40,41,45 : alt:=0;
          18,19          : alt:=5;
		  52,53          : alt:=1;
        end;
        if alt <> $ff then
        begin
		  DIVI:=32;	DIVF:=0;									// set pwm clock div to 32 (19.2/3 = 600KHz)
		  gpio_set_ALT   (pin,alt);
		  regsav:=clk_get_reg(PWMCLK_CNTL);						// save register content 
//PWMCLK_CNTL: 0x00000200
//PWMCLK_CNTL: 0x00000031
//dann
//PWMCLK_CNTL: 0x00000091
//PWMCLK_CNTL: 0x00000131
writeln('PWMCLK_CNTL: 0x',Hex(regsav,8));
		  clk_set_reg(PWMCLK_CNTL,BCM_PWD or $11 or (1 shl 5));	// stop clock		  
//        delay_us(110);										
          while (clk_get_reg(PWMCLK_CNTL) and $80)<>0 do delay_us(1); // Wait for clock to be !BUSY
writeln('PWMCLK_CNTL: 0x',Hex(clk_get_reg(PWMCLK_CNTL),8));
		  clk_set_reg(PWMCLK_DIV, BCM_PWD or 					// set pwm clock divider
		              (((DIVI and $3ff) shl 12) or 
					    (DIVF and $3ff))
					 );						
          clk_set_reg(PWMCLK_CNTL,BCM_PWD or $11);				// start clock
		  
//		  gpio_set_PIN(pin,false);								// Clear Bit
		  pwm_set_reg(PWMCTL,0);      delay_us(1);				// Disable PWM
		  pwm_SetRangeWPi($400,$400);							// Default range of 1024
		  pwm_set_reg(PWMDAT1,0);	  delay_us(1);				// start value
		  pwm_set_reg(PWMDAT2,0);     delay_us(1);				// start value
		  pwm_SetModeWPi(false);								// Enable PWMs		
        end
        else Log_Writeln(LOG_ERROR,'gpio_set_PINMODE: Pin: '+Num2Str(pin,0)+' Mode: '+Num2Str(mode,0)+' cannot be set to PWM'); 		
	  end;
    else Log_Writeln(LOG_ERROR,'gpio_set_PINMODE: Pin: '+Num2Str(pin,0)+' Mode: '+Num2Str(mode,0)+' mode not defined'); 
  end;
end;

procedure gpio_get_mask_and_idx(pin:longword; var idx,mask:longword);
begin
  idx :=get_regidx(GPLEV,pin);
  mask:=(1 shl (pin mod 32));
end;
  
procedure gpio_set_BIT   (gpioregpart,pin:longword;setbit:boolean); { set or reset pin in gpio register part }
var idx,mask:longword;
begin
  gpio_get_mask_and_idx(pin,idx,mask);
//Writeln('gpio_set_BIT: Pin: '+Num2Str(pin,0)+' level: '+Bool2Str(setbit)+' Reg: 0x'+Hex(gpioregpart,8)+' idx: 0x'+Hex(idx,8)+' mask: 0x'+Hex(mask,8));   
  if setbit then gpio_set_register(gpioregpart,pin,    mask ,false,false)
            else gpio_set_register(gpioregpart,pin,not(mask),true, false);
end;
  
procedure gpio_set_PIN   (pin:longword;highlevel:boolean);
{ Set RPi GPIO pin to high or low level: Speed @ 700MHz ->  1.25MHz }
begin
//Log_Writeln(LOG_DEBUG,'gpio_set_PIN: '+Num2Str(pin,0)+' level '+Bool2Str(highlevel));
//Writeln('gpio_set_PIN: '+Num2Str(pin,0)+' level '+Bool2Str(highlevel));
  if highlevel then gpio_set_BIT(GPSET,pin,true) else gpio_set_BIT(GPCLR,pin,true);
  { sleep(1); }
end;

function  gpio_get_PIN	 (pin,idx,mask:longword):boolean;
begin
  gpio_get_PIN:=((rpi_mmap_gpio_reg_read(idx) and mask)>0);
end;

function  gpio_get_PIN   (pin:longword):boolean;
{ Get RPi GPIO pin Level is true when Pin level is '1'; false when '0'; Speed @ 700MHz ->  2.33MHz }
var {valu,}idx,mask:longword;
begin
  //idx:=get_regidx(GPLEV,pin);
  //valu:=(gpio_get_reg(idx) and (1 shl (pin mod 32)));
  gpio_get_mask_and_idx(pin,idx,mask);
  //valu:=gpio_get_reg(idx) and mask;
  {Log_Writeln(LOG_DEBUG,'gpio_get_PIN: '+Num2Str(pin,0)+' level '+Bool2Str((valu>0))); }
  //gpio_get_PIN:=(valu>0);
  gpio_get_PIN:=gpio_get_PIN(pin,idx,mask);
end;

procedure gpio_set_GPPUD(mask:longword); begin gpio_set_register(GPPUD,0,mask,true,true); end; { set GPIO Pull-up/down Register (GPPUD) } 

procedure gpio_set_PULLUP (pin:longword; enable:boolean); 
begin 
  Log_Writeln(LOG_DEBUG,'gpio_set_PULLUP: Pin '+Num2Str(pin,0)+' '+Bool2Str(enable)); 
  gpio_set_BIT   (GPPUDCLK,pin,enable);
end;
  
procedure gpio_set_edge_rising(pin:longword; enable:boolean);  { Pin RisingEdge  Detection Register (GPREN) }
begin 
  Log_Writeln(LOG_DEBUG,'gpio_set_edge_rising: Pin '+Num2Str(pin,0)+' enable: '+Bool2Str(enable)); 
  gpio_set_BIT(GPREN,pin,enable);   { Pin RisingEdge  Detection }
end;

procedure gpio_set_edge_falling(pin:longword; enable:boolean); { Pin FallingEdge  Detection Register (GPFEN) }
begin 
  Log_Writeln(LOG_DEBUG,'gpio_set_edge_falling: Pin '+Num2Str(pin,0)+' enable: '+Bool2Str(enable)); 
  gpio_set_BIT(GPFEN,pin,enable);  { Pin FallingEdge Detection }
end;

function  gpio_get_reg_desc(idx:longword) : string; begin gpio_get_reg_desc:=(gpio_get_desc(idx,rpi_mmap_gpio_reg_read(idx))); end;

procedure pwm_show_regs;
var idx:longword; 
begin
  writeln('PWMBase  : ',Hex(PWM_BASE_in_Pages,8),'  PageSize: ',PAGE_SIZE,' PWM-Map-ptr:   0x',Hex(longword(mmap_arr_pwm),8));
  for idx:= PWM_BASE to PWM_BASE_LAST  do writeln(pwm_get_desc(idx,rpi_mmap_pwm_reg_read(idx)));
end;

procedure clk_show_regs;
var idx:longword; 
begin
  writeln('CLKBase  : ',Hex(CLK_BASE_in_Pages,8),'  PageSize: ',PAGE_SIZE,' CLK-Map-ptr:   0x',Hex(longword(mmap_arr_clk),8));
  for idx:= PWMCLK_CNTL to PWMCLK_DIV do writeln(pwm_get_desc(idx,rpi_mmap_clk_reg_read(idx)));
end;

procedure gpio_show_regs;
var idx:longword;
begin
  writeln('GPIOBase : ',Hex(GPIO_BASE_in_Pages,8),'  PageSize: ',PAGE_SIZE,' GPIO-Map-ptr:  0x',Hex(longword(mmap_arr_gpio),8));
  for idx:= GPIO_BASE to GPIO_BASE_LAST do writeln(gpio_get_desc(idx,rpi_mmap_gpio_reg_read(idx)));
end;
  
function  gpio_MAP_GPIO_NUM_2_HDR_PIN(pin:longword; mapidx:byte):longint; { Maps GPIO Number to the HDR_PIN, respecting rpi rev1 or rev2 board }
var hwpin,cnt:longint; 
begin
  hwpin:=-99; cnt:=1;
  if ((mapidx=1) or (mapidx<=gpiomax_map_idx_c)) then 
  begin
    while cnt<=gpiomax_c do
	begin
	  if abs(gpio_hdr_map_c[mapidx,cnt])=pin then begin hwpin:=cnt; cnt:=gpiomax_c; end;
	  inc(cnt);
	end;
  end;
  writeln('mapidx',mapidx:0,' HW-PIN: ',hwpin:2,' <- ',pin:2);
  gpio_MAP_GPIO_NUM_2_HDR_PIN:=hwpin;
end;  

function  gpio_MAP_GPIO_NUM_2_HDR_PIN(pin:longword):longint;
begin
  gpio_MAP_GPIO_NUM_2_HDR_PIN:=gpio_MAP_GPIO_NUM_2_HDR_PIN(pin,rpi_gpiomapidx);
end;
  
function  gpio_MAP_HDR_PIN_2_GPIO_NUM(hdr_pin_number:longword; mapidx:byte):longint; { Maps HDR_PIN to the GPIO Number, respecting rpi rev1 or rev2 board }
var gpio_pin:longint;
begin
  if (hdr_pin_number >= 1) and (hdr_pin_number <=gpiomax_c) and ((mapidx>=1) and (mapidx<=gpiomax_map_idx_c)) then gpio_pin:=gpio_hdr_map_c[mapidx,hdr_pin_number] else gpio_pin:=-1;
//writeln('mapidx',mapidx:0,' HW-PIN: ',hdr_pin_number:2,' -> ',gpio_pin:2);
  gpio_MAP_HDR_PIN_2_GPIO_NUM:=gpio_pin;
end;

function  gpio_MAP_HDR_PIN_2_GPIO_NUM(hdr_pin_number:longword):longint;
begin
  gpio_MAP_HDR_PIN_2_GPIO_NUM:=gpio_MAP_HDR_PIN_2_GPIO_NUM(hdr_pin_number,rpi_gpiomapidx);
end;

procedure gpio_set_HDR_PIN(hw_pin_number:longword;highlevel:boolean); { Maps PIN to the GPIO Header, respecting rpi rev1 or rev2 board }
var pin:longint;
begin
  pin:=gpio_MAP_HDR_PIN_2_GPIO_NUM(hw_pin_number,rpi_gpiomapidx);
  if pin>=0 then gpio_set_PIN(longword(pin),highlevel);
end;

function  gpio_get_HDR_PIN(hw_pin_number:longword):boolean; { Maps PIN to the GPIO Header, respecting rpi rev1 or rev2 board }
var pin:longint; lvl:boolean;
begin
  pin:=gpio_MAP_HDR_PIN_2_GPIO_NUM(hw_pin_number,rpi_gpiomapidx);
  if pin>=0 then lvl:=gpio_get_PIN(longword(pin)) else lvl:=false;
  gpio_get_HDR_PIN:=lvl;
end;
  
procedure LED_Status(ein:boolean); begin gpio_set_PIN(rpi_status_led_GPIO,ein); end;

procedure GPIO_PIN_TOGGLE_TEST;
{ just for demo reasons }
const looptimes=5; waittime	= 500; { 1Hz; let Status LED blink, alternate signal level on GPIO pin 16 to +3.3V and 0V }  
var   lw:longword;
begin
//gpio_show_regs;
  writeln('Start of GPIO_PIN_TOGGLE_TEST (Let the Status-LED blink ',looptimes:0,' times)');
  writeln('Set Pin',rpi_status_led_GPIO:0,' to OUTPUT'); gpio_set_OUTPUT(rpi_status_led_GPIO);   writeln(gpio_get_desc(2,rpi_mmap_gpio_reg_read(2)));
  for lw := 1 to looptimes do
  begin
    writeln(looptimes-lw+1:3,'. Set StatusLED (Pin',rpi_status_led_GPIO,') to 1'); LED_Status(true);  sleep(waittime);
	writeln(looptimes-lw+1:3,'. Set StatusLED (Pin',rpi_status_led_GPIO,') to 0'); LED_Status(false); sleep(waittime);
	writeln;
  end;
  writeln('End of GPIO_PIN_TOGGLE_TEST');
end;

procedure rpi_set_testnr  (testnumber:integer); begin testnr:=testnumber; end;

procedure Show_Buffer(var data:databuf_t);
var i : integer;
begin
  if LOG_Level<=LOG_DEBUG then 
  begin
    for i := 1 to data.lgt do LOG_Write(LOG_DEBUG,hex(data.buf[i-1],2)+' '); 
    LOG_writeln(LOG_Debug,'');
  end;
end;

function rtc_func(fkt:longint; fpath:string; var dattime:TDateTime) : longint;
(* uses e.g. /dev/rtc0 *)
var rtc_time:rtc_time_t; rslt:integer; hdl:cint; Y,Mo,D,H,Mi,S,MS : Word;
 function rtc_open(fpath:string) : longint; begin {$IFDEF UNIX}rtc_open:=fpOpen(fpath,O_RdWr); {$ENDIF} end;
begin  
  rslt:=0;
  if Pos('/DEV/RTC',Upper(fpath))=1 then 
  begin  
    {$IFDEF UNIX}
    case fkt of
      RTC_RD_TIME  : begin
                         hdl:= rtc_open(fpath);
                         if hdl < 0    then begin LOG_Writeln(LOG_ERROR,'rtc_func #1 RTC_RD_TIME (Handle: '+Num2Str(hdl,0)+')'); exit(hdl); end
                                       else       LOG_Writeln(LOG_DEBUG,'rtc_func #1 RTC_RD_TIME (Handle: '+Num2Str(hdl,0)+')');
                                     
                         rslt:=fpIOctl(hdl, RTC_RD_TIME, addr(rtc_time));
                         if rslt < 0 then begin LOG_Writeln(LOG_ERROR,'rtc_func #2 RTC_RD_TIME (Handle: '+Num2Str(hdl,0)+')'); fpclose(hdl); exit(rslt); end
                                       else       LOG_Writeln(LOG_DEBUG,'rtc_func #2 RTC_RD_TIME (Handle: '+Num2Str(hdl,0)+')');
                         with rtc_time do
                         begin
                           dattime:=EncodeDateTime(word(tm_year+1900),word(tm_mon+1),word(tm_mday),
                                                   word(tm_hour),     word(tm_min),  word(tm_sec), 0);
                         end;
                         writeln(FormatDateTime('yyyy-mm-dd hh:nn:ss',dattime));
                       end;
        RTC_SET_TIME : begin
                         hdl:= rtc_open(fpath);
                         if hdl < 0    then begin LOG_Writeln(LOG_ERROR,'rtc_func #1 RTC_SET_TIME (Handle: '+Num2Str(hdl,0)+')'); exit(hdl); end
                                       else       LOG_Writeln(LOG_DEBUG,'rtc_func #1 RTC_SET_TIME (Handle: '+Num2Str(hdl,0)+')');
                         with rtc_time do
                         begin
                           DecodeDateTime(dattime,Y,Mo,D,H,Mi,S,MS);
                           tm_year:=Y-1900; tm_mon:=Mo-1; tm_mday:=D; tm_hour:=H; tm_min:=Mi; tm_sec:=S;
                         end;
                         rslt:=fpIOctl(hdl, RTC_SET_TIME, addr(rtc_time));
                         if rslt < 0 then begin LOG_Writeln(LOG_ERROR,'rtc_func #2 RTC_SET_TIME (Handle: '+Num2Str(hdl,0)+')'); fpclose(hdl); exit(rslt); end
                                       else       LOG_Writeln(LOG_DEBUG,'rtc_func #2 RTC_SET_TIME (Handle: '+Num2Str(hdl,0)+')');
                       end;
      else             rslt:=-1;
    end;
    if rslt=0 then fpclose(hdl);
	{$ENDIF}
  end
  else
  begin
    (* not supported here, must be raw i2c access. Implementation later, maybe. *)
    rslt:=-1;
  end;
  rtc_func:=rslt;
end;

procedure show_i2c_struct(var data:databuf_t);
var i :integer;
begin
  with data do
  begin
    Log_Writeln(LOG_DEBUG,'I2C Struct:    0x'+Hex(longword(addr(data)),8)+' struct size: 0x'+Hex(sizeof(data),4));
	Log_Writeln(LOG_DEBUG,' .hdl:           '+Num2Str(hdl,0));
    Log_Writeln(LOG_DEBUG,' .busnum:        '+Num2Str(busnum,0));
    Log_Writeln(LOG_DEBUG,' .lgt:           '+Num2Str(lgt,0));
    Log_Writeln(LOG_DEBUG,' .reg:         0x'+Hex(reg,2));
	Log_Write  (LOG_DEBUG,' .buf:         0x'); for i := 1 to lgt do Log_Write  (LOG_DEBUG,Hex(data.buf[i-1],2)+' '); Log_Writeln(LOG_DEBUG,'');
  end;  
end;

procedure Display_i2c_struct(var data:databuf_t; comment:string);
begin
  LOG_Save_Level; LOG_Set_LEVEL(LOG_DEBUG); Log_Write(LOG_Get_Level,comment); show_i2c_struct(data); LOG_Restore_Level;
end;

procedure i2c_CleanBuffer(busnumber:byte);
var i: longint;
begin
  with i2c_buf[busnumber] do
  begin
    lgt:=0; hdl:=-1; busnum:=busnumber; reg:=0; for i:=0 to c_max_Buffer do buf[i]:=0; 
  end;
end;

procedure i2c_start(var data:databuf_t);
begin
  {$IFDEF UNIX}
    if rpi_run_on_ARM then 
    begin 
      if data.hdl < 0 then data.hdl:=fpOpen('/dev/i2c-'+Num2Str(data.busnum,0),O_RdWr);
    end;
  {$ENDIF}
  if data.hdl < 0 then LOG_Writeln(LOG_ERROR,'i2c_start (busnum: 0x'+hex(data.busnum,2)+' Handle: '+Num2Str(data.hdl,0)+')')
                  else LOG_Writeln(LOG_DEBUG,'i2c_start (busnum: 0x'+hex(data.busnum,2)+' Handle: '+Num2Str(data.hdl,0)+')');
end;

procedure i2c_end(var data:databuf_t);
begin
  {$IFDEF UNIX}
    if rpi_run_on_ARM then 
    begin  
      if data.hdl > 0 then fpClose(data.hdl);
    end;
  {$ENDIF}
  data.hdl:=-1;
end;

procedure i2c_Init;
var i:longint;
begin
  for i := 0 to i2c_max_bus do i2c_CleanBuffer(i); 
end;

procedure i2c_Close_All;
var i:longint;
begin
  for i := 0 to i2c_max_bus do i2c_end(i2c_buf[i]); 
end;

function  i2c_bus_read (baseadr,reg:word; var data:databuf_t; lgt:byte; testnr:integer) : integer;
var rslt:integer;  test:boolean;
begin
  rslt:=-1; test:=false; data.lgt := lgt; data.reg :=byte(reg);
  if data.lgt > SizeOf(data.buf) then 
  begin
    LOG_Writeln(LOG_ERROR,'i2c_bus_read Length to big (Adr:0x'+hex(baseadr,2)+' Reg:0x'+hex(reg,2)+')'+' got: '+Num2Str(data.lgt,0)+' max: '+Num2Str(SizeOf(data.buf),0));
    data.lgt := SizeOf(data.buf);
  end;
  if testnr<>NO_TEST then 
  begin { test, simulate access on i2c bus }
    i2c_Fill_Test_Buffer(data,testnr,baseadr,reg,data.busnum);
	rslt:=0;
  end
  else
  begin { no test }  
    {$IFDEF UNIX}
      if data.hdl < 0 then i2c_start(data);
	  {$warnings off}
//      rslt:=fpIOctl(data.hdl, I2C_TIMEOUT, pointer(1)); if rslt < 0 then exit(rslt); 
//      rslt:=fpIOctl(data.hdl, I2C_RETRIES, pointer(2)); if rslt < 0 then exit(rslt);
        rslt:=fpIOctl(data.hdl, I2C_SLAVE,   pointer(baseadr));
	  {$warnings on}
      if rslt < 0 then
      begin
        LOG_Writeln(LOG_ERROR,'i2c_bus_read Failed to select device (Adr:0x'+hex(baseadr,2)+' Reg:0x'+hex(reg,2)+' Result:'+Num2Str(rslt,0)+')');
        exit(rslt);
      end;
      rslt:=fpWrite (data.hdl,reg,1);
      if rslt <> 1 then
      begin
        LOG_Writeln(LOG_ERROR,'i2c_bus_read Failed to write Register (Adr:0x'+hex(baseadr,2)+' Reg:0x'+hex(reg,2)+' Result:'+Num2Str(rslt,0)+')');
        exit(rslt);
      end;
      rslt:=fpRead(data.hdl,data.buf,data.lgt);
	{$ENDIF}
	if test then Display_i2c_struct(data,'i2c_bus_read:');
    if rslt < 0 then
    begin
      LOG_Writeln(LOG_ERROR,'i2c_bus_read Failed to read device (Adr:0x'+hex(baseadr,2)+' Reg:0x'+hex(reg,2)+' Result:'+Num2Str(rslt,0)+') Hdl: '+Num2Str(data.hdl,0));
    end
    else
    begin
      if rslt = data.lgt then rslt:=0
	  else LOG_Writeln(LOG_ERROR,'i2c_bus_read Short read from device (Adr:0x'+hex(baseadr,2)+' Reg:0x'+hex(reg,2)+' Result:'+Num2Str(rslt,0)+') Hdl: '+Num2Str(data.hdl,0)+' expected: '+Num2Str(data.lgt+1,0)+' got: '+Num2Str(rslt,0));
    end;
  end;  
  i2c_bus_read := rslt;
end;

function i2c_string_read(baseadr,reg:word; lgt:byte; testnr:integer) : string; // read from the i2c general purpose bus e.g. s:=i2c_string_read($68,$00,7,NO_TEST)
var rslt,i:integer; s:string; busnum:byte;
begin   
  s:=''; busnum:=rpi_i2c_busnum(rpi_i2c_general_purpose_bus_c); 
  if lgt > SizeOf(i2c_buf[busnum].buf) then 
  begin
    LOG_Writeln(LOG_ERROR,'i2c_string_read Data Length to big: '+Num2Str(lgt,0)+' max cnt: '+Num2Str(SizeOf(i2c_buf[busnum].buf),0));
    i2c_buf[busnum].lgt := SizeOf(i2c_buf[busnum].buf);
  end;
  rslt:=i2c_bus_read(baseadr, reg, i2c_buf[busnum], lgt, testnr);  
  if rslt>=0 then for i := 1 to lgt do s:=s+char(i2c_buf[busnum].buf[i-1]); 
  i2c_string_read:=s;
end;

function  i2c_bus_write(baseadr,reg:word; var data:databuf_t; lgt:byte; testnr:integer) : integer;
var rslt:integer; test:boolean;
begin
  rslt:=-1; test:=false;
  data.lgt := lgt; 
  if data.lgt > SizeOf(data.buf) then 
  begin
    LOG_Writeln(LOG_ERROR,'i2c_bus_write Data Length to big: '+Num2Str(data.lgt,0)+' max cnt: '+Num2Str(SizeOf(data.buf),0));
    exit(-1);
    data.lgt := SizeOf(data.buf);
  end;	
  data.reg :=byte(reg);
  {$IFDEF UNIX}
    if data.hdl < 0 then i2c_start(data);
    {$warnings off} rslt:=fpIOctl(data.hdl, I2C_SLAVE,   pointer(baseadr)); {$warnings on}
    if rslt < 0 then
    begin
      LOG_Writeln(LOG_ERROR,'i2c_bus_write Failed to open device (Adr:0x'+hex(baseadr,2)+' Reg:0x'+hex(reg,2)+' Result:'+Num2Str(rslt,0)+') Hdl: '+Num2Str(data.hdl,0));
      exit(rslt);
    end;
    rslt:=fpWrite (data.hdl,data.reg,data.lgt+1);
  {$ENDIF}
  if test then Display_i2c_struct(data,'i2c_bus_write:');
  if rslt < 0 then
  begin
    LOG_Writeln(LOG_ERROR,'i2c_bus_write Failed to write to device (Adr:0x'+hex(baseadr,2)+' Reg:0x'+hex(reg,2)+' Result:'+Num2Str(rslt,0)+') Hdl: '+Num2Str(data.hdl,0));
  end
  else
  begin
    if rslt = data.lgt+1 then rslt:=0
	else LOG_Writeln(LOG_ERROR,'i2c_bus_write Short write to device (Adr:0x'+hex(baseadr,2)+' Reg:0x'+hex(reg,2)+' Result:'+Num2Str(rslt,0)+') Hdl: '+Num2Str(data.hdl,0)+' expected: '+Num2Str(data.lgt+1,0)+' got: '+Num2Str(rslt,0));
  end;
//if rslt=0 then Log_Writeln(LOG_INFO, 'i2c_bus_write(Adr:0x'+hex(baseadr,2)+' Reg:0x'+hex(reg,2)+' Lgt:0x'+hex(data.lgt,2)+')') 
//            else Log_Writeln(LOG_ERROR,'i2c_bus_write(Adr:0x'+hex(baseadr,2)+' Reg:0x'+hex(reg,2)+' Lgt:0x'+hex(data.lgt,2)+')'); 
  i2c_bus_write := rslt;
end;

function  i2c_string_write(baseadr,reg:word; s:string; testnr:integer) : integer; // write to the  i2c general purpose bus e.g.    i2c_string_write($68,$00,#$01+#$02+#$03)
var i:integer; busnum:byte;
begin   
  busnum:=rpi_i2c_busnum(rpi_i2c_general_purpose_bus_c);
  if length(s) > SizeOf(i2c_buf[busnum].buf) then 
  begin
    LOG_Writeln(LOG_ERROR,'i2c_string_write Data Length to big: '+Num2Str(length(s),0)+' max cnt: '+Num2Str(SizeOf(i2c_buf[busnum].buf),0));
    exit(-1);
    i2c_buf[busnum].lgt := SizeOf(i2c_buf[busnum].buf);
  end;	 
  i2c_buf[busnum].reg :=byte(reg); i2c_buf[busnum].lgt := length(s); if i2c_buf[busnum].lgt > SizeOf(i2c_buf[busnum].buf) then i2c_buf[busnum].lgt := SizeOf(i2c_buf[busnum].buf);
  for i:= 1 to i2c_buf[busnum].lgt do i2c_buf[busnum].buf[i-1]:=ord(s[i]);
  i2c_string_write:=i2c_bus_write(baseadr,reg,i2c_buf[busnum],i2c_buf[busnum].lgt, testnr); 
end;

procedure i2c_test;
{ V1.0 30-JUL-2013 }
{ test on cli, is i2c bus working and determine baseaddr of device. Newer version of rpi, i2c bus nr 1. older rpi i2cbus nr 0.
root@rpi# i2cdetect -y 0

root@rpi# i2cdetect -y 1        
     0  1  2  3  4  5  6  7  8  9  a  b  c  d  e  f
00:          -- -- -- -- -- -- -- -- -- -- -- -- --
10: -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --
20: -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --
30: -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --
40: -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --
50: -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --
60: -- -- -- -- -- -- -- -- 68 -- -- -- -- -- -- --
70: -- -- -- -- -- -- -- --
on 0x68, this is my RTC DS3232m
}
  procedure showstr(s:string); begin if s<>'' then writeln(hexstr(s)) else writeln('device is not responding'); end;
var s:string;
begin
  s:=i2c_string_read($68,$05,2,NO_TEST); showstr(s); // read 2 bytes; i2c device addr = 0x68; StartRegister = 0x05; result: content of reg[5..6] in string s
  
  i2c_string_write($68,$05,#$08+#$12,NO_TEST); // write 08 in reg 0x05 and 12 in reg 0x06 // set month register to 08 and year to 12
  
  s:=i2c_string_read($68,$05,2,NO_TEST); showstr(s); // read 2 bytes
  
  i2c_string_write($68,$05,#$07+#$13,NO_TEST); // write 07 in reg 0x05 and 13 in reg 0x06 // restore month and year
  
  LOG_Level:=LOG_debug; show_i2c_struct(i2c_buf[rpi_i2c_busnum(rpi_i2c_general_purpose_bus_c)]); LOG_Level:=LOG_WARNING;
end;

procedure show_spi_struct(var spi_strct:spi_ioc_transfer_t);
begin
  with spi_strct do
  begin
    Log_Writeln(LOG_DEBUG,'SPI Struct:    0x'+Hex(longword(addr(spi_strct)),8)+' struct size: 0x'+Hex(sizeof(spi_strct),4));
    Log_Writeln(LOG_DEBUG,' .tx_buf_ptr:  0x'+Hex(tx_buf_ptr,8));
    Log_Writeln(LOG_DEBUG,' .rx_buf_ptr:  0x'+Hex(rx_buf_ptr,8));
    Log_Writeln(LOG_DEBUG,' .len:           '+Num2Str(len,0));
    Log_Writeln(LOG_DEBUG,' .speed_hz:      '+Num2Str(speed_hz,0));
    Log_Writeln(LOG_DEBUG,' .delay_usecs:   '+Num2Str(delay_usecs,0));
    Log_Writeln(LOG_DEBUG,' .bits_per_word: '+Num2Str(bits_per_word,0));
  end;  
end;

procedure show_spi_bus_info_struct(var spi_bus_info_strct:SPI_Bus_Info_t; busnum:byte);
begin
  with spi_bus_info_strct do
  begin
    Log_Writeln(LOG_DEBUG,'SPI Bus Info:  0x'+Hex(longword(addr(spi_bus_info_strct)),8)+' struct size: 0x'+Hex(sizeof(spi_bus_info_strct),4)+' idx:'+Num2Str(busnum,0));
	Log_Writeln(LOG_DEBUG,' .spi_busnum:    '+Num2Str(spi_busnum,0));
    Log_Writeln(LOG_DEBUG,' .spi_path:      '+spi_path);
    Log_Writeln(LOG_DEBUG,' .spi_fd:        '+Num2Str(spi_fd,0));
    Log_Writeln(LOG_DEBUG,' .spi_opened:    '+Bool2Str(spi_opened));
  end;
end;

procedure show_spi_dev_info_struct(var spi_dev_info_strct:SPI_Device_Info_t; devnum:byte);
begin
  with spi_dev_info_strct do
  begin
    Log_Writeln(LOG_DEBUG,'SPI Dev Info:  0x'+Hex(longword(addr(spi_dev_info_strct)),8)+' struct size: 0x'+Hex(sizeof(spi_dev_info_strct),4)+' idx:'+Num2Str(devnum,0));
	Log_Writeln(LOG_DEBUG,' .spi_busnum:    '+Num2Str(spi_busnum,0));
    Log_Writeln(LOG_DEBUG,' .spi_bpw:       '+Num2Str(spi_bpw,0));
    Log_Writeln(LOG_DEBUG,' .spi_delay:     '+Num2Str(spi_delay,0));
    Log_Writeln(LOG_DEBUG,' .spi_speed:     '+Num2Str(spi_speed,0)+' 0x'+Hex(spi_speed,8));
    Log_Writeln(LOG_DEBUG,' .spi_LSB_FIRST: '+Num2Str(spi_LSB_FIRST,0));
    Log_Writeln(LOG_DEBUG,' .spi_mode:      '+Num2Str(spi_mode,0));
    Log_Writeln(LOG_DEBUG,' .spi_IOC_mode:0x'+Hex(spi_IOC_mode,8));
 //   Log_Writeln(LOG_DEBUG,' .dev_gpio_int:  '+Num2Str(dev_gpio_int,0));
    Log_Writeln(LOG_DEBUG,' .dev_gpio_en:   '+Num2Str(dev_gpio_en,0));
	Log_Writeln(LOG_DEBUG,' .dev_gpio_ook:  '+Num2Str(dev_gpio_ook,0));
 end;
end; 

procedure show_spi_buffer(var spi_buff:spi_databuf_t);
const maxbuf=10;
var i,s,e:longint;
begin
  with spi_buff do
  begin
    s:=posidx; e:=endidx; if e>maxbuf then e:=maxbuf; 
    Log_Writeln(LOG_DEBUG,'SPI Buffer:    0x'+Hex(longword(addr(spi_buff)),8)+' struct size: 0x'+Hex(sizeof(spi_buff),4));
    Log_Writeln(LOG_DEBUG,' .reg:         0x'+Hex(reg,4));
    if s<=e then
    begin
      Log_Write  (LOG_DEBUG,' .buf[0..'+Num2Str(e,2)+']:  0x'); 
      for i:= s to e do Log_Write  (LOG_DEBUG,Hex(buf[i],2)+' '); 
      Log_Write  (LOG_DEBUG,'... ');                                                              
      for i:= s to e do Log_Write   (LOG_DEBUG,StringPrintable(char(buf[i])));
      Log_Writeln(LOG_DEBUG,'');
    end
    else
    begin
      Log_Writeln(LOG_DEBUG,' .buf:           <empty>');
    end;
    Log_Writeln(LOG_DEBUG,' .posidx:        '+Num2Str(posidx,0));
    Log_Writeln(LOG_DEBUG,' .endidx:        '+Num2Str(endidx,0));
  end;
end;

function  _IOC(dir:byte; typ:char; nr,size:word):longword;
{ source http://www.cs.fsu.edu/~baker/devices/lxr/http/source/linux/include/asm-i386/ioctl.h?v=2.6.11.8
         http://lkml.indiana.edu/hypermail/linux/kernel/0108.2/0125.html
		  |dd|ssssssssssssss|tttttttt|nnnnnnnn| 
}
begin
  _ioc:=(dir      shl _IOC_DIRSHIFT)  or
        (ord(typ) shl _IOC_TYPESHIFT) or
        (nr       shl _IOC_NRSHIFT)   or
        (size     shl _IOC_SIZESHIFT); 
end;

function SPI_MSGSIZE(n:byte):word; 
var siz:word;
begin 
  if n*SizeOf(spi_ioc_transfer_t) < (1 shl _IOC_SIZEBITS) then siz:=n*SizeOf(spi_ioc_transfer_t) else siz:=0;
  SPI_MSGSIZE:=siz;
end; 

function  _IO  (typ:char; nr:word):longword;      begin _IO  :=_IOC(_IOC_NONE,                typ,nr,0);         end;
function  _IOR (typ:char; nr,size:word):longword; begin _IOR :=_IOC(_IOC_Read,                typ,nr,size);      end;
function  _IOW (typ:char; nr,size:word):longword; begin _IOW :=_IOC(_IOC_Write,               typ,nr,size);      end;
function  _IOWR(typ:char; nr,size:word):longword; begin _IOWR:=_IOC((_IOC_Write or _IOC_Read),typ,nr,size);      end;
function  SPI_IOC_MESSAGE(n:byte):longword;       begin SPI_IOC_MESSAGE:=_IOW(SPI_IOC_MAGIC, 0, SPI_MSGSIZE(n)); end;

procedure SPI_SetMode(devnum:byte);
var m:integer;
begin
  if spi_bus[spi_dev[devnum].spi_busnum].spi_opened then
  begin
    Log_Writeln(LOG_DEBUG,'SPI_SetMode DevNum: '+Num2Str(devnum,0));
    {$IFDEF UNIX}
      m:=fpioctl(spi_bus[spi_dev[devnum].spi_busnum].spi_fd, SPI_IOC_WR_MODE,          addr(spi_dev[devnum].spi_mode));      if m < 0 then Log_Writeln(LOG_ERROR,'SPI_SetMode fpioctl #1 Mode: 0x'+Hex(SPI_IOC_WR_MODE,8)+' devnum: 0x'+Hex(devnum,2)+' err:'+Num2Str(m,0));
//    m:=fpioctl(spi_bus[spi_dev[devnum].spi_busnum].spi_fd, SPI_IOC_WR_LSB_FIRST,     addr(spi_dev[devnum].spi_LSB_FIRST)); if m < 0 then Log_Writeln(LOG_ERROR,'SPI_SetMode fpioctl #2 Mode: 0x'+Hex(SPI_IOC_WR_LSB_FIRST,8)+' devnum: 0x'+Hex(devnum,2)+' err:'+Num2Str(m,0));
//    m:=fpioctl(spi_bus[spi_dev[devnum].spi_busnum].spi_fd, SPI_IOC_WR_BITS_PER_WORD, addr(spi_dev[devnum].spi_bpw));       if m < 0 then Log_Writeln(LOG_ERROR,'SPI_SetMode fpioctl #3 Mode: 0x'+Hex(SPI_IOC_WR_BITS_PER_WORD,8)+' devnum: 0x'+Hex(devnum,2)+' err:'+Num2Str(m,0));
	  m:=fpioctl(spi_bus[spi_dev[devnum].spi_busnum].spi_fd, SPI_IOC_WR_MAX_SPEED_HZ,  addr(spi_dev[devnum].spi_speed));     if m < 0 then Log_Writeln(LOG_ERROR,'SPI_SetMode fpioctl #4 Mode: 0x'+Hex(SPI_IOC_WR_MAX_SPEED_HZ,8)+' devnum: 0x'+Hex(devnum,2)+' err:'+Num2Str(m,0));
    {$ENDIF}
  end;
//show_spi_dev_info_struct(spi_dev[devnum], devnum);
end;

function SPI_BurstRead(devnum:byte) : byte;
{ get byte from Buffer. Buffer was filled before with procedure SPI_BurstRead2Buffer }
var b:byte;
begin
  b:=$ff;
  if spi_buf[devnum].posidx <= spi_buf[devnum].endidx then 
  begin
    b:=spi_buf[devnum].buf[spi_buf[devnum].posidx];
  end;
  inc(spi_buf[devnum].posidx);
  SPI_BurstRead:=b;
end;

procedure SPI_Struct_Init(var spi_struct:spi_ioc_transfer_t; devnum:byte; rx_bufptr,tx_bufptr:pointer; xferlen:longword);
var xlen:longword;
begin
//  Log_Writeln(LOG_DEBUG,'SPI_Struct_Init');
  xlen:=xferlen; if xlen>SPI_BUF_SIZE_c+1 then xlen:=SPI_BUF_SIZE_c+1;
  with spi_struct do
  begin
    {$warnings off}
      rx_buf_ptr	:= qword(rx_bufptr);
      tx_buf_ptr	:= qword(tx_bufptr);
	{$warnings on}
    len				:= xlen;
    delay_usecs		:= spi_dev[devnum].spi_delay;
    speed_hz    	:= spi_dev[devnum].spi_speed;
    bits_per_word	:= spi_dev[devnum].spi_bpw;
    cs_change		:= 0;
    pad				:= 0;
  end;
  { for i := 0 to spi_max_buf do spi_buf[devnum].buf[i]:=$ff; }
  spi_buf[devnum].endidx:=0;
  spi_buf[devnum].posidx:=spi_buf[devnum].endidx+1;
end;

procedure SPI_Init_Const;
begin
  SPI_IOC_RD_MODE :=          _IOR (SPI_IOC_MAGIC, 1, 1);
  SPI_IOC_WR_MODE :=          _IOW (SPI_IOC_MAGIC, 1, 1);
  SPI_IOC_RD_LSB_FIRST :=     _IOR (SPI_IOC_MAGIC, 2, 1);
  SPI_IOC_WR_LSB_FIRST :=     _IOW (SPI_IOC_MAGIC, 2, 1);
  SPI_IOC_RD_BITS_PER_WORD := _IOR (SPI_IOC_MAGIC, 3, 1);
  SPI_IOC_WR_BITS_PER_WORD := _IOW (SPI_IOC_MAGIC, 3, 1);
  SPI_IOC_RD_MAX_SPEED_HZ  := _IOR (SPI_IOC_MAGIC, 4, 4);
  SPI_IOC_WR_MAX_SPEED_HZ  := _IOW (SPI_IOC_MAGIC, 4, 4);
end;

function  SPI_Transfer(devnum:byte; cmdseq:string):integer;
var rslt,i,xlen:integer; xfer : spi_ioc_transfer_t;
begin
  rslt:=-1;
  xlen:=Length(cmdseq); if xlen > SPI_BUF_SIZE_c then begin xlen := SPI_BUF_SIZE_c; LOG_WRITELN(LOG_ERROR,'spi_transfer: transfer length to long'); end;
  for i:= 1 to xlen do spi_buf[devnum].buf[i-1]:=ord(cmdseq[i]);
  SPI_Struct_Init(xfer,devnum,addr(spi_buf[devnum].buf),addr(spi_buf[devnum].buf),xlen);  
  {$IFDEF UNIX} 
    rslt := fpioctl(spi_bus[spi_dev[devnum].spi_busnum].spi_fd, SPI_IOC_MESSAGE(1), addr(xfer)); 
  {$ENDIF}
  if rslt < 0 then Log_Writeln(LOG_ERROR,'SPI_transfer '+Num2Str(rslt,0)+
                                           ' devnum: ' +Num2Str(devnum,0)+
                                           ' spi_busnum: '+Num2Str(spi_dev[devnum].spi_busnum,0)+   
                                           ' spi_fd: '+    Num2Str(spi_bus[spi_dev[devnum].spi_busnum].spi_fd,0)+
										   ' cmdseq: '+HexStr(cmdseq));
  SPI_Transfer:=rslt;
end;

procedure XSPI_Write(devnum:byte; reg,data:word);
var rslt:integer; 
begin
  rslt:=spi_transfer(devnum, char(byte(reg or $80))+char(byte(data))); 
  if rslt < 0 then Log_Writeln(LOG_ERROR,'SPI_write Reg: 0x'+Hex(reg,4)+' Data: 0x'+Hex(data,4)+' result '+Num2Str(rslt,0));
end;

function XSPI_Read(devnum:byte; reg:word) : byte;
var b:byte; 
begin
  if spi_transfer(devnum, char(byte(reg))) < 0 then begin b:=$ff;                    {Log_Writeln(LOG_ERROR,'SPI_read Reg: 0x'+Hex(reg,4)+' result: '+Num2Str(rslt,0));} end
                                               else begin b:=spi_buf[devnum].buf[0]; {Log_Writeln(LOG_DEBUG,'SPI_read Reg: 0x'+Hex(reg,4)+' Data: 0x'+Hex(b,2));} end; 
  XSPI_Read:=b;
end;

procedure SPI_Write(devnum:byte; reg,data:word);
var rslt:integer; xfer : spi_ioc_transfer_t; buf : array[0..1] of byte;
begin
  rslt:=-1; 
//  Log_Writeln(LOG_DEBUG,'SPI_write Reg: 0x'+Hex(reg,4)+' Data: 0x'+Hex(data,4));
  SPI_Struct_Init(xfer,devnum,addr(buf),addr(buf),2);
  buf[0]:=byte(reg or $80); buf[1]:=byte(data);
  SPI_SetMode(devnum);  
  {$IFDEF UNIX} 
    rslt := fpioctl(spi_bus[spi_dev[devnum].spi_busnum].spi_fd, SPI_IOC_MESSAGE(1), addr(xfer)); 
  {$ENDIF}
  if rslt<0 then ;
{ if rslt < 0 then Log_Writeln(LOG_ERROR,'SPI_write '+Num2Str(rslt,0)+
                                           ' devnum: ' +Num2Str(devnum,0)+
                                           ' spi_busnum: '+Num2Str(spi_dev[devnum].spi_busnum,0)+   
                                           ' spi_fd: '+    Num2Str(spi_bus[spi_dev[devnum].spi_busnum].spi_fd,0));}
end;

function SPI_Read(devnum:byte; reg:word) : byte;
var b:byte; rslt:integer; xfer : array[0..1] of spi_ioc_transfer_t; buf : array[0..1] of byte;
begin
  rslt:=-1;
  b:=$ff;
  SPI_Struct_Init(xfer[0],devnum,addr(buf),addr(buf),1);
  SPI_Struct_Init(xfer[1],devnum,addr(buf),addr(buf),1);
  buf[0]:=byte(reg); 
  SPI_SetMode(devnum);  
  {$IFDEF UNIX} 
    rslt := fpioctl(spi_bus[spi_dev[devnum].spi_busnum].spi_fd, SPI_IOC_MESSAGE(2), addr(xfer)); 
  {$ENDIF}
  if rslt < 0 then begin             {Log_Writeln(LOG_ERROR,'SPI_read Reg: 0x'+Hex(reg,4)+' rslt: '+Num2Str(rslt,0));} end
                else begin b:= buf[0]; {Log_Writeln(LOG_DEBUG,'SPI_read Reg: 0x'+Hex(reg,4)+' Data: 0x'+Hex(b,2));} end;
  SPI_Read:=b;
end;

procedure SPI_BurstRead2Buffer (devnum,start_reg:byte; xferlen:longword);
{ full duplex, see example spidev_fdx.c}
var rslt:integer; xfer : array[0..1] of spi_ioc_transfer_t;
begin
//  Log_Writeln(LOG_DEBUG,'SPI_BurstRead2Buffer devnum:0x'+Hex(devnum,4)+' reg:0x'+Hex(start_reg,4)+' xferlen:0x'+Hex(xferlen,8));
  rslt:=-1;
  if spi_buf[devnum].posidx > spi_buf[devnum].endidx then
  begin
    SPI_Struct_Init(xfer[0],devnum,addr(spi_buf[devnum].buf),addr(spi_buf[devnum].buf),1);
	SPI_Struct_Init(xfer[1],devnum,addr(spi_buf[devnum].buf),addr(spi_buf[devnum].buf),xferlen);
    spi_buf[devnum].buf[0]:=start_reg; spi_buf[devnum].reg:=start_reg;
	
    SPI_SetMode(devnum);

 	(* if LOG_GetLogLevel<=LOG_DEBUG then show_spi_struct(xfer[0]);
	if LOG_GetLogLevel<=LOG_DEBUG then show_spi_struct(xfer[1]);
 	if LOG_GetLogLevel<=LOG_DEBUG then show_spi_dev_info_struct(spi_dev[devnum]);
 	if LOG_GetLogLevel<=LOG_DEBUG then show_spi_struct(rfm22_stat[devnum]); *)

//    Log_Writeln(LOG_DEBUG,'fpioctl('+Num2Str(spi_bus[spi_dev[devnum].spi_busnum].spi_fd,0)+', 0x'+Hex(SPI_IOC_MESSAGE(2),8)+', 0x'+Hex(longword(addr(xfer)),8)+')'); 
    {$IFDEF UNIX}
	  rslt := fpioctl(spi_bus[spi_dev[devnum].spi_busnum].spi_fd, SPI_IOC_MESSAGE(2), addr(xfer)); { full duplex }
    {$ENDIF} 
    if rslt < 0 then 
	begin
//	  Log_Writeln(LOG_ERROR,'SPI_BurstRead2Buffer fpioctl result: '+Num2Str(rslt,0));
      spi_buf[devnum].endidx:=0;
      spi_buf[devnum].posidx:=spi_buf[devnum].endidx+1;
	end
	else
	begin
      (* system.writeln('###'+num2str(rslt,0)); *)
      spi_buf[devnum].endidx:=rslt-1-1; (* -2: -1 because fpioctl delivers total transfered bytes, WriteByte(AdrReg) + ReadBytes(xlen) // -1 [0..xlen-1] *)
      spi_buf[devnum].posidx:=0;
	end;
//	if LOG_Get_Level<=LOG_DEBUG then show_spi_buffer(spi_buf[devnum]);
	(* if LOG_GetLogLevel<=LOG_DEBUG then show_spi_struct(rfm22_stat[devnum]); *)
  end;
//  Log_Writeln(LOG_DEBUG,'SPI_BurstRead2Buffer (end)');
end;

procedure SPI_BurstWriteBuffer (devnum,start_reg:byte; xferlen:longword);  { Write 'len' Bytes from Buffer SPI Dev startig at address 'reg'  }
var rslt:integer; xfer : spi_ioc_transfer_t;
begin
//  Log_Writeln(LOG_DEBUG,'SPI_BurstWriteBuffer devnum:0x'+Hex(devnum,4)+' reg:0x'+Hex(start_reg,4)+' xferlen:0x'+Hex(xferlen,8));
  rslt:=-1;
  if xferlen>0 then
  begin
    SPI_Struct_Init(xfer,devnum,addr(spi_buf[devnum].buf),addr(spi_buf[devnum].reg),xferlen+1); { +1 Byte, because send reg-content also. transfer starts at addr(spi_buf[devnum].reg) }
    spi_buf[devnum].reg:=start_reg or $80;
    SPI_SetMode(devnum);
// 	if LOG_Get_Level<=LOG_DEBUG then show_spi_struct(xfer);
// 	if LOG_Get_Level<=LOG_DEBUG then show_spi_dev_info_struct(spi_dev[devnum],devnum);
// 	if LOG_Get_Level<=LOG_DEBUG then show_spi_buffer(spi_buf[devnum]);
// 	if LOG_Get_Level<=LOG_DEBUG then Log_Writeln(LOG_DEBUG,'fpioctl('+Num2Str(spi_bus[spi_dev[devnum].spi_busnum].spi_fd,0)+', 0x'+Hex(SPI_IOC_MESSAGE(1),8)+', 0x'+Hex(longword(addr(xfer)),8)+')'); 
	{$IFDEF UNIX}
	  rslt := fpioctl(spi_bus[spi_dev[devnum].spi_busnum].spi_fd, SPI_IOC_MESSAGE(1), addr(xfer)); 
	{$ENDIF}
    if rslt < 0 then begin Log_Writeln(LOG_ERROR,'SPI_BurstWriteBuffer fpioctl result: '+Num2Str(rslt,0)); end
	              else begin inc(spi_buf[devnum].posidx,rslt-1);  {rslt-1 wg. reg + buffer content } end;
//	if LOG_Get_Level<=LOG_DEBUG then show_spi_buffer(spi_buf[devnum]);
  end;
end;

procedure SPI_StartBurst(devnum:byte; reg:word; writeing:byte; len:longint);
begin
//  Log_Writeln(LOG_DEBUG,'StartBurst StartReg: 0x'+Hex(reg,4)+' writing: '+Bool2Str(writeing<>0));
  if spi_bus[spi_dev[devnum].spi_busnum].spi_opened then 
  begin
    SPI_SetMode(devnum);
	spi_buf[devnum].reg:=byte(reg);
    if writeing=1 then 
	begin
	  spi_buf[devnum].endidx:=len-1; spi_buf[devnum].posidx:=0; 
	  SPI_BurstWriteBuffer (devnum,reg,len); { Write 'len' Bytes from Buffer to SPI Dev startig at address 'reg'  }
	  if ((reg and $7f) = $7f) then SPI_write(devnum, $3e,word(len)); { set packet length for TX FIFO }
    end
	else 
	begin
	  spi_buf[devnum].endidx:=0; spi_buf[devnum].posidx:=spi_buf[devnum].endidx+1;  { initiate BurstRead2Buffer }
	  SPI_BurstRead2Buffer (devnum,reg,len);  { Read 'len' Bytes from SPI Dev to Buffer }
	  { inc(spi_buf[devnum].posidx);  1. Byte in Read Buffer is startregister -> position to 1. register content }
	end;
  end;
end;

procedure SPI_EndBurst(devnum:byte);
begin
//  Log_Writeln(LOG_DEBUG,'SPI_EndBurst');
  spi_buf[devnum].endidx:=0; spi_buf[devnum].posidx:=spi_buf[devnum].endidx+1; { initiate BurstRead2Buffer }
end;

procedure SPI_Dev_Init(devnum:byte);
begin
  Log_Writeln(LOG_DEBUG,  'SPI_Dev_Init devnum: '+Num2Str(devnum,0));
  with spi_dev[devnum] do 
  begin 
    spi_busnum		:= devnum;
	spi_LSB_FIRST	:= 0;
	spi_bpw			:= 8;
    spi_delay		:= 5;
	spi_speed		:= 1000000;
    spi_mode		:= SPI_MODE_0;
	spi_IOC_mode	:= SPI_IOC_RD_MODE;
    isr_enable		:= false;
	isr.gpio		:= -1;
  end;
  show_spi_dev_info_struct(spi_dev[devnum], devnum);
end;

procedure SPI_Bus_Init(busnum:byte);
begin
  Log_Writeln(LOG_DEBUG,  'SPI_Bus_Init busnum: '+Num2Str(busnum,0));
  with spi_bus[busnum] do 
  begin 
    spi_dev[busnum+1].spi_busnum:=spi_busnum;
    spi_busnum := busnum; spi_fd:=-1; spi_opened:=false;
//	spi_path:=BIOS_Get_Ini_String('DEVICE','SPI_0_'+Num2Str(busnum,0)+'_PATH',false);
	if spi_path = '' then spi_path:='/dev/spidev0.'+Num2Str(busnum,0);
	if spi_path <>'' then
    begin
	  {$IFDEF UNIX} spi_fd:=fpOpen(spi_path,O_RdWr); {$ENDIF}
    end;
	if spi_fd < 0 then Log_Writeln(LOG_ERROR,'SPI_Bus_Init fpopen path: '+spi_path+' busnum: '+Num2Str(busnum,0)) else spi_opened:=true;
	if LOG_Get_Level<=LOG_DEBUG then show_spi_bus_info_struct(spi_bus[busnum],busnum);
  end;
  if spi_bus[busnum].spi_opened then 
  begin
	SPI_SetMode(busnum+1);  // on SPI Bus 0, device 1 is connected !!
  end;
end;

procedure SPI_Bus_Close(busnum:byte);
begin
  with spi_bus[busnum] do 
  begin 
    {$IFDEF UNIX} if spi_opened then fpclose(spi_fd); {$ENDIF}
    spi_busnum := busnum; spi_fd:=0; spi_opened:=false; spi_path:='';
  end;
end;

procedure SPI_DEV_INIT_All;	 var i:integer; begin for i := 0 to spi_max_dev do SPI_Dev_Init(i);  end;
procedure SPI_Bus_Init_All;  var i:integer; begin for i := 0 to spi_max_bus do SPI_Bus_Init(i);  end;
procedure SPI_Bus_Close_All; var i:integer; begin for i := 0 to spi_max_bus do SPI_Bus_Close(i); end;

procedure rfm22B_ShowChipType;
(* just to test SPI Read Function. Installed RFM22B Module on piggy back board is required!! *)
const RF22_REG_01_VERSION_CODE = $01; devnum=1;
  function  GDVC(b:byte):string;
  var t:string;
  begin
    t:='RFM_UNKNOWN';
    case (b and $1f) of
      $01 : t:='SIxxx_X4';
      $02 : t:='SI4432_V2';
      $03 : t:='SIxxx_A0';
	  $04 : t:='SI4431_A0';
	  $05 : t:='SI443x_B0';
      $06 : t:='SI443x_B1';
      else  t:='RFM_UNKNOWN';
    end;
    GDVC:='0x'+Hex(b,2)+' '+t;
  end;
begin
  writeln('Chip-Type: '+GDVC(SPI_Read(devnum, RF22_REG_01_VERSION_CODE))+' (correct answer should be 0x06)');  
end;

procedure Test_SPI; begin rfm22B_ShowChipType; end;

function rpi_snr :string;  		begin rpi_snr :=cpu_snr;  end;
function rpi_hw  :string;  		begin rpi_hw  :=cpu_hw;   end;
function rpi_proc:string;  		begin rpi_proc:=cpu_proc; end;
function rpi_mips:string;  		begin rpi_mips:=cpu_mips; end;
function rpi_feat:string;  		begin rpi_feat:=cpu_feat; end;
function rpi_rev :string;  		begin rpi_rev :=cpu_rev; end;
function rpi_revnum:byte;  		begin rpi_revnum:=cpu_rev_num; end;
function rpi_gpiomapidx:byte;  	begin rpi_gpiomapidx:=gpio_map_idx; end;
function rpi_freq :string; 		begin rpi_freq :=cpu_fmin+';'+cpu_fcur+';'+cpu_fmax+';Hz'; end;

function rpi_i2c_busnum(func:byte):byte; { get the i2c busnumber, where e.g. the geneneral purpose devices are connected. This depends on rev1 or rev2 board . e.g. rpi_i2c_busnum(rpi_i2c_general_purpose_bus_c) }
var b:byte;
begin
  b:=1; if func<>rpi_i2c_general_purpose_bus_c then b:=0; { default rev2 board }
  case rpi_revnum of 
     1 : begin b:=0; if func<>rpi_i2c_general_purpose_bus_c then b:=1; end;
	 2 : begin b:=1; if func<>rpi_i2c_general_purpose_bus_c then b:=0; end;
  end;
  rpi_i2c_busnum:=b;
end;

procedure rpi_show_cpu_info;
begin
  writeln('rpi Snr  : ',rpi_snr);
  writeln('rpi HW   : ',rpi_hw);
  writeln('rpi proc : ',rpi_proc);
  writeln('rpi rev  : ',rpi_rev);
  writeln('rpi mips : ',rpi_mips);
  writeln('rpi Freq : ',rpi_freq);
end;

procedure rpi_show_all_info;
begin
  rpi_show_cpu_info; 	writeln;
  gpio_show_regs;		writeln;
  pwm_show_regs;		writeln;
  clk_show_regs;
end;

procedure gpio_create_int_script(filn:string);
{ just for convenience }
const logfil_c='/tmp/gpio_script.log';
var ts:TStringlist; fil:text; 
begin
  {$I-} 
    assign (fil,filn); rewrite(fil);
    writeln(fil,'#!/bin/bash');
	writeln(fil,'# script was automatically created. Do not edit');
	writeln(fil,'# usage e.g.:');
	writeln(fil,'# usage e.g.: '+filn+' 22 in rising');
	writeln(fil,'# usage e.g.: '+filn+' 22 stop');
	writeln(fil,'#');
	writeln(fil,'logf='+logfil_c);
	writeln(fil,'path='+gpio_path_c);
	writeln(fil,'gpionum=$1');
	writeln(fil,'direction=$2');
    writeln(fil,'edgetype=$3');
	writeln(fil,'if ([ "$gpionum" ==   ""       ] || [ "$direction" == ""        ]) ||');
    writeln(fil,'   ([ "$direction" != "in"     ] && [ "$direction" != "out"     ]  && [ "$direction" != "stop" ]) || ');
	writeln(fil,'   ([ "$edgetype"  != "rising" ] && [ "$edgetype"  != "falling" ]  && [ "$direction" != "stop" ]) ; then');
    writeln(fil,'  echo "no valid parameter $1 $2 $3"');
    writeln(fil,'  echo "$0 <gpionum> <[in|out|stop]> <[rising|falling]>"');
    writeln(fil,'  exit 1;');
    writeln(fil,'fi');
	writeln(fil,'#');
	writeln(fil,'echo $0 $1 $2 $3 $4 $5 $6 $7 $8 $9 > $logf');
	writeln(fil,'echo   $gpionum   > $path/unexport');
	writeln(fil,'if ([ "$direction" == "in" ] || [ "$direction" == "out" ]); then');
	writeln(fil,'  echo create gpio$gpionum $direction $edgetype >> $logf');
    writeln(fil,'  echo $gpionum   > $path/export');
    writeln(fil,'  echo $direction > $path/gpio$gpionum/direction');
    writeln(fil,'  echo $edgetype  > $path/gpio$gpionum/edge');
	writeln(fil,'#');
	writeln(fil,'  echo  $path/gpio$gpionum/ >> $logf');
	writeln(fil,'  ls -l $path/gpio$gpionum/ >> $logf');
    writeln(fil,'fi');
	writeln(fil,'#');
    writeln(fil,'exit 0');
    close(fil);
  {$I+} 
  ts:=TStringList.create; 
  if call_external_prog('chmod +x '+filn,ts)=0 then ;
  ts.free;      
end;

{$IFDEF UNIX}
function rpi_hal_Dummy_INT(gpio_nr:integer):integer;
// if isr routine is not initialized
begin
  writeln ('rpi_hal_Dummy_INT fired for GPIO',gpio_nr);
  rpi_hal_Dummy_INT:=-1;
end;

function my_isr(gpio_nr:integer):integer;
// for gpio_int testing. will be called on interrupt
const waittim_ms=1;
begin
  writeln ('my_isr fired for GPIO',gpio_nr,' servicetime: ',waittim_ms:0,'ms');
  sleep(waittim_ms);
  my_isr:=999;
end;

//* Bits from:
//https://www.ridgerun.com/developer/wiki/index.php/Gpio-int-test.c */
//static void *
// https://github.com/omerk/pihwm/blob/master/lib/pi_gpio.c
// https://github.com/omerk/pihwm/blob/master/demo/gpio_int.c
// https://github.com/omerk/pihwm/blob/master/lib/pihwm.c
function isr_handler(p:pointer):longint; // (void *isr)
const STDIN_FILENO = 0; STDOUT_FILENO = 1; STDERR_FILENO = 2; POLLIN = $0001; POLLPRI = $0002; testrun_c=false;
var   rslt:integer; nfds,rc:longint; buf:array[0..63] of byte; fdset:array[0..1] of pollfd; testrun:boolean; isr_ptr:^isr_t; Call_Func:TFunctionOneArgCall;
begin
  rslt:=0; nfds:=2; testrun:=testrun_c; isr_ptr:=p; Call_Func:=isr_ptr^.func_ptr;
  if testrun then writeln('## ',isr_ptr^.gpio);
  if (isr_ptr^.flag=1) and (isr_ptr^.fd>=0) then
  begin
    if testrun then writeln('isr_handler running ',isr_ptr^.gpio);
    while true do
	begin
      fdset[1].fd := STDIN_FILENO; fdset[1].events := POLLIN;  fdset[1].revents:=0;
      fdset[0].fd := isr_ptr^.fd;  fdset[0].events := POLLPRI; fdset[0].revents:=0;

      rc := FPpoll (fdset, nfds, 1000);	// Timeout in ms 

      if (rc < 0) then begin if testrun then writeln('poll() failed!'); rslt:=-1; exit(rslt); end;
	  
      if (rc = 0) then
	  begin
	    if testrun then writeln('poll() timeout.');
        if (isr_ptr^.flag = 0) then
        begin
          if testrun then writeln('exiting isr_handler (timeout)');
		  EndThread;
        end;
      end; 

      if ((fdset[0].revents and POLLPRI)>0) then
	  begin //* We have an interrupt! */
        if (-1 = fpread (fdset[0].fd, buf, 64)) then
		begin
          if testrun then writeln('read failed for interrupt');
		  rslt:=-1;
		  exit(rslt);
        end;
		InterLockedIncrement(isr_ptr^.int_cnt_raw);
        if isr_ptr^.int_enable then 
		begin 
		  InterLockedIncrement(isr_ptr^.int_cnt); 
		  InterLockedIncrement(isr_ptr^.enter_isr_routine);
		  isr_ptr^.enter_isr_time:=now;
		  isr_ptr^.rslt:=Call_Func(isr_ptr^.gpio); 
		  isr_ptr^.last_isr_servicetime:=MilliSecondsBetween(now,isr_ptr^.enter_isr_time);
		  InterLockedDecrement(isr_ptr^.enter_isr_routine);
		end;
      end;

      if ((fdset[1].revents and POLLIN)>0) then
	  begin
        if (-1 = fpread (fdset[1].fd, buf, 1)) then
        begin
          if testrun then writeln('read failed for stdin read');
          rslt:=-1;
		  exit(rslt);
        end;
        if testrun then writeln('poll() stdin read 0x',Hex(buf[0],2));
      end;  
      flush (stdout);
    end;
  end
  else
  begin
    if testrun then writeln('exiting isr_handler (flag)');
    EndThread;
  end;
  isr_handler:=rslt;
end;
 
function gpio_initX(var isr:isr_t):integer;
// needed, because this is the only known possability to use ints without kernel modifications.
var ts:TStringlist; rslt:integer; pathstr,edge_type:string; 
begin
  rslt:=0; pathstr:=gpio_path_c+'/gpio'+Num2Str(isr.gpio,0); 
  if isr.rising_edge then edge_type:='rising' else edge_type:='falling';
  writeln('gpio_initX');
  {$I-}
    ts:=TStringList.create;
    if not FileExists(int_filn_c) then gpio_create_int_script(int_filn_c); 
    if call_external_prog(int_filn_c+' '+Num2Str(isr.gpio,0)+' in '+edge_type,ts)=0 then ;
    ts.free;
    if FileExists(pathstr+'/value') then isr.fd:=fpopen(pathstr+'/value', O_RDONLY or O_NONBLOCK );
  {$I+} 
  if (isr.fd<0) and (rslt=0) then rslt:=-1;
  gpio_initX:=rslt;
end;

function gpio_int_active(var isr:isr_t):boolean;
begin
  if isr.fd>=0 then gpio_int_active:=true else gpio_int_active:=false;
end;

function gpio_set_int(var isr:isr_t; gpio_num:longint; isr_proc:TFunctionOneArgCall; rising_edge:boolean) : integer;
var rslt:integer; 
begin
  rslt:=-1;
//writeln('gpio_int_set ',gpio_num);
  isr.gpio:=gpio_num;  			isr.flag:=1; 	isr.rslt:=0; 		isr.rising_edge:=rising_edge; 	isr.int_enable:=false; 
  isr.fd:=-1;          			isr.int_cnt:=0;	isr.int_cnt_raw:=0;	isr.enter_isr_routine:=0;		isr.func_ptr:=@rpi_hal_Dummy_INT;
  isr.last_isr_servicetime:=0; 	isr.enter_isr_time:=now; 
  
  if isr.gpio>=0 then
  begin
    gpio_set_input(isr.gpio); if isr.rising_edge then gpio_set_edge_rising(isr.gpio,true) else gpio_set_edge_falling(isr.gpio,true); 
    if gpio_initX(isr)=0 then 
    begin
	  if (isr_proc<>nil) then begin isr.func_ptr:=isr_proc; writeln('Int routine installed for GPIO'+Num2Str(gpio_num,0)); end;
      BeginThread(@isr_handler,@isr,isr.ThreadId);  		// http://www.freepascal.org/docs-html/prog/progse43.html
      isr.ThreadPrio:=ThreadGetPriority(isr.ThreadId);  
	  rslt:=0;
    end
	else writeln('Could not install INT for GPIO'+Num2Str(gpio_num,0));
  end;
  if rslt<>0 then writeln('gpio_set_int error ',rslt);
  gpio_set_int:=rslt;
end;

function gpio_int_release(var isr:isr_t):integer;
var rslt:integer;
begin
  rslt:=0;
//writeln('gpio_int_release: pin: ',isr.gpio);
  isr.flag := 0; isr.int_enable:=false;
  gpio_set_edge_rising (isr.gpio,false);
  gpio_set_edge_falling(isr.gpio,false); 
  if isr.fd>=0 then begin fpclose(isr.fd); isr.fd:=-1; end;
  gpio_int_release:=rslt;
end;

procedure instinthandler;  // not ready ,  inspiration http://lnxpps.de/rpie/
//var rslt:integer; p:pointer;
begin
//  writeln(request_irq(110,p,SA_INTERRUPT,'short',nil));
end;

procedure gpio_int_enable (var isr:isr_t); begin isr.int_enable:=true;  (*writeln('int Enable  ',isr.gpio);*) end;
procedure gpio_int_disable(var isr:isr_t); begin isr.int_enable:=false; writeln('int Disable ',isr.gpio); end;

procedure inttest(gpio_nr:longint);
// shows how to use the gpio_int functions
const loop_max=100;
var cnt:longint; isr:isr_t; 
begin
  writeln('INT main start on GPIO',gpio_nr,' loops: ',loop_max:0);
  gpio_set_int   (isr, gpio_nr,@my_isr,true); // set up isr routine, initialize isr struct: gpio_number, int_routine which have to be executed, rising_edge
  gpio_int_enable(isr); // Enable Interrupts, allows execution of isr routine
  for cnt:=1 to loop_max do
  begin
    write  ('doing nothing, waiting for an interrupt. loopcnt: ',cnt:3,' int_cnt: ',isr.int_cnt:3,' ThreadID: ',isr.ThreadID,' ThPrio: ',isr.ThreadPrio);
	if isr.rslt<>0 then begin write(' result: ',isr.rslt,' last service time: ',isr.last_isr_servicetime:0,'ms'); isr.rslt:=0; end;
	writeln;
    sleep (1000);
  end; 
  gpio_int_disable(isr);
  gpio_int_release(isr);
  writeln('INT main end   on GPIO',gpio_nr);
end;

procedure gpio_int_test; // shows how to use the gpio_int functions
const HW_Pin=15; // PIN Number on rpi HW Header P1  ref: http://elinux.org/RPi_Low-level_peripherals
var   gpio:longint;
begin
  gpio:=gpio_MAP_HDR_PIN_2_GPIO_NUM(HW_pin, rpi_gpiomapidx);  // translate Header Pin number to gpio number, dependend on rpi board revision
  writeln('gpio_int_test: HW_Pin:',HW_Pin:0,' maps to GPIO:',gpio:0,' idx:',rpi_gpiomapidx:0);
  inttest(gpio);
end;

{$ENDIF}

// PiFace routines
// code converted from C 2 pascal c-source: https://github.com/thomasmacpherson/piface/blob/master/c/src/piface/pfio.c
function  pfio_get_pin_bit_mask(pin_number:byte):byte;
begin
    // removed - 1 to reflect pin numbering of
    // the python interface (0, 1, ...) instead
    // of (1, 2, ...)
  pfio_get_pin_bit_mask:=(1 shl pin_number);
end;

function  pfio_get_pin_number(bit_pattern:byte):byte;
var pin_number:byte; 
begin
  pin_number := 0; // assume pin 0
  while ((bit_pattern and $01) = $00) and (pin_number<=7) do
  begin
    bit_pattern := (bit_pattern shr 1);
	inc(pin_number);
  end;
  if pin_number > 7 then pin_number:=0;
  pfio_get_pin_number:=pin_number;
end;

function  pfio_avail(devadr:byte):boolean; // has to be implemented. Just a dummy for now
const avail_c=true;
begin 
  // check the HW, if the Chip on Adr 'devadr' is available
  if not avail_c then LOG_WRITELN(LOG_ERROR,'PiFace board not available or not initialized'); 
  pfio_avail:=avail_c; 
end;

function  pfio_SPI_Read (devadr:byte; reg:word) : byte;
const SPI_READ_CMD=$41;
var b:byte;
begin
  b:=0;
  if devadr>$03 then Log_Writeln(LOG_ERROR,'pfio_spi_read: devadr '+Hex(devadr,2)+' not valid')
  else
    begin
    if pfio_avail(devadr) then
    begin  
      spi_transfer(pfio_devnum_default, char(SPI_READ_CMD or (devadr shl 1))+char(byte(reg))+char($ff));
      b:=spi_buf[pfio_devnum_default].buf[2];
    end;
  end;
  pfio_SPI_Read:=b;
end;

procedure pfio_spi_write(devadr:byte; reg,data:word);
const SPI_WRITE_CMD=$40;
begin
  if devadr>$03 then Log_Writeln(LOG_ERROR,'pfio_spi_write: devadr '+Hex(devadr,2)+' not valid')
                else if pfio_avail(devadr) then spi_transfer(pfio_devnum_default, char(SPI_WRITE_CMD or (devadr shl 1))+char(byte(reg))+char(byte(data)));
end;

procedure pfio_showregs(devadr:byte);
begin
  writeln('IOCON  0x'+Hex(pfio_spi_read(devadr, pfio_IOCON), 2));
  writeln('GPIOA  0x'+Hex(pfio_spi_read(devadr, pfio_GPIOA), 2));
  writeln('IODIRA 0x'+Hex(pfio_spi_read(devadr, pfio_IODIRA),2));
  writeln('IODIRB 0x'+Hex(pfio_spi_read(devadr, pfio_IODIRB),2));
  writeln('GPPUB  0x'+Hex(pfio_spi_read(devadr, pfio_GPPUB), 2));
end;

procedure pfio_init(devadr:byte);
var i:byte;
begin 
  if pfio_avail(devadr) then
  begin
    LOG_WRITELN(LOG_DEBUG,'PiFace board init');
//  pfio_showregs (devadr);	
    pfio_spi_write(devadr, pfio_IOCON, $08); // enable hardware addressing
    pfio_spi_write(devadr, pfio_GPIOA, $00); // turn on port A
    pfio_spi_write(devadr, pfio_IODIRA,$00); // set port A as an output
    pfio_spi_write(devadr, pfio_IODIRB,$FF); // set port B as an input
    pfio_spi_write(devadr, pfio_GPPUB, $FF); // turn on port B pullups
//	pfio_showregs (devadr);
    for i := 1 to 8 do pfio_digital_write(devadr,i,$00); // initialise all outputs to 0
  end;
end;	

function  pfio_read_input(devadr:byte):byte;      
var b:byte;    
begin 
  if not pfio_avail(devadr) then b:=0 else b:=pfio_spi_read (devadr, pfio_INPUT_PORT) xor $FF; 
  // XOR by 0xFF so we get the right outputs. before a turned off input would read as 1, confusing developers.
  pfio_read_input:=b;
end; 

function  pfio_read_output(devadr:byte):byte;    begin pfio_read_output:=pfio_spi_read(devadr, pfio_OUTPUT_PORT); end;

procedure pfio_write_output(devadr, value:byte); begin pfio_spi_write(devadr, pfio_OUTPUT_PORT,value); end;

function  pfio_digital_read(devadr, pin_number:byte):boolean;
var current_pin_values,pin_bit_mask:byte;
begin
    current_pin_values:=pfio_read_input(devadr);
    pin_bit_mask      :=pfio_get_pin_bit_mask(pin_number);
    // note: when using bitwise operators and checking if a mask is
    // in there it is always better to check if the result equals
    // to the desidered mask, in this case pin_bit_mask.
    pfio_digital_read:=(current_pin_values and pin_bit_mask ) = pin_bit_mask;
end;

procedure pfio_digital_write(devadr,pin_number,value:byte);
var pin_bit_mask,old_pin_values,new_pin_values:byte;
begin
  pin_bit_mask:=  pfio_get_pin_bit_mask(pin_number);
  old_pin_values:=pfio_read_output(devadr);
  if (value > 0) then new_pin_values := old_pin_values or       pin_bit_mask
                 else new_pin_values := old_pin_values and (not pin_bit_mask);
  if (LOG_Get_Level>=LOG_DEBUG) then
  begin
    Log_Writeln(LOG_DEBUG,'digital_write: pin number '+Hex(pin_number,2)+' value '+Hex(value,2));
    Log_Writeln(LOG_DEBUG,'pin bit mask:   0x'+Hex(pin_bit_mask,2));
    Log_Writeln(LOG_DEBUG,'old pin values: 0x'+Hex(old_pin_values,2));
    Log_Writeln(LOG_DEBUG,'new pin values: 0x'+Hex(new_pin_values,2));
    Log_Writeln(LOG_DEBUG,'');
  end;
  pfio_write_output(devadr,new_pin_values);
end;

function  SetBitINByte(oldval:byte; bitnum:byte; state:boolean):byte; // delivers Byte with 'bitnum' set or reset bitnum=1..8 
var b:byte;
begin
  b:=0; 
  if (bitnum>=1) and (bitnum<=8) then b:= $01 shl (bitnum-1);
  if state then b:=oldval or b else b:=oldval and (not b);
  SetBitINByte:=b;
end;

// Is input  'num' ON or OFF 
function  pfio_ISTAT(devadr, bitnum:byte):boolean; begin pfio_ISTAT:=(pfio_read_input(devadr)  and SetBitINByte(0, bitnum, true))>0; end;

// Is Output State	'bitnum'	[1..8]  ON or OFF // Whats the current state of Output pin, without setting it 
function  pfio_OSTAT(devadr, bitnum:byte):boolean; begin pfio_OSTAT:=(pfio_read_output(devadr) and SetBitINByte(0, bitnum, true))>0; end;

procedure pfio_RELAY(devadr, num:byte; state:boolean);
begin
  case num of
     1..2 : pfio_write_output(devadr, SetBitINByte(pfio_read_output(devadr),num,state));
	else LOG_WRITELN(LOG_ERROR,'pfio_RELAY: num '+Hex(num,2)+' not valid');
  end;	
end;

procedure pfio_OUTPUT(devadr, num:byte; state:boolean);
begin
  case num of
     1..8 : pfio_write_output(devadr, SetBitINByte(pfio_read_output(devadr),num,state));
	else LOG_WRITELN(LOG_ERROR,'pfio_OUTPUT: num '+Hex(num,2)+' not valid');
  end;	
end;

function  pfio_button_pressed(inputbyte:byte):byte; 
begin 
  pfio_button_pressed:=pfio_get_pin_number(inputbyte and $0f)+1;
end;

procedure pfio_test1(devadr:byte);
var cnt:word; b:byte;
begin
  writeln('Push the buttons [S1..S4] (runtime 10secs)');
  for cnt := 1 to 10 do
  begin
    b:=pfio_read_input(devadr);
    write  ('Input port: 0x'+Hex(b,2)); if b>0 then write(' Button pressed S'+Num2Str(pfio_button_pressed(b),0)); writeln;
	sleep(1000); // ms
  end;
end;

procedure pfio_test2(devadr:byte);
var cnt:word; 
begin
  writeln('Output test (runtime 20secs)');
  for cnt := 1 to 8 do begin writeln('OUTPUT ',cnt:0,' ON');  pfio_OUTPUT(devadr, cnt, an);  sleep(1000); end;
  for cnt := 1 to 8 do begin writeln('OUTPUT ',cnt:0,' OFF'); pfio_OUTPUT(devadr, cnt, aus); sleep(1000); end;
end;

procedure pfio_test3(devadr:byte);
var cnt,cnt1:word; 
begin
  writeln('Relay test (runtime 20secs)');
  for cnt1 := 1 to 5 do 
  begin 
    for cnt := 1 to 2 do 
    begin 
      writeln('Relay ',cnt:0,' ON');  pfio_RELAY(devadr, cnt, an);  sleep(1000); 
	  writeln('Relay ',cnt:0,' OFF'); pfio_RELAY(devadr, cnt, aus); sleep(1000); 
    end;
  end;
end;

procedure pfio_test4(devadr:byte);
const maxP_c=3; patterns:array[0..maxP_c] of byte = ($84, $48, $30, $48);                                      
var cnt,cnt1,cnt2:word; 
begin
  writeln('LED test (runtime infinite)');
  repeat
    for cnt1 := 1 to  2 do begin for cnt := 3 to 8 do begin pfio_OUTPUT(devadr, cnt, an); sleep(100); pfio_OUTPUT(devadr, cnt, aus); sleep(100); end; end;
	for cnt2 := 1 to 10 do begin for cnt1 := 0 to maxP_c do begin pfio_write_output(devadr, patterns[cnt1]); sleep(100); end; pfio_write_output(devadr, $00); end;
  until false;
end;

procedure pfio_test(devadr:byte);
begin
  pfio_test1(devadr);
  pfio_test2(devadr);
  pfio_test3(devadr);
  pfio_test4(devadr);
end;

procedure BB_OOK_PIN(state:boolean);
// this procedure, uses a gpio pin for OOK (OnOffKeying). 
begin
//Writeln('BB_OOK_PIN(state: '+Bool2Str(state)+' Pin: '+Num2Str(BB_pin,0));
  Log_Writeln(LOG_DEBUG,'BB_OOK_PIN(state: '+Bool2Str(state)+' Pin: '+Num2Str(BB_pin,0));
  if BB_pin>0	then gpio_set_PIN(BB_pin,state) 
				else LOG_WRITELN(LOG_ERROR,'BB_OOK_PIN: unknown GPIO number '+Num2Str(BB_pin,0));
end;

procedure BB_BitBang(codestring,Pat:string; periodusec_short,periodusec_long,periodusec_sync,repl:longint); // Pat: '0,HpLPHpLP;1,HPLpHPLp;X,HpLPHPLp;S,HpLS'
  procedure play(str:string);
  var i:integer;
  begin
    for i := 1 to length(str) do
	begin
	  case str[i] of
	    'L','l' : BB_OOK_PIN(false);
		'H','h' : BB_OOK_PIN(true);
		'p'		: delay_us(periodusec_short);	
		'P'		: delay_us(periodusec_long);	
		'S'		: delay_us(periodusec_sync);	
		' ' 	: begin { do nothing, just for formatting reasons } end; 
		else	  LOG_WRITELN(LOG_ERROR,'BB_BitBang: wrong pattern: '+str[i]+' playstr '+str);
	  end;
	end;
  end;
var   i,j:integer; H,L,X,S,sh1,sh2:string;
begin
  H:=''; L:=''; X:=''; S:=''; 
  for i := 1 to Anz_Item(Pat,';','') do
  begin
    sh1:=Select_Item(Pat,';','',i); sh2:=Select_Item(sh1,',','',2); sh1:=Select_Item(sh1,',','',1);
	if sh1='0' then L:=sh2; if sh1='1' then H:=sh2; if sh1='X' then X:=sh2; if sh1='S' then S:=sh2;
  end;
  for i := 1 to repl do
  begin
    for j := 1 to Length(codestring) do
    begin
      case codestring[j] of
        '0' : play(L);
		'1' : play(H);
		'X' : play(X);
		'S' : play(S);
		' ' : begin { do nothing, just for formatting reasons } end; 
		else  LOG_WRITELN(LOG_ERROR,'BB_BitBang: wrong pattern: '+codestring[j]+' in '+codestring);
	  end;
    end;
  end;
end; { BB_BitBang }

procedure BB_SendCode(switch_type:T_PowerSwitch; adr,id,desc:string; ein:boolean);
{ https://github.com/tandersson/rf-bitbanger/blob/master/rfbb_cmd/rfbb_cmd.c }
var   s,pat:string; ok:boolean; periodusec_short,periodusec_long,periodusec_sync,repl:longint;
begin
  s:=FilterChar(adr,'01'); pat:=''; ok:=false; repl:=10; periodusec_short:=340; periodusec_long:=3*periodusec_short; periodusec_sync:=32*periodusec_short;
  LOG_Writeln(LOG_DEBUG,'BB_SendCode on:'+Bool2Str(ein)+' TYP:'+GetEnumName(TypeInfo(T_PowerSwitch),ord(switch_type))+' ADR:'+adr+' DESC:'+desc);
//Writeln              ('BB_SendCode on:'+Bool2Str(ein)+' TYP:'+GetEnumName(TypeInfo(T_PowerSwitch),ord(switch_type))+' ADR:'+adr+' DESC:'+desc);  
  if s<>'' then
  begin
    LED_Status(false); 
	BB_OOK_PIN(false);	
    case switch_type of
	  ELRO,Sartano:	begin // This is tested, I have an ELRO PowerSwitch
					  ok:=true; pat:='0,HpLPHPLp;1,HpLPHpLP;S,HpLS';
					  repl:=15; periodusec_short:=320; periodusec_long:=3*periodusec_short; periodusec_sync:=31*periodusec_short; 
					  if ein then s:=s+'10' else s:=s+'01'; s:=s+'S'; 
					end;
	  nexa: 		begin {	This is not tested, I don't have a nexa PowerSwitch
							http://elektronikforumet.syntaxis.se/wiki/index.php/RF_Protokoll_-_Nexa/Proove_%28%C3%A4ldre,_ej_sj%C3%A4lvl%C3%A4rande%29
							The bit coding used by the encoder chips, for example M3E. from MOSDESIGN SEMICONDUCTOR, allows for trinary codes, ie '0','1' and 'X' (OPEN/FLOATING). 
							However, it seems that only '0' and 'X' is currently used in the NEXA/PROOVE remotes. 
							The high level in the ASCII-graphs below denotes the transmission of the 433 MHz carrier. The low level means no carrier.}
					  ok:=true; pat:='0,HpLPHpLP;1,HPLpHPLp;X,HpLPHPLp;S,HpLS';	
					  repl:=10; periodusec_short:=340; periodusec_long:=3*periodusec_short; periodusec_sync:=32*periodusec_short;
					  if ein then s:=s+'10' else s:=s+'01'; s:=s+'S'; 
					  s:=StringReplace(s,'1','X',[rfReplaceAll,rfIgnoreCase]);
					end;
	  Intertechno:	begin { This is not tested, I don't have a Intertechno PowerSwitch
							CONRAD-Intertechno: http://blog.sui.li/2011/04/12/low-cost-funksteckdosen-arduino/ }
					  ok:=true; pat:='0,HpLPHpLP;1,HPLpHpLP;S,HpLS'; 	
					  repl:=10; periodusec_short:=320; periodusec_long:=3*periodusec_short; periodusec_sync:=32*periodusec_short;
					  if ein then s:=s+'1'  else s:=s+'0';  s:=s+'S'; 
					end;
	  else          LOG_Writeln(LOG_ERROR,'BB_SendCode: unknown switchtype: '+GetEnumName(TypeInfo(T_PowerSwitch),ord(switch_type)));
    end;
	if ok then BB_BitBang(s, Pat, periodusec_short, periodusec_long, periodusec_sync, repl); 
	BB_OOK_PIN(false); 	
    LED_Status(true);
	sleep(1);	
  end;
end;

procedure BB_SetPin(pinnr:longint); 
begin 
  BB_pin:=pinnr; 
  Log_Writeln(LOG_DEBUG,'BB_SetPin: '+Num2Str(BB_pin,0)); 
  if BB_pin>0 then gpio_set_OUTPUT(BB_pin); 
//writeln('BB_SetPin: ',BB_pin);
end;

function  BB_GetPin:longint; begin BB_GetPin:=BB_pin; end;

procedure BB_InitPin(id:string); // e.g. id:'TLP434A' or id:'13'  (direct RPI Pin on HW Header P1 )
var devnum:byte; BBPin:longint; sh:string; 
begin
  sh:=Upper(id);
  if not Str2Num(Select_Item(sh,',','',1),BBpin) then BBpin:=-1;
  devnum:=0;
  if (sh='TLP434A') 	then devnum:=1;
  if (sh='TX433N') 		then devnum:=1;
  if (sh='TWS-BS') 		then devnum:=1; // from Sparkfun WRL-10534 
  if (sh='RFM22B')	 	then devnum:=2;
  case devnum of
	 1 : 					BBpin:=gpio_MAP_HDR_PIN_2_GPIO_NUM(IO1_Pin_on_RPI_Header,	rpi_gpiomapidx);  
	 2 : 					BBpin:=gpio_MAP_HDR_PIN_2_GPIO_NUM(OOK_Pin_on_RPI_Header,	rpi_gpiomapidx); 
	else if BBpin>0 then	BBpin:=gpio_MAP_HDR_PIN_2_GPIO_NUM(BBpin, 					rpi_gpiomapidx); 
  end;
  BB_SetPin(BBpin);
end;

procedure ELRO_TEST;
// Set you ELRO PowerSwitch to the following System- and Unit_A-Code
const id_c='ELRO-A'; SystemCode_c='10001'; Unit_A_c='10000'; Unit_B_c='01000'; Unit_C_c='00100'; Unit_D_c='00010'; Unit_E_c='00001'; 
var cnt:integer; oldpin:longint;
begin
  oldpin:=BB_GetPin;															// save it
  BB_SetPin(gpio_MAP_HDR_PIN_2_GPIO_NUM(IO1_Pin_on_RPI_Header,rpi_gpiomapidx)); // set the pin to OOK Pin for the piggyback-board Transmitter Chip (433.92 Mhz)
  writeln('Start  ELRO_TEST');
  for cnt := 1 to 15 do
  begin
    writeln(cnt:2,'. EIN: '+id_c); LED_Status(true); BB_SendCode(ELRO,SystemCode_c+Unit_A_c,id_c,'ELRO Switch A, System-Code: ON  OFF OFF OFF ON   Unit-Code: ON  OFF OFF OFF OFF', true);  sleep(1500); LED_Status(false); 
	writeln(cnt:2,'. AUS: '+id_c); LED_Status(true); BB_SendCode(ELRO,SystemCode_c+Unit_A_c,id_c,'ELRO Switch A, System-Code: ON  OFF OFF OFF ON   Unit-Code: ON  OFF OFF OFF OFF', false); sleep(2000); LED_Status(false); 
	writeln; writeln;
  end;
  writeln('End   ELRO_TEST');
  BB_SetPin(oldpin);															// restore it
end;

procedure morse_speed(speed:integer); // 1..5, -1=default_speed
//WpM:WordsPerMinute; BpM:Buchstaben/Letter pro Minute
begin
  morse_dit_lgt			:= 120;	//  10WpM=50BpM	-> 120ms // default
  case speed of
      1 : morse_dit_lgt	:=1200;	//  1WpM=  5BpM	->1200ms 
	  2 : morse_dit_lgt	:= 240;	//  5WpM= 25BpM	-> 240ms
	  3 : morse_dit_lgt	:= 150;	//  8WpM		-> 150ms 
	  4 : morse_dit_lgt	:= 120;	// 10WpM= 50BpM	-> 120ms
	  5 : morse_dit_lgt	:=  60;	// 20WpM=100BpM	->  60ms
  end;
end;

procedure morse_tx(s:string);
// http://de.wikipedia.org/wiki/Morsezeichen
// http://en.wikipedia.org/wiki/Morse_code
const test=true; CH_c = 'c'; 
  morse_char : array [01..26,01..02] of string = 
  ( ('.-',  'A') , ('-...','B') , ('-.-.','C') , ('-..', 'D') , ('.',   'E') , 
    ('..-.','F') , ('--.', 'G') , ('....','H') , ('..',  'I') , ('.---','J') ,
    ('-.-', 'K') , ('.-..','L') , ('--',  'M') , ('-.',  'N') , ('---', 'O') ,
    ('.--.','P') , ('--.-','Q') , ('.-.', 'R') , ('...', 'S') , ('-',   'T') ,
    ('..-', 'U') , ('...-','V') , ('.--', 'W') , ('-..-','X') , ('-.--','Y') ,
    ('--..','Z') );
 
  morse_digit : array [01..10,01..02] of string = 
  ( ('-----','0') , ('.----','1') , ('..---','2') , ('...--', '3') , ('....-','4') ,
    ('.....','5') , ('-....','6') , ('--...','7') , ('---..', '8') , ('----.','9') );

  sc1_count = 27;
  morse_sc1 : array [01..sc1_count,01..02] of string = 
  ( ('----',  CH_c),
    ('.-.-.-','.') , ('--..--',',') ,  ('---...', ':') , ('-.-.-.',';') , ('..--..','?') ,   
    ('-.-.--','!') , ('-....-','-') ,  ('..--.-', '_') , ('-.--.', '(') , ('-.--.-',')') , 
	('.----.',''''), ('-...-', '=') ,  ('.-.-.',  '+') , ('-..-.', '/') , ('.--.-.','@') ,
	('.-...', '&') , ('.-..-.','"') ,  ('...-..-','$') ,
    ('.-.-',  'Ä') , ('---.',  'Ö') ,  ('..--',   'Ü') , ('...--..','ß'), ('.--.-', 'À') ,
	('.--.-', 'Å') , ('.-..-', 'È') ,  ('--.--',  'Ñ') 
  );

var sh,sh2:string; n : longint; dit_lgt,dah_lgt,symbol_end,letter_end,word_end:word;

  procedure morse_wait(w:word); begin delay_msec(w) end;
  procedure dit; begin BB_OOK_PIN(AN); morse_wait(dit_lgt); BB_OOK_PIN(AUS); end; 
  procedure dah; begin BB_OOK_PIN(AN); morse_wait(dah_lgt); BB_OOK_PIN(AUS); end; 
  procedure sig (ch:char); begin if test then write(ch); if ch='.' then dit else dah; end;
  
  function  sc1 (s:string):string; var sh:string; j:longint; begin sh:=''; for j := 1 to sc1_count do if s=morse_sc1[j,2] then sh:=morse_sc1[j,1]; sc1:=sh; end;
  procedure mors(s1,s2:string);    var n : longint; begin if test then begin if s1=CH_c then write('CH') else write(s1); write(' '); end; for n := 1 to Length(s2) do begin sig(s2[n]); if n<Length(s2) then morse_wait(symbol_end); end; if test then writeln; end;
  
begin
  dit_lgt:=morse_dit_lgt; dah_lgt:=3*dit_lgt; symbol_end:=dit_lgt; letter_end:=dah_lgt; word_end:=7*dit_lgt; // define timing, depending on external variable morse_dit_lgt set by procedure morse_speed
  LOG_Writeln(LOG_DEBUG,'Morse: '+s);
  if test then  writeln('Morse: '+s);
  sh:=Upper(s);
//sh:=StringReplace(sh,'CH',CH_c,[rfReplaceAll]); // replace 'CH' with one character
  for n := 1 to Length(sh) do
  begin
    case sh[n] of
	  ' '	   : begin morse_wait(word_end); if test then writeln; end;
      'A'..'Z' : begin sh2:=morse_char [ord(sh[n])-ord('A')+1,1]; mors(sh[n],sh2); morse_wait(letter_end); end;
	  '0'..'9' : begin sh2:=morse_digit[ord(sh[n])-ord('0')+1,1]; mors(sh[n],sh2); morse_wait(letter_end); end;
	  else       begin sh2:=sc1(sh[n]);                           mors(sh[n],sh2); morse_wait(letter_end); end;
	end;
  end;
  if test then writeln;
end;

procedure morse_test;
var oldpin:longint;
begin
  oldpin:=BB_GetPin;						// save it
  BB_SetPin(rpi_status_led_GPIO); 			// set the pin to Rpi Status LED
  morse_speed(3);							// 3: 8WpM	-> 150ms 
  morse_tx('Hello this is a Morse Test.');	// The Status LED should blink (morse) now
  BB_SetPin(oldpin);						// restore it
end;

procedure rpi_hal_exit;
begin
  if ExitCode <> 0 then begin LOG_Writeln(LOG_ERROR,'rpi_hal_exit: Exitcode: '+Num2Str(ExitCode,3)); end;
  ExitProc := OldExitProc;
  SPI_Bus_Close_All;
  i2c_Close_All;
  gpio_end;
end;

begin
//writeln('hal+');
  LOG_Level:=LOG_Warning; 
//LOG_Level:=LOG_debug;
  testnr:=NO_TEST; 
  SetUTCOffset;  // set _TZlocal 
  mem_fd:=-1; mmap_arr_gpio:=nil; mmap_arr_pwm:= nil; mmap_arr_clk:= nil; 
  cpu_rev_num:=0; gpio_map_idx:=0;
  Get_CPU_INFO_Init; 
  if rpi_run_on_known_hw then
  begin
    OldExitProc:=ExitProc; ExitProc:=@rpi_hal_exit;
	{$IFDEF UNIX} gpio_create_int_script(int_filn_c); {$ENDIF} // no need for it. Just for convenience 
    gpio_start;
    i2c_Init;
    SPI_Init_Const; 
	SPI_DEV_INIT_All;
    SPI_BUS_INIT_All;
	BB_pin:=rpi_status_led_GPIO;
//  BB_SetPin(rpi_status_led_GPIO);	// set the BitBang GPIO-Pin to LED Status Pin
	morse_speed(-1);				// set to default speed 10WpM=50BpM	-> 120ms
//  rpi_show_all_info;
  end
  else Log_writeln(Log_ERROR,'rpi_hal: not running on known rpi HW');
//  gpio_set_HDR_PIN(5,false); gpio_set_HDR_PIN(13,false);
//writeln('hal-');
end.
