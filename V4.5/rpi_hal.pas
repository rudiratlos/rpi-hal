unit rpi_hal; // V4.5 // 09-Mar-2017
{ RPI_hal:
* Free Pascal Hardware abstraction library for the Raspberry Pi
* Copyright (c) 2012-2017 Stefan Fischer
***********************************************************************
*
* RPI_hal is free software: you can redistribute it and/or modify
* it under the terms of the GNU Lesser General Public License as 
* published by the Free Software Foundation, either version 3 
* of the License, or (at your option) any later version.
*
* RPI_hal is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
* GNU Lesser General Public License for more details.
*
* You should have received a copy of the GNU Lesser General Public License
* along with RPI_hal. If not, see <http://www.gnu.org/licenses/>.
*
*********************************************************************** 

  requires minimum FPC Version: 2.4.6
  support for the following RPI-Models: A,B,A+,B+,Pi2B,Zero,Pi3B 
  !!!!! In your program, pls. use following uses sequence: !!!!!
  uses cthreads,rpi_hal,<yourunits>...
  Info:  http://wiki.freepascal.org/Lazarus_on_Raspberry_Pi
  pls. report bugs and discuss code enhancements here:
  Forum: http://www.lazarus.freepascal.org/index.php/topic,20991.0.html
  the curl tool is used by function RPI_MAINT. Install it e.g. apt-get install curl
  Supported by the H2020 Project # 664786 - Reservoir Computing with Real-Time Data for Future IT
}
  {$MODE OBJFPC}
  { $T+}
  {$R+} {$Q+}
  {$H+}  // Ansistrings
  {$packrecords C} 
  {$MACRO ON}
  {$HINTS OFF}
Interface 
uses {$IFDEF UNIX}    cthreads,initc,ctypes,unixtype,cmem,BaseUnix,Unix,unixutil, {$ENDIF} 
     {$IFDEF WINDOWS} windows, {$ENDIF} 
	 typinfo,sysutils,dateutils,Classes,Process,math,inifiles,md5;
  
const
  supminkrnl=797; supmaxkrnl=970; 	// not used
  fmt_rfc3339='yyyy-mm-dd"T"hh:nn:ss';
  Real_unvalid_value=5.0E-324;
  hdl_unvalid=-1;
  AN=true; AUS=false; AUF=true; ZU=false;
  TestTimeOut_sec=60;	// 1min
  LF      = #$0A; CR   = #$0D; STX      = #$02; ETX = #$03;
  Cntrl_Z = #$1A; BELL =   #7; EOL_char =   LF; HT  = #$09; // HT=TAB
  yes_c='TRUE,YES,1,JA,AN,EIN,HIGH,ON'; nein_c='FALSE,NO,0,NEIN,AUS,LOW,OFF';
  CompanyShortName='BASIS';
  UAgentDefault='Mozilla/5.0 (Macintosh; Intel Mac OS X 10.10; rv:36.0) Gecko/20100101 Firefox/36.0';
//https://curl.haxx.se/docs/manpage.html
  CURLTimeOut_c= '300'; CURLPorts_c='49152-63000';
  CURLFTPDefaults_c='--retry 3 --retry-delay 5 --ftp-pasv --ftp-skip-pasv-ip --disable-epsv --connect-timeout '+CURLTimeOut_c+' --local-port '+CURLPorts_c;
  {$IFDEF WINDOWS} 
    CRLF=CR+LF; dir_sep_c='\';	
	c_tmpdir='c:\tmp'; AppDataDir_c = 'c:\ProgramData\'+CompanyShortName;	
	LogDir_c=c_tmpdir;  c_cmddir='c:\cmd'; c_etcdir=c_tmpdir; 
  {$ELSE} 
    CRLF=LF; dir_sep_c='/'; 	
	c_tmpdir='/tmp'; AppDataDir_c = '/var/lib/'+CompanyShortName;
	LogDir_c='/var/log'; c_cmddir='/usr/local/sbin'; c_etcdir = '/etc'; 
  {$ENDIF} 
  
  CRLF4HTTP=CR+LF; // for HTTP-Protocol we have to send 0d0a 
  ext_sep_c='.'; 
  sep_max_c=6;
  sep:array[0..sep_max_c] of char=(';',',','|','*','~','`','^');
     		   
  osc_freq_c			=  19200000; // OSC  (19.2Mhz ClkSrc=1)	
  pllc_freq_c			=1000000000; // PLLC (1000Mhz ClkSrc=5, changes with overclock settings) 
  plld_freq_c			= 500000000; // PLLD ( 500Mhz ClkSrc=6)
  HDMI_freq_c			= 216000000; // HDMI ( 216Mhz ClkSrc=7, auxiliary) 
  
  gpiomax_reg_c			=54; // max. gpio count (GPIO0-53) pls. see (BCM2709) 2012 Datasheet page 102ff 
  GPIO_PWM0	   			=18; // GPIO18 PWM0 	on Connector Pin12
  GPIO_PWM1				=19; // GPIO19 PWM1 	on Connector Pin35  (RPI2)
  GPIO_PWM0A0		   	=12; // GPIO12 PWM0 	on Connector Pin32  (RPI2)
  GPIO_PWM1A0			=13; // GPIO13 PWM1 	on Connector Pin33  (RPI2)
  GPIO_FRQ04_CLK0		= 4; // GPIO4  GPCLK0 	on Connector Pin7
  GPIO_FRQ05_CLK1		= 5; // GPIO5  GPCLK1 	on Connector Pin29  (reserved for system use)
  GPIO_FRQ06_CLK2		= 6; // GPIO6  GPCLK2 	on Connector Pin31
  GPIO_FRQ20_CLK0		=20; // GPIO20 GPCLK0 	on Connector Pin38  
  GPIO_FRQ21_CLK1		=21; // GPIO21 GPCLK1 	on Connector Pin40  (reserved for system use)
  GPIO_FRQ32_CLK0		=32; // GPIO32 GPCLK0	Compute module only
  GPIO_FRQ34_CLK0		=34; // GPIO34 GPCLK0	Compute module only
  GPIO_FRQ42_CLK1		=42; // GPIO42 GPCLK1	Compute module only (reserved for system use)
  GPIO_FRQ43_CLK2		=43; // GPIO43 GPCLK3	Compute module only 
  GPIO_FRQ44_CLK1		=44; // GPIO44 GPCLK1	Compute module only (reserved for system use)
  
  GPIO_path_c='/sys/class/gpio';
  mdl=9;
  wid1=12;
  gpiomax_map_idx_c=2;
  max_pins_c = 40;
//Map Pin-Nr on HW Header P1 to GPIO-Nr. (http://elinux.org/RPI_Low-level_peripherals)  
  UKN=-99; WRONGPIN=UKN-1; V5=-98; V33=-97; GND=-96; DNC=-95; IDSC=1; IDSD=0;
  GPIO_hdr_map_c:array[1..gpiomax_map_idx_c] of array[1..max_pins_c] of integer = //     !! <- Delta rev1 and rev2 	 									           --> Pins (27-40) only available on newer RPIs
//  							I2C		  I2C 																		   SPI		  SPI	
  (// HW-PIN           1    2    3    4    5     6     7     8     9    10   11   12   13   14    15   16    17   18    19   20    21  22    23    24   25    26   [27     28   29    30   31   32   33    34   35   36   37   38    39   40] }
   // Desc          3.3V   5V   SDA1  5V  SCL1  GND  1Wire  TxD   GND   RxD  11   12   13   GND   15   16  3.3V   18  MOSI  GND  MISO  22   SPI   SPI  GND   SPI  IDSD   IDSC   29   GND   31   32   33   GND   35   36   37   38   GND   40  }
    { rev1 GPIO } ( (V33),(V5),(UKN),(V5),( 1),(GND),(  4),( 14),(GND),(15),(17),(18),(21),(GND),(22),(23),(V33),(24),(10),(GND),( 9),(25),( 11),( 8),(GND),( 7),(IDSD),(IDSC),( 5),(GND),( 6),(12),(13),(GND),(19),(16),(26),(20),(GND),(21) ),
    { rev2 & B+ } ( (V33),(V5),(  2),(V5),( 3),(GND),(  4),( 14),(GND),(15),(17),(18),(27),(GND),(22),(23),(V33),(24),(10),(GND),( 9),(25),( 11),( 8),(GND),( 7),(IDSD),(IDSC),( 5),(GND),( 6),(12),(13),(GND),(19),(16),(26),(20),(GND),(21) )
  );
  
//Pin-Nr on HW Header P1; definitions for piggy-back board
  Int_Pin_on_RPI_Header=15; // =GPIO22 -> PIN Number on rpi HW Header P1  ref: http://elinux.org/RPI_Low-level_peripherals
  Ena_Pin_on_RPI_Header=22; // =GPIO25 -> RFM22_SD
  OOK_Pin_on_RPI_Header=11; // =GPIO17 -> RFM22_OOK
  IO1_Pin_on_RPI_Header=13; // =GPIO21/GPIO27 -> TLP434A OOK
  ITX_Pin_on_RPI_Header=12; // =GPIO18 -> IR TX
  IRX_Pin_on_RPI_Header=16; // =GPIO23 -> IR RX
  W1__Pin_on_RPI_Header=07; // =GPIO4  -> 1Wire BitBang
  Int_SPI_01_RPI_Header=18; // =GPIO24 -> Int Pin SPI1 on JP1 Pin5
  
{ BCM2708: Physical addresses range from 0x20000000 to 0x20FFFFFF for peripherals. 
    The bus addresses for peripherals are set up to map onto the peripheral 
	bus address range starting at 0x7E000000. 
	Thus a peripheral advertised here at bus address 0x7Ennnnnn is available 
	at physical address 0x20nnnnnn. }
	
  PAGE_SIZE=			$1000;		// 4k
  BCM270x_PSIZ_Byte= 	$80000000-$7e000000; // MemoryMap: Size of Peripherals. Docu Page 5  
  BCM270x_RegSizInByte= SizeOf(longword);
  BCM270x_RegMaxIdx= 	(BCM270x_PSIZ_Byte div BCM270x_RegSizInByte)-1; // Registers 0..RegMaxIdx
  BCM2708_PBASE= 		$20000000; 	// Peripheral Base in Bytes
  BCM2709_PBASE= 		$3F000000; 	// Peripheral Base in Bytes (RPI2B Processor) 
  
  STIM_BASE_OFS=    	$00003000; 	// Docu Page 172ff SystemTimer
  INTR_BASE_OFS=   		$0000B000;  // Docu Page 112ff 
  TIMR_BASE_OFS=   		$0000B000;  // Docu Page 196ff Timer ARM side
  PADS_BASE_OFS=   		$00100000; 
  CLK_BASE_OFS=   		$00101000; 	// Docu Page 107ff
  GPIO_BASE_OFS=   		$00200000; 	// Docu Page  90ff GPIO contr. page start (1 page=4096Bytes) 
  UART_BASE_OFS=   		$00201000;	// Docu Page 177ff
  PCM_BASE_OFS=    		$00203000;	// Docu Page 125ff
  SPI0_BASE_OFS=   		$00204000;	// Docu Page 152ff
  PWM_BASE_OFS=   		$0020C000; 	// Docu Page 138ff
  BSC_BASE_OFS=    		$00214000;	// Docu Page 160ff
  AUX_BASE_OFS=   		$00215000;  // Docu Page   8ff
  BSC0_BASE_OFS=   		$00205000;	// Docu Page  28ff
  BSC1_BASE_OFS=   		$00804000;	// Docu Page  28ff
  BSC2_BASE_OFS=   		$00805000;	// Docu Page  28ff
  I2C0_BASE_OFS=		BSC0_BASE_OFS;
  I2C1_BASE_OFS=		BSC1_BASE_OFS;
  I2C2_BASE_OFS=		BSC2_BASE_OFS;
  EMMC_BASE_OFS=   		$00300000;	// Docu Page  66ff
  BCM2709_LP_OFS=		$01000000;	// $40000000 BCM2836 Quad-A7 Core Local PeripheralBase. Docu QA7-rev3.4

//0x 4000 0000
//Indexes		(each addresses 4 Bytes) 
  Q4LP_BASE			= BCM2709_LP_OFS div BCM270x_RegSizInByte;
  Q4LP_CTL			= Q4LP_BASE+ 0;	// Control register Docu QA7_rev3.4 Page 7ff
  Q4LP_CTIMPRE		= Q4LP_BASE+ 2;	// Core timer prescaler	
  Q4LP_GPUINTRTG	= Q4LP_BASE+ 3;	// GPU interrupts routing
  Q4LP_CoreTimAccLS = Q4LP_BASE+ 7;	// Core timer access LS 32 bits
  Q4LP_CoreTimAccMS = Q4LP_BASE+ 8;	// Core timer access MS 32 bits
  Q4LP_LOCINTRTG	= Q4LP_BASE+ 9;	// Local Interrupt 0 [1-7] routing
  Q4LP_LOCTIMCTL	= Q4LP_BASE+13;	// Local timer control & status
  Q4LP_Core0IntCtl	= Q4LP_BASE+16;	// Core0 timer Interrupt control
  Q4LP_Core0IrqSrc	= Q4LP_BASE+24;	// Core0 IRQ Source
  Q4LP_Core0FIQSrc	= Q4LP_BASE+28;	// Core0 FIQ Source
  Q4LP_Last			= Q4LP_BASE+63;	// max. of 64 registers (0..63)

//0x 7E20 0000  
  GPIO_BASE			= GPIO_BASE_OFS div BCM270x_RegSizInByte;
  GPFSEL			= GPIO_BASE+$00;
  GPSET				= GPIO_BASE+$07; // Register Index: set   bits which are 1 ignores bits which are 0 
  GPCLR				= GPIO_BASE+$0a; // Register Index: clear bits which are 1 ignores bits which are 0  
  GPLEV				= GPIO_BASE+$0d;
  GPEDS				= GPIO_BASE+$10; // Pin Event Detection 
  GPREN				= GPIO_BASE+$13; // Pin RisingEdge  Detection 
  GPFEN				= GPIO_BASE+$16; // Pin FallingEdge Detection 
  GPHEN				= GPIO_BASE+$19; // Pin High Detection 
  GPLEN				= GPIO_BASE+$1c; // Pin Low  Detection 
  GPAREN			= GPIO_BASE+$1f; // Pin Async. RisigngEdge Detection 
  GPAFEN			= GPIO_BASE+$22; // Pin Async. FallingEdge Detection 
  GPPUD				= GPIO_BASE+$25; // Pin Pull-up/down Enable 
  GPPUDCLK			= GPIO_BASE+$26; // Pin Pull-up/down Enable Clock 
  GPTEST			= GPIO_BASE+$29;
  GPIOONLYREAD		= GPLEV;		 // 2x 32Bit Register, which are ReadOnly
  GPIO_BASE_LAST	= GPTEST;

  TIMR_BASE			= (TIMR_BASE_OFS+$400) div BCM270x_RegSizInByte; // Docu Page 196 
  APMLOAD			= TIMR_BASE+0;// 0x00	
  APMVALUE			= TIMR_BASE+1;// 0x04
  APMCTL			= TIMR_BASE+2;// 0x08
  APMIRQCLRACK		= TIMR_BASE+3;// 0x0c	// reading gives always 0x544D5241
  APMRAWIRQ			= TIMR_BASE+4;// 0x10
  APMMaskedIRQ		= TIMR_BASE+5;// 0x14
  APMReload			= TIMR_BASE+6;// 0x18
  APMPreDivider		= TIMR_BASE+7;// 0x1c
  APMFreeRunCounter	= TIMR_BASE+8;// 0x20	// Offset 0x420
  INTR_BASE_LAST	= APMFreeRunCounter;
  TestREG			= APMIRQCLRACK;
  
  STIM_BASE			= STIM_BASE_OFS div BCM270x_RegSizInByte; // SystemTimer
  STIMCS			= STIM_BASE+$00;	//  0
  STIMCLO			= STIM_BASE+$01;	//  4
  STIMCHI			= STIM_BASE+$02;	//  8
  STIMC0			= STIM_BASE+$03;	// 12
  STIMC1			= STIM_BASE+$04;	// 16
  STIMC2			= STIM_BASE+$05;	// 20
  STIMC3			= STIM_BASE+$06;	// 24
  STIM_BASE_LAST	= STIMC3;
  
  I2C0_BASE			= I2C0_BASE_OFS div BCM270x_RegSizInByte;
  I2C0_C			= I2C0_BASE+$00;  //  0
  I2C0_S			= I2C0_BASE+$01;  //  4
  I2C0_DLEN			= I2C0_BASE+$02;  //  8
  I2C0_A			= I2C0_BASE+$03;  //  0x0c
  I2C0_FIFO			= I2C0_BASE+$04;  //  0x10
  I2C0_DIV			= I2C0_BASE+$05;  //  0x14
  I2C0_DEL			= I2C0_BASE+$06;  //  0x18
  I2C0_CLKT			= I2C0_BASE+$07;  //  0x1c
  I2C0_BASE_LAST	= I2C0_CLKT;
  
  I2C1_BASE			= I2C1_BASE_OFS div BCM270x_RegSizInByte;
  I2C1_C			= I2C1_BASE+$00;  //  0
  I2C1_S			= I2C1_BASE+$01;  //  4
  I2C1_DLEN			= I2C1_BASE+$02;  //  8
  I2C1_A			= I2C1_BASE+$03;  //  0x0c
  I2C1_FIFO			= I2C1_BASE+$04;  //  0x10
  I2C1_DIV			= I2C1_BASE+$05;  //  0x14
  I2C1_DEL			= I2C1_BASE+$06;  //  0x18
  I2C1_CLKT			= I2C1_BASE+$07;  //  0x1c
  I2C1_BASE_LAST	= I2C1_CLKT;
  
  I2C2_BASE			= I2C2_BASE_OFS div BCM270x_RegSizInByte;
  I2C2_C			= I2C2_BASE+$00;  //  0
  I2C2_S			= I2C2_BASE+$01;  //  4
  I2C2_DLEN			= I2C2_BASE+$02;  //  8
  I2C2_A			= I2C2_BASE+$03;  //  0x0c
  I2C2_FIFO			= I2C2_BASE+$04;  //  0x10
  I2C2_DIV			= I2C2_BASE+$05;  //  0x14
  I2C2_DEL			= I2C2_BASE+$06;  //  0x18
  I2C2_CLKT			= I2C2_BASE+$07;  //  0x1c
  I2C2_BASE_LAST	= I2C2_CLKT;
  
  SPI0_BASE			= SPI0_BASE_OFS div BCM270x_RegSizInByte;
  SPI0_CS 			= SPI0_BASE+$00; //  0
  SPI0_FIFO	  		= SPI0_BASE+$01; //  4
  SPI0_CLK	  		= SPI0_BASE+$02; //  8
  SPI0_DLEN	  		= SPI0_BASE+$03; //  0x0c
  SPI0_LTOH	  		= SPI0_BASE+$04; //  0x10
  SPI0_DC	  		= SPI0_BASE+$05; //  0x14
  SPI0_BASE_LAST	= SPI0_DC;
  
  PWM_BASE			= PWM_BASE_OFS div BCM270x_RegSizInByte;
  PWMCTL 			= PWM_BASE+$00;	//  0
  PWMSTA	  		= PWM_BASE+$01; //  4
  PWMDMAC	  		= PWM_BASE+$02; //  8
  PWM0RNG 	 		= PWM_BASE+$04; // 0x10
  PWM0DAT   		= PWM_BASE+$05; // 0x14
  PWM0FIF   		= PWM_BASE+$06; // 0x18
  PWM1RNG	  		= PWM_BASE+$08; // 0x20
  PWM1DAT   		= PWM_BASE+$09; // 0x24
  PWM_BASE_LAST		= PWM1DAT;
 
  GMGPxCTL_BASE		= CLK_BASE_OFS div BCM270x_RegSizInByte; // Manual Page 107ff
  GMGP0CTL			= GMGPxCTL_BASE+$1c;// 0x2010 1070
  GMGP0DIV			= GMGPxCTL_BASE+$1d;// 0x2010 1074
  GMGP1CTL			= GMGPxCTL_BASE+$1e;// 0x2010 1078
  GMGP1DIV			= GMGPxCTL_BASE+$1f;// 0x2010 107c
  GMGP2CTL			= GMGPxCTL_BASE+$20;// 0x2010 1080
  GMGP2DIV			= GMGPxCTL_BASE+$21;// 0x2010 1084
  GMGP_BASE_LAST	= GMGP2DIV;

  PWMCLK_BASE		= CLK_BASE_OFS div BCM270x_RegSizInByte;	// Manual Page 107ff
  PWMCLKCTL 		= PWMCLK_BASE+$28;  //160 0xA0
  PWMCLKDIV  		= PWMCLK_BASE+$29;  //164 0xA4
  PWMCLK_BASE_LAST	= PWMCLKDIV;
  
  PWM_MS_MODE		= $80;
  PWM_USEFIFO		= $10;
  PWM_POLARITY		= $08;
  PWM_RPTL			= $04;
  PWM_SERIALIZER	= $02;
  
  PWM1_MS_MODE    	= $8000;  // Run in MS mode
  PWM1_USEFIFO    	= $2000;  // Data from FIFO
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
  
  PWM_DIVImax		= $0fff;  // 12Bit
  PWM_DIVImin		= 32;  	  // default
  
  BCM_PWD			= $5A000000;
  
  ENC_cnt			= 2;	  // Encoder Count
  ENC_SyncTime_c	= 10;	  // max. interval /sync. response time of device in msec
  ENC_sleeptime_def	= 50;
  
  TRIG_SyncTime_c	= 10;
    
  SERVO_FRQ=  50;								  // Servo SG90 frequency (Hz) for PWM
  SERVO_Speed=100; 						  	      // Datasheet Value:0.1s/60degree
  SRVOMINANG=-90; SRVOMIDANG=0;   SRVOMAXANG= 90; // Servo SG90 Datasheet Values (Angles in degree)
//SRVOMINDC=1000; SRVOMIDDC=1500; SRVOMAXDC=2000; // Servo SG90 Datasheet Values (us)
  SRVOMINDC= 600; SRVOMIDDC=1600; SRVOMAXDC=2600; // Servo SG90 Values found experimentally (us)
  
//LOG_All =1; LOG_DEBUG = 2; LOG_INFO =  10; Log_NOTICE = 20; Log_WARNING = 50; Log_ERROR = 100; Log_URGENT = 250; LOG_NONE = 254;   

//source: http://I2C-tools.sourcearchive.com/documentation/3.0.3-5/I2C-dev_8h_source.html 
  I2C_path_c		 = '/dev/i2c-';
  I2C_max_bus        = 1;
  I2C_max_buffer     = 32;
  I2C_unvalid_addr	 = $ff;
  I2C_UseNoReg		 = $ffff;  {  use this as Read/Write register, 
							      if I2C device has no registers (RD/WR only one value)
							      like the pressure sensor HDI M500 }
  I2C_M_TEN          = $0010;  // we have a ten bit chip address 
  I2C_M_WR			 = $0000;
  I2C_M_RD           = $0001;
  I2C_M_NOSTART      = $4000;
  I2C_M_REV_DIR_ADDR = $2000;
  I2C_M_IGNORE_NAK   = $1000;
  I2C_M_NO_RD_ACK    = $0800;
  I2C_M_RECV_LEN     = $0400;  // length will be first received byte
  
  I2C_RETRIES        = $0701; // number of times a device address should be polled when not acknowledging
  I2C_TIMEOUT        = $0702; // set timeout - call with int            
  I2C_SLAVE          = $0703; // Change slave address                   
                              // Attn.: Slave address is 7 or 10 bits   
  I2C_SLAVE_FORCE    = $0706; {  Change slave address                   
                                 Attn.: Slave address is 7 or 10 bits   
                                 This changes the address, even if it 
                                 is already taken! }
  I2C_TENBIT         = $0704; // 0 for 7 bit addrs, != 0 for 10 bit     

  I2C_FUNCS          = $0705; // Get the adapter functionality          
  I2C_RDWR           = $0707; // Combined R/W transfer (one stop only)
  I2C_PEC            = $0708; // != 0 for SMBus PEC                     
  I2C_SMBUS          = $0720; // SMBus-level access                     
    
  I2C_CTRL_REG		 =  0; 	  // Register Indexes
  I2C_STATUS_REG	 =  1;
  I2C_DLEN_REG		 =  2;
  I2C_A_REG			 =  3;
  I2C_FIFO_REG		 =  4;
  I2C_DIV_REG		 =  5;
  I2C_DEL_REG		 =  6;
  I2C_CLKT_REG		 =  7;
  
//to determine what functionality is present 
  I2C_FUNC_I2C                    = $00000001;
  I2C_FUNC_10BIT_ADDR             = $00000002;
  I2C_FUNC_PROTOCOL_MANGLING      = $00000004; // I2C_M_[REV_DIR_ADDR,NOSTART,..] 
  I2C_FUNC_SMBUS_PEC              = $00000008;
  I2C_FUNC_SMBUS_BLOCK_PROC_CALL  = $00008000; // SMBus 2.0 
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
  I2C_FUNC_SMBUS_READ_I2C_BLOCK   = $04000000; // I2C-like block xfer  
  I2C_FUNC_SMBUS_WRITE_I2C_BLOCK  = $08000000; // w/ 1-byte reg. addr.  
  I2C_FUNC_SMBUS_BYTE             = I2C_FUNC_SMBUS_READ_BYTE       or I2C_FUNC_SMBUS_WRITE_BYTE;
  I2C_FUNC_SMBUS_BYTE_DATA        = I2C_FUNC_SMBUS_READ_BYTE_DATA  or I2C_FUNC_SMBUS_WRITE_BYTE_DATA;
  I2C_FUNC_SMBUS_WORD_DATA        = I2C_FUNC_SMBUS_READ_WORD_DATA  or I2C_FUNC_SMBUS_WRITE_WORD_DATA;
  I2C_FUNC_SMBUS_BLOCK_DATA       = I2C_FUNC_SMBUS_READ_BLOCK_DATA or I2C_FUNC_SMBUS_WRITE_BLOCK_DATA;
  I2C_FUNC_SMBUS_I2C_BLOCK        = I2C_FUNC_SMBUS_READ_I2C_BLOCK  or I2C_FUNC_SMBUS_WRITE_I2C_BLOCK;  

  RPI_I2C_general_purpose_bus_c=1;  
    
  USB_IOC_MAGIC     = 'U';
  SPI_IOC_MAGIC     = 'k';
  RTC_MAGIC 		= 'p';
  SPI_CPHA			= $01;
  SPI_CPOL			= $02;
  SPI_MODE_0		= $00;
  SPI_MODE_1		= SPI_CPHA;
  SPI_MODE_2		= SPI_CPOL;
  SPI_MODE_3		= SPI_CPOL or SPI_CPHA;
  
  spi_path_c		= '/dev/spidev';
  spi_max_bus    	= 0;
  spi_max_dev	 	= 1; 
  SPI_BUF_SIZE_c 	= 64;
  SPI_unvalid_addr	=$ffff;
  SPI_Speed_c		=10000000; 
    
  _IOC_NONE   	 	=$00; _IOC_WRITE 	 =$01; _IOC_READ	  =$02;
  _IOC_NRBITS    	=  8; _IOC_TYPEBITS  =  8; _IOC_SIZEBITS  = 14; _IOC_DIRBITS  =  2;
  _IOC_NRSHIFT   	=  0; 
  _IOC_TYPESHIFT 	= (_IOC_NRSHIFT+  _IOC_NRBITS); 
  _IOC_SIZESHIFT 	= (_IOC_TYPESHIFT+_IOC_TYPEBITS);
  _IOC_DIRSHIFT  	= (_IOC_SIZESHIFT+_IOC_SIZEBITS);
  
  c_max_Buffer   	= 128;  // was 024 
  ERR_MAXCNT		=   5;
  ERR_AutoResetMSec	=2000;	// AutoReset of Errors in msec. 0=noReset
  NO_ERRHNDL		=  -1;
  NO_TEST        	= NO_ERRHNDL;

  RTC_RD_TIME 		= $40247009; 	//-2145095671;
  RTC_SET_TIME 		= $4024700A;	// 1076129802;
     
//consts for PseudoTerminal IO (/dev/ptmx)
  Terminal_MaxBuf = 1024; 
  NCCS 		=32;
  
  TCSANOW 	=0; 			// make change immediate 
  TCSADRAIN =1; 			// drain output, then change 
  TCSAFLUSH =2; 			// drain output, flush input 
  TCSASOFT 	=$10; 			// flag - don't alter h.w. state 
  
  ECHOKE 	= $1; 			// visual erase for line kill 
  ECHOE 	= $2; 			// visually erase chars 
  ECHOK 	= $4; 			// echo NL after line kill 
  ECHO 		= $8; 			// enable echoing 
  ECHONL 	= $10; 			// echo NL even if ECHO is off 
  ECHOPRT 	= $20; 			// visual erase mode for hardcopy 
  ECHOCTL 	= $40; 			// echo control chars as ^(Char) 
  ISIG 		= $80; 			// enable signals INTR, QUIT, [D]SUSP 
  ICANON 	= $100; 		// canonicalize input lines 
  ALTWERASE = $200; 		// use alternate WERASE algorithm 
  IEXTEN 	= $400; 		// enable DISCARD and LNEXT 
  EXTPROC 	= $800; 		// external processing 
  TOSTOP 	= $400000; 		// stop background jobs from output 
  FLUSHO 	= $800000; 		// output being flushed (state) 
  NOKERNINFO= $2000000; 	// no kernel output from VSTATUS 
  PENDIN 	= $20000000; 	// XXX retype pending input (state) 
  NOFLSH 	= $80000000;	// don't flush after interrupt 
  
  RPI_hal_dscl			=20;
    
type
  t_ErrorLevel=(LOG_All,LOG_DEBUG,LOG_INFO,Log_NOTICE,Log_WARNING,Log_ERROR,Log_URGENT,LOG_NONE); 
//t_port_flags order is important, do not change. Ord(t_port_flags) will be used to set ALT-Bits in GPFSELx Registers.
// ORD:				   0,     1,   2,   3,   4,   5,   6,   7,    8,    9      10
  t_port_flags  = (	INPUT,OUTPUT,ALT5,ALT4,ALT0,ALT1,ALT2,ALT3,PWMHW,PWMSW,control,
					FRQHW,Simulation,PullUP,PullDOWN,RisingEDGE,FallingEDGE,ReversePOLARITY);  
  s_port_flags  = set of t_port_flags;
  t_initpart	= (InitHaltOnError,InitGPIO,InitI2C,InitSPI);
  s_initpart  	= set of t_initpart;
  t_IOBusType	= (UnknDev,I2CDev,SPIDev);
  t_PowerSwitch	= ( ELRO,Sartano,Nexa,Intertechno,FS20);
  t_rpimaintflags=(	UpdExec,UpdPKGGet,UpdPKGInstal,UpdUpload,UpdDownload,
  					UpdProtoHTTP,UpdProtoRAW,UAgent,UpdNoRedoRequest,
  					UpdNOP,UpdSSL,UpdVerbose,UpdNoProgressBar,UpdLogAppend,UpdNoFTPDefaults,
  					UpdSUDO,UpdErrVerbose,UpdNoCreateDir,UpdDBG1,UpdDBG2);  
  s_rpimaintflags=set of t_rpimaintflags;
  t_MemoryMapPtr= ^t_MemoryMap;
  t_MemoryMap	= array[0..BCM270x_RegMaxIdx] of longword; // for 32 Bit access 
  buftype 		= array[0..c_max_Buffer-1] of byte;
  
  cint = longint; cuint= longword;
  
  Thread_Ctrl_t=record	 
	ThreadID:		TThreadID; //PtrUInt; 
	ThreadRunning,
	TermThread:		boolean;
	ThreadCmdStr:	string;
	ThreadRetCode:	integer;
	ThreadProgress:	integer;
	ThreadPara:		array[0..4] of integer;
  end;
  
  ERR_MGMT_t = record
    addr:word;
	RDerr,WRerr,CMDerr,MAXerr,AutoReset_ms:longword;
	TSok,TSokOld,TSerr,TSerrOld:TDateTime;
	desc:string[RPI_hal_dscl];
  end;
  
  HAT_Struct_t = record
    uuid,vendor,product,snr:string;
    product_id,product_ver:longword;
    available:boolean;
  end;
  
  rtc_time_t = record
    tm_sec,tm_min,tm_hour,tm_mday,tm_mon,tm_year,tm_wday,tm_yday,tm_isdst:longint;
  end;
  
  HW_DevicePresent_t = record
    hndl:integer;
    DevType:t_IOBusType;
    present:boolean;
    BusNum,HWAddr:integer;
    descr:string[RPI_hal_dscl];
    data:string;
  end;
  
  I2C_databuf_ptr = ^I2C_databuf_t;
  I2C_databuf_t = record
	buf: 	string[c_max_Buffer];
	hdl: 	cint;
  end;
  
  I2C_msg_ptr = ^I2C_msg_t;
  I2C_msg_t = record
    addr:	word;
	flags:	word;
	len:	word;
	bptr:	I2C_databuf_ptr;
  end;
  
  I2C_rdwr_ioctl_data_t = record
    msgs:	I2C_msg_ptr;
	nmsgs:	byte;
  end;
  
  PWM_struct_t = record
  	pwm_mode		: byte;
	pwm_sigalt		: boolean;
	pwm_dutycycle_us,
	pwm_restcycle_us,
	pwm_period_us,
	pwm_period_ms,
	pwm_dutyrange,
	pwm_value		: longword;	
	pwm_dtycycl,				// 0-1 // 0%-100%
	pwm_freq_hz		: real;
  end;
  
  GPIO_ptr	   = ^GPIO_struct_t;
  GPIO_struct_t = record
    description		: string[RPI_hal_dscl];
    gpio,HWPin,
	idxofs_1Bit,
	idxofs_3Bit,nr	: longint;
	regget,
	regset,regclr,
	mask_pol,
	mask_3Bit,
	mask_1Bit		: longword;
	initok,ein		: boolean;
	ThreadCtrl		: Thread_Ctrl_t;
	FRQ_freq_Hz		: real;
	FRQ_CTLIdx,
	FRQ_DIVIdx		: longword;
	PWM				: PWM_struct_t;
	portflags		: s_port_flags;
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
    int_enable 				: boolean; // if INT occures, INT Routine will be started or not 
	int_cnt,
    int_cnt_raw				: longword;
	enter_isr_time			: TDateTime;
	last_isr_servicetime	: int64;
  end;
    
  SERVO_struct_t = record
    HWAccess		: GPIO_struct_t;	// e.g. SG90 Micro Servo
	min_angle,							// -90 Degree	(max left turn)
	mid_angle,							//   0 Degree	(mid/neutral position)
	max_angle,							//  90 Degree	(max right turn)	
	speed60deg,							// Servo operating speed in msec for 60deg movement
	angle_current	: longint;
	period_us,							// Servo Period in us: 20000 (1000000 div 50Hz)
	min_dutycycle,						// 1  ms	@ 50Hz
	mid_dutycycle,						// 1.5ms
	max_dutycycle	: longword;			// 2  ms
  end;
  
  ENC_ptr = ^ENC_struct_t;
  ENC_CNT_struct_t = record	  
    Handle:integer;
    ENC_activity:boolean;
    switchcounter,switchcounterold,switchcountermax,
    counter,counterold,countermax:longint;
    encsteps,swsteps:longint;
    enc,encold,encFreq:real;
    fSyncTime:TDateTime;
    steps_per_cycle:byte;
    fcnt,fcntold,fdet_ms:longword;
  end; 
  ENC_struct_t = record					// Encoder data structure
    ENC_CS : TRTLCriticalSection;
	SyncTime: TDateTime;				// for syncing max. device queries
//  ENCptr:ENC_ptr; 
	ThreadCtrl:Thread_Ctrl_t;
	A_Sig,B_Sig,S_Sig:GPIO_struct_t;
	a,b,seq,seqold,deltaold,delta:longint;
	idxcounter,cycles,sleeptime_ms:longword;
	beepgpio:integer;
	ok,s2minmax:boolean;
	CNTInfo:ENC_CNT_struct_t;
	desc:string[RPI_hal_dscl];
  end;
  
  TRIG_ptr		= ^TRIG_struct_t;
  TRIG_struct_t = record
    TRIG_CS:	TRTLCriticalSection;
  	SyncTime:	TDateTime; 
	SyncTime_ms,
	tim_ms:		longword;
	flg:		boolean;
    TGPIO:		GPIO_struct_t;
	ThreadCtrl:	Thread_Ctrl_t;
	desc:		string[RPI_hal_dscl];
  end;  
      
  SPI_databuf_t = record
    reg:	byte;
//  buf: 	array[0..(SPI_BUF_SIZE_c-1)] of byte;
	buf: 	string[SPI_BUF_SIZE_c];
	posidx,
	endidx:	longint;
  end;
  
  spi_ioc_transfer_t = record  	// sizeof(spi_ioc_transfer_t) = 32
    tx_buf_ptr		: qword;	// Ptr to tx buffer
    rx_buf_ptr		: qword;	// Ptr to rx buffer
    len				: longword;	// # of bytes
	speed_hz    	: longword;	// Clock rate in Hz
    delay_usecs		: word;		// in msec
    bits_per_word	: byte;	
    cs_change		: byte;		// apply chip select
    pad				: longword;
  end;
  
  SPI_Bus_Info_t = record
	spi_speed		: longword;
  end;
 	
  SPI_Device_Info_t = record
	errhndl			: integer;
	spi_path 		: string;
	spi_fd   		: cint;
	spi_LSB_FIRST	: byte;     // Zero indicates MSB-first; other values indicate the less common LSB-first encoding.
	spi_bpw  		: byte; 	// bits per word 
	spi_delay 		: word; 	// delay usec 
	spi_speed 		: longword;	// spi speed in Hz 
	spi_cs_change  	: byte;     
	spi_mode  		: byte;     // 0..3 
	spi_IOC_mode	: longword; 
	dev_GPIO_ook,
	dev_GPIO_en 	: integer;
	isr_enable		: boolean;  // decides, establish and prepare INT-Environment. If false, then polling 
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
  
  PID_float_t  = real; // extended
  PID_Struct_t = record
	   PID_FirstTime,PID_IntImprove,PID_DifImprove,PID_LimImprove:boolean;
	   PID_cnt,PID_SampleTime_ms: longword;
       PID_Kp, PID_Ki, PID_Kd,
       PID_Integrated, PID_PrevInput,
       PID_MinOutput,  PID_MaxOutput,
       PID_PrevAbsError,
	   PID_Delta: PID_float_t;
	   PID_LastTime: TDateTime;
  end;
  
  T_IniFileDesc = record
	inifilbuf			: TIniFile;
	inifilename			: string;
	ok					: boolean;
  end;
  	       
var 
  mmap_arr:t_MemoryMapPtr;  
  CurlThreadCtrl:Thread_Ctrl_t;
  HighPrecisionMillisecondFactor:Int64=1000; 
  HighPrecisionMicrosecondFactor:Int64=1; 
  HighPrecisionTimerInit:boolean=false;
  SPI_ClkWritten:boolean=false;
  mem_fd:integer; 
  rtc_time:rtc_time_t; 
  _TZLocal:longint; _TZOffsetString:string[10];
  IniFileDesc:T_IniFileDesc;
  RpiMaintCmd:TIniFile;
  USBDEVFS_RESET,
  SPI_IOC_RD_MODE,SPI_IOC_WR_MODE,SPI_IOC_RD_LSB_FIRST,SPI_IOC_WR_LSB_FIRST,
  SPI_IOC_RD_BITS_PER_WORD,SPI_IOC_WR_BITS_PER_WORD,SPI_IOC_RD_MAX_SPEED_HZ,
  SPI_IOC_WR_MAX_SPEED_HZ:longword;
  
  spi_bus: 		array[0..spi_max_bus]	of SPI_Bus_Info_t;
  spi_dev:		array[0..spi_max_bus,
					  0..spi_max_dev]	of SPI_Device_Info_t;
  spi_buf:		array[0..spi_max_bus,
					  0..spi_max_dev]	of SPI_databuf_t; 
  I2C_buf:		array[0..I2C_max_bus]	of I2C_databuf_t; 
  
  ENC_struct: 	array					of ENC_struct_t;
  TRIG_struct: 	array					of TRIG_struct_t;
  SERVO_struct: array					of SERVO_struct_t;
  ERR_MGMT: 	array					of ERR_MGMT_t;
 
function  RPI_HW_Start:boolean; // start all. GPIO,I2C and SPI
function  RPI_HW_Start(initpart:s_initpart):boolean; // start dedicated parts. e.g. RPI_HW_Start([InitGPIO,InitI2C,InitSPI]); 
 
{$IFDEF UNIX} procedure GPIO_int_test; {$ENDIF}	// only for test   
procedure GPIO_PIN_TOGGLE_TEST; // just for demo reasons, call it from your own program. Be careful, it toggles GPIO pin 16 -> StatusLED }
procedure GPIO_Test(HWPinNr:longword; flags:s_port_flags);
procedure GPIO_TestAll;		// Test All GPIOs as OUTPUTs!!!
procedure GPIO_PWM_Test;	// Test with GPIO18 PWM0 on Connector Pin12
procedure GPIO_PWM_Test(gpio:longint; HWPWM:boolean; freq_Hz:real; dutyrange,startval:longword);
procedure FRQ_Test; 		// Test with GPIO4. 100kHz
procedure ENC_Test; 		// Encoder Test HWPins:15,16,18 
procedure SERVO_Test;		// Servo   Test HWPins:12,16,18 // GPIOs:18,23,24 
procedure SPI_Test; 
procedure SPI_Loop_Test;	
procedure I2C_test; 
procedure MEM_SpeedTest;
procedure CLK_Test;
procedure BIOS_Test;		// shows the usages of a config file
	 
function  BCM_GETREG(regidx:longword):longword;
procedure BCM_SETREG(regidx,newval:longword);  
procedure BCM_SETREG(regidx,newval:longword; and_mask,readmodifywrite:boolean);

function  RPI_Piggyback_board_available  : boolean;  
function  RPI_PiFace_board_available(devadr:byte) : boolean;  
function  RPI_run_on_known_hw:boolean;  
function  RPI_platform_ok:boolean;   			
function  RPI_mmap_run_on_unix:boolean;  
function  RPI_run_on_ARM:boolean; 
function  RPI_mmap_get_info (modus:longint)  : longword;
procedure RPI_HDR_SetDesc(HWPin:longint; desc:string);
procedure RPI_show_all_info;
procedure RPI_show_SBC_info;

function  ERR_NEW_HNDL(adr:word; descr:string; maxerrs,AutoResetMsec:longword):integer; 
function  ERR_MGMT_STAT(errhdl:integer):boolean;
function  ERR_MGMT_GetErrCnt(errhdl:integer):longword;
procedure ERR_MGMT_UPD(errhdl:integer; cmdcode,datalgt:byte; modus:boolean);
procedure Toggle_STATUSLED_very_fast;
 
procedure LED_Status    (ein:boolean); 		 // Switch Status-LED on or off

function  OSC_Setup(_gpio:longint; pwm_freq_Hz,pwm_dty:real):boolean;
function  FRQ_Setup		(var GPIO_struct:GPIO_struct_t; freq_Hz:real):boolean;
procedure FRQ_End		(var GPIO_struct:GPIO_struct_t);
function  TIM_Setup(timr_freq_Hz:real):real;
procedure TIM_Test; // 1MHz

procedure PWM_SetStruct (var GPIO_struct:GPIO_struct_t);  // set default values
procedure PWM_SetStruct (var GPIO_struct:GPIO_struct_t; mode:byte; freq_Hz:real; dutyrange,startval:longword);
function  PWM_Setup     (var GPIO_struct:GPIO_struct_t):boolean;
procedure PWM_Write     (var GPIO_struct:GPIO_struct_t; value:longword); // value: 0-1023
procedure PWM_SetClock  (var GPIO_struct:GPIO_struct_t); // same clock for PWM0 and PWM1. Needs only to be set once
procedure PWM_End		(var GPIO_struct:GPIO_struct_t);
function  PWM_GetDtyRangeVal(var GPIO_struct:GPIO_struct_t; DutyCycle:real):longword;
function  PWM_GetMaxFreq(dutycycle:longword):longword;
function  PWM_GetMaxDtyC(freq:real):longword;
function  PWM_GetDRVal  (percent:real; dutyrange:longword):longword; 

procedure GPIO_ShowStruct(var GPIO_struct:GPIO_struct_t);
procedure GPIO_SetStruct(var GPIO_struct:GPIO_struct_t); // set default values
procedure GPIO_SetStruct(var GPIO_struct:GPIO_struct_t; num,gpionum:longint; desc:string; flags:s_port_flags);
procedure GPIO_Switch	(var GPIO_struct:GPIO_struct_t); // Read GPIOx Signal in Struct
procedure GPIO_Switch   (var GPIO_struct:GPIO_struct_t; switchon:boolean);
function  GPIO_Setup    (var GPIO_struct:GPIO_struct_t):boolean;

function  GPIO_MAP_GPIO_NUM_2_HDR_PIN(gpio:longword; mapidx:byte):longint; // Maps GPIO Number to the HDR_PIN 
function  GPIO_MAP_GPIO_NUM_2_HDR_PIN(gpio:longword):longint;
function  GPIO_MAP_HDR_PIN_2_GPIO_NUM(hdr_pin_number:longint; mapidx:byte):longint; // Maps HDR_PIN to the GPIO Number 
function  GPIO_MAP_HDR_PIN_2_GPIO_NUM(hdr_pin_number:longint):longint;

procedure GPIO_set_HDR_PIN(hw_pin_number:longword;highlevel:boolean); // Maps PIN to the GPIO Header 
function  GPIO_get_HDR_PIN(hw_pin_number:longword):boolean; // Maps PIN to the GPIO Header 

function  GPIO_FCTOK(gpio:longint; flags:s_port_flags):boolean;
procedure GPIO_set_pin     (gpio:longword;highlevel:boolean); // Set RPi GPIO pin to high or low level; Speed @ 700MHz ->  0.65MHz
function  GPIO_get_PIN     (gpio:longword):boolean; // Get RPi GPIO pin Level is true when Pin level is '1'; false when '0'; Speed @ 700MHz ->  1.17MHz 
procedure GPIO_Pulse	   (gpio,pulse_ms:longword);

procedure GPIO_set_input   (gpio:longword);         // Set RPi GPIO pin to input  direction 
procedure GPIO_set_output  (gpio:longword);         // Set RPi GPIO pin to output direction 
procedure GPIO_set_ALT     (gpio:longword; altfunc:t_port_flags); // Set RPi GPIO pin to ALT0..ALT5 
procedure GPIO_set_PINMODE (gpio:longword; portfkt:t_port_flags);
procedure GPIO_set_PULLUP  (gpio:longword; enable:boolean); // enable/disable PullUp
procedure GPIO_set_PULLDOWN(gpio:longword; enable:boolean); // enable/disable PullDown
procedure GPIO_set_edge_rising (gpio:longword; enable:boolean); // Pin RisingEdge  Detection Register (GPREN)
procedure GPIO_set_edge_falling(gpio:longword; enable:boolean); // Pin FallingEdge Detection Register (GPFEN)
procedure GPIO_get_mask_and_idx(regidx,gpio:longword; var idxabs,mask:longword);
{$IFDEF UNIX} 
function  GPIO_set_int    (var isr:isr_t; GPIO_num:longint; isr_proc:TFunctionOneArgCall; flags:s_port_flags):integer; // set up isr routine, GPIO_number, int_routine which have to be executed, rising or falling_edge
function  GPIO_int_release(var isr:isr_t) : integer;
procedure GPIO_int_enable (var isr:isr_t); 
procedure GPIO_int_disable(var isr:isr_t); 
function  GPIO_int_active (var isr:isr_t):boolean;
{$ENDIF}
procedure GPIO_show_regs;
procedure pwm_show_regs;
procedure q4_show_regs;
procedure Clock_show_regs;
function  GPIO_get_desc(regidx,regcontent:longword) : string;  
procedure GPIO_ShowConnector;
procedure GPIO_ConnectorStringList(tl:TStringList);

function  ENC_GetHdl		(descr:string):byte;
procedure ENC_InfoInit		(var CNTInfo:ENC_CNT_struct_t);
function  ENC_Setup			(hdl:integer; stick2minmax:boolean; ctrpreset,ctrmax,stepspercycle:longword; beepergpio:integer):boolean;
procedure ENC_End			(hdl:integer);
function  ENC_GetVal		(hdl:byte; ctrsel:integer):real; 
function  ENC_GetVal		(hdl:byte):real; 
function  ENC_GetValPercent	(hdl:byte):real; 
function  ENC_GetSwitch		(hdl:byte):real;
function  ENC_GetCounter	(var ENCInfo:ENC_CNT_struct_t; ctrsel:integer):boolean;
procedure ENC_IncEncCnt		(var ENCInfo:ENC_CNT_struct_t; cnt:integer);
procedure ENC_IncSwCnt		(var ENCInfo:ENC_CNT_struct_t; cnt:integer);
  
function  TRIG_Reg(gpio:longint; descr:string; flags:s_port_flags; synctim_ms:longword):integer;
procedure TRIG_End(hdl:integer); 
procedure TRIG_SetValue(hdl:integer; timesig_ms:longword);
function  TRIG_GetValue(hdl:integer; var timesig_ms:longword):integer;

procedure SERVO_Setup(var SERVO_struct:SERVO_struct_t; 
						HWPinNr,nr,maxval,
						dcmin,dcmid,dcmax:longword; 
						angmin,angmid,angmax,speed:longint;
						desc:string; freq:real; flags:s_port_flags);
procedure SERVO_SetStruct(var SERVO_struct:SERVO_struct_t; dty_min,dty_mid,dty_max:longword; ang_min,ang_mid,ang_max,speed:longint);
procedure SERVO_Write(var SERVO_struct:SERVO_struct_t; angle:longint; syncwait:boolean);
procedure SERVO_End(var SERVO_struct:SERVO_struct_t);

procedure BIOS_ReadIniFile(fname:string);
procedure BIOS_EndIniFile;
procedure BIOS_UpdateFile; 
procedure BIOS_SetCacheUpdate(upd:boolean);
function  BIOS_GetIniString(section,name,default:string; secret:boolean):string;
function  BIOS_SetIniString(section,name,value:string; secret:boolean):boolean;	
procedure BIOS_DeleteKey(section,name:string);
procedure BIOS_EraseSection(section:string);

function  RPI_snr :string; // 0000000012345678 
function  RPI_hw  :string; // BCM2708 
function  RPI_proc:string; // ARMv6-compatible processor rev 7 (v6l) 
function  RPI_mips:string; // 697.95 
function  RPI_feat:string; // swp half thumb fastmult vfp edsp java tls 
function  RPI_rev :string; // rev1;256MB;1000002 
function  RPI_freq:string; // 700000;700000;900000;Hz  	
function  RPI_revnum:byte; // 1:rev1; 2:rev2; 0:error 
function  RPI_gpiomapidx:byte; // 1:rev1; 2:rev2; 3:B+; 0:error 
function  RPI_BCM2835:boolean;
function  RPI_BCM2835_GetNodeValue(node:string; var nodereturn:string):longint;
function  RPI_status_led_GPIO:byte;	// give GPIO_NUM of Status LED
function  RPI_I2C_busnum(func:byte):byte; // get the I2C busnumber, where e.g. the general purpose devices are connected. This depends on rev1 or rev2 board . e.g. RPI_I2C_busnum(RPI_I2C_general_purpose_bus_c) 
function  RPI_I2C_busgen:byte;  // general purpose bus
function  RPI_I2C_bus2nd:byte;  // 2.nd I2C bus
function  RPI_I2C_GetSpeed(bus:byte):longint;
function  RPI_hdrpincount:byte; // connector_pin_count on HW Header
function  RPI_GetBuildDateTimeString:string;
procedure RPI_show_cpu_info;
procedure RPI_MaintDelEnv;
procedure RPI_MaintSetEnvExec(EXECcmd:string);
procedure RPI_MaintSetEnvFTP(FTPServer,FTPUser,FTPPwd,FTPLogf,FTPDefaults:string);
procedure RPI_MaintSetEnvUPL(UplSrcFiles,UplDstDir,UplLogf:string);
procedure RPI_MaintSetEnvDWN(DwnSrcDir,DwnlSrcFiles,DwnDstDir,DwnLogf:string);
procedure RPI_MaintSetEnvUPD(UpdPkgSrcFile,UpdPkgDstDir,UpdPkgDstFile,UpdPkgMaintDir,UpdPkgLogf:string);
function  RPI_Maint(UpdFlags:s_rpimaintflags):integer; 

procedure HAT_EEprom_Map(tl:TStringList; hwname,uuid,vendor,product:string; prodid,prodver,gpio_drive,gpio_slew,gpio_hysteresis,back_power:word; useDefault,EnabIO:boolean);
procedure HAT_EEprom_Map_Test; 
function  HAT_GetInfo(var HAT_Struct:HAT_Struct_t):boolean;
procedure HAT_ShowStruct(var HAT_Struct:HAT_Struct_t);
function  HAT_vendor:string;	
function  HAT_product:string; 	
function  HAT_product_id:string; 
function  HAT_product_ver:string;
function  HAT_uuid:string; 
procedure HAT_Info_Test;

function  rtc_func(fkt:longint; fpath:string; var dattime:TDateTime) : longint;

function  USB_Reset(buspath:string):integer; // e.g. USB_Reset('/dev/bus/usb/002/004');
function  MapUSB(devpath:string):string;     // e.g. MapUSB('/dev/ttyUSB0') -> /dev/bus/usb/002/004

function  I2C_byte_write  (busnum,baseadr,basereg:word; data:byte; errhdl:integer):integer; 
function  I2C_word_write  (busnum,baseadr,basereg:word; data:word; flip:boolean; errhdl:integer):integer; 
function  I2C_word_read   (busnum,baseadr,basereg:word; flip:boolean; errhdl:integer):word; 
function  I2C_string_read (busnum,baseadr,basereg:word; len:byte; errhdl:integer; var outs:string):integer; 
function  I2C_string_write(busnum,baseadr,basereg:word; datas:string; errhdl:integer):integer; 
function  I2C_bus_read    (busnum,baseadr,basereg:word; len:byte; errhdl:integer):integer;
function  I2C_bus_write   (busnum,baseadr:word; errhdl:integer):integer;
function  I2C_ChkBusAdr   (busnum,baseadr:word):boolean; 
procedure I2C_show_struct (busnum:byte);
procedure I2C_Display_struct(busnum:byte; comment:string);
procedure HW_IniInfoStruct(var DeviceStruct:HW_DevicePresent_t);
procedure HW_SetInfoStruct(var DeviceStruct:HW_DevicePresent_t; DevTyp:t_IOBusType; BusNr,HWAdr:integer; dsc:string);
function  I2C_HWT(var DeviceStruct:HW_DevicePresent_t; bus,adr,reg,lgt:word; nv1,nv2,dsc:string):boolean;

function  SPI_HWT(var DeviceStruct:HW_DevicePresent_t; bus,adr,reg,lgt:word; nv1,nv2,dsc:string):boolean;
procedure SPI_ClkWrite(spi_hz:real);
procedure SPI_SetDevErrHndl(busnum,devnum:byte; errhdl:integer);
procedure SPI_SetDevDelay(busnum,devnum:byte; delayus:word);
procedure SPI_SetDevSpeedHz(busnum,devnum:byte; speedHz:longword);
procedure SPI_SetDevCSChange(busnum,devnum:byte; cschange:byte);
function  SPI_Write(busnum,devnum:byte; basereg,data:word):integer;
function  SPI_Read (busnum,devnum:byte; basereg:word) : byte;
function  SPI_Transfer (busnum,devnum:byte; cmdseq:string):integer;
function  SPI_Mode(spifd:cint; mode:longword; pvalue:pointer):integer;
procedure SPI_StartBurst(busnum,devnum:byte; reg:word; writeing:byte; len:longint);
procedure SPI_EndBurst(busnum,devnum:byte);
function  SPI_BurstRead(busnum,devnum:byte):byte;
procedure SPI_BurstWriteBuffer(busnum,devnum,basereg:byte; len:longword);
procedure SPI_BurstRead2Buffer(busnum,devnum,basereg:byte; len:longword);
procedure SPI_show_buffer(busnum,devnum:byte);
procedure SPI_show_dev_info_struct(busnum,devnum:byte);
procedure SPI_show_bus_info_struct(busnum:byte);
procedure SPI_show_struct(var spi_strct:spi_ioc_transfer_t);

procedure BB_OOK_PIN(state:boolean);
procedure BB_SetPin(pinnr:longint); 
function  BB_GetPin:longint; 
procedure BB_SendCode(switch_type:T_PowerSwitch; adr,id,desc:string; ein:boolean);
procedure BB_InitPin(id:string); // e.g. id:'TLP434A' or id:'13'  (direct RPI Pin on HW Header P1 )
procedure MORSE_speed(speed:integer); // 1..5, -1=default_speed
procedure MORSE_tx(s:string);
procedure MORSE_test;
procedure ELRO_TEST;

function  Thread_Start(var ThreadCtrl:Thread_Ctrl_t; funcadr:TThreadFunc; paraadr:pointer; delaymsec:longword; prio:longint):boolean;
function  Thread_End  (var ThreadCtrl:Thread_Ctrl_t; waitmsec:longword):boolean;
procedure Thread_SetName(name:string); 				   
procedure SetTimeOut (var EndTime:TDateTime;TimeOut_ms:Int64);
function  TimeElapsed(var EndTime:TDateTime;Retrig_ms:Int64):boolean;
function  TimeElapsed(EndTime:TDateTime):boolean;
procedure SetTimeOut_us (var hpcntr:int64; Retrig_us:int64);
function  TimeElapsed_us(var hpcntr:int64; Retrig_us:int64):boolean;
function  MicroSecondsBetween(us1,us2:int64):int64;
procedure TimeElapsed_us_Test;
procedure delay_nanos(Nanoseconds:longword);
procedure delay_us   (Microseconds:Int64);	
procedure delay_msec (Milliseconds:longword); 
function  GetHighPrecisionCounter: Int64;  
procedure Log_Write  (typ:T_ErrorLevel;msg:string);  // writes to STDERR
procedure Log_Writeln(typ:T_ErrorLevel;msg:string);  // writes to STDERR
procedure LOG_ShowStringList(typ:T_ErrorLevel; ts:TStringList); 
function  LOG_Get_Level : T_ErrorLevel; 
procedure LOG_Save_Level;   
procedure Log_Set_Level(level:T_ErrorLevel); 
procedure LOG_Restore_Level; 
function  LOG_GetEndMsg(comment:string):string;
function  LOG_GetVersion(version:real):string; 
		
procedure SAY   (typ:T_ErrorLevel; msg:string); // writes to STDOUT
procedure SAY_TL(typ:T_ErrorLevel; tl:TStringList); 
procedure SAY_Set_Level(level:T_ErrorLevel); 
 
function  Upper(const s : string) : String; 
function  Lower(const s : string) : String;
function  Bool2Str(b:boolean) : string; 
function  Bool2LVL(b:boolean) : string; 	 
function  Bool2Dig(b:boolean) : string; 
function  Bool2Swc(b:boolean) : string;	 
function  Bool2OC (b:boolean) : string;
function  Bool2YN (b:boolean) : string;
function  Str2Bool(s:string; var ein:boolean):boolean;
function  Num2Str(num:int64;lgt:byte):string;
function  Num2Str(num:longint; lgt:byte):string;
function  Num2Str(num:longword;lgt:byte):string;
function  Num2Str(num:real;lgt,nk:byte):string;  
function  Str2Num(s:string; var num:byte):boolean;
//function  Str2Num(s:string; var num:integer):boolean;
function  Str2Num(s:string; var num:int64):boolean;
function  Str2Num(s:string; var num:longint):boolean;
function  Str2Num(s:string; var num:longword):boolean;
function  Str2Num(s:string; var num:real):boolean; 
function  Str2Num(s:string; var num:extended):boolean; 
function  Str2DateTime(tdstring,fmt:string):TDateTime;
function  Str2LogLvl(s:string):T_ErrorLevel;
function  LeadingZero(w : Word) : String; 
function  LeadingZeros(l:longint;digits:byte):string;  
function  Bin(q:longword;lgt:Byte) : string; 
function  Hex   (nr:qword;lgt:byte) : string; 
function  HexStr(s:string):string;
function  StrHex(Hex_strng:string):string;
function  AdjZahlDE(r:real;lgt,nk:byte):string;
function  AdjZahl(s:string):string;
function  scale(valin,min1,max1,min2,max2:real):real;
function  Get_FixedStringLen(s:string;cnt:word;leading:boolean):string; 
procedure AskCR(msg:string);
function  SepRemove(s:string):string;
function  Trimme(s:string;modus:byte):string;//modus: 1:adjL 2:adjT 3:AdjLT 4:AdjLMT 5:AdjLMTandRemoveTABs
function  FilterChar(s,filter:string):string;
function  GetNumChar(s:string):string;
function  GetHexChar(s:string):string;
function  ReplaceChars(s,filterchars,replacechar:string):string;
function  RM_CRLF(s:string):string; 
function  GetHostName:string;
function  GetPrintableChars(s:string; c1,c2:char):string;
function  CamelCase(strng:string):string;
function  GetRndTmpFileName:string;
function  Get_FName(fullfilename:string):string; 
function  Get_ExtName(fullfilename:string; extwithdot:boolean):string; 
function  Get_Dir(fullfilename:string):string; 
function  Get_DirList(dirname:string; filelist:TStringList):integer;
function  GetTildePath(fullpath,homedir:string):string;
function  PrepFilePath(fpath:string):string;
function  GetFileAge(filname:string):TDateTime;
function  GetFileAgeInSec(filname:string):int64;
function  FileIsRecent(filepath:string; seconds_old,varianz:longint):boolean;
function  FileIsRecent(filepath:string; seconds_old:longint):boolean;
function  MStream2String(MStreamIn:TMemoryStream):string;
procedure String2MStream(MStreamIn:TMemoryStream; var SourceString:string);
function  MStream2File(filname:string; StreamOut:TMemoryStream):boolean;
function  File2MStream(filname:string;StreamOut:TMemoryStream; var hash:string):boolean;
function  TextFile2StringList(filname:string; StrListOut:TStringList; append:boolean; var hash:string):boolean;
function  StringListAdd2List(StrList1,StrList2:TStringList; append:boolean):longword; 
function  StringListAdd2List(StrList1,StrList2:TStringList):longword; //Adds StringList2 to Stringlist1. result is size of Stringlist in bytes
function  StringList2TextFile(filname:string; StrListOut:TStringList):boolean;
function  StringList2String(StrList:TStringList):string;
function  Anz_Item(const strng,trenner,trenner2:string): longint;
function  Select_Item(const strng,trenner,trenner2:string;itemno:longint) : string;
function  Select_RightItems(const strng,trenner,trenner2:string;startitemno:longint) : string; 
function  Select_LeftItems (const strng,trenner,trenner2:string;enditemno:longint) : string; 
function  StringPrintable(s:string):string; 
procedure ShowStringList(StrList:TStringList); 
function  StringListMinMaxValue(StrList:TStringList; fieldnr:word; tr1,tr2:string; var min,max:extended; var nk:longint):boolean;
function  SearchStringInListIdx(StrList:TStringList; srchstrng:string; occurance,StartIdx:longint):longint;
function  SearchStringInList(StrList:TStringList; srchstrng:string):string;
function  GiveStringListIdx(StrList:TStringList; srchstrng:string; var idx:longint; occurance:longint):boolean;
function  GiveStringListIdx(StrList:TStringList; srchstrngSTART,srchstrngEND:string; var idx:longint):boolean;
procedure MemCopy(src,dst:pointer; size:longint); 
procedure MemCopy(src,dst:pointer; size,srcofs,dstofs:longint);
function  DeltaTime_in_ms(dt1,dt2:TDateTime):int64;
function  CRC8(s:string):byte;
function  MD5_Check(file1,file2:string):boolean;
function  MyMod(a,b:longint):longint;
procedure Set_stty_speed(ttyandspeed:string); // e.g. /dev/ttyAMA0@9600
procedure SetUTCOffset; // time Offset in minutes form GMT to localTime
function  GetUTCOffsetString(offset_Minutes:longint):string; { e.g. '+02:00' } 
function  GetDateTimeUTC   : TDateTime;
function  GetDateTimeLocal:TDateTime; 
function  call_external_prog(typ:t_ErrorLevel; cmdline:string; receivelist:TStringList):integer;
function  call_external_prog(typ:t_ErrorLevel; cmdline:string; var receivestring:string):integer; 
function  PV_Progress(progressfile:string):integer;
function  CURLcmdCreate(usrpwd,proxy,ofil,uri:string; flags:s_rpimaintflags):string;
function  CURL(curlcmd,progressfile:string):integer;
procedure CURL_Test;

{$IFDEF UNIX}
//function  usleep(useconds:cuint):cint; cdecl; external clib name 'unistd';
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
function  FpPrCtl(options:cint; arg2,arg3,arg4,arg5:pointer):cint; cdecl; external clib name 'prctl';
{$ENDIF}

procedure PID_Test;
procedure PID_Init(var PID_Struct:PID_Struct_t; Kp,Ki,Kd,MinOutput,MaxOutput:PID_float_t);
// Initialises the PID engine of "PID_Struct"
// Kp = the "proportional" error multiplier
// Ki = the "integrated value" error multiplier
// Kd = the "derivative" error multiplier
// MinOutput = the minimal value the output value can have (should be < 0)
// MaxOutput = the maximal value the output can have (should be > 0)
procedure PID_Reset(var PID_Struct:PID_Struct_t);
// Re-initialises the PID engine of "PID_Struct" without change of settings
function  PID_Calc(var PID_Struct:PID_Struct_t; Setpoint,InputValue:PID_float_t):PID_float_t;
// To be called at a regular time interval (e.g. every 100 msec)
// Setpoint: the target value for "InputValue" to be reached
// InputValue: the actual value measured in the system
// Functionresult: PID function of (SetPoint-InputValue) of "PID_Struct",
//   a positive value means "InputValue" is too low  (< SetPoint), the process should take action to increase it
//   a negative value means "InputValue" is too high (> SetPoint), the process should take action to decrease it
procedure PID_SetIntImprove(var PID_Struct:PID_Struct_t; On_:boolean);
// Switches on or off the "Integration Improvement" mechanism of "PID_Struct". 
// This mechanism prevents overshoot/ringing/oscillation 
// due to integration. To be used after "PID_Init", which switches off the mechanism for compatibility reasons.
procedure PID_SetDifImprove(var PID_Struct:PID_Struct_t; On_:boolean);
// Switches on or off the "Differentiation Improvement" mechanism of "PID_Struct".
// This mechanism prevents unnecessary correction
// delay when the actual value is changing towards the SetPoint.
// To be used after "PID_Init", which switches off the mechanism for compatibility reasons.
procedure PID_SetLimImprove(var PID_Struct:PID_Struct_t; On_:boolean); 

implementation  

const int_filn_c='/tmp/GPIO_int_setup.sh';   
  	  prog_build_date = {$I %DATE%}; prog_build_time = {$I %TIME%}; 

var LOG_Level,LOG_OLD_Level,SAY_Level:T_ErrorLevel;
    ProgramStartTime:TDateTime;
    restrict2gpio:boolean;
    cpu_rev_num,GPIO_map_idx,I2C_busnum,connector_pin_count,status_led_GPIO:byte;
    cpu_snr,cpu_hw,cpu_proc,cpu_rev,cpu_mips,cpu_feat,cpu_fmin,cpu_fcur,cpu_fmax:string;
	cpu_freq,pll_freq:real;
	BB_pin: longint;
	MORSE_dit_lgt:word; 
	RPIHDR_Desc:array[1..max_pins_c] of string[mdl];
	
function  MyMod(a,b:longint):longint; 
var c:longint; 
begin 
  if b<>0 then begin c:=a mod b; if c<0 then c:=c+b; end else c:=a; 
  MyMod:=c; 
end;
function  RoundUpPow2(nr:real):longword; begin RoundUpPow2:=round(intpower(2,round(log2(nr)))); end;
function  DivRoundUp(n,d:real):longword; begin DivRoundUp:=round((n+d-1)/d); end;	
procedure delay_msec (Milliseconds:longword);  begin if Milliseconds>0 then sysutils.sleep(Milliseconds); end;
function  CRC8(s:string):byte; var i,crc:byte; begin crc:=$00; for i := 1 to Length(s) do crc:=crc xor ord(s[i]); CRC8:=crc; end;
procedure SetTimeOut (var EndTime:TDateTime;TimeOut_ms:Int64); begin EndTime:=IncMilliSecond(now,TimeOut_ms); end;
function  TimeElapsed(EndTime:TDateTime):boolean;              begin TimeElapsed:=(EndTime<=now); end;

function  TimeElapsed(var EndTime:TDateTime; Retrig_ms:Int64):boolean;
var ok:boolean;
begin 
  ok:=(EndTime<=now); 
  if ok then EndTime:=IncMilliSecond(now,Retrig_ms); 
  TimeElapsed:=ok; 
end;

procedure SetTimeOut_us (var hpcntr:int64; Retrig_us:int64);
begin
  hpcntr:=int64(GetHighPrecisionCounter+int64(Retrig_us*HighPrecisionMicrosecondFactor));
end;

function  TimeElapsed_us(var hpcntr:int64; Retrig_us:int64):boolean;
var ok:boolean;
begin 
  ok:=(hpcntr<=GetHighPrecisionCounter);
  if ok then SetTimeOut_us(hpcntr,Retrig_us);
  TimeElapsed_us:=ok;
end;

function  MicroSecondsBetween(us1,us2:int64):int64;
begin MicroSecondsBetween:=int64((us1-us2)*HighPrecisionMicrosecondFactor); end;

procedure TimeElapsed_us_Test;
const retrig_us=1000;
var i,j,n:int64; td:TDateTime;
begin
  writeln('TimeElapsed_us_Test: Start');
  n:=1; td:=now; i:=GetHighPrecisionCounter; j:=i;
  repeat
    if TimeElapsed_us(i,retrig_us) then inc(n);
  until (n>=10000);
  writeln('TimeElapsed_us_Test: ',MilliSecondsBetween(now,td),'ms ',MicroSecondsBetween(i,j),'us');
end;

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

procedure delay_us(Microseconds:int64);
// https://github.com/fundamentalslib/fundamentals5/blob/master/Source/Utils/flcTimers.pas
var i,j,f:int64; n:longint;
begin
  if Microseconds>0 then
  begin
    i:=GetHighPrecisionCounter;
	if Microseconds>900 then
	begin
	  n:= longint((Microseconds-900) div 1000); // number of ms with at least 900us in tight loop
      if n>0 then begin sysutils.sleep(n); end;	
	end;
    f:=int64(Microseconds*HighPrecisionMicrosecondFactor);
    repeat j:=GetHighPrecisionCounter; until (int64(j-i)>=f);
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

function  Str2LogLvl(s:string):T_ErrorLevel;
var lvl:T_ErrorLevel; slvl:string;
begin
  lvl:=LOG_WARNING; slvl:=Upper(s);
  if Pos('ERROR',	slvl)>0 then lvl:=LOG_ERROR; 
  if Pos('WARNING', slvl)>0 then lvl:=LOG_WARNING; 
  if Pos('NOTICE',	slvl)>0 then lvl:=LOG_NOTICE; 
  if Pos('INFO',	slvl)>0 then lvl:=LOG_INFO; 
  if Pos('DEBUG',	slvl)>0 then lvl:=LOG_DEBUG;
  if Pos('URGENT',	slvl)>0 then lvl:=LOG_URGENT;   
  Str2LogLvl:=lvl;
end;

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

// writes to STDOUT
procedure SAY_Set_Level(level:T_ErrorLevel); begin SAY_Level:=level; end;
procedure SAY   (typ:T_ErrorLevel; msg:string); begin if typ>=SAY_Level then writeln(Get_LogString('','','',typ)+msg+#$0d); end;
procedure SAY_TL(typ:T_ErrorLevel; tl:TStringList); var i:integer; begin for i:=1 to tl.count do SAY(typ,tl[i-1]); end;
// writes to STDERR
procedure Log_Write  (typ:T_ErrorLevel;msg:string); begin if typ>=LOG_Level then write  (ErrOutput,Get_LogString('','','',typ)+msg); end;
procedure Log_Writeln(typ:T_ErrorLevel;msg:string); begin if typ>=LOG_Level then writeln(ErrOutput,Get_LogString('','','',typ)+msg+#$0d); end;
function  Log_Shorting:boolean; begin Log_Shorting:=false; end; 

procedure LOG_ShowStringList(typ:T_ErrorLevel; ts:TStringList); 
var i:longint; 
begin 
  if typ >= LOG_Level then 
  begin 
    if LOG_Shorting then 
	begin
	  if ts.Count>=35 then
	  begin
	    for i := 1          to 13       do Log_Writeln(typ,ts[i-1]);
		                                   Log_Writeln(typ,'<! Output shortend, total lines: '+Num2Str(ts.count,0)+'>');
		for i := ts.Count-6 to ts.Count do Log_Writeln(typ,ts[i-1]);
	  end
	  else for i := 1 to ts.Count do Log_Writeln(typ,ts[i-1]);
	end
	else
    begin
	  for i := 1 to ts.Count do Log_Writeln(typ,ts[i-1]);
    end;	
    Flush(ErrOutput);	
  end; 
end;

function  LOG_Get_Level : T_ErrorLevel; begin LOG_Get_Level:=LOG_Level; end;
procedure LOG_Save_Level;    begin LOG_OLD_Level:=LOG_Get_Level; end;
procedure Log_Set_Level(level:T_ErrorLevel); begin LOG_Save_Level; LOG_Level:=level; end;
procedure LOG_Restore_Level; begin LOG_Set_Level(LOG_OLD_Level); end;

function  LOG_GetEndMsg(comment:string):string;
var sh:string;
begin  
  if comment<>'' then sh:=comment else sh:=ApplicationName;
  LOG_GetEndMsg:=sh+' ended at '+FormatDateTime('dd.mm.yyyy hh:mm:ss.zzz',now)+', runtime was '+FormatDateTime('hh:mm:ss.zzz',Now-ProgramStartTime); 
end;

function  LOG_GetVersion(version:real):string; 		
begin LOG_GetVersion:=ApplicationName+' V'+Num2Str(version,0,2)+' build '+RPI_GetBuildDateTimeString; end;

function  Str2Bool(s:string; var ein:boolean):boolean;
var ok:boolean;
begin
  ok:=false;
  if Pos(Upper(s),yes_c) >0 then begin ok:=true; ein:=true;  end;
  if Pos(Upper(s),nein_c)>0 then begin ok:=true; ein:=false; end;
  Str2Bool:=ok;
end;
function  Bool2Dig(b:boolean) : string; 	 begin if b then Bool2Dig:='1'    else Bool2Dig:='0';     end;
function  Bool2LVL(b:boolean) : string; 	 begin if b then Bool2LVL:='H'    else Bool2LVL:='L';     end;
function  Bool2Str(b:boolean) : string; 	 begin if b then Bool2Str:='TRUE' else Bool2Str:='FALSE'; end;
function  Bool2Swc(b:boolean) : string; 	 begin if b then Bool2Swc:='ON'   else Bool2Swc:='OFF';   end;
function  Bool2OC (b:boolean) : string; 	 begin if b then Bool2OC:='OPEN'  else Bool2OC:='CLOSE';  end;
function  Bool2YN (b:boolean) : string; 	 begin if b then Bool2YN:='YES'   else Bool2YN:='NO';     end;
function  Num2Str(num:int64;lgt:byte):string;    var s:string; begin str(num:lgt,s); Num2Str:=s; end;
function  Num2Str(num:longint;lgt:byte):string;  var s:string; begin str(num:lgt,s); Num2Str:=s; end;
function  Num2Str(num:longword;lgt:byte):string; var s:string; begin str(num:lgt,s); Num2Str:=s; end;
function  Num2Str(num:real;lgt,nk:byte):string;  var s:string; begin str(num:lgt:nk,s);Num2Str:=s; end;
function  Str2Num(s:string; var num:byte):boolean;     var code:integer; begin val(StringReplace(s,'0x','$',[rfReplaceAll,rfIgnoreCase]),num,code); Str2Num:=(code=0); end;
//function  Str2Num(s:string; var num:integer):boolean;  var code:integer; begin val(StringReplace(s,'0x','$',[rfReplaceAll,rfIgnoreCase]),num,code); Str2Num:=(code=0); end;
function  Str2Num(s:string; var num:int64):boolean;    var code:integer; begin val(StringReplace(s,'0x','$',[rfReplaceAll,rfIgnoreCase]),num,code); Str2Num:=(code=0); end;
function  Str2Num(s:string; var num:longint):boolean;  var code:integer; begin val(StringReplace(s,'0x','$',[rfReplaceAll,rfIgnoreCase]),num,code); Str2Num:=(code=0); end;
function  Str2Num(s:string; var num:longword):boolean; var code:integer; begin val(StringReplace(s,'0x','$',[rfReplaceAll,rfIgnoreCase]),num,code); Str2Num:=(code=0); end;
function  Str2Num(s:string; var num:real):boolean;     var code:integer; begin val(StringReplace(s,'0x','$',[rfReplaceAll,rfIgnoreCase]),num,code); Str2Num:=(code=0); end;
function  Str2Num(s:string; var num:extended):boolean; var code:integer; begin val(StringReplace(s,'0x','$',[rfReplaceAll,rfIgnoreCase]),num,code); Str2Num:=(code=0); end;
function  Hex  (nr:qword;lgt:byte) : string; begin Hex:=Format('%0:-*.*x',[lgt,lgt,nr]); end;
function  HexStr(s:string):string; var sh:string; i:longint; begin sh:=''; for i := 1 to Length(s) do sh:=sh+Hex(ord(s[i]),2); HexStr:=sh; end;
function  LeadingZero(w:word):string; begin LeadingZero:=Format('%0:-*.*d',[2,2,w]); end;
procedure AskCR(msg:string); begin write(msg+'<CR>'); readln; end;
//function  Get_FixedStringLen(s:string;cnt:word;leading:boolean):string; var fmt:string; begin fmt:='%0:'; if not leading then fmt:=fmt+'-'; fmt:=fmt+'*.*s'; Get_FixedStringLen:=Format(fmt,[cnt,cnt,s]); end;
function  Get_FixedStringLen(s:string;cnt:word;leading:boolean):string; var fmt:string; begin if leading then fmt:='%' else fmt:='%-'; fmt:=fmt+Num2Str(cnt,0)+'s'; Get_FixedStringLen:=Format(fmt,[s]); end;
function  Upper(const s : string) : String; var sh : String; i:word; begin sh:=''; for i:= 1 to Length(s) do sh:=sh+Upcase(s[i]);   Upper:=sh; end;
function  Lower(const s : string) : String; var sh : String; i:word; begin sh:=''; for i:= 1 to Length(s) do sh:=sh+LowerCase(s[i]);Lower:=sh; end;
function  CharPrintable(c:char):string; begin if ord(c)<$20 then CharPrintable:=#$5e+char(ord(c) xor $40) else CharPrintable:=c; end;
function  StringPrintable(s:string):string; var sh : string; i : longint; begin sh:=''; for i:=1 to Length(s) do sh:=sh+CharPrintable(s[i]); StringPrintable:=sh; end;
procedure ShowStringList(StrList:TStringList); var n:longint; begin for n:= 1 to StrList.Count do writeln(StrList[n-1]); end;
function  AdjZahlDE(r:real;lgt,nk:byte):string; var s:string; begin s:=StringReplace(Num2Str(r,lgt,nk),'.',',',[]); AdjZahlDE:=s; end;
function  AdjZahl(s:string):string;
var hs:string; n,pkt,com:integer; DEformat:boolean;
begin  
  DEformat:=false; pkt:=POS('.',s); com:=POS(',',s); hs:='';
  if (pkt<com) and (com<>0) then DEformat:=true;
//writeln(DEformat,' ',pkt,' ',com);
  for n:=1 to Length(s) do
  begin
    case s[n] of
      '.': if (DEformat) then hs:=hs+''  else hs:=hs+'.';
      ',': if (DEformat) then hs:=hs+'.' else hs:=hs+'';
      else hs:=hs+s[n];
    end;
  end; // only . as decimalpoint
  hs:=StringReplace(hs,'.--','.00',[]); hs:=StringReplace(hs,'.-', '.00',[]); 
  AdjZahl:=hs;
end;

function  StrHex(Hex_strng:string):string;
const tab:array[1..6] of byte=($0a,$0b,$0c,$0d,$0e,$0f);
var s,sh:string; i:longint; b,bh:byte; pending:boolean;
begin
  sh:=''; bh:=$00; s:=GetHexChar(Hex_strng); pending:=((Length(s) mod 2)<>0);
  for i := 1 to Length(s) do
  begin
    b:=ord(s[i]);
	if (b>=$30) and (b<=$39) then b:=b and $0f else b:=tab[(b and $0f)];
	if (((i-1) mod 2) <> 0) or ((i=Length(s)) and pending) then 
	begin 
	  bh:=bh or b; sh:=sh+char(bh); bh:=$00; 
	end 
	else bh:=b shl 4;
  end;
  StrHex:=sh;
end;

function  Str2DateTime(tdstring,fmt:string):TDateTime;
begin
  Str2DateTime:=ScanDateTime(fmt,tdstring);
end; 

function  scale(valin,min1,max1,min2,max2:real):real;
var r1,r2:real;
begin
  r2:=valin;
  if (valin>=min1) and (valin<=max1) then
  begin
    r1:=max1-min1;
    if r1<>0 then
    begin
      r2:=valin*(max2-min2)/r1;
    end else LOG_Writeln(LOG_ERROR,'Scale: wrong min1/max1 value pair');
  end else LOG_Writeln(LOG_ERROR,'Scale: valin not in range of min1/max1 value pair');
  scale:=r2;
end;

function  LeadingZeros(l:longint;digits:byte):string;
var s1,s2:string; i:byte; 
begin
  s1:=''; for i := 1 to digits do s1:=s1+'0'; Str(l:0,s2); s1:=s1+s2; 
  LeadingZeros:=copy(s1,Length(s1)-digits+1,255); 
end;

function GetFileAge(filname:string):TDateTime;
var fa:longint; fildat:TDateTime; fn:string;
begin
  fildat:=0; fn:=PrepFilePath(filname);
  if FileExists(fn) then 
  begin
    {$I-} fa:=FileAge(fn); if fa<>-1 then fildat:=FileDateToDateTime(fa); {$I+}
  end;
  GetFileAge:=fildat;
end;

function  GetFileAgeInSec(filname:string):int64;
var fa:longint; res:int64; fildat:TDateTime; fn:string;
begin
  fildat:=0; res:=-1; fn:=PrepFilePath(filname);
  if FileExists(fn) then 
  begin
    {$I-} 
	  fa:=FileAge(fn); 
	  if fa<>-1 then 
	  begin 
	    fildat:=FileDateToDateTime(fa); 
		res:=round(SecondsBetween(now,fildat)); 
	  end; 
	{$I+}
  end;
  GetFileAgeInSec:=res;
end;

function  GetRNDsec(seconds_old,varianz:longint):longint;
var v,vh:longint;
begin
  v:=seconds_old;
  if varianz<>0 then
  begin
    vh:=varianz div 2; v:=Random(varianz+1); v:=vh-v; v:=seconds_old-v; if v<0 then v:=seconds_old;
  end;
  GetRNDsec:=v;
end;

function  FileIsRecent(filepath:string; seconds_old,varianz:longint):boolean;
var ok:boolean; tdat:TDateTime;
begin
  tdat:=GetFileAge(filepath); 
  ok:=(SecondsBetween(now,tdat)<=GetRNDsec(seconds_old,varianz));
//LOG_Writeln(LOG_Warning,Bool2Str(ok)+' Delta: '+Num2Str(DeltaTime_in_min(now,tdat),0)+' min FileDate: '+GetXMLTimeStamp(tdat)+' '+Real2Str(v/60,0,2)+' min');
  FileIsRecent:=ok;
end;

function  FileIsRecent(filepath:string; seconds_old:longint):boolean;
begin
  FileIsRecent:=FileIsRecent(filepath,seconds_old,0);
end;

function adjL(s:string):string;
{.c schmeisst leading Blanks weg. }
var i,j : word; sh : string; first : boolean;
begin
  first := true; j := 1;
  sh := s;
  for i := 1 to Length(sh) do
    if (sh[i] = ' ') and (first) then j := i else first := false;
  if (j>0) and (j<=Length(sh)) then if sh[j] = ' ' then INC(j);
  sh := copy(sh,j,Length(sh)-j+1);
  adjL := sh;
end;

function adjT(s:string):string;
{.c schmeisst trailing Blanks weg. }
var i,j : integer; sh : string; first : boolean;
begin
  sh := s; first := true; j := length(sh);
  for i := Length(sh) downto 1 do
    if (sh[i]  = ' ') and (first) then j := i else first := false;
  if (j>0) and (j<=Length(sh)) then if sh[j] = ' ' then DEC(j);
  sh := copy(sh,1,j);
  adjT := sh;
end;

function adjM(s:string):string;
{.c schmeisst mehrfach folgende Blanks weg. }
var sh,sh2:string;
begin
  sh:=s; 
  repeat sh2:=sh; delete(sh,Pos('  ',sh),1); until sh=sh2;
  adjM:=sh;
end;

function adj(s:string):string; begin adj := adjL(adjT(s)); end;  
function adjAll(s:string):string; begin adjALL := adjM(adj(s));  end;

function  Trimme(s:string;modus:byte):string;
var sh:string; { modus: 1:adjL 2:adjT 3:AdjLT 4:AdjLMT 5:AdjLMTandRemoveTABs }
begin
  sh := s;
  case modus of
    0  : ;
    1  : sh := adjL(s);
	2  : sh := adjT(s);
	3  : sh := adj(s);
	4  : sh := adjAll(s);
	5  : sh := adjAll(StringReplace(s,#$09,' ',[rfReplaceAll]));
	else sh := adjAll(s);
  end;
  Trimme := sh;  
end;

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

function GetHexChar(s:string):string;
begin GetHexChar:=FilterChar(s,'0123456789ABCDEFabcdef'); end;

function GetNumChar(s:string):string;
begin GetNumChar:=FilterChar(s,'0123456789'); end;

function ReplaceChars(s,filterchars,replacechar:string):string;
{.c ersetzt aus string s alle char die in filter angegeben sind mit replacechar }
var sh:string; i:integer;
begin
  sh:=s; 
  for i := 1 to Length(filterchars) do sh:=StringReplace(sh,filterchars[i],replacechar,[rfReplaceAll]);
  ReplaceChars:=sh;
end;

function  RM_LF  (s:string):string; begin RM_LF:=  ReplaceChars(s,#$0a,''); end;
function  RM_CR  (s:string):string; begin RM_CR:=  ReplaceChars(s,#$0d,''); end;
function  RM_CRLF(s:string):string; begin RM_CRLF:=ReplaceChars(s,#$0d+#$0a,''); end;

function  GetHostName:string;
var computer:string; {$IFDEF Win32}c:array[0..127] of Char; sz:dword;{$ENDIF}
begin
  computer:='';
  {$IFDEF Win32} sz:=SizeOf(c); GetComputerName(c,sz); computer:=c;
  {$ELSE} computer:=unix.GetHostName; {$ENDIF}
  GetHostName:=computer;
end;

function  CamelCase(strng:string):string; 
// IN:  CamelCase
// OUT: -camel-case
var i:longint; c:char; sh:string;
begin 
  sh:='';
  for i:= 1 to Length(strng) do
  begin
    c:=strng[i];
	if (Upper(c)=c) and (c<>' ') then sh:=sh+'-'; 
	if c<>' ' then sh:=sh+LowerCase(c);
  end;
  CamelCase:=sh; 
end;

function GetPrintableChars(s:string; c1,c2:char):string;
var sh:string; i:word;
begin
  sh:='';
  for i := 1 to Length(s) do
    if ((ord(s[i])>=ord(c1)) and (ord(s[i])<=ord(c2))) then sh:=sh+s[i]; { #$<c1>..#$<c2> }	   
  GetPrintableChars:=sh;
end;

procedure FSplit(fullfilename:string; var Directory,FName,Extension:string; extwithdot:boolean);
var anz:integer; ext:string;
begin
  anz:=Anz_Item(fullfilename,dir_sep_c,''); ext:='';
  Directory:=Select_LeftItems (fullfilename,dir_sep_c,'',anz-1); 
  Fname:=    Select_RightItems(fullfilename,dir_sep_c,'',anz); 
  Extension:=Select_Item(Fname,ext_sep_c,'',Anz_Item(Fname,ext_sep_c,''));
  if (Extension<>'') then ext:=ext_sep_c+Extension;
  Fname:=StringReplace(Fname,ext,'',[rfReplaceAll,rfIgnoreCase]);
  if (Extension<>'') and (extwithdot) then Extension:=ext_sep_c+Extension;
//writeln(fullfilename,'|',directory,'|',fname,'|',extension,'-',dir_sep_c);
end;

function  Get_ExtName(fullfilename:string; extwithdot:boolean):string; 
var Directory,FName,Extension : string; 
begin FSplit(fullfilename,Directory,FName,Extension,extwithdot); Get_ExtName:=Extension; end;

function  Get_FName(fullfilename:string):string; 
var Directory,FName,Extension : string;
begin FSplit(fullfilename,Directory,FName,Extension,true); Get_FName:=Fname; end;

function  Get_Dir(fullfilename:string):string; 
var Directory,FName,Extension : string;
begin FSplit(fullfilename,Directory,FName,Extension,true); Get_Dir:=Directory;end;

function  Get_DirList(dirname:string; filelist:TStringList):integer;
const
{$IFDEF WINDOWS} c_dircmd = 'dir'; c_dirpara = '/b /ogne'; 
{$ELSE}          c_dircmd = 'ls';  c_dirpara = '-1';  {$ENDIF}
begin
//writeln('Get_DirList:',c_dircmd+' '+c_dirpara+' '+PrepFilePath(dirname));
  Get_DirList:=call_external_prog(LOG_NONE,c_dircmd+' '+c_dirpara+' '+PrepFilePath(dirname), filelist);
end;

function  GetTildePath(fullpath,homedir:string):string;
var sh:string;
begin
  sh:=StringReplace(fullpath,homedir,'~',[rfReplaceAll,rfIgnoreCase]);
  GetTildePath:=sh;
end;

function  PrepFilePath(fpath:string):string;
var i:integer; s:string; //Directory,FName,Extension:string; 
begin
  s:=SetDirSeparators(fpath);
  {$IFDEF UNIX} 
    if Pos(':',s)>0 then LOG_Writeln(LOG_ERROR,'filepath contains windows separator '+fpath);
  {$ENDIF}
//FSplit(fpath,Directory,FName,Extension,true); FName:=PrepFileName(FName); s:=Directory+PathDelim+FName+Extension;
  for i:= 1 to 3 do s:=StringReplace(s,PathDelim+PathDelim,PathDelim,[rfReplaceAll,rfIgnoreCase]); 
  PrepFilePath:=s;
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

function  Select_RightItems(const strng,trenner,trenner2:string;startitemno:longint) : string; 
var sh:string; n,m : longint;
begin
  sh:=''; m:=Anz_Item(strng,trenner,trenner2);
  for n := startitemno to m do
  begin
    sh:=sh+Select_Item(strng,trenner,trenner2,n);
	if n<m then sh:=sh+trenner;
  end;
  Select_RightItems := sh;
end;

function  Select_LeftItems(const strng,trenner,trenner2:string;enditemno:longint) : string; 
var sh:string; n,m : longint;
begin
  sh:=''; m:=enditemno;
  for n := 1 to m do
  begin
    sh:=sh+Select_Item(strng,trenner,trenner2,n);
	if n<m then sh:=sh+trenner;
  end;
  Select_LeftItems := sh;
end;

function  SepRemove(s:string):string;
var n:longint; sh:string;
begin
  sh:=s;
  for n:=0 to sep_max_c do sh:=StringReplace(sh,sep[n],' ',[rfReplaceAll,rfIgnoreCase]);
  SepRemove:=sh;
end;

function  StringListMinMaxValue(StrList:TStringList; fieldnr:word; tr1,tr2:string; var min,max:extended; var nk:longint):boolean;
var i:longint; e:extended; b1,b2:boolean; nkh,lgt:integer; sh:string;
begin
  min:=NaN; max:=NaN; b1:=false; b2:=false; nk:=0;
  if StrList.count>0 then
  begin
    min:=maxfloat; max:=-maxfloat;	// was maxextended , creates error on ARM (rpi) with FPC 2.6.4 
    for i:= 1 to StrList.count do 
    begin
	  sh:=Select_Item(StrList[i-1],tr1,tr2,fieldnr); // 12.3456
	  if Str2Num(sh,e) then
	  begin
	    lgt:=Length(sh); nkh:=lgt-Pos('.',sh); if nkh=lgt then nkh:=0;
	    if nkh>nk then nk:=nkh;
	    if e>max then begin max:=e; b1:=true; end;
		if e<min then begin min:=e; b2:=true; end;
	  end;
    end;
	if not b1 then max:=NaN; if not b2 then min:=NaN;
  end;
  StringListMinMaxValue:=(b1 and b2);
end;

function  SearchStringInList(StrList:TStringList; srchstrng:string):string;
var sh:string; n:longint;
begin
  n:=1; sh:='';
  while (n<=StrList.Count) do
  begin
    if (Pos(srchstrng,StrList[n-1])>0) then begin sh:=StrList[n-1]; n:=StrList.Count; end;
    inc(n);  
  end;
  SearchStringInList:=sh;
end;

function SearchStringInListIdx(StrList:TStringList; srchstrng:string; occurance,StartIdx:longint):longint;
// return idx, where searchstring occurs to the 'occurance' count. If not then return -1;
// if occurence>0 then search list from 1. to last record
// if occurence<0 then search list from end to 1. record
var n,ret,occhelp : longint; found:boolean; 
begin
  found:=false; ret:=-1; occhelp:=0;
  if occurance>0 then
  begin // von 1-Ende durchsuchen
    n:=StartIdx; if n<0 then n:=0;
    while (n<StrList.Count) and not found do
    begin
      if (Pos(srchstrng,StrList[n])>0) then 
	  begin 
	    inc(occhelp); 
	    if (occhelp=occurance) then begin found :=true; ret:=n; end; 
	  end;
      inc(n);  
    end;
  end;
  if occurance<0 then
  begin // von Ende-1 durchsuchen
    n:=StrList.Count-1; 
    while (n>=0) and not found do
    begin
      if (Pos(srchstrng,StrList[n])>0) then begin inc(occhelp); if (occhelp=abs(occurance)) then begin found :=true; ret:=n; end; end;
      dec(n);  
    end;
  end;
  SearchStringInListIdx:=ret;
end;

function  GiveStringListIdx(StrList:TStringList; srchstrng:string; var idx:longint; occurance:longint):boolean;
var ok:boolean;
begin
  idx:=SearchStringInListIdx(StrList, srchstrng, occurance,0); 
  if (idx>=0) and (idx<StrList.count) then ok:=true else ok:=false;  
  GiveStringListIdx:=ok;
end;

function  GiveStringListIdx(StrList:TStringList; srchstrngSTART,srchstrngEND:string; var idx:longint):boolean;
var ok,ende:boolean; sh:string; n,p1,p2:longint;
begin
  ok:=false; ende:=false; n:=1;
  repeat
    idx:=SearchStringInListIdx(StrList, srchstrngSTART, n,0); 
//  writeln(srchstrngSTART,' ',srchstrngEND,' ',idx);
    if (idx>=0) and (idx<StrList.count) then 
    begin
      sh:=StrList[idx]; p1:=Pos(srchstrngSTART,sh); p2:=Pos(srchstrngEND,sh);
      ok:=(p2>p1);
//    writeln(p1,' ',p2,' ',ok,' ',sh);
    end 
	else ende:=true;
	inc(n);
  until ok or ende;
  GiveStringListIdx:=ok;
end;

function  SearchInConfigList(inifilbuf:TStringlist; section,name:string; secret:boolean; defaultstring:string; var line,secstart,secend:longint; var history:string): string;
  function SectionLineFound(var s:string):boolean; begin SectionLineFound:=((Pos('[',s)=1) and (Pos(']',s)=Length(s))); end;
  function SectionFound(var s:string; section:string):boolean; begin SectionFound:=(Pos('['+Upper(section)+']',Upper(s))=1); end;  
  function NameFound   (var s:string; name:   string):boolean; begin NameFound:=   (Pos(    Upper(name)+'=',   Upper(s))=1); end;   
var sect_found,name_found:boolean; s,sh,seclink:string; n:word; i:integer;
begin
  sh:=defaultstring; sect_found:=((section='') and (inifilbuf.Count>0)); 
  name_found:=false; seclink:=''; history:=history+'#'+section+'*';
  n:=0; line:=-1; secend:=-1; if sect_found then secstart:=0 else secstart:=-1; 
  while (n<inifilbuf.Count) and (not (sect_found and name_found)) do
  begin
//  writeln(n,' ',inifilbuf.Count);
    s:=inifilbuf[n];  
    if SectionLineFound(s) then
	begin
	  if sect_found then secend:=n-1;
	  sect_found:=SectionFound(s,section);
      if sect_found then 
	  begin 
	    secstart:=n; 
//	    writeln('section ',section,' ',sect_found);
	  end;
    end;
	if sect_found and  NameFound(s,'SECTIONLINK') then 
	begin
	  i:=Pos('=',s); seclink:=''; if i>0 then seclink:=copy(s,i+1,Length(s));
	end;
	if sect_found then name_found:=NameFound(s,name);
    if name_found and  sect_found then 
	begin
//	  inc(n);
	  line:=n;
	  i:=Pos('=',s); sh:=''; if i>0 then sh:=copy(s,i+1,Length(s));
	  while (n<inifilbuf.Count) do 
	  begin s:=inifilbuf[n]; if SectionLineFound(s) then secend:=n-1; inc(n); end;
	  if secend<0 then secend:=inifilbuf.Count-1; 
	end;
	inc(n);
//  writeln('found section:',sect_found,' name:',name_found,' ',sh);
  end;
  if (secend<0) then
  begin
    if sect_found then secend:=inifilbuf.Count else secstart:=-1;
  end;  
//writeln('#',seclink,'#',name_found);
  if (not name_found) and (seclink<>'') then
  begin
    LOG_Writeln(LOG_DEBUG,'SearchInConfigList: SECTIONLINK '+'['+seclink+'|'+name+'] is currently not supported  !!! '+history);
	if Pos('#'+seclink+'*',history)=0 
	  then sh:=SearchInConfigList(inifilbuf, seclink, name, secret, defaultstring, line, secstart, secend, history)
	  else LOG_WRITELN(LOG_ERROR,'SearchInConfigList: Loop in SECTIONLINK '+seclink+' '+history);
  end;
  SearchInConfigList:=sh;
end;

function  StringList2String(StrList:TStringList):string;
var li:longint; sh:string;
begin
  sh:='';
  for li:= 1 to StrList.count do sh:=sh+Trimme(StrList[li-1],5);
  StringList2String:=sh;
end;

function  StringList2TextFile(filname:string; StrListOut:TStringList):boolean;
{ Write StringList to TextFile }
var b:boolean; n:longint; fil:text; fn:string;
begin
  b:=false; fn:=PrepFilePath(filname);
  Log_Writeln(LOG_DEBUG,'Writing to file:  '+fn+' lines: '+Num2Str(StrListOut.count,0)); 
  {$I-} 
  assign (fil,fn); rewrite(fil);
  if IOResult = 0 then
  begin
    for n := 1 to StrListOut.count do system.writeln(fil,StrListOut[n-1]); 
	b:=true;
    close(fil); 
  end
  else LOG_Writeln(LOG_Error,'StringList2TextFile: could not write file '+filname);
  {$I+}
//Log_Writeln(LOG_INFO,'Writing to file-: '+fn+' append_mode: '+Bool2Str(append_mode)+' lines: '+Num2Str(StrListOut.count,0)); 
  StringList2TextFile:=b;
end;

function  StringListAdd2List(StrList1,StrList2:TStringList; append:boolean):longword; //Adds StringList2 to Stringlist1. result is size of Stringlist in bytes
var n:longint; siz:longword;  
begin 
  siz:=0;
  if append then 
  begin 
    for n := 1 to StrList2.count		do StrList1.add   (  StrList2[n-1]);
    inc(siz,Length(StrList2[n-1]));
  end
  else 
  begin
    for n := StrList2.count downto 1  	do StrList1.insert(0,StrList2[n-1]); 
    inc(siz,Length(StrList2[n-1]));
  end;
  StringListAdd2List:=siz;
end;

function  StringListAdd2List(StrList1,StrList2:TStringList):longword; 
begin StringListAdd2List:=StringListAdd2List(StrList1,StrList2,true); end;

function  TextFile2StringList(filname:string; StrListOut:TStringList; var hash:string):boolean;
{ Read TextFile into a StringList (also possible from stdin, if filename='' ) }
var b:boolean; fn:string;
begin
  b:=true; fn:=PrepFilePath(filname);
  {$I-} 
  if FileExists(fn) then 
  begin
    StrListOut.LoadFromFile(fn); hash:=MD5Print(MD5String(StringList2String(StrListOut))); 
	Log_Writeln(LOG_DEBUG,'Read  from file: '+fn+' lines: '+Num2Str(StrListOut.count,0)+' hash: '+hash); 
  end 
  else 
  begin 
    b:=false; hash:=''; 
	LOG_Writeln(LOG_Error,'TextFile2StringList: could not read file '+fn);
  end; 
  {$I+}
  TextFile2StringList:=b;
end;

function  TextFile2StringList(filname:string; StrListOut:TStringList; append:boolean; var hash:string):boolean;
var tl:TStringList; ok:boolean; 
begin
  ok:=false; 
  if append then
  begin
    tl:=TStringList.create;
    ok:=TextFile2StringList(filname,tl,hash);
	if ok then StringListAdd2List(StrListOut,tl);
	tl.free;
  end
  else 
  begin
    StrListOut.clear;
    ok:=TextFile2StringList(filname,StrListOut,hash);
  end;
  TextFile2StringList:=ok;
end;

function  TextFileContentCheck(file1,file2:string; mode:byte):boolean;
var ok:boolean; ts1,ts2:TStringList; i:longint; hash:string;
begin
  ok:=false;
  if FileExists(file1) and FileExists(file2) then
  begin
    ts1:=TStringList.create; ts2:=TStringList.create;
    if TextFile2StringList(file1,ts1,false,hash) then 
      if TextFile2StringList(file2,ts2,false,hash) then
	    if (ts1.count=ts2.count) and (ts1.count>0) then
        begin
	      ok:=true;
	      for i:= 1 to ts1.count do 
		  begin 
		    case mode of
		       1 : begin if Select_Item(ts1[i-1],' ','',1)<>Select_Item(ts2[i-1],' ','',1) then ok:=false; end;
		      else begin if ts1[i-1]<>ts2[i-1] then ok:=false; end;
		    end; // case
		  end;
        end;  
    ts1.free; ts2.free;
  end;
  TextFileContentCheck:=ok;
end;

function  GetRndTmpFileName:string;
var sh:string; dt:TDateTime;
begin
  dt:=now;
  sh:=GetUTCOffsetString(_TZLocal); if sh='' then sh:='Z'; //YEAR-MM-DDThh:mm:ss+XX
  sh:=FormatDateTime('yyyy-mm-dd',dt)+'T'+FormatDateTime('hh:nn:ss',dt)+sh; 
  sh:=c_tmpdir+'/tmp_'+FilterChar(sh,'0123456789TtZ')+'.txt';
  GetRndTmpFileName:=PrepFilePath(sh); 
end;

procedure BIOS_UpdateFile; 
begin 
  with IniFileDesc do 
  begin
    if ok then inifilbuf.UpdateFile; 
  end;
end;

procedure BIOS_EndIniFile; 
begin 
  with IniFileDesc do 
  begin
    if ok then
    begin
      BIOS_UpdateFile;
      inifilbuf.free; 
    end;
    ok:=false;
  end;
end;

procedure BIOS_DeleteKey(section,name:string);
begin with IniFileDesc do if ok then inifilbuf.DeleteKey(section,name); end;

procedure BIOS_EraseSection(section:string);
begin with IniFileDesc do if ok then inifilbuf.EraseSection(section); end;

procedure BIOS_SetCacheUpdate(upd:boolean);
begin with IniFileDesc do if ok then inifilbuf.CacheUpdates:=upd; end;

procedure BIOS_ReadIniFile(fname:string);
// e.g. BIOS_ReadIniFile('/etc/configfile.ini')
begin
  with IniFileDesc do
  begin
	inifilename:=PrepFilePath(fname); ok:=false;
    if inifilename<>'' then 
	begin
//	  if FileExists(inifilename) then 
	  begin // will be created, if file does not exist
	    inifilbuf:=TIniFile.Create(inifilename); ok:=true;
      end
//    else LOG_Writeln(LOG_ERROR,'BIOS_ReadIniFile: no config file found '+inifilename);	  
	end;
  end;
end;

function BIOS_GetIniString(section,name,default:string; secret:boolean): string;
// e.g. configfile.ini content:
// [SECNAME1]
// PARA1=Value 1234
// [SECNAME2]
// PARA1=Value 1
// PARAX=ValueX
// e.g. BIOS_GetIniString('SECNAME2','PARA1',false);
// return: 'Value 1'
// if Parameter is not found, then return default-string
var sh:string;
begin
  with IniFileDesc do
  begin
    if ok	then sh:=inifilbuf.ReadString(section,name,default)
    		else begin
    			   sh:=default;
//    			   Log_Writeln(LOG_ERROR,'BIOS_GetIniString: INI-File not opened');
    			 end;
  end;	  
  if sh='' then sh:=default;
  BIOS_GetIniString:=sh;
end;

function  BIOS_SetIniString(section,name,value:string; secret:boolean):boolean;			
begin
  with IniFileDesc do
  begin
    if ok	then inifilbuf.WriteString(section,name,value)
    		else Log_Writeln(LOG_ERROR,'BIOS_SetIniString: INI-File not opened');
  end;
  BIOS_SetIniString:=true;
end;

procedure BIOS_Test;
var fil:text; sh:string;
begin
  {$IFDEF UNIX} // just create a config file, only for demo reasons
    sh:=ChangeFileExt(ApplicationName,'.ini');
    assign (fil,sh); rewrite(fil);
    writeln(fil,'[SECNAME1]'); writeln(fil,'PARA1=Value 1234');
    writeln(fil,'[SECNAME2]'); writeln(fil,'PARA1=Value 1'); writeln(fil,'PARAX=ValueX');
    close(fil);
    writeln('Test start: reading the config file ',sh);
    BIOS_ReadIniFile(sh);	
    sh:=BIOS_GetIniString('SECNAME2','PARA1','DefaultValue',false);
    writeln(' Read the parameter "PARA1" from section "SECNAME2"=',sh);
    sh:=BIOS_GetIniString('SECNAME1','PARA1','DefaultValue',false);
    writeln(' Read the parameter "PARA1" from section "SECNAME1"=',sh);  
    sh:=BIOS_GetIniString('SECNAME2','PARA3','DefaultValue',false);
    writeln(' Read the non existent parameter "PARA3" from section "SECNAME2"=',sh);
    writeln('Test end.');
    BIOS_EndIniFile;
  {$ENDIF}
end;

function  MStream2String(MStreamIn:TMemoryStream):string;
var s:string;
begin
  SetString(s,PAnsiChar(MStreamIn.memory),MStreamIn.size);
  MStream2String:=s;
end;

procedure String2MStream(MStreamIn:TMemoryStream; var SourceString:string);
begin
  MStreamIn.WriteBuffer(Pointer(SourceString)^, Length(SourceString));
  MStreamIn.Position := 0;
end;

function  MStream2File(filname:string; StreamOut:TMemoryStream):boolean;
var ok:boolean; fs:TFileStream;
begin
  ok:=true; fs:=TFileStream.Create(PrepFilePath(filname), fmCreate);
  if StreamOut.Size>0 then 
  begin StreamOut.Position:=0; fs.CopyFrom(StreamOut,StreamOut.Size); end else ok:=false;
  fs.free; 
  MStream2File:=ok;
end;

function  File2MStream(filname:string;StreamOut:TMemoryStream; var hash:string):boolean;
var b:boolean; fn:string;
begin
  b:=true; fn:=PrepFilePath(filname);
  {$I-}
  if FileExists(fn) then 
  begin
    StreamOut.LoadFromFile(fn); 
	hash:=MD5Print(MD5String(MStream2String(StreamOut))); 
  end
  else begin b:=false; hash:=''; end; 
  {$I+}
  File2MStream:=b;
end;

procedure MemCopy(src,dst:pointer; size:longint); begin if size>0 then Move(src^, dst^, size); end; 
procedure MemCopy(src,dst:pointer; size,srcofs,dstofs:longint);
begin
  if size>0 then
  begin
    {$warnings off} 
      Move(pointer(longword(src)+srcofs)^, pointer(longword(dst)+dstofs)^, size);
	{$warnings on} 
  end;
end;

function GetVZ(dt1,dt2:TDateTime):integer; var vz:integer; begin if dt1>=dt2 then vz:=1 else vz:=-1; GetVZ:=vz; end;

function DeltaTime_in_ms(dt1,dt2:TDateTime):int64;
begin                                 
  DeltaTime_in_ms:=GetVZ(dt1,dt2)*MilliSecondsBetween(dt1,dt2);
end;

function call_external_prog(typ:t_ErrorLevel; cmdline:string; receivelist:TStringList):integer;
// can return multiple lines in StringList
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
//writeln('cmdline: ',cmdline);
  if (cmdline<>'')  then 
  begin
    M := TMemoryStream.Create;
    BytesRead := 0; 
    P := TProcess.Create(nil);
	OurCommand:='';
	P.Options := [poUsePipes]; 
	{$IFDEF WINDOWS}
//    Can't use dir directly, it's built in, so we just use the shell:
      OurCommand:='cmd.exe /c '+cmdline;
	  P.CommandLine := OurCommand;
    {$ENDIF}
    {$IFDEF UNIX}
	  OurCommand := cmdline;
      p.Executable := '/bin/sh'; 
	  p.Parameters.Add('-c'); 
	  p.Parameters.Add(OurCommand);  
    {$ENDIF}
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
      receivelist.LoadFromStream(M);
      {$warnings off} if test then showstringlist(receivelist); {$warnings on}
	end;
	P.Free;
    M.Free;
    {$warnings off} if test then writeln('Leave call_external_prog '); {$warnings on}
  end
  else if (typ<>LOG_NONE) then LOG_Writeln(LOG_ERROR,'call_external_prog: empty cmdline '+cmdline);
  if (exitStat<>0) and (typ<>LOG_NONE) then
  begin
    LOG_Writeln(typ,'call_external_prog: '+cmdline);
    LOG_ShowStringList(typ,receivelist);
  end;
  call_external_prog:=exitStat;
end;

function  call_external_prog(typ:t_ErrorLevel; cmdline:string; var receivestring:string):integer; 
// one return line
var res,exitstat:integer;
begin
  exitstat:=RunCommandInDir('','/bin/sh',['-c',cmdline],receivestring,res); // requires FPC 2.4.6
  if exitstat=0 then
  begin       
//writeln(':',receivestring,':',Length(receivestring),':',HexStr(receivestring));
// remove trailing $00 (0 terminated string; remove trailing LF
  if Length(receivestring)>0 then 
    if receivestring[Length(receivestring)]=#$00 then receivestring:=copy(receivestring,1,Length(receivestring)-1);
  if Length(receivestring)>0 then 
    if receivestring[Length(receivestring)]=#$0a then receivestring:=copy(receivestring,1,Length(receivestring)-1);
    if (typ<>LOG_NONE) then LOG_Writeln(typ,'call_external_prog['+Num2Str(res,0)+']:'+cmdline+':res:'+receivestring);
  end 
  else receivestring:='';
//writeln('##++##',cmdline,'#',res,'#',exitstat,'#',receivestring,'#',HexStr(receivestring),'#');
  call_external_prog:=res;
end;

function  Xcall_external_prog(typ:t_ErrorLevel; cmdline:string):string; 
var sh:string; ts:TStringlist; 
begin 
  ts:=TStringList.Create;
  if (call_external_prog(typ,cmdline,ts)=0) then
  begin
    if ts.count>0 then sh:=ts[0] else sh:='';
  end else sh:='';
  ts.free;
  Xcall_external_prog:=sh;
end;

function  MD5_Check(file1,file2:string):boolean;
//38398e53aa45f86427ada3e9331c24f9  rfm.tgz.md5
//38398e53aa45f86427ada3e9331c24f9  /tmp/rfm.tgz.md5
var ok:boolean; md5f1,md5f2:string;
begin
  ok:=false;
  if FileExists(file1) and FileExists(file2) then
  begin
    call_external_prog(LOG_NONE,'tail '+file1,md5f1); md5f1:=Select_Item(md5f1,' ','',1);
    call_external_prog(LOG_NONE,'tail '+file2,md5f2); md5f2:=Select_Item(md5f2,' ','',1);
	ok:=((Upper(md5f1)=Upper(md5f2)) and (md5f1<>''));
  end;
  MD5_Check:=ok;
end;

procedure RPI_MaintDelEnv; begin RpiMaintCmd.EraseSection('RPIMAINT'); end;
procedure RPI_MaintSetEnvExec(EXECcmd:string);
begin
  RpiMaintCmd.WriteString('RPIMAINT','EXEC', 	EXECcmd);
end;
procedure RPI_MaintSetEnvFTP(FTPServer,FTPUser,FTPPwd,FTPLogf,FTPDefaults:string);
var sh:string;
begin
  sh:=FTPDefaults; if sh='' then sh:=CURLFTPDefaults_c;
//writeln('RPI_MaintSetEnvFTP:',FTPServer,':',FTPUser,':',FTPPwd,':',FTPLogf,':',sh);
  RpiMaintCmd.WriteString('RPIMAINT','FTPSRV', FTPServer);
  RpiMaintCmd.WriteString('RPIMAINT','FTPUSR', FTPUser);
  RpiMaintCmd.WriteString('RPIMAINT','FTPPWD', FTPPwd);
  RpiMaintCmd.WriteString('RPIMAINT','FTPLOG', FTPLogf);
  RpiMaintCmd.WriteString('RPIMAINT','FTPOPT', sh);
end; 
procedure RPI_MaintSetEnvUPD(UpdPkgSrcFile,UpdPkgDstDir,UpdPkgDstFile,UpdPkgMaintDir,UpdPkgLogf:string);
begin
  RpiMaintCmd.WriteString('RPIMAINT','UPDPSF', UpdPkgSrcFile);
  RpiMaintCmd.WriteString('RPIMAINT','UPDPDD', UpdPkgDstDir);
  RpiMaintCmd.WriteString('RPIMAINT','UPDPDF', UpdPkgDstFile);
  RpiMaintCmd.WriteString('RPIMAINT','UPDMDIR',UpdPkgMaintDir);
  RpiMaintCmd.WriteString('RPIMAINT','UPDPLOG',UpdPkgLogf);
end;
procedure RPI_MaintSetEnvUPL(UplSrcFiles,UplDstDir,UplLogf:string);
begin // FTP-Upload
  RpiMaintCmd.WriteString('RPIMAINT','UPLSF',  UplSrcFiles);
  RpiMaintCmd.WriteString('RPIMAINT','UPLDD',  UplDstDir);
  RpiMaintCmd.WriteString('RPIMAINT','UPLLOG', UplLogf);
end;
procedure RPI_MaintSetEnvDWN(DwnSrcDir,DwnlSrcFiles,DwnDstDir,DwnLogf:string);
begin // FTP-Download
  RpiMaintCmd.WriteString('RPIMAINT','DWNSD',  DwnSrcDir);
  RpiMaintCmd.WriteString('RPIMAINT','DWNSF',  DwnlSrcFiles);
  RpiMaintCmd.WriteString('RPIMAINT','DWNDD',  DwnDstDir);
  RpiMaintCmd.WriteString('RPIMAINT','DWNLOG', DwnLogf);
end;

function  CURL_ErrCode(errnum:longint):string; // translate some error codes
var sh:string;
begin
  case errnum of
  	  0: sh:='ok';
      1: sh:='Unsupported protocol';
	  2: sh:='Failed to initialize';
	  3: sh:='URL malformed';
	  5: sh:='Couldn''t resolve proxy';
	  6: sh:='Couldn''t resolve host';
	  7: sh:='Failed to connect to host';
	  8: sh:='FTP weird server reply';
	  9: sh:='FTP access denied';
	 11: sh:='FTP weird PASS reply';
	 13: sh:='FTP weird PASV reply';
	 14: sh:='FTP weird 227 format';
	 15: sh:='FTP can''t resolve host IP';
	 17: sh:='FTP couldn''t set binary';
	 18: sh:='Partial file';
	 19: sh:='FTP couldn''t download/access the given file';
	 21: sh:='FTP quote error';
	 22: sh:='HTTP page not retrieved';
	 23: sh:='Write error';
	 25: sh:='FTP couldn''t STOR file';
	 26: sh:='Read error';
	 27: sh:='Out of memory';
	 28: sh:='Operation timeout';
	 30: sh:='FTP PORT failed';
	 33: sh:='HTTP range error';
	 34: sh:='HTTP post error';
	 35: sh:='SSL connect error';
	 36: sh:='FTP bad download resume';
	 37: sh:='couldn''t read file. Failed to open the file. Permissions?';
	 49: sh:='Malformed telnet option';
	 51: sh:='The peer''s SSL certificate or SSH MD5 fingerprint was not OK';
	 52: sh:='The server didn''t reply anything';
	 67: sh:='failed to log in';
	else sh:='unknown errornum';
  end; // case
  if errnum<>0 then sh:='('+Num2Str(errnum,0)+') '+sh;
  CURL_ErrCode:=sh;
end;

function  CURLThread(ptr:pointer):ptrint;
var sh:string;
begin
  Thread_SetName('CURL_Thread'); 
  with CurlThreadCtrl do 
  begin 
    TermThread:=false; ThreadRunning:=true; ThreadProgress:=0;
    ThreadRetCode:=call_external_prog(LOG_NONE,ThreadCmdStr,sh);
//  writeln('CURLThread:',ThreadRetCode,':',sh,':');
	TermThread:=true;
    delay_msec(1000); // give other curl workers enough time to close 
    ThreadRunning:=false; 
  end; // with
  EndThread; 
  CURLThread:=0;
end;

function  PV_Progress(progressfile:string):integer;
// asumes that pv output is redirected to progressfile with -n option
// e.g. dd if=/dev/urandom bs=1M count=100 | pv -n -s 100m 2>/tmp/pv.out | dd of=/dev/null
// percentage is in /tmp/pv.out and is assigned to function result res
// requires apt-get install pv
var res:integer; sh:string;
begin
  res:=-1;
  if call_external_prog(LOG_NONE,'tail -n 1 '+progressfile,sh)=0 then 
  begin
    sh:=Select_Item(sh,#$0a,'',1);
    if not Str2Num(sh,res) then res:=-1;
  end;
  PV_Progress:=res;
end;

function  CURLcmdCreate(usrpwd,proxy,ofil,uri:string; flags:s_rpimaintflags):string;
var cmd:string;
begin
  if  	  UpdSUDO			IN flags	then cmd:='sudo curl ' else cmd:='curl '; 
  if not (UpdNoRedoRequest	IN flags) 	then cmd:=cmd+'-Lf '; 
  if not (UpdNoFTPDefaults 	IN flags) 	then cmd:=cmd+CURLFTPDefaults_c+' ';
  if UAgent 				IN flags 	then cmd:=cmd+'-A "User-Agent: '+UAgentDefault+'" ';
  if usrpwd<>'' 					  	then cmd:=cmd+'-u '+usrpwd+' ';
  if proxy<>''							then cmd:=cmd+'-x '+proxy+' ';
  if UpdVerbose 			IN flags	then cmd:=cmd+'-v ';
  if UpdSSL     			IN flags	then cmd:=cmd+'-k --ssl ';
  if not (UpdNoCreateDir 	IN flags) 	then cmd:=cmd+'--ftp-create-dirs ';
  if ofil<>'' 							then cmd:=cmd+'-o '+ofil+' ';
  cmd:=cmd+uri;
  CURLcmdCreate:=cmd;
end;

function  CURL(curlcmd,progressfile:string):integer;
const taillgt1_c=80;
  function  CURL_Progress(progressfil:string; taillgt:integer):string;
  var s,sh:string; p:integer;
  begin
    if call_external_prog(LOG_NONE,'tail -c'+Num2Str(taillgt,0)+' '+progressfil,sh)=0 then s:=sh else s:='';
    sh:=Trimme(copy(Select_Item(s,#$0d,'',2),1,3),3);
//  if CurlThreadCtrl.TermThread then writeln('BAR: ',HexStr(sh),' ',sh,' ',Str2Num(sh,p)); 
    if (taillgt<=taillgt1_c) and Str2Num(sh,p) and (p>=0) and (p<101) 
      then CurlThreadCtrl.ThreadProgress:=p;
    CURL_Progress:=#$0d+s;
  end;
var   dt:TDateTime; last:boolean; cnt,taillgt,curltimeout_sec:longint; bar:string; 
begin
  with CurlThreadCtrl do 
  begin 
	ThreadCmdStr:=curlcmd; 
	last:=false; cnt:=0; taillgt:=8*taillgt1_c; // get hdr info
	if not Str2Num(CURLTimeOut_c,curltimeout_sec) then curltimeout_sec:=300;
	curltimeout_sec:=round(curltimeout_sec*1.05);
	DeleteFile(progressfile);
	Thread_Start(CurlThreadCtrl,@CURLThread,@ThreadCmdStr,0,0);
	SetTimeOut(dt,curltimeout_sec*1000); delay_msec(500);
	repeat
	  if not TermThread then delay_msec(1000);
	  if (progressfile<>'') then
	  begin
		bar:=CURL_Progress(progressfile,taillgt);
	    if (bar<>'') then write(bar); 
	  end; 
	  if (not ThreadRunning) and (not last) then begin last:=true; SetTimeOut(dt,5000); end;
	  inc(cnt); if cnt>=1 then taillgt:=taillgt1_c;
	until TimeElapsed(dt) or ((ThreadProgress>=100) and (cnt>5));
	writeln;
//  writeln('End CURL ',ThreadProgress,' ',cnt,' to:',TimeElapsed(dt));
	Thread_End(CurlThreadCtrl,0);
	if ThreadRetCode<>0 then LOG_Writeln(LOG_ERROR,'CURL: '+CURL_ErrCode(ThreadRetCode));
//	DeleteFile(progressfile);
	CURL:=ThreadRetCode;
  end; // with
end;

function  CURL_TestProgressThread(ptr:pointer):ptrint;
// e.g. this thread could update a Gauge on an external OLED display
var enab:boolean; timo:TDateTime;
begin
  Thread_SetName('CURL_ProgressThread'); 
  enab:=true; 
  SetTimeOut(timo,10000); // give curl thread enough time to set ThreadRunning variable
  with CurlThreadCtrl do 
  begin 
	repeat
	  delay_msec(8000);
	  writeln;
	  writeln('Here is the thread, which handles curl progress information asynchronously ',ThreadProgress,'%');
	  if (TimeElapsed(timo) or ThreadRunning) then enab:=false;
	until (ThreadProgress>=100) or (not (ThreadRunning or enab));
    writeln('End CURL_TestProgressThread ',ThreadProgress);
  end; // with
  EndThread; 
  CURL_TestProgressThread:=0;
end;

procedure CURL_Test;
const pfil='/tmp/curltest.log';
var ret:integer; ThAsyncID:TThreadID; curlcmd:string;
begin
  curlcmd:=CURLcmdCreate('','','/dev/null',
  		'https://github.com/Hexxeh/rpi-firmware/tarball/52241088c1da59a359110d39c1875cda56496764',
  		[UpdNoCreateDir,UpdNoFTPDefaults]
  		)+' >'+pfil+' 2>'+pfil+'.prog';
  writeln(curlcmd);
  ThAsyncID:=BeginThread(@CURL_TestProgressThread,nil);	// do something async with the progress information
  ret:=CURL(curlcmd,pfil+'.prog');						// initiate curl download
//writeln('End CURL_Test1');
  WaitForThreadTerminate(ThAsyncID,20000);
  writeln('RetCode: ',ret);
end;

function  RPI_Maint(UpdFlags:s_rpimaintflags):integer; 
const test_c=false; test2_c=false; c_maxp=10; 
type  t_parr = array[1..c_maxp] of string;
var   p2:t_parr; j,res:integer; test,test2:boolean;
	  flgs:s_rpimaintflags; cmd:t_rpimaintflags; 
	  sh,cdmod,usrpwd,cmds,FTPServer,FTPUser,FTPPwd,FTPlogf,FTPOpts,
	  UpdPkgSrcFile,UpdPkgDstFile,UpdPkgDstDirAndFile,
	  UpdPkgMaintDir,UpdPkgMD5FileOld,UpdPkgDstDir,UpdPkglogf,
	  UplSrcFiles,UplDstDir,Upllogf,DwnSrcDir,DwnSrcFiles,DwnDstDir,DwnLogf:string;
	  
  function  cmdget(var p:t_parr):string; var i:integer; sh:string; begin sh:=p[1]; for i:=2 to c_maxp do sh:=sh+' '+p[i]; cmdget:=Trimme(sh,4); end;
  procedure parr_clean(var p:t_parr); var i:integer; begin for i:=1 to c_maxp do p[i]:=''; end;
  function  parr_gets (var p:t_parr):string; var i:integer; sh:string; begin sh:=''; if test2 then for i:=1 to c_maxp do if p[i]<>'' then sh:=sh+p[i]+' '; parr_gets:=Trimme(sh,3); end;
  procedure parr_show (s:string; var p:t_parr); begin if test2 then say(LOG_INFO,'maint: '+s+':'+parr_gets(p)+':'); end;
  function  MD5Chk(file1,file2:string):boolean;
  var ok:boolean; sh:string;
  begin
    ok:=MD5_Check(file1,file2); sh:='MD5_Check: '+file1+' '+file2+' same='+Bool2YN(ok);
    if ok then say(LOG_INFO,sh) else say(LOG_ERROR,sh);
    MD5Chk:=ok;
  end;
    
  function  cmd_do(p:t_parr):integer;
  var cmd:string; res:integer; page3:TStringList; 
  begin
    res:=-1;  	
  	if (p[1]<>'') then
	begin
	  cmd:=cmdget(p);
      if test then writeln('cmd_do: '+cmd);
	  page3:=TStringList.create; 
	  res:=call_external_prog(LOG_NONE,cmd,page3);
	  if not (res=0) then 
	  begin
		if not (UpdErrVerbose IN UpdFlags) then 
		begin 
		  LOG_Writeln(LOG_ERROR,'could not exec '+cmd);
		  if (page3.count>0) then LOG_ShowStringList(LOG_ERROR,page3); 
		end;
      end;							  
	  page3.free;
	end;
	cmd_do:=res;
  end;
    
begin
  res:=-1; test:=(UpdDBG1 IN UpdFlags); test2:=(UpdDBG2 IN UpdFlags);
  flgs:=UpdFlags+[UpdNOP]; 
  FTPServer:=		RpiMaintCmd.ReadString('RPIMAINT','FTPSRV', '');	
  FTPUser:=  		RpiMaintCmd.ReadString('RPIMAINT','FTPUSR', '');		
  FTPPwd:=	 	 	RpiMaintCmd.ReadString('RPIMAINT','FTPPWD', '');	
  FTPlogf:=	 	 	RpiMaintCmd.ReadString('RPIMAINT','FTPLOG', '/tmp/rpimaint_ftp.log');
  FTPOpts:=	 	 	RpiMaintCmd.ReadString('RPIMAINT','FTPOPT', CURLFTPDefaults_c);
  usrpwd:=			FTPUser; if usrpwd='' then usrpwd:='anonymous';
  if FTPPwd<>'' then usrpwd:=usrpwd+':'+FTPPwd;
  if UpdNoFTPDefaults IN UpdFlags then FTPOpts:='';
  UplSrcFiles:=		RpiMaintCmd.ReadString('RPIMAINT','UPLSF', '');		// <path1>/file1.tgz,<path2>/file2.tgz
  UplDstDir:=		RpiMaintCmd.ReadString('RPIMAINT','UPLDD', '/');	// /upload
  Upllogf:=			RpiMaintCmd.ReadString('RPIMAINT','UPLLOG','/tmp/rpimaint_upload.log'); 
  
  DwnSrcDir:=		RpiMaintCmd.ReadString('RPIMAINT','DWNSD', '/');	// /<ftpsrcpath>/
  DwnSrcFiles:=		RpiMaintCmd.ReadString('RPIMAINT','DWNSF', '');		// file1.ext,file2.ext
  DwnDstDir:=		RpiMaintCmd.ReadString('RPIMAINT','DWNDD', '/');	// /var/lib/<CompanyShortName>/rfm/upd/
  Dwnlogf:=			RpiMaintCmd.ReadString('RPIMAINT','DWNLOG','/tmp/rpimaint_dwnload.log'); 
  
  UpdPkgSrcFile:=	RpiMaintCmd.ReadString('RPIMAINT','UPDPSF', '');	// /rfm/rfm.tgz
  UpdPkgDstDir:=	RpiMaintCmd.ReadString('RPIMAINT','UPDPDD', '/tmp');// /tmp/
  UpdPkgDstFile:=	RpiMaintCmd.ReadString('RPIMAINT','UPDPDF', '');	// rfm.tgz
  UpdPkgMaintDir:=	RpiMaintCmd.ReadString('RPIMAINT','UPDMDIR','');	// /var/lib/<CompanyShortName>/rfm/upd/
  UpdPkglogf:=		RpiMaintCmd.ReadString('RPIMAINT','UPDPLOG','/tmp/rpimaint_updpkg.log');		    
  UpdPkgMD5FileOld:=   PrepFilePath(UpdPkgMaintDir+'/'+UpdPkgDstFile+'.md5');
  UpdPkgDstDirAndFile:=PrepFilePath(UpdPkgDstDir+  '/'+UpdPkgDstFile); 
  for cmd IN flgs do
  begin
    cmds:=GetEnumName(TypeInfo(t_rpimaintflags),ord(cmd));
//  say(LOG_Info,'maint cmd/attrib['+cmds+']: last: '+Bool2Str(cmd=High(flgs)));
    res:=-1; parr_clean(p2); // clear para array  
	case cmd of
	  UpdExec:		begin // e.g. EXEC=ls -l /tmp 
					  say(LOG_Info,'enter maint step: '+cmds);
	      			  sh:=RpiMaintCmd.ReadString('RPIMAINT','EXEC','');
	      			  if (sh<>'') then
	      			  begin	
	      				for j:=1 to c_maxp do p2[j]:=Select_Item(sh,' ','',j);
	      				if UpdSUDO IN UpdFlags then p2[1]:='sudo '+p2[1];  
	      				res:=cmd_do(p2); 
	      			  end else res:=0;
	      			end;
	  UpdUpload:	begin	
					  say(LOG_Info,'enter maint step: '+cmds);
	  				  if (FTPServer='') then
	  				  begin
	  				    say(LOG_ERROR,'maint['+cmds+']: no FTPServerInfo supplied, use RPI_MaintSetEnvFTP');  
	  				    break; 
	  				  end;
	  				  if (UplSrcFiles='') then
	  				  begin
	  				    say(LOG_ERROR,'maint['+cmds+']: no UpdPkgInfo supplied, use RPI_MaintSetEnvUPL');
	  				    break;
	  				  end;
//curl -u usr:pwd <curldefaults> -v -k --ssl -T "{file1,file2}" "ftp://host/upload/" > file.log 2> file.log.prog
					  p2[1]:='curl'; 	
					  if UpdSUDO 		IN UpdFlags 	  then p2[1]:='sudo '+p2[1]; 
					  
					  if usrpwd<>'' 					  then p2[2]:='-u '+usrpwd;
					  if UpdVerbose 	IN UpdFlags 	  then p2[2]:=p2[2]+' -v';
					  if UpdSSL     	IN UpdFlags 	  then p2[2]:=p2[2]+' -k --ssl';
					  if not (UpdNoCreateDir IN UpdFlags) then p2[2]:=p2[2]+' --ftp-create-dirs';
					  if FTPOpts<>'' then 	p2[2]:=p2[2]+' '+FTPOpts;
					  
					  p2[3]:='-T "{'+UplSrcFiles+'}"';
					  if UpdProtoHTTP 	IN UpdFlags
					    then p2[4]:='"http://'+FTPServer+UplDstDir+'"' // if you have multiple files, do not forget trailing /
					    else p2[4]:='"ftp://'+ FTPServer+UplDstDir+'"';
					  
					  if UpdLogAppend	IN UpdFlags then p2[7]:='>>' else p2[7]:='>'; 
					  p2[8]:='"'+Upllogf+'"';  
					  if not (UpdNoProgressBar IN UpdFlags) then
					  begin		
					    p2[9]:='2>'; p2[10]:='"'+Upllogf+'.prog"'; 
					  end;
					  parr_show('#1',p2);
					  if (CURL(cmdget(p2),p2[10])=0) then 
					  begin
						res:=0; 
						say(LOG_Info,'maint['+cmds+']: file '+UpdPkgSrcFile+' successfully uploaded');    			  
	      			  end;
	      			end;  	      			
	  UpdDownload:	begin // download file(s)
					  say(LOG_Info,'enter maint step: '+cmds);
	  				  if (FTPServer='') and (not (UpdProtoRAW IN UpdFlags)) then
	  				  begin 
	  				    say(LOG_ERROR,'maint['+cmds+']: no FTPSupportServer supplied, use RPI_MaintSetEnvFTP before');   
	  				    break;
	  				  end;
	  				  if (DwnSrcDir='') then
	  				  begin
	  				    say(LOG_ERROR,'maint['+cmds+']: no DwnSrcDir supplied, use RPI_MaintSetEnvDWN');
	  				    break;
	  				  end;
	  				  if (DwnSrcFiles='') then
	  				  begin
	  				    say(LOG_ERROR,'maint['+cmds+']: no DwnSrcFiles supplied, use RPI_MaintSetEnvDWN');
	  				    break;
	  				  end;
	  				  if (DwnDstDir='') then
	  				  begin
	  				    say(LOG_ERROR,'maint['+cmds+']: no DwnDstDir supplied, use RPI_MaintSetEnvDWN');
	  				    break;
	  				  end;
	  				  cdmod:='/#1';
	  				  if UpdProtoRAW 		IN UpdFlags then
	  				  begin
	  				  	sh:=DwnSrcDir+'/'+'{'+DwnSrcFiles+'}';
	  				  end
	  				  else
	  				  begin
	  				    if UpdProtoHTTP 	IN UpdFlags
					      then sh:='http://'+FTPServer+PrepFilePath(DwnSrcDir+'/')+'{'+DwnSrcFiles+'}'
					      else sh:='ftp://'+ FTPServer+PrepFilePath(DwnSrcDir+'/')+'{'+DwnSrcFiles+'}';
					  end;
					  if DwnDstDir='/dev/null' then cdmod:='';
//curl -u usr:pwd -v -k --ssl -o "./#1" "ftp://www.xyz.com/dir/{file1,file2,file3}" > "file.log" 2> "file.log.prog"
					  p2[1]:='curl'; 	
					  if usrpwd<>''						  	then p2[2]:='-u '+usrpwd;
					  if UpdSUDO		IN UpdFlags 	  	then p2[1]:='sudo '+p2[1];  
					  if not (UpdNoRedoRequest IN UpdFlags) then p2[2]:=p2[2]+' -Lf'; 					  
					  if UpdVerbose 	IN UpdFlags 	  	then p2[2]:=p2[2]+' -v';
					  if UpdSSL     	IN UpdFlags 	  	then p2[2]:=p2[2]+' -k --ssl';
					  if not (UpdNoCreateDir IN UpdFlags) 	then p2[2]:=p2[2]+' --ftp-create-dirs';
					  
					  p2[2]:=p2[2]+' '+FTPOpts;
					  p2[3]:='-o'; 		p2[4]:='"'+PrepFilePath(DwnDstDir+cdmod)+'"'; 
					  p2[5]:='"'+sh+'"';p2[6]:='';
					  					  
					  if UpdLogAppend	IN UpdFlags then p2[7]:='>>' else p2[7]:='>'; 
					  p2[8]:='"'+Dwnlogf+'"'; 
					  if not (UpdNoProgressBar IN UpdFlags) then
					  begin				
					    p2[9]:='2>'; p2[10]:='"'+Dwnlogf+'.prog"'; 
					  end;
					  parr_show('#1',p2);
					  if (CURL(cmdget(p2),p2[10])=0) then
					  begin
					    res:=0; 
						say(LOG_Info,'maint['+cmds+']: successfully downloaded '+DwnSrcFiles);
					  end else LOG_Writeln(LOG_ERROR,'maint['+cmds+']: Step#1 '+parr_gets(p2)); 
					end;
	      			
	  UpdPKGGet:	begin // get a whole install package, check if download is needed
					  say(LOG_Info,'enter maint step: '+cmds);
	  				  if FTPServer='' then
	  				  begin 
	  				    say(LOG_ERROR,'maint['+cmds+']: no FTPSupportServer supplied, use RPI_MaintSetEnvFTP before');   
	  				    break;
	  				  end;
	  				  if UpdProtoHTTP 	IN UpdFlags
					    then sh:='http://'+FTPServer+UpdPkgSrcFile
					    else sh:='ftp://'+ FTPServer+UpdPkgSrcFile;				  
//curl -u usr:pwd <curldefaults> -v -k --ssl -o <dstfile>.md5 "ftp://ftp.host.com/<MaintUpdPkgSrcFile>.md5" > file.log 2> file.log.prog
					  p2[1]:='curl'; 	
					  if usrpwd<>'' 					  then p2[2]:='-u '+usrpwd;
					  if UpdSUDO		IN UpdFlags 	  then p2[1]:='sudo '+p2[1];  
					  if UpdVerbose 	IN UpdFlags 	  then p2[2]:=p2[2]+' -v';
					  if UpdSSL     	IN UpdFlags 	  then p2[2]:=p2[2]+' -k --ssl';
					  if not (UpdNoCreateDir IN UpdFlags) then p2[2]:=p2[2]+' --ftp-create-dirs';
					  
					  p2[2]:=p2[2]+' '+FTPOpts;
					  p2[3]:='-o'; 			p2[4]:=UpdPkgDstDirAndFile+'.md5'; 
					  p2[5]:='"'+sh+'.md5"';p2[6]:='';
					  					  
					  if UpdLogAppend	IN UpdFlags then p2[7]:='>>' else p2[7]:='>'; 
					  p2[8]:=FTPlogf; 
					  if not (UpdNoProgressBar IN UpdFlags) then
					  begin				
					    p2[9]:='2>'; p2[10]:=FTPlogf+'.prog'; 
					  end;
					  parr_show('#1',p2);
					  if (CURL(cmdget(p2),p2[10])=0) then
					  begin
						say(LOG_Info,'maint['+cmds+']: successfully downloaded '+UpdPkgDstFile+'.md5');
						if not MD5Chk(UpdPkgDstDirAndFile+'.md5',UpdPkgMD5FileOld) then
						begin // get big file, there is a different package available
						  p2[4]:=UpdPkgDstDirAndFile; p2[5]:='"'+sh+'"'; p2[7]:='>>';
						  parr_show('#2',p2);
						  if (CURL(cmdget(p2),p2[10])=0) then
						  begin
							say(LOG_Info,'maint['+cmds+']: successfully downloaded '+UpdPkgDstFile);
							parr_clean(p2); 
							p2[1]:='md5sum'; p2[2]:=UpdPkgDstDirAndFile; 
							if UpdSUDO 	  IN UpdFlags then	p2[1]:='sudo '+p2[1];  
							p2[3]:='>'; p2[4]:=UpdPkgDstDirAndFile+'.md5.2'; 
							parr_show('#3',p2);
							if (cmd_do(p2)=0) then
							begin
							  if MD5Chk(UpdPkgDstDirAndFile+'.md5',UpdPkgDstDirAndFile+'.md5.2') then 
							  begin
								res:=0; say(LOG_Info,'maint['+cmds+']: valid md5 of '+UpdPkgDstFile);
							  end
							  else
							  begin
								LOG_Writeln(LOG_ERROR,'maint['+cmds+']: Step#4 '+parr_gets(p2)); 
								parr_clean(p2); 
								p2[1]:='rm'; 				p2[2]:='-f'; 
								if UpdSUDO IN UpdFlags then	p2[1]:='sudo '+p2[1];  
								p2[3]:=UpdPkgDstDirAndFile; 
								parr_show('#4',p2);
								LOG_Writeln(LOG_ERROR,'maint['+cmds+']: invalid md5 of '+UpdPkgDstFile+' '+parr_gets(p2));
								cmd_do(p2); // remove unvalid package
							  end;								  
							end else LOG_Writeln(LOG_ERROR,'maint['+cmds+']: Step#3 '+parr_gets(p2)); 
						  end else LOG_Writeln(LOG_ERROR,'maint['+cmds+']: Step#2 '+parr_gets(p2)); 
						end
						else 
						begin
						  res:=0; 
						  say(LOG_Info,'maint['+cmds+']: valid md5 of '+UpdPkgDstFile+', file was already successfully transferred');
						end;
					  end else LOG_Writeln(LOG_ERROR,'maint['+cmds+']: Step#1 '+parr_gets(p2)); 
					end;
					
	  UpdPKGInstal:	begin
					  say(LOG_Info,'enter maint step: '+cmds);
	  	  			  if (UpdPkgDstFile='') then
	  				  begin 
	  				    say(LOG_ERROR,'maint['+cmds+']: no UpdPkgInfo supplied, use RPI_MaintSetEnvUPD');  
	  				    break;
	  				  end;
					  if not MD5Chk(UpdPkgDstDirAndFile+'.md5',UpdPkgMD5FileOld) then
					  begin // newer pkg should be available, try to install it
						say(LOG_INFO,'maint: deploying newer package '+UpdPkgDstFile);
						if FileExists(UpdPkgDstDirAndFile) then
						begin						  
						  p2[1]:='tar'; 					p2[2]:='-xvzf';
						  if UpdSUDO 	  IN UpdFlags then	p2[1]:='sudo '+p2[1];  
						  p2[3]:=UpdPkgDstDirAndFile;		p2[4]:='-C'; 
						  p2[5]:=UpdPkgDstDir;  			p2[6]:='';
						  if UpdLogAppend IN UpdFlags then	p2[7]:='>>' 	else p2[7]:='>';  				
						  p2[8]:=UpdPkglogf; 				p2[9]:='2>&1'; 
						  parr_show('#1',p2);
						  if (cmd_do(p2)=0) then 
						  begin
							parr_clean(p2); 
							p2[1]:='chmod'; 				p2[2]:='+x'; 
							if UpdSUDO 	  IN UpdFlags then	p2[1]:='sudo '+p2[1];  
							p2[3]:=PrepFilePath(UpdPkgDstDir+'/install.sh');
							p2[7]:='>>'; 	p2[8]:=UpdPkglogf;	p2[9]:='2>&1';
							parr_show('#2',p2);
							if (cmd_do(p2)=0) then 
							begin			
							  parr_clean(p2);  
							  p2[1]:=PrepFilePath(UpdPkgDstDir+'/install.sh "'+rpi_snr+'" "'+UpdPkgMaintDir+'" "'+UpdPkglogf+'"');   //	execute install.sh
							  if UpdSUDO IN UpdFlags then		p2[1]:='sudo '+p2[1];  
							  p2[7]:='>>'; 	p2[8]:=UpdPkglogf;	p2[9]:='2>&1';
							  parr_show('#3',p2);
							  if (cmd_do(p2)=0) then 
							  begin	
							    res:=0;
							    parr_clean(p2);  // cp -f /tmp/rfm.tgz.md5 <UpdPkgMaintDir>/rfm.tgz.md5
							    p2[1]:='cp -f '+UpdPkgDstDirAndFile+'.md5 '+UpdPkgMD5FileOld;
								if UpdSUDO IN UpdFlags then	p2[1]:='sudo '+p2[1];  
							    cmd_do(p2);
							    if res=0 then say(LOG_Info,'maint['+cmds+']: package '+UpdPkgDstFile+' successfully deployed')
							        else LOG_Writeln(LOG_ERROR,'maint['+cmds+']: Step#5 '+p2[1]); 
							  end else LOG_Writeln(LOG_ERROR,'maint['+cmds+']: Step#4 '+p2[1]); 
							end else LOG_Writeln(LOG_ERROR,'maint['+cmds+']: Step#3 '+parr_gets(p2)); 
						  end else LOG_Writeln(LOG_ERROR,'maint['+cmds+']: Step#2 '+parr_gets(p2)); 
						end else LOG_Writeln(LOG_ERROR,'maint['+cmds+']: Step#1, Package not available: '+UpdPkgDstFile);							  
					  end
					  else 
					  begin
					    res:=0; 
					    say(LOG_INFO,'maint['+cmds+']: Packages are identical, no update needed');
					  end;
					end;
		  else		res:=0;	// do nothing, just attribs no commands
	    end; // case
	if res<>0 then break;
  end; // for
  RPI_Maint:=res;
end;
 
procedure Set_stty_speed(ttyandspeed:string); 	// e.g. /dev/ttyAMA0@9600
var _speed,_tty,sh:string; baudr:longword;
begin
  _tty:=  Select_Item(ttyandspeed,'@','',1);	// /dev/ttyAMA0
  _speed:=Select_Item(ttyandspeed,'@','',2);	// 9600
  if not Str2Num(_speed,baudr) then baudr:=9600;
  if FileExists(_tty) then
  begin
    call_external_prog(LOG_NONE,'stty -F '+_tty+' '+Num2Str(baudr,0),sh);
  end else LOG_Writeln(LOG_ERROR,'Set_stty_speed: device does not exist: '+ttyandspeed);
end;

procedure ERR_MGMT_UPD(errhdl:integer; cmdcode,datalgt:byte; modus:boolean);
begin
  if (errhdl<>NO_ERRHNDL) and (Length(ERR_MGMT)>0) and (errhdl<Length(ERR_MGMT)) then
  begin
    with ERR_MGMT[errhdl] do
	begin
	  if modus then
	  begin // ok part
	    TSokOld:=TSok; TSok:=now; 
		if AutoReset_ms>0 then
		begin
		  if (MilliSecondsBetween(TSok,TSerr)>=AutoReset_ms) then
		    begin RDerr:=0; WRerr:=0; CMDerr:=0; end;
		end;
	  end
	  else
	  begin // error part
	    TSerrOld:=TSerr; TSerr:=now;
	    case cmdcode of
	      _IOC_READ:  inc(RDerr);
		  _IOC_WRITE: inc(WRerr);
		  else		  inc(CMDerr);
	    end; // case
	  end;
	end; // with
  end;
end;

function  ERR_MGMT_GetErrCnt(errhdl:integer):longword;
var err:longword;
begin
  err:=0;
  if (Length(ERR_MGMT)>0) and (errhdl>=0) and (errhdl<Length(ERR_MGMT)) then
    with ERR_MGMT[errhdl] do err:=RDerr+WRerr+CMDerr;
  ERR_MGMT_GetErrCnt:=err;
end;
	
function  ERR_MGMT_STAT(errhdl:integer):boolean;
var ok:boolean;
begin
  if (Length(ERR_MGMT)>0) and (errhdl<Length(ERR_MGMT)) then
  begin
    with ERR_MGMT[errhdl] do begin ok:=((RDerr+WRerr+CMDerr)<MAXerr); end;
  end else ok:=true;
  ERR_MGMT_STAT:=ok;
end;

function  ERR_NEW_HNDL(adr:word; descr:string; maxerrs,AutoResetMsec:longword):integer; 
var h:integer;
begin 
  SetLength(ERR_MGMT,(Length(ERR_MGMT)+1)); 
  h:=(Length(ERR_MGMT)-1); 
  if h>=0 then 
  begin
    with ERR_MGMT[h] do
	begin
	  addr:=adr; desc:=descr; 
	  RDErr:=0; WRErr:=0; CMDerr:=0; MaxErr:=maxerrs;
	  TSok:=now; TSokOld:=TSok; TSerr:=TSok; TSerrOld:=TSerr;
	  AutoReset_ms:=AutoResetMsec;	// 0:off
	end; // with
  end;
  ERR_NEW_HNDL:=h;
end;

procedure ERR_End(hndl:integer); 
var i:integer;
begin 
  for i:= 1 to Length(ERR_MGMT) do
  begin
    with ERR_MGMT[i-1] do
	begin
	  if not ERR_MGMT_STAT(i-1) then
	    LOG_Writeln(LOG_ERROR,	'ERR_MGMT[0x'+Hex(addr,4)+']: '+' '+desc+
								' ERR RD:'+Num2Str(RDerr,0)+
								' WR:'+Num2Str(WRerr,0)+
								' CMD:'+Num2Str(CMDerr,0)+
								' AutoReset:'+Num2Str(AutoReset_ms,0)+'ms');
	end; // with
  end;
  SetLength(ERR_MGMT,0); 
end;

{$IFDEF UNIX}  
function  Term_ptmx(var termio:Terminal_device_t; link:string; menablemask,mdisablemask:longint):boolean;
// opens pseudo terminal.
// returns master and slave filedescriptor, and slavename for usage. link, links slavename to link
// masks: Term_ptmx(x,x,x,x, 0,ECHO) -> disables TerminalECHO // 0=noEnableAnything,disable ECHO
const ptmx_c='/dev/ptmx';
var snp:pchar; linkflag:boolean; tl:TStringList; newsettings:termios; sh:string;
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
			      if FileExists(link) then 
				  begin 
				    LOG_WRITELN(LOG_Warning,'ptmx, link exits: '+link+' (unlink '+link+')');
				    call_external_prog(LOG_NONE,'unlink '+link+'; ls -l '+link,sh);
					LOG_ShowStringList(LOG_WARNING,tl);
			        sleep(500);
				  end;
				  if (not FileExists(link)) then
			      begin
			        call_external_prog(LOG_NONE,'ln -s '+slavepath+' '+link+'; ls -l '+link,sh);
//LOG_ShowStringList(LOG_WARNING,tl);
					sleep(500);
				    linkflag:=FileExists(link);
				    if not linkflag then 
					begin
					  LOG_WRITELN(LOG_ERROR,'ptmx: cannot create link '+link+' (ln -s '+slavepath+' '+link+')');
					  LOG_ShowStringList(LOG_ERROR,tl);
					end;
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
	  writeln('Screen1: pls. open 2 additional terminal sessions (e.g. with putty to your pi user:root)');
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
	  writeln('End of Test_BiDirectionDevice_in_UserSpace (you should get an Input/output error on screen2 now)');
    end
    else writeln('ptmx init failed');
  end;
end;
{$ENDIF}

procedure Get_CPU_INFO_Init;   
const proc1_c='cat /proc/cpuinfo'; proc2_c='cat /sys/devices/system/cpu/cpu0/cpufreq/cpuinfo'; 
	  proc3_c='for src in arm core h264 isp v3d uart pwm emmc pixel vec hdmi dpi ; do echo -e "$src:\t$(vcgencmd measure_clock $src)" ; done'; 
var ts:TStringlist; sh:string; lw:longword; code:integer; 
  function cpuinfo_unix(infoline:string):string;
  var s:string; i:integer;
  begin
    s:=''; i:=1; while i<=ts.count do begin if Pos(Upper(infoline),Upper(ts[i-1]))=1 then begin s:=ts[i-1]; i:=ts.count+1 end; inc(i); end;
	cpuinfo_unix:=copy(s,Pos(':',s)+2,Length(s));
  end;
  function getvcgencmd(opt:string; var val:real):boolean;
  var _ok:boolean;
  begin
    ts.clear; _ok:=false;
    if (call_external_prog(LOG_NONE,'vcgencmd measure_clock '+opt,sh)=0) then 
    begin
      sh:=RM_CRLF(sh);
	  if sh<>'' then if Str2Num(copy(sh,Pos(')=',sh)+2,Length(sh)),val) then _ok:=true;
	end;
	getvcgencmd:=_ok;
  end;
  function RPI_SetInfo(cpurevs,desc:string; cpurev,I2Cbusnr,gpioidx,slednr,pincnt:byte;memsizMB:word):string;
//         RPI_SetInfo('a02082','2B',       3,     1,       2,      47,    40,         1024); // PI2B  
  begin
    connector_pin_count:=pincnt; cpu_rev_num:=cpurev; I2C_busnum:=I2Cbusnr; 
    GPIO_map_idx:=gpioidx; 	status_led_GPIO:=slednr; 
    RPI_SetInfo:=	'rev'+Num2Str(cpurev,0)+';'+
					Num2Str(memsizMB,0)+'MB;'+
					desc+';'+cpurevs+';'+
	                Num2Str(connector_pin_count,0);	//	  rev3;1024MB;2B;a02082;40	
  end;
begin 
   cpu_snr:='';  cpu_hw:='';   cpu_proc:=''; cpu_rev:=''; cpu_mips:=''; cpu_feat:=''; cpu_rev_num:=0;
   cpu_fmin:=''; cpu_fcur:=''; cpu_fmax:=''; I2C_busnum:=0; status_led_GPIO:=0; 
   for lw:=1 to max_pins_c do RPIHDR_Desc[lw]:='';
   connector_pin_count:=40; 
   cpu_freq:= 700000000; pll_freq:=2000000000; 
  {$IFDEF UNIX}  
	ts:=TStringList.Create;
	call_external_prog(LOG_NONE,proc2_c+'_min_freq',sh); cpu_fmin:=RM_CRLF(sh);
	call_external_prog(LOG_NONE,proc2_c+'_cur_freq',sh); cpu_fcur:=RM_CRLF(sh);
	call_external_prog(LOG_NONE,proc2_c+'_max_freq',sh); cpu_fmax:=RM_CRLF(sh);
    if not getvcgencmd('arm', cpu_freq)	then cpu_freq:= 700000000; 	
    lw:=round(2*pllc_freq_c/1000000);
	pll_freq:=floor(2400 div lw)*lw*1000000; if pll_freq>0 then ;
//  writeln('CPU Freq: ',cpu_fmin,' ',cpu_fcur,' ',cpu_fmax,' ',cpu_freq,' ',pllc_freq_c,' ',pll_freq);
	if call_external_prog(LOG_NONE,proc1_c,ts)=0 then
    begin
	  cpu_snr:= cpuinfo_unix('Serial');			// e.g. 0000...
	  cpu_hw:=  cpuinfo_unix('Hardware');		// e.g. BCM2709
	  cpu_proc:=cpuinfo_unix('Processor');
	  cpu_mips:=cpuinfo_unix('BogoMIPS');
	  cpu_feat:=cpuinfo_unix('Features');
	  cpu_rev:= cpuinfo_unix('Revision');		// e.g. a01041
	  I2C_busnum:=1; status_led_GPIO:=47;   
      cpu_rev_num:=0; GPIO_map_idx:=cpu_rev_num; 
	  val('$'+cpu_rev,lw,code); 
	  if (code=0) and ((Pos('BCM',cpu_hw)=1)) then
	  begin 
//writeln('cpuinfo ',hex(lw,8));
//http://elinux.org/RPI_HardwareHistory
//http://www.raspberrypi-spy.co.uk/2012/09/checking-your-raspberry-pi-board-version/
        case (lw and $7fffff) of // mask out overvoltage bit
          $00..$03 : cpu_rev:=RPI_SetInfo(cpu_rev,'B', 1,0,1,16,26, 256);
	      $04..$06 : cpu_rev:=RPI_SetInfo(cpu_rev,'B', 2,1,2,16,26, 256);
		  $07..$09 : cpu_rev:=RPI_SetInfo(cpu_rev,'A', 2,1,2,16,26, 256);
		  $0d..$0f : cpu_rev:=RPI_SetInfo(cpu_rev,'B', 2,1,2,16,26, 512);
		  $10,$13  : cpu_rev:=RPI_SetInfo(cpu_rev,'B+',1,0,2,47,40, 512);
		  $11,$14  : cpu_rev:=RPI_SetInfo(cpu_rev,'CM',1,0,2,47, 0, 512); 	// ComputeModule
		  $12,$15  : cpu_rev:=RPI_SetInfo(cpu_rev,'A+',1,0,2,47,40, 256);
		  $1000c1,
		  $100092,
		  $100093  : cpu_rev:=RPI_SetInfo(cpu_rev,'Z', 7,0,2,47,40, 512); 	// PiZero (900092)
		  $222042,
		  $221041,	// a21041 or a01041 (overvoltage bit was masked out)  
		  $201041  : cpu_rev:=RPI_SetInfo(cpu_rev,'2B',3,1,2,47,40,1024); 	// Pi2B
		  $222082,															// Pi3B (a22082 Embest, China)
		  $202082  : cpu_rev:=RPI_SetInfo(cpu_rev,'3B',4,1,2,47,40,1024); 	// Pi3B (a02082 Sony, UK)
		  else LOG_Writeln(LOG_ERROR,'Get_CPU_INFO_Init: (0x'+Hex(lw,8)+') unknown rev:'+cpu_rev+': RPI not supported');
        end; // case   
      end else Log_Writeln(LOG_ERROR,'Get_CPU_INFO_Init: Rev:'+cpu_rev+' Hardware:'+cpu_hw+' Processor:'+cpu_proc+' no known platform');
//    writeln(cpu_rev_num);	  
    end;	
	ts.free;   
  {$ENDIF}
end;

function  Bin(q:longword;lgt:Byte) : string;
{.c shows q in binary representation: bbbb bbbb ... }
var h : string; i : Byte;
begin
  h:='';
  for i := (lgt-1) downto 0 do
  begin
    if ((q and (1 shl i))>0)   then h:=h+'1' else h:=h+'0';
	if ((i mod 4)=0) and (i>0) then h:=h+' ';
  end;
  Bin:=h;
end; { Bin }

function  RPI_GetBuildDateTimeString:string;
var sh:string;
begin
  sh:=StringReplace(prog_build_date,'/','-',[rfReplaceAll,rfIgnoreCase]);
  sh:=sh+'T'+prog_build_time;
  RPI_GetBuildDateTimeString:=sh;
end;

procedure RPI_HDR_SetDesc(HWPin:longint; desc:string);
begin if (HWPin>=1) and (HWPin<=max_pins_c) then RPIHDR_Desc[HWPin]:=copy(desc,1,mdl); end;

function  RPI_mmap_get_info (modus:longint)  : longword;
var valu:longword; li:longint; sh:string;
begin 
  valu:=0;
  case modus of
	 1,2 : valu:=PAGE_SIZE;
	 3	 : begin 
			 valu:=BCM2709_PBASE; // for BCM2709 and BCM2835
			 if (Upper(RPI_hw)='BCM2708') then valu:=BCM2708_PBASE;	// for old RPI	 
		   end;
	 4   : begin {$IFDEF UNIX} valu:=1; {$ELSE} valu:=0; {$ENDIF} end;      (* if run_on_unix ->1 else 0 *)
	 5   : if (Upper({$i %FPCTARGETCPU%})='ARM') then valu:=1 else valu:=0; (* if run_on_ARM  ->1 else 0 *)
	 6	 : begin valu:=1; end;												(* if RPI_Piggyback_board_available -> 1 dummy, for future use *)
	 7   : if ((RPI_mmap_get_info(5)=1) and 
	           ((Upper(RPI_hw)='BCM2708') or
	            (Upper(RPI_hw)='BCM2835') or 								(* new in Linux raspberrypi 4.9.11-v7+ #971 SMP Mon Feb 20 20:44:55 GMT 2017 armv7l GNU/Linux *) 
			    (Upper(RPI_hw)='BCM2709'))) then valu:=1;		   			(* runs on known rpi HW *)  
	 8	 : begin valu:=1; end;												(* if PiFaceBoard_board_available -> 1 dummy, for future use *)
	 9   : begin 
	 	     call_external_prog(LOG_NONE,'uname -v',sh); 						// e.g. #970 SMP Mon Feb 20 19:18:29 GMT 2017
	 	     sh:=Select_Item(sh,' ','',1);										// #970
	 	     sh:=GetNumChar(sh);												// 970
	 	     if not Str2Num(sh,li) then li:=-1;									// dummy, works with kernel above 4.4.50 
	 	     if (li<supminkrnl) or (li>supmaxkrnl) then valu:=1 else valu:=1;	// dummy, supported min./max. kernel version 4.0.5 - 4.4.50
	 	   end;
  end;
  RPI_mmap_get_info:=valu;
end;

function  RPI_BCM2835:boolean; begin RPI_BCM2835:=(Upper(RPI_hw)='BCM2835'); end;

function  RPI_BCM2835_GetNodeValue(node:string; var nodereturn:string):longint;
var res:longint;
begin
  res:=-1; 
  if RPI_BCM2835 then
  begin
   call_external_prog(LOG_NONE,'xxd -ps '+node,nodereturn);
   if not Str2Num('$'+GetHexChar(nodereturn),res) then res:=-1; 
// nodereturn:=StrHex(nodereturn);
  end;
  RPI_BCM2835_GetNodeValue:=res;
end;

function  RPI_I2C_GetSpeed(bus:byte):longint;
var speed_kHz:longint; sh:string;
begin
  speed_kHz:=RPI_BCM2835_GetNodeValue('/sys/class/i2c-adapter/i2c-1/of_node/clock-frequency',sh);
  if speed_kHz<0 then
  begin // last chance, try dmesg
    call_external_prog(LOG_NONE,'dmesg | grep bcm2708_i2c',sh); 
    sh:=Select_Item(Upper (sh),	'(BAUDRATE','',2);	//  400000)
    sh:=Select_Item(Trimme(sh,4), ')','',1);		//  400000
    if not Str2Num(sh,speed_kHz) then speed_kHz:=-1;
  end;
  RPI_I2C_GetSpeed:=speed_kHz;
end;

function RPI_get_GPIO_BASE:longword;						begin RPI_get_GPIO_BASE:=RPI_mmap_get_info(3); end;
function RPI_mmap_run_on_unix:boolean; 						begin RPI_mmap_run_on_unix:=(RPI_mmap_get_info(4)=1); end;
function RPI_run_on_ARM:boolean;       						begin RPI_run_on_ARM :=     (RPI_mmap_get_info(5)=1); end;
function RPI_Piggyback_board_available  : boolean; 			begin RPI_Piggyback_board_available:=(RPI_mmap_get_info(6)=1); end;
function RPI_PiFace_board_available(devadr:byte): boolean; 	begin RPI_PiFace_board_available:=   (RPI_mmap_get_info(8)=1); end;
function RPI_run_on_known_hw:boolean;     					begin RPI_run_on_known_hw := (RPI_mmap_get_info(7)=1); end;
function RPI_platform_ok:boolean; 							begin RPI_platform_ok:= ((RPI_run_on_known_hw) and ((RPI_mmap_get_info(9)=1))) end;
function GetRegAdr(idx:longword):longword; 					begin GetRegAdr:=RPI_get_GPIO_BASE+(idx*BCM270x_RegSizInByte);end;

function  GPIO_get_ALTMask(gpio:longword; altfunc:t_port_flags):longword;
//INPUT=0; OUTPUT=1; ALT0=4; ALT1=5; ALT2=6; ALT3=7; ALT4=3; ALT5=2;
var msk,afkt:longword;
begin
  afkt:=ord(altfunc) and $7; 
  if (altfunc=INPUT) then afkt:=7; // Reset Mask
  msk:=(afkt shl ((gpio mod 10)*3));
  GPIO_get_ALTMask:=msk;
end;

procedure GPIO_get_mask_and_idxOfs(regidx,gpio:longword; var idxofs:longint; var mask:longword);
begin
  idxofs:=0; mask:=0;
  case regidx of  
	GPFSEL : begin idxofs:=((gpio mod gpiomax_reg_c) div 10); mask:=(7 shl ((gpio mod 10)*3)); end;
	else     begin idxofs:=((gpio mod gpiomax_reg_c) div 32); mask:=(1 shl ( gpio mod 32));    end;
  end; // case
end;

procedure GPIO_get_mask_and_idx(regidx,gpio:longword; var idxabs,mask:longword);
// out:idxabs gives absolute index
var iofs:longint;
begin
  GPIO_get_mask_and_idxOfs(regidx,gpio,iofs,mask); idxabs:=regidx+iofs; 
end;

function  valid_regidx(regidx:longword):boolean;
var ok:boolean;
begin
 ok:=((mmap_arr<>nil) and (regidx<=BCM270x_RegMaxIdx));
 if not ok then
   LOG_WRITELN(LOG_ERROR,'valid_regidx: not initialized or regidx not valid: '+num2Str(regidx,0));
 valid_regidx:=ok;
end;

function  BCM_GETREG (regidx:longword):longword; 
begin 
//writeln('Boom: 0x',Hex(regidx,8),' ',regidx);
BCM_GETREG:=mmap_arr^[regidx]; 
end;


procedure BCM_SETREG (regidx,newval:longword);   begin mmap_arr^[regidx]:=newval; end;

procedure BCM_SETREG (regidx,newval:longword; and_mask,readmodifywrite:boolean);
begin
//if valid_regidx(regidx) then
  begin
    if readmodifywrite then
    begin
	  if and_mask then BCM_SETREG(regidx,BCM_GETREG(regidx) and newval) 
				  else BCM_SETREG(regidx,BCM_GETREG(regidx) or  newval);
    end
	else BCM_SETREG(regidx,newval); 
  end;
end;

procedure MEM_SpeedTest; // just for investigations
// tests access speed to RPI Registers vs. regular memory.  
// result: access to register is around 6 times slower than access to memory !!!
// on a Pi3 Model B
// mem:  199ms
// mmap: 1204ms APMIRQCLRACK Value: 0x544D5241
const loops=10000000;
var i,lw,lw1:longword; dt1,dt2,dt3:TDateTime;
begin
  lw:=1234; lw1:=lw; if lw1>0 then ;
  dt1:=now; for i:=1 to loops do lw1:=lw;
  dt2:=now; for i:=1 to loops do lw1:=mmap_arr^[APMIRQCLRACK]; // 0x544D5241
  dt3:=now; 
  writeln('mem:  ',MilliSecondsBetween(dt2,dt1),'ms');
  writeln('mmap: ',MilliSecondsBetween(dt3,dt2),'ms',' APMIRQCLRACK Value: 0x',Hex(lw1,4));
end;

function  MMAP_start:integer;
//Set up a memory mapped region to access peripherals
var rslt,errno:longint; 
begin
  rslt:=-1; errno:=0; restrict2gpio:=false; 
  {$IFDEF LINUX}
    if RPI_run_on_ARM and (mmap_arr=nil) then 
    begin 
      mem_fd:=fpOpen('/dev/mem',(O_RDWR or O_SYNC (*or O_CLOEXEC*)));		// open /dev/mem 
	  if mem_fd<0 then
      begin 
//      rslt:=-2; restrict2gpio:=true; 
//      mem_fd:=fpOpen('/dev/gpiomem',(O_RDWR or O_SYNC (*or O_CLOEXEC*)));	// open /dev/gpiomem
//		not supported
      end;
      if mem_fd>=0 then 
      begin // mmap GPIO
	    rslt:=-3;
		mmap_arr:=fpMMap(pointer(0),BCM270x_PSIZ_Byte,
		                 (PROT_READ or PROT_WRITE),
						 (MAP_SHARED {or MAP_FIXED}),
						 mem_fd,
						 (RPI_get_GPIO_BASE div PAGE_SIZE)
						); 
		if mmap_arr=MAP_FAILED then errno:=fpgeterrno else rslt:=0; 
		fpclose(mem_fd);
		if (rslt=0) and (not restrict2gpio) then
		begin 
		  rslt:=-4;
// When reading this register it returns 0x544D5241 which is the ASCII reversed value for "ARMT".
		  if (BCM_GETREG(APMIRQCLRACK)= $544D5241) then rslt:=0; // ok
		end;
      end;
    end;
  {$ENDIF}
  case rslt of
     0 : Log_writeln(Log_INFO, 'RPI_mmap_init, init successful');
    -1 : Log_writeln(Log_ERROR,'RPI_mmap_init, can not open /dev/mem on target CPU '+{$i %FPCTARGETCPU%}+', result: '+Num2Str(rslt,0));
    -2 : Log_writeln(Log_ERROR,'RPI_mmap_init, can not open /dev/gpiomem on target CPU '+{$i %FPCTARGETCPU%}+', result: '+Num2Str(rslt,0));
    -3 : Log_writeln(Log_ERROR,'RPI_mmap_init, mmap fpgeterrno: '+Num2Str(errno,0)+' result: '+Num2Str(rslt,0));
	-4 : Log_writeln(Log_ERROR,'RPI_mmap_init, can not read test register APMIRQCLRACK');
	else Log_writeln(Log_ERROR,'RPI_mmap_init, unknown error, result: '+Num2Str(rslt,0));
  end;
  if rslt=0 then 
  begin
    if restrict2gpio then Log_writeln(Log_WARNING,'RPI_mmap_init, only GPIO access allowed');
  end else mmap_arr:=nil;	
  MMAP_start:=rslt;
end;

procedure MMAP_end;
var rslt:longint;
begin
  rslt:=0;
  {$IFDEF UNIX} 
	if (mmap_arr<>nil) 	then fpMUnMap(mmap_arr,BCM270x_PSIZ_Byte);
  {$ENDIF}
  mmap_arr:=nil; 
  case rslt of
     0 : Log_writeln(Log_INFO, 'RPI_mmap_close, successful '+Num2Str(rslt,0));
    -1 : Log_writeln(Log_ERROR,'RPI_mmap_close, un-mmapping '+Num2Str(rslt,0));
    else Log_writeln(Log_ERROR,'RPI_mmap_close, unknown error '+Num2Str(rslt,0));	
  end;
end;

function  GPIO_Start:integer; begin GPIO_Start:=MMAP_start; end;

function  GPIO_HWPWM_capable(gpio:longword; pwmnum:byte):boolean;
var ok:boolean;
begin
  ok:=false;
  if not ok then ok:=((pwmnum=0) and ((gpio=GPIO_PWM0) or (gpio=GPIO_PWM0A0)));
  if not ok then ok:=((pwmnum=1) and ((gpio=GPIO_PWM1) or (gpio=GPIO_PWM1A0)));
  GPIO_HWPWM_capable:=ok;
end;

function  GPIO_HWPWM_capable(gpio:longword):boolean;
begin GPIO_HWPWM_capable:=(GPIO_HWPWM_capable(gpio,0) or GPIO_HWPWM_capable(gpio,1)); end;

function  GPIO_FCTOK(gpio:longint; flags:s_port_flags):boolean;
var _ok:boolean; 
begin
  _ok:=((gpio>=0) and (GPIO_MAP_GPIO_NUM_2_HDR_PIN(gpio)>=0));
  if _ok and (PWMHW IN flags) then _ok:=GPIO_HWPWM_capable(gpio);
  if _ok and (FRQHW IN flags) then 
	 _ok:=((gpio=GPIO_FRQ04_CLK0) or (gpio=GPIO_FRQ05_CLK1) or (gpio=GPIO_FRQ06_CLK2) or 
	       (gpio=GPIO_FRQ20_CLK0) or (gpio=GPIO_FRQ32_CLK0) or (gpio=GPIO_FRQ34_CLK0) or
		   (gpio=GPIO_FRQ42_CLK1) or (gpio=GPIO_FRQ43_CLK2) or (gpio=GPIO_FRQ42_CLK1));
  GPIO_FCTOK:=_ok;
end;

function GPIO_get_AltDesc(gpio:longint; altpin:byte; dfltifempty:string):string;
// datasheet page 102 
const maxalt_c=5; res=''; intrnl='<intrnl>';
      Alt_hdr_dsc_c   : array[0..maxalt_c] of array[0..gpiomax_reg_c-1] of string[mdl] = 
  (	// ALT0
    ( ('I2C SDA0'),		('I2C SCL0'),	('I2C SDA1'),	('I2C SCL1'),	('GPCLK0'),
	  ('GPCLK1'),		('GPCLK2'),		('SPI0 CE1/'),	('SPI0 CE0/'),	('SPI0 MISO'),
	  ('SPI0 MOSI'),	('SPI0 SCLK'),	('PWM0'),		('PWM1'),		('TxD0'),
	  ('RxD0'),			(res),			(res),			('PCM CLK'),	('PCM FS'),
	  ('PVM DIN'),		('PCMDOUT'),	(res),			(res),			(res),
	  (res),			(res),			(res),			('SDA0'),		('SCL0'),
	  (res),			(res),			('GPCLK0'),		(res),			('GPCLK0'),
	  ('SPI0 CE1/'),	('SPI0 CE0/'),	('SPI0 MISO'),	('SPI0 MOSI'),	('SPI0 SCLK'),
	  ('PWM0'),		 	('PWM1'),		('GPCLK1'),		('GPCLK2'),		('GPCLK3'),
	  ('PWM1'),			(intrnl),		(intrnl),		(intrnl),		(intrnl),
	  (intrnl),			(intrnl),		(intrnl),		(intrnl)		),
	// ALT1
    ( ('SA5'),			('SA4'),		('SA3'),		('SA2'),		('SA1'),
	  ('SA0'),			('SOE/'),		('SWE/'),		('SD0'),		('SD1'),
	  ('SD2'),			('SD3'),		('SD4'),		('SD5'),		('SD6'),
	  ('SD7'),			('SD8'),		('SD9'),		('SD10'),		('SD11'),
	  ('SD12'),			('SD13'),		('SD14'),		('SD15'),		('SD16'),
	  ('SD17'),			(res),			(res),			('SA5'),		('SA4'),
	  ('SA3'),			('SA2'),		('SA1'),		('SA0'),		('SOE/'),
	  ('SWE/'),			('SD0'),		('SD1'),		('SD2'),		('SD3'),
	  ('SD4'),			('SD5'),		('SD6'),		('SD7'),		('SDA0'),
	  ('SCL0'),			(''),			(''),			(''),			(''),	
	  (''),				(''),			(''),			('')		  ),
	// ALT2	  
	( (res),			(res),			(res),			(res),			(res),
	  (res),			(res),			(res),			(res),			(res),
	  (res),			(res),			(res),			(res),			(res),
	  (res),			(res),			(res),			(res),			(res),
	  (res),			(res),			(res),			(res),			(res),
	  (res),			(res),			(res),			('PCM CLK'),	('PCM FS'),
	  ('PCM DIN'),		('PCM DOUT'),	(res),			(res),			(res),
	  (''),				('TxD0'),		('RxD0'),		('RTS0'),		('CTS0'),
	  (''),				(res),			(res),			(res),			('SDA1'),
	  ('SCL1'),			(''),			(''),			(''),			(''),	
	  (''),				(''),			(''),			('')		  ),
	// ALT3	  
	( (''),				(''),			(''),			(''),			(''),
	  (''),				(''),			(''),			(''),			(''),
	  (''),				(''),			(''),			(''),			(''),
	  (''),				('CTS0'),		('RTS0'),		('BSCL'),		('BSCL'),
	  ('BSCL'),			('BSCL'),		('SD1 CLK'),	('SD1 CMD'),	('SD1 DAT0'),
	  ('SD1 DAT1'),		('SD1 DAT2'),	('SD1 DAT3'),	(res),			(res),
	  ('CTS0'),			('RTS0'),		('TxD0'),		('RxD0'),		(res),
	  (res),			(res),			(res),			(res),			(res),
	  (res),			(res),			(res),			(res),			(res),
	  (''),				(''),			(''),			(''),			(''),	  
	  (''),				(''),			(''),			('')		),
	// ALT4
	( (''),				(''),			(''),			(''),			(''),
	  (''),				(''),			(''),			(''),			(''),
	  (''),				(''),			(''),			(''),			(''),
	  (''),				('SPI1 CE2/'),	('SPI1 CE1/'),	('SPI1 CE0/'),	('SPI1 MISO'),
	  ('SPI1 MOSI'),	('SPI1 SCLK'),	('ARM TRST'),	('ARM RTCK'),	('ARM TDO'),
	  ('ARM TCK'),		('ARM TDI'),	('ARM TMS'),	(''),			(''),
	  (''),				(''),			(''),			(''),			(''),
	  (''),				(''),			(''),			(''),			(''),
	  ('SPI2 MISO'),	('SPI2 MOSI'),	('SPI2 SCLK'),	('SPI2 CE0/'),	('SPI2 CE1/'),
	  ('SPI2 CE2/'),	(''),			(''),			(''),			(''),	  	  
	  (''),				(''),			(''),			('')		),
	// ALT5
	( (''),				(''),			(''),			(''),			('ARM TDI'),
	  ('ARM TDO'),		('ARM RTCK'),	(''),			(''),			(''),
	  (''),				(''),			('ARM TMS'),	('ARM TCK'),	('TxD1'),
	  ('RxD1'),			('CTS1'),		('RTS1'),		('PWM0'),		('PWM1'),
	  ('GPCLK0'),		('GPCLK1'),		(''),			(''),			(''),
	  (''),				(''),			(''),			(''),			(''),
	  ('CTS1'),			('RTS1'),		('TxD1'),		('RxD1'),		(''),
	  (''),				(''),			(''),			(''),			(''),
	  ('TxD1'),			('RxD1'),		('RTS1'),		('CTS1'),		(''),	
	  (''),				(''),			(''),			(''),			(''),	  
	  (''),				(''),			(''),			('')		)	  
  );
var sh:string;
begin
{$warnings off}
  if (altpin>=0) and (altpin<=maxalt_c) and 
	 (gpio>=0)   and (gpio<gpiomax_reg_c)    then sh:=Alt_hdr_dsc_c[altpin,gpio] else sh:='';
{$warnings on}  
  if sh='' then sh:=dfltifempty;
  GPIO_get_AltDesc:=sh;
end; //GPIO_get_AltDesc

function GPIO_get_altval(RegAltVal:byte):byte;
var b:byte;
begin
  b:=(RegAltVal and $07);
  case b of 
    $02..$03: 	b:=$07-b;	// A04 A05
	$04..$05,
	$06..$07: 	b:=b-$04;	// A00 A01 A02 A03
  end;
  GPIO_get_altval:=b;
end;

function gpiofkt(gpio:longint; gpiofunc:byte; desclong:boolean):string;
var s:string; av:byte;
begin
  case (gpiofunc and $7) of
	$00 : 		s:='IN '; 
	$01 : 		s:='OUT'; 
	$02..$07: 	begin 
				  av:=GPIO_get_altval(gpiofunc);
				  s:='A'+Num2Str(av,0)+' '; 
				  if desclong then s:=GPIO_get_AltDesc(gpio,av,s); 
				end; 
	else  s:='';
  end;
 gpiofkt:=s;
end;

function  GPIO_get_fkt_value(gpio:longint):byte;
var regidx,mask:longword; altval:byte;
begin
  altval:=$00;
  if (gpio>=0) and (gpio<gpiomax_reg_c) then
  begin
    GPIO_get_mask_and_idx(GPFSEL,gpio,regidx,mask);
	altval:=Byte(((BCM_GETREG(regidx) and mask) shr ((gpio mod 10)*3)) and $7);
  end;  
  GPIO_get_fkt_value:=altval;
end;

function get_reg_desc(regidx,regcontent:longword):string;
var s:string;
begin
  s:='';
  case regidx of
  	GPFSEL..GPFSEL+5: 		s:='GPFSEL'+  Num2Str(longword(regidx-GPFSEL),0); 
	GPSET ..GPSET+1: 		s:='GPSET'+   Num2Str(longword(regidx-GPSET),0); 
    GPCLR ..GPCLR+1: 		s:='GPCLR'+   Num2Str(longword(regidx-GPCLR),0);
	GPLEV ..GPLEV+1: 		s:='GPLEV'+   Num2Str(longword(regidx-GPLEV),0);
	GPEDS ..GPEDS+1: 		s:='GPEDS'+   Num2Str(longword(regidx-GPEDS),0);
	GPREN	..GPREN+1: 		s:='GPREN'+   Num2Str(longword(regidx-GPREN),0); 	
	GPFEN ..GPFEN+1: 		s:='GPFEN'+   Num2Str(longword(regidx-GPFEN),0); 
	GPHEN  ..GPHEN+1: 		s:='GPHEN'+   Num2Str(longword(regidx-GPHEN),0);
	GPLEN	..GPLEN+1: 		s:='GPLEN'+   Num2Str(longword(regidx-GPLEN),0); 
	GPAREN..GPAREN+1: 		s:='GPAREN'+  Num2Str(longword(regidx-GPAREN),0);
	GPAFEN..GPAFEN+1: 		s:='GPAFEN'+  Num2Str(longword(regidx-GPAFEN),0);
	GPPUD: 					s:='GPPUD'+   Num2Str(longword(regidx-GPPUD),0);
	GPPUDCLK..GPPUDCLK+1: 	s:='GPPUDCLK'+Num2Str(longword(regidx-GPPUDCLK),0);
	STIMCS: 				s:='SYSTIMCS'; 
	STIMCLO: 				s:='SYSTIMCLO';
	STIMCHI: 				s:='SYSTIMCHI';
	STIMC0: 				s:='SYSTIMC0';
	STIMC1: 				s:='SYSTIMC1';
	STIMC2: 				s:='SYSTIMC2';
	STIMC3: 				s:='SYSTIMC3';
	SPI0_CS:				s:='CS';
	SPI0_FIFO:	 			s:='FIFO';
    SPI0_CLK:				s:='CLK';	
	SPI0_DLEN:				s:='DLEN';
	SPI0_LTOH:				s:='LTOH';
	SPI0_DC:				s:='DC';		
	I2C0_C:					s:='CONTROL';
	I2C0_S:					s:='STATUS';
	I2C0_DLEN:				s:='DLEN';
	I2C0_A:					s:='SLAVEADR';
	I2C0_FIFO:				s:='FIFO';
	I2C0_DIV:				s:='DIV';
	I2C0_DEL:				s:='DEL';
	I2C0_CLKT:				s:='CLKT';	
	I2C1_C:					s:='CONTROL';
	I2C1_S:					s:='STATUS';
	I2C1_DLEN:				s:='DLEN';
	I2C1_A:					s:='SLAVEADR';
	I2C1_FIFO:				s:='FIFO';
	I2C1_DIV:				s:='DIV';
	I2C1_DEL:				s:='DEL';
	I2C1_CLKT:				s:='CLKT';
	PWMCTL: 				s:='PWMCTL'; 
	PWMSTA: 				s:='PWMSTA';
	PWMDMAC: 				s:='PWMDMAC';
	PWM0RNG: 				s:='PWM0RNG';
	PWM0DAT: 				s:='PWM0DAT';
	PWM0FIF: 				s:='PWM0FIF';
	PWM1RNG: 				s:='PWM1RNG';
	PWM1DAT: 				s:='PWM1DAT';
	GMGP0CTL: 				s:='GMGP0CTL'; 
	GMGP0DIV: 				s:='GMGP0DIV';
	GMGP1CTL: 				s:='GMGP1CTL';
	GMGP1DIV: 				s:='GMGP1DIV';
	GMGP2CTL: 				s:='GMGP2CTL';
	GMGP2DIV: 				s:='GMGP2DIV';
	PWMCLKCTL: 				s:='PWMCLKCTL';
	PWMCLKDIV: 				s:='PWMCLKDIV';
	APMVALUE:				s:='APMVALUE';
	APMCTL:					s:='APMCTL';
	APMIRQCLRACK:			s:='APMIRQCLRACK';
	APMRAWIRQ:				s:='APMRAWIRQ';
	APMMaskedIRQ:			s:='APMMaskedIRQ';
	APMReload: 				s:='APMReload';
	APMPreDivider: 	  		s:='APMPreDivider';
	APMFreeRunCounter: 		s:='APMFreeRunCounter';
	Q4LP_CTL :				s:='CTL'; 
	Q4LP_CTIMPRE :			s:='CTIMPRE';
	Q4LP_LOCINTRTG :		s:='LOCINTRTG';
	Q4LP_GPUINTRTG :		s:='GPUINTRTG';
	Q4LP_CoreTimAccLS :		s:='CTIMLSB';
	Q4LP_CoreTimAccMS :		s:='CTIMMSB';	  
	Q4LP_LOCTIMCTL :		s:='LOCTIMCTL';
	Q4LP_LOCTIMCTL+1:		s:='LOCTIMFLG';
	Q4LP_Core0IntCtl..
	Q4LP_Core0IntCtl+3:		s:='C'+Num2Str(longword(regidx-Q4LP_Core0IntCtl),0)+'INTCTL';
	Q4LP_Core0IrqSrc..
	Q4LP_Core0IrqSrc+3:		s:='C'+Num2Str(longword(regidx-Q4LP_Core0IrqSrc),0)+'IRQSRC';
	Q4LP_Core0FIQSrc..
	Q4LP_Core0FIQSrc+3:		s:='C'+Num2Str(longword(regidx-Q4LP_Core0FIQSrc),0)+'FIQSRC';
	else 					s:='['+Hex(RPI_get_GPIO_BASE+(regidx*BCM270x_RegSizInByte),8)+']'; 
						  //s:='Reg['+Num2Str(longword(regidx),0)+']';
  end; // case
  s:=Get_FixedStringLen(s,wid1,false)+': '+Bin(regcontent,32)+' 0x'+Hex(regcontent,8);  
  get_reg_desc:=s;
end;

function  GPIO_get_desc(regidx,regcontent:longword) : string; 
var s:string; pin:integer;
begin
  s:='';  
  case regidx of
    GPFSEL..GPFSEL+5 : begin
                         for pin:= 9 downto 0 do
						   s:=s+'P'+LeadingZero(pin+(regidx-GPFSEL)*10)+':'+
						      gpiofkt((pin+(regidx-GPFSEL)*10),
							           GPIO_get_fkt_value((pin+(regidx-GPFSEL)*10)),false)+' ';					 
	                   end;
  end;
  GPIO_get_desc:=s;
end;
  
procedure DESC_HWPIN(pin:longint; var desc,dir,pegel:string);
//  WRONGPIN=-100; UKN=-99; V5=-98; V33=-97; GND=-96; DNC=-95; 
var gpio:longint; altval,av:byte;
begin
  gpio:=GPIO_MAP_HDR_PIN_2_GPIO_NUM(pin); dir:=''; pegel:='';
  case gpio of
	V5:			desc:='5V';
	V33:		desc:='3.3V';
	GND:		desc:='GND';
	IDSC:		desc:='ID SC';
	IDSD:		desc:='ID SD';
	DNC:		desc:='';
	UKN:		desc:='';
	WRONGPIN:	desc:='';
	else		begin
				  gpio:=abs(gpio);
				  if (pin>=1) and (pin<=max_pins_c) 
				    then desc:=RPIHDR_Desc[pin] else desc:='';
				  altval:=GPIO_get_fkt_value(gpio);
				  dir:=gpiofkt(gpio,altval,false);
				  case altval of
					$00: begin pegel:=Bool2LVL(GPIO_get_PIN(gpio)); end; // IN 
					$01: begin pegel:=Bool2LVL(GPIO_get_PIN(gpio)); end; // OUT
					else begin 
						   av:=GPIO_get_altval(altval); 
						   if desc='' then desc:=GPIO_get_AltDesc(gpio,av,desc); 
//						   sh:='A0'+Num2Str(av,1);
						 end;
				  end; // case
				  if desc='' then desc:='GPIO'+LeadingZero(gpio);
				end;
  end; //case
end;

function  CEPstring(cmd:string):string; var sh:string; begin call_external_prog(Log_NONE,cmd,sh); CEPstring:=sh; end;

function  HAT_vendor:string;	 begin HAT_vendor:= 	CEPstring('cat /proc/device-tree/hat/vendor'); 		end;
function  HAT_product:string; 	 begin HAT_product:=	CEPstring('cat /proc/device-tree/hat/product'); 	end;
function  HAT_product_id:string; begin HAT_product_id:=	CEPstring('cat /proc/device-tree/hat/product_id');	end;
function  HAT_product_ver:string;begin HAT_product_ver:=CEPstring('cat /proc/device-tree/hat/product_ver');	end;
function  HAT_uuid:string; 		 begin HAT_uuid:=		CEPstring('cat /proc/device-tree/hat/uuid');		end;
function  HAT_GetInfo(var HAT_Struct:HAT_Struct_t):boolean;
begin
  with HAT_Struct do
  begin
    uuid:=''; vendor:=''; product:=''; snr:=''; product_id:=0; product_ver:=0; 
    available:=DirectoryExists('/proc/device-tree/hat');
    if available then
    begin
      uuid:=		HAT_uuid;
      vendor:=		HAT_vendor;
      product:=		HAT_product;					// e.g. productname@snr
      snr:=			Select_Item(product,'@','',2);	// snr
      product:=		Select_Item(product,'@','',1);	// productname
      if not Str2Num(HAT_product_id, product_id)  then product_id:= 0;
      if not Str2Num(HAT_product_ver,product_ver) then product_ver:=0;
    end;
    HAT_GetInfo:=available;
  end; // with
end;
procedure HAT_ShowStruct(var HAT_Struct:HAT_Struct_t);
begin
  with HAT_Struct do
  begin
    writeln('uuid:     '+uuid);
    writeln('vendor:   '+vendor);
    writeln('product:  '+product);
    if snr<>'' then writeln('snr:      '+snr);
    writeln('prod_id:  0x'+Hex(product_id, 4));
    writeln('prod_ver: 0x'+Hex(product_ver,4));
  end;
end;
procedure HAT_Info_Test;
var HAT_info:HAT_Struct_t;
begin
  if HAT_GetInfo(HAT_info) then
  begin
    writeln('HAT Info:');
    HAT_ShowStruct(HAT_info);
  end else Log_Writeln(Log_ERROR,'HAT_Info_Test: no HAT installed');
end;

procedure HAT_EEprom_Map(tl:TStringList; hwname,uuid,vendor,product:string; prodid,prodver,gpio_drive,gpio_slew,gpio_hysteresis,back_power:word; useDefault,EnabIO:boolean);
//https://github.com/raspberrypi/hats/blob/master/eeprom-format.md
//https://github.com/raspberrypi/hats/blob/master/devicetree-guide.md
  procedure la(str:string); begin tl.add(str); end;
var _hwname,_uuid,_vendor,_product,dir,desc,pegel,sh,sh2,sh3:string; _gd,_gs,_gh,_bp,n,pin:word;
begin
  _hwname:=hwname;	if _hwname=''	then _hwname:=Get_Fname(ParamStr(0));
  _uuid:=uuid;		if _uuid=''		then _uuid:=   '00000000-0000-0000-0000-000000000000';
  _vendor:=vendor;	if _vendor=''	then _vendor:= 'ACME Technology Company';
  _product:=product;if _product=''	then _product:='Special Sensor Board';
  _gd:=gpio_drive;	if _gd>15		then _gd:=0;
  _gs:=gpio_slew;	if _gs>3		then _gs:=0;
  _gh:=gpio_hysteresis;	if _gh>3	then _gh:=0;
  _bp:=back_power;	if _bp>3		then _bp:=0;
	la('########################################################################');
	la('# EEPROM settings file for '+_hwname);
	la('# Vendor info');
	la('');
	la('product_uuid '+_uuid);
	la('product_id 0x'+ Hex(prodid, 4));
	la('product_ver 0x'+Hex(prodver,4));
	la('vendor "'+ copy(_vendor, 1,255)+'"');
	la('product "'+copy(_product,1,255)+'"');		
	la('');
	la('########################################################################');
	la('');
	la('# drive strength, 0=default, 1-8=2,4,6,8,10,12,14,16mA, 9-15=reserved');
	la('gpio_drive '+Num2Str(_gd,0));
	la('');
	la('# 0=default, 1=slew rate limiting, 2=no slew limiting, 3=reserved');
	la('gpio_slew '+Num2Str(_gs,0));
	la('');
	la('# 0=default, 1=hysteresis disabled, 2=hysteresis enabled, 3=reserved');
	la('gpio_hysteresis '+Num2Str(_gh,0));
	la('');
	la('# If board back-powers Pi via 5V GPIO header pins:');
	la('# 0 = board does not back-power');
	la('# 1 = board back-powers and can supply the Pi with a minimum of 1.3A');
	la('# 2 = board back-powers and can supply the Pi with a minimum of 2A');
	la('# 3 = reserved');
	la('# If back_power=2 then USB high current mode will be automatically enabled on the Pi');
	la('back_power '+Num2Str(_bp,0));
	la('');
	la('########################################################################');
	la('# GPIO pins, uncomment for GPIOs used on board');
	la('# Options for FUNCTION: INPUT, OUTPUT, ALT0-ALT5');
	la('# Options for PULL: DEFAULT, UP, DOWN, NONE');
	la('# NB GPIO0 and GPIO1 are reserved for ID EEPROM so cannot be set');
	la('');
	    la('#         GPIO  FUNCTION  PULL');
	    la('#         ----  --------  ----');
	for n:= 2 to 27 do
	begin
	  sh:='#'; if EnabIO then sh:=' ';
	  if useDefault then 
	  begin
	    sh:=sh+'setgpio  '+Get_FixedStringLen(Num2Str(n,0),2,true)+'    INPUT     DEFAULT';
	  end
	  else
	  begin
	    pin:=GPIO_MAP_GPIO_NUM_2_HDR_PIN(n);
	    DESC_HWPIN(pin,desc,dir,pegel);
	    desc:= Get_FixedStringLen(desc,mdl,false);
	    dir:=  Get_FixedStringLen(dir,   3,false);
	    pegel:=Get_FixedStringLen(pegel, 1,false);
	    if dir<>'' then
	    begin
	      sh2:=StringReplace(dir,'IN' ,'INPUT', [rfReplaceAll,rfIgnoreCase]);
	      sh2:=StringReplace(sh2,'OUT','OUTPUT',[rfReplaceAll,rfIgnoreCase]);
	      sh2:=StringReplace(sh2,'A',  'ALT',   [rfReplaceAll,rfIgnoreCase]); 
	      sh2:=Get_FixedStringLen(sh2,10,false);
	      sh3:='DEFAULT';
	      sh:= sh+'setgpio  '+Get_FixedStringLen(Num2Str(n,0),6,false)+sh2+sh3+
	      			'  # '+Num2Str(pin,2)+' '+pegel+' '+Trimme(desc,3);
	    end;  
	  end;
	  if Trimme(sh,3)<>'' then la(sh);
	end; // for
end;

procedure HAT_EEprom_Map_Test;
(*	./eepmake eeprom_mycfg.txt eepcfg.eep
	./eepflash.sh -w -t=24c256 -f=eepcfg.eep
	./eepflash.sh -r -t=24c256 -f=myeep.eep
	./eepdump myeep.eep stuff.eep
	more stuff.eep								*)
var tl:TStringList;
begin
  tl:=TStringList.create;
  HAT_EEprom_Map(tl,'test','','your company','your board',$0001,$0001,0,0,0,2,true,false);
  ShowStringList(tl); // StringList2TextFile('/tmp/eeprom_example.txt',tl);
  tl.free;
end;

procedure GPIO_ConnectorStringList(tl:TStringList);
{ shows the actual configuration of the Hardware Connector. 
V shows the actual logic level of the PIN 'L' is low and 'H' is high level
DIR: IN=Pin is configured as Input, OUT=Output. A0..A5 shows the ALT level. 
pls. see datasheet for definition

PIN Header (BCM2709 rev3;1GB;PI2B;a01041):
Signal    DIR V Pin  Pin V DIR Signal
3.3V             1 ||  2       5V       
I2C SDA1  A0     3 ||  4       5V       
I2C SCL1  A0     5 ||  6       GND      
GPIO04    IN  H  7 ||  8   A0  TxD0     
GND              9 || 10   A0  RxD0     
GPIO17    OUT H 11 || 12 H IN  GPIO18   
GPIO27    IN  L 13 || 14       GND      
GPIO22    IN  L 15 || 16 L IN  GPIO23   
3.3V            17 || 18 L IN  GPIO24   
SPI0 MOSI A0    19 || 20       GND      
SPI0 MISO A0    21 || 22 L IN  GPIO25   
SPI0 SCLK A0    23 || 24   A0  SPI0 CE0/
GND             25 || 26   A0  SPI0 CE1/
ID SD           27 || 28       ID SC    
GPIO05    IN  H 29 || 30       GND      
GPIO06    IN  H 31 || 32 L IN  GPIO12   
GPIO13    IN  L 33 || 34       GND      
GPIO19    IN  L 35 || 36 L IN  GPIO16   
GPIO26    IN  L 37 || 38 L IN  GPIO20   
GND             39 || 40 L IN  GPIO21
}
var pin,pinmax:longint; sh,dir,desc,pegel:string;
begin
  pinmax:=40;
  begin
    sh:='';
	tl.add('PIN Header ('+RPI_hw+' '+RPI_rev+'):');
	tl.add('Signal    DIR V Pin  Pin V DIR Signal');
    for pin:= 1 to pinmax do
	begin
	  DESC_HWPIN(pin,desc,dir,pegel);
	  desc:= Get_FixedStringLen(desc,mdl,false);
	  dir:=  Get_FixedStringLen(dir,   3,false);
	  pegel:=Get_FixedStringLen(pegel, 1,false);
	  if (pin mod 2)=0 then 
	  begin 
	    sh:=sh+' || '+Num2Str(pin,2)+' '+pegel+' '+dir+' '+desc; 
		tl.add(sh); 
		sh:=''; 
	  end 
	  else 
	  begin
	    sh:=desc+' '+dir+' '+pegel+' '+Num2Str(pin,2);
	  end;
	end;
  end;
end;

procedure GPIO_ShowConnector;
var tl:TStringList;
begin
  tl:=TStringList.create;
  GPIO_ConnectorStringList(tl);
  ShowStringList(tl);
  tl.free;
end;

function  show_reg(regidx,mode:longword):string;
var data:longword; s:string;
begin 
  data:=BCM_GETREG(regidx);
  s:=get_reg_desc(regidx,data);
  if mode=1 then s:=s+' '+GPIO_get_desc(regidx,data);
  show_reg:=s;
end;

procedure show_regs(desc:string; ofs,startidx,endidx,mode:longword; showhdr:boolean);
var idx:longword; skip:boolean;
begin
  skip:=((mode=2) and (RPI_hw='BCM2708'));
  writeln(Get_FixedStringLen(desc,wid1,false)+': ',Hex(RPI_get_GPIO_BASE+ofs,8));
  if showhdr then
  begin
    write  (Get_FixedStringLen('Adr(1F-00)',wid1,false)+': ');
    for idx:=31 downto 0 do 
      begin write(Hex((idx mod $10),1)); if (idx mod 4)=0 then write(' '); end; writeln;
  end;
  if (not skip) then
  begin
    for idx:=startidx to endidx do writeln(show_reg(idx,mode));
  end
  else writeln(RPI_hw,' processor has no registers here');
end;
procedure show_regs(desc:string; ofs,startidx,endidx,mode:longword);
begin show_regs(desc,ofs,startidx,endidx,mode,true); end;

procedure GPIO_show_regs;begin 	show_regs('GPIOBase',	GPIO_BASE_OFS, GPIO_BASE,GPIO_BASE_LAST,1); end;
procedure SPI0_show_regs;begin 	show_regs('SPI0Base', 	SPI0_BASE_OFS, SPI0_BASE,SPI0_BASE_LAST,0); end;
procedure I2C0_show_regs;begin 	show_regs('I2C0Base', 	I2C0_BASE_OFS, I2C0_BASE,I2C0_BASE_LAST,0); end;
procedure I2C1_show_regs;begin 	show_regs('I2C1Base', 	I2C1_BASE_OFS, I2C1_BASE,I2C1_BASE_LAST,0); end;
procedure I2C2_show_regs;begin 	show_regs('I2C2Base', 	I2C2_BASE_OFS, I2C2_BASE,I2C2_BASE_LAST,0); end;
procedure PWM_show_regs; begin 	show_regs('PWMBase', 	PWM_BASE_OFS,  PWM_BASE, PWM_BASE_LAST,0); end;
procedure STIM_show_regs;begin  show_regs('SYSTIMBase', STIM_BASE_OFS, STIM_BASE,STIM_BASE_LAST,0); end;
procedure TIM_show_regs; begin 	show_regs('TIMRBase', 	TIMR_BASE_OFS, TIMR_BASE,INTR_BASE_LAST,0); end;
procedure CLK_show_regs; begin 	show_regs('CLKBase', 	CLK_BASE_OFS,  GMGP0CTL, GMGP2DIV,0); writeln;
								show_regs('PWMCLK',  	CLK_BASE_OFS,  PWMCLKCTL,PWMCLKDIV,0); end;
procedure Q4_show_regs;  begin 	show_regs('Q4Base',  	BCM2709_LP_OFS,Q4LP_BASE,Q4LP_Last,2); end;

procedure Clock_show_regs;
begin
  show_regs('SPIClk',	SPI0_BASE_OFS,	SPI0_CLK,		SPI0_CLK,0,false); 		
  show_regs('I2C0Clk',	I2C0_BASE_OFS,	I2C0_DIV,		I2C0_DIV,0,false); 	
  show_regs('I2C1Clk',	I2C1_BASE_OFS,	I2C1_DIV,		I2C1_DIV,0,false); 	
  show_regs('I2C2Clk',	I2C2_BASE_OFS,	I2C2_DIV,		I2C2_DIV,0,false); 	
  show_regs('TIMR',		TIMR_BASE_OFS,	APMPreDivider,	APMPreDivider,0,false);
  show_regs('GMGPxCTL',	CLK_BASE_OFS,	GMGP0DIV,		GMGP0DIV,0,false); 
  show_regs('GMGPxCTL',	CLK_BASE_OFS,	GMGP1DIV,		GMGP1DIV,0,false); 	
  show_regs('GMGPxCTL',	CLK_BASE_OFS,	GMGP2DIV,		GMGP2DIV,0,false); 
  show_regs('PWMCLK',	CLK_BASE_OFS,	PWMCLKDIV,		PWMCLKDIV,0,false); 
  show_regs('Q4LP',		BCM2709_LP_OFS,	Q4LP_CTIMPRE,	Q4LP_CTIMPRE,2,false);  
end;

procedure GPIO_set_RESET(gpio:longword); 
var idx,mask:longword;
begin // RESET 3Bits @ according gpio location within register GPFSELn
  GPIO_get_mask_and_idx(GPFSEL,gpio,idx,mask);
  BCM_SETREG(idx,(not GPIO_get_ALTMask(gpio,INPUT)),true,true); 
end;
  
procedure GPIO_set_INPUT (gpio:longword); 
begin 
  Log_Writeln(LOG_DEBUG,'GPIO_set_INPUT: GPIO'+Num2Str(gpio,0)); 
  GPIO_set_RESET(gpio);
end;

procedure GPIO_set_OUTPUT(gpio:longword); 
var idx,mask:longword;
begin 
  Log_Writeln(LOG_DEBUG,'GPIO_set_OUTPUT: GPIO'+Num2Str(gpio,0)); 
  GPIO_get_mask_and_idx(GPFSEL,gpio,idx,mask);
  GPIO_set_RESET(gpio); // Always use GPIO_set_RESET(x) before using GPIO_set_OUTPUT(x), to reset Bits
  BCM_SETREG(idx,GPIO_get_ALTMask(gpio,OUTPUT),false,true); 
end; 

procedure GPIO_set_ALT(gpio:longword; altfunc:t_port_flags);
var idx,mask:longword;
begin
  Log_Writeln(LOG_DEBUG,'GPIO_set_ALT: GPIO'+Num2Str(gpio,0)+' AltFunc:'+Num2Str(ord(altfunc),0)); 
  GPIO_get_mask_and_idx(GPFSEL,gpio,idx,mask);
  GPIO_set_RESET(gpio); // Always use GPIO_set_RESET(x) before using GPIO_set_ALT(x,y), to reset Bits
  BCM_SETREG(idx,GPIO_get_ALTMask(gpio,altfunc),false,true);
end;

function  pwm_SW_Thread(ptr:pointer):ptrint;
begin
  with GPIO_ptr(ptr)^ do
  begin
    if (gpio>=0) and (ptr<>nil) then
	begin	
      writeln('pwm_SW_Thread: Start of ',description,' with PWMSW (GPIO',Num2Str(gpio,0),')');
//	  , period(us):',PWM.pwm_period_us,' dtycycl(us):',PWM.pwm_dutycycle_us,' restcycl(us):',PWM.pwm_restcycle_us);
      Thread_SetName(description);
	  while not ThreadCtrl.TermThread do
	  begin			
	    if PWM.pwm_sigalt then
		begin
		  if (PWM.pwm_dutycycle_us>0)	then 
		  begin 
//          writeln('PWM.pwm_dutycycle_us:',PWM.pwm_dutycycle_us);
		    mmap_arr^[regset]:=mask_1Bit;
		    if (PWM.pwm_restcycle_us>0)	then delay_us(PWM.pwm_dutycycle_us)
										else PWM.pwm_sigalt:=false;
		  end;
	      if (PWM.pwm_restcycle_us>0)	then 
		  begin 
//          writeln('PWM.pwm_restcycle_us:',PWM.pwm_restcycle_us);
		    mmap_arr^[regclr]:=mask_1Bit; 
		    if (PWM.pwm_dutycycle_us>0)	then delay_us(PWM.pwm_restcycle_us)
										else PWM.pwm_sigalt:=false;
		  end;
		end
		else delay_msec(PWM.pwm_period_ms);
	  end; 
	  mmap_arr^[regclr]:=mask_1Bit; 
	end
	else LOG_Writeln(LOG_ERROR,'pwm_SW_Thread: GPIO not supported or no valid datastruct pointer');
    writeln('pwm_SW_Thread: END of ',description);
	EndThread;
  end;
  pwm_SW_Thread:=0;
end;

function  pwm_GetDCSWVal(pwm_period_us,pwm_value,pwm_dutyrange:longword):longword;
var pwm_dutycycle_us:longword;
begin
  pwm_dutycycle_us:=0;
  if (pwm_dutyrange>0) then pwm_dutycycle_us:=round(pwm_period_us*pwm_value/(pwm_dutyrange-1));
  pwm_GetDCSWVal:=pwm_dutycycle_us;
end;

function  pwm_GetMODVal(value,maxval:longword):longword;
var res:longword;
begin
  res:=value;
  if (res>=maxval) then if (maxval>0) then res:=(res mod maxval) else res:=0;
  pwm_GetMODVal:=res;
end;

function  PWM_GetDRVal(percent:real; dutyrange:longword):longword; 
//dutyrange: 	pwm_dutyrange
//percent: 		0-1
//output:		0-(pwm_dutyrange-1)
var res:longword;
begin
  res:=0;
  if ((dutyrange>0) and (percent>0) and (percent<=1)) then res:=round(percent*(dutyrange-1));
  PWM_GetDRVal:=res;
end;

procedure pwm_WriteRange(gpio,range:longword);
begin
  case gpio of 
    GPIO_PWM0,GPIO_PWM0A0: BCM_SETREG(PWM0RNG,range); // HW PWM
	GPIO_PWM1,GPIO_PWM1A0: BCM_SETREG(PWM1RNG,range); // HW PWM
  end; // case
end;

procedure pwm_Write(gpio,value:longword);
begin
  case gpio of  
    GPIO_PWM0,GPIO_PWM0A0: BCM_SETREG(PWM0DAT,value); // HW PWM
	GPIO_PWM1,GPIO_PWM1A0: BCM_SETREG(PWM1DAT,value); // HW PWM
  end; // case
end;

procedure pwm_Write(var GPIO_struct:GPIO_struct_t; value:longword); // value: 0-(pwm_dutyrange-1)
begin
  with GPIO_struct do
  begin
    PWM.pwm_value:=pwm_GetMODVal(value,PWM.pwm_dutyrange); //value: 0-(pwm_dutyrange-1)
	PWM.pwm_dutycycle_us:=pwm_GetDCSWVal(PWM.pwm_period_us,PWM.pwm_value,PWM.pwm_dutyrange);	
	PWM.pwm_restcycle_us:=0; 
	if PWM.pwm_period_us>PWM.pwm_dutycycle_us 
	  then PWM.pwm_restcycle_us:=PWM.pwm_period_us-PWM.pwm_dutycycle_us
	  else PWM.pwm_dutycycle_us:=PWM.pwm_period_us;
	PWM.pwm_period_ms:=trunc(PWM.pwm_period_us/1000); 
	if PWM.pwm_period_ms<=0 then PWM.pwm_period_ms:=1;
	PWM.pwm_sigalt:=true;
(*  writeln('pwm_Write:'+
		' GPIO'+Num2Str(gpio,0)+
		' value:'+Num2Str(PWM.pwm_value,0)+
		' dtyrange:'+Num2Str(PWM.pwm_dutyrange,0)+
		' dtyperiod(us):'+Num2Str(PWM.pwm_period_us,0)+
		' dtycycl(us):'+Num2Str(PWM.pwm_dutycycle_us,0)+
		' dtyrest(us):'+Num2Str(PWM.pwm_restcycle_us,0)
		);*)
    if (PWMHW IN portflags) then
	begin
      case gpio of	  
         GPIO_PWM0,GPIO_PWM0A0: BCM_SETREG(PWM0DAT,PWM.pwm_value,false,false); // HW PWM
	     GPIO_PWM1,GPIO_PWM1A0: BCM_SETREG(PWM1DAT,PWM.pwm_value,false,false); // HW PWM
      end; // case
	end;
  end; // with  
end; 

function  CLK_GetFreq(clksource:longword):real; // Hz
(*how to determine PLL freq:
http://blog.riyas.org/2014/01/raspberry-pi-as-simple-low-cost-rf-signal-generator-sweeper.html
http://raspberrypi.stackexchange.com/questions/1153/what-are-the-different-clock-sources-for-the-general-purpose-clocks
The clock frequencies were determined by experiment. 
The oscillator (19.2 MHz) and PLLD (500 MHz) are unlikely to change.
Clock sources
0     0 Hz     Ground
1     19.2 MHz oscillator
2     0 Hz     testdebug0
3     0 Hz     testdebug1
4     0 Hz     PLLA
5     1000 MHz PLLC (changes with overclock settings)
6     500 MHz  PLLD
7     216 MHz  HDMI auxiliary
8-15  0 Hz     Ground
The integer divider may be 2-4095. The fractional divider may be 0-4095.
There is (probably) no 25MHz cap for using non-zero mash values.
There are three general purpose clocks.
The clocks are named GPCLK0, GPCLK1, and GPCLK2.
Don't use GPCLK1 (it's probably used for the Ethernet clock). *)
var f:real;
begin
  case clksource of 
	 1 : f:= osc_freq_c;	// OSC  (19.2Mhz)	
	 5 : f:= pllc_freq_c;	// PLLC (1000Mhz changes with overclock settings) 
	 6 : f:= plld_freq_c;	// PLLD (500Mhz)
	 7 : f:= HDMI_freq_c;	// HDMI (216Mhz auxiliary)
	else f:= 0.0;
  end; // case
//writeln('CLK_GetFreq corefreq:',(pllc_freq):0:5);
  CLK_GetFreq:=f; 
end;

function  CLK_GetMinFreq:real; begin CLK_GetMinFreq:=CLK_GetFreq(1)/(4095.4095); end;
function  CLK_GetMaxFreq:real; begin CLK_GetMaxFreq:=CLK_GetFreq(6)/(1.0); end;
function  CLK_ValidFreq(freq_Hz:real):boolean;
begin CLK_ValidFreq:=((freq_Hz>=CLK_GetMinFreq) and (freq_Hz<=CLK_GetMaxFreq)); end;

function CLK_CheckFreq(freq_Hz:real; clksrc:longword; var divi,divf,mash:longword):boolean;
// !!todo!!, calc freq for mash>0
var _ok:boolean; da:real; mindivi:byte;
begin
  _ok:=CLK_ValidFreq(freq_Hz);  
  if _ok and (freq_Hz>0) then
  begin
    case mash of
	    3: begin mindivi:=5; end;
	    2: begin mindivi:=3; end;
	    1: begin mindivi:=2; end;
	  else begin mindivi:=1; mash:=0; end;
	end;
	if mash<>0 then LOG_Writeln(LOG_ERROR,'CLK_CheckFreq: currently not implemented mash<>0');
    da:=CLK_GetFreq(clksrc)/freq_Hz; 
	divi:=trunc(da); divf:=round(4096.0*(da-divi));
    _ok:=(not ((divi>4095.0) or (divi<mindivi) or (divf>4095.0)));
//	writeln('CLK_CheckFreq: freq(Hz):',freq_hz:0:2,' clksrc:',clksrc:0,' PLLfreq(Hz):',CLK_GetFreq(clksrc):0:1,' da:',da:0:2,' divi:',divi,' divf:',divf,' mash:',mash,' ok:',_ok);
  end;
  CLK_CheckFreq:=_ok;
end; 

function  CLK_GetSource(freq_Hz:real; var clksrc,divi,divf,mash:longword):boolean;
var _ok:boolean; 
begin
  _ok:=false; clksrc:=1; divi:=4095; divf:=4095;
  if CLK_ValidFreq(freq_Hz) then
  begin // find the best clk source // 6/1/7/5
    if (not _ok) then begin clksrc:=6; _ok:=CLK_CheckFreq(freq_Hz,clksrc,divi,divf,mash); end;
    if (not _ok) then begin clksrc:=1; _ok:=CLK_CheckFreq(freq_Hz,clksrc,divi,divf,mash); end;
	if (not _ok) then begin clksrc:=7; _ok:=CLK_CheckFreq(freq_Hz,clksrc,divi,divf,mash); end;
    if (not _ok) then begin clksrc:=5; _ok:=CLK_CheckFreq(freq_Hz,clksrc,divi,divf,mash); end;
  end;
  CLK_GetSource:=_ok;
end;  

function  CLK_GetRegIdx(mode:byte; var regctlidx,regdividx:longword):boolean;
var _ok:boolean;
begin
  _ok:=false;
  case mode of
    0 : begin _ok:=true; regctlidx:=GMGP0CTL;  regdividx:=GMGP0DIV;  end;
	1 : begin _ok:=true; regctlidx:=GMGP1CTL;  regdividx:=GMGP1DIV;  end;
	2 : begin _ok:=true; regctlidx:=GMGP2CTL;  regdividx:=GMGP2DIV;  end;
    3 : begin _ok:=true; regctlidx:=PWMCLKCTL; regdividx:=PWMCLKDIV; end;
  end; // case
  CLK_GetRegIdx:=_ok;
end;

function  CLK_GetDivisor(regcont:longword):real;
begin
  CLK_GetDivisor:=((regcont and $fff000) shr 12)+((regcont and $fff) shl 10); 
end;

function  CLK_GetMashValue(mode:byte):byte; 
var regctl,regdiv:longword;
begin
  CLK_GetRegIdx(mode,regctl,regdiv);
  CLK_GetMashValue:=byte((BCM_GETREG(regctl) and $600) shr 9); 
end;

function  CLK_GetClkFreq(mode:byte; PLL_FREQ,FREQ_req:real; 
                         var FREQ_O_min,FREQ_O_avg,FREQ_O_max:real;
						 var MASH:byte; var DIVIF:longword):boolean;
var DIVImin,DIVI,DIVF:longword; divisor:real; ok:boolean;
begin
  ok:=false;
  MASH:=CLK_GetMashValue(mode) and $3; // MashValue 0..3
  DIVImin:=MASH+1; if MASH=3 then DIVImin:=5;
  if abs(FREQ_req)<>0 then
  begin
    divisor:=PLL_FREQ/FREQ_req; 
	DIVI:=trunc(divisor) and $fff; DIVF:=round(frac(divisor)/1024) and $fff;	// 2x12Bit values
	if DIVI<DIVImin then DIVI:=DIVImin;
	DIVIF:=((DIVI shl 12) or DIVF);
//	writeln('divisor: ',divisor:0:5,' DIVImin:',DIVImin,' DIVI:',DIVI,' DIVF:',DIVF,' MASH:',MASH,' DIVIF:',DIVIF);
    case MASH of
      0 : begin 
		    FREQ_O_max:=PLL_FREQ/DIVI;
		    FREQ_O_avg:=PLL_FREQ/DIVI;
		    FREQ_O_min:=PLL_FREQ/DIVI;
		  end;
	  1 : begin 
		    FREQ_O_max:=PLL_FREQ/DIVI;
		    FREQ_O_avg:=PLL_FREQ/(DIVI+(DIVF shl 10));
		    FREQ_O_min:=PLL_FREQ/(DIVI+1);
		  end;
	  2 : begin 
		    FREQ_O_max:=PLL_FREQ/(DIVI-1);
		    FREQ_O_avg:=PLL_FREQ/(DIVI+(DIVF shl 10));
		    FREQ_O_min:=PLL_FREQ/(DIVI+2);
		  end;
	  3 : begin 
		    FREQ_O_max:=PLL_FREQ/(DIVI-3);
		    FREQ_O_avg:=PLL_FREQ/(DIVI+(DIVF shl 10));
		    FREQ_O_min:=PLL_FREQ/(DIVI+4);
		  end;
    end; // case
	ok:=(FREQ_O_max<=Clk_GetFreq(5));
  end;
  CLK_GetClkFreq:=ok;
end;

function  CLK_Write(regctlidx,regdividx:longword; DIVI,DIVF,ctlmask:longword):boolean;
const wt_us=1; maxtry=1000; CLK_CTL_ENAB=$00000010;
var n:longword; ok:boolean;
begin
  n:=0;
//writeln('CLK_Write: '+Num2Str(DIVI,0));  
  BCM_SETREG(regctlidx,BCM_PWD or $01,false,false); // stop clock										
  while ((BCM_GETREG(regctlidx) and $80)<>0) and (n<=maxtry) do	// Wait for clock to be !BUSY
    begin inc(n); delay_us(wt_us); end;
  ok:=(n<maxtry);
  if not ok then 
  begin
	LOG_Writeln(LOG_WARNING,'CLK_Write: take to long time to get ready '+Num2Str(n,0));
	delay_msec(1);
  end
  else if (n>100) then LOG_Writeln(LOG_WARNING,'CLK_Write: n:'+Num2Str(n,0));
  BCM_SETREG(regdividx,(BCM_PWD or ((DIVI and $0fff) shl 12) or (DIVF and $0fff)),false,false); // set clock divider						
  if ctlmask<>0 then
  begin
    delay_us(10);
    BCM_SETREG(regctlidx,(BCM_PWD or (ctlmask and (not CLK_CTL_ENAB))),false,false); 
  end;
  delay_us(10);  
  BCM_SETREG(regctlidx,(BCM_PWD or ctlmask or CLK_CTL_ENAB),false,false); // start clock
  CLK_Write:=ok;
end;

function  PWM_ClkWrite(regctlidx,regdividx:longword; DIVI:longword):boolean;
const wt_us=1; maxtry=1000; 
var pwm_control:longword; ok:boolean;
begin
//writeln('PWM_ClkWrite: '+Num2Str(DIVI,0));
  pwm_control:=BCM_GETREG(PWMCTL);				// save register content 
//writeln('PWMCTL: 0x',Hex(pwm_control,8));
  BCM_SETREG(PWMCTL,0,false,false);  			// stop PWM 
  ok:=CLK_Write(regctlidx,regdividx,DIVI,0,$01);// $01: clock src from osci
  BCM_SETREG(PWMCTL,pwm_control,false,false); 	// restore PWM_CONTROL	
  PWM_ClkWrite:=ok;
end;

function  PWM_GetMinFreq(dutycycle:longword):longword; 
var lw:longword;
begin
  if dutycycle<>0 then lw:=round(CLK_GetFreq(1)/(PWM_DIVImax*dutycycle)) else lw:=0;
  PWM_GetMinFreq:=lw;
end;

function  PWM_GetMaxFreq(dutycycle:longword):longword;
var lw:longword;
begin
  if dutycycle<>0 then lw:=round(CLK_GetFreq(1)/(PWM_DIVImin*dutycycle)) else lw:=0;
  PWM_GetMaxFreq:=lw;
end;

function  PWM_GetMaxDtyC(freq:real):longword;
var lw:longword;
begin
  if freq<>0 then lw:=round(CLK_GetFreq(1)/(PWM_DIVImin*freq)) else lw:=0;
  PWM_GetMaxDtyC:=lw;
end;

function  PWM_GetDtyRangeVal(var GPIO_struct:GPIO_struct_t; DutyCycle:real):longword;
// DutyCycle: 0..1
var dcr:real; drlw:longword;
begin
  dcr:=DutyCycle; if dcr<0 then dcr:=0.0; if dcr>1.0 then dcr:=1.0; 
  with GPIO_struct.PWM do
  begin
    if pwm_dutyrange>1 then drlw:=round(dcr*(pwm_dutyrange-1)) else drlw:=0;
  end; // with
  PWM_GetDtyRangeVal:=drlw;
end;

procedure pwm_SetClock(var GPIO_struct:GPIO_struct_t); 
// same clock for PWM0 and PWM1. Needs only to be set once
var DIVI:longword;
begin
  with GPIO_struct do
  begin
    if (PWMHW IN portflags) then
	begin
      DIVI:=PWM_DIVImin;  // default
      if ((PWM.pwm_freq_Hz*PWM.pwm_dutyrange)<>0) 
	    then DIVI:=round(CLK_GetFreq(1)/(PWM.pwm_freq_Hz*PWM.pwm_dutyrange)); 
//    writeln('pwm_SetClock0: ',CLK_GetFreq(1):0:5,' freq(Hz):',PWM.pwm_freq_Hz:0:5,' dty:',PWM.pwm_dutyrange:0,' DIVI:',DIVI);
	  if (DIVI<PWM_DIVImin) or (DIVI>PWM_DIVImax) then 
	  begin
	    LOG_Writeln(LOG_ERROR,'pwm_SetClock DIVI:'+Num2Str(DIVI,0)+' desired PWM-Freq. will not be reached. use smaller duty cycle');
	    if (DIVI<PWM_DIVImin) then DIVI:=PWM_DIVImin else DIVI:=PWM_DIVImax;
	  end;
//    writeln('pwm_SetClock1: ',DIVI);
	  PWM_ClkWrite(PWMCLKCTL,PWMCLKDIV,DIVI);	
	end;
  end; // with
end;
		
function  PortFlagsString(flgs:s_port_flags):string;
var j:t_port_flags; sh:string;
begin
  sh:=''; 
  for j IN flgs do 
    sh:=sh+GetEnumName(TypeInfo(t_port_flags),ord(t_port_flags(j)))+' ';
  PortFlagsString:=sh;
end;
		
procedure GPIO_ShowStruct(var GPIO_struct:GPIO_struct_t);
begin
  with GPIO_struct do
  begin 
    writeln('GPIO_ShowStruct: ',description,' Portflags:',PortFlagsString(portflags),' initok:',initok,' Simulation:',simulation);
	writeln('HWPin:',HWPin,' GPIO',gpio:0,' nr:',nr:0,' State:',ein);
	writeln('idxofs_1Bit:0x',Hex(idxofs_1Bit,2),' mask_1Bit:0x',Hex(mask_1Bit,8),' idxofs_3Bit:0x',Hex(idxofs_3Bit,2),' mask_3Bit:0x',Hex(mask_3Bit,8));
	writeln('pwm_mode:',PWM.pwm_mode,' pwm_freq:',PWM.pwm_freq_hz:0:2,' pwm_dutyrange:',PWM.pwm_dutyrange,' value:',PWM.pwm_value,
	       ' pwm_dutycycle_us:',PWM.pwm_dutycycle_us,' pwm_period_us:',PWM.pwm_period_us);
  end;
end;

procedure  Thread_SetName(name:string);
const PR_SET_NAME=$0f;
var   thread_name:string[16];
begin
  thread_name:=copy(name+#$00,1,16); 
  if thread_name<>'' then
  begin
    {$IFDEF LINUX}
      if FpPrCtl(PR_SET_NAME,@thread_name[1],nil,nil,nil)<>0 then
        LOG_Writeln(LOG_ERROR,'Thread_SetName: can not set name '+name);  
    {$ENDIF}
  end;
end;

function  Thread_Start(var ThreadCtrl:Thread_Ctrl_t; funcadr:TThreadFunc; 
					   paraadr:pointer; delaymsec:longword; prio:longint):boolean;
begin
  with ThreadCtrl do
  begin
    TermThread:=false; ThreadRetCode:=0; ThreadProgress:=0;
	ThreadID:=BeginThread(funcadr,paraadr);
	ThreadRunning:=(ThreadID<>TThreadID(0));
	if ThreadRunning and (delaymsec>0) then delay_msec(delaymsec); // let thread time to start
	if ThreadRunning and (prio<>0) then ThreadSetPriority(ThreadID,prio);
	Thread_Start:=ThreadRunning;
  end;
end;

function  Thread_End(var ThreadCtrl:Thread_Ctrl_t; waitmsec:longword):boolean;
begin
  with ThreadCtrl do
  begin
    TermThread:=true;
    if ThreadRunning then ThreadRunning:=(WaitForThreadTerminate(ThreadID,waitmsec)=0);
	Thread_End:=ThreadRunning;
  end;
end;

procedure PWM_End(var GPIO_struct:GPIO_struct_t);
var regsav:longword;
begin 
  with GPIO_struct do
  begin
    ThreadCtrl.TermThread:=true; 
    if (PWMHW IN portflags) then
	begin // HW PWM	
      if GPIO_HWPWM_capable(gpio) then
	  begin 
		regsav:=BCM_GETREG(PWMCTL);			// save ctl register
//      writeln('PWM_End: PWMCTL 0x',hex(regsav,8));			
		if GPIO_HWPWM_capable(gpio,0) // // maskout Bits for channel1/2
		  then regsav:=(regsav and $0000ff00) and (not PWM0_ENABLE)
		  else regsav:=(regsav and $000000ff) and (not PWM1_ENABLE); 	
//      writeln('PWM_End: PWMCTL 0x',hex(regsav,8));
		BCM_SETREG(PWMCTL,regsav,false,false); // Disable channel PWM
	  end;
    end
	else Thread_End(ThreadCtrl,100);
  end;  // with
end;

procedure pwm_SetStruct(var GPIO_struct:GPIO_struct_t; mode:byte; freq_Hz:real; dutyrange,startval:longword);
begin
  with GPIO_struct do
  begin
  	PWM.pwm_mode:=mode; PWM.pwm_freq_hz:=freq_Hz; 
	with ThreadCtrl do begin TermThread:=true; ThreadRunning:=false; ThreadID:=TThreadID(0); end;
	if (PWM.pwm_freq_hz<>0) then PWM.pwm_period_us:=round(1000000/PWM.pwm_freq_hz) else PWM.pwm_period_us:=0; 
	PWM.pwm_dutyrange:=dutyrange; pwm_Write(GPIO_struct,startval);
(*	PWM.pwm_value:=startval; 
	PWM.pwm_dutycycle_us:=pwm_GetDCSWVal(PWM.pwm_period_us,PWM.pwm_value,PWM.pwm_dutyrange);
    if PWM.pwm_period_us>PWM.pwm_dutycycle_us 
	  then PWM.pwm_restcycle_us:=PWM.pwm_period_us-PWM.pwm_dutycycle_us
	  else PWM.pwm_dutycycle_us:=PWM.pwm_period_us;
	PWM.pwm_period_ms:=trunc(PWM.pwm_period_us/1000); 
	if PWM.pwm_period_ms<=0 then PWM.pwm_period_ms:=1;*)
  end;
end;

procedure pwm_SetStruct(var GPIO_struct:GPIO_struct_t); 
//HW-PWM: Mark Space mode // set pwm hw clock div to 32 (19.2Mhz/32 = 600kHz) // Default range of 1024
//SW-PWM: Mark Space mode // set pwm sw clock to 50Hz // DutyCycle range of 1000 (0-999)
const dcycl=1000;
begin 
  with GPIO_struct do
  begin
    if (PWMHW IN portflags)   
	  then pwm_SetStruct(GPIO_struct,PWM_MS_MODE,PWM_GetMaxFreq(dcycl),dcycl,0)  // set default values for HW PWM0/1
	  else pwm_SetStruct(GPIO_struct,PWM_MS_MODE, 				   50, dcycl,0); // SW PWM 50Hz; DutyCycle 0-999
  end;
end;

function  pwm_Setup(var GPIO_struct:GPIO_struct_t):boolean;
var regsav:longword;
begin
  with GPIO_struct do
  begin
    if initok and (OUTPUT IN portflags) then 
	begin
	  initok:=false; 
	  if (PWMHW IN portflags) then
	  begin // HW PWM	  
	    case gpio of
	      GPIO_PWM0,GPIO_PWM0A0,GPIO_PWM1A0,
		  GPIO_PWM1 : begin // PWM0:Pin12:GPIO18 PWM1:Pin35:GPIO19 
					    initok:=true; 
//				    	writeln('pwm_Setup (HW):'); GPIO_ShowStruct(GPIO_struct);
					    GPIO_set_PINMODE(gpio,PWMHW);					  
						regsav:=BCM_GETREG(PWMCTL);			// save ctl register
						BCM_SETREG(PWMCTL,0,false,false);  	// stop PWM 
					    pwm_SetClock      (GPIO_struct); 	// set clock external before pwm_Setup
//                      writeln('pwm_Setup: PWMCTL 0x',hex(regsav,8));			
//  					writeln('pwm_Setup: pwm_dutyrange ',PWM.pwm_dutyrange);
						if GPIO_HWPWM_capable(gpio,0) then
						begin
						  BCM_SETREG(PWM0RNG,PWM.pwm_dutyrange,false,false); delay_us(10); // set max value for duty cycle	
						  regsav:=regsav and $0000ff00;	// maskout Bits for channel1
						  regsav:=regsav or PWM0_ENABLE; 						  
						  if ((PWM.pwm_mode and PWM_MS_MODE)<>0)    then regsav:=regsav or PWM0_MS_MODE;
						  if ((PWM.pwm_mode and PWM_USEFIFO)<>0) 	then regsav:=regsav or PWM0_USEFIFO;	
						  if ((PWM.pwm_mode and PWM_POLARITY)<>0)	then regsav:=regsav or PWM0_REVPOLAR;	
						  if ((PWM.pwm_mode and PWM_RPTL)<>0) 	    then regsav:=regsav or PWM0_REPEATFF;			
						  if ((PWM.pwm_mode and PWM_SERIALIZER)<>0) then regsav:=regsav or PWM0_SERIAL;		  
						end
						else
						begin
						  BCM_SETREG(PWM1RNG,PWM.pwm_dutyrange,false,false); delay_us(10);
						  regsav:=regsav and $000000ff; // maskout Bits for channel2
						  regsav:=regsav or PWM1_ENABLE; 
						  if ((PWM.pwm_mode and PWM_MS_MODE)<>0)    then regsav:=regsav or PWM1_MS_MODE;
						  if ((PWM.pwm_mode and PWM_USEFIFO)<>0)    then regsav:=regsav or PWM1_USEFIFO;	
						  if ((PWM.pwm_mode and PWM_POLARITY)<>0)	then regsav:=regsav or PWM1_REVPOLAR;	
						  if ((PWM.pwm_mode and PWM_RPTL)<>0) 	    then regsav:=regsav or PWM1_REPEATFF;			
						  if ((PWM.pwm_mode and PWM_SERIALIZER)<>0) then regsav:=regsav or PWM1_SERIAL;		
						end;
//                      writeln('pwm_Setup: pwm_value ',PWM.pwm_value);
						pwm_Write  (GPIO_struct,PWM.pwm_value);	// set start value
//                      writeln('pwm_Setup: PWMCTL 0x',hex(regsav,8));			// 					
					    BCM_SETREG(PWMCTL,regsav,false,false);		// Enable channel PWM
					  end;
		  else Log_Writeln(LOG_ERROR,'pwm_Setup: GPIO'+Num2Str(gpio,0)+' not supported for HW PWM'); 
		end;
	  end
	  else
	  begin // SW PWM
        case gpio of
		  -999..-1: Log_Writeln(LOG_ERROR,'pwm_Setup: GPIO'+Num2Str(gpio,0)+' not supported for PWM'); 
		  else		begin 
		              if (gpio>=0) and (PWMSW IN portflags) then
					  begin
					    initok:=true;
						GPIO_set_PINMODE(gpio,OUTPUT); portflags:=portflags+[OUTPUT];
//                      writeln('pwm_Setup (SW):'); GPIO_ShowStruct(GPIO_struct);
// Start SW PWM Thread
					    Thread_Start(ThreadCtrl,@pwm_SW_Thread,addr(GPIO_struct),100,-1);
(*					    with ThreadCtrl do
						begin
						  TermThread:=false; ThreadRunning:=true; // Start SW PWM Thread
					      ThreadID:=BeginThread(@pwm_SW_Thread,addr(GPIO_struct)); 
						end;
						delay_msec(100); // let SW-Threads start
*)
					  end
					  else Log_Writeln(LOG_ERROR,'pwm_Setup: wrong neg. GPIO Error Code: '+Num2Str(gpio,0)+' '+PortFlagsString(portflags));
					end;
	    end; // case
	  end;
    end
	else Log_Writeln(LOG_ERROR,'pwm_Setup: GPIO_struct is not initialized'); 
  end;
  pwm_Setup:=GPIO_struct.initok;
end;

function  TIM_Setup(timr_freq_Hz:real):real;
var _ok:boolean; _divi:longword; _f:real;
begin
  _ok:=false; _f:=0;
  if timr_freq_Hz>0 then
  begin
    _divi:=round(CLK_GetFreq(5)/timr_freq_Hz); //250MHz CoreFreq/timr_freq_Hz
	if (_divi>0) and (_divi<=$400) then 
	begin
	  _f:=CLK_GetFreq(5)/_divi;
	  dec(_divi); _ok:=true; // the timer divide (10Bit) is base clock / (divide+1)
	  BCM_SETREG(APMPreDivider,_divi);
	  BCM_SETREG(APMCTL, 		$280);	// Free running counter Enabled; Timer enable
	end;
  end;
  if not _ok then 
    LOG_Writeln(LOG_ERROR,'TIM_Setup: can not set freq: '+Num2Str(timr_freq_Hz,0,0));
  TIM_Setup:=_f;
end;

procedure TIM_Test; // 1MHz
begin
  TIM_Setup(1000000); 
end;

function  OSC_Setup(_gpio:longint; pwm_freq_Hz,pwm_dty:real):boolean;
var _ok:boolean; flgh:s_port_flags; gpio_struct:GPIO_struct_t;  
    _f,_dty:real; _dtyrange,_dtyw:longword;
begin
  _ok:=false;
  if GPIO_FCTOK(_gpio,[PWMHW]) then flgh:=[PWMHW] else flgh:=[PWMSW];
  _f:=pwm_freq_Hz; _dty:=pwm_dty; 
  if ((PWMSW IN flgh) and (_f>200)) then _f:=200;
  _dtyrange:=PWM_GetMaxDtyC(_f); _dtyw:=round(_dtyrange*_dty);
  writeln('OSC_Setup: ',(PWMHW IN flgh),' f:',_f:0:1,'Hz range:',_dtyrange:0,' dty:',_dtyw:0);
  GPIO_SetStruct (gpio_struct,1,_gpio,'OSC',[OUTPUT]+flgh);
  pwm_SetStruct  (gpio_struct,PWM_MS_MODE,_f,_dtyrange,_dtyw); 
  pwm_SetClock   (gpio_struct);
  _ok:=GPIO_Setup(gpio_struct);
  OSC_Setup:=_ok;
end;

procedure FRQ_End(var GPIO_struct:GPIO_struct_t);
var regsav:longword;
begin 
  with GPIO_struct do
  begin
    ThreadCtrl.TermThread:=true; 
    if (FRQHW IN portflags) then
	begin 	
      regsav:=(BCM_GETREG(FRQ_CTLIdx) and $70f); // mask out Enable and unused Bits
	  BCM_SETREG(FRQ_CTLIdx,(BCM_PWD or regsav),false,false); 	// Disable clock 
    end;
  end;  // with
end;

function  FRQ_GetClkRegIdx(gpio:longint; var mode:byte):boolean;
var _ok:boolean;
begin
  _ok:=true; mode:=$ff;
  case gpio of // set clocksource
    GPIO_FRQ04_CLK0,GPIO_FRQ20_CLK0,
	GPIO_FRQ32_CLK0,GPIO_FRQ34_CLK0: mode:=0;
	GPIO_FRQ05_CLK1,GPIO_FRQ21_CLK1,
	GPIO_FRQ42_CLK1,GPIO_FRQ44_CLK1: mode:=1;
    GPIO_FRQ06_CLK2,GPIO_FRQ43_CLK2: mode:=2;
    else _ok:=false; 
  end; // case	
  if not _ok then LOG_Writeln(LOG_ERROR,'FRQ_GetClkRegIdx: no clock GPIO'+Num2Str(gpio,0));
  FRQ_GetClkRegIdx:=_ok;
end;

function  FRQ_Setup(var GPIO_struct:GPIO_struct_t; freq_Hz:real):boolean;
var _mode:byte; _clksrc,_msk,_divi,_divf,_mash:longword; 
begin
  with GPIO_struct do
  begin
    initok:=CLK_ValidFreq(freq_Hz);
    if initok and (FRQHW IN portflags) then 
	begin
	  FRQ_freq_Hz:=freq_Hz; _mash:=0;
	  initok:=CLK_GetSource(FRQ_freq_Hz,_clksrc,_divi,_divf,_mash); 
	  if initok then
	  begin	  	  
//writeln('FRQ_Setup: freq(Hz):',FRQ_freq_Hz:0:2,' divi:0x',Hex(_divi,3),' divf:0x',Hex(_divf,3),' clksrc:',_clksrc:0,' mash:',_mash:0);
	    initok:=FRQ_GetClkRegIdx(gpio,_mode); 	
        if initok then initok:=CLK_GetRegIdx(_mode,FRQ_CTLIdx,FRQ_DIVIdx);  		
		if initok then
        begin	
		  initok:=false; 
          if (ALT0 IN portflags) then begin GPIO_set_ALT(gpio,ALT0); initok:=true; end;
		  if (ALT1 IN portflags) then begin GPIO_set_ALT(gpio,ALT1); initok:=true; end;
		  if (ALT2 IN portflags) then begin GPIO_set_ALT(gpio,ALT2); initok:=true; end; 
		  if (ALT3 IN portflags) then begin GPIO_set_ALT(gpio,ALT3); initok:=true; end; 
		  if (ALT4 IN portflags) then begin GPIO_set_ALT(gpio,ALT4); initok:=true; end; 
		  if (ALT5 IN portflags) then begin GPIO_set_ALT(gpio,ALT5); initok:=true; end; 
          if not initok then LOG_Writeln(LOG_ERROR,'FRQ_Setup: ALTx');		  
          _msk:=((_mash and $3) shl 9) or (_clksrc and $0f); // set mash and clk-src	  
		  if initok then initok:=CLK_Write(FRQ_CTLIdx,FRQ_DIVIdx,_divi,_divf,_msk);
//        writeln('Mash:0x',Hex(CLK_GetMashValue(_mode),2),' mode:',_mode,' clksrc:',_clksrc);
		  if not initok then LOG_Writeln(LOG_ERROR,'FRQ_Setup: CLK_Write');		  
        end else LOG_Writeln(LOG_ERROR,'FRQ_Setup: CLK_GetRegIdx');					
	  end else LOG_Writeln(LOG_ERROR,'FRQ_Setup: CLK_GetSource');	
	end else LOG_Writeln(LOG_ERROR,'FRQ_Setup for freq(Hz): '+Num2Str(FRQ_freq_Hz,0,2)+' not possible');
    FRQ_Setup:=initok;
  end; // with
end;

procedure FRQ_WaveTest; // !!!! not completed !!!!!
const gpio=4; maxcnt=50; scal=100; freqHz=100000;
type t_MM = array of longword; 
var  GPIO_struct:GPIO_struct_t; range:t_MM; n:longword;
  procedure FillWaveTable;
  var step:real; i:longword;
  begin
    step:=(2*pi)/maxcnt;
    for i:= 0 to (maxcnt-1) do range[i]:=round(scal*(sin(i*step)+1));
  end;
begin 
exit; 
  SetLength(range,maxcnt);
  FillWaveTable;
  GPIO_SetStruct(GPIO_struct,1,gpio,'WAVE-TEST',[FRQHW]);
  if GPIO_Setup (GPIO_struct) then 
  begin
    if FRQ_Setup(GPIO_struct,freqHz) then
	begin
      repeat
        for n:= 0 to (maxcnt-1) do 
	    begin
//	      mmap_arr^[GPIO_struct.FRQ_DIVIdx]:=(BCM_PWD or ((range[n] and $fff) shl 12));	
writeln('#',n,' val:',range[n]);		
	    end;
      until false;
	end;
  end;
  SetLength(range,0);
end;

procedure FRQ_Test; 
const freqHz=1000000; gpio=4; // (1MHz on GPIO#4)
var  GPIO_struct:GPIO_struct_t; _mode,b:byte; FRQ_CTLIdx,FRQ_DIVIdx:longword; 
     reg,regctl,regdiv:longword; initok:boolean;		
begin 
  writeln('FRQ_Test: you should see a freq. ',freqHz:0,'Hz on GPIO',gpio:0,' minf:',(CLK_GetMinFreq/1000):0:1,'kHz maxf:',(CLK_GetMaxFreq/1000):0:1,' kHz');  
  if CLK_ValidFreq(freqHz) then
  begin
    GPIO_SetStruct(GPIO_struct,1,gpio,'FRQ HW TEST',[FRQHW]);
    if GPIO_Setup (GPIO_struct) then 
    begin
	  for b:= 0 to 3 do
      begin
        CLK_GetRegIdx(b,regctl,regdiv);
        reg:=BCM_GETREG(regdiv);  
	    writeln(Hex(GetRegAdr(regdiv),8),':  ',Hex(reg,8),' divisor:',CLK_GetDivisor(reg):0:5);
      end;
	  initok:=FRQ_GetClkRegIdx(gpio,_mode); 	
      if initok then initok:=CLK_GetRegIdx(_mode,FRQ_CTLIdx,FRQ_DIVIdx); 
	  if initok then
	  begin
	    for b:=0 to 3 do
	    begin
		  writeln('Mash: ',b:0,' ',Hex(CLK_GetMashValue(b),4)); 
		end;
	    show_regs('GMGP'+Num2Str(_mode,0)+'CTL',CLK_BASE_OFS,FRQ_CTLIdx,FRQ_DIVIdx,0,false); 
        initok:=FRQ_Setup(GPIO_struct,freqHz);
	    show_regs('GMGP'+Num2Str(_mode,0)+'CTL',CLK_BASE_OFS,FRQ_CTLIdx,FRQ_DIVIdx,0,false); 
//	    Clock_show_regs;
	    delay_msec(60000);
	    FRQ_End  (GPIO_struct);
	  end;
    end;	
  end;
end;

procedure CLK_Test;
const gpioPWM=13; // (PWM1/GPIO#13/Pin33)
	  gpioFRQ=20; // (OSC/GPIO#20/Pin38) 
var mode_pll,MASH,n:byte; reg,regctl,regdiv,DIVIF:longword; 
    fr,FREQ_O_min,FREQ_O_avg,FREQ_O_max:real; ok:boolean;
begin
  mode_pll:=1; fr:=18.32*1000000;
  ok:=CLK_GetClkFreq(3,CLK_GetFreq(mode_pll),fr,FREQ_O_min,FREQ_O_avg,FREQ_O_max,MASH,DIVIF);
  writeln('CLK_Tst, mode:',mode_pll:0,' f:',fr:0:2,' fmin:',FREQ_O_min:0:2,' favg:',FREQ_O_avg:0:2,' fmax:',FREQ_O_max:0:2,' MASH:',MASH,' DIVIF:0x',Hex(DIVIF,8),' ok:',ok);
  for n:= 0 to 3 do
  begin
    CLK_GetRegIdx(n,regctl,regdiv);
    reg:=BCM_GETREG(regdiv);  
	writeln(Hex(GetRegAdr(regdiv),8),':  ',Hex(reg,8),' divisor:',CLK_GetDivisor(reg):0:5);
  end;
end;

procedure GPIO_set_PINMODE(gpio:longword; portfkt:t_port_flags);
// http://wiki.freepascal.org/Lazarus_on_Raspberry_Pi#5._PiGPIO_Low-level_native_pascal_unit_.28GPIO_control_instead_of_wiringPi_c_library.29
var akft:t_port_flags;
begin
//LOG_Writeln(LOG_DEBUG,'GPIO_set_PINMODE: GPIO'+Num2Str(gpio,0)+' Mode: '+Num2Str(ord(portfkt),0)); 
  case portfkt of
    INPUT : GPIO_set_INPUT (gpio);
    OUTPUT: GPIO_set_OUTPUT(gpio);
	ALT0,ALT1,ALT2,ALT3,ALT4,
    ALT5  : GPIO_set_ALT   (gpio,portfkt); 	
	PWMHW : begin
			  akft:=INPUT; 
			  case gpio of
					 12,13,40,41,45 : akft:=ALT0;
					 18,19          : akft:=ALT5;
					 52,53          : akft:=ALT1;
			  end; // case
			  if (akft<>INPUT) then begin GPIO_set_ALT(gpio,akft); end
			    else Log_Writeln(LOG_ERROR,'GPIO_set_PINMODE: GPIO'+Num2Str(gpio,0)+' portfkt:'+Num2Str(ord(portfkt),0)+' cannot be set to PWM'); 		
		    end;
    else Log_Writeln(LOG_ERROR,'GPIO_set_PINMODE: GPIO'+Num2Str(gpio,0)+' portfkt:'+Num2Str(ord(portfkt),0)+' mode not defined'); 
  end; // case
end;

procedure GPIO_Switch(var GPIO_struct:GPIO_struct_t); // Read GPIOx Status in Struct
var sh:string;
begin
  with GPIO_struct do
  begin
    if initok then
    begin	
	  if not (simulation IN portflags) then 
	  begin 
		ein:=(GPIO_get_PIN(gpio) xor (mask_pol<>0));
	  end;
	  sh:=description;
	  if sh='' then sh:='GPIO_Switch(Num#'+Num2Str(nr,0)+'/GPIO#'+Num2Str(gpio,0)+
					'/HWPin#'+Num2Str(HWPin,0)+')';
//	  writeln(sh+	' ReversePolarity: '+Bool2Str((mask_pol<>0))+' SignalLevel: '+Bool2Str(ein));	  
    end
    else LOG_Writeln(LOG_ERROR,'GPIO_Switch HDRPin:'+Num2Str(HWPin,0)+' not registered');
  end;
end;

procedure GPIO_Switch(var GPIO_struct:GPIO_struct_t; switchon:boolean); // switch GPIOx on/off
var sh:string; 
begin
  with GPIO_struct do
  begin
    if initok then
    begin 
      if switchon<>ein then 
	  begin
	    sh:=description;
		if sh='' then sh:='GPIO_Switch(Num#'+Num2Str(nr,0)+'/GPIO#'+Num2Str(gpio,0)+
					'/HWPin#'+Num2Str(HWPin,0)+')';
//		writeln(sh+	' ReversePolarity: '+Bool2Str((mask_pol<>0))+' SignalLevel: '+Bool2Str(switchon));
				   
		if not (simulation IN portflags) then 
		begin // only on level change
		  if switchon then mmap_arr^[regset]:=mask_1Bit else mmap_arr^[regclr]:=mask_1Bit;
		end;
	  end;
	  ein:=switchon;
    end
    else LOG_Writeln(LOG_ERROR,'GPIO_Switch HDRPin:'+Num2Str(HWPin,0)+' not registered');
  end;
end;

procedure GPIO_SetStruct(var GPIO_struct:GPIO_struct_t; num,gpionum:longint; desc:string; flags:s_port_flags);
//e.g. GPIO_SetStruct(structure,3,8,'description',[INPUT,PullUP,ReversePOLARITY]);
begin  
  with GPIO_struct do
  begin	
	gpio:=gpionum; HWPin:=GPIO_MAP_GPIO_NUM_2_HDR_PIN(gpio); 
	nr:=num; description:=desc; portflags:=flags; FRQ_freq_Hz:=0.0;
	RPI_HDR_SetDesc(HWPin,desc);
	idxofs_1Bit:=0; idxofs_3Bit:=0; mask_1Bit:=0; mask_3Bit:=0; mask_pol:=0; 
	regget:=GPIOONLYREAD; regset:=GPIOONLYREAD; regclr:=GPIOONLYREAD; ein:=false;
	with ThreadCtrl do begin TermThread:=true; ThreadRunning:=false; end; 
//	plausibility check and clean-up of port flags 
	if (PWMHW 		IN portflags)  or 
	   (PWMSW 		IN portflags)  then portflags:=portflags+[OUTPUT];
    if (INPUT  	    IN portflags)  and 
	   (OUTPUT      IN portflags)  then portflags:=portflags-[OUTPUT,PWMHW,PWMSW]; // cannot be both		  
	if (PullUP      IN portflags)  and 
	   (PullDOWN    IN portflags)  then portflags:=portflags-[PullDOWN]; // cannot be both		  		  
	if (RisingEDGE  IN portflags)  and 
	   (not(INPUT   IN portflags)) then portflags:=portflags-[RisingEDGE]; 
    if (FallingEDGE IN portflags)  and 
	   (not(INPUT   IN portflags)) then portflags:=portflags-[FallingEDGE]; 
	if (PWMHW IN portflags) and (not GPIO_FCTOK(gpio,[PWMHW])) then
	begin
	  LOG_writeln(LOG_ERROR,'GPIO_SetStruct: GPIO'+Num2Str(gpio,0)+' can not be PWMHW');
	  portflags:=portflags-[PWMHW]+[PWMSW];		
	end;
	if (FRQHW IN portflags) then
    begin
	  portflags:=portflags-[OUTPUT,ALT0,ALT5];
	  if GPIO_FCTOK(gpio,[FRQHW]) then
	  begin
	    portflags:=portflags+[ALT0];	
        if (gpio=GPIO_FRQ20_CLK0) or (gpio=GPIO_FRQ21_CLK1) 
		  then portflags:=portflags-[ALT0]+[ALT5];	  
	  end
	  else
	  begin
	    LOG_writeln(LOG_ERROR,'GPIO_SetStruct: GPIO'+Num2Str(gpio,0)+' can not be FRQHW');
	    portflags:=portflags-[FRQHW];		
	  end;
	end;
	if (portflags=[]) 			   then portflags:=[INPUT]; 
	initok:=((gpio>=0) and (gpio<64)); 
	if initok then 
	begin
	  GPIO_get_mask_and_idxOfs(GPFSEL,gpio,idxofs_3Bit,mask_3Bit);
	  GPIO_get_mask_and_idxOfs(GPSET, gpio,idxofs_1Bit,mask_1Bit);
	  regget:=GPLEV+idxofs_1Bit; 
	  if (ReversePOLARITY IN portflags) then 
	  begin 
	    regset:=GPCLR+idxofs_1Bit; 
		regclr:=GPSET+idxofs_1Bit; 
		mask_pol:=mask_1Bit;
	  end
	  else 
	  begin 
	    regset:=GPSET+idxofs_1Bit; 
		regclr:=GPCLR+idxofs_1Bit; 
		mask_pol:=0;
	  end;
	end;
    pwm_SetStruct(GPIO_struct); // set default values for pwm
//  GPIO_ShowStruct(GPIO_struct);
  end;
end;

procedure GPIO_SetStruct(var GPIO_struct:GPIO_struct_t);
begin
  GPIO_SetStruct(GPIO_struct,0,-1,'',[INPUT]);
end;

function  GPIO_Setup(var GPIO_struct:GPIO_struct_t):boolean;
begin
  with GPIO_struct do
  begin
    if initok then 
	begin
	  if gpio<0 then
	  begin
	    gpio:=-1; initok:=false;
	    LOG_Writeln(LOG_ERROR,'GPIO_Reg for HDRPin: '+Num2Str(HWPin,0)+' can not be mapped to GPIO num');
	  end
	  else
	  begin
	    if not (simulation IN portflags)then
	    begin	
//		  setup of portflags
		  ein:=false;
		  if (FallingEDGE  	IN portflags) then GPIO_set_edge_falling(gpio,true); 
		  if (RisingEDGE   	IN portflags) then GPIO_set_edge_rising (gpio,true); 
//		  writeln('GPIO_Setup: ',ord(port_dir));
          if (INPUT  		IN portflags) then begin GPIO_set_PINMODE (gpio,INPUT);  end; 
	      if (OUTPUT 		IN portflags) then 
		  begin 
		    GPIO_set_PINMODE (gpio,OUTPUT);  
			GPIO_Switch(GPIO_struct,false); 
		  end;
		  if (PullDOWN IN portflags) then GPIO_set_PULLDOWN    (gpio,true); 
		  if (PullUP   IN portflags) then GPIO_set_PULLUP      (gpio,true); 
		  if (PWMSW    IN portflags) or (PWMHW IN portflags) 
		    then initok:=pwm_Setup(GPIO_struct);
        end;		
	  end;
	end
	else Log_Writeln(LOG_ERROR,'GPIO_Setup: GPIO_struct is not initialized'); 
  end; // with
  GPIO_Setup:=GPIO_struct.initok;
end;

procedure xyx(reg1,reg2,mask:longword); begin mmap_arr^[reg1]:=mask; mmap_arr^[reg2]:=mask; end;
  
procedure Toggle_Pin_very_fast(gpio:longword; cnt:qword);
// just to show how fast (without overhead) we can toggle PINxx. 
// with rpi2 B+ @ 900MHz
// Result(fastway=true): >20Mhz // Result(fastway=false): 2.4Mhz 
const fastway=true;
var i:qword; GPIO_struct:GPIO_struct_t; s,e:TDateTime; 
begin
  i:=0;
  GPIO_SetStruct(GPIO_struct,1,gpio,'GPIO Toggle TEST',[OUTPUT]);
  if GPIO_Setup (GPIO_struct) then
  begin
    with GPIO_struct do
	begin
//GPIO_show_regs;	
	  GPIO_ShowStruct(GPIO_struct);
	  writeln('Start with ',cnt:0,' samples, GPIO',gpio:0,' Pin:',HWPin:0,' Mask:0x',Hex(mask_1Bit,8),' idxofs_1Bit:0x',Hex(idxofs_1Bit,2),')');
      s:=now; // start measuring time 
	  repeat 
	    {$warnings off} 
	      if fastway then
		  begin // >20MHz
//          xyx(regset,regclr,mask_1Bit); // 15MHz, takes 30% times longer ??!!
	        mmap_arr^[regset]:=mask_1Bit; (* High*) mmap_arr^[regclr]:=mask_1Bit; (* Low *)
		  end
		  else 
		  begin // 2-3Mhz only ???!!!
		    GPIO_Switch(GPIO_struct,true); GPIO_Switch(GPIO_struct,false);
		  end;
		{$warnings on} 
		inc(i); 
	  until (i>=cnt);
      e:=now; // end measuring time
	  writeln('End: ',FormatDateTime('yyyy-mm-dd hh:nn:ss',e),' (',(cnt/MilliSecondsBetween(e,s)/1000):0:3,'MHz)');
	end; 
  end else writeln('Can not initialize GPIO',gpio);
end;

procedure Toggle_STATUSLED_very_fast; begin Toggle_Pin_very_fast(RPI_status_led_GPIO,100000000); end;	

procedure LED_Status(ein:boolean); begin GPIO_set_PIN(RPI_status_led_GPIO,ein); end;

procedure GPIO_PIN_TOGGLE_TEST;
{ just for demo reasons }
const looptimes=10; waittime_ms	= 1000; // 0.5Hz; let Status LED blink  
var   lw:longword;
begin
//GPIO_show_regs;
  writeln('Start of GPIO_PIN_TOGGLE_TEST (Let the Status-LED blink ',looptimes:0,' times)');
  writeln('Set GPIO',RPI_status_led_GPIO:0,' to OUTPUT'); 
  GPIO_set_OUTPUT(RPI_status_led_GPIO);   
  for lw := 1 to looptimes do
  begin
    writeln(looptimes-lw+1:3,'. Set StatusLED (GPIO',RPI_status_led_GPIO,') to 1'); LED_Status(true);  sleep(waittime_ms);
	writeln(looptimes-lw+1:3,'. Set StatusLED (GPIO',RPI_status_led_GPIO,') to 0'); LED_Status(false); sleep(waittime_ms);
	writeln;
  end;
  writeln('End of GPIO_PIN_TOGGLE_TEST');
end;
  
procedure GPIO_set_BIT(regidx,gpio:longword;setbit,readmodifywrite:boolean); { set or reset pin in gpio register part }
var idx,mask:longword;
begin
  GPIO_get_mask_and_idx(regidx,gpio,idx,mask);
//Writeln('GPIO_set_BIT: GPIO'+Num2Str(gpio,0)+' level: '+Bool2Str(setbit)+' Reg: 0x'+Hex(regidx,8)+' idx: 0x'+Hex(idx,8)+' mask: 0x'+Hex(mask,8));   
  if setbit then BCM_SETREG(idx,    mask ,false,readmodifywrite)
            else BCM_SETREG(idx,not(mask),true, readmodifywrite);
end;
  
procedure GPIO_set_PIN(gpio:longword;highlevel:boolean);
{ Set RPi GPIO to high or low level: Speed @ 700MHz ->  1.25MHz }
begin
//Log_Writeln(LOG_DEBUG,'GPIO_set_PIN: '+Num2Str(gpio,0)+' level '+Bool2Str(highlevel));
//Writeln('GPIO_set_PIN: '+Num2Str(gpio,0)+' level '+Bool2Str(highlevel));
  if highlevel then GPIO_set_BIT(GPSET,gpio,true,false) else GPIO_set_BIT(GPCLR,gpio,true,false);
  { sleep(1); }
end;

function  GPIO_get_PIN   (gpio:longword):boolean;
// Get RPi GPIO pin Level is true when Pin level is '1'; false when '0'; Speed @ 700MHz ->  2.33MHz 
var idx,mask:longword;
begin
  GPIO_get_mask_and_idx(GPLEV,gpio,idx,mask);
  GPIO_get_PIN:=((BCM_GETREG(idx) and mask)>0);
end;

procedure GPIO_Pulse(gpio,pulse_ms:longword);
begin
  GPIO_set_pin(gpio,true);
  delay_msec(pulse_ms);
  GPIO_set_pin(gpio,false);
end;

procedure GPIO_set_GPPUD(enable,pullup:boolean); 
begin 
  if enable then
  begin
    if pullup then BCM_SETREG(GPPUD,$02,false,false) else BCM_SETREG(GPPUD,$01,false,false);
  end
  else BCM_SETREG(GPPUD,$00,false,false);
  delay_msec(1);
end; { set GPIO Pull-up/down Register (GPPUD) } 

procedure GPIO_set_PULLUPORDOWN(gpio:longword; enable,pullup:boolean); // pulldown: pullup=false;
// approximately 50KΩ
var idx,mask:longword;
begin 
  LOG_Writeln(LOG_DEBUG,'GPIO_set_PULLUPORDOWN: GPIO'+Num2Str(gpio,0)+' '+Bool2Str(enable)+' '+Bool2Str(pullup)); 
  GPIO_get_mask_and_idx(GPPUDCLK,gpio,idx,mask);
  GPIO_set_GPPUD(enable,pullup); 				// assert clock to GPPUDCLKn
  BCM_SETREG(idx,mask,false,false);
  delay_msec(1);
  GPIO_set_GPPUD(false, pullup); 				// deassert clock from GPPUDCLKn
  BCM_SETREG(idx,0,false,false);  
  delay_msec(1);
end;
procedure GPIO_set_PULLUP  (gpio:longword; enable:boolean); begin GPIO_set_PULLUPORDOWN(gpio,enable,true);  end;	// enable or disable PULLUP
procedure GPIO_set_PULLDOWN(gpio:longword; enable:boolean); begin GPIO_set_PULLUPORDOWN(gpio,enable,false); end;	// enable or disable PULLDOWN

procedure GPIO_set_edge_rising(gpio:longword; enable:boolean);  { Pin RisingEdge  Detection Register (GPREN) }
begin 
  Log_Writeln(LOG_DEBUG,'GPIO_set_edge_rising: GPIO'+Num2Str(gpio,0)+' enable: '+Bool2Str(enable)); 
  GPIO_set_BIT(GPREN,gpio,enable,true);   { Pin RisingEdge  Detection }
end;

procedure GPIO_set_edge_falling(gpio:longword; enable:boolean); { Pin FallingEdge  Detection Register (GPFEN) }
begin 
  Log_Writeln(LOG_DEBUG,'GPIO_set_edge_falling: GPIO'+Num2Str(gpio,0)+' enable: '+Bool2Str(enable)); 
  GPIO_set_BIT(GPFEN,gpio,enable,true);  { Pin FallingEdge Detection }
end;

procedure GPIO_PWM_Test(gpio:longint; HWPWM:boolean; freq_Hz:real; dutyrange,startval:longword);
// only for PWM0:Pin12:GPIO18 PWM1:Pin35:GPIO19
const maxcnt=2; 
var i,cnt:longint; GPIO_struct:GPIO_struct_t;
begin
  if HWPWM then  GPIO_SetStruct(GPIO_struct,1,gpio,'HW PWM_TEST',[PWMHW])
			else GPIO_SetStruct(GPIO_struct,1,gpio,'SW PWM_TEST',[PWMSW]);
  pwm_SetStruct (GPIO_struct,PWM_MS_MODE,freq_Hz,dutyrange,startval); // ca. 50Hz (50000/1000) -> divisor: 384	
  pwm_SetClock  (GPIO_struct);
  if GPIO_Setup (GPIO_struct) then
  begin
    GPIO_ShowConnector; GPIO_ShowStruct(GPIO_struct); 		
	i:=0; cnt:=1;
	repeat
	  if (i>(dutyrange-1)) then 
	  begin 
	    pwm_Write(GPIO_struct,dutyrange-1);	
		writeln('Loop(',cnt,'/',dutyrange,'): reached max. pwm value: ',dutyrange-1); sleep(30); 
		GPIO_ShowStruct(GPIO_struct); 
		i:=0; inc(cnt);
	  end 
      else pwm_Write(GPIO_struct,i);
//    if (i=(dutyrange div 2)) then readln;  // for measuring with osci
	  if HWPWM then begin inc(i); sleep(10); end else begin inc(i,10); sleep(10); end;	// ms
	until (cnt>maxcnt);
	pwm_Write     (GPIO_struct,0);	// set last value to 0
	pwm_SetStruct (GPIO_struct); 	// reset to PWM default values
    sleep(100); // let SW Thread time to terminate
  end
  else Log_Writeln(LOG_ERROR,'GPIO_PWM_Test: GPIO'+Num2Str(GPIO_struct.gpio,0)+' Init has failed'); 	
end;

procedure GPIO_PWM_Test; // Test with GPIO18 PWM0 on Connector Pin12
const gpio=GPIO_PWM0; 
var dc,f_hz:longword;
begin
  f_hz:=50; dc:=PWM_GetMaxDtyC(f_hz);	// get the best DutyCycle for this freq.
  writeln('GPIO_PWM_Test with GPIO',gpio,' Connector Pin',GPIO_MAP_GPIO_NUM_2_HDR_PIN(gpio),' SOFTWARE based');
  GPIO_PWM_Test(gpio,false,f_hz,dc,0); // SW PWM Test

  f_hz:=5000; dc:=PWM_GetMaxDtyC(f_hz);	// get the best DutyCycle for this freq.
  writeln('GPIO_PWM_Test with GPIO',gpio,' Connector Pin',GPIO_MAP_GPIO_NUM_2_HDR_PIN(gpio),' HARDWARE based');
  GPIO_PWM_Test(gpio,true, f_hz,dc,0);  // HW PWM Test
  writeln('GPIO_PWM_Test END');
end;

procedure GPIO_Test(HWPinNr:longword; flags:s_port_flags);
const loopmax=2;
var i:longint; GPIO_struct:GPIO_struct_t;
begin
  GPIO_SetStruct(GPIO_struct,1,GPIO_MAP_HDR_PIN_2_GPIO_NUM(HWPinNr),'GPIO_Test',flags);
  if GPIO_Setup (GPIO_struct) then
  begin
    with GPIO_struct do
	begin
	  description:='GPIO_Test(HWPin#'+Num2Str(HWPin,0)+'/GPIO#'+Num2Str(gpio,0)+')';
	  if (OUTPUT IN flags) then
	  begin
        writeln('Test OUTPUT HWPin: '+Num2Str(HWPin,0)+'  GPIO: '+Num2Str(gpio,0)); 
	    for i := 1 to loopmax do
	    begin
	      writeln('  for setting Pin to HIGH, pls. push <CR> button'); readln;
          GPIO_Switch(GPIO_struct,true); 
          writeln('  for setting Pin to LOW,  pls. push <CR> button'); readln;
	      GPIO_Switch(GPIO_struct,false); 
	    end;
	    writeln('Test next PIN, pls. push <CR> button'); readln;
      end; // Output-Test
	  if (INPUT IN flags) then
	  begin
        writeln('Test INPUT HWPin: '+Num2Str(HWPin,0)+'  GPIO: '+Num2Str(gpio,0)); 
		for i := 1 to loopmax do
	    begin
	      writeln('  for reading Pin, pls. push <CR> button'); readln; 
		  GPIO_Switch(GPIO_struct); // Read GPIO
		  writeln(description+': '+Bool2LVL(ein));
		end;
	  end; // Input-Test
	end; // with
  end
  else Writeln('GPIO_Test: can not Map HWPin:'+Num2Str(HWPinNr,0)+' to valid GPIO num');	
  writeln;
end;

procedure GPIO_TestAll;
// for testing of correct operation. (only OUTPUT tests)
begin
  begin // 26 Pin Hdr
    GPIO_Test(07,[OUTPUT]); GPIO_Test(11,[OUTPUT]); GPIO_Test(12,[OUTPUT]); 
	GPIO_Test(13,[OUTPUT]); GPIO_Test(15,[OUTPUT]); GPIO_Test(16,[OUTPUT]); 
	GPIO_Test(18,[OUTPUT]); GPIO_Test(22,[OUTPUT]); 
  end;
  if RPI_hdrpincount>=40 then
  begin // 40 PIN Hdr
    GPIO_Test(29,[OUTPUT]); GPIO_Test(31,[OUTPUT]); GPIO_Test(32,[OUTPUT]); 
	GPIO_Test(33,[OUTPUT]); GPIO_Test(35,[OUTPUT]); GPIO_Test(36,[OUTPUT]); 
	GPIO_Test(37,[OUTPUT]); GPIO_Test(38,[OUTPUT]); GPIO_Test(40,[OUTPUT]);
  end;
end;

procedure SERVO_End(var SERVO_struct:SERVO_struct_t);
begin PWM_End(SERVO_struct.HWAccess); end;

procedure SERVO_End(hndl:longint);
var n:longint;
begin
  if hndl<0 then
  begin
    for n:= 1 to Length(SERVO_struct) do SERVO_End(SERVO_struct[n-1]);
    SetLength(SERVO_struct,0);
  end else SERVO_End(SERVO_struct[hndl]);
end;

procedure SERVO_SetStruct(var SERVO_struct:SERVO_struct_t; dty_min,dty_mid,dty_max:longword; ang_min,ang_mid,ang_max,speed:longint);
begin
  with SERVO_struct do
  begin
    if ((ang_min<=ang_mid) and (ang_mid<=ang_max)) and 
	   ((dty_min<=dty_mid) and (dty_mid<=dty_max)) then
    begin
	  min_dutycycle:=dty_min; mid_dutycycle:=dty_mid; max_dutycycle:=dty_max; 
	  min_angle:=	 ang_min; mid_angle:=    ang_mid; max_angle:=    ang_max;
	end
	else
	begin
	  min_dutycycle:=SRVOMINDC;  mid_dutycycle:=SRVOMIDDC;  max_dutycycle:=SRVOMAXDC;  // SG90 ms in Ticks
	  min_angle:=	 SRVOMINANG; mid_angle:=    SRVOMIDANG; max_angle:=    SRVOMAXANG; // SG90 degree Values 
	  LOG_writeln(LOG_ERROR,'SERVO_SetStruct: invalid duty cycle or angle values. set it to default values');
	end;
	speed60deg:=speed;
	angle_current:=max_angle+1;			// just to force 1. servo-movement to 0Deg
  end;
end;

procedure SERVO_Write(var SERVO_struct:SERVO_struct_t; angle:longint; syncwait:boolean);
var setval,angle_old:longint;
begin
  with SERVO_struct do
  begin
    if (angle_current<>angle) then
	begin
	  angle_old:=angle_current; angle_current:=angle; 
	  if angle_current<min_angle then angle_current:=min_angle; 
	  if angle_current>max_angle then angle_current:=max_angle;
	  setval:=mid_dutycycle;
	  if ((min_angle<>0) and (max_angle<>0) and (angle_current<>mid_angle)) then
      begin	
	    if (angle_current>=min_angle) and (angle_current<mid_angle) then
	    begin
		  setval:=round(((min_angle-angle_current)/min_angle) * 
		                 (mid_dutycycle-min_dutycycle) + min_dutycycle);
//        writeln('Angle-: ',angle_current);
	    end
	    else
	    begin
//        writeln('Angle+: ',angle_current);
		  setval:=round((angle_current/max_angle) * 
		                (max_dutycycle-mid_dutycycle) + mid_dutycycle);
	    end;
	  end;
//    writeln('setval1: ',setval);
//    transform setval to dutyrange e.g. 0..1000
      with SERVO_struct.HWAccess.PWM do
	  begin
	    if (pwm_dutyrange<>0) and (pwm_period_us<>0) 
	      then setval:=abs(round(setval/(pwm_period_us/pwm_dutyrange)))
	      else setval:=0;	 
      end; // with		
//    writeln('setval2: ',setval,' #######################################');
	  pwm_Write(SERVO_struct.HWAccess,setval);
//    writeln('SyncWaitTime(ms):',round((abs(angle_old-angle_current)/60)*speed60Deg));
	  if syncwait then 
	    delay_msec(round((abs(angle_old-angle_current)/60)*speed60Deg));
    end;	
  end; // with
end;

procedure SERVO_Setup(var SERVO_struct:SERVO_struct_t; 
						HWPinNr,nr,maxval,
						dcmin,dcmid,dcmax:longword; 
						angmin,angmid,angmax,speed:longint;
						desc:string; freq:real; flags:s_port_flags);
var flgs:s_port_flags; _gpio:longint;
begin
  _gpio:=GPIO_MAP_HDR_PIN_2_GPIO_NUM(HWPinNr); 
  if (PWMSW IN flags) or (PWMHW IN flags) then flgs:=flags else flgs:=flags+[PWMSW];
  if (PWMHW IN flags) and (not GPIO_HWPWM_capable(_gpio)) then flgs:=flags+[PWMSW]-[PWMHW];
  with SERVO_struct do
  begin
    SERVO_SetStruct(SERVO_struct,dcmin,dcmid,dcmax,angmin,angmid,angmax,speed);
    GPIO_SetStruct (SERVO_struct.HWAccess,nr,_gpio,desc,flgs);
    pwm_SetStruct  (SERVO_struct.HWAccess,PWM_MS_MODE,freq,maxval,dcmid);
    pwm_SetClock   (SERVO_struct.HWAccess);
  end; // with
end;

procedure SERVO_GetData(var nr,yaw,pitch,roll:longint);
// Get Data from Accelerator-/Gyro-/Compass-Sensors (e.g. Quaternion, Euler-Angels)
// use Data and convert it to new Servo positions
// this is just for demo reasons
var min,mid,max:longint;
begin
  min:=SRVOMINANG; mid:=SRVOMIDANG; max:=SRVOMAXANG;
  case (nr mod 12) of // just a quick demo
      1: begin yaw:=max; pitch:=mid; roll:=mid; end; 
	  2: begin yaw:=max; pitch:=max; roll:=mid; end; 
	  3: begin yaw:=max; pitch:=max; roll:=max; end; 
	  4: begin yaw:=mid; pitch:=max; roll:=max; end; 
	  5: begin yaw:=mid; pitch:=mid; roll:=max; end; 
	  7: begin yaw:=min; pitch:=mid; roll:=mid; end; 
	  8: begin yaw:=min; pitch:=min; roll:=mid; end; 
	  9: begin yaw:=min; pitch:=min; roll:=min; end; 
	 10: begin yaw:=mid; pitch:=min; roll:=min; end; 
	 11: begin yaw:=mid; pitch:=mid; roll:=min; end; 
    else begin yaw:=mid; pitch:=mid; roll:=mid; end;
  end;
  inc(nr); 
end;

procedure SERVO_Test;
// tested with TowerPro Micro Servos 9g SG90 Datasheet values 
//   "0" (1.5 ms pulse) is middle, 
//  "90" ( ~2 ms pulse) is all the way to the right, 
// "-90" ( ~1 ms pulse) is all the way to the left.
// Frequency: 50Hz-> 20ms period (20000us)
const   
  freq=SERVO_FRQ; speed=SERVO_Speed;
  HWPinNr_YAW=  12; // GPIO18 HW-PWM
  YAW_minAng=SRVOMINANG;	YAW_midANG=SRVOMIDANG;	    YAW_maxAng=SRVOMAXANG;// SG90 degree Values
  YAW_min=   SRVOMINDC;     YAW_mid=   SRVOMIDDC; 	  	YAW_max=   SRVOMAXDC; // SG90 ms in Ticks
  HWPinNr_PITCH=16; // GPIO23 SW-PWM	
  PITCH_min=   YAW_min; 	PITCH_mid=   YAW_mid; 		PITCH_max=   YAW_max;
  PITCH_minAng=YAW_minAng;	PITCH_midAng=YAW_midAng;	PITCH_maxAng=YAW_maxANG;
  HWPinNr_ROLL= 18; // GPIO24 SW-PWM
  ROLL_min=   YAW_min; 		ROLL_mid=   YAW_mid; 		ROLL_max=   YAW_max;
  ROLL_minAng=YAW_minAng;	ROLL_midAng=YAW_midAng;		ROLL_maxAng=YAW_maxANG;
var nr,yaw,pitch,roll,_dc:longint;
begin
  writeln('SERVO_Test: Start');
  SetLength(SERVO_struct,3);	// create data structures for 3 servos
  _dc:=PWM_GetMaxDtyC(freq);	// get the best DutyCycle for this freq.
  SERVO_Setup(  SERVO_struct[0],HWPinNr_YAW,  0,_dc,YAW_min,  YAW_mid,  YAW_max,  YAW_minAng,  YAW_midAng,  YAW_maxANG,  speed,'SERVO YAW  ',freq,[PWMHW]);
  SERVO_Setup(  SERVO_struct[1],HWPinNr_PITCH,1,_dc,PITCH_min,PITCH_mid,PITCH_max,PITCH_minAng,PITCH_midAng,PITCH_maxAng,speed,'SERVO PITCH',freq,[PWMSW]);
  SERVO_Setup(  SERVO_struct[2],HWPinNr_ROLL, 2,_dc,ROLL_min, ROLL_mid, ROLL_max, ROLL_minAng, ROLL_midAng, ROLL_maxAng, speed,'SERVO ROLL ',freq,[PWMSW]);
  if GPIO_Setup(SERVO_struct[0].HWAccess) and 
     GPIO_Setup(SERVO_struct[1].HWAccess) and
	 GPIO_Setup(SERVO_struct[2].HWAccess) then
  begin 
    nr:=0; 
    repeat // control loop
// Do SERVO_Write(SERVO_struct[<nr>],<new_servo_pos>,<syncwait>); 
	  SERVO_GetData(nr,yaw,pitch,roll);	// get new servo position data
	  writeln('Servos: ',yaw:4,' ',pitch:4,' ',roll:4);
	  SERVO_Write(SERVO_struct[0],yaw,  false); 
	  SERVO_Write(SERVO_struct[1],pitch,false); 
	  SERVO_Write(SERVO_struct[2],roll, false); 
      delay_msec(SERVO_Speed*round(90/60)); // let servo time for full turn
	until (nr>50);
	for nr:=1 to Length(SERVO_struct) do SERVO_Write(SERVO_struct[nr-1],0,false);  
	delay_msec(SERVO_Speed*round(90/60)); // let servos time to turn to neutral position
	SERVO_End(-1);
	writeln('SERVO_Test: END');
  end 
  else LOG_Writeln(LOG_ERROR,'SERVO_Test: could not be initialized');
end;

function  GPIO_MAP_GPIO_NUM_2_HDR_PIN(gpio:longword; mapidx:byte):longint; { Maps GPIO Number to the HDR_PIN, respecting rpi rev1 or rev2 board }
var hwpin,cnt:longint; 
begin
  hwpin:=-99; cnt:=1;
  if ((mapidx=1) or (mapidx<=gpiomax_map_idx_c)) then 
  begin
    while cnt<=max_pins_c do
	begin
	  if abs(GPIO_hdr_map_c[mapidx,cnt])=gpio then begin hwpin:=cnt; cnt:=max_pins_c; end;
	  inc(cnt);
	end;
  end;
//writeln('mapidx',mapidx:0,' HW-PIN: ',hwpin:2,' <- ',gpio:2);
  GPIO_MAP_GPIO_NUM_2_HDR_PIN:=hwpin;
end;  

function  GPIO_MAP_GPIO_NUM_2_HDR_PIN(gpio:longword):longint;
begin
  GPIO_MAP_GPIO_NUM_2_HDR_PIN:=GPIO_MAP_GPIO_NUM_2_HDR_PIN(gpio,RPI_gpiomapidx);
end;
  
function  GPIO_MAP_HDR_PIN_2_GPIO_NUM(hdr_pin_number:longint; mapidx:byte):longint; { Maps HDR_PIN to the GPIO Number, respecting rpi rev1 or rev2 board }
var GPIO_pin:longint;
begin
  if (hdr_pin_number>=1) and (hdr_pin_number<=max_pins_c) and 
     ((mapidx>=1) and (mapidx<=gpiomax_map_idx_c)) then GPIO_pin:=GPIO_hdr_map_c[mapidx,hdr_pin_number] else GPIO_pin:=WRONGPIN;
//writeln('mapidx',mapidx:0,' HW-PIN: ',hdr_pin_number:2,' -> ',GPIO_pin:2);
  GPIO_MAP_HDR_PIN_2_GPIO_NUM:=GPIO_pin;
end;

function  GPIO_MAP_HDR_PIN_2_GPIO_NUM(hdr_pin_number:longint):longint;
begin
  GPIO_MAP_HDR_PIN_2_GPIO_NUM:=GPIO_MAP_HDR_PIN_2_GPIO_NUM(hdr_pin_number,RPI_gpiomapidx);
end;

procedure GPIO_set_HDR_PIN(hw_pin_number:longword;highlevel:boolean); { Maps PIN to the GPIO Header, respecting rpi rev1 or rev2 board }
var pin:longint;
begin
  pin:=GPIO_MAP_HDR_PIN_2_GPIO_NUM(hw_pin_number,RPI_gpiomapidx);
  if pin>=0 then GPIO_set_PIN(longword(pin),highlevel);
end;

function  GPIO_get_HDR_PIN(hw_pin_number:longword):boolean; { Maps PIN to the GPIO Header, respecting rpi rev1 or rev2 board }
var pin:longint; lvl:boolean;
begin
  pin:=GPIO_MAP_HDR_PIN_2_GPIO_NUM(hw_pin_number,RPI_gpiomapidx);
  if pin>=0 then lvl:=GPIO_get_PIN(longword(pin)) else lvl:=false;
  GPIO_get_HDR_PIN:=lvl;
end;

function  ENC_GetVal(hdl:byte; ctrsel:integer):real; 
var val:real;
begin 
  val:=0;
  {$warnings off}
  if (hdl>=0) and (hdl<Length(ENC_struct)) then {$warnings on}
  begin
    with ENC_struct[hdl] do
    begin
	  EnterCriticalSection(ENC_CS); 		
        case ctrsel of
           0 : val:=CNTInfo.counter;
	       1 : val:=cycles;
	       2 : val:=CNTInfo.switchcounter;
	       3 : if CNTInfo.countermax<>0 then val:=CNTInfo.counter/CNTInfo.countermax;
	       4 : val:=CNTInfo.encFreq;
	      else val:=CNTInfo.counter;
	    end; // case
	  LeaveCriticalSection(ENC_CS);
    end; // with
  end else LOG_Writeln(LOG_ERROR,'ENC_GetVal: hdl '+Num2Str(hdl,0)+' out of range');
  ENC_GetVal:=val;  
end;

function  ENC_GetVal       (hdl:byte):real; begin ENC_GetVal:=       ENC_GetVal(hdl,0); end;
function  ENC_GetValPercent(hdl:byte):real; begin ENC_GetValPercent:=ENC_GetVal(hdl,3); end;
function  ENC_GetSwitch    (hdl:byte):real; begin ENC_GetSwitch:=    ENC_GetVal(hdl,2); end;

procedure ENC_IncSwCnt (var ENCInfo:ENC_CNT_struct_t; cnt:integer);
begin inc(ENCInfo.switchcounter,cnt); end;

procedure ENC_IncEncCnt(var ENCInfo:ENC_CNT_struct_t; cnt:integer);
begin inc(ENCInfo.counter,cnt); end;

function  ENC_GetCounter(var ENCInfo:ENC_CNT_struct_t; ctrsel:integer):boolean;
begin
  with ENCInfo do
  begin
	switchcounterold:=	switchcounter; 	
	switchcounter:=		round(ENC_GetSwitch(Handle)); 
	counterold:=		counter; 		
	counter:=  			round(ENC_GetVal   (Handle,ctrsel));
	swsteps:=			switchcounter-switchcounterold;
	encsteps:=			counter-	  counterold;
	ENC_activity:=		((encsteps<>0) or (swsteps<>0));
//	writeln('ENC_GetCounter: ',counter,' ',counterold,' ',encsteps,' Switch: ',switchcounter,' ',switchcounterold);
    ENC_GetCounter:=	ENC_activity;
  end; // with
end;
 
procedure ENC_End(hdl:integer); 
var i:integer; 
begin 
  if (hdl<0) then
  begin
    for i:= 1 to Length(ENC_struct) do Thread_End(ENC_struct[i-1].ThreadCtrl,100);
	SetLength(ENC_struct,0);
  end
  else
  begin
    if (hdl>=0) and (hdl<Length(ENC_struct)) then Thread_End(ENC_struct[hdl].ThreadCtrl,100);
  end;
end;

procedure ENC_DetWheelFreq(var CNTInfo:ENC_CNT_struct_t; steps:longint); // !!!TODO!!!
var ms,dsteps:longint; 
begin
  with CNTInfo do
  begin  
	fcnt:=fcnt+abs(steps); dsteps:=fcnt-fcntold;
  	if (dsteps>0) and TimeElapsed(fSyncTime,fdet_ms) then 
	begin
	  ms:=MilliSecondsBetween(now,fSyncTime); 
	  if (ms>0) then 
	  begin
		encFreq:=(dsteps*1000/ms); fcntold:=fcnt;
	  end;    
    end;
  end; // with
end;

function  ENC_Device(ptr:pointer):ptrint;
(* seq	B	A	  AxorB		  delta	meaning	
	0	0	0		0			0	no change
	1	0	1		1			1	1 step clockwise
	2	1	1		0			2	2 steps clockwise or counter-clockwise (fault condition)
	3	1	0		1			3	1 step counter clockwise *)
const SwitchDebounceTime_ms=25;	// Switch has to be pressed for a minimum time to be recognized
	  SwitchRepeatTime_ms=1000;	// inc count every xx ms (repeat rate)
var   hdl:longint; regval,cyclesold:longword; dt:TDateTime; sw_change:boolean;
begin 
  hdl:=longint(ptr); 
  if (hdl>=0) and (hdl<Length(ENC_struct)) then
  begin
    with ENC_struct[hdl] do
    begin
	  Thread_SetName(desc);  
	  ThreadCtrl.ThreadRunning:=true; ThreadCtrl.TermThread:=false;
//    writeln('ThreadStart ',TermThread,' ',sleeptime_ms); 
	  InitCriticalSection(ENC_CS); dt:=now; SyncTime:=now;
      repeat
        sw_change:=false; cyclesold:=cycles;
		regval:=mmap_arr^[A_Sig.regget];
		if (((regval and A_Sig.mask_1Bit) xor A_Sig.mask_pol)>0) then a:=1 else a:=0;
		if A_Sig.regget<>B_Sig.regget then regval:=mmap_arr^[B_Sig.regget];
	    if (((regval and B_Sig.mask_1Bit) xor B_Sig.mask_pol)>0) then b:=1 else b:=0;
		seq:=(a xor b) or (b shl 1);
		if S_Sig.gpio>=0 then 
		begin 
		  if A_Sig.regget<>S_Sig.regget then regval:=(mmap_arr^[S_Sig.regget]);
		  if (((regval and S_Sig.mask_1Bit) xor S_Sig.mask_pol)=0)		
		  then SetTimeOut(dt,SwitchDebounceTime_ms) // Retrigger press time
		  else 
			if TimeElapsed(dt,SwitchRepeatTime_ms) then 
			begin
			  EnterCriticalSection(ENC_CS); 
				inc(CNTInfo.switchcounter);
			  LeaveCriticalSection(ENC_CS); 
			  sw_change:=true;
			end;
		end;
		delta:=0;	  
		if seq<>seqold then  
		begin
//		  fpc calc neg. mod wrong Ex: (−144)%5=5−(144%5)=5−(4)=1(−144)%5=5−(144%5)=5−(4)=1. 
		  if seqold>seq	then delta:=4-(abs(seq-seqold) mod 4) else delta:=(seq-seqold) mod 4;
		  if delta=3	then delta:=-1
			            else if delta=2 then if deltaold<0 then delta:=-delta;
		  EnterCriticalSection(ENC_CS); 
			ENC_DetWheelFreq(CNTInfo,delta);
			if s2minmax then
			begin
			  if (CNTInfo.counter+delta)<0 then CNTInfo.counter:=0 else inc(CNTInfo.counter,delta);
			  if CNTInfo.counter>(CNTInfo.countermax-1) then CNTInfo.counter:=CNTInfo.countermax-1;
			end
			else inc(CNTInfo.counter,delta);
			CNTInfo.counter:=CNTInfo.counter mod CNTInfo.countermax;	// 0 - countermax-1
			cycles:= 		 CNTInfo.counter div CNTInfo.steps_per_cycle;
		  LeaveCriticalSection(ENC_CS);
//        writeln('Seq:',seq,' seqold:',seqold,' delta:',delta,' deltaold:',deltaold,' b:',b,' a:',a);		  
		  deltaold:=delta; seqold:=seq;
		end; 
		if ((cycles<>cyclesold) or sw_change) and (beepgpio>=0) then GPIO_Pulse(beepgpio,1);
		delay_msec(sleeptime_ms);
	  until ThreadCtrl.TermThread;
//    writeln('ENC_Device: Thread will terminate');
	  DoneCriticalSection(ENC_CS);
	  EndThread;
	  ThreadCtrl.ThreadRunning:=false;
	end; // with
  end else LOG_Writeln(LOG_ERROR,'ENC_Device: hdl '+Num2Str(hdl,0)+' out of range');
  ENC_Device:=0;
end;

procedure ENC_InfoInit(var CNTInfo:ENC_CNT_struct_t);
begin
  with CNTInfo do
  begin
    Handle:=-1; 		ENC_activity:=false;	steps_per_cycle:=4;
    encsteps:=0;		swsteps:=0;					
    counter:=0;			counterold:=0; 			countermax:=$ffff;			
    switchcounter:=0;	switchcounterold:=0;	switchcountermax:=$ffff;	
    enc:=0; 			encold:=0;   
    fSyncTime:=now;		fdet_ms:=1000; 			encFreq:=0;  // turn freq of wheel   
    fcnt:=0; 			fcntold:=0;
  end; // with
end;

function  ENC_Setup(hdl:integer; stick2minmax:boolean; 
					ctrpreset,ctrmax,stepspercycle:longword; beepergpio:integer):boolean;
//in: 	hdl:			1..ENC_cnt
//		A/B_Sig:		2 GPIOs, which should be used for the Encoder A,B Signal
//      S_Sig:			GPIO, which handles SwitchButton of Encoder. e.g. the KY-040 encoder has a switch. 
//		stick2minmax: 	true,  if we don't want an immediate counter transition from <ctrmax> to 0 or from 0 to <ctrmax>  
//		ctrpreset:		set an initial counter value. multiple of stepspercycle
//		ctrmax:			counter is always between 0 and <ctrmax>
//		stepspercycle:	an regular encoder generates 4 steps per cycle (resolution).
//out:					true, if we could allocate the HW-Pins (success)
var _ok:boolean;
begin
  _ok:=false;
  if (hdl>=0) and (hdl<Length(ENC_struct)) then
  begin
    with ENC_struct[hdl] do
    begin 
	  ok:=(GPIO_Setup(A_Sig) and GPIO_Setup(B_Sig));
	  if S_Sig.gpio>=0 then ok:=ok and GPIO_Setup(S_Sig);
      if ok then 
      begin	// Pins are available
        ENC_InfoInit(CNTInfo);  CNTInfo.Handle:=hdl; 
		s2minmax:=stick2minmax; sleeptime_ms:=ENC_SyncTime_c; 
	    seqold:=2; deltaold:=0; 
		if stepspercycle>0 then CNTInfo.steps_per_cycle:=stepspercycle;
		cycles:=round(ctrpreset/CNTInfo.steps_per_cycle);
		idxcounter:=0; beepgpio:=beepergpio; 
		if ((beepgpio>=0) and 
		   (GPIO_MAP_GPIO_NUM_2_HDR_PIN(beepgpio)>=0)) then GPIO_set_output(beepgpio);
		with CNTInfo do
		begin
		  ENC_activity:=false;
		  counter:=(cycles*steps_per_cycle); 
		  counterold:=counter; countermax:=counter+1;
		  if ctrmax>counter then countermax:=ctrmax+1; // wg. counter mod countermax
		end; // with
//		ThreadCtrl.ThreadID:=BeginThread(@ENC_Device,pointer(hdl)); // Start Encoder Thread
		Thread_Start(ThreadCtrl,@ENC_Device,pointer(hdl),0,-1); // Start Encoder Thread
      end
	  else LOG_Writeln(LOG_ERROR,'ENC_RotEncInit: Checked Pins not ok');
      _ok:=ok;	  
    end; // with
  end
  else 
  if (hdl>ENC_cnt) then LOG_Writeln(LOG_ERROR,'ENC_RotEncInit: increase ENC_Cnt:'+Num2Str(ENC_cnt,0)+' hdl:'+Num2Str(hdl,0));
  ENC_Setup:=_ok;
end;

function  ENC_GetHdl(descr:string):byte;
var devnum:longint;
begin
  SetLength(ENC_struct,Length(ENC_struct)+1);
  devnum:=Length(ENC_struct)-1; 
  SAY(LOG_DEBUG,'ENC_GetHdl devnum:'+Num2Str(devnum,0));
  with ENC_struct[devnum] do
  begin
    desc:=descr;
    ENC_InfoInit(CNTInfo);
	CNTInfo.Handle:=devnum;
  end;
  ENC_GetHdl:=devnum; 
end;

procedure ENC_Test;
// tested with Keyes KY-040 Rotary Encoder
// pls. be aware, that the SWitch Input has no external Pullup. Turn on internal Port-PullUP
// Switch Input has active low signal -> ReversePolarity
const StepsPerRev=4; MAXCount=1024; MAXSWCount=6; term=5;
//    Pins on Connector, where the Encoder is connected to. 
      ENC_A_HWPin=15; ENC_B_HWPin=16; ENC_S_HWPin=18; // A:GPIO22(DT) B:GPIO23(CLK) SW:GPIO24(SW)
var   ENC_hdl:byte; cnt,swcnt:word; dt:TDateTime;
begin
  ENC_hdl:=ENC_GetHdl('ENC-Test');// create a Encoder Data-structure. return is a hdl
  with ENC_struct[ENC_hdl] do
  begin
    GPIO_SetStruct(A_Sig,1,GPIO_MAP_HDR_PIN_2_GPIO_NUM(ENC_A_HWPin),'ENC A-Signal (DT)', [INPUT]);
    GPIO_SetStruct(B_Sig,2,GPIO_MAP_HDR_PIN_2_GPIO_NUM(ENC_B_HWPin),'ENC B-Signal (CLK)',[INPUT]);
    GPIO_SetStruct(S_Sig,3,GPIO_MAP_HDR_PIN_2_GPIO_NUM(ENC_S_HWPin),'ENC Switch (SW)',   [INPUT,PullUP,ReversePOLARITY]);
    if ENC_Setup(ENC_hdl,true,0,MAXCount,StepsPerRev,-1) then
    begin
      cnt:=0; swcnt:=0;
      writeln('Do some manual rotation on encoder. Prog will terminate, if Switch was pressed ',term,' times');
	  writeln('Used Pins on Connector, A-Pin:',A_SIG.HWPin,' B-Pin:',B_SIG.HWPin,' SW-Pin:',S_SIG.HWPin);
	  writeln('Used GPIOs with Signal: A on GPIO',A_SIG.gpio,', B on GPIO',B_Sig.gpio,', SW on GPIO',S_Sig.gpio);
	  writeln('MAXCount:',MAXCount,' MAXSWCount:',MAXSWCount-1);
//    InitCriticalSection(ENC_CS); 
	  SetTimeOut(dt,TestTimeOut_sec*1000);
      repeat // Main Loop
        delay_msec(500);	// wait x millisec, relevant for reporting only
	    swcnt:=round(ENC_GetSwitch(ENC_hdl));
	    writeln( 'Counter: ',round(ENC_GetVal(ENC_hdl,0)),
		  	    ' Cycles: ', round(ENC_GetVal(ENC_hdl,1)),
			    ' Switch: ',(swcnt mod MAXSWCount));  // switch cnt 0..(MAXSWCount-1)
        inc(cnt);
      until (swcnt>=term) or TimeElapsed(dt);  // end, if Encoder Switch was pressed <term> times
//    DoneCriticalSection(ENC_CS);
	  writeln('Encoder Thread will terminate');
	  ENC_End(ENC_hdl);
    end else Log_Writeln(Log_ERROR,'ENC_Test: can not init ENC datastruct');
  end; // with
  writeln('ENC Test end.');
end;

function  TRIG_GetValue(hdl:integer; var timesig_ms:longword):integer;
// out: -1:NO IN signal detected; 0:IN signal active; 
// out:  1:IN signal not active anymore, lastsignaltime in ms
var _res:integer;
begin 
  _res:=-1;
  if (hdl>=0) and (hdl<Length(TRIG_struct)) then
  begin
    with TRIG_struct[hdl] do
    begin
	  EnterCriticalSection(TRIG_CS); 
	    if flg then _res:=0;	// in signal high
	    if ((not flg) and (tim_ms>0)) then _res:=1;	// in signal down
		if _res=1 then begin timesig_ms:=tim_ms; tim_ms:=0; end;
	  LeaveCriticalSection(TRIG_CS); 
    end; // with
  end;
  TRIG_GetValue:=_res;
end;
  
function  TRIG_IN_Thread(ptr:pointer):ptrint;
var _hdl:longint; 
begin 
  _hdl:=longint(ptr);
  if (_hdl>=0) and (_hdl<Length(TRIG_struct)) then
  begin
    with TRIG_struct[_hdl] do
    begin
	  Thread_SetName(desc);  
	  ThreadCtrl.ThreadRunning:=true; ThreadCtrl.TermThread:=false;
//    writeln('ThreadStart ',TermThread,' ',sleeptime_ms); 
	  InitCriticalSection(TRIG_CS); 
	  repeat
        GPIO_Switch(TGPIO); // IN Part: Get HW-Signal and update DataStruct
		with TGPIO do
		begin
	      if ein and (not flg) then 
	      begin
		    EnterCriticalSection(TRIG_CS); 
	          SyncTime:=now; // start time 
		      tim_ms:=0;
		      flg:=true;
		    LeaveCriticalSection(TRIG_CS); 
	      end;
	      if (not ein) and flg then
	      begin
		    EnterCriticalSection(TRIG_CS); 
	          tim_ms:=MilliSecondsBetween(now,SyncTime);
	          flg:=false;
		    LeaveCriticalSection(TRIG_CS); 
	      end;
		  delay_msec(SyncTime_ms);
		end; // with
	  until ThreadCtrl.TermThread;
	  DoneCriticalSection(TRIG_CS);
	end; // with
  end;
  TRIG_IN_Thread:=0;
end;

procedure TRIG_SetValue(hdl:integer; timesig_ms:longword);
begin 
  if (hdl>=0) and (hdl<Length(TRIG_struct)) then
  begin
    with TRIG_struct[hdl] do
    begin
	  EnterCriticalSection(TRIG_CS); 
	    tim_ms:=timesig_ms; flg:=true;
	  LeaveCriticalSection(TRIG_CS); 
    end; // with
  end;
end;

function  TRIG_OUT_Thread(ptr:pointer):ptrint;
var _hdl:longint; 
begin 
  _hdl:=longint(ptr);
  if (_hdl>=0) and (_hdl<Length(TRIG_struct)) then
  begin
    with TRIG_struct[_hdl] do
    begin
	  Thread_SetName(desc);  
	  ThreadCtrl.ThreadRunning:=true; ThreadCtrl.TermThread:=false;
//    writeln('ThreadStart ',TermThread,' ',sleeptime_ms); 
	  InitCriticalSection(TRIG_CS); 
	  repeat
		with TGPIO do
		begin
		  EnterCriticalSection(TRIG_CS); 
	        if (tim_ms>0) then
		    begin
			  GPIO_set_pin(gpio,true);
			  delay_msec(tim_ms);
			  GPIO_set_pin(gpio,false);
			  tim_ms:=0;
		    end;		  
		  LeaveCriticalSection(TRIG_CS); 
		  delay_msec(SyncTime_ms);
		end; // with
	  until ThreadCtrl.TermThread;
	  DoneCriticalSection(TRIG_CS);
	end; // with
  end;
  TRIG_OUT_Thread:=0;
end;

procedure TRIG_End(hdl:integer); 
var i:integer; 
begin 
  if (hdl<0) then
  begin
    for i:= 1 to Length(TRIG_struct) do Thread_End(TRIG_struct[i-1].ThreadCtrl,100);
	SetLength(TRIG_struct,0);
  end
  else
  begin
    if (hdl>=0) and (hdl<Length(TRIG_struct)) then Thread_End(TRIG_struct[hdl].ThreadCtrl,100);
  end;
end;
 
function  TRIG_Reg(gpio:longint; descr:string; flags:s_port_flags; synctim_ms:longword):integer;
var _hdl,mode:integer;
begin
  _hdl:=-1;
  if (gpio>=0) then 
  begin
    SetLength(TRIG_struct,Length(TRIG_struct)+1); _hdl:=Length(TRIG_struct)-1; 
    with TRIG_struct[_hdl] do
    begin
      desc:=descr; tim_ms:=0; SyncTime:=now; flg:=false; SyncTime_ms:=synctim_ms; mode:=-1;
	  if (INPUT  IN flags) then mode:=0;
	  if (OUTPUT IN flags) then mode:=1;
	  if mode>=0 then GPIO_SetStruct(TGPIO,1,gpio,desc,flags);
	  case mode of
	    0: if GPIO_Setup (TGPIO)
		     then Thread_Start(ThreadCtrl,@TRIG_IN_Thread, pointer(_hdl),0,-1) 
		     else _hdl:=-1;
	    1: if GPIO_Setup (TGPIO)
		     then Thread_Start(ThreadCtrl,@TRIG_OUT_Thread,pointer(_hdl),0,-1)
		     else _hdl:=-1;
	    else _hdl:=-1;
	  end;
	  if _hdl=-1 then SetLength(TRIG_struct,Length(TRIG_struct)-1);
    end; // with
  end;
  TRIG_Reg:=_hdl;
end;  

procedure TRIG_IN_Test;
const HWPIN=12;
var hdl:integer; timesig_ms:longword;
begin
  hdl:=TRIG_Reg(GPIO_MAP_HDR_PIN_2_GPIO_NUM(HWPIN),'TrigInTest',[INPUT],TRIG_SyncTime_c);
  if (hdl>=0) then
  begin
    repeat
	  if TRIG_GetValue(hdl,timesig_ms)=1 then
	    writeln('Got a TimeSignal on HWPIN#',HWPIN,' with ',timesig_ms,' msec');
	  delay_msec(1000);	// only for report timing
	until false;
  end;
end;

procedure Show_Buffer(var data:I2C_databuf_t);
begin
  if LOG_Level<=LOG_DEBUG then LOG_Writeln(LOG_DEBUG,HexStr(data.buf)); 
end;

function rtc_func(fkt:longint; fpath:string; var dattime:TDateTime) : longint;
(* uses e.g. /dev/rtc0 *)
var rslt:integer; hdl:cint; Y,Mo,D,H,Mi,S,MS : Word;
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
                         rslt:=fpIOctl(hdl,RTC_RD_TIME, addr(rtc_time));
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
    (* not supported here, must be raw I2C access. Implementation later, maybe. *)
    rslt:=-1;
  end;
  rtc_func:=rslt;
end;

{$IFDEF UNIX}
function  MapUSB(devpath:string):string; // e.g. MapUSB('/dev/ttyUSB0') -> /dev/bus/usb/002/004
var dpath:string; 
begin
  dpath:='echo /dev/bus/usb/`udevadm info --name='+devpath+' --attribute-walk ';
  dpath:=dpath+'| sed -n ''s/\s*ATTRS{\(\(devnum\)\|\(busnum\)\)}==\"\([^\"]\+\)\"/\4/p'' ';
  dpath:=dpath+'| head -n 2 | awk ''{$1 = sprintf("%03d", $1); print}''` ';
  dpath:=dpath+'| tr " " "/"';
//writeln('MapUSB:',dpath);
//echo /dev/bus/usb/`udevadm info --name=/dev/ttyUSB0 --attribute-walk | sed -n 's/\s*ATTRS{\(\(devnum\)\|\(busnum\)\)}==\"\([^\"]\+\)\"/\4/p' | head -n 2 | awk '{$1 = sprintf("%03d", $1); print}'` | tr " " "/"
  call_external_prog(LOG_NONE,dpath,dpath); dpath:=RM_CRLF(dpath);
  if (dpath='')  or   (upper(dpath)='/DEV/BUS/USB/') then dpath:='';
  if (dpath<>'') then if not FileExists(dpath) then dpath:='';
  MapUSB:=dpath;
end;

function  USB_Reset(buspath:string):integer; // call e.g. USB_Reset('/dev/bus/usb/002/004');
var rc,fd,i:integer; devpath:string;
begin
  rc:=-1; 
//writeln('buspath:',buspath,' ',USBDEVFS_RESET);
  if (buspath<>'') then
  begin
    for i:=1 to Anz_Item(buspath,',','') do
	begin
	  devpath:=Select_Item(buspath,',','',i);
      if (devpath='') or (not FileExists(devpath)) then
      begin
        LOG_Writeln(LOG_ERROR,'USB_Reset: no valid device path '+devpath);
      end
      else
      begin
	    fd := fpopen(devpath, O_WRONLY);
	    if (fd < 0) then
	    begin
          LOG_Writeln(LOG_ERROR,'USB_Reset: Error opening device '+devpath);
	    end
	    else
	    begin
          LOG_Writeln(LOG_DEBUG,'USB_Reset: Resetting USB device '+devpath);
	      rc := fpioctl(fd, USBDEVFS_RESET, nil);
	      if (rc < 0) then begin LOG_Writeln(LOG_ERROR,'USB_Reset: Error in ioctl '+Num2Str(rc,0)+' '+devpath);    end
	                  else begin LOG_Writeln(LOG_DEBUG,'USB_Reset: successful '+Num2Str(rc,0)+' '+devpath); rc:=0; end;
	      fpclose(fd);
	      if rc=0 then sleep(2000);
        end;
      end;
    end;
  end;
  USB_Reset:=rc;
end;
{$ELSE}
function  MapUSB(devpath:string):string;     begin MapUSB:='';    end;
function  USB_Reset(buspath:string):integer; begin USB_Reset:=-1; end;
{$ENDIF}

procedure I2C_Show_struct(busnum:byte);
begin
  with I2C_buf[busnum] do
  begin
    Log_Writeln(LOG_DEBUG,'I2C Struct[0x'+Hex(busnum,2)+']:');
	Log_Writeln(LOG_DEBUG,' .hdl: '+Num2Str(hdl,0));
	Log_Write  (LOG_DEBUG,' .buf: 0x'+HexStr(buf)); 
  end;  
end;

procedure I2C_Display_struct(busnum:byte; comment:string);
begin
  LOG_Save_Level; 
  LOG_Set_LEVEL(LOG_DEBUG); 
  Log_Write(LOG_Get_Level,comment); 
  I2C_show_struct(busnum); 
  LOG_Restore_Level;
end;

function  I2C_ChkBusAdr(busnum,baseadr:word):boolean; 
var _ok:boolean;
begin 
  _ok:=((busnum<=I2C_max_bus) and (baseadr>=$03) and (baseadr<=$77));
  if not _ok then 
    LOG_Writeln(LOG_ERROR,'I2C_ChkBusAdr['+Hex(busnum,2)+'/0x'+Hex(baseadr,2)+']: not valid');
  I2C_ChkBusAdr:=_ok; 
end; 

procedure I2C_CleanBuffer(busnum:byte);
begin with I2C_buf[busnum] do begin hdl:=-1; buf:=''; end; end;

procedure I2C_Start(busnum:integer);
var _I2C_path:string;
begin
  _I2C_path:='';
  with I2C_buf[busnum] do
  begin
    I2C_CleanBuffer(busnum);
    {$IFDEF UNIX}
      if RPI_run_on_ARM then 
      begin 
	    _I2C_path:=I2C_path_c+Num2Str(busnum,0);
	    if (_I2C_path<>'') and FileExists(_I2C_path) then hdl:=fpOpen(_I2C_path,O_RdWr);
      end;
    {$ENDIF}
    if (hdl<0) and (busnum=RPI_I2C_busgen) then 
      LOG_Writeln(LOG_ERROR,'I2C_start[0x'+hex(busnum,2)+']: '+_I2C_path);
  end;
end;

procedure I2C_Start; var b:byte; begin for b:=0 to I2C_max_bus do I2C_Start(b); end;

procedure I2C_End(busnum:integer);
begin
  {$IFDEF UNIX}
    if RPI_run_on_ARM then   
      if I2C_buf[busnum].hdl>=0 then fpClose(I2C_buf[busnum].hdl);
  {$ENDIF}
  I2C_buf[busnum].hdl:=-1;
end;

procedure I2C_Close_All; var b:byte; begin for b:=0 to I2C_max_bus do I2C_End(b); end;

function  I2C_bus_read(busnum,baseadr,basereg:word; len:byte; errhdl:integer):integer;
var rslt:integer; reg,lgt:byte; test:boolean;
begin
  rslt:=-1; 
  with I2C_buf[busnum] do
  begin
    if (hdl>=0) then
    begin
      test:=false; lgt:=len;
//writeln('I2C_bus_read[0x'+hex(busnum,2)+'/0x'+hex(baseadr,2)+'/0x'+hex(basereg,4)+']: ',hex(basereg,4),' ',hex(I2C_UseNoReg,4));
      if lgt>SizeOf(buf) then 
      begin
        LOG_Writeln(LOG_ERROR,'I2C_bus_read[0x'+hex(busnum,2)+'/0x'+hex(baseadr,2)+'/0x'+hex(basereg,2)+']: Length exceed buflgt, got: '+Num2Str(len,0)+' max: '+Num2Str(SizeOf(buf),0));
        lgt:=SizeOf(buf);
      end;
      {$IFDEF UNIX}
//      if hdl<0 then I2C_start(data);
	    {$warnings off}
//		  rslt:=0;
//        rslt:=fpIOctl(hdl,I2C_TIMEOUT,pointer(1)); if rslt<0 then exit(rslt); 
//        rslt:=fpIOctl(hdl,I2C_RETRIES,pointer(2)); if rslt<0 then exit(rslt);
          rslt:=fpIOctl(hdl,I2C_SLAVE,  pointer(baseadr));
	    {$warnings on}
        if rslt<0 then
        begin
          LOG_Writeln(LOG_ERROR,'I2C_bus_read[0x'+hex(busnum,2)+'/0x'+hex(baseadr,2)+'/0x'+hex(basereg,2)+']: failed to select device, errnum: '+Num2Str(rslt,0));
          ERR_MGMT_UPD(errhdl,_IOC_NONE,lgt,false);	  
	      buf:='';
		  exit(rslt);
        end;
	    if basereg<>I2C_UseNoReg then
	    begin
		  reg:=byte(basereg);
          rslt:=fpWrite (hdl,reg,1);
          if rslt<>1 then
          begin
            LOG_Writeln(LOG_ERROR,'I2C_bus_read[0x'+hex(busnum,2)+'/0x'+hex(baseadr,2)+'/0x'+hex(basereg,2)+']: failed to write Register, errnum: '+Num2Str(rslt,0));
            ERR_MGMT_UPD(errhdl,_IOC_WRITE,lgt,false);
		    buf:='';
			exit(rslt);
          end;
	    end;
		SetLength(buf,1);
        rslt:=fpRead(hdl,buf[1],lgt);
      {$ENDIF}
      if test then I2C_Display_struct(busnum,'I2C_bus_read:');
      if rslt<0 then
      begin
        LOG_Writeln(LOG_ERROR,'I2C_bus_read[0x'+hex(busnum,2)+'/0x'+hex(baseadr,2)+'/0x'+hex(basereg,2)+']: failed to read device, errnum: '+Num2Str(rslt,0));
        ERR_MGMT_UPD(errhdl,_IOC_READ,lgt,false);
		buf:='';
      end
      else
      begin
	    SetLength(buf,rslt);
		ERR_MGMT_UPD(errhdl,_IOC_READ,rslt,true);
        if rslt<lgt then
	      LOG_Writeln(LOG_ERROR,'I2C_bus_read[0x'+hex(busnum,2)+'/0x'+hex(baseadr,2)+'/0x'+hex(basereg,2)+']: Short read, errnum: '+Num2Str(rslt,0)+' expected length: '+Num2Str(lgt,0)+' got: '+Num2Str(rslt,0));
      end;  
    end;
  end; // with
  I2C_bus_read:=rslt;
end;

function  xI2C_bus_read(busnum,baseadr,basereg:word; len:byte; errhdl:integer):integer;
// not ready
var rslt:integer; reg,lgt,idx:byte; 
    msgset:I2C_rdwr_ioctl_data_t; iomsgs:array[0..1] of I2C_msg_t;
begin
  rslt:=-1; 
  with I2C_buf[busnum] do
  begin
    if (hdl>=0) then
    begin
      lgt:=len; idx:=0;
//writeln('I2C_bus_read[0x'+hex(busnum,2)+'/0x'+hex(baseadr,2)+'/0x'+hex(basereg,4)+']: ',hex(basereg,4),' ',hex(I2C_UseNoReg,4));
      if lgt>SizeOf(buf) then 
      begin
        LOG_Writeln(LOG_ERROR,'I2C_bus_read[0x'+hex(busnum,2)+'/0x'+hex(baseadr,2)+'/0x'+hex(basereg,2)+']: Length exceed buflgt, got: '+Num2Str(len,0)+' max: '+Num2Str(SizeOf(buf),0));
        lgt:=SizeOf(buf);
      end;
      {$IFDEF UNIX}
	    if basereg<>I2C_UseNoReg then
	    begin
		  reg:=byte(basereg);
		  iomsgs[idx].addr:=  baseadr;
		  iomsgs[idx].bptr:=  @reg;
		  iomsgs[idx].len:=   1;
		  iomsgs[idx].flags:= I2C_M_WR;
		  inc(idx);
	    end;
		iomsgs[idx].addr:=    baseadr;
		iomsgs[idx].bptr:=	  @buf[1];
		iomsgs[idx].len:=     lgt;
		iomsgs[idx].flags:=   I2C_M_RD;

		msgset.nmsgs:=idx+1;
		msgset.msgs :=@iomsgs;

        rslt:=fpIOCTL(hdl,I2C_RDWR,@msgset);
      {$ENDIF}
      if rslt<0 then
      begin
        LOG_Writeln(LOG_ERROR,'I2C_bus_read[0x'+hex(busnum,2)+'/0x'+hex(baseadr,2)+'/0x'+hex(basereg,2)+']: failed to read device, errnum: '+Num2Str(rslt,0));
        ERR_MGMT_UPD(errhdl,_IOC_READ,lgt,false);
		buf:='';
      end
      else
      begin
	    SetLength(buf,lgt); rslt:=lgt;
		ERR_MGMT_UPD(errhdl,_IOC_READ,lgt,true);
      end;  
    end;
  end; // with
  xI2C_bus_read:=rslt;
end;

function I2C_string_read(busnum,baseadr,basereg:word; len:byte; errhdl:integer; var outs:string):integer; 
var rslt:integer; lgt:byte;
begin   
  with I2C_buf[busnum] do
  begin
    lgt:=len; 
    if len>c_max_Buffer then 
    begin
      LOG_Writeln(LOG_ERROR,'I2C_string_read[0x'+hex(busnum,2)+'/0x'+hex(baseadr,2)+'/0x'+hex(basereg,2)+']: Length exceed buflgt, got: '+Num2Str(len,0)+' max: '+Num2Str(c_max_Buffer,0));
      buf:='';
	  exit(-1);
	  lgt:=c_max_Buffer;
    end;
//  writeln('I2C_string_read1: I2Caddr:0x'+Hex(baseadr,2)+' reg:0x'+Hex(basereg,2)+' busnum:0x'+Hex(busnum,2)+' lgt:0x'+Hex(lgt,2));
    rslt:=I2C_bus_read(busnum,baseadr,basereg,lgt,errhdl); 
//  writeln('I2C_string_read2: I2Caddr:0x'+Hex(baseadr,2)+' reg:0x'+Hex(basereg,2)+' busnum:0x'+Hex(busnum,2)+' lgt:0x'+Hex(lgt,2)+' rslt:'+Num2Str(rslt,0));  
	outs:=buf;
	I2C_string_read:=rslt;
  end; // with
end;

function  I2C_word_read(busnum,baseadr,basereg:word; flip:boolean; errhdl:integer):word; 
// read from the I2C general purpose bus e.g. s:=I2C_string_read($68,$00,7)
var sh:string; w:word;
begin
  w:=0; I2C_string_read(busnum,baseadr,basereg,2,errhdl,sh);
  if Length(sh)>=2 then
  begin
    if flip then w:=word(ord(sh[2]) shl 8) or word(ord(sh[1]))
			else w:=word(ord(sh[1]) shl 8) or word(ord(sh[2]));
  end;
  I2C_word_read:=w;
end;

function  I2C_bus_write(busnum,baseadr:word; errhdl:integer):integer;
var rslt:integer; lgt:byte;
begin
  rslt:=-1; 
  with I2C_buf[busnum] do
  begin
    if (hdl>=0) then
    begin
      lgt:=Length(buf);	
      {$IFDEF UNIX}
//      writeln('i2cwr: 0x'+HexStr(buf)+' ',hdl); 
        {$warnings off} rslt:=fpIOctl(hdl,I2C_SLAVE,pointer(baseadr)); {$warnings on}
        if rslt<0 then
        begin
          LOG_Writeln(LOG_ERROR,'I2C_bus_write[0x'+hex(busnum,2)+'/0x'+hex(baseadr,2)+']: failed to open device, errnum: '+Num2Str(rslt,0));
          ERR_MGMT_UPD(errhdl,_IOC_NONE,lgt,false);
	      exit(rslt);
        end;
	    rslt:=fpWrite(hdl,buf[1],lgt);
      {$ENDIF}
//    I2C_Display_struct(busnum,'I2C_bus_write:');
      if rslt<0 then
      begin
        LOG_Writeln(LOG_ERROR,'I2C_bus_write[0x'+hex(busnum,2)+'/0x'+hex(baseadr,2)+']: failed to write to device, errnum: '+Num2Str(rslt,0));
        ERR_MGMT_UPD(errhdl,_IOC_WRITE,lgt,false);
      end
      else
      begin
	    ERR_MGMT_UPD(errhdl,_IOC_WRITE,lgt,true);
        if (rslt<lgt) then
	      LOG_Writeln(LOG_ERROR,'I2C_bus_write[0x'+hex(busnum,2)+'/0x'+hex(baseadr,2)+']: short write, errnum: '+Num2Str(rslt,0)+' expected: '+Num2Str(lgt+1,0)+' got: '+Num2Str(rslt,0));
      end;
    end;
  end; // with
  I2C_bus_write:=rslt;
end;

function  I2C_string_write(busnum,baseadr,basereg:word; datas:string; errhdl:integer):integer; 
begin   
  if length(datas)>=c_max_Buffer then 
  begin
    LOG_Writeln(LOG_ERROR,'I2C_string_write['+Hex(busnum,2)+'/'+Hex(baseadr,2)+'/'+Hex(basereg,2)+']: data length:'+Num2Str(length(datas),0)+' exceeds buffer size:'+Num2Str(c_max_Buffer,0));
	exit(-1);
  end;	 
  if basereg<>I2C_UseNoReg	then I2C_buf[busnum].buf:=char(byte(basereg))+datas
							else I2C_buf[busnum].buf:=datas; 
  I2C_string_write:=I2C_bus_write(busnum,baseadr,errhdl); 
end;

function  I2C_word_write(busnum,baseadr,basereg:word; data:word; flip:boolean; errhdl:integer):integer; 
var sh:string;
begin
  if flip 	then sh:=char(byte(data))+char(byte(data shr 8))
			else sh:=char(byte(data shr 8))+char(byte(data));
  I2C_word_write:=I2C_string_write(busnum,baseadr,basereg,sh,errhdl);
end;

function  I2C_word_write(baseadr,basereg:word; data:word; flip:boolean; errhdl:integer):integer;
begin I2C_word_write:=I2C_word_write(RPI_I2C_busgen,baseadr,basereg,data,flip,errhdl); end;

function  I2C_byte_write(busnum,baseadr,basereg:word; data:byte; errhdl:integer):integer; 
begin	 
  if basereg<>I2C_UseNoReg	then I2C_buf[busnum].buf:=char(byte(basereg))+char(data)
							else I2C_buf[busnum].buf:=char(data); 
  I2C_byte_write:=I2C_bus_write(busnum,baseadr,errhdl); 
end;

procedure HW_SetInfoStruct(var DeviceStruct:HW_DevicePresent_t; DevTyp:t_IOBusType; BusNr,HWAdr:integer; dsc:string);
begin with DeviceStruct do begin BusNum:=BusNr; HWAddr:=HWAdr; DevType:=DevTyp; descr:=dsc; end; end;

procedure HW_IniInfoStruct(var DeviceStruct:HW_DevicePresent_t);
begin
  HW_SetInfoStruct(DeviceStruct,UnknDev,hdl_unvalid,hdl_unvalid,'');
  with DeviceStruct do begin present:=false; Hndl:=hdl_unvalid; data:=''; end;
end;
(*An unhandled exception occurred at $00065F64 :
ERangeError : Range check error
$00065F64  HW_SETINFOSTRUCT,  line 5728 of /data/home/sfischer/projects/pas/rpi/rpi_hal.pas
$00065FE8  HW_INIINFOSTRUCT,  line 5732 of /data/home/sfischer/projects/pas/rpi/rpi_hal.pas
*)
function  SPI_HWT(var DeviceStruct:HW_DevicePresent_t; bus,adr,reg,lgt:word; nv1,nv2,dsc:string):boolean;
begin
  with DeviceStruct do
  begin
    HW_IniInfoStruct(DeviceStruct);
    HW_SetInfoStruct(DeviceStruct,SPIDev,0,hdl_unvalid,dsc);
    present:=true;		// Dummy, to do !!!!!!!!! read device to determine if it's there
    
    if present  then begin BusNum:=bus; HWaddr:=adr; end;
    SPI_HWT:=present;
  end;
end;

function  I2C_HWT(var DeviceStruct:HW_DevicePresent_t; bus,adr,reg,lgt:word; nv1,nv2,dsc:string):boolean;
// I2C HardwareTest. used to determine, device available on i2c bus
// usage e.g. DisplayPresent:=I2C_HWT(RPI_I2C_busnum,LCD_I2C_ADR,$01,1,'','','LCD');
var info:string; 
begin
  with DeviceStruct do
  begin
    HW_IniInfoStruct(DeviceStruct); data:=''; present:=false;
    HW_SetInfoStruct(DeviceStruct,I2CDev,rpi_I2C_busgen,i2c_unvalid_addr,dsc);
    info:=dsc+'[0x'+Hex(bus,2)+'/0x'+Hex(adr,2)+'/0x'+Hex(reg,2)+']';
//  writeln('info:',info);
    if I2C_ChkBusAdr(bus,adr) then
    begin
      i2c_string_read(bus,adr,reg,lgt,NO_ERRHNDL,data); 
      present:=(data<>'');     
      if present 			   then present:=present and (Length(data)=lgt);
      if present and (nv1<>'') then present:=present and (HexStr(data)<>nv1); 
      if present and (nv2<>'') then present:=present and (HexStr(data)<>nv2); 
      if present then info:='SUCCESS: '+info 
				 else info:='WARNING: '+info+': could not be accessed!';
      if data<>''	then info:=info+': 0x'+HexStr(data) else info:=info+': <nodata>';
      if present  then SAY(LOG_INFO,info) else SAY(LOG_WARNING,info);
      if present  then begin BusNum:=bus; HWaddr:=adr; end;
    end;
    I2C_HWT:=present;
  end; // with
end;

procedure I2C_test;
{V1.0 30-JUL-2013
test on cli, is I2C bus working and determine baseaddr of device. 
Newer version of rpi, I2C bus nr 1. older rpi I2Cbus nr 0.
root@rpi# I2Cdetect -y 0
root@rpi# I2Cdetect -y 1        
     0  1  2  3  4  5  6  7  8  9  a  b  c  d  e  f
00:          -- -- -- -- -- -- -- -- -- -- -- -- --
..
60: -- -- -- -- -- -- -- -- 68 -- -- -- -- -- -- --
70: -- -- -- -- -- -- -- --
on 0x68, this is my RTC DS3232m }
  procedure showstr(s:string); begin if s<>'' then writeln(hexstr(s)) else writeln('device is not responding'); end;
const testnr=1;
var s:string;
  procedure test1_rtc;
  begin
    I2C_string_read(RPI_I2C_busgen,$68,$05,2,NO_ERRHNDL,s); showstr(s); // read 2 bytes; I2C device addr = 0x68; StartRegister = 0x05; result: content of reg[5..6] in string s
    I2C_string_write(RPI_I2C_busgen,$68,$05,#$08+#$12,NO_ERRHNDL); // write 08 in reg 0x05 and 12 in reg 0x06 // set month register to 08 and year to 12
    I2C_string_read(RPI_I2C_busgen,$68,$05,2,NO_ERRHNDL,s); showstr(s); // read 2 bytes
    I2C_string_write(RPI_I2C_busgen,$68,$05,#$07+#$13,NO_ERRHNDL); // write 07 in reg 0x05 and 13 in reg 0x06 // restore month and year
    LOG_Level:=LOG_debug; 
	I2C_show_struct(RPI_I2C_busgen); 
	LOG_Level:=LOG_WARNING;
  end;
  procedure test2_mma7660;
  // chip: accelerometer
  begin
    I2C_string_write  (RPI_I2C_busgen,$4c,$07,#$00,NO_ERRHNDL); 			// write 00 in reg 0x07 
	I2C_string_write  (RPI_I2C_busgen,$4c,$07,#$04,NO_ERRHNDL); 			// write 04 in reg 0x07 
	I2C_string_write  (RPI_I2C_busgen,$4c,$00,#$04,NO_ERRHNDL);
    I2C_string_write  (RPI_I2C_busgen,$4c,$01,#$03,NO_ERRHNDL);
    I2C_string_write  (RPI_I2C_busgen,$4c,$02,#$02,NO_ERRHNDL);	
//  I2C_string_read(RPI_I2C_busgen,$4c,$07,1,NO_ERRHNDL,s); showstr(s); // read 1 byte; I2C device addr=0x4c; Register=0x07; MOdeRegister
	I2C_string_read(RPI_I2C_busgen,$4c,$00,1,NO_ERRHNDL,s); showstr(s); // read 1 byte; I2C device addr=0x4c; Register=0x00; XOUT  
	I2C_string_read(RPI_I2C_busgen,$4c,$01,1,NO_ERRHNDL,s); showstr(s); // read 1 byte; I2C device addr=0x4c; Register=0x01; YOUT  
	I2C_string_read(RPI_I2C_busgen,$4c,$02,1,NO_ERRHNDL,s); showstr(s); // read 1 byte; I2C device addr=0x4c; Register=0x02; ZOUT  
	LOG_Level:=LOG_debug; 
	I2C_show_struct(RPI_I2C_busgen); 
	LOG_Level:=LOG_WARNING; 
  end;
begin
  case testnr of
    1 : test1_rtc;
	2 : test2_mma7660;
  end; // case
end;

procedure SPI_show_struct(var spi_strct:spi_ioc_transfer_t);
const errlvl=LOG_WARNING;
begin
  with spi_strct do
  begin
    Log_Writeln(errlvl,'SPI Struct:    0x'+Hex(longword(addr(spi_strct)),8)+' struct size: 0x'+Hex(sizeof(spi_strct),4));
    Log_Writeln(errlvl,' .tx_buf_ptr:  0x'+Hex(tx_buf_ptr,8));
    Log_Writeln(errlvl,' .rx_buf_ptr:  0x'+Hex(rx_buf_ptr,8));
    Log_Writeln(errlvl,' .len:           '+Num2Str(len,0));
    Log_Writeln(errlvl,' .speed_hz:      '+Num2Str(speed_hz,0));
    Log_Writeln(errlvl,' .delay_usecs:   '+Num2Str(delay_usecs,0));
    Log_Writeln(errlvl,' .bits_per_word: '+Num2Str(bits_per_word,0));
	Log_Writeln(errlvl,' .cs_change:     '+Num2Str(cs_change,0));
  end;  
end;

procedure SPI_show_bus_info_struct(busnum:byte);
const errlvl=LOG_WARNING;
begin
  with spi_bus[busnum] do
  begin
    Log_Writeln(errlvl,'SPI Bus Info['+Num2Str(busnum,0)+']:');
	Log_Writeln(errlvl,' .spi_speed:    '+Num2Str(busnum,0));
  end;
end;

procedure SPI_show_dev_info_struct(busnum,devnum:byte);
const errlvl=LOG_WARNING;
begin
  if (busnum<=spi_max_bus) and (devnum<=spi_max_dev) then
  begin
    with spi_dev[busnum,devnum] do
    begin
      Log_Writeln(errlvl,'SPI Dev Info['+Num2Str(busnum,0)+'/'+Num2Str(devnum,0)+']:');
      Log_Writeln(errlvl,' .spi_path:      '+spi_path);
	  Log_Writeln(errlvl,' .spi_open:      '+Bool2Str(spi_fd>=0));
	  Log_Writeln(errlvl,' .spi_bpw:       '+Num2Str(spi_bpw,0));
      Log_Writeln(errlvl,' .spi_delay:     '+Num2Str(spi_delay,0));
      Log_Writeln(errlvl,' .spi_speed:     '+Num2Str(spi_speed,0));
	  Log_Writeln(errlvl,' .spi_cs_change: '+Num2Str(spi_cs_change,0));
      Log_Writeln(errlvl,' .spi_LSB_FIRST: '+Num2Str(spi_LSB_FIRST,0));
      Log_Writeln(errlvl,' .spi_mode:      '+Num2Str(spi_mode,0));
      Log_Writeln(errlvl,' .spi_IOC_mode:0x'+Hex(spi_IOC_mode,8));
 //   Log_Writeln(errlvl,' .dev_GPIO_int:  '+Num2Str(dev_GPIO_int,0));
      Log_Writeln(errlvl,' .dev_GPIO_en:   '+Num2Str(dev_GPIO_en,0));
	  Log_Writeln(errlvl,' .dev_GPIO_ook:  '+Num2Str(dev_GPIO_ook,0));
   end; // with
 end else Log_Writeln(Log_ERROR,'SPI_show_dev_info_struct: busnum/devnum out of range');
end; 

procedure SPI_show_buffer(busnum,devnum:byte);
const errlvl=LOG_WARNING; maxshowbuf=35;
var i,eidx:longint; sh:string;
begin
  with spi_buf[busnum,devnum] do
  begin
    eidx:=endidx; if eidx>maxshowbuf then eidx:=maxshowbuf; // just show the beginning of the buffer
    Log_Writeln(errlvl,'SPI Buffer['+Num2Str(busnum,0)+'/'+Num2Str(devnum,0)+']:');
    Log_Writeln(errlvl,' .reg:         0x'+Hex(reg,4));
    if posidx<=eidx then
    begin
	  sh:=' .buf['+Num2Str(posidx,2)+'..'+Num2Str(eidx,2)+']:  0x';
      for i:= posidx to (eidx+1) do sh:=sh+Hex(ord(buf[i]),2); sh:=sh+' ... ';                                                              
      for i:= posidx to (eidx+1) do sh:=sh+StringPrintable(buf[i]);
      Log_Writeln(errlvl,sh);
    end
    else
    begin
      Log_Writeln(errlvl,' .buf:           <empty>');
    end;
    Log_Writeln(errlvl,' .posidx:        '+Num2Str(posidx,0));
    Log_Writeln(errlvl,' .endidx:        '+Num2Str(endidx,0));
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
 
function  _IO  (typ:char; nr:word):longword;      begin _IO  :=_IOC(_IOC_NONE,                typ,nr,0);         end;
function  _IOR (typ:char; nr,size:word):longword; begin _IOR :=_IOC(_IOC_Read,                typ,nr,size);      end;
function  _IOW (typ:char; nr,size:word):longword; begin _IOW :=_IOC(_IOC_Write,               typ,nr,size);      end;
function  _IOWR(typ:char; nr,size:word):longword; begin _IOWR:=_IOC((_IOC_Write or _IOC_Read),typ,nr,size);      end;

function SPI_ClockDivider(spi_hz:real):word;
var cdiv:word; lw:longword;
begin
  if (spi_hz<(CLK_GetFreq(5)/2)) then
  begin
    cdiv:=0;
	if (spi_hz>0) then
    begin // CDIV must be a power of two
      lw:=RoundUpPow2(DivRoundUp(CLK_GetFreq(5),spi_hz));
	  if (lw<=$ffff) then cdiv:=word(lw) else cdiv:=0 // 0 is the slowest we can go
    end;
  end
  else cdiv:=2; // CLK_GetFreq(5)/2 is the fastest we can go
  SPI_ClockDivider:=cdiv;
end;

procedure SPI_ClkWrite(spi_hz:real);
var cdiv:word;
begin
  if not SPI_ClkWritten then
  begin
    cdiv:=SPI_ClockDivider(spi_hz);
    LOG_Writeln(LOG_INFO,'SPI_ClkWrite: '+Num2Str((CLK_GetFreq(5)/cdiv),0,0)+'Hz cdiv:0x'+Hex(CDIV,4));
    BCM_SETREG(SPI0_CLK,cdiv,false,false);
  end;
  SPI_ClkWritten:=true;
end;

function SPI_MSGSIZE(n:byte):word; 
var siz:word;
begin 
  if n*SizeOf(spi_ioc_transfer_t)<(1 shl _IOC_SIZEBITS) then 
    siz:=n*SizeOf(spi_ioc_transfer_t) else siz:=0;
  SPI_MSGSIZE:=siz;
end;

function  SPI_IOC_MESSAGE(n:byte):longword; 
begin SPI_IOC_MESSAGE:=_IOW(SPI_IOC_MAGIC,0,SPI_MSGSIZE(n)); end;

function  SPI_Mode(spifd:cint; mode:longword; pvalue:pointer):integer;
var rslt:integer;
begin
  rslt:=-1; {$IFDEF UNIX} if spifd>=0 then rslt:=fpioctl(spifd,mode,pvalue); {$ENDIF}   
  if rslt<0 then Log_Writeln(LOG_ERROR,'SPI_Mode Mode: 0x'+Hex(mode,8)+' spifd:'+Num2Str(spifd,0)+' err:'+Num2Str(rslt,0));
  SPI_Mode:=rslt;
end;

procedure SPI_SetDevErrHndl(busnum,devnum:byte; errhdl:integer);
begin spi_dev[busnum,devnum].errhndl:=errhdl; end;

procedure SPI_SetDevDelay(busnum,devnum:byte; delayus:word);
begin spi_dev[busnum,devnum].spi_delay:=delayus; end;

procedure SPI_SetDevSpeedHz(busnum,devnum:byte; speedHz:longword);
begin spi_dev[busnum,devnum].spi_speed:=speedHz; end;

procedure SPI_SetDevCSChange(busnum,devnum:byte; cschange:byte);
var cs:byte;
begin cs:=0; if cschange<>0 then cs:=1; spi_dev[busnum,devnum].spi_cs_change:=cs; end;

procedure SPI_Struct_Init(busnum,devnum:byte; var spi_struct:spi_ioc_transfer_t; rx_bufptr,tx_bufptr:pointer; xferlen:longword);
begin
//Log_Writeln(LOG_DEBUG,'SPI_Struct_Init');
  if (busnum<=spi_max_bus) and (devnum<=spi_max_dev) then
  begin
    with spi_dev[busnum,devnum] do
    begin
      with spi_struct do
      begin
        {$warnings off}
          rx_buf_ptr	:= qword(rx_bufptr);
          tx_buf_ptr	:= qword(tx_bufptr);
	    {$warnings on}
        delay_usecs		:= spi_delay;
        speed_hz    	:= spi_speed;
        bits_per_word	:= spi_bpw;
	    cs_change		:= spi_cs_change;	     
        pad				:= 0;
	    len				:= xferlen; 
	    if len>=SPI_BUF_SIZE_c then len:=SPI_BUF_SIZE_c-1;
      end; // with
	  with spi_buf[busnum,devnum] do
	  begin
	    reg:=0; endidx:=0; posidx:=1;
	  end; // with
    end; // with
  end else LOG_Writeln(LOG_ERROR,'SPI_Struct_Init: busnum/devnum not in range');
end;

procedure IO_Init_Const;
begin
  USBDEVFS_RESET :=			  _IO  (USB_IOC_MAGIC,20);
  SPI_IOC_RD_MODE :=          _IOR (SPI_IOC_MAGIC, 1, 1);
  SPI_IOC_WR_MODE :=          _IOW (SPI_IOC_MAGIC, 1, 1);
  SPI_IOC_RD_LSB_FIRST :=     _IOR (SPI_IOC_MAGIC, 2, 1);
  SPI_IOC_WR_LSB_FIRST :=     _IOW (SPI_IOC_MAGIC, 2, 1);
  SPI_IOC_RD_BITS_PER_WORD := _IOR (SPI_IOC_MAGIC, 3, 1);
  SPI_IOC_WR_BITS_PER_WORD := _IOW (SPI_IOC_MAGIC, 3, 1);
  SPI_IOC_RD_MAX_SPEED_HZ  := _IOR (SPI_IOC_MAGIC, 4, 4);
  SPI_IOC_WR_MAX_SPEED_HZ  := _IOW (SPI_IOC_MAGIC, 4, 4);
//RTC_RD_TIME :=			  _IOR (RTC_MAGIC,     9,@rtc_time);
//RTC_SET_TIME:=			  _IOW (RTC_MAGIC,    10,@rtc_time);
end;

function  SPI_Transfer(busnum,devnum:byte; cmdseq:string):integer;
const numxfer=1;
var rslt,xlen:integer; xfer:array[0..(numxfer-1)] of spi_ioc_transfer_t; 
begin
  rslt:=-1; xlen:=Length(cmdseq); 
  if (busnum<=spi_max_bus) and (devnum<=spi_max_dev) then
  begin
    if xlen>0 then
    begin
      if xlen>=SPI_BUF_SIZE_c then 
      begin 
        xlen:=SPI_BUF_SIZE_c; 
	    LOG_WRITELN(LOG_ERROR,'spi_transfer: transfer length to long'); 
      end;
      with spi_buf[busnum,devnum] do
      begin
        buf:=copy(cmdseq,1,xlen);
//      SPI_show_buffer(busnum,devnum);
        SPI_Struct_Init(busnum,devnum,xfer[0],addr(buf[1]),addr(buf[1]),xlen); 
//      SPI_Show_Struct(xfer[0]);
        {$IFDEF UNIX} 
          rslt:=fpioctl(spi_dev[busnum,devnum].spi_fd,SPI_IOC_MESSAGE(numxfer),addr(xfer[0])); 
        {$ENDIF}
        if rslt<0 then 
        begin
	      buf:='';
          Log_Writeln(LOG_ERROR,	
		    'SPI_transfer '+Num2Str(rslt,0)+' devnum: ' +Num2Str(devnum,0)+
		    ' spi_busnum: '+Num2Str(busnum,0)+   
		    ' spi_fd: '+Num2Str(spi_dev[busnum,devnum].spi_fd,0)+
		    ' cmdseq: '+HexStr(cmdseq));
	      ERR_MGMT_UPD(spi_dev[busnum,devnum].errhndl,_IOC_WRITE,xlen,false);
        end
        else 
	    begin
	      posidx:=1; endidx:=rslt; SetLength(buf,rslt);
	      ERR_MGMT_UPD(spi_dev[busnum,devnum].errhndl,_IOC_READ, rslt,true);
	      ERR_MGMT_UPD(spi_dev[busnum,devnum].errhndl,_IOC_WRITE,rslt,true);
	    end;
      end; // with
    end;
  end else LOG_Writeln(LOG_ERROR,'SPI_Transfer[0x'+Hex(busnum,2)+'/0x'+Hex(devnum,2)+']: invalid busnum/devnum');
  SPI_Transfer:=rslt;
end;

function  SPI_Write(busnum,devnum:byte; basereg,data:word):integer;
var rslt:integer; xfer:spi_ioc_transfer_t; buf:array[0..1] of byte;
begin
  rslt:=-1; 
Log_Writeln(LOG_WARNING,'SPI_write Reg: 0x'+Hex(basereg,4)+' Data: 0x'+Hex(data,4));
  if (busnum<=spi_max_bus) and (devnum<=spi_max_dev) then
  begin
    SPI_Struct_Init(busnum,devnum,xfer,addr(buf),addr(buf),2);
    buf[1]:=byte(data); buf[0]:=byte(basereg);
    {$IFDEF UNIX} 
      rslt:=fpioctl(spi_dev[busnum,devnum].spi_fd,SPI_IOC_MESSAGE(1),addr(xfer)); 
    {$ENDIF}
    if rslt<0 then 
    begin
      ERR_MGMT_UPD(spi_dev[busnum,devnum].errhndl,_IOC_WRITE,2,false);
     Log_Writeln(LOG_ERROR,'SPI_write '+Num2Str(rslt,0)+
                          ' devnum: ' +Num2Str(devnum,0)+
                          ' spi_busnum: '+Num2Str(busnum,0));
    end
    else
    begin
    writeln('SPI_WRITE: result',rslt);
      ERR_MGMT_UPD(spi_dev[busnum,devnum].errhndl,_IOC_WRITE,2,true);
    end;
  end else LOG_Writeln(LOG_ERROR,'SPI_Write[0x'+Hex(busnum,2)+'/0x'+Hex(devnum,2)+']: invalid busnum/devnum');
  SPI_Write:=rslt;
end;

function SPI_Read(busnum,devnum:byte; basereg:word):byte;
var b:byte; rslt:integer; xfer:array[0..1] of spi_ioc_transfer_t; xbuf:SPI_databuf_t;
begin
  rslt:=-1; b:=$ff;
  if (busnum<=spi_max_bus) and (devnum<=spi_max_dev) then
  begin
    SPI_Struct_Init(busnum,devnum,xfer[0],addr(xbuf.buf[1]),addr(xbuf.buf[1]),1);
    SPI_Struct_Init(busnum,devnum,xfer[1],addr(xbuf.buf[1]),addr(xbuf.buf[1]),1);
    for b:=1 to SPI_BUF_SIZE_c do xbuf.buf[b]:=#$00;
	xbuf.buf[1]:=char(byte(basereg)); 
    {$IFDEF UNIX} 
      rslt:=fpioctl(spi_dev[busnum,devnum].spi_fd,SPI_IOC_MESSAGE(2),addr(xfer)); 
    {$ENDIF}
    if rslt<0 then
    begin
	  b:=$ff;
//    Log_Writeln(LOG_ERROR,'SPI_read Reg: 0x'+Hex(reg,4)+' rslt: '+Num2Str(rslt,0));
	  ERR_MGMT_UPD(spi_dev[busnum,devnum].errhndl,_IOC_READ,1,false);
    end
    else 
    begin 
	  SetLength(xbuf.buf,rslt);
      b:=byte(xbuf.buf[1]); 
//    Log_Writeln(LOG_ERROR,'SPI_read Reg: 0x'+Hex(basereg,4)+' Data: 0x'+HexStr(xbuf.buf)+' rslt:'+Num2Str(rslt,0));
      ERR_MGMT_UPD(spi_dev[busnum,devnum].errhndl,_IOC_READ,1,true);	
    end;
  end else LOG_Writeln(LOG_ERROR,'SPI_Read[0x'+Hex(busnum,2)+'/0x'+Hex(devnum,2)+']: invalid busnum/devnum');
  SPI_Read:=b;
end;

function  SPI_BurstRead(busnum,devnum:byte):byte;
{ get byte from Buffer. Buffer was filled before with procedure SPI_BurstRead2Buffer }
var b:byte;
begin
  b:=$ff;
  if (busnum<=spi_max_bus) and (devnum<=spi_max_dev) then
  begin
    if spi_buf[busnum,devnum].posidx<=spi_buf[busnum,devnum].endidx then 
    begin
      b:=ord(spi_buf[busnum,devnum].buf[spi_buf[busnum,devnum].posidx]);
    end;
    inc(spi_buf[busnum,devnum].posidx);
  end else LOG_Writeln(LOG_ERROR,'SPI_BurstRead[0x'+Hex(busnum,2)+'/0x'+Hex(devnum,2)+']: invalid busnum/devnum');
  SPI_BurstRead:=b;
end;

procedure SPI_BurstRead2Buffer(busnum,devnum,basereg:byte; len:longword);
{ full duplex, see example spidev_fdx.c}
var rslt:integer; xfer : array[0..1] of spi_ioc_transfer_t;
begin
//  Log_Writeln(LOG_DEBUG,'SPI_BurstRead2Buffer devnum:0x'+Hex(devnum,4)+' reg:0x'+Hex(start_reg,4)+' len:0x'+Hex(len,8));
  rslt:=-1;
  if (busnum<=spi_max_bus) and (devnum<=spi_max_dev) then
  begin
    if spi_buf[busnum,devnum].posidx>spi_buf[busnum,devnum].endidx then
    begin
      SPI_Struct_Init(busnum,devnum,xfer[0],addr(spi_buf[busnum,devnum].buf),addr(spi_buf[busnum,devnum].buf),1);
	  SPI_Struct_Init(busnum,devnum,xfer[1],addr(spi_buf[busnum,devnum].buf),addr(spi_buf[busnum,devnum].buf),len);
      spi_buf[busnum,devnum].buf[1]:=char(byte(basereg)); 
	  spi_buf[busnum,devnum].reg:=basereg;
//    SPI_SetMode(busnum,devnum);
  (*  if LOG_GetLogLevel<=LOG_DEBUG then show_spi_struct(xfer[0]);
	  if LOG_GetLogLevel<=LOG_DEBUG then show_spi_struct(xfer[1]);
 	  if LOG_GetLogLevel<=LOG_DEBUG then show_spi_dev_info_struct(busnum,devnum); *)

//    Log_Writeln(LOG_DEBUG,'fpioctl('+Num2Str(spi_bus[busnum].spi_fd,0)+', 0x'+Hex(SPI_IOC_MESSAGE(2),8)+', 0x'+Hex(longword(addr(xfer)),8)+')'); 
      {$IFDEF UNIX}
	    rslt:=fpioctl(spi_dev[busnum,devnum].spi_fd,SPI_IOC_MESSAGE(2),addr(xfer)); { full duplex }
      {$ENDIF} 
      if rslt<0 then 
	  begin
//	    Log_Writeln(LOG_ERROR,'SPI_BurstRead2Buffer fpioctl result: '+Num2Str(rslt,0));
        spi_buf[busnum,devnum].endidx:=0;
        spi_buf[busnum,devnum].posidx:=1;
	  end
	  else
	  begin
        spi_buf[busnum,devnum].endidx:=rslt; 
        spi_buf[busnum,devnum].posidx:=1;
	  end;
//	  if LOG_Get_Level<=LOG_DEBUG then show_spi_buffer(spi_buf[devnum]);
	  (* if LOG_GetLogLevel<=LOG_DEBUG then show_spi_struct(rfm22_stat[devnum]); *)
    end;
  end else LOG_Writeln(LOG_ERROR,'SPI_BurstRead2Buffer[0x'+Hex(busnum,2)+'/0x'+Hex(devnum,2)+']: invalid busnum/devnum');
//  Log_Writeln(LOG_DEBUG,'SPI_BurstRead2Buffer (end)');
end;

procedure SPI_BurstWriteBuffer(busnum,devnum,basereg:byte; len:longword);
// Write 'len' Bytes from Buffer SPI Dev startig at address 'reg'
var rslt:integer; xfer : spi_ioc_transfer_t;
begin
//  Log_Writeln(LOG_DEBUG,'SPI_BurstWriteBuffer devnum:0x'+Hex(devnum,4)+' reg:0x'+Hex(start_reg,4)+' xferlen:0x'+Hex(xferlen,8));
  rslt:=-1;
  if (busnum<=spi_max_bus) and (devnum<=spi_max_dev) then
  begin
    if len>0 then
    begin
      SPI_Struct_Init(busnum,devnum,xfer,addr(spi_buf[busnum,devnum].buf),addr(spi_buf[busnum,devnum].reg),len+1); //+1 Byte, because send reg-content also. transfer starts at addr(spi_buf[devnum].reg)
      spi_buf[busnum,devnum].reg:=basereg;
//    SPI_SetMode(busnum,devnum);
// 	  if LOG_Get_Level<=LOG_DEBUG then show_spi_struct(xfer);
// 	  if LOG_Get_Level<=LOG_DEBUG then show_spi_dev_info_struct(busnum,devnum);
// 	  if LOG_Get_Level<=LOG_DEBUG then show_spi_buffer(busnum,devnum);
// 	  if LOG_Get_Level<=LOG_DEBUG then Log_Writeln(LOG_DEBUG,'fpioctl('+Num2Str(spi_bus[busnum].spi_fd,0)+', 0x'+Hex(SPI_IOC_MESSAGE(1),8)+', 0x'+Hex(longword(addr(xfer)),8)+')'); 
	  {$IFDEF UNIX}
	    rslt:=fpioctl(spi_dev[busnum,devnum].spi_fd,SPI_IOC_MESSAGE(1),addr(xfer)); 
	  {$ENDIF}
      if rslt<0 then Log_Writeln(LOG_ERROR,'SPI_BurstWriteBuffer fpioctl result: '+Num2Str(rslt,0))
	            else inc(spi_buf[busnum,devnum].posidx,rslt-1); //rslt-1 wg. reg + buffer content
//	  if LOG_Get_Level<=LOG_DEBUG then show_spi_buffer(busnum,devnum);
    end;
  end else LOG_Writeln(LOG_ERROR,'SPI_BurstWriteBuffer[0x'+Hex(busnum,2)+'/0x'+Hex(devnum,2)+']: invalid busnum/devnum');
end;

procedure SPI_StartBurst(busnum,devnum:byte; reg:word; writeing:byte; len:longint);
begin
//Log_Writeln(LOG_DEBUG,'StartBurst StartReg: 0x'+Hex(reg,4)+' writing: '+Bool2Str(writeing<>0));
  if (busnum<=spi_max_bus) and (devnum<=spi_max_dev) then
  begin
    if (spi_dev[busnum,devnum].spi_fd>=0) then 
    begin
//    SPI_SetMode(busnum,devnum);
	  spi_buf[busnum,devnum].reg:=byte(reg);
      if writeing=1 then 
	  begin
	    spi_buf[busnum,devnum].endidx:=len; spi_buf[busnum,devnum].posidx:=1; 
	    SPI_BurstWriteBuffer(busnum,devnum,reg,len); { Write 'len' Bytes from Buffer to SPI Dev startig at address 'reg'  }
	    if ((reg and $7f)=$7f) then SPI_write(busnum,devnum,$3e,word(len)); { set packet length for TX FIFO }
      end
	  else 
	  begin
	    spi_buf[busnum,devnum].endidx:=0; 
	    spi_buf[busnum,devnum].posidx:=1;  { initiate BurstRead2Buffer }
	    SPI_BurstRead2Buffer(busnum,devnum,reg,len);  { Read 'len' Bytes from SPI Dev to Buffer }
	    //inc(spi_buf[busnum,devnum].posidx); //1. Byte in Read Buffer is startregister -> position to 1. register content 
	  end;
    end;
  end else LOG_Writeln(LOG_ERROR,'SPI_StartBurst[0x'+Hex(busnum,2)+'/0x'+Hex(devnum,2)+']: invalid busnum/devnum');
end;

procedure SPI_EndBurst(busnum,devnum:byte);
begin
//Log_Writeln(LOG_DEBUG,'SPI_EndBurst');
  if (busnum<=spi_max_bus) and (devnum<=spi_max_dev) then
  begin
    spi_buf[busnum,devnum].endidx:=0; 
    spi_buf[busnum,devnum].posidx:=1; // initiate BurstRead2Buffer
  end else LOG_Writeln(LOG_ERROR,'SPI_EndBurst[0x'+Hex(busnum,2)+'/0x'+Hex(devnum,2)+']: invalid busnum/devnum');
end;

function  SPI_Dev_Init(busnum,devnum:byte):boolean;
var ok:boolean;
begin
  ok:=false;
  if (busnum<=spi_max_bus) and (devnum<=spi_max_dev) then
  begin
    with spi_dev[busnum,devnum] do 
    begin 
	  errhndl		:= NO_ERRHNDL;
	  isr_enable	:= false;
	  isr.gpio		:= -1;
	  spi_LSB_FIRST	:= 0;
	  spi_bpw		:= 8;
      spi_delay		:= 0;
	  spi_cs_change	:= 0;	// do not change CS during multiple byte transfers
	  spi_speed		:= spi_speed_c; 
      spi_mode		:= SPI_MODE_0;
	  spi_IOC_mode	:= SPI_IOC_RD_MODE; 
	  spi_fd		:= -1; 
	  spi_path		:=spi_path_c+Num2Str(busnum,0)+'.'+Num2Str(devnum,0);
//writeln('SPI_Dev_Init: ',spi_path);
	  if (spi_path<>'') and FileExists(spi_path) then
      begin
	    {$IFDEF UNIX} spi_fd:=fpOpen(spi_path,O_RdWr); {$ENDIF}
      end;
	  if (spi_fd<0) then 
	  begin
	    Log_Writeln(LOG_ERROR,'SPI_Dev_Init[0x'+Hex(busnum,2)+'/'+Hex(devnum,2)+']: '+spi_path);
	    if LOG_Get_Level<=LOG_DEBUG then SPI_show_dev_info_struct(busnum,devnum);
	  end
	  else ok:=true;
    end; // with
  end else LOG_Writeln(LOG_ERROR,'SPI_Dev_Init[0x'+Hex(busnum,2)+'/0x'+Hex(devnum,2)+']: invalid busnum/devnum');
//SPI_show_dev_info_struct(spi_dev[devnum], devnum);
  SPI_Dev_Init:=ok;
end;

procedure SPI_Start(busnum:byte);
var devnum:byte;
begin
  Log_Writeln(LOG_DEBUG,'SPI_Start busnum: '+Num2Str(busnum,0));
  if (busnum<=spi_max_bus) then
  begin
    with spi_bus[busnum] do 
    begin 
	  spi_speed:=spi_speed_c; // 10000000;
	  SPI_ClkWritten:=false;
      for devnum:=0 to spi_max_dev do
	  begin
	    if SPI_Dev_Init(busnum,devnum) then SPI_ClkWrite(spi_speed);
	  end; // for
    end;
  end else LOG_Writeln(LOG_ERROR,'SPI_Start[0x'+Hex(busnum,2)+']: invalid busnum');
end;

procedure SPI_Start;  
var i:integer; 
begin 
  for i:=0 to spi_max_bus do SPI_Start(i);  
  SPI_ClkWritten:=false;
end;

procedure SPI_Bus_Close(busnum:byte);
var devnum:byte;
begin
  if (busnum<=spi_max_bus) then
  begin
    for devnum:=0 to spi_max_dev do
    begin	
      with spi_dev[busnum,devnum] do 
      begin 
        {$IFDEF UNIX} if (spi_fd>=0) then fpclose(spi_fd); {$ENDIF}
        spi_fd:=-1; 
      end;
	end; // for
  end else LOG_Writeln(LOG_ERROR,'SPI_Bus_Close[0x'+Hex(busnum,2)+']: invalid busnum');
end;

procedure SPI_Bus_Close_All; 
var i:integer; 
begin 
  for i:=0 to spi_max_bus do SPI_Bus_Close(i); 
end;

procedure SPI_Loop_Test;
const seq=	#$48+#$45+#$4C+#$4C+#$4F+#$20+#$74+#$68+#$69+#$73+#$20+#$69+#$73+#$20+
			#$61+#$20+#$53+#$50+#$49+#$2D+#$4C+#$6F+#$6F+#$70+#$2D+#$54+#$65+#$73+#$74;
// 	  seq=	'HELLO this is a SPI-Loop-Test';
var rslt:integer; busnum,devnum:byte; //speed:longword;
begin
  busnum:=0; devnum:=0; // test on /dev/spidev0.0 // spidev<busnum.devnum>
  writeln('SPI_Loop_Test: Start');
  writeln('  pls. connect/short MOSI and MISO line (GPIO10/GPIO9).');
  writeln('  If you remove the wire between MOSI and MISO, and connect the MISO');
  writeln('  "H"-Level (+3.3 V), you should be able to read 0xFFs.');
  writeln('  If you connect MISO to ground (GND), you should receive 0x00s for each byte instead.');
  writeln('  we will send byte sequence 0x'+HexStr(seq));
  writeln('  with a length of '+Num2Str(Length(seq),0)+' bytes and should also receive it. <CR>');
  readln;
  
  (*if SPI_Mode(	spi_bus[busnum].spi_fd,SPI_IOC_RD_MAX_SPEED_HZ,addr(speed))>=0
    then writeln('SPI_Loop_Test: SPI clock rate=',speed) 
    else LOG_Writeln(LOG_ERROR,'SPI_Loop_Test: can not get SPI clock rate'); *)

  if SPI_Mode(	spi_dev[busnum,devnum].spi_fd,SPI_IOC_WR_MODE,
				addr(spi_dev[busnum,devnum].spi_mode))<0 then 
    LOG_Writeln(LOG_ERROR,'SPI_Loop_Test: setting SPI mode');
	
  if SPI_Mode(	spi_dev[busnum,devnum].spi_fd,SPI_IOC_WR_BITS_PER_WORD,
				addr(spi_dev[busnum,devnum].spi_bpw))<0 then 
	LOG_Writeln(LOG_ERROR,'SPI_Loop_Test: setting SPI bits per word');
  repeat
    rslt:=SPI_Transfer(busnum,devnum,seq);
    if rslt>=0 then
    begin
      writeln('SPI_Loop_Test: success, NumBytesRead: '+Num2Str(rslt,0));
      SPI_Show_Buffer(busnum,devnum); 
    end
    else LOG_Writeln(LOG_ERROR,'SPI_Loop_Test: errnum: '+Num2Str(rslt,0));
	delay_msec(500);
  until false;
  writeln('SPI_Loop_Test: End');
end;

procedure rfm22B_ShowChipType;
(* just to test SPI Read Function. Installed RFM22B Module on piggy back board is required!! *)
const RF22_REG_01_VERSION_CODE = $01; busnum=0; devnum=0;
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
  SPI_SetDevCSChange(busnum,devnum,0);
  writeln('Chip-Type: '+
    GDVC(SPI_Read(busnum,devnum,RF22_REG_01_VERSION_CODE))+
	' (correct answer should be 0x06)');  
end;
procedure SPI_Test; begin rfm22B_ShowChipType; end;

function RPI_snr :string;  			begin RPI_snr :=cpu_snr;  end;
function RPI_hw  :string;  			begin RPI_hw  :=cpu_hw;   end;
function RPI_proc:string;  			begin RPI_proc:=cpu_proc; end;
function RPI_mips:string;  			begin RPI_mips:=cpu_mips; end;
function RPI_feat:string;  			begin RPI_feat:=cpu_feat; end;
function RPI_rev :string;  			begin RPI_rev :=cpu_rev; end;
function RPI_revnum:byte;  			begin RPI_revnum:=cpu_rev_num; end;
function RPI_gpiomapidx:byte;  		begin RPI_gpiomapidx:=GPIO_map_idx; end;
function RPI_hdrpincount:byte;  	begin RPI_hdrpincount:=connector_pin_count; end; 
function RPI_freq :string; 			begin RPI_freq :=cpu_fmin+';'+cpu_fcur+';'+cpu_fmax+';Hz'; end;
function RPI_status_led_GPIO:byte;	begin RPI_status_led_GPIO:=status_led_GPIO; end;

function RPI_I2C_busnum(func:byte):byte; 
//get the I2C busnumber, where e.g. the general purpose devices are connected. 
//This depends on rev1 or rev2 board . e.g. RPI_I2C_busnum(RPI_I2C_general_purpose_bus_c) }
var b:byte;
begin
  b:=I2C_busnum; if func<>RPI_I2C_general_purpose_bus_c then inc(b);
  RPI_I2C_busnum:=(b mod 2);
end;

function RPI_I2C_busgen:byte; begin RPI_I2C_busgen:=RPI_I2C_busnum(RPI_I2C_general_purpose_bus_c);   end;
function RPI_I2C_bus2nd:byte; begin RPI_I2C_bus2nd:=RPI_I2C_busnum(RPI_I2C_general_purpose_bus_c+1); end;

procedure RPI_show_cpu_info;
begin
  writeln('rpi Snr  : ',RPI_snr);
  writeln('rpi HW   : ',RPI_hw);
  writeln('rpi proc : ',RPI_proc);
  writeln('rpi rev  : ',RPI_rev);
  writeln('rpi mips : ',RPI_mips);
  writeln('rpi Freq : ',RPI_freq);
  writeln('rpi Osci : ',(CLK_GetFreq(1)/1000000):7:2,' MHz');
  writeln('rpi PLLC : ',(CLK_GetFreq(5)/1000000):7:2,' MHz (CoreFreq)');
  writeln('rpi PLLD : ',(CLK_GetFreq(6)/1000000):7:2,' MHz');
  writeln('rpi HDMI : ',(CLK_GetFreq(7)/1000000):7:2,' MHz'); 
  writeln('CLK min  : ',(CLK_GetMinFreq/1000):   7:2,' kHz');
  writeln('CLK max  : ',(CLK_GetMaxFreq/1000000):7:2,' MHz');
  writeln('PWMHW min: ',(PWM_GetMinFreq(PWM_DIVImax)/1.0):7:2,' Hz');
  writeln('PWMHW max: ',(PWM_GetMaxFreq(PWM_DIVImin)/1000):7:2,' kHz'); 
end;

procedure RPI_show_SBC_info; begin RPI_show_cpu_info; end;

procedure RPI_show_all_info;
begin
  RPI_show_SBC_info;	writeln;
  GPIO_show_regs;		writeln;
  if (not restrict2gpio) then
  begin
    spi0_show_regs;		writeln;
    pwm_show_regs;		writeln;
    clk_show_regs;		writeln;
    stim_show_regs;		writeln;
    tim_show_regs;		writeln;
    q4_show_regs; 		writeln; 
    i2c0_show_regs;		writeln;
    i2c1_show_regs;		writeln;
//  i2c2_show_regs;		writeln;
    Clock_show_regs; writeln;
    GPIO_ShowConnector;
  end else Log_Writeln(Log_WARNING,'RPI_show_all_info: can report GPIO register only');
end;

procedure GPIO_create_int_script(filn:string);
const logfil_c='/tmp/GPIO_script.log';
var fil:text; sh:string;
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
	writeln(fil,'path='+GPIO_path_c);
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
  call_external_prog(LOG_NONE,'chmod +x '+filn,sh);   
end;

{$IFDEF UNIX}
function RPI_hal_Dummy_INT(GPIO_nr:integer):integer;
// if isr routine is not initialized
begin
  writeln ('RPI_hal_Dummy_INT fired for GPIO',GPIO_nr);
  RPI_hal_Dummy_INT:=-1;
end;

function my_isr(GPIO_nr:integer):integer;
// for GPIO_int testing. will be called on interrupt
const waittim_ms=1;
begin
  writeln ('my_isr fired for GPIO',GPIO_nr,' servicetime: ',waittim_ms:0,'ms');
  sleep(waittim_ms);
  my_isr:=999;
end;

//* Bits from:
//https://www.ridgerun.com/developer/wiki/index.php/Gpio-int-test.c */
//static void *
// https://github.com/omerk/pihwm/blob/master/lib/pi_gpio.c
// https://github.com/omerk/pihwm/blob/master/demo/GPIO_int.c
// https://github.com/omerk/pihwm/blob/master/lib/pihwm.c
function isr_handler(p:pointer):longint; // (void *isr)
const testrun_c=true;
    STDIN_FILENO = 0; STDOUT_FILENO = 1; STDERR_FILENO = 2; 
	POLLIN = $0001; POLLPRI = $0002; 
var rslt:integer; nfds,rc:longint; 
    buf:array[0..63] of byte; fdset:array[0..1] of pollfd; 
	testrun:boolean; isr_ptr:^isr_t; Call_Func:TFunctionOneArgCall;
begin
  rslt:=0; nfds:=2; testrun:=testrun_c; isr_ptr:=p; Call_Func:=isr_ptr^.func_ptr;
  if testrun then writeln('## ',isr_ptr^.gpio);
  if (isr_ptr^.flag=1) and (isr_ptr^.fd>=0) then
  begin
    if testrun then writeln('isr_handler running for GPIO',isr_ptr^.gpio);
    while true do
	begin
      fdset[0].fd := STDIN_FILENO; fdset[0].events := POLLIN;  fdset[0].revents:=0;
      fdset[1].fd := isr_ptr^.fd;  fdset[1].events := POLLPRI; fdset[1].revents:=0;

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

      if ((fdset[1].revents and POLLPRI)>0) then
	  begin //* We have an interrupt! */
        if (-1 = fpread (fdset[1].fd, buf, SizeOf(buf))) then
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

      if ((fdset[0].revents and POLLIN)>0) then
	  begin
        if (-1 = fpread (fdset[0].fd, buf, 1)) then
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

function  WriteStr2UnixDev(dev,s:string):integer; 
var rslt:integer; lgt:byte; buffer:I2C_databuf_t; 
begin  
  rslt:=-1;
  {$IFDEF UNIX}
    with buffer do
    begin
	  lgt:=length(s);
      if lgt>SizeOf(buf) then 
	  begin
	    LOG_Writeln(LOG_ERROR,'WriteStr2UnixDev: string to long: '+Num2Str(lgt,0)+'/'+Num2Str(SizeOf(buf),0));
	    exit(-1);
      end;		
      buf:=s;
      hdl:=fpopen(dev, Open_RDWR or O_NONBLOCK);
      if hdl<0 then exit(-2); 
	  rslt:=fpWrite(hdl,buf,lgt);
      if (rslt=lgt) then rslt:=0;
	  fpclose(hdl);
    end; // with
  {$ENDIF}
  WriteStr2UnixDev:=rslt;
end;
 
function GPIO_OpenFile(var isr:isr_t):integer;
// needed, because this is the only known possibility to use ints without kernel modifications.
(* path=/sys/class/gpio
   echo $gpionum	> $path/export
   echo in 			> $path/gpio$gpionum/direction
   echo $edgetype	> $path/gpio$gpionum/edge
*)
var rslt:integer; pathstr,edge_type:string; 
begin
  rslt:=0; pathstr:=GPIO_path_c+'/gpio'+Num2Str(isr.gpio,0); 
  if isr.rising_edge then edge_type:='rising' else edge_type:='falling';
  writeln('GPIO_OpenFile');
  {$I-}
    if (WriteStr2UnixDev(GPIO_path_c+'/export',Num2Str(isr.gpio,0))=0) then
      if (WriteStr2UnixDev(pathstr+'/direction','in')=0) then
	      WriteStr2UnixDev(pathstr+'/edge',edge_type);
    if FileExists(pathstr+'/value') then 
	  isr.fd:=fpopen(pathstr+'/value', O_RDONLY or O_NONBLOCK );
  {$I+} 
  if (isr.fd<0) then rslt:=-1;
  GPIO_OpenFile:=rslt;
end;

function GPIO_int_active(var isr:isr_t):boolean;
begin
  if isr.fd>=0 then GPIO_int_active:=true else GPIO_int_active:=false;
end;

function GPIO_set_int(var isr:isr_t; GPIO_num:longint; isr_proc:TFunctionOneArgCall; flags:s_port_flags) : integer;
var rslt:integer; _flags:s_port_flags; GPIO_struct:GPIO_struct_t;
begin
  rslt:=-1; _flags:=flags;
//writeln('GPIO_int_set ',GPIO_num);
  isr.gpio:=GPIO_num;  			isr.flag:=1; 	isr.rslt:=0; 		isr.int_enable:=false; 
  isr.fd:=-1;          			isr.int_cnt:=0;	isr.int_cnt_raw:=0;	isr.enter_isr_routine:=0;		
  isr.last_isr_servicetime:=0; 	isr.enter_isr_time:=now; 
  isr.func_ptr:=@RPI_hal_Dummy_INT;  
  _flags:=_flags+[INPUT]-[OUTPUT,PWMHW,PWMSW]; // interrupt is INPUT, remove all Output flags
  isr.rising_edge:=true; // default
  if (FallingEdge IN _flags) then isr.rising_edge:=false; 	
  if (RisingEdge  IN _flags) then isr.rising_edge:=true; 	
  if isr.rising_edge 
    then _flags:=_flags+[RisingEdge]
	else _flags:=_flags+[FallingEdge]; 
  GPIO_SetStruct(GPIO_struct,1,isr.gpio,'INT',_flags);  
  if (isr.gpio>=0) and GPIO_Setup(GPIO_struct) then
  begin 
    if GPIO_OpenFile(isr)=0 then 
    begin
	  if (isr_proc<>nil) then isr.func_ptr:=isr_proc;
      BeginThread(@isr_handler,@isr,isr.ThreadId);  // http://www.freepascal.org/docs-html/prog/progse43.html
      isr.ThreadPrio:=ThreadGetPriority(isr.ThreadId);  
	  rslt:=0;
    end
	else LOG_Writeln(LOG_ERROR,'GPIO_SETINT: Could not set INT for GPIO'+Num2Str(GPIO_num,0));
  end;
  if rslt<>0 then LOG_Writeln(LOG_ERROR,'GPIO_SETINT: err:'+Num2Str(rslt,0));
  GPIO_set_int:=rslt;
end;

function GPIO_int_release(var isr:isr_t):integer;
var rslt:integer;
begin
  rslt:=0;
//writeln('GPIO_int_release: pin: ',isr.gpio);
  isr.flag:=0; isr.int_enable:=false; delay_msec(100); // let Thread Time to terminate
  GPIO_set_edge_rising (isr.gpio,false);
  GPIO_set_edge_falling(isr.gpio,false); 
  if isr.fd>=0 then 
  begin 
    fpclose(isr.fd); isr.fd:=-1; 
	WriteStr2UnixDev(GPIO_path_c+'/unexport',Num2Str(isr.gpio,0));
  end;
  GPIO_int_release:=rslt;
end;

procedure instinthandler;  // not ready ,  inspiration http://lnxpps.de/rpie/
//var rslt:integer; p:pointer;
begin
//  writeln(request_irq(110,p,SA_INTERRUPT,'short',nil));
end;

procedure GPIO_int_enable (var isr:isr_t); begin isr.int_enable:=true;  (*writeln('int Enable  ',isr.gpio);*) end;
procedure GPIO_int_disable(var isr:isr_t); begin isr.int_enable:=false; writeln('int Disable ',isr.gpio); end;

procedure inttest(GPIO_nr:longint);
// shows how to use the GPIO_int functions
const loop_max=30;
var cnt:longint; isr:isr_t; 
begin
  writeln('INT main start on GPIO',GPIO_nr,' loops: ',loop_max:0);
  GPIO_set_int   (isr,GPIO_nr,@my_isr,[RisingEdge]); // set up isr routine, initialize isr struct: GPIO_number, int_routine which have to be executed, rising_edge
  GPIO_int_enable(isr); // Enable Interrupts, allows execution of isr routine
  for cnt:=1 to loop_max do
  begin
    write  ('doing nothing, waiting for an interrupt on GPIO',GPIO_nr:0,' loopcnt: ',cnt:3,' int_cnt: ',isr.int_cnt:3,' ThreadID: ',longword(isr.ThreadID),' ThPrio: ',isr.ThreadPrio);
	if isr.rslt<>0 then begin write(' result: ',isr.rslt,' last service time: ',isr.last_isr_servicetime:0,'ms'); isr.rslt:=0; end;
	writeln;
    sleep (1000);
  end; 
  GPIO_int_disable(isr);
  GPIO_int_release(isr);
  writeln('INT main end   on GPIO',GPIO_nr);
end;

procedure GPIO_int_test; // shows how to use the GPIO_int functions
const gpio=22; 
begin
  writeln('GPIO_int_test: GPIO',gpio,' HWPin:',GPIO_MAP_GPIO_NUM_2_HDR_PIN(gpio));
  inttest(gpio);
end;

{$ENDIF}

procedure BB_OOK_PIN(state:boolean);
// this procedure, uses a gpio pin for OOK (OnOffKeying). 
begin
//Writeln('BB_OOK_PIN(state: '+Bool2Str(state)+' Pin: '+Num2Str(BB_pin,0));
  Log_Writeln(LOG_DEBUG,'BB_OOK_PIN(state: '+Bool2Str(state)+' Pin: '+Num2Str(BB_pin,0));
  if BB_pin>0	then GPIO_set_PIN(BB_pin,state) 
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
					  if ein then s:=s+'10' else s:=s+'01'; s:=s+'S'; // ein: '00' ???
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
  if BB_pin>0 then GPIO_set_OUTPUT(BB_pin); 
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
	 1 : 					BBpin:=GPIO_MAP_HDR_PIN_2_GPIO_NUM(IO1_Pin_on_RPI_Header,	RPI_gpiomapidx);  
	 2 : 					BBpin:=GPIO_MAP_HDR_PIN_2_GPIO_NUM(OOK_Pin_on_RPI_Header,	RPI_gpiomapidx); 
	else if BBpin>0 then	BBpin:=GPIO_MAP_HDR_PIN_2_GPIO_NUM(BBpin, 					RPI_gpiomapidx); 
  end;
  BB_SetPin(BBpin);
end;

procedure ELRO_TEST;
// Set your ELRO PowerSwitch to the following System- and Unit_A-Code
const id_c='ELRO-A'; SystemCode_c='10001'; Unit_A_c='10000'; Unit_B_c='01000'; Unit_C_c='00100'; Unit_D_c='00010'; Unit_E_c='00001'; 
var cnt:integer; oldpin:longint;
begin
  oldpin:=BB_GetPin;															// save it
  BB_SetPin(GPIO_MAP_HDR_PIN_2_GPIO_NUM(IO1_Pin_on_RPI_Header,RPI_gpiomapidx)); // set the pin to OOK Pin for the piggyback-board Transmitter Chip (433.92 Mhz)
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

procedure MORSE_speed(speed:integer); // 1..5, -1=default_speed
//WpM:WordsPerMinute; BpM:Buchstaben/Letter pro Minute
begin
  MORSE_dit_lgt			:= 120;	//  10WpM=50BpM	-> 120ms // default
  case speed of
      1 : MORSE_dit_lgt	:=1200;	//  1WpM=  5BpM	->1200ms 
	  2 : MORSE_dit_lgt	:= 240;	//  5WpM= 25BpM	-> 240ms
	  3 : MORSE_dit_lgt	:= 150;	//  8WpM		-> 150ms 
	  4 : MORSE_dit_lgt	:= 120;	// 10WpM= 50BpM	-> 120ms
	  5 : MORSE_dit_lgt	:=  60;	// 20WpM=100BpM	->  60ms
  end;
end;

procedure MORSE_tx(s:string);
// http://de.wikipedia.org/wiki/Morsezeichen
// http://en.wikipedia.org/wiki/MORSE_code
const test=true; CH_c = 'c'; 
  MORSE_char : array [01..26,01..02] of string = 
  ( ('.-',  'A') , ('-...','B') , ('-.-.','C') , ('-..', 'D') , ('.',   'E') , 
    ('..-.','F') , ('--.', 'G') , ('....','H') , ('..',  'I') , ('.---','J') ,
    ('-.-', 'K') , ('.-..','L') , ('--',  'M') , ('-.',  'N') , ('---', 'O') ,
    ('.--.','P') , ('--.-','Q') , ('.-.', 'R') , ('...', 'S') , ('-',   'T') ,
    ('..-', 'U') , ('...-','V') , ('.--', 'W') , ('-..-','X') , ('-.--','Y') ,
    ('--..','Z') );
 
  MORSE_digit : array [01..10,01..02] of string = 
  ( ('-----','0') , ('.----','1') , ('..---','2') , ('...--', '3') , ('....-','4') ,
    ('.....','5') , ('-....','6') , ('--...','7') , ('---..', '8') , ('----.','9') );

  sc1_count = 27;
  MORSE_sc1 : array [01..sc1_count,01..02] of string = 
  ( ('----',  CH_c),
    ('.-.-.-','.') , ('--..--',',') ,  ('---...', ':') , ('-.-.-.',';') , ('..--..','?') ,   
    ('-.-.--','!') , ('-....-','-') ,  ('..--.-', '_') , ('-.--.', '(') , ('-.--.-',')') , 
	('.----.',''''), ('-...-', '=') ,  ('.-.-.',  '+') , ('-..-.', '/') , ('.--.-.','@') ,
	('.-...', '&') , ('.-..-.','"') ,  ('...-..-','$') ,
    ('.-.-',  'Ä') , ('---.',  'Ö') ,  ('..--',   'Ü') , ('...--..','ß'), ('.--.-', 'À') ,
	('.--.-', 'Å') , ('.-..-', 'È') ,  ('--.--',  'Ñ') 
  );

var sh,sh2:string; n : longint; dit_lgt,dah_lgt,symbol_end,letter_end,word_end:word;

  procedure MORSE_wait(w:word); begin delay_msec(w) end;
  procedure dit; begin BB_OOK_PIN(AN); MORSE_wait(dit_lgt); BB_OOK_PIN(AUS); end; 
  procedure dah; begin BB_OOK_PIN(AN); MORSE_wait(dah_lgt); BB_OOK_PIN(AUS); end; 
  procedure sig (ch:char); begin if test then write(ch); if ch='.' then dit else dah; end;
  
  function  sc1 (s:string):string; var sh:string; j:longint; begin sh:=''; for j := 1 to sc1_count do if s=MORSE_sc1[j,2] then sh:=MORSE_sc1[j,1]; sc1:=sh; end;
  procedure mors(s1,s2:string);    var n : longint; begin if test then begin if s1=CH_c then write('CH') else write(s1); write(' '); end; for n := 1 to Length(s2) do begin sig(s2[n]); if n<Length(s2) then MORSE_wait(symbol_end); end; if test then writeln; end;
  
begin
  dit_lgt:=MORSE_dit_lgt; dah_lgt:=3*dit_lgt; symbol_end:=dit_lgt; letter_end:=dah_lgt; word_end:=7*dit_lgt; // define timing, depending on external variable MORSE_dit_lgt set by procedure MORSE_speed
  LOG_Writeln(LOG_DEBUG,'Morse: '+s);
  if test then  writeln('Morse: '+s);
  sh:=Upper(s);
//sh:=StringReplace(sh,'CH',CH_c,[rfReplaceAll]); // replace 'CH' with one character
  for n := 1 to Length(sh) do
  begin
    case sh[n] of
	  ' '	   : begin MORSE_wait(word_end); if test then writeln; end;
      'A'..'Z' : begin sh2:=MORSE_char [ord(sh[n])-ord('A')+1,1]; mors(sh[n],sh2); MORSE_wait(letter_end); end;
	  '0'..'9' : begin sh2:=MORSE_digit[ord(sh[n])-ord('0')+1,1]; mors(sh[n],sh2); MORSE_wait(letter_end); end;
	  else       begin sh2:=sc1(sh[n]);                           mors(sh[n],sh2); MORSE_wait(letter_end); end;
	end;
  end;
  if test then writeln;
end;

procedure MORSE_test;
var oldpin:longint;
begin
  oldpin:=BB_GetPin;						// save it
  BB_SetPin(RPI_status_led_GPIO); 			// set the pin to Rpi Status LED
  MORSE_speed(3);							// 3: 8WpM	-> 150ms 
  MORSE_tx('Hello this is a Morse Test.');	// The Status LED should blink (morse) now
  BB_SetPin(oldpin);						// restore it
end;

(*PID library with fixed calculation time interval. 
  inspired by D. Rosseel and ported to FPC by SF
  Doku: http://www.libstock.com/projects/view/161/pid-library *)
procedure PID_SetIntImprove(var PID_Struct:PID_Struct_t; On_:boolean); begin PID_Struct.PID_IntImprove:=On_; end;
procedure PID_SetDifImprove(var PID_Struct:PID_Struct_t; On_:boolean); begin PID_Struct.PID_DifImprove:=On_; end;
procedure PID_SetLimImprove(var PID_Struct:PID_Struct_t; On_:boolean); begin PID_Struct.PID_LimImprove:=On_; end;

procedure PID_Reset(var PID_Struct:PID_Struct_t);
begin
  with PID_Struct do
  begin 
    PID_cnt:=0; PID_Integrated:=0.0; PID_PrevInput:=0.0; 
	PID_PrevAbsError:=0.0; PID_FirstTime:=true; 
  end; // with
end;

procedure PID_Init(var PID_Struct:PID_Struct_t; Kp,Ki,Kd,MinOutput,MaxOutput:PID_float_t);
begin
  PID_Reset(PID_Struct); PID_SetLimImprove(PID_Struct,false);	 
  PID_SetIntImprove(PID_Struct,false); PID_SetDifImprove(PID_Struct,false);	
  with PID_Struct do
  begin 
    PID_Kp:=Kp; PID_Ki:=Ki; PID_Kd:=Kd; PID_MinOutput:=MinOutput; PID_MaxOutput:=MaxOutput; 
	PID_Delta:=0; PID_LastTime:=now; PID_SampleTime_ms:=100;
  end;
end;

function  PID_Calc(var PID_Struct:PID_Struct_t; Setpoint,InputValue:PID_float_t):PID_float_t;
  function  Sign(value:PID_float_t):boolean; begin sign:=(value>=0); end;
  procedure Limit1(var Value:PID_float_t; MinOut,MaxOut:PID_float_t);
  begin if Value<MinOut then Value:=MinOut else if Value>MaxOut then Value:=MaxOut; end;
  procedure Limit2(var Value:PID_float_t; DeltaVal:PID_float_t);
  begin if Value<DeltaVal then Value:=DeltaVal else if Value>DeltaVal then Value:=DeltaVal; end;
	
var Err,ErrValue,DiffValue,ErrAbs,reslt:PID_float_t;
begin
  reslt:=0; ErrAbs:=0;
  with PID_Struct do
  begin
//  if (not IsNaN(Setpoint)) and (not IsNaN(InputValue)) then  // if type PID_float_t=extended
//  if (MilliSecondsBetween(now,PID_LastTime)>=PID_SampleTime_ms) then
    begin
	  inc(PID_cnt); 
      Err := SetPoint - InputValue;
      if PID_DifImprove then ErrAbs := abs(Err);
      ErrValue  := Err * PID_Kp;
      if PID_IntImprove then if Sign(Err)<>Sign(PID_Integrated) then PID_Integrated:=0.0;
      PID_Integrated := PID_Integrated + (Err * PID_Ki);
      Limit1(PID_Integrated, PID_MinOutput, PID_MaxOutput);
      if PID_FirstTime then
      begin 
        PID_FirstTime    := false;
        PID_PrevInput    := InputValue;
        PID_PrevAbsError := 0.0;
      end;
      DiffValue := (InputValue - PID_PrevInput) * PID_Kd;
      PID_PrevInput := InputValue;
      if PID_DifImprove then
      begin
        if ErrAbs < PID_PrevAbsError then DiffValue := 0.0; 
        PID_PrevAbsError := ErrAbs;
      end;
      reslt := ErrValue + PID_Integrated - DiffValue; 
      Limit1(reslt, PID_MinOutput, PID_MaxOutput);
	  if PID_LimImprove then Limit2(reslt, Err);
	  PID_Delta:=reslt;
	  PID_LastTime:=now;
    end;
  end;  // with
  PID_Calc:=reslt;
end;

procedure PID_TestXX;
//just for demo purposes
//simulate PID. How the to be adjusted Value approaches a Setpoint value
const
  PID_Kp=0.15; PID_Ki=0.1;  PID_Kd=0.1;	// Kp=1.1,Ki=0.2,Kd=0.1; 
  PID_Min=-25; PID_Max=+25;				// MinOutput=-25; MaxOutput=+25
  dm_c=13; scale_c=100; ntimes_c=10; errinduct=false;
  PID_SetPoints_c:array[0..(dm_c-1)] of 
    PID_float_t = ( 0, 0.1, 0.2, 0.3, 0.5, 0.7, 0.8, 0.9, 1.1, 1.05, 1.01, 0.9, 0.95);
var loop,n:integer; pid1:PID_Struct_t; NewVal,SetPoint,delta:PID_float_t;
begin
  PID_Init(pid1,PID_Kp,PID_Ki,PID_Kd,PID_Min,PID_Max);
  PID_SetIntImprove (pid1,true); PID_SetDifImprove(pid1,true);	// enable improvements
  NewVal:=0; loop:=0; n:=0;
  writeln('PID_Test2 Kp:',PID_Kp:0:2,' Ki:',PID_Ki:0:2,' Kd:',PID_Kd:0:2);
  repeat
    SetPoint:=PID_SetPoints_c[loop]*scale_c;
	delta:=PID_Calc(pid1,SetPoint,NewVal);
	{$warnings off} if errinduct then delta:=delta*random; {$warnings on} 
	writeln('PID_Test: SetPoint:',SetPoint:7:2,'  NewVal:',NewVal:7:2,'   delta:',delta:12:8);
	NewVal:=NewVal+delta;
	// action according to NewVal
	sleep(1000); 
	inc(n); if n>=ntimes_c then begin n:=0;	inc(loop); if loop>=dm_c then loop:=0; end;
  until false;
end;

procedure PID_Test;
//just for demo purposes
//simulate PID. How the to be adjusted Value approaches a Setpoint value
const
  PID_Kp=1.1;  PID_Ki=0.2;  PID_Kd=0.1;	// Kp=1.1,Ki=0.2,Kd=0.1; 
  PID_Min=-25; PID_Max=+25;				// MinOutput=-25; MaxOutput=+25
  dm_c=8; scale_c=47; ntimes_c=16; errinduct=false;
  PID_SetPoints_c:array[0..(dm_c-1)] of PID_float_t = ( 1, 0, -1, 0, 2, 3, -1, 0 );
var loop,n:integer; pid1:PID_Struct_t; NewVal,SetPoint,delta:PID_float_t;
begin
  PID_Init(pid1,PID_Kp,PID_Ki,PID_Kd,PID_Min,PID_Max);
  PID_SetIntImprove (pid1,true); PID_SetDifImprove(pid1,true);	// enable improvements
  NewVal:=0; loop:=0; n:=0;
  writeln('PID_Test2 Kp:',PID_Kp:0:2,' Ki:',PID_Ki:0:2,' Kd:',PID_Kd:0:2);
  repeat
    SetPoint:=PID_SetPoints_c[loop]*scale_c;
	delta:=PID_Calc(pid1,SetPoint,NewVal);
	{$warnings off} if errinduct then delta:=delta*random; {$warnings on} 
	writeln('PID_Test: SetPoint:',SetPoint:7:2,'  NewVal:',NewVal:7:2,'   delta:',delta:12:8);
	NewVal:=NewVal+delta;
	// action according to NewVal
	sleep(1000); 
	inc(n); if n>=ntimes_c then begin n:=0;	inc(loop); if loop>=dm_c then loop:=0; end;
  until false;
end;
 
procedure RPI_hal_exit;
begin
//writeln('Exit unit RPI_hal+');
  if ExitCode<>0 then 
    begin LOG_Writeln(LOG_ERROR,'RPI_hal_exit: Exitcode: '+Num2Str(ExitCode,3)); end;
  if RPI_platform_ok then
  begin
    TRIG_End(-1); 
    ENC_End(-1);
	SERVO_End(-1);
	ERR_END(-1);
    SPI_Bus_Close_All;
    I2C_Close_All;
    MMAP_end;
  end;
//writeln('Exit unit RPI_hal-');
  BIOS_EndIniFile;
  RpiMaintCmd.free;
end;

function  RPI_Init_Allowed:boolean;
var ok:boolean; i:longint;
begin
  ok:=false;
  for i:=1 to ParamCount do if Upper(ParamStr(i))='-RPIHAL=HWINIT' then ok:=true;  
  RPI_Init_Allowed:=ok;
end;

function  RPI_HW_Start(initpart:s_initpart):boolean;
var ok:boolean; _initpart:s_initpart;
begin
  ok:=RPI_platform_ok;
  if ok then
  begin
    _initpart:=initpart;
    if ((InitI2C) IN _initpart) or ((InitSPI) IN _initpart) 
      then _initpart:=_initpart+[InitGPIO]; // GPIO is mandatory
    if ok and (InitGPIO IN _initpart) 	then ok:=(GPIO_Start=0);

    if ok and (InitI2C	IN _initpart) then
    begin 
      ok:=(not restrict2gpio);
      if ok then I2C_Start else Log_Writeln(Log_ERROR,'RPI_HW_Start: can not start I2C, try with sudo');
    end;

    if ok and (InitSPI	IN _initpart) then 
    begin
      ok:=(not restrict2gpio);
      if ok then SPI_Start else Log_Writeln(Log_ERROR,'RPI_HW_Start: can not start SPI, try with sudo');
    end;
    
    if not ok then
    begin
      LOG_Writeln(LOG_ERROR,'RPI_hal: can not initialize MemoryMap, RPI_hal will Halt(1)');
      if (InitHaltOnError IN _initpart)	then Halt(1);
    end;
  end
  else
  begin
     if RPI_run_on_known_hw 
      then Log_Writeln(Log_ERROR,'RPI_hal: supported min-/maximum kernel #'+Num2Str(supminkrnl,0)+' - #'+Num2Str(supmaxkrnl,0)+' ( uname -a )')
      else Log_Writeln(Log_ERROR,'RPI_hal: not running on supported rpi HW');
  end;   
  RPI_HW_Start:=ok;
end;

function  RPI_HW_Start:boolean; 
begin RPI_HW_Start:=RPI_HW_Start([InitHaltOnError,InitGPIO,InitI2C,InitSPI]); end; // start all

begin
//writeln('Enter unit rpi_hal');
  ProgramStartTime:=now;
  AddExitProc(@RPI_hal_exit);
  LOG_Level:=LOG_Warning; IniFileDesc.inifilename:=''; 
//LOG_Level:=LOG_debug;
  SAY_Set_Level(LOG_DEBUG);
  RpiMaintCmd:=TIniFile.Create('');
  SetUTCOffset;  // set _TZlocal 
  mem_fd:=-1; mmap_arr:=nil; cpu_rev_num:=0; GPIO_map_idx:=0;
  Get_CPU_INFO_Init; 
  BB_pin:=RPI_status_led_GPIO;
  MORSE_speed(-1);				// set to default speed 10WpM=50BpM	-> 120ms 
  IO_Init_Const;
  if RPI_Init_Allowed then RPI_HW_Start;
//{$IFDEF UNIX} GPIO_create_int_script(int_filn_c); {$ENDIF} // no need for it. Just for convenience 
//writeln('Leave unit rpi_hal');
end.
