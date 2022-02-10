unit rpi_hal; // V6.0 // 2022-02-10
{ RPI_hal:
* Free Pascal Hardware abstraction library for the Raspberry Pi
* Copyright (c) 2012-2022 Stefan Fischer
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

  minimum FPC Version: 
  	2.4.6 for 32Bit for armhf
	3.2.0+dfsg-12 [2021/01/25] for aarch64 64Bit
  support for the following RPI-Models: A,B,A+,B+,Pi2B,Zero,Pi3B,4B...
  !!!!! pls. use following uses sequence in your program: !!!!!
  uses cthreads,rpi_hal,<yourunits>...
  required sw tools (apt install curl whois):
  - curl		(PKG: curl)  is used by function RPI_MAINT.
  - mkpasswd	(PKG: whois) is used by function LNX_ChkUsrPwdValid.
  Info:  http://wiki.freepascal.org/Lazarus_on_Raspberry_Pi
  pls. report bugs and discuss code enhancements on github issues
  Supported by the H2020 Project # 664786 - Reservoir Computing with Real-Time Data for Future IT
}
  {$MODE OBJFPC}
  {$R+} {$Q+}
  {$H+}  // Ansistrings
  { $ PACKRECORDS C} 
  {$PACKRECORDS 16} 
  { $ ALIGN 32}
  {$MACRO ON}
  { $ HINTS OFF}
  {$NOTES OFF}
  
Interface 
uses {$IFDEF UNIX}    cthreads,unixtype, (*pthreads,*) initc,ctypes,BaseUnix,Unix,unixutil,errors, {$ENDIF} 
     {$IFDEF WINDOWS} windows, {$ENDIF} 
	 crt,typinfo,sysutils,strutils,dateutils,Classes,Process,math,inifiles,md5;
 	 
const
  supminkrnl=797; supmaxkrnl=970; 	// not used
  fmt_rfc3339='yyyy-mm-dd"T"hh:nn:ss';
  tfmt0 = 'hh:mm:ss.zz';
  
//MaxLongINT=	high(longint);			// $7fffffff // already defined
  MaxLongWORD=	high(longword);			// $ffffffff
  MaxINT64= 	high(int64);			// $7fffffffffffffff
  MinINT64= 	low (int64);			// $8000000000000000
  MaxQWORD=		high(qword);			// $ffffffffffffffff
//MinSingle=	Single	(1.5E-45);		MaxSingle=	Single	(3.4E38); // already defined in math.pp
//MinDouble=	Double	(5.0E-324);		MaxDouble=	Double	(1.7E308);
//MinExtended=	Extended(1.9E-4932);	MaxExtended=Extended(1.1E4932);
 
  eeprom_devadr_c=$50;	// EEPROM @ I2C-Adr 0x50 
  
  DBGRecordCnt_c= 60000;
  
  hdl_unvalid=-1;
  AN=true; AUS=false; AUF=true; ZU=false; LINKS=false; RECHTS=true;
  TestTimeOut_sec=60;	// 1min
  wdoc_path_c=			'/dev/watchdog';
  rpi_fw_dev=			'/dev/vcio';
  rpi_cpu_temp_dev_c=	'/sys/class/thermal/thermal_zone0/temp'; 
//http://makezine.com/2016/03/02/raspberry-pi-3-not-halt-catch-fire/
  RPI_TempAlarmCelsius_c=   85;	// 85'C according to spec (max. temp), 82'C rpi start to throttle@82Deg 
  RPI_CTempCool_c=		0.6824;	// factor for 58'C
  RPI_CTempFanOFF_c=	RPI_CTempCool_c;
  RPI_CTempFanON_c=		0.7647;	// factor for 65'C
  RPI_CTempWarn_c= 		0.8824;	// factor for 75'C
  RPI_CTempHot_c=		0.9412;	// factor for 80'C
  
  RPI_TempFanOFF_c=		RPI_TempAlarmCelsius_c*RPI_CTempFanOFF_c; 	 // 58'C
  RPI_TempFanON1_c=		RPI_TempAlarmCelsius_c*RPI_CTempFanON_c; 	 // 65'C
  RPI_TempFanON2_c=		RPI_TempAlarmCelsius_c*RPI_CTempWarn_c; 	 // 75'C
  
  RPI_TightLoop_us_c=	125; 	// us tested on rpi3B&4 @600MHz
 
  LF      = #$0A; CR   = #$0D; STX      = #$02; ETX = #$03;	ESC=#27;
  Cntrl_Z = #$1A; BELL =   #7; EOL_char =   LF; HT  = #$09; // HT=TAB
  yes_c='TRUE,YES,1,JA,AN,EIN,HIGH,ON'; nein_c='FALSE,NO,0,NEIN,AUS,LOW,OFF';
  
  sed_enc_htm_c='s/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g; s/"/\&quot;/g; s/''"''"''/\&#39;/g';
  sed_uml_htm_c='s/Š/\&auml;/g; s/š/\&ouml;/g; s/Ÿ/\&uuml;/g; s/€/\&Auml;/g; s/…/\&Ouml;/g; s/†/\&Uuml;/g';
  sed_esc_htm_c='sed '''+sed_enc_htm_c+'; '+sed_uml_htm_c+''''; // esc html with sed

  CompanyShortName='BASIS';
  DfltSect_c='DEFAULT'; HomeSect_c='HOME'; noSect_c='UNKNOWN';
  UAgentDefault='Mozilla/5.0 (Macintosh; Intel Mac OS X 10.10; rv:36.0) Gecko/20100101 Firefox/36.0';
//https://curl.haxx.se/docs/manpage.html
  CURLTimeOut_c= '300'; CURLPorts_c='49152-63000';
  CURLFTPDefaults_c='--retry 3 --retry-delay 5 --ftp-pasv --ftp-skip-pasv-ip --disable-epsv --connect-timeout '+CURLTimeOut_c+' --local-port '+CURLPorts_c;
//CURLSSLDefaults_c='-k --ssl --ssl-allow-beast'; // does not work on webgo24
  CURLSSLDefaults_c='-k --insecure';
  CURLpfext_c='.prog';
  cryptext_c= '.cpt';
  curlprogsync_ms_c=3000;		// > 9 
  {$IFDEF WINDOWS} 
    CRLF=CR+LF; dir_sep_c='\';	
	c_tmpdir='c:\tmp'; AppDataDir_c = 'c:\ProgramData\'+CompanyShortName;	
	LogDir_c=c_tmpdir;  c_cmddir='c:\cmd'; c_etcdir=c_tmpdir; 
  {$ELSE} 
    CRLF=LF; dir_sep_c='/'; 	
	c_tmpdir='/tmp'; AppDataDir_c = '/var/lib/'+CompanyShortName; 
	LogDir_c='/var/log'; c_cmddir='/usr/local/sbin'; c_etcdir = '/etc'; 
	dmtdir_c='/etc/service';  // Daemon-Tools directory
  {$ENDIF} 
  
// fbtft: framebuffer specific info. 
// needed for SPI OLED/TFT/LCD display (SSD1306 sainsmart18 ...) console 
// setterm --cursor off --clear all > /dev/tty1
// /usr/bin/fbi -d /dev/fb1 --noverbose -a /opt/splash.png
  tty_console_c=		'/dev/tty1';
  fbdev_c=				'/dev/fb0';
  fbcon_c=				'fbcon=map:10 fbcon=font:VGA8x8 logo.nologo';	// /dev/fb1 <-> /dev/tty1
(*  
/etc/modules-load.d/fbtft.conf
spi_bcm2835
fbtft_device

TFT-Tyoe: 1.8SPI 128x160 kompatibel zu sainsmart18 (evtl. auch ander displays zum setzen!!!!!)
/etc/modprobe.d/fbtft.conf
options fbtft_device name=sainsmart18 debug=3 rotate=90 speed=16000000

TFT-Tyoe: 0.91SPI 128x64 kompatibel zu SSD1306
options fbtft_device name=adafruit13m debug=3 speed=16000000 gpios=dc:9
*)
  
  sslcfgfile_c=AppDataDir_c+'/openssl.cnf';
  cert_dir_c=		'/etc/ssl';
  cert_key_dir_c=	cert_dir_c+'/private';					
  cert_crt_dir_c=	cert_dir_c+'/certs';
  ca_pem_c=			cert_crt_dir_c+'/Deutsche_Telekom_Root_CA_2.pem';	// default ca file
  
  cert0_key_c=		cert_key_dir_c+'/ssl-cert-snakeoil.key';	
  cert0_combined_c=	cert_key_dir_c+'/ssl-cert-snakeoil-combined.pem'; // e.g. for lighthttpd, shellinabox
  cert0_crtORpem_c=	cert_crt_dir_c+'/ssl-cert-snakeoil.pem';
  
  cert1_key_c=		cert_key_dir_c+'/server.key';
  cert1_combined_c=	cert_key_dir_c+'/server-combined.pem'; 
  cert1_crtORpem_c=	cert_crt_dir_c+'/server.crt';
  
  letsencryptdir_c=	'/etc/letsencrypt/live';
  
  LNX_ShadowFile=		'/etc/shadow';
  LNX_DevTree=			'/proc/device-tree';
  
  IP_infomax_c=			3;
  ifuap_c=				'ap0';
  ifeth_c=				'eth0';
  ifwlan_c=				'wlan0';
  ifwlan1_c=			'wlan1';
  ifusb0_c=				'usb0';
  ovpn_dev_c=			'tun0';
  noip_c=				'noIPAdr'; 
  noMAC_c=				'noMAC';		// ff:ff:ff:ff:ff:ff
  noData_c=				'noData';
  unknown_c=			'unknown';
  exit_c=				'<exit>';
  none_c=				'<none>';
  usrbrk_c=				'usr break';
  
//ipdevarr:array[-1..IP_infomax_c] of string[10]=('nodev',ifwlan_c,ifeth_c,ifuap_c,ifwlan1_c);  
  IP_infoNOadapt_c=	-1;
  IP_infoWLAN0idx_c= 0;
  IP_infoETH0idx_c=	 1;
  IP_infoUAP0idx_c=	 2;
  IP_infoWLAN1idx_c= 3;
    
  hnamdflt_c=	'raspberrypi';
  EncDecPWD_c=	'rpi_hal$4712';		// default pwd, if no encrypt/decrypt pwd is supplied
  
  CRLF4HTTP=CR+LF; // for HTTP-Protocol we have to send 0d0a 

  ext_sep_c='.'; 
  esc_char_c='\';

  sep_max_c=6;
  sep:array[0..sep_max_c] of char=(';',',','|','*','~','`','^');
     		   
  nano_c:longword		=1000000000;
  osc_freq_c			=  19200000; // OSC  (19.2Mhz ClkSrc=1)	
  pllc_freq_c			=1000000000; // PLLC (1000Mhz ClkSrc=5, changes with overclock settings) 
  plld_freq_c			= 500000000; // PLLD ( 500Mhz ClkSrc=6)
  HDMI_freq_c			= 216000000; // HDMI ( 216Mhz ClkSrc=7, auxiliary) 
  
  gpiomax_2711_reg_c	=58; // max. gpio count (GPIO0-57) (BCM2711)
  gpiomax_2708_reg_c	=54; // max. gpio count (GPIO0-53) pls. see (BCM2709) 2012 Datasheet page 102ff 
  GPIO_PWM0	   			=18; // GPIO18 PWM0 	on Connector Pin12
  GPIO_PWM1				=19; // GPIO19 PWM1 	on Connector Pin35  (RPI2)
  GPIO_PWM0A0		   	=12; // GPIO12 PWM0 	on Connector Pin32  (RPI2)
  GPIO_PWM1A0			=13; // GPIO13 PWM1 	on Connector Pin33  (RPI2)
  GPIO_PWM0Audio		=40; // GPIO40 PWM0		on Audio
  GPIO_PWM1Audio		=45; // GPIO45 PWM1		on Audio
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
  mdl=16; // was 9;
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
 
//PWM table (8Bit) for linear dimming
  PWMlinTAB_c:array[0..31] of byte = (
      0,  1,  2,  2,  2,  3,  3,  4,  5,  6,   7,   8,  10,  11,  13,  16,
     19, 23, 27, 32, 38, 45, 54, 64, 76, 91, 108, 128, 152, 181, 215, 255);
 
//ARM Physical to VC IO Mapping  
  BCM2xxx_VCIO_ALIAS=	$7E000000;
//ARM Physical to VC Bus Mapping
  GPU_CACHED_BASE=		$40000000;
  GPU_UNCACHED_BASE=	$C0000000;
   
{ BCM2708: Physical addresses range from 0x20000000 to 0x20FFFFFF for peripherals. 
    The bus addresses for peripherals are set up to map onto the peripheral 
	bus address range starting at 0x7E000000. 
	Thus a peripheral advertised here at bus address 0x7Ennnnnn is available 
	at physical address 0x20nnnnnn. }
	
  PAGE_SIZE=			$1000;		// 4k
  BCM270x_PSIZ_Byte= 	$80000000-BCM2xxx_VCIO_ALIAS; // MemoryMap: Size of Peripherals. Docu Page 5  
  BCM270x_RegSizInByte= SizeOf(longword);
  BCM270x_RegMaxIdx= 	(BCM270x_PSIZ_Byte div BCM270x_RegSizInByte)-1; // Registers 0..RegMaxIdx
  BCM2708_PBASE= 		$20000000; 	// Peripheral Base in Bytes
  BCM2709_PBASE= 		$3F000000; 	// Peripheral Base in Bytes (RPI2B Processor) 
  BCM2711_PBASE=		$fe000000;	// Peripheral Base in Bytes (rpi4) 
  
  STIM_BASE_OFS=    	$00003000; 	// Docu Page 172ff SystemTimer
  INTR_BASE_OFS=   		$0000B000;  // Docu Page 112ff 
  TIMR_BASE_OFS=   		$0000B000;  // Docu Page 196ff Timer ARM side
  MBX_BASE_OFS=			$0000B880;	// MailboxBaseAddr // dmesg | grep mbox
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

//0x 7E10 0000	// https://de.scribd.com/doc/101830961/GPIO-Pads-Control2
  PADS_BASE			= PADS_BASE_OFS div BCM270x_RegSizInByte;
  PADS_GPIO00_27	= PADS_BASE+$0b;	// 0x7e10 002c PADS (GPIO  0-27)
  PADS_GPIO28_45	= PADS_BASE+$0c;	// 0x7e10 0030 PADS (GPIO 28-45)
  PADS_GPIO46_53	= PADS_BASE+$0d;	// 0x7e10 0034 PADS (GPIO 46-53)
  PADS_BASE_START	= PADS_GPIO00_27;
  PADS_BASE_LAST	= PADS_GPIO46_53;
  
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
  GPPUPPDN			= GPIO_BASE+$39; // Pin Pull-up/down Enable 2711 pins 15:0
  GPPUPPDN1			= GPIO_BASE+$3a; // Pin Pull-up/down Enable 2711 pins 31:16
  GPPUPPDN2			= GPIO_BASE+$3b; // Pin Pull-up/down Enable 2711 pins 47:32
  GPPUPPDN3			= GPIO_BASE+$3c; // Pin Pull-up/down Enable 2711 pins 57:48
  
  GPIOONLYREAD		= GPLEV;		 // 2x 32Bit Register, which are ReadOnly
  GPIO_BASE_LAST	= GPPUPPDN3;

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
  
  MBX_BASE			= MBX_BASE_OFS div BCM270x_RegSizInByte;
  MBX_READ0			= MBX_BASE+$00;	//	0x00		Read data from VC to ARM
  MBX_PEEK0			= MBX_BASE+$04;	//	0x10
  MBX_SENDER0		= MBX_BASE+$05;	//	0x14
  MBX_STATUS0		= MBX_BASE+$06;	//	0x18		Status of VC to ARM
  MBX_CONFIG0		= MBX_BASE+$07;	//	0x1c
  MBX_WRITE1		= MBX_BASE+$08;	//	0x20		Write data from ARM to VC
  MBX_PEEK1			= MBX_BASE+$0c;	//	0x30
  MBX_SENDER1		= MBX_BASE+$0d;	//	0x34
  MBX_STATUS1		= MBX_BASE+$0e;	//	0x38
  MBX_CONFIG1		= MBX_BASE+$0f;	//	0x3c		
  
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
  ENC_SyncTime_c	= 12;	  // max. interval /sync. response time of device in msec and switch debounce time
  ENC_SwRepeatTime_c= 1000;	  // if switch is pressed 1sec, treat as repeated keystroke 
  ENC_sleeptime_def	= 50;
  ENC_SwitchShutDown=3000;	  // Switch pressed 3sec signals ShutDown 
  
  TRIG_SyncTime_c	= 10;
    
  SERVO_FRQ=  50;								  // Servo SG90 frequency (Hz) for PWM
  SERVO_Speed=100; 						  	      // Datasheet Value:0.1s/60degree
  SRVOMINANG=-90; SRVOMIDANG=0;   SRVOMAXANG= 90; // Servo SG90 Datasheet Values (Angles in degree)
//SRVOMINDC=1000; SRVOMIDDC=1500; SRVOMAXDC=2000; // Servo SG90 Datasheet Values (us)
  SRVOMINDC= 600; SRVOMIDDC=1600; SRVOMAXDC=2600; // Servo SG90 Values found experimentally (us)
  
//LOG_All =1; LOG_DEBUG = 2; LOG_INFO =  10; Log_NOTICE = 20; Log_WARNING = 50; Log_ERROR = 100; Log_URGENT = 250; LOG_NONE = 254;   

  I2C_COMBINED_path_c= '/sys/module/i2c_bcm2708/parameters/combined';
//source: http://I2C-tools.sourcearchive.com/documentation/3.0.3-5/I2C-dev_8h_source.html 
  I2C_path_c		 = '/dev/i2c-';
  I2C_max_bus        = 1;
  I2C_unvalid_addr	 = $ff;
  I2C_UseNoReg		 = $ffff;  {  use this as Read/Write register, 
							      if I2C device has no registers (RD/WR only one value)
							      like the pressure sensor HDI M500 }
  I2C_M_WR			 = $0000;
  I2C_M_RD           = $0001;
  I2C_M_TEN          = $0010;  	// we have a ten bit chip address 
  I2C_M_DMA_SAFE	 = $0200;	// use only in kernel space
  I2C_M_RECV_LEN     = $0400;  	// length will be first received byte
  I2C_M_NO_RD_ACK    = $0800;
  I2C_M_IGNORE_NAK   = $1000;
  I2C_M_REV_DIR_ADDR = $2000;
  I2C_M_NOSTART      = $4000;
  I2C_M_STOP		 = $8000;
 
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
  
  I2C_RDWR_IOCTL_MAX_MSGS		  = 42;
  
//to determine what functionality is present 
  I2C_FUNC_I2C                    = $00000001;
  I2C_FUNC_10BIT_ADDR             = $00000002;
  I2C_FUNC_PROTOCOL_MANGLING      = $00000004; // I2C_M_[REV_DIR_ADDR,NOSTART,..] 
  I2C_FUNC_SMBUS_PEC              = $00000008;
  I2C_FUNC_NOSTART				  = $00000010; // I2C_M_NOSTART
  I2C_FUNC_SLAVE				  = $00000020;
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
  I2C_FUNC_SMBUS_HOST_NOTIFY	  = $10000000; // SMBus 2.0 or later
  
  I2C_FUNC_SMBUS_BYTE             = I2C_FUNC_SMBUS_READ_BYTE       or I2C_FUNC_SMBUS_WRITE_BYTE;
  I2C_FUNC_SMBUS_BYTE_DATA        = I2C_FUNC_SMBUS_READ_BYTE_DATA  or I2C_FUNC_SMBUS_WRITE_BYTE_DATA;
  I2C_FUNC_SMBUS_WORD_DATA        = I2C_FUNC_SMBUS_READ_WORD_DATA  or I2C_FUNC_SMBUS_WRITE_WORD_DATA;
  I2C_FUNC_SMBUS_BLOCK_DATA       = I2C_FUNC_SMBUS_READ_BLOCK_DATA or I2C_FUNC_SMBUS_WRITE_BLOCK_DATA;
  I2C_FUNC_SMBUS_I2C_BLOCK        = I2C_FUNC_SMBUS_READ_I2C_BLOCK  or I2C_FUNC_SMBUS_WRITE_I2C_BLOCK;  

  RPI_I2C_general_purpose_bus_c=1;  
  c_max_Buffer   	= $ff-1;  // was 128 // was 024 

  SPI_IOC_MAGIC     = 'k';
  
  SPI_CPHA			= $01;
  SPI_CPOL			= $02;
  SPI_MODE_0		= $00;
  SPI_MODE_1		= SPI_CPHA;
  SPI_MODE_2		= SPI_CPOL;
  SPI_MODE_3		= SPI_CPOL or SPI_CPHA;
  SPI_CS_HIGH		= $04;
  SPI_LSB_FIRST		= $08;
  SPI_3WIRE			= $10;
  SPI_LOOP			= $20;
  SPI_NO_CS			= $40;
  SPI_READY			= $80;
  SPI_TX_DUAL		= $100;
  SPI_TX_QUAD		= $200;
  SPI_RX_DUAL		= $400;
  SPI_RX_QUAD		= $800;
  
  spi_path_c		= '/dev/spidev';
  spi_max_bus    	= 0;
  spi_max_dev	 	= 1; 
  SPI_BUF_SIZE_c 	= c_max_Buffer;	// 255; // was 64;
  SPI_unvalid_addr	=$ffff;
  SPI_Speed_c		=500000; 
    
  _IOC_NONE   	 	=$00; _IOC_WRITE 	 =$01; _IOC_READ	  =$02;
  _IOC_NRBITS    	=  8; _IOC_TYPEBITS  =  8; _IOC_SIZEBITS  = 14; _IOC_DIRBITS  =  2;
  _IOC_NRSHIFT   	=  0; 
  _IOC_TYPESHIFT 	= (_IOC_NRSHIFT+  _IOC_NRBITS); 
  _IOC_SIZESHIFT 	= (_IOC_TYPESHIFT+_IOC_TYPEBITS);
  _IOC_DIRSHIFT  	= (_IOC_SIZESHIFT+_IOC_SIZEBITS);
  
  ERR_MAXCNT		=   5;
  ERR_AutoResetMSec	=2000;	// AutoReset of Errors in msec. 0=noReset
  NO_ERRHNDL		=  -1;
  NO_TEST        	= NO_ERRHNDL;
  
//consts for rpi fw mbx access (/dev/vcio)
//source: https://github.com/raspberrypi/linux/blob/rpi-4.19.y/include/soc/bcm2835/raspberrypi-firmware.h
// 29 Jan 2020
//TAG_property_stati
  TAG_STATUS_REQUEST=							0;
  TAG_STATUS_SUCCESS=							$80000000;
  TAG_STATUS_ERROR=								$80000001;

//TAG_property_tags  
  TAG_PROPERTY_END=								0;
  TAG_GET_FIRMWARE_REVISION=					$00000001;
  TAG_GET_FIRMWARE_VARIANT=						$00000002;
  TAG_GET_FIRMWARE_HASH=						$00000003;

  TAG_SET_CURSOR_INFO=							$00008010;
  TAG_SET_CURSOR_STATE=							$00008011;

  TAG_GET_BOARD_MODEL=							$00010001;
  TAG_GET_BOARD_REVISION=						$00010002;
  TAG_GET_BOARD_MAC_ADDRESS=					$00010003;
  TAG_GET_BOARD_SERIAL=							$00010004;
  TAG_GET_ARM_MEMORY=							$00010005;
  TAG_GET_VC_MEMORY=							$00010006;
  TAG_GET_CLOCKS=								$00010007;
  TAG_GET_POWER_STATE=							$00020001;
  TAG_GET_TIMING=								$00020002;
  TAG_SET_POWER_STATE=							$00028001;
  TAG_GET_CLOCK_STATE=							$00030001;
  TAG_GET_CLOCK_RATE=							$00030002;
  TAG_GET_VOLTAGE=								$00030003;
  TAG_GET_MAX_CLOCK_RATE=						$00030004;
  TAG_GET_MAX_VOLTAGE=							$00030005;
  TAG_GET_TEMPERATURE=							$00030006;
  TAG_GET_MIN_CLOCK_RATE=						$00030007;
  TAG_GET_MIN_VOLTAGE=							$00030008;
  TAG_GET_TURBO=								$00030009;
  TAG_GET_MAX_TEMPERATURE=						$0003000a;
  TAG_GET_STC=									$0003000b;
  TAG_ALLOCATE_MEMORY=							$0003000c;
  TAG_LOCK_MEMORY=								$0003000d;
  TAG_UNLOCK_MEMORY=							$0003000e;
  TAG_RELEASE_MEMORY=							$0003000f;
  TAG_EXECUTE_CODE=								$00030010;
  TAG_EXECUTE_QPU=								$00030011;
  TAG_SET_ENABLE_QPU=							$00030012;
  TAG_GET_DISPMANX_RESOURCE_MEM_HANDLE=			$00030014;
  TAG_GET_EDID_BLOCK=							$00030020;
  TAG_GET_CUSTOMER_OTP=							$00030021;
  TAG_GET_EDID_BLOCK_DISPLAY=					$00030023;
  TAG_GET_DOMAIN_STATE=							$00030030;
  TAG_GET_THROTTLED=							$00030046;
  TAG_GET_CLOCK_MEASURED=						$00030047;
  TAG_NOTIFY_REBOOT=							$00030048;
  TAG_SET_CLOCK_STATE=							$00038001;
  TAG_SET_CLOCK_RATE=							$00038002;
  TAG_SET_VOLTAGE=								$00038003;
  TAG_SET_TURBO=								$00038009;
  TAG_SET_CUSTOMER_OTP=							$00038021;
  TAG_SET_DOMAIN_STATE=							$00038030;
  TAG_GET_GPIO_STATE=							$00030041;
  TAG_SET_GPIO_STATE=							$00038041;
  TAG_SET_SDHOST_CLOCK=							$00038042;
  TAG_GET_GPIO_CONFIG=							$00030043;
  TAG_SET_GPIO_CONFIG=							$00038043;
  TAG_GET_PERIPH_REG=							$00030045;
  TAG_SET_PERIPH_REG=							$00038045;
  TAG_GET_POE_HAT_VAL=							$00030049;
  TAG_SET_POE_HAT_VAL=							$00030050;
  TAG_NOTIFY_XHCI_RESET=						$00030058;

//* Dispmanx TAGS */
  TAG_FRAMEBUFFER_ALLOCATE=						$00040001;
  TAG_FRAMEBUFFER_BLANK=						$00040002;
  TAG_FRAMEBUFFER_GET_PHYSICAL_WIDTH_HEIGHT=	$00040003;
  TAG_FRAMEBUFFER_GET_VIRTUAL_WIDTH_HEIGHT=		$00040004;
  TAG_FRAMEBUFFER_GET_DEPTH=					$00040005;
  TAG_FRAMEBUFFER_GET_PIXEL_ORDER=				$00040006;
  TAG_FRAMEBUFFER_GET_ALPHA_MODE=				$00040007;
  TAG_FRAMEBUFFER_GET_PITCH=					$00040008;
  TAG_FRAMEBUFFER_GET_VIRTUAL_OFFSET=			$00040009;
  TAG_FRAMEBUFFER_GET_OVERSCAN=					$0004000a;
  TAG_FRAMEBUFFER_GET_PALETTE=					$0004000b;
  TAG_FRAMEBUFFER_GET_TOUCHBUF=					$0004000f;
  TAG_FRAMEBUFFER_GET_GPIOVIRTBUF=				$00040010;
  TAG_FRAMEBUFFER_RELEASE=						$00048001;
  TAG_FRAMEBUFFER_TEST_PHYSICAL_WIDTH_HEIGHT=	$00044003;
  TAG_FRAMEBUFFER_TEST_VIRTUAL_WIDTH_HEIGHT=	$00044004;
  TAG_FRAMEBUFFER_TEST_DEPTH=					$00044005;
  TAG_FRAMEBUFFER_TEST_PIXEL_ORDER=				$00044006;
  TAG_FRAMEBUFFER_TEST_ALPHA_MODE=				$00044007;
  TAG_FRAMEBUFFER_TEST_VIRTUAL_OFFSET=			$00044009;
  TAG_FRAMEBUFFER_TEST_OVERSCAN=				$0004400a;
  TAG_FRAMEBUFFER_TEST_PALETTE=					$0004400b;
  TAG_FRAMEBUFFER_TEST_VSYNC=					$0004400e;
  TAG_FRAMEBUFFER_SET_PHYSICAL_WIDTH_HEIGHT=	$00048003;
  TAG_FRAMEBUFFER_SET_VIRTUAL_WIDTH_HEIGHT=		$00048004;
  TAG_FRAMEBUFFER_SET_DEPTH=					$00048005;
  TAG_FRAMEBUFFER_SET_PIXEL_ORDER=				$00048006;
  TAG_FRAMEBUFFER_SET_ALPHA_MODE=				$00048007;
  TAG_FRAMEBUFFER_SET_VIRTUAL_OFFSET=			$00048009;
  TAG_FRAMEBUFFER_SET_OVERSCAN=					$0004800a;
  TAG_FRAMEBUFFER_SET_PALETTE=					$0004800b;
  TAG_FRAMEBUFFER_SET_TOUCHBUF=					$0004801f;
  TAG_FRAMEBUFFER_SET_GPIOVIRTBUF=				$00048020;
  TAG_FRAMEBUFFER_SET_VSYNC=					$0004800e;
  TAG_FRAMEBUFFER_SET_BACKLIGHT=				$0004800f;

  TAG_VCHIQ_INIT=								$00048010;

  TAG_GET_COMMAND_LINE=							$00050001;
  TAG_GET_DMA_CHANNELS=							$00060001;
  
  MB_CHANNEL_ERROR=	 $FEEDDEAD;	
  MB_CHANNEL_SUCCESS=$80000000;	// MAIL_FULL
  MB_FULL=			 $80000000;
  MB_LEVEL=			 $400000FF;
  MB_EMPTY=			 $40000000;	// Mailbox Status Register: Mailbox Empty MAIL_EMPTY
  MB_CHANNEL_POWER= 	$00;	// Mailbox Channel 0: Power Management Interface 
  MB_CHANNEL_FB=		$01;	// Mailbox Channel 1: Frame Buffer
  MB_CHANNEL_VUART=		$02;	// Mailbox Channel 2: Virtual UART
  MB_CHANNEL_VCHIQ=		$03;	// Mailbox Channel 3: VCHIQ Interface
  MB_CHANNEL_LEDS=		$04;	// Mailbox Channel 4: LEDs Interface
  MB_CHANNEL_BUTTONS=	$05;	// Mailbox Channel 5: Buttons Interface
  MB_CHANNEL_TOUCH=		$06;	// Mailbox Channel 6: Touchscreen Interface
  MB_CHANNEL_COUNT=		$07;	// Mailbox Channel 7: Counter
  MB_CHANNEL_TAGS=		$08;	// Mailbox Channel 8: Tags (ARM to VC)
  MB_CHANNEL_GPU=		$09;	// Mailbox Channel 9: GPU (VC to ARM)
     
//flags for watchdog     
  WDIOF_OVERHEAT=		$0001;	// Reset due to CPU overheat
  WDIOF_FANFAULT=		$0002;	// Fan failed
  WDIOF_EXTERN1=		$0004;	// External relay 1
  WDIOF_EXTERN2=		$0008;	// External relay 2
  WDIOF_POWERUNDER=		$0010;	// Power bad/power fault
  WDIOF_CARDRESET=		$0020;	// Card previously reset the CPU
  WDIOF_POWEROVER=		$0040;	// Power over voltage
  WDIOF_SETTIMEOUT=		$0080;	// Set timeout (in seconds)
  WDIOF_MAGICCLOSE=		$0100;	// Supports magic close char
  WDIOF_PRETIMEOUT=		$0200;	// Pretimeout (in seconds), get/set
  WDIOF_ALARMONLY=		$0400;	// Watchdog triggers a management or other external alarm not a reboot
  WDIOF_KEEPALIVEPING=	$8000;	// Keep alive ping reply	

//consts for PseudoTerminal IO (/dev/ptmx)
  Terminal_MaxBuf = 1024; 
  NCCS 		= 32;
  
  TCSANOW 	= 0; 			// make change immediate 
  TCSADRAIN = 1; 			// drain output, then change 
  TCSAFLUSH = 2; 			// drain output, flush input 
  TCSASOFT 	= $10; 			// flag - don't alter h.w. state 
  
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
  
  RPI_hal_dscl=	20;
  
  HeapStatMax_c=20;
  
  CLOCK_REALTIME=0; 		// Taken from linux/time.h // Posix timers
  
  CertPublic=1; CertPrivKey=2; CertCA=3; CertCombined=4;
  CertPackRPIMaint=0; CertPackSnakeOil=1; CertPackServer=2; CertPackLetsEncrypt=3; CertPackLast=CertPackLetsEncrypt;
  
  iKp=0; iKi=1; iKd=2;		// arr-indexes for Kp,Ki,Kd
  PID_AVGminNum_c=2; PID_AVGmaxNum_c=50; PID_epsilon_c=0.000001; 
  PID_nk8=8;		 PID_timadj_c=0.000001; // usec sensor data
  PID_loctusec=4; 	 PID_locsollval=5; 	 PID_locistval=6; 	// csv field locations
  PID_twiddle_tolerance=	0.001;		 
  PID_twiddleSavAtTolScal_c=100;	 
  PID_nk15=15;
  
  DIST_wid_c=6;
       
type
  E_rpi_hal_Exception= class(Exception);
  t_ErrorLevel=   (	LOG_NHdr,LOG_WHITE,LOG_BLACK,LOG_BLUE,LOG_GREEN,LOG_YELLOW,LOG_ORANGE,LOG_RED,LOG_MAGENTA,
  					LOG_CYAN,LOG_BROWN,LOG_LGRAY,LOG_DGRAY,LOG_LBLUE,LOG_LGREEN,LOG_LCYAN,LOG_LRED,LOG_LMAGENTA,
  					LOG_All,LOG_DEBUG,LOG_INFO,LOG_NOTICE,LOG_WARNING,LOG_ERROR,LOG_URGENT,LOG_NONE,LOG_NONE2); 
//t_port_flags order is important, do not change. Ord(t_port_flags) will be used to set ALT-Bits in GPFSELx Registers.
// ORD:				   0,     1,   2,   3,   4,   5,   6,   7,    8,    9      10
  t_port_flags  = (	INPUT,OUTPUT,ALT5,ALT4,ALT0,ALT1,ALT2,ALT3,PWMHW,PWMSW,control,
					FRQHW,Simulation,PullUP,PullDOWN,RisingEDGE,FallingEDGE,NOpull,
					DS2mA,DS4mA,DS6mA,DS8mA,DS10mA,DS12mA,DS14mA,DS16mA,noPADhyst,noPADslew,
					ReversePOLARITY,InitialHIGH,noWRthrough,IOCheck,UseUsage,
					UseCSec,UseCSecWR,UseCSecRD,I2C,
					Baud300,Baud1k2,Baud2k4,Baud4k8,Baud9k6,Baud19k2,Baud38k4,Baud57k6,
					SIOinvertLogic,Bit5,Bit6,Bit7,Bit8,StopBit1,StopBit1H,StopBit2,HShw,HSsw,
					ParityNONE,ParityODD,ParityEVEN,ParityMark,ParitySpace,withSTTY,
					TTYstartCursor,TTYstopCursor,TTYclearScreen,QRshowCode,noERRORhndl); 					
  s_port_flags  = set of t_port_flags;

  t_initpart	= (	InitHaltOnError,InitGPIO, (* InitGPIOonly,*) InitRPIfw,InitI2C,InitSPI,
  					InitCreateScript,InitOnExitShowRuntime,StartShutDownWatcher,InitWDOG,InitWDOGnoThread,
  					InstSignalHandler,UPDAuthDBDateTime,InitCertSnakeOil,InitCertServer,InitCertLetsEncrypt,
  					OSGetIPinfos);
  s_initpart  	= set of t_initpart;
  t_IOBusType	= (	UnknDev,I2CDev,SPIDev);
  t_PowerSwitch	= ( ELRO,Sartano,Nexa,Intertechno,FS20);
  t_rpimaintflags=(	UseENCrypt,UpdExec,UpdPKGGet,UpdPKGcopy,UseDECrypt,UpdPKGInst,UpdPKGInstV,
  					UpdUpld,UpdDwnld,UpdProtoHTTP,UpdProtoHTTPS,UpdProtoRAW,UAgent,UpdNoRedoRequest,
  					UpdNOP,UpdSSL,UpdVerbose,UpdQuiet,UpdForce,UpdUpdate,UpdNoProgressBar,UpdLogAppend,UpdNoFTPDefaults, //UpdSUDO,
  					UpdErrVerbose,UpdNoCreateDir,UpdNewerOnly,UpdCleanUP,UpdKeepFile,
  					UpdNoWDOGprevent,UpdNoZIP,UpdFollowLink,UpdVerify,UpdDBG1,UpdDBG2,UpdnoMD5Chk,UpdOnlyMD5Chk,
  					UPDStop,UPDDisable,UPDEnable,UPDStart,UPDReStart,UpdShowThInfo,SysV,Systemd,
  					APTforceUpd,APTforceOverwrite,APTProgressBar,APTProgressBarFancy,APTforceConfOLD,APTautoClean,APTautoRemove,APTcheckPkg,
  					APTallowRelChg,APTnoProxy,APTpkgPin,APTdwnOnly,APTautoInst,APTsimulate,APTallowUnAuth,APTfixBroken,APTignoreHold,
  					APTupdate,APTupgrade,APTdistUpgrade,APTinstall,APTreInstall,APTremove,APTpurge,APTcheck,APTdownload,APTclean,
  					WDOG_Close,WDOG_Retrig,WDOG_GTO,WDOG_STO,WDOG_BSTAT,WDOG_GSup,WDOG_Pause,WDOG_Resume,  
  					ActWeb,ActCTRLDev,ActSCPI,ActButton,ActInTestMode,ActDelFile,ActIsCmd,
  					USR1flg,USR2flg,USR3flg,USR4flg,USR5flg);		
  s_rpimaintflags=set of t_rpimaintflags;
  
  t_RPI_config	= (	GET_CAN_EXPAND,EXPAND_FS,GET_HOSTNAME,SET_HOSTNAME,GET_BOOT_CLI,GET_AUTOLOGIN,
  					SET_BOOT_CLI,SET_BOOT_CLIA,SET_BOOT_GUI,SET_BOOT_GUIA,GET_BOOT_WAIT,SET_BOOT_WAIT,
  					GET_SPLASH,SET_SPLASH,GET_OVERSCAN,SET_OVERSCAN,GET_PIXDUB,SET_PIXDUB,GET_CAMERA,SET_CAMERA,
  					GET_SSH,SET_SSH,GET_VNC,SET_VNC,GET_SPI,SET_SPI,GET_I2C,SET_I2C,GET_SERIAL,GET_SERIALHW,SET_SERIAL,
  					GET_1WIRE,SET_1WIRE,GET_RGPIO,SET_RGPIO,GET_PI_TYPE,GET_OVERCLOCK,SET_OVERCLOCK,
  					GET_GPU_MEM,GET_GPU_MEM_256,GET_GPU_MEM_512,GET_GPU_MEM_1K,SET_GPU_MEM,
  					GET_HDMI_GROUP,GET_HDMI_MODE,SET_HDMI_GP_MOD,GET_WIFI_CTRY,SET_WIFI_CTRY,WLAN_INTERFACES);
  					
  t_PWRflags = 	  ( PWR_OFF,PWR_ON,PWR_HDMI );
  s_PWRflags =		set of t_PWRflags;
  
  t_Manu_flag=	  (	unknownManufacturer,Bosch,HDI,AMS,HTD,MCP,IDT,MAXIM);
  
  t_BIOS_Flags=	  (	BIOS_secret,BIOS_noOVR,BIOS_DoESC,BIOS_UnESC,BIOS_crypt,
  					 BIOS_bool,BIOS_int,BIOS_uint,BIOS_float,BIOS_NonZero,BIOS_tstmp,BIOS_PrefDflt,
  					 BIOS_1byte,BIOS_2byte,BIOS_4byte,BIOS_lon,BIOS_lat,
  					 BIOS_tryARRidx,BIOS_RemOnDflt,
  					 BIOS_trim1,BIOS_trim2,BIOS_trim3,BIOS_trim4,BIOS_Printable,BIOS_UnEscUrl);
  s_BIOS_Flags=		set of t_BIOS_Flags;
  
  t_Strobe_flag=  ( STB_Off,STB_On,STB_Reset,STB_OneShot,STB_Interval,STB_IntvalSet,STB_DtyCycl,STB_GetState,STB_Async,STB_unk);
  s_Strobe_flag=	set of t_Strobe_flag;
  
  Cert_Type_t=	  (	CT_rsa,CT_x509,CT_ssl,CT_serial,CT_modulus,CT_modmd5,CT_md5,CT_sha1,CT_sha256,CT_sha512,CT_combined,CT_Path);
  
  MSG_Type_t=	  (	noIDaddmsg,dashmsg,pmsg,usrmsg,maintmsg,cmdmsg,curlprogmsg);
  MSG_Type_s=		set of MSG_Type_t;
      
  t_MemoryMapPtr= ^t_MemoryMap;
  t_MemoryMap	= array[0..BCM270x_RegMaxIdx] of longword; // for 32 Bit access 
  buftype 		= array[0..c_max_Buffer-1] of byte;
  
  cint=longint; cuint=longword; cuint64=qword;
  Pclockid_t=^clockid_t; clockid_t=longint;
  
  t_CLOption = record Name,Value:string; end;
  t_CLOptions= array of t_CLOption;
  
  TProcedureNoArgCall=	procedure;
  TProcedureOneArgCall=	procedure(i:integer);
  TProcedureCOneArgCall=procedure(i:cint); cdecl;
  TFunctionNoArgCall=	function ():integer;
  TFunctionOneArgCall=	function (i:integer):integer;
  TFunctionOneArgCallR=	function (i:integer):real;
  TcFunctionOneArgCall=	function (i:cint):cint;
  TThFunctionOneArgCall=function (ptr:pointer):ptrint;
  TFunctionThreeArgCall=function (lvl:t_ErrorLevel; msgtype:MSG_Type_t; msg:string):longint;

  RPIreg64_t = record
	case typus:byte of
		$00: (Reg64:qword);
		$01: (RegLO32,RegHI32:longword);
  end;

  RING_BufferData_t = real;
  RING_Buffer_t = record
  	dcnt,bufsiz,			// data count
  	RDidx,WRidx:longint;	// read/write indx
  	buf: array of RING_BufferData_t;
  end;

  STAT_struct_t = record
    filled_up,
    statready:		boolean;
    useSampleDev,
    idxLast,idx:	longint;
  	SUMval,MINval,MAXval,MEANval,StdDev,
	old_avg,trend:	float;
	val_arr:		array of float;
  end;
    
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
   
  Thread_ClassPrio_t = (SCHED_OTHER,SCHED_FIFO,SCHED_RR,SCHED_BATCH,SCHED_ISO,SCHED_IDLE,SCHED_DEADLINE); 
  Thread_name_t=	string[16];

  Thread_Ctrl_ptr= ^Thread_Ctrl_t;
  Thread_Ctrl_t=record	 
	ThreadID:		TThreadID; //PtrUInt; 
	ThreadRunning,
	TermThread:		boolean;
	ThreadFunc:		TThFunctionOneArgCall;
	ThreadFlags:	s_rpimaintflags;
	ThreadTimeOut:	TDateTime;
	ThreadPrio,
	ThreadRetCode,
	ThreadProgressOld,
	ThreadProgress:	integer;
	ThreadInfo,
	ThreadCmdStr,
	ThreadRetStr:	string;
	UsrData:		array[0..4] of longword;
	ThreadPara:		array[0..4] of integer;
	ThreadParaStr:	array[0..4] of string;
  end;
  
  TL_prot_t=record
    TL_CS:		TRTLCriticalSection;
    TL:			TStringList;
    TL_modified,
    TL_initok:	boolean;
    TL_stamp:	TDateTime;
    TL_hash:	string;
  end;
  
  STR_prot_t=record
    STR_CS:	TRTLCriticalSection;
    STR:	string;
    STR_modified:boolean;
  end;
  
  ERR_MGMT_t = record
    addr:word;
	RDerr,WRerr,CMDerr,MAXerr,AutoReset_ms:longword;
	TSok,TSokOld,TSerr,TSerrOld:TDateTime;
	desc:string[RPI_hal_dscl];
  end;

  DBG_log_ptr= ^DBG_log_t;
  DBG_log_t=record
    DBGCallptr:TThFunctionOneArgCall;
    DBGDataptr:pointer;
    DbgThreadRunning:boolean;
    DbgRecTrig,DbgFMT,DbgTrigMode,DbgLogMode,DbgSeq,DBGlogID:longint;
    DbgRecordTime_ms:longword;
    DbgStartTime,DbgTime:qword;
    DbgTimeStamp,DbgNextWriteLog:TDateTime;
	DbgLogLvl,DbgLogRetLvl:T_ErrorLevel;
	DbgTL:TStringList;
	DBGlogTMode:TMode;
	DBGlogFilHDR,DBGlogDIR,DBGlogUSR,DBGlogGRP,
	DBGlogHDR,DBGlogLine:string;	
  end;
  
  watchdog_info_t = record
	options,						// Options the card/driver supports
	firmware_version:	longword;	// Firmware version of the card
	identity: array[0..31] of byte;	// Identity of the board
  end;
				
  watchdog_struct_t = record
  	NextTrigTime,
  	WDOGFire:	TDateTime;
  	RetrigAsync:boolean;
  	Hndl,
  	retival_msec,
  	LastBootStat,
  	ival_sec:	longint;
  	LastChanceHandler_ptr:TProcedureNoArgCall;
    info:		watchdog_info_t;
    devpath:	string;
    ThreadCtrl:	Thread_Ctrl_t;
  end;

  HAT_Struct_t = record
    uuid,vendor,product,snr:string;
    product_id,product_ver:longword;
    available,overwrite:boolean;
  end;

  RPI_TempRec_t=record
	Temp:		real;	// CPU GPU Temp
    TempLvl:	T_ErrorLevel; 
  end;
  RPI_Temps_t=record
//  Temp_CS:	TRTLCriticalSection;
//    TempIdx:	longint;				// points to max temp
    TempMaxObsTS,	TempMinObsTS:TDateTime;
    TempMaxObserved,TempMinObserved,
    TempCOOL,TempWARN,TempHOT,
  	TempMax:	real;
  	TempMaxLvl:	t_ErrorLevel;
  	TempMaxObservedNEW,TempMinObservedNEW:boolean;
  	LastUpdate:	TDateTime;
  	TempRec:	array of RPI_TempRec_t;
  	TempUnit,							// 'C &#x2103; 
  	HDRname,
  	SECTname:	string;
//  TempInfo:	string;
  end;
  
  RPI_FW_API_t = record
	hndl:longint;
  end;
  
  RPI_MBX_tag_t = packed record
	tag_id:		longword;
	buffer_size:longword;
	data_size:	longword;
	dev_id:		longword;
	val:		longword;
  end;
  
  RPI_MBX_msgPTR_t= ^RPI_MBX_msg_t;
  RPI_MBX_msg_t = packed record
	msg_size:	longword;
	request_code:longword;
	tag_id:		longword;
	buffer_size:longword;
	data_size:	longword;
	dev_id:		longword;
	val:		longword;
	end_tag:	longword;
  end;
    
  I2C_Bus_Info_t = record
    I2C_CS 			: TRTLCriticalSection;
    I2C_useCS		: boolean;
	I2C_funcs,
	I2C_speed		: longword;
  end;
  
  I2C_stringbuf_ptr = ^I2C_stringbuf_t;
  I2C_stringbuf_t = record
	str:string[c_max_Buffer];	// ShortString
  end;

  I2C_databuf_ptr = ^I2C_databuf_t;
  I2C_databuf_t = record
  	buf:	I2C_stringbuf_t;
	hdl: 	cint;
	test,reperr:boolean;
  end;
  
  I2C_msg_ptr = ^I2C_msg_t;
  I2C_msg_t = record
    addr:	word;
	flags:	word;
	len:	word;
	bptr:	pointer;
//	bptr:	I2C_stringbuf_ptr;
  end;
  
  I2C_rdwr_ioctl_data_ptr = ^I2C_rdwr_ioctl_data_t;
  I2C_rdwr_ioctl_data_t = record
    msgs:	I2C_msg_ptr;
	nmsgs:	longword;
  end;
  
  I2C_rdwr_mult_msgs_ptr = ^I2C_rdwr_mult_msgs_t;
  I2C_rdwr_mult_msgs_t = record
	errhdl: cint;
	busno:	longword;
	msgs:	array[0..(I2C_RDWR_IOCTL_MAX_MSGS-1)] of I2C_msg_t;
  end;
  
  HW_Usage_t = record
  	usecnt,usetimesec:longword;
  	dat:TDateTime;
  end;
  
  HW_DevicePresent_t = record
    hndl:integer;
    DevType:t_IOBusType;
    Xpresent:boolean;
    BusNum,HWAddr:integer;
    Manuf:t_Manu_flag; 
    descr:string[RPI_hal_dscl];
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
	pwm_freq_hz,
	pwm_freq_min,
	pwm_freq_max	: real;
  end;
  
  BEEP_ptr	   = ^BEEP_struct_t;
  BEEP_struct_t = record
    gpio			: longint;
    USRbrk			: boolean;
	cnt,
	High_ms,
	Low_ms			: longword;
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
	SIOspeedIdx		: byte;
	SIOinvLogic,
	initok,ein		: boolean;
	ThreadCtrl		: Thread_Ctrl_t;
	FRQ_freq_Hz,
	FRQ_freq_min,
	FRQ_freq_max	: real;
	FRQ_CTLIdx,
	FRQ_DIVIdx		: longword;
	PWM				: PWM_struct_t;
	portCapabilityFlags,
	portflags		: s_port_flags;
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
  
  FREQ_Determine_t = record
    fdet_enab:boolean;
	fSyncTime:TDateTime;
	fTurnRate_Hz:real;
	fcnt,fcntold,fdet_ms:longint;
  end;  
  
  StrobeStruct_t = record
	state:							t_Strobe_flag;
	modetog,OUTtrigger:				boolean;
	OUTstat,OUTstatold:				integer;
	strobeONtimer,strobetimer,
	strobeINTstartTimer,
	strobeOLDtimer,strobeINTtimer:	qword;
	seq,strobeON_us,strobeONmin_us,
	strobeINTmax_us,strobeINT_us:	int64;
	strobeDTYcycle:					real;
  end;
  
  ENC_ptr = ^ENC_struct_t;
  ENC_CNT_ptr=^ENC_CNT_struct_t;
  ENC_CNT_struct_t = record	  
    Handle:integer;
    ENC_activity,ENC_WasActive:boolean;
    switchcounter,switchcounterold,switchcountermax,
    switchlastpresstime,
    counter,counterold,countermark,countermax,cycles,cyclesold:longint;
    encsteps,enccycles,swsteps,Interval_ms:longint;
    enc,encold:real;
    fIntervalResetTime,DelayResetTime:TDateTime;
    activitymodedetect,
    steps_per_cycle:byte;
    kbdcode,kbdupcnt,kbddwncnt,kbdswitch:char;
    TurnRateStruct:FREQ_Determine_t;
  end; 
  ENC_struct_t = record					// Encoder data structure
    ENC_CS : TRTLCriticalSection;
	SyncTime: TDateTime;				// for syncing max. device queries
//  ENCptr:ENC_ptr; 
	ThreadCtrl:Thread_Ctrl_t;
	A_Sig,B_Sig,S_Sig:GPIO_struct_t;
	a,b,seq,seqold:word;
	deltaold,delta:longint;
	idxcounter,SwitchRepeatTime_ms,
	sleeptime_ms:longword;
	BEEP:BEEP_struct_t;
	ok,s2minmax:boolean;
	SwitchFiredSpecFunc:TProcedureNoArgCall;
	CNTInfo:ENC_CNT_struct_t;
	desc:string[RPI_hal_dscl];
  end;
  
  TRIG_ptr		= ^TRIG_struct_t;
  TRIG_struct_t = record
    TRIG_CS:	TRTLCriticalSection;
  	SyncTime:	TDateTime; 
	SyncTime_ms:longword;
	tim_ms:		longint;
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
    tx_nbits		: byte;
    rx_nbits		: byte;
    pad				: word;
  end;
  
  SPI_AddrMux_t = record
    AdrMuxEnable	: boolean;
    AdrCSgpio		: array[0..1] of longint;
  end;
  
  SPI_Bus_Info_t = record
    SPI_CS 			: TRTLCriticalSection;
    SPI_useCS		: boolean;
	SPI_maxspeed	: longword;
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
    
  PID_float_t=	real;
  PID_array_t=	array[0..2] of PID_float_t;
  
  PID_Method_t=	(	P_Default,PI_Default,PID_Default,
  					P_Oppelt,PI_Oppelt,PID_Oppelt,
  					P_ZiegNich,PI_ZiegNich,PID_ZiegNich,
  					P_SUM,PD_SUM,PI_SUM,PID_SUM,PI_SUM_Fast,PID_SUM_Fast,
					P_CHR_GSA,P_CHR_GFA,P_CHR_GS20,P_CHR_GF20,
					PI_CHR_GSA,PI_CHR_GFA,PI_CHR_GS20,PI_CHR_GF20,
					PID_CHR_GSA,PID_CHR_GFA,PID_CHR_GS20,PID_CHR_GF20,
					P_SAMAL_GSA,P_SAMAL_GFA,P_SAMAL_GS20,P_SAMAL_GF20,
					PI_SAMAL_GFA,PI_SAMAL_GF20,PI_SAMAL_GSA,PI_SAMAL_GS20,
					PID_SAMAL_GFA,PID_SAMAL_GF20,PID_SAMAL_GSA,PID_SAMAL_GS20);
					
  PID_Twiddle_t = record
    twiddle_LogColor,
    twiddle_LogLevel:	T_ErrorLevel;
	twiddle_on,
	twiddle_saved,
	twiddle_save:		boolean;
	twiddle_ID,
	twiddle_state,
	twiddle_idx,
	twiddle_intermax,
	twiddle_tolnoreachcnt,
	twiddle_iterations:	longint;
	twiddle_sum_dp,
	twiddle_sum_dps,
	twiddle_best_error:	PID_float_t;
	twiddle_tol,
	err,p,p0,dp,ps,dps:	PID_array_t;
	twiddle_repdt:		TDateTime;		
	twiddle_INI_sect,
	twiddle_INI_key:	string;
  end;
  
  PID_Det_t = record
	PIDMethod:PID_Method_t;
	SampleTimeAvg:PID_float_t;
	SampleTimeAdjFactor,
 	Ti,Td,
  	Ks,Te,Tb,Tsum:PID_float_t; 
  end;
  
  PID_Struct_t = record
	PID_nr:				longint;
	PID_cnt: 			longword;
	PID_SampleTime_us:	int64;			// micro seconds
	PID_ovr,
	PID_IntImprove,	
	PID_DifImprove,
	PID_LimImprove,
	PID_FirstTime,
	PID_UseSelfTuning:	boolean;
	PID_Time,
	PID_StartTime,
	PID_LastTime: 		timespec;
    PID_Integrated, 
    PID_IntegratedWindupResetValue,
    PID_SetPointLast,
    PID_SetPoint,		// r(t): SP:SetPoint:FŸhrungsgrš§e
    PID_ProcessValue,	// y(t): PV:ProcessValue:Regelgrš§e
    PID_ControlOut,		// u(t): ControlOut:Stellgrš§e
    PID_MinOutput,  	// ControlOut minimum, if ON
    PID_MaxOutput,		// ControlOut maximum, if ON
    PID_Error,
    PID_LastError,
    PID_PrevAbsError:	PID_float_t;
    PID_pid,
	PID_K,PID_KTa,
	PID_csv_Lims,
	PID_Lims,
	PID_Ksav:			PID_array_t;
    PID_Twiddle:		PID_Twiddle_t;
    PID_csv_TL:			TStringList;
    PID_csv_enable:		boolean;
    PID_csv_RECtime_ms:	word;
    PID_csv_SetPointMaximum:PID_float_t;	
    PID_csc_RECstop:	TDateTime;	
    PID_csv_fown,PID_csv_fgrp,
    PID_csv_fn:			string;
  end;

  TREND_Struct_t = record
    TREND_Indicator:		real;
    TREND_Avg,TREND_Val:	array[0..2] of real;
	TREND_IdxOld,TREND_Idx,
	TREND_Cnt:				longint;
  end;

  T_IniFileDesc = record
	inifilbuf:		TIniFile;
	ok:				boolean;	
	modifydate:		TDateTime;
	dfltflags:		s_BIOS_flags;
	dfltsection,
	inifilename:	string;	
  end;
  
  WAVE_RampShape_t = (LIN_Ramp,LIN_Triangle,LIN_SawTooth,LIN_Square,SINusoidal,S_Shape);
  WAVE_Array_t= array of real;
  WAVE_Signal_Struct_t = record
  	enable,
	up:		boolean;
	mode:	WAVE_RampShape_t; 
	idx,
	int_ms:	longint;
	timer:	TDateTime;
  end;
  
  cert_t = record
    ok:boolean;
    certtyp:Cert_Type_t;
	desc,filnam,id:string;
  end;
  cert_pack_t = record
	ok:		boolean;
	idx:	longint;
	packtyp:Cert_Type_t;
	desc,
	pwd:	string;
	cert:	array[CertPublic..CertCombined] of cert_t;	// 1:publicCert 2:privateKey 3:CaCert 4:CertCombined
  end;
   
  IP_Info_t = record
    stat,wireless:boolean;
    timestamp:TDateTime;
	alias,iface,ip4addr,ip6addr,hwaddr,gwaddr,nsaddr,domain,
	link,ssid,signal_link,signal_level,signal_quality,chan,freq,DNSname:string;
  end;
  
  IP_Infos_ptr = ^IP_Infos_t;
  IP_Infos_t = record
	idx:		longint;
    init,init1,
    samesubnet:	boolean;
    devlst,
    ip4ext1,ip4ext2,
    ip4ext,
    hostapd_extdev,
    hostname:	string;
    IP_Info: 	array[0..IP_infomax_c] of IP_Info_t;
  end;

  AlignmentSize_t = record
    c:char;
//    a:array[1..16] of byte;	// force data alignment to 32 byte
    b:array[1..15] of byte;
  end;
  
  HeapStat_t = record
  	lvl:			T_ErrorLevel;
	HeapStatAlloc: 	array[0..HeapStatMax_c] of longint;
	name:			string;
  end;
  
  ERR_Rec_t = record
	step:		longint; 
	title,msg:	string;
  end;
      
  TMR_struct_t = record
	tim_start,tim_ende:timespec;
	tim_ns,tim_ns_min,tim_ns_max:int64;
	cnt:int64;
  end;

  RPI_TMR_struct_t = record
	tim_start,tim_ende:qword;
	tim_us,tim_us_min,tim_us_max:int64;
	cnt:int64;
  end;
  
  DISTribution_t = record
  	siz,cnt:qword;
    vmin,vmax,step:real;
  range:array of longint;
//    range:array[0..3] of longint;
  end;
  
  CSV_array_t = array of string;

var
  dummy:AlignmentSize_t; // requires {$PACKRECORDS 32} 
msg:RPI_MBX_msg_t;	// 32 byte aligned
  mmap_arr:t_MemoryMapPtr;  
  CLOptions:t_CLOptions;
  CurlThreadCtrl:Thread_Ctrl_t;
  HighPrecisionMillisecondFactor:Int64=1000; 
  HighPrecisionMicrosecondFactor:Int64=1; 
  HighPrecisionTimerInit:boolean=false;
  terminateProg:boolean;
  RPI_MaintMinVersion,RPI_MaintMaxVersion,RTC3231_LastTemp:real;
  mem_fd:integer; 
  wdog:watchdog_struct_t;
  SDcard_root_hdl:byte;
  RPI_bType:byte;
  RPI_FreqARMFreq:longword;
  RTC3231_NextRead,LNX_UsrAuthModDateTime,RPI_ProgramStartTime,RPI_BootTime:TDateTime;
  _TZLocal:longint; _TZOffsetString:string[10]; _TZString:string[25];
  IniFileDesc:T_IniFileDesc;
  RpiMaintCmd:TIniFile;
  MSG_HUB_ptr,CURL_ProgressUpdateHook_ptr:TFunctionThreeArgCall;
  RPI_SignalHandlerHook_ptr:TProcedureCOneArgCall;
  SD_speedRD,MD5Hash4emptyString:string;
  
  USBDEVFS_RESET,
  SPI_IOC_RD_MODE,SPI_IOC_WR_MODE,SPI_IOC_RD_LSB_FIRST,SPI_IOC_WR_LSB_FIRST,
  SPI_IOC_RD_BITS_PER_WORD,SPI_IOC_WR_BITS_PER_WORD,SPI_IOC_RD_MAX_SPEED_HZ,
  SPI_IOC_WR_MAX_SPEED_HZ,IOCTL_TAG_PROPERTY,
  WDIOC_SETTIMEOUT,WDIOC_GETTIMEOUT,WDIOC_KEEPALIVE,WDIOC_GETBOOTSTATUS,
  WDIOC_GETSUPPORT,WDIOC_GETSTATUS:longword;
  
  RPI_ShutDown_RebootCall,RPI_ShutDown_Call,WDOG_LastChance_ptr:TProcedureNoArgCall;
  RPI_ShutDownMin_ms,RPI_ShutDownDebounce_ms:word; 
  RPI_ShutDown_struct:GPIO_struct_t;
  RPI_HW_initpart:s_initpart;
  
  HAT_Info:			HAT_Struct_t;
  IP_Infos:			IP_Infos_t;
  HS,WS,DS: 		HeapStat_t;
  RPI_Temps:		RPI_Temps_t;
  
  CertPack:		array[CertPackRPIMaint..
  					 	CertPackLast]	of cert_pack_t;
    
  SPI_AddrMux:	array[0..spi_max_dev]	of SPI_AddrMux_t;
  spi_bus: 		array[0..spi_max_bus]	of SPI_Bus_Info_t;
  spi_dev:		array[0..spi_max_bus,
					  0..spi_max_dev]	of SPI_Device_Info_t;
  spi_buf:		array[0..spi_max_bus,
					  0..spi_max_dev]	of SPI_databuf_t; 
  I2C_bus:		array[0..I2C_max_bus]	of I2C_Bus_Info_t; 
  I2C_buf:		array[0..I2C_max_bus]	of I2C_databuf_t;
  
  ENC_struct: 	array					of ENC_struct_t;
  TRIG_struct: 	array					of TRIG_struct_t;
  SERVO_struct: array					of SERVO_struct_t;
  ERR_MGMT: 	array					of ERR_MGMT_t;
  
  NGINX_TestContent:TStringList;
  
procedure AlignShow; 
function  RPI_HW_Start:boolean; // start all. GPIO,I2C and SPI
function  RPI_HW_Start(initpart:s_initpart):boolean; // start dedicated parts. e.g. RPI_HW_Start([InitGPIO,InitI2C,InitSPI]); 
function  RPI_HW_Start(initpart:s_initpart; p1,p2:string):boolean;
 
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
procedure I2C_ZIP_Test;
procedure MEM_SpeedTest;
procedure CLK_Test;
procedure BIOS_Test;		// shows the usages of a config file
procedure CL_Test;			// CommandLineParser test
procedure GetDateTimefromXMLTimeStamp_Test;
procedure call_external_prog_Test;
procedure DBGlog_Test;
procedure STAT_Test; 
procedure TST_Select_Item;
procedure TST_Trimme;
procedure DIST_Test;
procedure IPInfo_Test;
procedure RING_BufferTest;
procedure RFC822DateTimeTest;

function  _IOC (dir:byte; typ:char; nr,size:word):longword;
function  _IO  (typ:char; nr:word):longword; 
function  _IOR (typ:char; nr,size:word):longword;
function  _IOW (typ:char; nr,size:word):longword;
function  _IOWR(typ:char; nr,size:word):longword;

function  BIT_Get(v:byte;		  i:byte):boolean;
function  BIT_Get(v:word;		  i:byte):boolean;
function  BIT_Get(v:longword;	  i:byte):boolean;
function  BIT_Get(v:qword; 		  i:byte):boolean;

procedure BIT_Clr(var v:byte;	  i:byte);
procedure BIT_Clr(var v:word;	  i:byte);
procedure BIT_Clr(var v:longword; i:byte);
procedure BIT_Clr(var v:qword;	  i:byte);

procedure BIT_Set(var v:byte;	  i:byte);
procedure BIT_Set(var v:word;	  i:byte);
procedure BIT_Set(var v:longword; i:byte);
procedure BIT_Set(var v:qword;	  i:byte); 

procedure BIT_Put(var v:byte; 	  i:byte; b:boolean); 
procedure BIT_Put(var v:word;	  i:byte; b:boolean); 
procedure BIT_Put(var v:longword; i:byte; b:boolean); 
procedure BIT_Put(var v:qword;	  i:byte; b:boolean);

function  MSK_Get8		(bitnum:byte):byte; 
function  MSK_Get16		(bitnum:byte):word;
function  MSK_Get16_8	(bitnum:byte; var idxofs:byte):byte;
function  MSK_Get64_8	(bitnum:byte; var idxofs:byte):byte;
function  MSK_Get256_8	(bitnum:byte; var idxofs:byte):byte;

function  MSK2BitNum	(mask:qword):integer;

function  GetARRIdx(bracketset:byte; var aidx,algt:longint; var key:string):boolean;

function  BCM_REGAdr(idx:longword):longword; 
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
procedure STIM_show_regs;
function  RPI_WLANavailChan(cntry:string):string;
function  RPI_PWRCtrl(flags:s_PWRflags):integer;

Function  RPI_FW_property(req,tag:longword; tag_data:pointer; buf_size:byte):longint;
procedure RPI_FW_test;

procedure RPI_MBX_test;

function  ERR_NEW_HNDL(adr:word; descr:string; maxerrs,AutoResetMsec:longword):integer;  
function  ERR_MGMT_STAT(errhdl:integer):boolean;
function  ERR_MGMT_GetInfo(errhdl,modus:integer):longword;
function  ERR_MGMT_GetErrCnt(errhdl:integer):longword;
function  ERR_MGMT_GetMaxErrCnt(errhdl:integer):longword;
procedure ERR_MGMT_UPD(errhdl:integer; cmdcode,datalgt:integer; modus:boolean);
procedure Toggle_STATUSLED_very_fast;
 
procedure LED_Status    (ein:boolean);		// Switch Status-LED on or off

procedure HDMI_Switch(ein:boolean);			// switch HDMI on/off 

function  CLK_GetFreq(clksource:longword):real; // Hz
function  CLK_GetMinFreq:real; 
function  CLK_GetMaxFreq:real; 

function  OSC_Setup(_gpio:longint; pwm_freq_Hz,pwm_dty:real):longint;
procedure OSC_Write(_gpio,pwm_dutyrange:longint; pwm_dty:real);

function  TIM_Setup(timr_freq_Hz:real):real;
procedure TIM_Test; // 1MHz

procedure FRQ_SetStruct (var GPIO_struct:GPIO_struct_t);	// set default values
procedure FRQ_SetStruct (var GPIO_struct:GPIO_struct_t; freq_Hz:real);
procedure FRQ_SetStruct (var GPIO_struct:GPIO_struct_t; freq_Hz,freq_min,freq_max:real);
function  FRQ_Setup		(var GPIO_struct:GPIO_struct_t):boolean;
procedure FRQ_Switch	(var GPIO_struct:GPIO_struct_t; ein:boolean);

procedure PWM_SetStruct (var GPIO_struct:GPIO_struct_t);  // set default values
procedure PWM_SetStruct (var GPIO_struct:GPIO_struct_t; mode:byte; freq_Hz:real; dutyrange,startval:longword);
function  PWM_Setup     (var GPIO_struct:GPIO_struct_t):boolean;
procedure PWM_Write     (var GPIO_struct:GPIO_struct_t; value:longword); // value: 0-1023
procedure PWM_setClock  (var GPIO_struct:GPIO_struct_t); // same clock for PWM0 and PWM1. Needs only to be set once
procedure PWM_End		(var GPIO_struct:GPIO_struct_t);
function  PWM_GetDtyRangeVal(var GPIO_struct:GPIO_struct_t; DutyCycle:real):longword;
function  PWM_GetMinFreq(dutycycle:longword):real;
function  PWM_GetMaxFreq(dutycycle:longword):real;
function  PWM_GetMaxDtyC(freq:real):longword;
function  PWM_GetDRVal  (percent:real; dutyrange:longword):longword; 

procedure BEEP_SetStruct (var BEEP_struct:BEEP_struct_t; beepgpio:longint; beepcnt,beepHighms,beepLOWms:longword);
function  GPIO_BeepThread(BEEPstructPTR:pointer):ptrint;
procedure GPIO_Beep		 (var BEEP_struct:BEEP_struct_t);

procedure GPIO_ShowStruct(var GPIO_struct:GPIO_struct_t);
procedure GPIO_SetStruct(var GPIO_struct:GPIO_struct_t); // set default values
procedure GPIO_SetStruct(var GPIO_struct:GPIO_struct_t; num,gpionum:longint; desc:string; flags:s_port_flags);
procedure GPIO_Switch	(var GPIO_struct:GPIO_struct_t); // Read GPIOx Signal in Struct
procedure GPIO_Switch   (var GPIO_struct:GPIO_struct_t; switchon:boolean);
function  GPIO_SIO_Write(var GPIO_struct:GPIO_struct_t; cmd:string):longint;
function  GPIO_Setup    (var GPIO_struct:GPIO_struct_t):boolean;

function  GPIO_MAP_GPIO_NUM_2_HDR_PIN(gpio:longint; mapidx:byte):longint; // Maps GPIO Number to the HDR_PIN 
function  GPIO_MAP_GPIO_NUM_2_HDR_PIN(gpio:longint):longint;
function  GPIO_MAP_HDR_PIN_2_GPIO_NUM(hdr_pin_number:longint; mapidx:byte):longint; // Maps HDR_PIN to the GPIO Number 
function  GPIO_MAP_HDR_PIN_2_GPIO_NUM(hdr_pin_number:longint):longint;

procedure GPIO_set_HDR_PIN(hw_pin_number:longword;highlevel:boolean); // Maps PIN to the GPIO Header 
function  GPIO_get_HDR_PIN(hw_pin_number:longword):boolean; // Maps PIN to the GPIO Header 

function  GPIO_FCTOK(gpio:longint; flags:s_port_flags):boolean;
procedure GPIO_set_pin     (gpio:longword;highlevel:boolean); // Set RPi GPIO pin to high or low level; Speed @ 700MHz ->  0.65MHz
function  GPIO_get_PIN     (gpio:longword):boolean; // Get RPi GPIO pin Level is true when Pin level is '1'; false when '0'; Speed @ 700MHz ->  1.17MHz 
procedure GPIO_Pulse	   (gpio,pulse_ms:longword);
procedure GPIO_SIO_BBout   (gpio:longword; WRbuf:string; speedIdx:byte; invertLogic:boolean);

procedure GPIO_set_input   (gpio:longword);         // Set RPi GPIO pin to input  direction 
procedure GPIO_set_output  (gpio:longword);         // Set RPi GPIO pin to output direction 
procedure GPIO_set_ALT     (gpio:longword; altfunc:t_port_flags); // Set RPi GPIO pin to ALT0..ALT5 
procedure GPIO_set_PINMODE (gpio:longword; portfkt:t_port_flags);
procedure GPIO_set_PAD	   (gpio:longword; flgs:s_port_flags);
procedure GPIO_set_PAD	   (gpio:longword; noSLEW,noHYST:boolean; drivestrength:byte);
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
function  GPIO_PortCapabilityFlags(gpio:longint):s_port_flags;
function  GPIO_PortFlags2String(flgs:s_port_flags):string;
function  GPIO_String2PortFlags(flagstring:string):s_port_flags;

procedure FREQ_CounterReset	(var FREQ_Struct:FREQ_Determine_t);
procedure FREQ_InitStruct	(var FREQ_Struct:FREQ_Determine_t; detint_ms:longint);
procedure FREQ_DetTurnRate	(var FREQ_Struct:FREQ_Determine_t; steps:longint);

function  ENC_GetHdl		(descr:string):byte;
procedure ENC_InfoInit		(var CNTInfo:ENC_CNT_struct_t);
function  ENC_Setup(hdl:integer; stick2minmax:boolean; ctrpreset,ctrmax,stepspercycle:longword; beepergpio:integer):boolean;
procedure ENC_End			(hdl:integer);
function  ENC_GetVal		(hdl:integer; ctrsel:integer):real; 
function  ENC_GetVal		(hdl:integer):real; 
function  ENC_GetValPercent	(hdl:integer):real; 
function  ENC_GetSwitch		(hdl:integer):real;
function  ENC_GetCycles     (hdl:integer):real; 
function  ENC_GetMark		(hdl:integer):real;
function  ENC_SetMark		(hdl:integer):real;
function  ENC_WasActive	    (hdl:integer):boolean;

function  ENC_GetCounter	(var ENCInfo:ENC_CNT_struct_t):boolean;
procedure ENC_IncEncCnt		(var ENCInfo:ENC_CNT_struct_t; cnt:integer);
procedure ENC_IncSwCnt		(var ENCInfo:ENC_CNT_struct_t; cnt:integer);
  
function  TRIG_Reg(gpio:longint; descr:string; flags:s_port_flags; synctim_ms:longword):integer;
procedure TRIG_End(hdl:integer); 
procedure TRIG_SetValue(hdl:integer; timesig_ms:longint);
function  TRIG_GetValue(hdl:integer; var timesig_ms:longint):integer;

procedure SERVO_Setup(var SERVO_struct:SERVO_struct_t; 
						HWPinNr,nr,maxval,
						dcmin,dcmid,dcmax:longword; 
						angmin,angmid,angmax,speed:longint;
						desc:string; freq:real; flags:s_port_flags);
procedure SERVO_SetStruct(var SERVO_struct:SERVO_struct_t; dty_min,dty_mid,dty_max:longword; ang_min,ang_mid,ang_max,speed:longint);
procedure SERVO_Write(var SERVO_struct:SERVO_struct_t; angle:longint; syncwait:boolean);
procedure SERVO_End(var SERVO_struct:SERVO_struct_t);

function  BIOS_GetIniFilename:string;
procedure BIOS_ReadIniFile(fname:string);
procedure BIOS_EndIniFile;
function  BIOS_CacheUpdate:boolean;
procedure BIOS_CacheUpdate(upd:boolean);

function  BIOS_GetIniNum(section,name:string; flgs:s_BIOS_Flags; default,minval,maxval:real):real;
function  BIOS_GetIniNum(section,name:string; default,minval,maxval:real):real;
function  BIOS_GetIniNum(name:string; default,minval,maxval:real):real;

function  BIOS_GetIniString(name,default:string):string;
function  BIOS_GetIniString(name,default:string; flgs:s_BIOS_Flags):string;
function  BIOS_GetIniString(section,name,default:string):string;
function  BIOS_GetIniString(section,name,default:string; flgs:s_BIOS_Flags):string;

function  BIOS_SetIniString(name,value:string):boolean;	
function  BIOS_SetIniString(section,name,value:string):boolean;	
function  BIOS_SetIniString(section,name,value:string; flgs:s_BIOS_Flags):boolean;
function  BIOS_SetDelIniString(section,name,value:string; flgs:s_BIOS_Flags):boolean;

function  BIOS_DeleteKey(section,name:string):boolean;
procedure BIOS_EraseSection(section:string);
procedure BIOS_SetDfltSection(section:string);
procedure BIOS_SetDfltFlags(flags:s_BIOS_flags);
procedure USAGE_Init(nr:byte; var struct:HW_Usage_t; sect,key:string);

function  RPI_lsbrel:string;// Raspbian GNU/Linux 11 (bullseye)
function  RPI_OSrev:string;	// 11.0
function  RPI_snr :string; 	// 0000000012345678 
function  RPI_hw  :string; 	// BCM2708
function  RPI_fw  :string; 	// 2018-02-09T14:22:56
function  RPI_uname:string;	// Linux pump 4.14.18-v7+ #1093 SMP Fri Feb 9 15:33:07 GMT 2018 armv7l GNU/Linux
function  RPI_machine:string;// armv7l
function  RPI_proc:string; 	// ARMv6-compatible processor rev 7 (v6l) 
function  RPI_mips:string; 	// 697.95 
function  RPI_feat:string; 	// swp half thumb fastmult vfp edsp java tls 
function  RPI_rev :string; 	// rev1;256MB;1000002 
function  RPI_freq:string; 	// 700000;700000;900000;Hz  	
function  RPI_Volt:string;	// core:1.2000V;sdram_c:1.2000V;sdram_i:1.2000V;sdram_p:1.2250V
function  RPI_FREQs:string;	// arm:600000000;core:250000000;h264:250000000;isp:250000000;...
function  RPI_whoami:string;
procedure RPI_FreqARMGet;
function  RPI_ThrottleDesc:string; //under-voltage;arm frequency capped...
procedure RPI_ThrottleGet;
function  RPI_ThrottleThread:ptrint;
function  RPI_revnum:real; // 0:error
function  RPI_gpiomapidx:byte; // 1:rev1; 2:rev2; 3:B+; 0:error 
function  RPI_cores:longint;
function  RPI_BCM2835:boolean;
function  RPI_BCM2835_GetNodeValue(node:string; var nodereturn:string):longint;
function  RPI_status_led_GPIO:byte;	// give GPIO_NUM of Status LED
function  RPI_GetPrecisionCounter_us:qword;
procedure RPI_SetTimeOut_us(var qTimer:qword; Retrig_us:longword); // depricated
function  RPI_SetTimeOut_us(Retrig_us:longword):qword;
function  RPI_SetTimer_us(var qTimerIN:qword; Retrig_us:longword):qword;
function  RPI_TimeElapsed_us(var qTimer:qword):boolean;
function  RPI_TimeElapsed_us(var actualqTimer,qTimer:qword; Retrig_us:longword):boolean;
function  RPI_MicroSecondsBetween(qTimer1,qTimer2:qword):int64;
procedure RPI_TMR_Init(var RPI_TMR_struct:RPI_TMR_struct_t);
procedure RPI_TMR_GetStartTime(var RPI_TMR_struct:RPI_TMR_struct_t);
procedure RPI_TMR_GetEndTime(var RPI_TMR_struct:RPI_TMR_struct_t);
function  RPI_I2C_BRadj(i2c_speed_kHz:longint):longint;
function  RPI_I2C_busnum(func:byte):byte; // get the I2C busnumber, where e.g. the general purpose devices are connected. This depends on rev1 or rev2 board . e.g. RPI_I2C_busnum(RPI_I2C_general_purpose_bus_c) 
function  RPI_I2C_busgen:byte;  // general purpose bus
function  RPI_I2C_bus2nd:byte;  // 2.nd I2C bus
function  RPI_I2C_GetSpeed(bus:byte):longword;
function  RPI_I2C_GetFuncs(bus:byte):longword;
function  RPI_I2C_ChkFuncs(bus:byte; funcs:longword):boolean;
function  RPI_I2C_ChkDev(bus,adr:byte):integer;
function  RPI_SPI_GetSpeed(bus:byte):longint;
function  RPI_hdrpincount:byte; // connector_pin_count on HW Header
function  RPI_GetBuildDateTimeString:string;
function  RPI_GetBuildDateTime:TDateTime;
procedure RPI_show_cpu_info;
procedure RPI_MaintSetVersions(versmin,versmax:real); 
procedure RPI_MaintDelEnv;
procedure RPI_MaintSetEnvExec(EXECcmd:string);
procedure RPI_MaintSetEnvFTP(FTPServer,FTPUser,FTPPwd,FTPLogf,FTPDefaults:string);
procedure RPI_MaintSetEnvUPL(UplSrcPackageRemark,UplSrcFiles,UplDstDir,UplLogf:string);
procedure RPI_MaintSetEnvDWN(DwnSrcDir,DwnlSrcFiles,DwnDstDir,DwnLogf:string);
procedure RPI_MaintSetEnvUPD(UpdPkgSrcFile,UpdPkgDstDir,UpdPkgDstFile,UpdPkgMaintDir,UpdPkgLogf:string);
function  RPI_Maint(UpdFlags:s_rpimaintflags; var CurlThCtl:Thread_Ctrl_t):integer;
function  RPI_INFO_Split(info:string; var labl,valu:string):boolean;
function  RPI_cxt_GPIOopts(flgs:s_port_flags):string;
function  RPI_config(raspicmd:t_RPI_config; par1,par2:string; var resultstring:string):integer; 
function  RPI_Temp(logmsg:boolean):T_ERRORLevel;
procedure TEMP_Create(var TempStruct:RPI_Temps_t; section,HDR_name,Units:string; ARRlgt:word);
procedure TEMP_Free(var TempStruct:RPI_Temps_t);
procedure TEMP_SaveLimits(var TempStruct:RPI_Temps_t);
procedure TEMP_LoadLimits(var TempStruct:RPI_Temps_t);

procedure HAT_EEprom_Map(tl:TStringList; hwname,uuid,vendor,product:string; prodid,prodver,gpio_drive,gpio_slew,gpio_hysteresis,back_power:word; useDefault,EnabIO:boolean);
procedure HAT_EEprom_Map_Test; 
function  HAT_GetInfo:boolean;
function  HAT_GetInfo(ovrwrt:boolean; duuid,dvendor,dproduct,dsnr:string; dpid,dpver:longword):boolean;
procedure HAT_ShowStruct;
procedure HAT_GetStructInfo(HAT_INFO_tl:TStringList; lgt:byte);
function  HAT_vendor:string;	
function  HAT_product:string; 	
function  HAT_product_id:string; 
function  HAT_product_ver:string;
function  HAT_uuid:string; 
function  HAT_custom(tl:TStringList; const keys:string):string;
function  HAT_custom(tl:TStringList; const keys,dflts:string):string;
procedure HAT_Info_Test;

function  USB_Reset(buspath:string):integer; // e.g. USB_Reset('/dev/bus/usb/002/004');
function  MapUSB(devpath:string):string;     // e.g. MapUSB('/dev/ttyUSB0') -> /dev/bus/usb/002/004

procedure I2C_show_struct (busnum:byte);
procedure I2C_Display_struct(busnum:byte; comment:string);
procedure HW_IniInfoStruct(var DeviceStruct:HW_DevicePresent_t);
procedure HW_SetInfoStruct(var DeviceStruct:HW_DevicePresent_t; DevTyp:t_IOBusType; BusNr,HWAdr:integer; ManufType:t_Manu_flag; dsc:string);

function  I2C_HWpresent(var DeviceStruct:HW_DevicePresent_t):boolean;
function  I2C_HWT(var DeviceStruct:HW_DevicePresent_t; bus,adr,lgt:word; ManufType:t_Manu_flag; cmds:string; Handle:integer; rv1,nv1,nv2,dsc:string):boolean;
function  I2C_HWT(var DeviceStruct:HW_DevicePresent_t; bus,adr,lgt:word; ManufType:t_Manu_flag; cmds:string; Handle:integer; rv1,nv1,nv2,dsc,dsc2:string):boolean;
function  I2C_HWSpeedT(var DeviceStruct:HW_DevicePresent_t; lgt:word; loops:longword; cmds,dsc:string):real;
function  I2C_HWSpeedT(BusNum,HWaddr,rdlgt:word; loops:longword; cmds,dsc:string):real;

procedure I2C_EnterCriticalSection(busnum:byte);
procedure I2C_LeaveCriticalSection(busnum:byte); 

procedure I2C_init_ROOTmsg	(var rdwr:I2C_rdwr_ioctl_data_t; msgptr:I2C_msg_ptr; msgcnt:longword);
function  I2C_xfer			(var rdwr:I2C_rdwr_ioctl_data_t; var multmsgs:I2C_rdwr_mult_msgs_t):integer;
procedure I2C_prep_IOmsg	(var rdwr:I2C_rdwr_ioctl_data_t; var multmsgs:I2C_rdwr_mult_msgs_t; baseadr:word; const WRbuf:string; WRflgs:word; var RDbuf:I2C_stringbuf_t; RDflgs,RDlen:word);
procedure I2C_show_MULTmsgs	(var rdwr:I2C_rdwr_ioctl_data_t; var multmsgs:I2C_rdwr_mult_msgs_t);
procedure I2C_init_MULTmsgs	(var multmsgs:I2C_rdwr_mult_msgs_t; busnum:word; errhndl:integer; wipe:boolean);

function  I2C_bus_WrRd		(busnum,baseadr:word; const WRbuf:string; WRflgs:word; var RDbuf:I2C_stringbuf_t; RDflgs:word; RDlen:byte; errhdl:integer):integer;
function  I2C_string_read	(busnum,baseadr:word; const WRbuf:string; RDlen:byte; errhdl:integer; var RDbuf:I2C_stringbuf_t):integer;
function  I2C_string_read	(busnum,baseadr:word; const WRbuf:string; RDlen:byte; errhdl:integer; var RDbuf:string):integer;
function  I2C_string_write	(busnum,baseadr:word; const WRbuf:string; errhdl:integer):integer; 
function  I2C_ChkBusAdr		(busnum,baseadr:word):boolean; 

//		** old I2C functions, pls. use above only. Just for compatibility reasons
function  I2C_byte_write	(busnum,baseadr,basereg:word; data:byte; errhdl:integer):integer; 
function  I2C_byte_read		(busnum,baseadr,basereg:word; errhdl:integer):byte; 
function  I2C_word_write	(busnum,baseadr,basereg:word; data:word; flip:boolean; errhdl:integer):integer; 
function  I2C_word_read		(busnum,baseadr,basereg:word; flip:boolean; errhdl:integer):word; 
function  I2C_string_read	(busnum,baseadr,basereg:word; RDlen:byte; errhdl:integer; var RDbuf:string):integer; 
function  I2C_string_write	(busnum,baseadr,basereg:word; WRbuf:string; errhdl:integer):integer;  
//function  I2C_bus_read    (busnum,baseadr,basereg:word; len:byte; errhdl:integer):integer;
//function  I2C_bus_write   (busnum,baseadr:word; errhdl:integer):integer;
function  oldI2C_string_read(busnum,baseadr,basereg:word; len:byte; errhdl:integer; var outs:string):integer;
function  oldI2C_string_read(busnum,baseadr:word; cmds:string; len:byte; errhdl:integer; var outs:string):integer; 
function oldI2C_string_write(busnum,baseadr:word; datas:string; errhdl:integer):integer; 
function oldI2C_string_write(busnum,baseadr,basereg:word; datas:string; errhdl:integer):integer;
// END	** old functions

function  SPI_HWpresent(var DeviceStruct:HW_DevicePresent_t):boolean;
function  SPI_HWT(var DeviceStruct:HW_DevicePresent_t; bus,adr,lgt:word; ManufType:t_Manu_flag; cmds:string; Handle:integer; rv1,nv1,nv2,dsc:string):boolean;
function  SPI_Dev_Init(busnum,devnum,bpw,cs_change:byte; mode,maxspeed_hz:longword; delay_usec:word):boolean;
function  SPI_Dev_Init(busnum,devnum:byte):boolean;
function  SPI_ClkWrite(spi_hz:real):longword;
procedure SPI_SetDevErrHndl(busnum,devnum:byte; errhdl:integer);
procedure SPI_EnterCriticalSection(busnum:byte);
procedure SPI_LeaveCriticalSection(busnum:byte);
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
procedure SPI_AdrMuxInit(CSnum,adr0gpio,adr1gpio:longint);
procedure SPI_AdrMux(CSnum,adr:byte);
procedure SPI_AdrMux(adr:byte);

procedure eeprom_SetAddr(devaddr:word);
function  eeprom_write_page(startadr:word; datas:string):integer;
function  eeprom_read_page(startadr:word; len:byte; var outs:string):integer;

function  Thread_Start		(var ThreadCtrl:Thread_Ctrl_t; funcadr:TThreadFunc; paraadr:pointer; delaymsec:longword; prio:integer):boolean;
function  Thread_End  		(var ThreadCtrl:Thread_Ctrl_t; waitmsec:longword):boolean;
procedure Thread_InitStruct0(var ThreadCtrl:Thread_Ctrl_t);
procedure Thread_InitStruct	(var ThreadCtrl:Thread_Ctrl_t);
procedure Thread_InitStruct2(var ThreadCtrl:Thread_Ctrl_t; ThFunc:TThFunctionOneArgCall);
procedure Thread_SetName(name:string); 
procedure Thread_ShowStruct(var ThreadCtrl:Thread_Ctrl_t);   
procedure SetTimeOut (var EndTime:TDateTime;TimeOut_ms:Int64);
function  TimeElapsed(var EndTime:TDateTime;Retrig_ms:Int64):boolean;
function  TimeElapsed(EndTime:TDateTime):boolean;
procedure SetTimeOut_us (ptspec_start,ptspec_end:Ptimespec; Retrig_us:int64);
procedure SetTimeOut_us (ptspec:Ptimespec; Retrig_us:int64);
procedure SetTimeSpec	(ptspec:Ptimespec; sec,nsec:int64);
function  TimeElapsed_us(ptspec:Ptimespec):boolean;
function  TimeElapsed_us(ptspec:Ptimespec; Retrig_us:int64):boolean;
procedure TimeStrobeInit(var StrobeStruct:StrobeStruct_t; const ID,strobINT_us:int64);
procedure TimeStrobeDuty(var StrobeStruct:StrobeStruct_t; dutycycle:real);
procedure TimeStrobeDutyAsyn(var StrobeStruct:StrobeStruct_t; dutycycle:real);
procedure TimeStrobeMode(var StrobeStruct:StrobeStruct_t; const modi:s_Strobe_flag);
procedure TimeStrobeMode(var StrobeStruct:StrobeStruct_t; const modi:s_Strobe_flag; const strob_us:int64);
procedure TimeStrobeAsyn(var StrobeStruct:StrobeStruct_t; const modus:t_Strobe_flag);
function  TimeStrobe	(var StrobeStruct:StrobeStruct_t):integer;
function  TimeStrobeShowStr(var StrobeStruct:StrobeStruct_t; msg:string):string;
procedure TimeStrobeShow(var StrobeStruct:StrobeStruct_t; lvl:T_ErrorLevel; msg:string);

procedure LOGSAY_tst;
procedure Log_Writeln(typ:T_ErrorLevel;msg:string);  // writes to STDERR
procedure Log_Writeln(typ,col:T_ErrorLevel;msg:string);
procedure LOG_ShowStringList(typ:T_ErrorLevel; ts:TStringList); 
procedure LOG_ShowStringList(typ1,typ2:T_ErrorLevel; ts:TStringList); 
function  LOG_Level:t_ErrorLevel;    
procedure Log_Level(level:t_ErrorLevel);
procedure LOG_LevelSave; 
procedure LOG_LevelRestore; 
procedure LOG_LevelColor(enab:boolean);
function  LOG_GetEndMsg(comment:string):string;
function  LOG_GetVersion(version:real):string; 
function  LOG_Get_LevelStringShort(lvl:T_ErrorLevel):string;
procedure LOG_SAY_Level(mask:byte);	
procedure SAY   (typ:T_ErrorLevel; msg:string); // writes to STDOUT
procedure SAY	(typ,col:T_ErrorLevel;msg:string);
procedure SAY   (typ:T_ErrorLevel; const msg:string; const params:array of const);overload;
procedure SAY_TL(typ:T_ErrorLevel; tl:TStringList); 
procedure SAY_Level(level:t_ErrorLevel); 

procedure DBGlog_Set	(var dbgstruct:dbg_log_t; logLVL:T_ErrorLevel; logMode,trgMode,resFMT:longint; DbgRecordTime:longword);
procedure DBGlog_Start	(var dbgstruct:dbg_log_t);
procedure DBGlog_Open	(var dbgstruct:dbg_log_t; LOGid:longint; LOGhdr,LOGfilhdr,LOGdir,LOGusr,LOGgrp:string; LOGtmode:TMode; HandlerAdr:TThFunctionOneArgCall; DataAdr:pointer);
procedure DBGlog_Close	(var dbgstruct:dbg_log_t);
function  DBGlog_WriteFileThread(ptr:pointer):ptrint;

function  ERR_string (var ERR_Rec:ERR_Rec_t):string;
procedure ERR_SetStep(var ERR_Rec:ERR_Rec_t; errnr:longint); 
procedure ERR_SetStep(var ERR_Rec:ERR_Rec_t; errnr:longint; errmsg:string); 
procedure ERR_SetStep(var ERR_Rec:ERR_Rec_t; errnr:longint; errtitle,errmsg:string); 

procedure DUMP_CallStack(hdr:string);
procedure DUMP_ExceptionCallStack(hdr:string; E:Exception);
procedure DUMP_ExceptionCallStack(hdr:string; E:Exception; haltprog:boolean);

function  MSG_HUB(lvl:t_ErrorLevel; msgtype:MSG_Type_t; msg:string):longint;

function  IPInfo_GetIPAdr(iface:string; var ipaddr:string; ip4:boolean):boolean;
function  IPInfo_GetMACAdr(iface:string; var hwaddr:string):boolean;
function  IPInfo_GetHostName:string;
function  IPInfo_GetDomainName(iface:string):string;
function  IPInfo_GetDomainName:string;
function  IPInfo_GetMainDomainName:string;
function  IPInfo_GetWLANSignal(iface:string):longint; 	// 999,0-100
function  IPInfo_GetWLANSigDB(iface:string):longint; 	// 999,-100..0
function  IPInfo_iface(aliasname:string):string;
function  IPInfo_IsOnline(ip4:boolean):boolean;
function  IPInfo_AddrExt(ip4:boolean):string;
function  IPInfo_Addr4(iface:string):string;
function  IPInfo_Addr6(iface:string):string;
function  IPInfo_MACAddr(iface:string; fmt:byte):string;
function  IPInfo_GetInterfaceName(intidx:longint):string;
function  IPInfo_GetIdx(intface:string):longint;
procedure IPInfo_GetOS;	// force OS read
procedure IPInfo_GetOS(var IPInfos:IP_Infos_t);
function  IPInfo_Wait:boolean;
function  IPInfo_Wait1:boolean;
procedure IPInfo_Show(lvl:T_ErrorLevel; var IPInfo:IP_Info_t);
procedure IPInfos_Show(lvl:T_ErrorLevel; var IPInfos:IP_Infos_t);

function  IP4AddrValid(ipstr:string):boolean;
function  IP4AddrListValid(ipliststr:string):boolean;
function  IP6AddrValid(ipstr:string):boolean;
function  IP6AddrListValid(ipliststr:string):boolean;
function  IPAddrListValid(ipliststr:string):boolean;
function  IP4AddrsInSameSubnet(ip4adr1,ip4adr2:string):boolean;

function  GetHostNameOS:string;
procedure Get_SDcard_RDSpeed;
function  MAC_isRPI(macsubstr:string):boolean;

procedure LNX_sudo(sudouse:boolean);
function  LNX_sudo:boolean;
function  LNX_GetFBdev(dflt:string):string;
function  LNX_RTC3231_ReadTemp:real;
function  LNX_IsMount(mntpoint:string):boolean;
function  LNX_ProgInstalled(progname:string):boolean;
function  LNX_ParSET(filnam,parnam,parval:string):integer;
function  LNX_ParGET(filnam,parnam:string; var parval:string):integer;
function  LNX_ParLinEXIST(filnam,parstr:string):boolean;
function  LNX_GetProcessNumsByName(processname:string):string;
procedure LNX_KillProcesses(processlist:string; signal:word);
function  LNX_StrMod(part:byte; mode:TMode):string;
function  LNX_chmod(filename:string; mode:TMode):cint;
function  LNX_chowngrp(filename:string; owner,group:string):integer;
function  LNX_chowngrpmod(filename:string; owner,group:string; mode:TMode):integer;
procedure LNX_GetUsrPwdString(StrList:TStringList; pwdfile,usrlst:string; carveflds:longint);
function  LNX_UpdPwdFile(pwdfile,usr,pwd:string):integer;
function  LNX_ChkUsrPwdValid(usr,pwd,pwddefault:string):integer;
function  LNX_ChgUsrPwd(usr,usrreq,pwd,pwd2,pwddflt,pwdold:string; PWD_OLDsameNEW:boolean; var msg:string):integer;
function  LNX_ChgUsrPwd(usr,pwd:string; var msg:string):integer;
function  LNX_GetRandomAccessToken(typ:longint):string;
function  LNX_GetTZList(ts:TStringList; fmt:byte):integer;
function  LNX_GetISOquery(ts:TStringList; opts:string):integer;
function  LNX_GetBase64String(str:string):string;
function  LNX_GetNewestFile(filnampat:string):string;
function  LNX_LinkFile(filnam,linknam:string):integer;
function  LNX_tarSAV(target,fillst:string; flags:s_rpimaintflags):longint;
function  LNX_tarRST(target,fillst:string; flags:s_rpimaintflags):longint;
function  LNX_CertFormatTyp(certtyp:Cert_Type_t):string;
function  LNX_CertIDget(filnam:string; certtyp:Cert_Type_t; idouttyp:Cert_Type_t; var id:string):boolean;
procedure LNX_CertIDtest;
procedure LNX_CertInit(var certstruct:cert_t);
function  LNX_CertReg(var certstruct:cert_t; certfil:string; certtype:Cert_Type_t):boolean;
procedure LNX_CertPackShow(lvl:T_ErrorLevel; var certpack:cert_pack_t);
procedure LNX_CertInitPack(var certpack:cert_pack_t; num:longint); 
function  LNX_CertStartPack(var certpack:cert_pack_t; descr,pubcertfil,privkeyfil,cacertfil,combinedfil,passwd:string; certpacktyp:Cert_Type_t):boolean;
function  LNX_EncryptFile(filpubkey,filnam,ext:string; flags:s_rpimaintflags):integer;
function  LNX_DecryptFile(filprivkey,filnam,ext:string; flags:s_rpimaintflags):integer;
function  LNX_RemoveOldFiles(path2files:string; days:longint):integer;
function  LNX_RemoveFilesKeepLatest(fnhdr:string; uniqcnt:integer):integer;
function  LNX_ShellESC(s:string):string;
procedure LNX_ADD2Crontab(cmd:string);
function  LNX_ErrDesc(errno:longint):string;
function  LNX_SetDateTimeUTC(utc:TDateTime):integer;
function  LNX_SetDateTimeUTC2(utc:TDateTime; hwclock:boolean):integer;
function  LNX_WDOG(wdog_action:t_rpimaintflags; p1:longint):longint;
function  LNX_WDOG(wdog_action:t_rpimaintflags):longint; 
function  LNX_SSHFSmount(site,pwd,mnt:string; var err:string):integer;

function  BTLE_StartBeaconURL(url:string):boolean;
function  BTLE_StartBeaconURL(url:string; TXPower:integer):boolean;
function  BTLE_StopBeacon:boolean;
procedure BT_PrettyHostName(hnam:string);

procedure MinMaxAdj(var value:real; valmin,valmax:real);
function  Limits(var value:int64; minvalue,maxvalue:int64):int64;
function  Limits(var value:longint; minvalue,maxvalue:longint):longint;
function  Limits(var value:longword; minvalue,maxvalue:longword):longword;
function  Limits(var value:single; minvalue,maxvalue:single):single;
function  Limits(var value:real; minvalue,maxvalue:real):real;
function  InLimits(value,minvalue,maxvalue:real):boolean;
function  MinMax(value:int64; var minvalue,maxvalue:int64):integer;
function  MinMax(value:longint; var minvalue,maxvalue:longint):integer;
function  MinMax(value:longword; var minvalue,maxvalue:longword):integer;
function  MinMax(value:real; var minvalue,maxvalue:real):integer;
procedure STAT_Open(var stats:STAT_struct_t; arrsize:word);
procedure STAT_Close(var stats:STAT_struct_t);
procedure STAT_Reset(var stats:STAT_struct_t);
function  STAT_Inject(var stats:STAT_struct_t; newval:float):boolean;
function  STAT_Str(var stats:STAT_struct_t; vk,nk:byte):string;
procedure HeapStatINI(var struct:HeapStat_t; HSname:string; indentcnt:byte; replvl:T_ErrorLevel);
procedure HeapStat(var struct:HeapStat_t; idx:longint);
procedure RB_Open (var struct:RING_Buffer_t; siz:word; inipat:RING_BufferData_t);
procedure RB_Close(var struct:RING_Buffer_t);
function  RB_RD(var struct:RING_Buffer_t; var dataOUT:RING_BufferData_t):boolean;
function  RB_WR(var struct:RING_Buffer_t; dataIN:RING_BufferData_t):boolean;

function  CL_Compose(cmdLine:string):string; 	
function  CL_Parse  (cmdLine:string):t_CLOptions; 
function  CL_OptGiven(var cl_opts:t_CLOptions; opt:string):integer;
 
function  FileAccessible(filnam:string):boolean;
procedure SetTextCol(typ:T_ErrorLevel);
procedure UnSetTextCol;
function  Upper(const s : string) : String; 
function  Lower(const s : string) : String;
function  Bool2Num(b:boolean) : byte;
function  Bool2Str(b:boolean) : string; 
function  Bool2LVL(b:boolean) : string; 	 
function  Bool2Dig(b:boolean) : string; 
function  Bool2Swc(b:boolean) : string;	
function  Bool2DIR(b:boolean) : string; 
function  Bool2OC (b:boolean) : string;
function  Bool2YN (b:boolean) : string;
function  Bool2YNS(b:boolean) : string;
function  Bool2PF (b:boolean) : string;
function  Bool2EA (b:boolean) : string;
function  Bool2eas(b:boolean) : string;
function  Bool2UpDown(b:boolean):string;
function  TimeSpec2Str(ptspec:Ptimespec):string;
function  TimeSpec2Num(ptspec:Ptimespec):real;
function  TimeSpec2Num_ns(ptspec:Ptimespec):int64;	
function  Str2Bool(s:string):boolean;
function  Str2Bool(s:string; var ein:boolean):boolean;
function  Num2Limit(var Value:real; MinOut,MaxOut:real):boolean;
function  Num2Bool(num:int64):boolean;
function  Num2Bool(num:real):boolean;
function  Num2Str(num:int64):string; 
function  Num2Str(num:longint):string; 
function  Num2Str(num:longword):string;	
function  Num2Str(num:real;nk:byte):string;
function  Num2Str(num:int64;lgt:byte):string;
function  Num2Str(num:longint; lgt:byte):string;
function  Num2Str(num:longword;lgt:byte):string;
function  Num2Str(num:qword;lgt:byte):string;
function  Num2Str(num:real;lgt,nk:integer):string; 
function  Num2DtyStr(dty:real):string; 
function  Trend2Ch(num:longint):char; 
function  Str2Num(s:string; var num:byte):boolean;
function  Str2Num(s:string; var num:smallint):boolean;
function  Str2Num(s:string; var num:int64):boolean;
function  Str2Num(s:string; var num:qword):boolean;
function  Str2Num(s:string; var num:longint):boolean;
function  Str2Num(s:string; var num:longword):boolean;
function  Str2Num(s:string; var num:real):boolean; 
function  Str2Num(s:string; var num:extended):boolean;
procedure Str2Num(s:string; var num:byte; dflt:byte);
procedure Str2Num(s:string; var num:smallint; dflt:smallint);
procedure Str2Num(s:string; var num:int64; dflt:int64);
procedure Str2Num(s:string; var num:qword; dflt:qword);
procedure Str2Num(s:string; var num:longint; dflt:longint);
procedure Str2Num(s:string; var num:longword; dflt:longword);
procedure Str2Num(s:string; var num:real; dflt:real);
procedure Str2Num(s:string; var num:single; dflt:single);
procedure Str2Num(s:string; var num:extended; dflt:extended);
function  Str2NumFMT(s:string; nk:byte):string;
function  Num2StrFMT(num:real; nk:byte):string;
function  Str2CP437(s:string):string;
function  Str2TimeSpec(s:string; var ts:timespec):boolean; 
function  Str2DateTime(const tdstring,fmt:string; var dt:TDateTime):boolean;
function  Str2DateTime(const tdstring:string; fmtsel:integer; var dt:TDateTime):boolean;
function  UnicodeStr2UTF8(unicodestr:string):string;
function  Str2LogLvl(s:string):T_ErrorLevel;
function  StrShort2LogLvl(s:string; dfltlvl:T_ErrorLevel):T_ErrorLevel;
function  LogLvl2Str(lvl:T_ErrorLevel):string;
function  GetLogLvls(tr:string):string;
function  LeadingZero(w : Word) : String; 
function  LeadingZeros(l:longint;digits:byte):string;  
function  Bin(q:longword;lgt:Byte) : string; 
//function  Hex(nr:qword;lgt:byte) : string; 
//function  Hex(ptr:pointer;lgt:byte): string;
function  QW2Str(qw:qword):string;
function  HexStr(s:shortstring):string;overload;
function  HexStr(s:string):string;overload;
function  StrHex(Hex_strng:string):string;
function  AdjZahlDE(r:real;lgt,nk:byte):string;
function  AdjZahl(s:string):string;
function  adjL0(s:string):string;
function  adjT0(s:string):string;
function  Adj_LF(strIN:string):string;
function  FormatFileSize(const Size: Int64):string;
function  FormatNumSize(const Size:real):string;
function  scale(x,in_min,in_max,out_min,out_max:real):real;
function  scale(x,in_min,in_max,out_min,out_max:longint):longint;
function  scale(x,in_min,in_max,out_min,out_max:int64):int64;
function  scale(x,dflt,in_min,in_max,out_min,out_max:real):real;
function  scale(x,dflt,in_min,in_max,out_min,out_max:longint):longint;
function  scale(x,dflt,in_min,in_max,out_min,out_max:int64):int64;
function  DIST_Insert(var struct:DISTribution_t; valIN:real):longint;
function  DIST_Init(var struct:Distribution_t; ArrSize:word; fmin,fmax:real):boolean;
procedure DIST_Show(var struct:Distribution_t; hdr,lbl:string; lvl,lcol:T_ErrorLevel);
procedure DIST_End(var struct:Distribution_t);
function  Get_SameCharString(cnt:longint;c:char):string;
function  Get_FixedStringLen(s:string;cnt:word;leading:boolean):string; 
//function  StringReverse(s:string):string;
function  ShortStrng(fmt,maxlgt,divdr:longint; str:string):string;
function  KEYpressedChar(lvl:T_ErrorLevel; msg:string; ch:char):boolean;
function  KEYpressedChar(ch:char):boolean;
function  ESCpressed:boolean;
procedure AskCR;
procedure AskCR(msg:string);
procedure AskCR(lvl:T_ErrorLevel; msg:string);
function  AskYN(msg:string; dflt:string):boolean;
function  AskStr(msg:string; var outstr:string):boolean;
function  AskNum(von,bis:longint; msg:string; var outnum:longint):boolean;
function  AskNumNoExit(von,bis:longint; msg:string; var outnum:longint):boolean;
function  SepRemove(s:string):string;
function  Trimme(s:string;modus:byte):string;//modus: 1:adjL 2:adjT 3:AdjLT 4:AdjLMT 5:AdjLMTandRemoveTABs
function  FilterChar(s,filter:string):string;
function  RemoveChar(s,filter:string):string;
function  GetNumChar(s:string):string;
function  GetNumChar2(s:string):string;
function  GetAlphaNumChar(s:string):string;
function  GetParserTokenChar(s:string):string;
function  ContainDescenderLetter(s:string):boolean;
function  GetHexChar(s:string):string;
function  HashTag(const InString:string):string; 
function  HashTag(modus:byte; const filname,InString,comment:string):string;
function  HashTagFMT(hash:string):string;
function  ReplaceChars(s,filterchars,replacechar:string):string;
function  RM_CRLF(s:string):string; 
function  SB_LF  (s:string):string; // \n -> #$0a
function  SB_CR  (s:string):string; // \r -> #$0d
function  SB_CRLF(s:string):string; 
function  SB_UnESC(s:string):string;
function  BS_LF  (s:string):string; // #$0a -> \n
function  BS_CR  (s:string):string; // #$0d -> \r
function  BS_CRLF(s:string):string; 
function  BS_DoESC(s:string):string;
function  BS_ALL (s:string):string;
function  GetPrintableChars(s:string; c1,c2:char):string;
function  CamelCase(strng:string):string;
function  GetRndTmpFileName(filhdr,extname:string):string;
function  Get_FName(fullfilename:string):string; 
function  Get_FName(fullfilename:string; withext:boolean):string; 
function  Get_FNameExt(fullfilename:string):string; 
function  Get_ExtName(fullfilename:string; extwithdot:boolean):string; 
function  Get_Dir(fullfilename:string):string; 
function  Get_DirList(dirname:string; filelist:TStringList):integer;
function  GetTildePath(fullpath,homedir:string):string;
function  PrepFilePath(fpath:string):string;
function  ISdir(filname:string):boolean;
function  MKdir(dirname:string; mode:word):integer;
function  SetFileAge(filname:string; mode:integer; fdat:TDateTime):integer;
function  GetFileAge(filname:string):TDateTime;
function  GetFileSize(filname:string):int64;
function  GetFileAgeInSec(filname:string):int64;
function  FileIsRecent(filepath:string; seconds_old,varianz:longint):boolean;
function  FileIsRecent(filepath:string; seconds_old:longint):boolean;
function  MStream2String(MStreamIn:TMemoryStream):string;
procedure String2MStream(MStreamIn:TMemoryStream; var SourceString:string);
function  MStream2File(filname:string; StreamOut:TMemoryStream):boolean;
function  File2MStream(filname:string;StreamOut:TMemoryStream; var hash:string):boolean;
function  File2MString(filname:string; var OutString,hash:string):boolean;
function  TextFile2StringList(const filname:string; StrListOut:TStringList):boolean;
function  TextFile2StringList(const filname:string; StrListOut:TStringList; append:boolean):boolean;
function  StringListAdd2List(StrList1,StrList2:TStringList; append:boolean):longword; 
function  StringListAdd2List(StrList1,StrList2:TStringList):longword; //Adds StringList2 to Stringlist1. result is size of Stringlist in bytes
function  StringList2TextFile(filname:string; StrListOut:TStringList):boolean;
function  StringList2TextFile(filname:string; StrListOut:TStringList; append_mode:boolean):boolean;
function  StringList2TextFile(filname,owner,group:string; mode:TMode; StrListOut:TStringList):boolean;
function  StringList2String(StrList:TStringList):string;
function  StringList2String(StrList:TStringList; tr:string):string;
procedure String2StringList(str:string; StrList:TStringList);
function  String2TextFile(filname:string; StrOut:string):boolean;
procedure StringSplit(const delim:char; const strng:string; const strings:TStrings);
function  TailFile(filname:string; LinesCount:longint):RawByteString;
procedure TailFileFollow(filname:string; LinesCount:longint);
procedure TL_prot_Init(var tlp:TL_prot_t);
procedure TL_prot_Stop(var tlp:TL_prot_t);
procedure STR_prot_Init(var slp:STR_prot_t);
procedure STR_prot_Stop(var slp:STR_prot_t);
function  escSEP(const strng:string):string;
function  Anz_Item(const strng,trenner,trenner2:string): longint;
function  Select_Item(const strng,trenner,trenner2,dflt:string;itemno:longint):string; 
function  Select_Item(const strng,trenner,trenner2:string;itemno:longint) : string;
function  Select_RightItems(const strng,trenner,trenner2:string;startitemno:longint):string; 
function  Select_LeftItems (const strng,trenner,trenner2:string;enditemno:longint):string; 
function  Locate_Value(const strng,search,tr1,tr2,tr3,tr4:string; var valoutstrng:string; flags:s_BIOS_Flags):boolean;

function  CSV_ESCvalue(const value:string):string;
function  CSV_Count(const strng:string):longint;
function  CSV_Count(const strng:string; const delim:char):longint;
function  CSV_Item(const strng:string; itemno:longint):string;
function  CSV_Item(const strng:string; const delim:char; itemno:longint):string;
function  CSV_Item(const strng:string; const delim:char; const dflt:string; itemno:longint):string;
procedure CSV_Explode(const strng:string; var fields:CSV_array_t);
procedure CSV_Explode(const strng:string; const delim:char; const dflt:string; var fields:CSV_array_t);
function  CSV_RightItems(const strng:string; const delim:char; itemno:longint):string; 
function  CSV_LeftItems(const strng:string; const delim:char; itemno:longint):string;
function  CSV_RemFirstSep(const strng:string; const delim:char):string;
function  CSV_RemLastSep(const strng:string):string;
function  CSV_RemLastSep(const strng:string; const delim:char):string;
procedure CSVRemLastSep(var strng:string; const delim:char);
procedure CSV_MaintList(var csvlst:string; entry:string; addit:boolean);
function  CSV_MaintListToogleField(var csvlst:string; entry:string):boolean;
function  CSV_FileList(const cmd:string):string;

function  ReMAParrFL(var arr,adflt:Array of real; sects,keys,values:string):boolean;
function  ReMAParrLI(var arr,adflt:Array of longint;  sects,keys,values:string):boolean;
function  MODarrLI	(var arr:Array of longint; idx,newval:longint; sects,keys:string):boolean;
function  MODarrLW(var arr:Array of longword; idx:longint; newval:longword; sects,keys:string):boolean;
function  ReMAParrLW(var arr,adflt:Array of longword; sects,keys,values:string):boolean;
function  ChgArrLW  (var arr,adflt:Array of longword; var ArrOut:Array of longint):boolean;

function  ContentHasChangedTimeStamp(const hashOld,hashNew:string; timeStampOld,timeStampNew:TDateTime):TDateTime;
function  StringPrintable(s:string):string; 
function  CharPrintable(c:char):string;
function  URLencode(s:string):string; 
function  URLdecode(s:string):string;
procedure ShowStringList(StrList:TStringList); 
function  StringListMinMaxValue(StrList:TStringList; fieldnr:word; tr1,tr2:string; flgs:s_BIOS_Flags; var min,max:extended; var nk:longint):boolean;
procedure StringListSnap(StrListIn,StrListOut:TStringList; const srchstrng:string);
function  SearchStringInListIdx(StrList:TStringList; const srchstrng:string; occurance,StartIdx:longint):longint;
function  SearchStringInList(StrList:TStringList; const srchstrng:string):string;
function  GiveStringListIdx(StrList:TStringList; const srchstrng:string; var idx:longint; occurance:longint):boolean;
function  GiveStringListIdx(StrList:TStringList; const srchstrng:string; var idx:longint; occurance,StartIdx:longint):boolean;
function  GiveStringListIdx(StrList:TStringList; const srchstrngSTART,srchstrngEND:string; var idx:longint):boolean;
function  GiveStringListIdx2(StrList:TStringList; const srchstrng:string; var idxStart,idxEnd:longint):boolean;
procedure MemCopy(src,dst:pointer; size:longint); 
procedure MemCopy(src,dst:pointer; size,srcofs,dstofs:longint);
function  DeltaTime_in_ms(dt1,dt2:TDateTime):int64;
function  CHK8(s:string):byte;
function  CRC8(s:string):byte;
function  CRC8_ok(s:string):boolean;
function  MD5_HashGET(filnam:string; var MD5hash:string):boolean;
function  MD5_HashCreateFile(filnam,MD5filnam:string; var MD5hash:string):boolean;
function  MD5_HashGETFile(MD5filnam:string; var MD5hash:string):boolean;
function  MD5_Check(file1,file2:string):boolean;
function  MOD_Euclid(a,b:longint):longint;
function  MovAvg(interval:longword; var InpArr,OutArr:array of single):longint; // moving average
function  MovAvg(interval:longword; var InpArr,OutArr:array of real):longint; // moving average 
function  SearchValIdx(var InpArr:array of real; srchval,Epsilon:real; up:boolean):longint; 
function  TTY_sttySpeed(lvl:t_ErrorLevel; ttyandspeed:string):integer;  // e.g. '/dev/ttyAMA0@9600'
function  TTY_setterm(lvl:t_ErrorLevel; ttydev,ttyopts:string):integer; // e.g. '/dev/tty1' '--cursor off --clear all' 
function  TTY_console:string;
procedure TimeZoneString(TimeZoneString:string);
function  TimeZoneString:string;
function  GetTimeZoneString:string;
procedure SetUTCOffset; // time Offset in minutes form GMT to localTime
function  GetDateTimeLocal:TDateTime; 
function  GetDateTimeLocal(utc:TDateTime):TDateTime; 
function  CalcUTCOffsetString(offset_Minutes:longint; withcolon:boolean):string; // e.g. '+02:00'
function  GetUTCOffsetString:string; // e.g. '+02:00' 
function  GetUTCOffsetMinutes(ofs:string):longint; // e.g. '-02:00' -> -120
function  GetDateTimeUTC:TDateTime;
function  GetDateTimeUTC(dt:TDateTime; tzofs:longint):TDateTime; 
function  DateTime2FMT(fmt:integer; dt:TDateTime):string;
function  DateTime00MS(dt:TDateTime):TDateTime;	// get rid of ms
function  RFC822DateTimeEncode(dt:TDateTime; tzofs:longint):string;
function  RFC822DateTimeEncode(dt:TDateTime):string; // Sat, 14 Aug 2021 07:57:03 +0000
function  RFC822DateTimeEncode:string;
function  RFC822DateTimeDecode(const tstmp:string; var dt:TDateTime):boolean;
function  GetTimeStamp(dt:TDateTime):string; 	// YEAR-MM-DD hh:mm:ss.zzz
function  GetTZTimeStamp(dt:TDateTime):string;	// YEAR-MM-DD hh:mm:ss.zzz+XX:XX
function  GetXMLTimeStamp(dt:TDateTime):string; // YEAR-MM-DDThh:mm:ss.zzz+XX:XX
function  GetDateTimefromXMLTimeStamp(tstmp:string; var dt:TDateTime; var tzofs:longint):boolean;
function  GetUTCDateTimefromXMLTimeStamp(tstmp:string; var dt:TDateTime):boolean;
function  GetDateTimefromUTC(tstmp:string; var dt:TDateTime):boolean;
function  GetDateTimefromTimeDateCtlUTC(tstmp:string; var dt:TDateTime):boolean;
function  call_external_prog(typ:t_ErrorLevel; cmdline:string):integer; 
function  call_external_prog(typ:t_ErrorLevel; cmdline:string; var receivestring:string):integer;
function  call_external_prog(typ:t_ErrorLevel; cmdline:string; receivelist:TStringList):integer; 
function  call_external_prog(typ:t_ErrorLevel; cmdline:string; receivelist:TStringList; timo_msec:word):integer;
function  RunScript(filname,para:string):integer;
function  RunScript(ts:TStringList; para:string):integer;
function  RunScript(ts:TStringList; filname,para:string):integer;
function  RunProcess(filname,para:string; syncwait:boolean):integer;
function  RunProcess(cmds,filname,para:string; syncwait:boolean):integer;
function  RunProcess(ts:TStringList; filname,para:string; syncwait:boolean):integer;
function  PV_Progress(progressfile:string):integer;
function  CURLcmdCreate(usrpwd,proxy,ofil,uri:string; flags:s_rpimaintflags):string;
procedure CURL_RemoveProgressfile(progressfile:string);
function  CURL_DoProgressAction(var CurlThCtl:Thread_Ctrl_t; var terminate:boolean):boolean;
procedure CURL_SetPara(var CurlThCtl:Thread_Ctrl_t; info,curlcmd,logfile,filenamelist,dirname:string; updintervall_ms:integer; flgs:s_rpimaintflags);
function  CURL(var CurlThCtl:Thread_Ctrl_t):integer;
procedure CURL_Test;
procedure TimeElapsed_us_Test;
procedure Test_TimeOut;
procedure TEST_TimeStrobe(filename:string);
procedure delay_nanos(Nanoseconds:int64);
procedure delay_us   (Microseconds:longword);	
procedure delay_msec (Milliseconds:longword); 
function  delay_sec	 (sec:real):boolean;
function  GetHighPrecisionCounter: Int64; 
function  Sigmoid(A,k,x,x0:real):real;
function  SigmoidIsA(A,k,epsilon,x0:real):real;
procedure tst_Sigmoid;
procedure tst_Sigmoid_normalized;

function sysconf			(i:cint):clong;cdecl;external name 'sysconf';
function clock_getres		(clock_id:clockid_t; res:Ptimespec):longint;cdecl;external clib name 'clock_getres';
function clock_gettime		(clock_id:clockid_t; tp: Ptimespec):longint;cdecl;external clib name 'clock_gettime';
function clock_settime		(clock_id:clockid_t; tp: Ptimespec):longint;cdecl;external clib name 'clock_settime';
function clock_nanosleep	(clock_id:clockid_t; flags:longint; req:Ptimespec; rem:Ptimespec):longint;cdecl;external clib name 'clock_nanosleep';
function clock_getcpuclockid(pid:pid_t; clock_id:Pclockid_t):longint;cdecl;external clib name 'clock_getcpuclockid';

{$IFDEF UNIX}
//function  usleep(Microseconds:cuint64):longint;cdecl;external 'libc'; //name 'usleep';
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
function  MicroSecondsBetween(ts1,ts2:timespec):int64;
function  MicroSecondsBetween(ts:timespec):int64;
{$ELSE}
function  MicroSecondsBetween(ts1,ts2:int64):int64; 
{$ENDIF}
function  MilliSecsBetween(td:TDateTime):int64;

procedure PID_Test(csvuse:boolean; csvfn,fusr,fgrp:string);
procedure PID_Test_GetPara;
procedure Twiddle_Test;

function  PID_WT(fnIN,fnOUT:string; PID_loctTIMusec,PID_locPVval,PID_locSPval:integer; lvl:T_ErrorLevel; var PID_Det:PID_Det_t):boolean;
function  PID_DetPara(loglvl:t_ErrorLevel; StrList:TStringList; idxStart,idxEnd,smoothdata,smoothtdr,loctim,locist,locSetPoint:longint; StoerSprung,timadjfct:real; var PID_Det:PID_Det_t; tst:boolean; filout:string):integer;
function  PID_GetPara(loglvl:t_ErrorLevel; var PID_Det:PID_Det_t; var K:PID_array_t; loginfo:string):integer;
procedure PID_DetShow(var struct:PID_Det_t; loglvl,collvl:T_ErrorLevel; hdr,trl:string);

procedure PID_Init(var PID_Struct:PID_Struct_t; nr:longint; itermax:longword; enab_twiddle:boolean; MinOutput,MaxOutput,WindupResetValue:real; SampleTime_us:int64; K,dK,tol:PID_array_t);
procedure PID_Init(var PID_Struct:PID_Struct_t; SampleTime_us:int64; K:PID_array_t);
procedure PID_Reset(var PID_Struct:PID_Struct_t);
function  PID_Calc(var PID_Struct:PID_Struct_t; SetPoint,ProcessValue:PID_float_t; Stoersprung:boolean):boolean;
function  PID_Calc(var PID_Struct:PID_Struct_t; SetPoint,ProcessValue:PID_float_t):boolean;
procedure PID_SetIntImprove(var PID_Struct:PID_Struct_t; On_:boolean);
procedure PID_SetDifImprove(var PID_Struct:PID_Struct_t; On_:boolean);
procedure PID_SetSampleTime(var PID_Struct:PID_Struct_t; SampleTime_us:int64);
procedure PID_SetMinMaxLimit(var PID_Struct:PID_Struct_t; MinOutput,MaxOutput:PID_float_t);
procedure PID_SetSelfTuning(var PID_Struct:PID_Struct_t; On_:boolean); 

function  PID_ExecTwiddle(var PID_Twiddle:PID_Twiddle_t; var PID_K:PID_array_t; errorUpdate:PID_float_t):boolean;
procedure PID_InitTwiddle(var PID_Twiddle:PID_Twiddle_t; ID:longint; enab:boolean; itermax:longword; ap,dK,tol:PID_array_t);
procedure PID_EnableTwiddle_Save(var PID_Twiddle:PID_Twiddle_t; enable:boolean);
procedure PID_Twiddle_LogLevel(var PID_Twiddle:PID_Twiddle_t; lvl1,lvl2:T_ErrorLevel);
procedure PID_SetTwiddle_KeyName(var PID_Twiddle:PID_Twiddle_t; sect,key:string);
procedure PID_SaveTwiddle(var PID_Twiddle:PID_Twiddle_t; K,dK:PID_array_t);
function  PID_ReadTwiddle(sect,key:string; var K,dK,tol:PID_array_t):boolean;
function  PID_ReadTwiddle(sect,key:string; var K,dK,tol:PID_array_t; replvl1,replvl2:T_ErrorLevel):boolean;

function  PID_VectorStr(var pidarr:PID_array_t; vk,nk:integer; sep:char):string;
function  PID_VectorStr(var pidarr:PID_array_t; vk,nk:integer):string;
function  PID_Vector(Kp,Ki,Kd:PID_float_t):PID_array_t;
function  PID_DetCreate(myKS,myTe,myTb,myTimeBase_sec,mySampleTime:PID_float_t):PID_Det_t;
function  PID_DetCreate(myPIDmethod:PID_Method_t; myKS,myTe,myTb,myTimeBase_sec,mySampleTime:PID_float_t):PID_Det_t;
function  PID_TDR(var TickArr,ValArr,OutTickDeltaArr,OutValArr:array of PID_float_t):longint;
function  PID_DetType(Te,Tb:PID_float_t):PID_Method_t;
function  PID_TimAdj(timadjfct:real; var Te,Tb,TSum:PID_float_t):integer;
function  PID_DetAvgs(IdxStart,IdxEnd:longint; var avgnumIst,avgnumPInc:longint):boolean; 
function  PID_FileLoad(StrList:TStringList; filnam,SearchCrit:string; var IdxStart,IdxEnd:longint):boolean;
function  PID_sim(StrList:TStringList; simnr:integer):real;
procedure PID_SimCSV(tl:TStringList; var PID_Det:PID_Det_t; var pid:PID_Struct_t);
function  PID_Limit(var Value:PID_float_t; MinOut0,MinOut,MaxOut:PID_float_t):PID_float_t;
procedure PID_TestSim;
procedure PID_TestSim2(fil,fusr,fgrp:string);
function  PID_Info(var PID_Struct:PID_Struct_t; fmt:longint):string;
procedure PID_csv_fname(var PID_Struct:PID_Struct_t; csvfilename:string);
procedure PID_csv_fname(var PID_Struct:PID_Struct_t; csvfilename,fown,fgrp:string);
procedure PID_csv_USE(var PID_Struct:PID_Struct_t; use:boolean);
procedure PID_csv_RECtime(var PID_Struct:PID_Struct_t; rectim_ms:word);
procedure PID_csv_SetPointMax(var PID_Struct:PID_Struct_t; spmax:PID_float_t);
procedure PID_close(var PID_Struct:PID_Struct_t);

function  WAVE_InitArray(wavelist:TStringList; var wa:WAVE_Array_t; var valmin,valmax:real):longint;
function  WAVE_InitArray(var wa:WAVE_Array_t; wavemode:WAVE_RampShape_t; valstart,valend:real; valcnt:longint; dtycycle:real):longint;
procedure WAVE_InitStruct(var wstruct:WAVE_Signal_Struct_t; var wa:WAVE_Array_t; wavemode:WAVE_RampShape_t; intervall_ms:longint);
procedure WAVE_Enable(var wstruct:WAVE_Signal_Struct_t; enab:boolean);
function  WAVE_SetIdx(var wstruct:WAVE_Signal_Struct_t; var wa:WAVE_Array_t; startidx:longint):boolean;
function  WAVE_GetIdx(var wstruct:WAVE_Signal_Struct_t; var wa:WAVE_Array_t):boolean;
procedure WAVE_Show(var wstruct:WAVE_Signal_Struct_t; var wa:WAVE_Array_t);
procedure WAVE_Test;

procedure TMR_Init(var TMR_struct:TMR_struct_t);
procedure TMR_GetStartTime(var TMR_struct:TMR_struct_t);
procedure TMR_GetEndTime(var TMR_struct:TMR_struct_t);

procedure SIG_EndLoop(nr:integer; ende:boolean);
function  SIG_EndLoop(nr:integer):boolean;
function  SIG_ESCterm(nr:integer):boolean;

procedure USR_BreakSetFunc(USRbrkFunc:TFunctionOneArgCall); 

implementation  

const max_EndLoop_c=5;
	  int_filn_c='/tmp/GPIO_int_setup.sh';   
  	  prog_build_date = {$I %DATE%}; prog_build_time = {$I %TIME%}; 

var 
	_LOG_Level,_LOG_OLD_Level,_SAY_Level,_SAY_OLD_Level:T_ErrorLevel;
	rpi_fw_api:RPI_FW_API_t;
    rpi_timespecresolution:timespec;
    _LOG_LevelColor,restrict2gpio,_OnExitShowRuntime:boolean;
    GPIO_map_idx,I2C_busnum,connector_pin_count,status_led_GPIO:byte;
    cpu_snr,cpu_hw,cpu_proc,cpu_rev,cpu_mips,cpu_feat,cpu_fmin,cpu_fcur,
    cpu_machine,cpu_fmax,os_rev,lsb_rel,cpu_fw,uname,sudo,whoami:string;
    cpu_rev_num,cpu_freq,pll_freq:real;
    RPI_ShutDownGPIO,cpu_cores: longint;
	eeprom_devadr:word; 
	GPU_MEM_BASE,RPI_Throttle:longword;
	oa,na:PSigActionRec;	
	RPIHDR_Desc:array[1..max_pins_c] of string[mdl];
	_EndLoop:array[0..max_EndLoop_c] of boolean;
	CallUSRbrkFunc:TFunctionOneArgCall;

//function  Aligned(p:pointer; alig:byte):boolean; begin Aligned:=((PtrUint(p) mod alig)=0); end; 
function  Aligned(p:pointer; alig:byte):boolean; begin Aligned:=(p=Align(p,alig)); end;
procedure AlignShow; 
begin 
  writeln('addr 0x'+HexStr(@msg),' (',PtrUInt(@msg),') aligned ',Aligned(@msg,32),' (',(PtrUint(@msg) mod 32),')'); 
end;

procedure USR_BreakSetFunc(USRbrkFunc:TFunctionOneArgCall); begin CallUSRbrkFunc:=USRbrkFunc; end;

procedure SIG_EndLoop(nr:integer; ende:boolean); begin _EndLoop[nr]:=ende; end;
function  SIG_EndLoop(nr:integer):boolean;		 begin SIG_EndLoop:=_EndLoop[nr]; end;

function  SIG_ESCterm(nr:integer):boolean; 
var _pressed:boolean;
begin 
  _pressed:=KEYpressedChar(LOG_WARNING,'terminated',ESC); 
  if _pressed then SIG_EndLoop(nr,true);
  SIG_ESCterm:=_pressed;
end;

function  ERR_string(var ERR_Rec:ERR_Rec_t):string;
begin 
  with ERR_Rec do 
  begin 
	ERR_string:=title+'['+Num2Str(step,0)+']: '+msg; 
  end; // with
end;

procedure ERR_SetStep(var ERR_Rec:ERR_Rec_t; errnr:longint); 
begin ERR_Rec.step:=errnr; end;

procedure ERR_SetStep(var ERR_Rec:ERR_Rec_t; errnr:longint; errmsg:string); 
begin ERR_Rec.step:=errnr; ERR_Rec.msg:=errmsg; end;

procedure ERR_SetStep(var ERR_Rec:ERR_Rec_t; errnr:longint; errtitle,errmsg:string); 
begin ERR_Rec.step:=errnr; ERR_Rec.title:=errtitle; ERR_Rec.msg:=errmsg; end;

procedure DUMP_CallStack(hdr:string);
// https://wiki.lazarus.freepascal.org/Logging_exceptions
const MaxDepth = 20;
var I:Longint; prevbp:Pointer; CallerFrame,CallerAddress,bp:Pointer; _tl:TStringList;
begin
  _tl:=TStringList.create;
  _tl.add(hdr+' ##############################+');
  bp := get_frame;
  // This trick skip SendCallstack item
  // bp:= get_caller_frame(get_frame);
  try
    prevbp := bp - 1;
    I := 0;
    while bp > prevbp do begin
       CallerAddress := get_caller_addr(bp);
       CallerFrame := get_caller_frame(bp);
       if (CallerAddress = nil) then Break;
       _tl.add(BackTraceStrFunc(CallerAddress));
       Inc(I);
       if (I >= MaxDepth) or (CallerFrame = nil) then Break;
       prevbp := bp;
       bp := CallerFrame;
     end;
   except
//	prevent endless dump if an exception occured
   end;
  _tl.add(hdr+' ##############################-');
  LOG_ShowStringList(LOG_ERROR,_tl);
  _tl.free;
end;

procedure DUMP_ExceptionCallStack(hdr:string; E:Exception; haltprog:boolean);
// https://wiki.lazarus.freepascal.org/Logging_exceptions
var i:integer; Frames:PPointer; _tl:TStringList;
begin
  _tl:=TStringList.create;
  _tl.add(Trimme(hdr+' '+E.ClassName+' ##############################+',3));
  _tl.add('Stacktrace: '+E.Message);
//if (E<>nil) then _tl.add('Exception class: '+E.ClassName);
  _tl.add(BackTraceStrFunc(ExceptAddr));
  Frames:=ExceptFrames;
  for i:= 0 to (ExceptFrameCount-1) do _tl.add(BackTraceStrFunc(Frames[i]));
  _tl.add(Trimme(hdr+' '+E.ClassName+' ##############################-',3));
  LOG_ShowStringList(LOG_ERROR,_tl);
  _tl.free;
  if haltprog then Halt; // End of program execution
end;
procedure DUMP_ExceptionCallStack(hdr:string; E:Exception);
begin DUMP_ExceptionCallStack(hdr,E,true); end;
	
function  MOD_Euclid(a,b:longint):longint;
var m:longint;
begin
  if (b<>0) then
  begin
	m:=a mod b;
  	if (m<0) then
      if (b<0) then m:=m-b else m:=m+b;
  end else m:=0;
  MOD_Euclid:=m;
end;

function  USRBreakFunc(mode:integer):integer; 
// dummy, assign your own USR_Break function with USR_BreakSetFunc.
// this function will be called by delay_sec
// e.g. USR_BreakSetFunc(@USR_Break);
begin 
  USRBreakFunc:=0; 
end;

procedure delay_msec(Milliseconds:longword);  
begin 
  if (Milliseconds>0) then sysutils.sleep(Milliseconds); 
end;

function  delay_sec(sec:real):boolean;		// in sec
const _mio_c=1000000; _resol_msec_c=100; 	// resolution 100msec
var _cnt,_cntmax,_us:qword; _flg:boolean;
begin
  _flg:=true;
  if (sec>0) then
  begin
	_us:=round(sec*_mio_c);
	if (sec>0.5) then // 500msec
	begin
	  _cnt:=	0; 
	  _cntmax:=	trunc(sec * 1000 / _resol_msec_c); 
	  _us:=	_us mod _mio_c;
	  while (not TerminateProg) and (_flg and (_cnt<_cntmax)) do
	  begin
		delay_msec(_resol_msec_c);
		if (CallUSRbrkFunc<>nil) then if (CallUSRbrkFunc(0)>0) then _flg:=false; // break 
		inc(_cnt);
		LNX_WDOG(WDOG_Retrig);
	  end; // while
	end;
	if (_flg and (_us>0)) then delay_us(_us);
  end;
  delay_sec:=_flg;
end;

function  RoundUpPow2(nr:real):longword; begin RoundUpPow2:=round(intpower(2,round(log2(nr)))); end;
function  DivRoundUp(n,d:real):longword; begin DivRoundUp:=round((n+d-1)/d); end;	
function  CHK8(s:string):byte; var i,chk:byte; begin chk:=$00; for i := 1 to Length(s) do chk:=chk  +  ord(s[i]); CHK8:=chk; end;
function  CRC8(s:string):byte; var i,crc:byte; begin crc:=$00; for i := 1 to Length(s) do crc:=crc xor ord(s[i]); CRC8:=crc; end;
function  CRC8_ok(s:string):boolean; var ok:boolean; begin ok:=false; if s<>'' then ok:=(ord(s[Length(s)])=CRC8(copy(s,1,Length(s)-1))); CRC8_ok:=ok; end;
procedure SetTimeOut (var EndTime:TDateTime;TimeOut_ms:Int64); begin EndTime:=IncMilliSecond(now,TimeOut_ms); end;
function  TimeElapsed(EndTime:TDateTime):boolean;              begin TimeElapsed:=(EndTime<=now); end;

function  TimeElapsed(var EndTime:TDateTime; Retrig_ms:Int64):boolean;
var ok:boolean;
begin 
  ok:=(EndTime<=now); 
  if ok and (Retrig_ms>=0) then EndTime:=IncMilliSecond(now,Retrig_ms); 
  TimeElapsed:=ok; 
end;

function  TimeSpec2Num(ptspec:Ptimespec):real;
begin TimeSpec2Num:=ptspec^.tv_sec + (ptspec^.tv_nsec*rpi_timespecresolution.tv_nsec/nano_c); end;

function  TimeSpec2Num_ns(ptspec:Ptimespec):int64;
begin TimeSpec2Num_ns:=ptspec^.tv_sec*nano_c + (ptspec^.tv_nsec*rpi_timespecresolution.tv_nsec); end;

function  TimeSpec2Str(ptspec:Ptimespec):string; 
// e.g usage: str:=TimeSpec2Str(@timespec);
begin 
  TimeSpec2Str:=	FormatDateTime('YYYY-MM-DD hh:mm:ss',
  					UnixToDateTime(ptspec^.tv_sec))+'.'+
  				 	LeadingZeros(ptspec^.tv_nsec,9); 
end;

function  TimeSpec_Diff(ptspec_start,ptspec_end:Ptimespec):timespec;
// https://gist.github.com/diabloneo/9619917
var ts:timespec;
begin
  if (ptspec_end^.tv_nsec < ptspec_start^.tv_nsec) then
  begin
	ts.tv_sec:=	ptspec_end^.tv_sec 	- ptspec_start^.tv_sec  - 1;
	ts.tv_nsec:=ptspec_end^.tv_nsec - ptspec_start^.tv_nsec + nano_c;
  end
  else
  begin
	ts.tv_sec:=	ptspec_end^.tv_sec 	- ptspec_start^.tv_sec;
	ts.tv_nsec:=ptspec_end^.tv_nsec - ptspec_start^.tv_nsec;
  end;
  TimeSpec_Diff:=ts;
end; 

procedure SetTimeOut_ns(ptspec_start,ptspec_end:Ptimespec; Retrig_nsec:int64);
begin
  try
	if (Retrig_nsec<>0) then
	begin
  	  if (rpi_timespecresolution.tv_nsec=1) then
  	  begin
  	  	ptspec_end^.tv_sec:=  ptspec_start^.tv_sec  + (Retrig_nsec  div nano_c);
	  	ptspec_end^.tv_nsec:=(ptspec_start^.tv_nsec +  Retrig_nsec) mod nano_c;
  	  end
  	  else
  	  begin
  	  	ptspec_end^.tv_sec:=  ptspec_start^.tv_sec  + (Retrig_nsec  div nano_c);
      	ptspec_end^.tv_nsec:=(ptspec_start^.tv_nsec + (Retrig_nsec  div rpi_timespecresolution.tv_nsec)) mod nano_c;
  	  end;
  	  if (ptspec_end^.tv_nsec < ptspec_start^.tv_nsec) then inc(ptspec_end^.tv_sec);
  	end else ptspec_end^:=ptspec_start^;
//say(Log_INFO,'SetTimeOut_ns: '+TimeSpec2Str(ptspec_start)+' '+TimeSpec2Str(ptspec_end)+' ('+Num2Str(rpi_timespecresolution.tv_nsec,0)+')');
  except
  	On E_rpi_hal_Exception :Exception do Writeln('SetTimeOut_ns: ',Retrig_nsec,' ',E_rpi_hal_Exception.Message);
  end;
end;

procedure SetTimeOut_ns(ptspec:Ptimespec; Retrig_ns:int64);
// e.g usage: SetTimeOut_ns(@timespec,123);
var tv_now:timespec; 
begin 
  clock_gettime(CLOCK_REALTIME,@tv_now); // call OS
  SetTimeOut_ns(@tv_now,ptspec,Retrig_ns); 
end;

procedure SetTimeSpec(ptspec:Ptimespec; sec,nsec:int64);
begin ptspec^.tv_sec:=sec; ptspec^.tv_nsec:=nsec; end;

procedure SetTimeOut_us(ptspec_start,ptspec_end:Ptimespec; Retrig_us:int64);
begin SetTimeOut_ns(ptspec_start,ptspec_end,Retrig_us*1000); end;

procedure SetTimeOut_us(ptspec:Ptimespec; Retrig_us:int64);
// e.g usage: SetTimeOut_us(@timespec,123);
// pls. consider to use the more efficient RPI_SetTimeOut_us
var tv_now:timespec; 
begin 
  clock_gettime(CLOCK_REALTIME,@tv_now); // call OS
  SetTimeOut_ns(@tv_now,ptspec,Retrig_us*1000); 
end;

function  TimeElapsed_ns(ptspec:Ptimespec; Retrig_ns:int64):boolean;
var ok:boolean; tv_now:timespec;
begin 
  clock_gettime(CLOCK_REALTIME,@tv_now); // call OS

  if (ptspec^.tv_sec = tv_now.tv_sec) 
	then ok:=(ptspec^.tv_nsec <= tv_now.tv_nsec)
	else ok:=(ptspec^.tv_sec  <  tv_now.tv_sec);

  if (ok and (Retrig_ns>0)) then SetTimeOut_ns(@tv_now,ptspec,Retrig_ns);
  TimeElapsed_ns:=ok;
end;

function  TimeElapsed_us(ptspec:Ptimespec; Retrig_us:int64):boolean;
// pls. consider to use the more efficient RPI_TimeElapsed_us
begin TimeElapsed_us:=TimeElapsed_ns(ptspec,Retrig_us*1000); end;

function  TimeElapsed_us(ptspec:Ptimespec):boolean;
begin TimeElapsed_us:=TimeElapsed_ns(ptspec,0) end;

procedure Test_TimeOut;
var tv_now1,tv_now2:timespec; timo:boolean; n:longint;
begin
  writeln('resolution: ',rpi_timespecresolution.tv_nsec);
  clock_gettime(CLOCK_REALTIME,@tv_now1); // call OS
  writeln('tv_now1: ',TimeSpec2Str(@tv_now1));
  writeln;
  with tv_now1 do begin tv_sec:=0; tv_nsec:=0; end;
  with tv_now2 do begin tv_sec:=0; tv_nsec:=0; end;

  writeln('tv_now1: ',TimeSpec2Str(@tv_now1),' tv_now2: ',TimeSpec2Str(@tv_now2));
  SetTimeOut_ns(@tv_now2,1); writeln('tv_now1: ',TimeSpec2Str(@tv_now1),' tv_now2: ',TimeSpec2Str(@tv_now2));
  SetTimeOut_ns(@tv_now2,999999999); writeln('tv_now1: ',TimeSpec2Str(@tv_now1),' tv_now2: ',TimeSpec2Str(@tv_now2));
  writeln;

  n:=0;
  SetTimeOut_ns(@tv_now2,60);
  repeat
  	timo:=TimeElapsed_ns(@tv_now2,50000000);
	writeln('tv_now2: ',TimeSpec2Str(@tv_now2),' timo:',timo);
	if timo then inc(n);
	delay_msec(5);
  until (n>=5);
end;

procedure TimeStrobeAsyn(var StrobeStruct:StrobeStruct_t; const modus:t_Strobe_flag);
begin
  with StrobeStruct do
  begin
//  strobetimer:=RPI_GetPrecisionCounter_us;
	case modus of
(*	  STB_Reset:	begin 
	  				  strobeINTtimer:=strobetimer;
					  strobeONtimer:= strobeINTtimer;
					end; *)
	  STB_Reset,
	  STB_IntvalSet:begin
	  				  strobeINTtimer:=strobeINTstartTimer + strobeINT_us;
	  				  strobeON_us:=	  round(strobeINT_us  * strobeDTYcycle);
	  				  strobeONtimer:= strobeINTstartTimer + strobeON_us;
	  				end;
	  STB_DtyCycl:	  strobeONtimer:= strobeINTstartTimer + strobeON_us;
	end; // case
  end; // with
end;

procedure TimeStrobeMode(var StrobeStruct:StrobeStruct_t; const modi:s_Strobe_flag; const strob_us:int64);
var stateold:t_Strobe_flag; // sh:string;
begin
//  sh:='';
  with StrobeStruct do
  begin	
    stateold:=				 state;
    strobetimer:=			 RPI_GetPrecisionCounter_us;
	if (STB_IntvalSet IN modi) then
  	begin
  	  state:=				 STB_Interval;
//sh:=sh+GetEnumName(TypeInfo(t_Strobe_flag),ord(STB_IntvalSet));
  	  strobeINT_us:=		 strob_us;
  	  Limits(strobeON_us,	 0,round(strobeINT_us*strobeDTYcycle));
	  if (STB_Async IN modi) then TimeStrobeAsyn(StrobeStruct,STB_IntvalSet);
	end;
	
	if ((modi*[STB_OneShot,STB_DtyCycl])<>[]) then
//	if (STB_DtyCycl IN modi) then
  	begin
//sh:=sh+GetEnumName(TypeInfo(t_Strobe_flag),ord(STB_DtyCycl));
	  strobeON_us:=  		 strob_us; 	
	  Limits(strobeON_us,0,	 strobeINT_us);
	  if (strobeINT_us<>0)
	  	then strobeDTYcycle:=strobeON_us/strobeINT_us
	  	else strobeDTYcycle:=0.0;
	  if (STB_OneShot IN modi) then state:=STB_OneShot;
	  if (STB_Async   IN modi) then TimeStrobeAsyn(StrobeStruct,STB_DtyCycl);
	end;  
	
	modetog:=(state<>stateold);
  end; // with
end;

procedure TimeStrobeMode(var StrobeStruct:StrobeStruct_t; const modi:s_Strobe_flag);
begin TimeStrobeMode(StrobeStruct,modi,0); end;

procedure TimeStrobeDuty(var StrobeStruct:StrobeStruct_t; dutycycle:real);
begin
  if (dutycycle<>StrobeStruct.strobeDTYcycle) then
  begin
	Limits(dutycycle,0.0,1.0);
	TimeStrobeMode(StrobeStruct,[STB_DtyCycl],round(StrobeStruct.strobeINT_us*dutycycle));
  end;
end;

procedure TimeStrobeDutyAsyn(var StrobeStruct:StrobeStruct_t; dutycycle:real);
begin
  if (dutycycle<>StrobeStruct.strobeDTYcycle) then
  begin
	Limits(dutycycle,0.0,1.0);
  	TimeStrobeMode(StrobeStruct,[STB_DtyCycl,STB_Async],round(StrobeStruct.strobeINT_us*dutycycle));
  end;
end;

procedure TimeStrobeOneShotAsyn(var StrobeStruct:StrobeStruct_t; dutycycle:real);
begin
  if (dutycycle<>StrobeStruct.strobeDTYcycle) then
  begin
	Limits(dutycycle,0.0,1.0);
  	TimeStrobeMode(StrobeStruct,[STB_OneShot,STB_Async],round(StrobeStruct.strobeINT_us*dutycycle));
  end;
end;
	
procedure TimeStrobeInit(var StrobeStruct:StrobeStruct_t; const ID,strobINT_us:int64);
begin
  with StrobeStruct do
  begin
    seq:=					ID;
	state:=					STB_unk;
	modetog:=				true;
	OUTstat:=				0;
	OUTstatOld:=			OUTstat+1;
	strobeDTYcycle:=		0;
	strobeONmin_us:=		0;

	TimeStrobeMode(			StrobeStruct,[STB_Async,STB_Interval,STB_IntvalSet,STB_DtyCycl],strobINT_us);
	TimeStrobeDutyAsyn(		StrobeStruct,0);
	strobeOLDtimer:=		strobetimer;
	strobeINTstartTimer:=	strobetimer;
  end; // with
end;

function  TimeStrobePeek(var StrobeStruct:StrobeStruct_t; const modus:t_Strobe_flag):t_Strobe_flag;
var flg:t_Strobe_flag;
begin 
  with StrobeStruct do
  begin
	case modus of
	  STB_DtyCycl:	if RPI_TimeElapsed_us(strobetimer,	strobeONtimer,0)
	  				  then flg:=STB_Off else flg:=STB_On;
	  STB_OneShot,
	  STB_Interval:	if RPI_TimeElapsed_us(strobetimer,	strobeINTtimer,0) 
	  				  then flg:=STB_Off else flg:=STB_On;
	  STB_GetState:	flg:=state;
	  else 			flg:=STB_unk;
	end; // case 
  end; // with
  TimeStrobePeek:=flg;
end;

function  TimeStrobe(var StrobeStruct:StrobeStruct_t):integer;
var qw:qword;
begin
  with StrobeStruct do
  begin
    strobeOLDtimer:=		strobetimer;	
	if RPI_TimeElapsed_us(	strobetimer,	strobeINTtimer,	strobeINT_us) then
	begin
	  strobeINTstartTimer:=	strobetimer;	// mark intervall start
//writeln('TimeStrobeX: mode:'+GetEnumName(TypeInfo(t_Strobe_flag),Ord(mode))+' state:'+GetEnumName(TypeInfo(t_Strobe_flag),Ord(state)));		
	  strobeONtimer:=		strobetimer +	strobeON_us; // pwm ON time
	end;  

   	OUTstatOld:=OUTstat;
	OUTstat:=0;
	if (strobetimer >= strobeONtimer) then
//	if RPI_TimeElapsed_us(	strobetimer,	strobeONtimer,	0) then 
	begin
	  if (state=STB_OneShot) then state:=STB_Off;
	end 
	else 
	begin
	  if (state<>STB_Off) then OUTstat:=1;
	end;
	OUTtrigger:=(OUTstat<>OUTstatOld);

	TimeStrobe:=OUTstat;
  end; // with
end;

function  TimeStrobeShowStr(var StrobeStruct:StrobeStruct_t; msg:string):string;
var sh:string;
begin
  with StrobeStruct do
  begin
	sh:='StrobeStruct['+Num2Str(seq,0)+'/'+
		msg+'/'+GetEnumName(TypeInfo(t_Strobe_flag),ord(state))+']:'+
		' dty:'+Num2Str(strobeDTYcycle,4,2)+
		' OutTrigger:'+Bool2YNS(OUTtrigger)+
		' OUTstat:'+Bool2YNS(Num2Bool(OUTstat))+
		' strobeINT:'+Num2Str(strobeINT_us,0)+
		' strobeON:'+Num2Str(strobeON_us,0)+
		' strobeINTstartTimer:'+Num2Str(strobeINTstartTimer,0)+
		' strobeTimerDelta:'+Num2Str(strobetimer-strobeINTstartTimer,0);
//		' strobeONtimerDelta:'+Num2Str(strobeONtimer-strobeINTstartTimer,0);
  end; // with
  TimeStrobeShowStr:=sh;
end;

procedure TimeStrobeShow(var StrobeStruct:StrobeStruct_t; lvl:T_ErrorLevel; msg:string);
begin LOG_Writeln(lvl,TimeStrobeShowStr(StrobeStruct,msg)); end;

procedure TEST_TimeStrobe(filename:string);
const
  Polltime_us_c=100;	// 100us takt	
  ival_c=1000000; 		// Intervall 1sec
var 
  StrobeStruct:StrobeStruct_t; 
  trig:boolean; i64:int64;
  tim0:qword; dt:TDateTime; tl:TStringList;
begin
  if not RPI_HW_Start then begin writeln('TEST_TimeStrobe: can not init HW'); halt; end;
  tl:=TStringList.create;
  tl.add('tim,out,dty');
  SetTimeOut(dt,20000); // 20sec
  
  TimeStrobeInit(StrobeStruct,0,ival_c);
TimeStrobeShow(StrobeStruct, LOG_WARNING, 'after  init');
TimeStrobe(StrobeStruct);
TimeStrobeShow(StrobeStruct, LOG_WARNING, 'afterStrobe');  

//  TimeStrobeDutyAsyn(StrobeStruct,0.0); 	// 25% of ival_c

//TimeStrobeOneShotAsyn(StrobeStruct,0.5);
//TimeStrobeMode(StrobeStruct,[STB_OneShot],ival_c div 10);
TimeStrobeShow(StrobeStruct, LOG_WARNING, 'afterMode');


  with StrobeStruct do
  begin
	tim0:=strobeOLDtimer;

  	repeat  	  
  	  TimeStrobe(StrobeStruct);
	  if (seq=0) then tim0:=strobeOLDtimer;

	  if OUTtrigger then
	  begin
	  	tl.add(Num2Str(strobeOLDtimer-tim0,0)+','+Num2Str(OUTstatOld,0)+','+Num2Str(StrobeStruct.strobeDTYcycle,0,2));
	  	tl.add(Num2Str(strobetimer-tim0,0)+','+   Num2Str(OUTstat,0)+','+   Num2Str(StrobeStruct.strobeDTYcycle,0,2));
	  end;
	  
	  trig:=true;
  	  case seq of
 	     17700: TimeStrobeMode(StrobeStruct, [STB_IntvalSet,STB_Async], (ival_c div 2));
  	   	 35000: TimeStrobeDutyAsyn(StrobeStruct,0.50);
 	     50010: TimeStrobeDutyAsyn(StrobeStruct,1.00);
 	     85000: TimeStrobeDutyAsyn(StrobeStruct,0.50);
  	  	125000..
  	  	154000: TimeStrobeDutyAsyn(StrobeStruct,0.25);
        155000: TimeStrobeDutyAsyn(StrobeStruct,0.01);
		else	  trig:=false;
	  end; // case

	  if trig then
	  begin
	  	tl.add(Num2Str(strobetimer-tim0,0)+','+Num2Str(OUTstat,0)+','+Num2Str(StrobeStruct.strobeDTYcycle,0,2));
	  	trig:=false;
	  end;

	  inc(seq);
	  
	  i64:=RPI_GetPrecisionCounter_us-strobetimer;
	  if (i64<Polltime_us_c) then delay_us(Polltime_us_c-i64);
  	until terminateProg or keypressed or TimeElapsed(dt);

  end; // with
  TimeStrobeMode(StrobeStruct,[STB_OFF]);

  writeln('rec#:',tl.count,' ',filename);
  if (filename<>'') then
  begin
  	StringList2TextFile(filename,tl);
  	LNX_chowngrp(filename,'www-data','www-data');
  end else ShowStringList(tl);
  tl.free;
end;

{$IFDEF WINDOWS}
  function  CPUClockFrequency: int64; var rslt:int64; begin if not QueryPerformanceFrequency(rslt) then rslt:=-1; CPUClockFrequency:=rslt; end;
  procedure InitHighPrecisionTimer; var F : int64; begin F := CPUClockFrequency; HighPrecisionMillisecondFactor := F div 1000; HighPrecisionMicrosecondFactor := F div 1000000; HighPrecisionTimerInit := True; end;
  function  GetHighPrecisionCounter: Int64; var rslt:int64; begin if not HighPrecisionTimerInit then InitHighPrecisionTimer; QueryPerformanceCounter(rslt); GetHighPrecisionCounter:=rslt; end;
  procedure delay_nanos(Nanoseconds:int64); var i:longword; begin for i:=1 to 1000 do; end; // dummy
{$ELSE}
  function  GetHighPrecisionCounter: int64; var rslt:int64; TV : TTimeVal; TZ : PTimeZone; begin TZ := nil; fpGetTimeOfDay(@TV, TZ); rslt := int64(TV.tv_sec) * 1000000 + Int64(TV.tv_usec); GetHighPrecisionCounter:=rslt; end;

  procedure delay_nanos(Nanoseconds:int64);
  var res:longint; sleeper,remain:timespec;
  begin
	try
	  sleeper.tv_sec:=  Nanoseconds div nano_c;
      sleeper.tv_nsec:=	Nanoseconds mod nano_c;	// 0-999999999
      if (rpi_timespecresolution.tv_nsec<>1) then 
	  	sleeper.tv_nsec:= sleeper.tv_nsec div rpi_timespecresolution.tv_nsec;
      repeat
	  	res:=fpnanosleep(@sleeper,@remain);
	  	if (res<>0) then
	  	begin
		  sleeper:=remain;	// -1: nanosleep was interrupted, remain holds left ns
//		  LOG_Writeln(LOG_WARNING,'delay_nanos['+Num2Str(res,0)+']: '+TimeSpec2Str(@remain));
	  	end;
      until (res>=0);
    except
	  LOG_Writeln(LOG_ERROR,'delay_nanos: '+Num2Str(Nanoseconds,0));
    end;
  end; 
{$ENDIF}

function  RPI_MicroSecondsBetween(qTimer1,qTimer2:qword):int64;
var i64:int64;
begin 
  if (qTimer1>=qTimer2) 
	then i64:= (qTimer1-qTimer2)
	else i64:=-(qTimer2-qTimer1);
  RPI_MicroSecondsBetween:=i64; 
end;
 
{$IFDEF UNIX}
(*function  RPI_GetPrecisionCounter_us:qword;
var qT:qword;
begin 
  try
    Move(mmap_arr[STIMCLO],qT,Sizeof(qT)); // 1.5x faster
  except
    qT:=0;
    LOG_Writeln(LOG_ERROR,'RPI_GetPrecisionCounter_us');
  end;
  RPI_GetPrecisionCounter_us:=qT;
end;*)

function  RPI_GetPrecisionCounter_us:qword;
var qT:RPIreg64_t;
begin 
  try
    qT.RegHI32:=mmap_arr^[STIMCHI]; 
    qT.RegLO32:=mmap_arr^[STIMCLO];
  except
    qT.Reg64:=0;
    LOG_Writeln(LOG_ERROR,'RPI_GetPrecisionCounter_us');
  end;
  RPI_GetPrecisionCounter_us:=qT.Reg64;
end;

function  RPI_SetTimeOut_us(Retrig_us:longword):qword;
// e.g usage: qTimer:=RPI_SetTimeOut_us(123);
begin
  RPI_SetTimeOut_us:= RPI_GetPrecisionCounter_us + Retrig_us;
end;

procedure RPI_SetTimeOut_us(var qTimer:qword; Retrig_us:longword);
// depricated, use function above
// e.g usage: RPI_SetTimeOut_us(qTimer,123);
begin qTimer:=RPI_GetPrecisionCounter_us + Retrig_us; end;

function  RPI_SetTimer_us(var qTimerIN:qword; Retrig_us:longword):qword;
// e.g usage: qTimerOUT:=RPI_SetTimeOut_us(qTimerIN,123);
begin RPI_SetTimer_us:=qTimerIN+Retrig_us; end;

function  RPI_TimeElapsed_us(var actualqTimer,qTimer:qword; Retrig_us:longword):boolean;
// e.g usage: if RPI_TimeElapsed_us(qT,qTimer,123) then xxx;
var ok:boolean;
begin 
  try 
    actualqTimer:=RPI_GetPrecisionCounter_us;
	ok:=(actualqTimer >= qTimer);
  	if (ok and (Retrig_us>0)) then qTimer:= actualqTimer + Retrig_us;
  except
    LOG_Writeln(LOG_ERROR,'RPI_TimeElapsed_us: '+Num2Str(Retrig_us,0)+' check usage of RPI_HW_Start');
	ok:=true; // prevent endless loop, in case of error
  end;
  RPI_TimeElapsed_us:=ok;
end;

function  RPI_TimeElapsed_us(var qTimer:qword):boolean;
var qT:qword;
begin RPI_TimeElapsed_us:=RPI_TimeElapsed_us(qt,qTimer,0); end;

procedure RPI_TMR_Init(var RPI_TMR_struct:RPI_TMR_struct_t);
begin
  with RPI_TMR_struct do
  begin
	tim_start:=0;					tim_ende:=tim_start;
	tim_us:=0;						cnt:=0;
	tim_us_min:=high(int64);		tim_us_max:=low(int64);
  end; // end;
end;

procedure RPI_TMR_GetStartTime(var RPI_TMR_struct:RPI_TMR_struct_t);
begin
  try
	RPI_TMR_struct.tim_start:=RPI_GetPrecisionCounter_us;
  except
	LOG_Writeln(LOG_ERROR,'RPI_TMR_GetStartTime: check usage of RPI_HW_Start');
  end;
end;

procedure RPI_TMR_GetEndTime(var RPI_TMR_struct:RPI_TMR_struct_t);
begin
  try
	with RPI_TMR_struct do
  	begin
	  tim_ende:=RPI_GetPrecisionCounter_us; 
	  tim_us:=RPI_MicroSecondsBetween(tim_ende,tim_start);
	  MinMax(tim_us,tim_us_min,tim_us_max);
	  inc(cnt);
  	end; // with
  except
	LOG_Writeln(LOG_ERROR,'RPI_TMR_GetEndTime: check usage of RPI_HW_Start');
  end;
end;

procedure delay_us(Microseconds:longword);
var qEndTimer:qword; // qTimer,qt:qword; i64:int64;
begin 
  try
	if (Microseconds>0) then
  	begin
  	  qEndTimer:=RPI_SetTimeOut_us(Microseconds);
	
	  if (Microseconds>RPI_TightLoop_us_c)	// delay with low CPU usage
		then delay_nanos((Microseconds-RPI_TightLoop_us_c)*1000); 
		
//	  Move(mmap_arr^[STIMCLO],qt,Sizeof(qt)); // !!
        
      while (RPI_GetPrecisionCounter_us < qEndTimer) do; // tight loop with high CPU usage
      
(*    Move(mmap_arr^[STIMCLO],qTimer,Sizeof(qTimer));
	  if (qEndTimer<qt) then i64:=-(qt-qEndTimer) else i64:=qEndTimer-qt; 
	  writeln('delay_us: ',Microseconds:4,'us delta:',int64(qTimer-qEndTimer):4,' tightloop entry:',i64:4,' ',int64(Microseconds>RPI_TightLoop_us_c)); *)
  	end;
  except
	LOG_Writeln(LOG_ERROR,'delay_us: '+Num2Str(Microseconds,0)+' check usage of RPI_HW_Start');
  end;
end;

function  NanoSecondsBetween(ts1,ts2:timespec):int64;
var i64:int64;
begin
  i64:=	(ts1.tv_sec * nano_c + ts1.tv_nsec * rpi_timespecresolution.tv_nsec) -
  		(ts2.tv_sec * nano_c + ts2.tv_nsec * rpi_timespecresolution.tv_nsec);
  NanoSecondsBetween:=i64;
end;

function  MicroSecondsBetween(ts1,ts2:timespec):int64;
begin MicroSecondsBetween:=NanoSecondsBetween(ts1,ts2) div 1000; end;

function  MicroSecondsBetween(ts:timespec):int64;
var tsnow:timespec;
begin 
  clock_gettime(CLOCK_REALTIME,@tsnow);
  MicroSecondsBetween:=MicroSecondsBetween(tsnow,ts); 
end;

function  MilliSecsBetween(td:TDateTime):int64;
begin MilliSecsBetween:=MilliSecondsBetween(now,td); end;

procedure TimeElapsed_us_Test2(retrig_us,loops:longword);
var tv,tv_start,tv_end:timespec; us:qword; n:longint;
begin
  n:=0;
  clock_gettime(CLOCK_REALTIME,@tv_start); 
  while (n<loops) do
  begin
    if TimeElapsed_us(@tv,retrig_us) then inc(n);
  end;
  clock_gettime(CLOCK_REALTIME,@tv_end);
  us:=MicroSecondsBetween(tv_end,tv_start);
  
  clock_gettime(CLOCK_REALTIME,@tv_start); 
  tv_start:=tv;
  for n:=1 to loops do TimeElapsed_us(@tv,retrig_us); // just test code efficency
  clock_gettime(CLOCK_REALTIME,@tv_end); 
  
  writeln('TimeElapsed_us Test2:     ',us:9,'us (',100-(loops*retrig_us/us*100):5:3,'%) perf: ',(MicroSecondsBetween(tv_end,tv_start)/loops):0:3,'us/loop');
end;

procedure TimeElapsed_us_Test3(retrig_us,loops:longword);
var qTstart,qTend,qT,qT0:qword; us:qword; n:longint;
begin
  n:=0; 
  qT:=RPI_GetPrecisionCounter_us; 		// save starttime
  qTstart:=qT;
  while (n<loops) do
  begin
    if RPI_TimeElapsed_us(qT0,qT,retrig_us) then inc(n);
  end;
  qTend:=RPI_GetPrecisionCounter_us; 	// save endtime
  us:=RPI_MicroSecondsBetween(qTend,qTstart);
  
  qT:=RPI_GetPrecisionCounter_us; 		// save starttime
  qTstart:=qT;
  for n:=1 to loops do RPI_TimeElapsed_us(qT0,qT,retrig_us); // just test code efficency
  qTend:=RPI_GetPrecisionCounter_us; 	// save endtime
  
  writeln('RPI_TimeElapsed_us Test3: ',us:9,'us (',100-(loops*retrig_us/us*100):5:3,'%) perf: ',(RPI_MicroSecondsBetween(qTend,qTstart)/loops):0:3,'us/loop much more accurate and faster for us cycle times ');
end;

procedure TimeElapsed_us_Test; // piOS
const usval_c=10000; retrig_us=10; loops_c=1000000;
var tv_start,tv_end,tvh:timespec; qTstart,qTend,qT:qword;
begin
  writeln('Test(loops: ',loops_c,' ',(usval_c/1000):0:3,'ms ',usval_c:6,'us ',retrig_us,'us) rpi_timespecresolution: ',rpi_timespecresolution.tv_nsec,'ns');

  qTstart:=RPI_GetPrecisionCounter_us; 		// save starttime
  delay_us(usval_c); 
  qTend:=RPI_GetPrecisionCounter_us; 		// save endtime
  writeln('delay_us Test:            ',RPI_MicroSecondsBetween(qTend,qTstart):9,'us');

  clock_gettime(CLOCK_REALTIME,@tv_start); 	// save starttime
  SetTimeOut_us(@tvh,usval_c);
  while not TimeElapsed_us(@tvh) do ;
  clock_gettime(CLOCK_REALTIME,@tv_end); 	// save endtime
  writeln('TimeElapsed_us Test:      ',MicroSecondsBetween(tv_end,tv_start):9,'us');

  qTstart:=RPI_GetPrecisionCounter_us; 		// save starttime
  qT:=RPI_SetTimeOut_us(usval_c);
  while not RPI_TimeElapsed_us(qT) do ;
  qTend:=RPI_GetPrecisionCounter_us; 		// save endtime
  writeln('RPI_TimeElapsed_us Test:  ',RPI_MicroSecondsBetween(qTend,qTstart):9,'us');

  writeln;
  TimeElapsed_us_Test2(retrig_us,loops_c);
  TimeElapsed_us_Test3(retrig_us,loops_c);
end;

{$ELSE}
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
//    if (n>0) then begin sysutils.sleep(n); end;	
      if (n>0) then begin delay_msec(n); end;
	end;
    f:=int64(Microseconds*HighPrecisionMicrosecondFactor);
    repeat j:=GetHighPrecisionCounter; until (int64(j-i)>=f);
  end;
end;

function  MicroSecondsBetween(us1,us2:int64):int64;
begin MicroSecondsBetween:=int64((us1-us2)*HighPrecisionMicrosecondFactor); end;

procedure TimeElapsed_us_Test; // windows
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
{$ENDIF}

procedure USAGE_Init(nr:byte; var struct:HW_Usage_t; sect,key:string);
var sh:string;
begin
  with struct do
  begin
    sh:=CSV_Item(BIOS_GetIniString(sect,key,''),';',nr);
    if not Str2Num(CSV_Item(sh,1),usecnt) 		then usecnt:=0;
    if not Str2Num(CSV_Item(sh,2),usetimesec)	then usetimesec:=0;
    dat:=now;
  end;
end;

procedure TimeZoneString(TimeZoneString:string); begin _TZString:=TimeZoneString; end;
function  TimeZoneString:string; begin TimeZoneString:=_TZString end;

function  GetTimeZoneString:string;
(* timedatectl --no-ask-password status
               Local time: Fri 2021-08-13 12:54:16 UTC
           Universal time: Fri 2021-08-13 12:54:16 UTC
                 RTC time: Fri 2021-08-13 12:54:18
                Time zone: Etc/UTC (UTC, +0000)
System clock synchronized: yes
              NTP service: active
          RTC in local TZ: no
*)
var _tl:TStringList; n:longint; sh1,sh2:string;
begin
  _tl:=TStringList.create;
  call_external_prog(LOG_ERROR,'timedatectl --no-ask-password status',_tl);
  if (_tl.count>0) then
  begin
    n:=1;
//	showstringlist(_tl);
  	while (n<=_tl.count) do
  	begin
	  if (_tl[n-1]<>'') then
	  begin
	    sh1:=CSV_Item(			_tl[n-1],':',1);
	    sh2:=CSV_RightItems(	_tl[n-1],':',2);
	    if (Pos('TIME ZONE',Upper(sh1))>0) then
	    begin
	      if (Length(sh2)>0) then // Etc/UTC (UTC, +0000)
	    	TimeZoneString(Trimme(Select_Item(sh2,' (','',1),3)); // Etc/UTC
//		  writeln('GetTimeZoneString:',TimeZoneString,':',CR);
	      n:= _tl.count;
	    end;
	  end;
	  inc(n);
	end; // while
  end;
  _tl.free;
  GetTimeZoneString:=TimeZoneString;
end;

function  CalcUTCOffsetString(offset_Minutes:longint; withcolon:boolean):string; // e.g. '+02:00'
var sh:string[6]='-0000';
begin
  if (offset_Minutes<>0) then
  begin  
	if (offset_Minutes<=0) then sh:='-' else sh:='+';
  	if withcolon 
	  then sh:=sh+LeadingZero(abs(offset_Minutes) div 60)+':'+LeadingZero(abs(offset_Minutes) mod 60)
	  else sh:=sh+LeadingZero(abs(offset_Minutes) div 60)+	  LeadingZero(abs(offset_Minutes) mod 60);
  end else if withcolon then sh:='-00:00';
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
  _TZOffsetString:=CalcUTCOffsetString(_TZLocal,true);
end;

function  GetUTCOffsetString:string; // e.g. '+02:00'
begin GetUTCOffsetString:=_TZOffsetString; end;

function  GetUTCOffsetMinutes(ofs:string):longint; // e.g. -02:00 -> -120
var mins,hours,li:longint;
begin
  if (Pos(':',ofs)>0)
	then ofs:=StringReplace(ofs,':','',[rfReplaceAll]); // -0200

  case Length(ofs) of
	5:	begin // -0200
		  if not Str2Num(copy(ofs,4,2),mins)  then mins:= 0;
		  if not Str2Num(copy(ofs,1,3),hours) then hours:=0;
		  if (hours>=0)
			then li:=hours*60+mins
			else li:=hours*60-mins;
		end;
   1,3:	begin // -120 // EDT // Military 1ALPHA (RFC1123 carry no information )
		  if not Str2Num(ofs,li) then 
		  begin
			mins:=0; hours:=0;
			if (ofs='EDT') then hours:=-4
			  else if (ofs='EST') then hours:=-5
				else if (ofs='CDT') then hours:=-5
				  else if (ofs='CST') then hours:=-6
				    else if (ofs='MDT') then hours:=-6
				      else if (ofs='MST') then hours:=-7
				    	else if (ofs='PDT') then hours:=-7
				    	  else if (ofs='PST') then hours:=-8;
(*				    		else if (ofs='A') then hours:=-1		// 1ALPHA  
				    		  else if (ofs='M') then hours:=-12		// 1ALPHA
				    			else if (ofs='N') then hours:=+1	// 1ALPHA
				    			  else if (ofs='Y') then hours:=+12;// 1ALPHA *)			    	  
			if (hours>=0)
			  then li:=hours*60+mins
			  else li:=hours*60-mins;
		  end;
		end;
	else	li:=0;
  end; // case
  GetUTCOffsetMinutes:=li;
end;

function  GetDateTimeUTC(dt:TDateTime; tzofs:longint):TDateTime; begin GetDateTimeUTC:=IncMinute(dt,-tzofs); end;
function  GetDateTimeUTC:   TDateTime; begin GetDateTimeUTC:=GetDateTimeUTC(now,_TZLocal); end;
function  GetDateTimeLocal: TDateTime; begin GetDateTimeLocal:=now; end;
function  GetDateTimeLocal(utc:TDateTime):TDateTime; begin GetDateTimeLocal:=IncMinute(utc,_TZLocal); end;

function  GetDateTimefromUTC(tstmp:string; var dt:TDateTime):boolean;
// IN: 'Fri, 22 Jun 2018 15:05:27 GMT'
begin GetDateTimefromUTC:=Str2DateTime(tstmp,11,dt); end;

function  GetDateTimefromTimeDateCtlUTC(tstmp:string; var dt:TDateTime):boolean;
// IN: 'Thu 2021-08-26 07:38:17 UTC'
begin GetDateTimefromTimeDateCtlUTC:=Str2DateTime(tstmp,13,dt); end;

function  DateTime00MS(dt:TDateTime):TDateTime;
// get rid of ms
var YY,MM,DD,hh,mi,sec,ms:word; 
begin
  DecodeDateTime(dt,YY,MM,DD,hh,mi,sec,ms);
  DateTime00MS:=EncodeDateTime(YY,MM,DD,hh,mi,sec,00);
end;

function  DateTime2FMT(fmt:integer; dt:TDateTime):string;
var _dt1,_dt2:TDateTime; YY,MM,DD:word; sh:string;
begin
  case fmt of
	   1: sh:=FormatDateTime('yyyy-mm-dd" "hh:nn:ss.zzz',dt);
	   2: sh:=FormatDateTime('yyyy-mm-dd"T"hh:nn:ss.zzz',dt);
	   3: sh:=FormatDateTime('yyyy-mm-dd',dt);
	   4: sh:=FormatDateTime('yyyy-mm-dd" "hh:nn:ss',dt);
	   5: begin 
			DecodeDate(dt, YY,MM,DD); 	_dt1:=EnCodeDate(YY,MM,DD);
			DecodeDate(now,YY,MM,DD); 	_dt2:=EnCodeDate(YY,MM,DD);
			if (_dt1=_dt2) then sh:='Today'
			  else if (_dt1=IncDay(_dt2,-1)) then sh:='Yesterday'
				else sh:=DateTime2FMT(3,dt);
			sh:=sh+' '+FormatDateTime('hh:nn',dt);
		  end;
	   6: sh:=DateTime2FMT(4,dt)+_TZOffsetString;
	   7: sh:=DateTime2FMT(2,dt)+_TZOffsetString;
	   
	   8: sh:=FormatDateTime('yyyymmddhhnnss',dt);
	   9: sh:=FormatDateTime('yyyy-mm-dd"T"hh:nn:ss',dt);
	else  sh:=DateTime2FMT(1,dt);
  end; // case
  DateTime2FMT:=sh;
end;

function  Str2DateTime(const tdstring,fmt:string; var dt:TDateTime):boolean;
var _ok:boolean;
begin 
  try
	_ok:=true;
	dt:=ScanDateTime(fmt,tdstring);
  except
	_ok:=false;
  end;
  Str2DateTime:=_ok; 
end; 

function  Str2DateTime(const tdstring:string; fmtsel:integer; var dt:TDateTime):boolean;	 
var ok:boolean; sh:string;
begin
  try
  	ok:=true;
    case fmtsel of	
       1:	dt:=ScanDateTime(	'yyyy-mm-dd hh:nn:ss.zzz',		tdstring);
       2:	dt:=ScanDateTime(	'yyyy-mm-dd"T"hh:nn:ss.zzz',	tdstring);
       3:	dt:=ScanDateTime(	'yyyy-mm-dd',					tdstring);
       4:	dt:=ScanDateTime(	'yyyy-mm-dd hh:nn:ss',			tdstring);
       5:	begin
       		  sh:=tdstring;
    		  sh:=StringReplace(sh,'Today',	   DateTime2FMT(3,now),[rfReplaceAll,rfIgnoreCase]);
    		  sh:=StringReplace(sh,'Yesterday',DateTime2FMT(3,IncDay(now,-1)),[rfReplaceAll,rfIgnoreCase]);
       		  dt:=ScanDateTime(	'yyyy-mm-dd hh:nn',				sh);
       		end;
       6:	dt:=GetDateTimeUTC(
			  	  ScanDateTime(	'yyyy-mm-dd hh:nn:ss',			tdstring),
			  	  GetUTCOffsetMinutes(CSV_Item(tdstring,' ',CSV_Count(tdstring,' ')))
			  	 );
       7:	dt:=GetDateTimeUTC(
			  	  ScanDateTime(	'yyyy-mm-dd"T"hh:nn:ss.zzz',	tdstring),
			  	  GetUTCOffsetMinutes(CSV_Item(tdstring,' ',CSV_Count(tdstring,' ')))
			  	 );
       8:	dt:=ScanDateTime(	'yyyymmddhhnnss',				tdstring);
       9:	dt:=ScanDateTime(	'yyyy-mm-dd"T"hh:nn:ss',		tdstring);
	  10:	dt:=ScanDateTime(	'ddd, dd mmm yy hh:nn:ss',		tdstring);
	  11:	dt:=ScanDateTime(	'ddd, dd mmm yyyy hh:nn:ss',	tdstring);
      12:	dt:=ScanDateTime(	'dd mmm yy hh:nn:ss',			tdstring);    
      13:	dt:=ScanDateTime(	'ddd, dd mmm yy hh:nn',			tdstring);
	  14:	dt:=ScanDateTime(	'ddd, dd mmm yyyy hh:nn',		tdstring);
	  15:	dt:=ScanDateTime(	'ddd yyyy-mm-dd hh:nn:ss',		tdstring);
	  else	ok:=false;
    end;
  except
    ok:=false;
  end;
  Str2DateTime:=ok;
end;

function  RFC822DateTimeDecode(const tstmp:string; var dt:TDateTime):boolean;
(*	https://github.com/log2timeline/dfdatetime/issues/162
	https://datatracker.ietf.org/doc/html/rfc822#section-5
	Fri, 22 Jun 2018 15:05:27 +0100	// RFC 822, updated by RFC 1123
	Sun, 06 Nov 94 08:49:37 GMT
	06 Nov 94 08:49:37 Z *)
var ok:boolean; // li:longint; zs:string;
begin
  ok:=true;
  if not Str2DateTime(tstmp,10,dt) then 		// 'ddd, dd mmm yy hh:nn:ss'
  	if not Str2DateTime(tstmp,11,dt) then 		// 'ddd, dd mmm yyyy hh:nn:ss'
  	  if not Str2DateTime(tstmp,12,dt) then		// 'dd mmm yy hh:nn:ss'
  	 	if not Str2DateTime(tstmp,13,dt) then	// 'ddd, dd mmm yy hh:nn'
  	 	  if not Str2DateTime(tstmp,14,dt) then ok:=false; // 'ddd, dd mmm yyyy hh:nn'

  if ok then
	dt:=GetDateTimeUTC(dt,GetUTCOffsetMinutes(CSV_Item(tstmp,' ',CSV_Count(tstmp,' '))));

(*if ok then
  begin // handle zone
	zs:=CSV_Item(tstmp,' ',CSV_Count(tstmp,' ')); // +0100
	li:=GetUTCOffsetMinutes(zs);
	dt:=GetDateTimeUTC(dt,li);
	writeln(tstmp,':',zs,':',li,':',DateTime2FMT(4,dt));
  end; *)  
  RFC822DateTimeDecode:=ok;
end;

procedure RFC822DateTimeTest;
  procedure RFC822(s:string);
  var dt:TDateTime;
  begin
  	if RFC822DateTimeDecode(s,dt)
  	  then writeln(DateTime2FMT(4,dt), ' <-- ',s)
	  else writeln(s,'   convert not ok');
  end;
begin
  RFC822('Sun, 06 Nov 1994 08:49:37 -0130');// RFC 822, updated by RFC 1123
  RFC822('Sun, 06 Nov 94 08:49:37 GMT');	// RFC 822
  RFC822('Sun, 06 Nov 94 08:49 PST');		// RFC 822
  RFC822('06 Nov 94 08:49:37 N');			// RFC 822, updated by RFC 1123 (carry no info)
  RFC822(RFC822DateTimeEncode);
end;

function  RFC822DateTimeEncode(dt:TDateTime; tzofs:longint):string; // Sat, 14 Aug 2021 07:57:03 -0000
// https://www.freepascal.org/docs-html/rtl/sysutils/formatchars.html
begin
  RFC822DateTimeEncode:=
	FormatDateTime('ddd, dd mmm YYYY hh:mm:ss',dt)+' '+
	CalcUTCOffsetString(tzofs,false);
end;
function  RFC822DateTimeEncode(dt:TDateTime):string;
begin RFC822DateTimeEncode:=RFC822DateTimeEncode(dt,_TZLocal); end;
function  RFC822DateTimeEncode:string;
begin RFC822DateTimeEncode:=RFC822DateTimeEncode(now,_TZLocal); end;

function  GetXMLTimeStamp(dt:TDateTime):string; // YEAR-MM-DDThh:mm:ss.zzz+XX:XX
begin GetXMLTimeStamp:=DateTime2FMT(7,dt); end; 

function  GetTimeStamp(dt:TDateTime):string; // YEAR-MM-DD hh:mm:ss.zzz
begin GetTimeStamp:=DateTime2FMT(1,dt); end; 

function  GetTZTimeStamp(dt:TDateTime):string; // YEAR-MM-DD hh:mm:ss.zzz+XX:XX
begin GetTZTimeStamp:=DateTime2FMT(4,dt); end; 

function  GetDateTimefromXMLTimeStamp(tstmp:string; var dt:TDateTime; var tzofs:longint):boolean;
// IN: 2018-06-26T16:01:12.070+02:00
//     2019-04-16T20:09:25.745+02:00
// 	   2021-08-26T09:24:50.242Z,-120
var _ok:boolean; p:longint; dats,tims:string; 
begin    
  p:=Pos('T',tstmp);
  if (p>0)
	then begin tims:=copy(tstmp,p+1,Length(tstmp)); dats:=copy(tstmp,1,p-1); end 
	else begin tims:=tstmp; dats:=DateTime2FMT(3,now); end;
  
  				p:=Pos('Z',tims);	// 16:01:12.070Z
  if (p>0) then inc(p);				// get rid of Z
  if (p=0) then p:=Pos('+',tims);	// 16:01:12.070+02:00
  if (p=0) then p:=Pos('-',tims);	// 16:01:12.070-02:00
  if (p>0) then
  begin
    tzofs:= GetUTCOffsetMinutes(copy(tims,p,Length(tims)));
//writeln('tims:',tims,':tzofs:',tzofs,':p=',p,':lgt=',Length(tims));
//tims:09:24:50.242Z-120:tzofs:0:p=14:lgt=17
    tims:=	copy(tims,1,p-1);
  end else tzofs:=0;
//GetDateTimefromXMLTimeStamp:2021-08-26|09:24:50.242|20|2021-08-26T09:24:50.242Z-120
//writeln;writeln('GetDateTimefromXMLTimeStamp:',dats,'|',tims,'|',tzofs,'|',tstmp);
  _ok:=	 Str2DateTime(dats+' '+tims,1,dt);	// 'yyyy-mm-dd hh:nn:ss.zzz'
  if not _ok then 
	_ok:=Str2DateTime(dats+' '+tims,4,dt);	// 'yyyy-mm-dd hh:nn:ss'
  GetDateTimefromXMLTimeStamp:=_ok
end;

function  GetUTCDateTimefromXMLTimeStamp(tstmp:string; var dt:TDateTime):boolean;
var _ok:boolean; tzofs:longint;
begin
  _ok:=GetDateTimefromXMLTimeStamp(tstmp,dt,tzofs);
  if _ok then dt:=GetDateTimeUTC(dt,tzofs);
  GetUTCDateTimefromXMLTimeStamp:=_ok;
end;

procedure TST_GetDateTimefromXMLTimeStamp(tstmp:string);
var ok:boolean; dt:TDateTime; tzofs:longint;
begin
  dt:=0;
  writeln(tstmp); 
  ok:=GetDateTimefromXMLTimeStamp(tstmp,dt,tzofs);
  writeln(FormatDateTime('YYYY-MM-DD" "hh:mm:ss.zzz',dt),' ',tzofs:0,' ',ok);
  if ok then
    writeln(FormatDateTime('YYYY-MM-DD" "hh:mm:ss.zzz',GetDateTimeUTC(dt,tzofs)),' (UTC)');
  writeln;
end;

procedure GetDateTimefromXMLTimeStamp_Test;
begin
  TST_GetDateTimefromXMLTimeStamp('2017-07-06T16:01:12.070-02:00');
  TST_GetDateTimefromXMLTimeStamp('16:01:12.070+02:00');
  TST_GetDateTimefromXMLTimeStamp('16:01:12+02:00');
  TST_GetDateTimefromXMLTimeStamp('16:01:12.123456');
  TST_GetDateTimefromXMLTimeStamp('16:01:12.070Z');
  TST_GetDateTimefromXMLTimeStamp('2017-07-06 16:01:12.070-02:00');
end;

function  LogLvl2Str(lvl:T_ErrorLevel):string;
begin 
  LogLvl2Str:=StringReplace(
  	GetEnumName(TypeInfo(T_ErrorLevel),ord(lvl)),'LOG_','',[rfReplaceAll,rfIgnoreCase]);
end;

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
  if Pos('NONE',	slvl)>0 then lvl:=LOG_NONE;   
  if Pos('ALL',		slvl)>0 then lvl:=LOG_ALL;   
  Str2LogLvl:=lvl;
end;

function  StrShort2LogLvl(s:string; dfltlvl:T_ErrorLevel):T_ErrorLevel;
var lvl:T_ErrorLevel; slvl:string;
begin
  lvl:=dfltlvl;   	slvl:=Upper(s);
  if Pos('ERR',		slvl)>0 then lvl:=LOG_ERROR;
  if Pos('WRN',		slvl)>0 then lvl:=LOG_WARNING; 
  if Pos('SUC',		slvl)>0 then lvl:=LOG_NOTICE; 
  if Pos('INF',		slvl)>0 then lvl:=LOG_INFO; 
  if Pos('URG',		slvl)>0 then lvl:=LOG_URGENT; 
  if Pos('NON',		slvl)>0 then lvl:=LOG_NONE; 
  if Pos('ALL',		slvl)>0 then lvl:=LOG_ALL; 
  if Pos('MAG',		slvl)>0 then lvl:=LOG_MAGENTA; 
  if Pos('RED',		slvl)>0 then lvl:=LOG_RED; 
  if Pos('ORA',		slvl)>0 then lvl:=LOG_ORANGE; 
  if Pos('YLW',		slvl)>0 then lvl:=LOG_YELLOW; 
  if Pos('GRN',		slvl)>0 then lvl:=LOG_GREEN;
  if Pos('LGR',		slvl)>0 then lvl:=LOG_LGREEN; 
  if Pos('BLU',		slvl)>0 then lvl:=LOG_BLUE;
  if Pos('BLK',		slvl)>0 then lvl:=LOG_BLACK;
  if Pos('WHT',		slvl)>0 then lvl:=LOG_WHITE; 
  StrShort2LogLvl:=lvl;
end;

function  GetLogLvls(tr:string):string;
var sh:string;
begin
  sh:='ERROR'+tr+'WARNING'+tr+'INFO';
  GetLogLvls:=sh;
end;

function  LOG_Get_LevelStringShort(lvl:T_ErrorLevel):string;
var  s:string;
begin
  s:='UKN'; 
  case lvl of
(*  LOG_WHITE,LOG_BLACK,LOG_BLUE,LOG_LGREEN,
  	LOG_GREEN,LOG_YELLOW,LOG_ORANGE,
  	LOG_RED:	s:='COL'; *)
    LOG_RED:	s:='RED';
  	LOG_ORANGE:	s:='ORA';
  	LOG_YELLOW:	s:='YLW';
  	LOG_GREEN:	s:='GRN';
  	LOG_LGREEN:	s:='LGR';
  	LOG_BLUE:	s:='BLU';
  	LOG_BLACK:	s:='BLK';
  	LOG_WHITE:	s:='WHT';
  	LOG_MAGENTA:s:='MAG';
  	
    LOG_ERROR:	s:='ERR';
    LOG_WARNING:s:='WRN';
    LOG_NOTICE:	s:='SUC';
    LOG_INFO:	s:='INF';
    LOG_DEBUG:	s:='DBG';
	LOG_URGENT:	s:='URG';
	LOG_ALL: 	s:='ALL';
	LOG_NONE2,
	LOG_NONE: 	s:='NON';
	else		s:=LogLvl2Str(lvl);
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

procedure HeapStatINI(var struct:HeapStat_t; HSname:string; indentcnt:byte; replvl:T_ErrorLevel);
var _n:longint;
begin
  with struct do
  begin
    lvl:=replvl;
    if (HSname<>'') then name:=HSname else name:='HeapStat';
    name:=copy('          ',1,indentcnt)+name;
	for _n:= 0 to HeapStatMax_c do HeapStatAlloc[_n]:=0; 
	HeapStatAlloc[0]:=GetHeapStatus.TotalAllocated;
  end; // with
end;

procedure HeapStat(var struct:HeapStat_t; idx:longint);
begin
  with struct do
  begin
    if (idx>=0) and (idx<=HeapStatMax_c) then
    begin
      HeapStatAlloc[idx]:=GetHeapStatus.TotalAllocated;
  	  if (HeapStatAlloc[0]<>HeapStatAlloc[idx]) then 
  	  begin
(*  	    SetTextCol(lvl);
  	  	writeln(Get_LogString('','','',lvl)+name+'[0/'+Num2Str(idx,2)+']: '+Num2Str(HeapStatAlloc[0],7)+' '+Num2Str(HeapStatAlloc[idx],7)+#$0d);   
   	 	UnSetTextCol; *)
   	  	HeapStatAlloc[0]:=HeapStatAlloc[idx];
  	  end; 
  	end else LOG_Writeln(LOG_ERROR,'HeapStat['+Num2Str(idx,0)+'/'+Num2Str(HeapStatMax_c,0)+']: increase const HeapStatMax_c');
  end; // with
end;

function  FileAccessible(filnam:string):boolean;
var res:longint; {$IFDEF UNIX}info:stat;{$ENDIF}
begin
  res:=-1; filnam:=PrepFilePath(Trimme(filnam,3));
  if (filnam<>'') then
  begin
{$IFDEF UNIX}
	if (fpstat(filnam,info)<>0) then 
	begin
	  res:=fpGetErrNo;
	  LOG_Writeln(LOG_ERROR,'FileAccessible['+Num2Str(res,0)+'] '+SysErrorMessage(res)+': '+filnam);
	end else res:=0;
{$ELSE}
	if FileExists(filnam) then res:=0;
	if (res<>0) then LOG_Writeln(LOG_ERROR,'FileAccessible: file not exist '+filnam);
{$ENDIF}
  end; 
  FileAccessible:=(res=0);
end;

procedure ColTest;
var b:byte;
begin
  for b:=0 to 255 do
  begin
    if (b<>blink) then
    begin // no blink
	  TextColor(b);
	  SAY(LOG_INFO,Num2Str(b,3)+' TextTextTextTextTextTextTextTextTextTextText');
	end else SAY(LOG_INFO,Num2Str(b,3)+' Blink');
	NormVideo;
  end;
end;

procedure SetTextCol(typ:T_ErrorLevel);
// https://wiki.freepascal.org/Colors
begin
  if _LOG_LevelColor then 
  begin
	case typ of
		LOG_URGENT:		TextColor(LightRed);
		LOG_RED,
        LOG_ERROR:		TextColor(red);
        LOG_YELLOW,
      	LOG_WARNING:	TextColor(yellow);
      	LOG_GREEN,
      	LOG_NOTICE:		TextColor(green);
      	LOG_MAGENTA:	TextColor(magenta);
      	LOG_WHITE:		TextColor(white);
      	LOG_BLACK:		TextColor(black);
      	LOG_BLUE:		TextColor(blue); 
      	LOG_CYAN:		TextColor(cyan); 
      	LOG_BROWN:		TextColor(brown);
//     	LOG_ORANGE:		TextColor(orange);
      	LOG_LGRAY:		TextColor(LightGray);
      	LOG_DGRAY:		TextColor(DarkGray); 
      	LOG_LBLUE:		TextColor(LightBlue);  
      	LOG_LGREEN:		TextColor(LightGreen);
      	LOG_LCYAN:		TextColor(LightCyan);
      	LOG_LRED:		TextColor(LightRed);
      	LOG_LMAGENTA:	TextColor(LightMagenta);       	
    end; // case
  end;
end;
procedure UnSetTextCol; begin if _LOG_LevelColor then NormVideo; end;

function  MSG_HUB(lvl:t_ErrorLevel; msgtype:MSG_Type_t; msg:string):longint;
// Hook to pass messages to upper level units. OLED displays...
// install: MSG_HUB_ptr:=@YourOwnFunction;
var res:longint;
begin
  if (MSG_HUB_ptr<>nil) then res:=MSG_HUB_ptr(lvl,msgtype,msg) else res:=-1;
  MSG_HUB:=res;
end;

function Adj_LF(strIN:string):string; 
begin Adj_LF:=StringReplace(strIN,#$0a,#$0d+#$0a,[rfReplaceAll]); end;

// writes to STDOUT
function  SAY_Level:t_ErrorLevel; 		 begin SAY_Level:=_SAY_Level; end;
procedure SAY_LevelSave;    	 		 begin _SAY_OLD_Level:=_SAY_Level; end;
procedure SAY_Level(level:t_ErrorLevel); begin SAY_LevelSave; if level<LOG_NONE then _SAY_Level:=level else _SAY_Level:=LOG_NONE2; end;
procedure SAY_LevelRestore; 			 begin SAY_Level(_SAY_OLD_Level); end;
procedure SAY_TL(typ:T_ErrorLevel; tl:TStringList); var i:longint; begin for i:=1 to tl.count do SAY(typ,tl[i-1]); end;
procedure SAY   (typ:T_ErrorLevel; const msg:string; const params:array of const);overload; begin SAY(typ,Format(msg,params)); end;

procedure SAY   (typ,col:T_ErrorLevel; msg:string); 
begin 
  if (typ>=_SAY_Level) then 
  begin 
	SetTextCol(col); 
	writeln(Get_LogString('','','',typ)+msg+#$0d); 
	UnSetTextCol; 
  end; 
end;
procedure SAY(typ:T_ErrorLevel; msg:string); 
begin SAY(typ,typ,msg); end;

procedure LOG_Writeln(typ,col:T_ErrorLevel; msg:string); 
begin
  if (typ>=_LOG_Level) then 
  begin 
	SetTextCol(col); 
//	write(StdErr,#$0d+Get_LogString('','','',typ)+msg+#$0d+#$0a); 
	writeln(StdErr,Get_LogString('','','',typ)+msg+#$0d); 
	UnSetTextCol; 
  end; // else write(StdErr,#$0d);
end;

procedure LOG_Writeln(typ:T_ErrorLevel; msg:string); 
begin LOG_Writeln(typ,typ,msg); end;

procedure LOGSAY_tst;
begin
  writeln('Test (start):');
  LOG_Writeln(LOG_ERROR,	'Line2 (LOG)');
  LOG_Writeln(LOG_WARNING,	'Line3 (LOG)');
  writeln(					'Line4');
  LOG_Writeln(LOG_WARNING,	'Line5 (LOG)');
  SAY		 (LOG_NOTICE,	'Line6 (SAY)');
  LOG_Writeln(LOG_WARNING,	'Line7 (LOG)');
  writeln(					'Line8');
  writeln('Test (end)');
end;

function  Log_Shorting:boolean; begin Log_Shorting:=false; end; 

procedure LOG_ShowStringList(typ1,typ2:T_ErrorLevel; ts:TStringList); 
var i:longint; 
begin 
  if (typ1>=_LOG_Level) then 
  begin 
    if LOG_Shorting then 
	begin
	  if ts.Count>=35 then
	  begin
	    for i := 1          to 13       do Log_Writeln(typ1,typ2,ts[i-1]);
		                                   Log_Writeln(typ1,typ2,'<! Output shortend, total lines: '+Num2Str(ts.count,0)+'>');
		for i := ts.Count-6 to ts.Count do Log_Writeln(typ1,typ2,ts[i-1]);
	  end
	  else for i := 1 to ts.Count do Log_Writeln(typ1,typ2,ts[i-1]);
	end
	else
    begin
	  for i := 1 to ts.Count do Log_Writeln(typ1,typ2,ts[i-1]);
    end;	
    Flush(ErrOutput);	
  end; 
end;

procedure LOG_ShowStringList(typ:T_ErrorLevel; ts:TStringList); 
begin LOG_ShowStringList(typ,typ,ts); end;

function  LOG_Level:t_ErrorLevel; 		 begin LOG_Level:=_LOG_Level; end;
procedure LOG_LevelSave;    			 begin _LOG_OLD_Level:=_LOG_Level; end;
procedure LOG_Level(level:T_ErrorLevel); begin LOG_LevelSave; if level<LOG_NONE then _LOG_Level:=level else _LOG_Level:=LOG_NONE2; end;
procedure LOG_LevelRestore; 			 begin LOG_Level(_LOG_OLD_Level); end;
procedure LOG_LevelColor(enab:boolean);	 begin _LOG_LevelColor:=enab; end;

function  LOG_GetEndMsg(comment:string):string;
var sh:string;
begin  
  if comment<>'' then sh:=comment else sh:=ApplicationName;
  LOG_GetEndMsg:=sh+' ended at '+FormatDateTime('dd.mm.yyyy hh:mm:ss.zzz',now)+', runtime was '+FormatDateTime('hh:mm:ss.zzz',Now-RPI_ProgramStartTime); 
end;

procedure LOG_SAY_Level(mask:byte);
var saylvl,loglvl:byte;
begin
  loglvl:= (mask and $0f);
  case loglvl of
	0: LOG_Level(LOG_NONE);
	1: LOG_Level(LOG_ERROR);
	2: LOG_Level(LOG_WARNING);
	3: LOG_Level(LOG_INFO);
	4: LOG_Level(LOG_DEBUG);
//	else LOG_Writeln(LOG_ERROR,'LOG_LevelSet: 0x'+HexStr(loglvl,2)+' wrong loglvl');
  end; // case
  saylvl:=((mask and $f0) shr 4);
  case saylvl of
	0: SAY_Level(LOG_NONE);
	1: SAY_Level(LOG_ERROR);
	2: SAY_Level(LOG_WARNING);
	3: SAY_Level(LOG_INFO);
	4: SAY_Level(LOG_DEBUG);
//	else LOG_Writeln(LOG_ERROR,'LOG_LevelSet: 0x'+HexStr((saylvl shl 4),2)+' wrong saylvl');
  end; // case
//writeln('LOG_SAY_Level: 0x'+HexStr(mask,2));
end;

function  LOG_GetVersion(version:real):string; 		
begin LOG_GetVersion:=ApplicationName+' V'+Num2Str(version,0,3)+' build '+RPI_GetBuildDateTimeString; end;

procedure DBGlog_Set(var dbgstruct:dbg_log_t; logLVL:T_ErrorLevel; logMode,trgMode,resFMT:longint; DbgRecordTime:longword);
(* trgMode // start recording @		  	
				1:		set point reached
	  	  		else	from start (default) *)
begin 
  with dbgstruct do
  begin
	DbgFMT:=	 		resFMT; 
	DbgLogLvl:=			logLVL;
	DbgLogMode:=		logMode;  
	DbgRecordTime_ms:=	DbgRecordTime;
  	DbgTrigMode:=		trgMode;
  	DbgRecTrig:=		0; // enable log start
  end; // with
end;

procedure DBGlog_Start(var dbgstruct:dbg_log_t);
begin
  with dbgstruct do
  begin   
	DbgSeq:=			-1;
	DbgTimeStamp:=		now;
	DbgNextWriteLog:=	DbgTimeStamp;
  end; // with
end;

procedure DBGlog_Open(var dbgstruct:dbg_log_t; 
			LOGid:longint; LOGhdr,LOGfilhdr,LOGdir,LOGusr,LOGgrp:string; 
			LOGtmode:TMode; 
			HandlerAdr:TThFunctionOneArgCall;
			DataAdr:pointer);
begin  
  with dbgstruct do
  begin
	DBGlog_Start(		dbgstruct);
  	DBGlog_Set(	 		dbgstruct,LOG_NONE,0,0,0,0); 
  	DBGlogID:=			LOGid;
  	DBGlogHDR:=			LOGhdr;
  	DBGlogLine:=		'';
  	DBGlogFilHDR:=		LOGfilhdr;
  	DBGlogDIR:=			LOGdir;
  	DBGlogUSR:=			LOGusr;
  	DBGlogGRP:=			LOGgrp;
  	DBGlogTMODE:=		LOGtmode;
  	DbgRecTrig:=		-1; // prevent unintentional log start
  	DbgLogRetLvl:=		LOG_NONE;
  	DBGCallptr:=		HandlerAdr;
  	DBGDataptr:=		DataAdr;
  	DbgTL:=				TStringList.create;
  	DbgThreadRunning:=	false;
  	DbgStartTime:=		0; 
  	DbgTime:=			DbgStartTime;	
  end; // with
end;

procedure DBGlog_Close(var dbgstruct:dbg_log_t);
var _timo:TDateTime;
begin
  with dbgstruct do
  begin 
  	DbgRecTrig:=		4; 		// flush last data and destroy stringlist
  	SetTimeOut(_timo,	500);	// give WriteThread time to terminate (max. 500msec)
  	while (DbgThreadRunning and (not TimeElapsed(_timo))) do delay_msec(25);
	if (not DbgThreadRunning) then DbgTL.free;
  end; // with
end;

function  DBGlog_WriteFileThread(ptr:pointer):ptrint;
// async. log writer
var _ok,_end:boolean; _lvl:T_ErrorLevel;
	_TL:TStringList; fn0,fn1,fn2,fn4,fn5,sh:string; _dt:TDateTime;
begin  
  try
  	if (ptr<>nil) then
  	begin
	  with dbg_log_ptr(ptr)^ do 
	  begin
	  	DbgThreadRunning:=true;
	  	DbgLogRetLvl:=LOG_NONE;
	  	fn0:=DBGlogFilHDR+LeadingZeros(DBGlogID,2); fn1:=fn0; fn2:=fn0;	// dbg01
	  	Thread_SetName(fn0+'_#'+Num2Str(DbgSeq,0));

  	  	fn1:=fn0+'_'+LeadingZeros(DbgSeq,4);						// dbg01_0001
// 	  	fn2:=fn0+'_'+FormatDateTime('YYYYMMDDhhmmss',DbgTimeStamp);	// dbg01_20200127123345
  	  	fn0:=fn2+'_'+LeadingZeros(DbgSeq,4);						// dbg01_20200127123345_0001

	  	fn0:=PrepFilePath(DBGlogDIR+'/'+fn0+'.csv');				// for writing2disk
	  	fn1:=PrepFilePath(DBGlogDIR+'/'+fn1+'.csv');				// for display
	  	fn4:=PrepFilePath(DBGlogDIR+'/'+fn2+'.csv');
	  	fn5:=PrepFilePath(DBGlogDIR+'/'+fn2+'_*.csv');
	  	if DirectoryExists(Get_Dir(fn5)) then
	  	begin
		  if (DbgSeq=0) then call_external_prog(LOG_NONE,'rm '+fn5+' > /dev/nul 2>&1');
	  	end else call_external_prog(LOG_NONE,'mkdir -p '+Get_Dir(fn5)+' > /dev/nul 2>&1');
	  	
	  	sh:='#'+Num2Str(DbgSeq,0)+' '+Num2Str((DbgRecordTime_ms/1000),0,1)+'s '+Num2Str(DBGRecordCnt_c,0);
	  	LOG_Writeln(DbgLogLvl,'Dbg['+Num2Str(DBGlogID,0)+']: '+sh);

	  	repeat
	  	  _end:=((DbgRecTrig>=2) or terminateProg);
		  if (((DbgTL.count mod 10000)=0) or TimeElapsed(_dt,15000) or _end) then
			LOG_Writeln(DbgLogLvl,'Dbg['+Num2Str(DBGlogID,0)+']: '+Num2Str(DbgTL.count,5)+
			  ' LogEnd:'+FormatDateTime('hh:mm:ss',DbgNextWriteLog)+
			  ' recording:'+Bool2YNS(not TimeElapsed(DbgNextWriteLog))+
			  ' trig:'+Num2Str(DbgRecTrig,0)+
			  ' TermTh:'+Bool2YNS(((DbgRecTrig>=3) or terminateProg))
		  	); 
		  if (not _end) then delay_msec(10); 
	  	until _end;
	
		if not terminateProg then
	  	begin
		  _TL:=DbgTL;
		  DbgTL:=TStringList.create;

		  if StringList2TextFile(fn0,_TL) then
		  begin
	  	  	if (DbgRecTrig>=3) then
	  	  	begin // consolidate parts to 1 file
	  	      DbgRecTrig:=-1; 	// prevent 2.nd dbg;
	  	  	  if (DbgSeq=0)	then sh:='rm '+ fn4+' > /dev/nul 2>&1 ; mv '+fn0+' '+fn4
	  	  		  			else sh:='cat '+fn5+' > '+fn4+' ; rm ' +fn5+' > /dev/nul 2>&1';
	  	  	  _ok:=(call_external_prog(LOG_NONE,sh)=0);
//		  	  LOG_Writeln(LOG_WARNING,'Dbg['+Num2Str(DBGlogID,0)+']: '+sh);	    

	  	  	  if _ok then 
	  	  	  begin
	  		  	_ok:=(LNX_chowngrpmod(fn4,DBGlogUSR,DBGlogGRP,DBGlogTMODE)=0);
	  	 	  	_lvl:=DbgLogLvl;
	  	  	  end 
	  	  	  else 
	  	  	  begin
	  	  	  	_lvl:=LOG_ERROR;
	  	  	  	DbgLogRetLvl:=LOG_ERROR;
	  	  	  end;

	  	  	  LOG_Writeln(_lvl,'Dbg['+Num2Str(DBGlogID,0)+']: '+FormatFileSize(GetFileSize(fn4))+' '+GetTildePath(fn4,AppDataDir_c));

	  	  	end else DbgRecTrig:=1;	// reset
		  end else DbgRecTrig:=-1; 	// prevent 2.nd dbg;
	  	end 
	  	else
	  	begin
		  LOG_Writeln(LOG_ERROR,'Dbg['+Num2Str(DBGlogID,0)+']: '+fn0);
	  	end;
	  	_TL.free;  	
	  	DbgThreadRunning:=false;
//	  	LOG_Writeln(DbgLogLvl,'DBGlog_WriteFileThread['+Num2Str(DBGlogID,0)+']: EndThread');
	  end; // with
	end else Log_Writeln(Log_ERROR,'DBGlog_WriteFileThread: no parameter pointer supplied'); 
  except
	LOG_Writeln(LOG_ERROR,'DBGlog_WriteFileThread: exception');
  end;
  EndThread;
  DBGlog_WriteFileThread:=0;
end;

procedure DBGlogging(var dbgstruct:dbg_log_t; HighPrecCntr:qword; DbgGetLogTrig:boolean);
begin
  try
	with dbgstruct do
	begin
	  DbgTime:=HighPrecCntr;
	  case DbgRecTrig of
		0:	begin
	  		  if DbgGetLogTrig then 
	  		  begin
	  		    DBGlog_Start(dbgstruct);
	    		DbgRecTrig:=1; DbgStartTime:=HighPrecCntr;			// save 1. timestamp
	    		DBGlogging(dbgstruct,HighPrecCntr,DbgGetLogTrig);	// Hdr und 1.entry
	  		  end;	
	  		end;	  		
		1:	begin		
		  	  if (DBGCallptr<>nil) then 
		  	  begin
		  	 	DBGCallptr(@dbgstruct);
			  	if (DbgTL.count=0) then 
	    	  	begin
	    	      inc(DbgSeq);
	              if ((DbgSeq=0) and (DBGlogHDR<>'')) then DbgTL.add(DBGlogHDR);
	              SetTimeOut(DbgNextWriteLog,DbgRecordTime_ms);
	              BeginThread(@DBGlog_WriteFileThread,@dbgstruct);
			  	end;
	    	  	DbgTL.add(DBGlogLine);
			  end;
			  
			  if (DbgTL.count>=DBGRecordCnt_c) then  DbgRecTrig:=2;	
			  	 
			  if (DbgRecordTime_ms>0) then
			  	if TimeElapsed(DbgNextWriteLog) then DbgRecTrig:=3;  	 
	  		end;
	  end; // case
	end; // with
  except
	LOG_Writeln(LOG_ERROR,'DBGlogging: exception');
  end;
end;

var DBGDataArray1: array[0..1] of real=(1.23,2.34);	// just for testing, global measure data

function  DBGlog_CreateValueLineDummy(ptr:pointer):ptrint;
// example procedure which will create .csv data line
begin
  try
	with dbg_log_ptr(ptr)^ do 
	begin
	
	  DBGlogLine:=	// adjust this code according to your .csv data needs
	  	Num2Str(RPI_MicroSecondsBetween(DbgTime,DbgStartTime),0)+','+
	  	Num2Str(DBGDataArray1[0],0,2)+','+Num2Str(DBGDataArray1[1],0,2);	
	  	
	end;
  except
	LOG_Writeln(LOG_ERROR,'DBGlog_CreateValueLineDummy: exception');
  end;
  DBGlog_CreateValueLineDummy:=0;
end;

procedure DBGlog_Test;
// example with one logwriter, we can have multiple _dbglog:array[1..5] of DBG_log_t;
// e.g. create .csv for https://github.com/danvk/dygraphs 
var n:integer; _HighPrecCntr:qword; _dbglog:array[1..1] of DBG_log_t;
begin
  DBGlog_Open(
		_dbglog[1],						// init sequence
		1,								// id for 1st logwriter, part of filename
		'usec,val1,val2',				// csv header line
		'dbg',							// file name header e.g. dbg<id>.csv
		'/tmp',							// dir where you will find the .csv file
		'pi','pi',&744,					// usr/grp and access rights
		@DBGlog_CreateValueLineDummy,	// pointer to create .csv data line
		@DBGDataArray1); 				// pointer to Measure Data Array
  DBGlog_Set(_dbglog[1],LOG_WARNING,1,1,1,8000);	// 8000ms (8sec) recording time
		
  for n:= 0 to 9 do
  begin // work loop, runs 10sec
  	_HighPrecCntr:=RPI_GetPrecisionCounter_us; 		// timestamp in usec
  	DBGlogging(_dbglog[1], _HighPrecCntr, (n=1) );	// log debug entry, start trigger@n=1
  	 
	delay_msec(1000);
	DBGDataArray1[0]:=n/5; 				// simulate measure value changes
	DBGDataArray1[1]:=n/10; 			// simulate measure value changes
  end;
  
  for n:= 1 to Length(_dbglog) do DBGlog_Close(_dbglog[n]);
  writeln('you should find the file /tmp/dbg01.csv');
end;

function  BIT_Get(v:byte;		  i:byte):boolean; begin BIT_Get:=((v shr i) and 1)=1; end;
function  BIT_Get(v:word;		  i:byte):boolean; begin BIT_Get:=((v shr i) and 1)=1; end;
function  BIT_Get(v:longword;	  i:byte):boolean; begin BIT_Get:=((v shr i) and 1)=1; end;
function  BIT_Get(v:qword; 		  i:byte):boolean; begin BIT_Get:=((v shr i) and 1)=1; end;

procedure BIT_Clr(var v:byte;	  i:byte); begin v:=v and ((1 shl i) xor High(byte));     end;
procedure BIT_Clr(var v:word;	  i:byte); begin v:=v and ((1 shl i) xor High(word));     end;
procedure BIT_Clr(var v:longword; i:byte); begin v:=v and ((1 shl i) xor High(longword)); end;
procedure BIT_Clr(var v:qword;	  i:byte); begin v:=v and ((1 shl i) xor High(qword));    end;

procedure BIT_Set(var v:byte;	  i:byte); begin v:=v or  (1 shl i); end;
procedure BIT_Set(var v:word;	  i:byte); begin v:=v or  (1 shl i); end;
procedure BIT_Set(var v:longword; i:byte); begin v:=v or  (1 shl i); end;
procedure BIT_Set(var v:qword;	  i:byte); begin v:=v or  (1 shl i); end;

procedure BIT_Put(var v:byte; 	  i:byte; b:boolean); begin v:=(v and ((1 shl i) xor High(byte))) 	  or (byte(b) shl i); end;
procedure BIT_Put(var v:word; 	  i:byte; b:boolean); begin v:=(v and ((1 shl i) xor High(word))) 	  or (word(b) shl i); end;
procedure BIT_Put(var v:longword; i:byte; b:boolean); begin v:=(v and ((1 shl i) xor High(longword))) or (longword(b) shl i); end;
procedure BIT_Put(var v:qword; 	  i:byte; b:boolean); begin v:=(v and ((1 shl i) xor High(qword))) 	  or (qword(b) shl i); end;

function  MSK_Get8(bitnum:byte):byte; 
begin MSK_Get8:=(1 shl (bitnum and $07)); end; //IN:  bitnum 0-7

function  MSK_Get16(bitnum:byte):word; 
begin MSK_Get16:=(1 shl (bitnum and $0f)); end; //IN:  bitnum 0-15

function  MSK_Get16_8(bitnum:byte; var idxofs:byte):byte;
//IN:  bitnum 0-15
//IDX: 0:bitnum 0-7	1:bitnum 8-15	
begin
  idxofs:=((bitnum and $0f) shr 3); 
  MSK_Get16_8:=(1 shl (bitnum mod 8));
end;

function  MSK_Get64_8(bitnum:byte; var idxofs:byte):byte;
//IN:  bitnum 0-63
begin
  idxofs:=((bitnum and $3f) shr 3); 
  MSK_Get64_8:=(1 shl (bitnum mod 8));
end;

function  MSK_Get256_8(bitnum:byte; var idxofs:byte):byte;
//IN:  bitnum 0-255
begin
  idxofs:=((bitnum and $ff) shr 3); 
  MSK_Get256_8:=(1 shl (bitnum mod 8));
end;

function  MSK2BitNum(mask:qword):integer;
var i,j:integer;
begin
  i:=0; j:=-1;
  while (i<64) do
  begin
  	if (((mask shr i) and 1)>0) then
  	begin
  	  j:= i;
  	  i:=64; // exit loop
  	end;
  	inc(i);
  end; // while
  MSK2BitNum:=j;
end;  
  
procedure TL_prot_Init(var tlp:TL_prot_t);
begin
  with tlp do
  begin
	InitCriticalSection(TL_CS); 
	TL:=TStringList.create;
	TL_modified:=false;
	TL_initok:=	 true;
    TL_stamp:=	 0; 
    TL_hash:=	 MD5Hash4emptyString;
  end; // with
end;
procedure TL_prot_Stop(var tlp:TL_prot_t);
begin
  with tlp do
  begin
    TL_initok:=	 false;
    TL_stamp:=	 0; 
    TL_hash:=	 MD5Hash4emptyString;
    TL_modified:=false;
    TL.free;
	DoneCriticalSection(TL_CS);
  end; // with
end;

procedure STR_prot_Init(var slp:STR_prot_t);
begin
  with slp do
  begin
	InitCriticalSection(STR_CS);
	STR:='';
	STR_modified:=true;
  end; // with
end;
procedure STR_prot_Stop(var slp:STR_prot_t);
begin
  with slp do
  begin  
	DoneCriticalSection(STR_CS); 
	STR:='';
	STR_modified:=false;
  end; // with
end;

function  LNX_GetFBdev(dflt:string):string;
var sh:string;
begin
  sh:='';
  call_external_prog(LOG_NONE,'ls -r /dev/fb* | head -1',sh);
  if (Trimme(sh,3)='') then
  begin
  	if (Trimme(dflt,3)<>'') then sh:=dflt else sh:=fbdev_c;
  end;
  LNX_GetFBdev:=sh;
end;

function  LNX_RTC3231_ReadTemp:real;
// read temperature sensor of DS3231 compatible RTC chip, from driver
// RTC delivers every 64sec a TEMP reading. resolution 0.25degree
// /boot/config.txt: dtoverlay=i2c-rtc,ds3231
//  echo $(cat /sys/bus/i2c/devices/1-0068/hwmon/hwmon1/temp1_input|awk '{print $0/1000}')
const 
  OLDpath='/sys/bus/i2c/devices/1-0068/hwmon/hwmon1/temp1_input'; // not working 20210809
  path=	  '/sys/bus/i2c/devices/i2c-1/1-0068/hwmon/hwmon2/temp1_input';
var sh:string;
begin
  try
  {$IFDEF UNIX} 
	if TimeElapsed(RTC3231_NextRead,64000) then
	begin
	  if FileExists(path) then
	  begin
  	 	if (call_external_prog(LOG_NONE,
	  	  'echo $(cat '+path+'|awk ''{print $0/1000}'')',sh)=0) then
		  if not Str2Num(sh,RTC3231_LastTemp) then RTC3231_LastTemp:=NaN;
	  end 
	  else 
	  begin
		RTC3231_LastTemp:=NaN;
//		Log_Writeln(LOG_ERROR,'LNX_RTC3231_ReadTemp: invalid devpath '+path);
	  end;
	end;
  {$ELSE}
	RTC3231_LastTemp:=NaN;
  {$ENDIF}
  except
	RTC3231_LastTemp:=NaN;
  end;
  LNX_RTC3231_ReadTemp:=RTC3231_LastTemp;
end;

function  LNX_ResolveIP2name(IP:string):string;
var _tl:TStringList; idx:longint; sh:string;
begin // todo
  sh:=IP;
  {$IFDEF UNIX} 
	_tl:=TStringList.create;
  	if (call_external_prog(LOG_NONE,'arp -a',_tl)=0) then
  	begin
	  idx:=SearchStringInListIdx(_tl,' ('+IP+') ',1,0);
	  if (idx>=0) then
	  begin // found e.g. rpi3b_1w.abc.def.com (10.8.81.132) at <incomplete> on wlan0
		sh:=Trimme(Select_Item(_tl[idx],' (','','',1),3);	// rpi3b_1w.abc.def.com 
		if (sh='') then sh:=IP;
	  end;
  	end;
  	_tl.free;
  {$ENDIF}
  LNX_ResolveIP2name:=sh;
end;

procedure LNX_WDOG_LastChanceHandler;
begin
  LOG_Writeln(LOG_WARNING,'LNX_WDOG_LastChanceHandler');
end;

function  LNX_WDOG_Thread(ptr:pointer):ptrint;
var  _cnt,_fsec,_ms:longint; i64:int64; sh:string;
begin
//SAY(LOG_WARNING,'LNX_WDOG_Thread: start');
  try
    Thread_SetName('WDOG');   
  	with wdog do
  	begin
	  _fsec:=trunc(retival_msec/1000)*10; 
	  _ms:=  retival_msec  mod  1000;
  	  
	  with ThreadCtrl do 
	  begin 
//		writeln('WDOG: ',retival_msec,'ms');
	  	TermThread:=false; ThreadRunning:=true;
  	  	repeat
      	  if not TermThread then 
      	  begin
		  	i64:=DeltaTime_in_ms(WDOGFire,now);
		  	if (i64<=retival_msec) then
		  	begin
		  	  sh:='LNX_WDOG_Thread: WDOG will fire within '+Num2Str(i64,0)+'msec';
		  	  if (i64>=1)	then LOG_Writeln(LOG_WARNING,sh)
		  	  				else LOG_Writeln(LOG_ERROR,	 sh);
		  	  if (LastChanceHandler_ptr<>nil) then LastChanceHandler_ptr;
		  	end;
		  	
		  	_cnt:= 0; 
		  	while ((_cnt<_fsec) and (not (terminateProg or TermThread))) do
			begin // seconds loop
	  		  delay_msec(100);
	  		  inc(_cnt);
			end; // while	  			
		  	if ((_ms>0) and (not (terminateProg or TermThread))) then delay_msec(_ms);
//         	delay_msec(retival_msec);  // replaced by interruptable loop above      	
          	
		  	if RetrigAsync then 
		  	begin
//		 	  SAY(LOG_WARNING,'WDOG: RetrigAsync');
			  LNX_WDOG(WDOG_Retrig);	// retrigger WDOG
		  	end;
	  	  end;
	  	until terminateProg or TermThread;
  	  	TermThread:=true; ThreadRunning:=false;
  	  end; // with
  	end; // with
  except
	On E_rpi_hal_Exception :Exception do writeln('LNX_WDOG_Thread: ',E_rpi_hal_Exception.Message);
  end;
//SAY(LOG_WARNING,'LNX_WDOG_Thread: end');
  EndThread;  
  LNX_WDOG_Thread:=0;
end;

procedure LNX_WDOG_Init(var struct:watchdog_struct_t);
var n:longint;
begin
  with struct do
  begin
	Hndl:=-1; 			devpath:=wdoc_path_c;	RetrigAsync:=true; 
	ival_sec:=15; 		retival_msec:=(ival_sec*1000) div 5; 
	Thread_InitStruct	(ThreadCtrl);
	LastBootStat:=0;	LastChanceHandler_ptr:=@LNX_WDOG_LastChanceHandler;
	NextTrigTime:=now;	SetTimeOut(WDOGFire,(ival_sec*1000));
	with info do
	begin
	  options:=0; 		firmware_version:=0;
	  for n:=0 to 31 do identity[n]:=$00;
	end;
  end; // with
end;

function  LNX_WDOG_Start:boolean;
(*	https://embeddedfreak.wordpress.com/2010/08/23/howto-use-linux-watchdog/
	https://github.com/binerry/RaspberryPi/blob/master/snippets/c/watchdog/wdt_test.c
	https://github.com/torvalds/linux/blob/master/include/uapi/linux/watchdog.h
	https://github.com/torvalds/linux/blob/master/include/uapi/asm-generic/fcntl.h *)
begin
  with wdog do
  begin
  	if (Hndl>=0) then LNX_WDOG(WDOG_Close);	// close old WDOG and reopen
  	LNX_WDOG(WDOG_Pause);	// retrig by Thread, not controlled by main prog (sync) 
  	Hndl:=fpOpen(devpath, (O_RDWR or O_NOCTTY));
  	if (Hndl<0) then
  	begin 
	  LOG_Writeln(LOG_ERROR,'LNX_WDOG['+Num2Str(Hndl,0)+']: can not open '+devpath); 
	  Hndl:=-1;
  	end 
  	else 
  	begin
	  ival_sec:=LNX_WDOG(WDOG_GTO);
(*	  if (wtim_ms=0) then wtim_ms:=((ival_sec*1000) div 3); // get wdog timeout
  	  if (wtim_ms=0) then wtim_ms:=2000;
  	  retival_msec:=wtim_ms; *)
	  SAY(LOG_INFO,'LNX_WDOG['+Num2Str(Hndl,0)+'/'+Num2Str(ival_sec,0)+'/'+Num2Str(retival_msec,0)+']: init succesful '+devpath);
  	end;
  	LNX_WDOG_Start:=(Hndl>=0);
  end; // with
end;

function  LNX_WDOG(wdog_action:t_rpimaintflags; p1:longint):longint;
var c:char='V'; res:longint; sh:string;
begin
  res:=-1; 
  with wdog do
  begin
	if (Hndl>=0) then
  	begin 
	  case wdog_action of
		WDOG_Close:	begin // disable and close watchdog device
					  LNX_WDOG(WDOG_Resume);
					  ThreadCtrl.TermThread:=true; // signal Thread terminate
					  if ((info.options and WDIOF_MAGICCLOSE)<>0) then
					  begin
			  		  	c:='V'; res:=fpwrite(Hndl,c,1);	// disable WDOG
			  		  	fpClose(Hndl);
			  		  	SAY(LOG_INFO,'LNX_WDOG['+Num2Str(Hndl,0)+'/'+Num2Str(res,0)+']: closed '+devpath);
			  		  end else LOG_Writeln(LOG_ERROR,'WDOG no support WDIOF_MAGICCLOSE');
			  		  Hndl:=-1;
					end;
		WDOG_Retrig:begin // retrigger WDOG
					  if ((info.options and WDIOF_KEEPALIVEPING)<>0) then
					  begin
			  		  {$R-} 
						if TimeElapsed(NextTrigTime,retival_msec) then
			  		 	begin
			  		 	  SetTimeOut(WDOGFire,(ival_sec*1000));
						  SAY(LOG_DEBUG,'LNX_WDOG[Retrig]: retrigger');
						  res:=fpIOCTL(Hndl, WDIOC_KEEPALIVE, nil);
//			  			  c:='W'; res:=fpwrite(Hndl,c,1);
						end;	
			  		  {$R+} 
			  		  end else LOG_Writeln(LOG_ERROR,'WDOG no support WDIOF_KEEPALIVEPING');
					end;
		WDOG_GTO:	begin  // get timeout (sec)
			  		  {$R-} 
						res:=fpIOCTl(Hndl, WDIOC_GETTIMEOUT, @ival_sec);
						SAY(LOG_DEBUG,'LNX_WDOG: timeout is '+Num2Str(ival_sec,0));
						if (res<>0) then
						begin
				  		  LOG_Writeln(LOG_ERROR,'LNX_WDOG[GTO]: '+Num2Str(fpGetErrno,0));
			 	  		  res:=-1;
			  			end
			  			else
			  			begin 
			  			  retival_msec:=(ival_sec*1000) div 5;
			  			  res:=ival_sec;
			  			end;
			  		  {$R+} 
					end;
		WDOG_STO:	begin // set timeout (sec)
					  if ((info.options and WDIOF_SETTIMEOUT)<>0) then
					  begin
			  		  {$R-} 
						if (p1>0) then ival_sec:=p1 else ival_sec:=15;
						SAY(LOG_DEBUG,'LNX_WDOG: timeout set '+Num2Str(ival_sec,0));
						res:=fpIOCTL(Hndl, WDIOC_SETTIMEOUT, @ival_sec);
						if (res<>0) then
						begin
				  		  LOG_Writeln(LOG_ERROR,'LNX_WDOG[STO]: '+Num2Str(fpGetErrno,0));
			 	  		  res:=-1;
			  			end 
			  			else 
			  			begin 
			  			  retival_msec:=(ival_sec*1000) div 5; 
			  			  res:=ival_sec; 
			  			end;
			  		  {$R+} 
			  		  end else LOG_Writeln(LOG_ERROR,'WDOG no support WDIOF_SETTIMEOUT');
		   			end;
		WDOG_BSTAT:	begin // Check if last boot is caused by watchdog
			  		  {$R-}
						res:=fpIOCTL(Hndl, WDIOC_GETBOOTSTATUS, @LastBootStat);
						if (res<>0) then
						begin
				  		  LOG_Writeln(LOG_ERROR,'LNX_WDOG[BSTAT]: '+Num2Str(fpGetErrno,0));
			 	   		  res:=-1;
						end
						else
						begin
				  		  res:=LastBootStat;
				  		  if (LastBootStat<>0) then 
							LOG_WRITELN(LOG_WARNING,'LNX_WDOG: Last boot was caused by: Watchdog');
						end;
			  		  {$R+}
					end;
		WDOG_GSup:	begin // WDIOC_GETSUPPORT		
(* options:0x00008180
wdctl:
Device:        /dev/watchdog
Identity:      Broadcom BCM2835 Watchdog timer [version 0]
Timeout:       15 seconds
Pre-timeout:    0 seconds
Timeleft:      14 seconds
FLAG           DESCRIPTION               STATUS BOOT-STATUS
KEEPALIVEPING  Keep alive ping reply          1           0
MAGICCLOSE     Supports magic close char      0           0
SETTIMEOUT     Set timeout (in seconds)       0           0		*)
			  		  {$R-}
						res:=fpIOCTL(Hndl, WDIOC_GETSUPPORT, @info);
						if (res<>0) then
						begin
				  		  LOG_Writeln(LOG_ERROR,'LNX_WDOG[GSup]: '+Num2Str(fpGetErrno,0));
			 	   		  res:=-1;
						end
						else
						begin
						  with info do
						  begin
							sh:=''; res:=0;
							while (res<=31) do
							begin
							  if (identity[res]<>$00) 
								then sh:=sh+char(identity[res]) else res:=31;
							  inc(res);
							end;
							SAY(LOG_INFO,'LNX_WDOG[GSup]: '+sh+' [version '+Num2Str(firmware_version,0)+'] opts:0x'+HexStr(options,8));
							res:=options;
						  end; // with
						end;
			  		  {$R+}	
					end;	
		WDOG_Pause:	begin // pause
			  		  SAY(LOG_INFO,'LNX_WDOG: pause');
			  		  RetrigAsync:=true;
			  		  res:=0;
					end;
		WDOG_Resume:begin // resume
			  		  SAY(LOG_INFO,'LNX_WDOG: resume');
			  		  RetrigAsync:=false;
			  		  res:=0;
					end;
	  end; // case
	end;
  end; // with
  LNX_WDOG:=res;
end;
function  LNX_WDOG(wdog_action:t_rpimaintflags):longint; begin LNX_WDOG:=LNX_WDOG(wdog_action,0); end; 

function  LNX_ShellESC(s:string):string;
// $.*[\]^
var sh:string;
begin
  sh:=s;
  sh:=StringReplace(sh,'\','\\',[rfReplaceAll]);
  sh:=StringReplace(sh,'$','\$',[rfReplaceAll]);
  sh:=StringReplace(sh,'*','\*',[rfReplaceAll]);
  sh:=StringReplace(sh,'[','\[',[rfReplaceAll]);
  sh:=StringReplace(sh,']','\]',[rfReplaceAll]);
  sh:=StringReplace(sh,'^','\^',[rfReplaceAll]);
  sh:=StringReplace(sh,'.','\.',[rfReplaceAll]);
  sh:=StringReplace(sh,',','\,',[rfReplaceAll]);
  sh:=StringReplace(sh,'"','\"',[rfReplaceAll]);
  sh:=StringReplace(sh,'(','\(',[rfReplaceAll]);
  sh:=StringReplace(sh,')','\)',[rfReplaceAll]);
  LNX_ShellESC:=sh;
end;

function  LNX_ParLinEXIST(filnam,parstr:string):boolean;
// parstr IN: 'autostart=1'
// filnam IN: '/etc/hostapd/hostapd.conf'
var bool:boolean; n:longint; sh:string;
begin
  bool:=false;
  if (filnam<>'') and (parstr<>'') then 
  begin
    if (call_external_prog(LOG_NONE,'grep -c -F "'+parstr+'" "'+filnam+'"',sh)=0) then
      if Str2Num(Trimme(sh,3),n) then bool:=(n>0); // n linecount of parstr in filnam 
  end;
  LNX_ParLinEXIST:=bool;
end;

function  LNX_ParSET(filnam,parnam,parval:string):integer;
// filnam IN: '/etc/hostapd/hostapd.conf'
// parnam IN: 'autostart'
// parval IN: '1'
// OUT OK: >=0
var res:integer;
begin
  if (filnam<>'') and (parnam<>'') then 
  begin
    res:=call_external_prog(LOG_NONE,
      'sed -i -r "s/'+parnam+'[ ]*=.*/'+parnam+'='+parval+'/g" "'+filnam+'"');
  end else res:=-1;
  LNX_ParSET:=res;
end;

function  LNX_ParGET(filnam,parnam:string; var parval:string):integer;
// filnam IN:  '/etc/hostapd/hostapd.conf'
// parnam IN:  'autostart'
// parval OUT: '1'
var res:integer;
begin
  if (filnam<>'') and (parnam<>'') then 
  begin
//	res:=call_external_prog(LOG_NONE,'grep -sF "'+parnam+'=" '+filnam+' | sed "s/'+parnam+'=//g"',parval);
    res:=call_external_prog(LOG_NONE,'grep -sF "'+parnam+'=" '+filnam,parval);
    if (res=0) then
    begin
	  if (parval<>'') then
      begin
		parval:=StringReplace(parval,parnam+'=','',[]);
      end else res:=-3;	// no para line
    end else res:=-2;	// file not exist
  end else res:=-1;		// file or para not given
  LNX_ParGET:=res;
end;

procedure LNX_sudo(sudouse:boolean); 
begin if sudouse then sudo:='sudo ' else sudo:=''; end;
function  LNX_sudo:boolean; begin LNX_sudo:=(Trimme(sudo,3)<>''); end;

function  LNX_IsMount(mntpoint:string):boolean;
// check mounted
var ok:boolean; sh:string;
begin
  if (mntpoint<>'') then
  begin
  	ok:=(call_external_prog(LOG_NONE,'findmnt -rn | grep '+mntpoint,sh)=0);
  	ok:=(DirectoryExists(PrepFilePath(mntpoint)) and (Pos(mntpoint,sh)>0));
  	if not ok then LOG_Writeln(LOG_ERROR,'LNX_IsMount: '+mntpoint);
  end else ok:=false;
  LNX_IsMount:=ok;
end;

procedure LNX_ADD2Crontab(cmd:string);
var sh:string;
begin
  if (cmd<>'') then
  begin
	sh:=sudo+'(crontab -l; echo "'+LNX_ShellESC(cmd)+'";) | crontab -';
	call_external_prog(LOG_NONE,sh,sh);
  end;
end;

function  LNX_SetDateTimeUTC2(utc:TDateTime; hwclock:boolean):integer;
var res:integer; cmd:string;
begin
  cmd:='date -s "'+DateTime2FMT(2,utc)+'Z" >/dev/null'; // date -s "2021-08-26T09:42:32.632Z" >/dev/null
  if hwclock then cmd:=cmd+' ; hwclock --utc --systohc';
  res:=call_external_prog(LOG_NONE,cmd);
  if (res=0)
    then LOG_Writeln(LOG_WARNING,'LNX_SetDateTimeUTC2['+Num2Str(res,0)+']: '+cmd)
	else LOG_Writeln(LOG_ERROR,  'LNX_SetDateTimeUTC2['+Num2Str(res,0)+']: can not exec: '+cmd);
  LNX_SetDateTimeUTC2:=res;
end;

function  LNX_SetDateTimeUTC(utc:TDateTime):integer;
// Set the system clock to the specified time. This will also update the RTC time accordingly. 
// The time may be specified in the format "2012-10-30 18:17:16".
var cmd:string;
begin //timedatectl set-time '2021-08-26 14:47:20'
  cmd:='timedatectl set-time '''+FormatDateTime('yyyy-mm-dd',utc)+' '+FormatDateTime('hh:nn:ss',utc)+'''';
//LOG_Writeln(LOG_WARNING,'LNX_SetDateTimeUTC: '+cmd);
  LNX_SetDateTimeUTC:=call_external_prog(LOG_NONE,cmd);
end;
  	  
function  LNX_GetTZList(ts:TStringList; fmt:byte):integer;
  procedure fmtentry(fmt:byte; ofsmins:integer; f1,f2:string); 
  begin 
	ts.add(Trimme(f1+'*'+'(GMT'+CalcUTCOffsetString(ofsmins,true)+') '+f2,3)); 
  end;
var res:integer;
begin
  case fmt of
    1:	begin	// very very short list (not working with timedatectl set-timezone [TIMEZONE])
//https://opensource.apple.com/source/system_cmds/system_cmds-230/zic.tproj/datfiles/etcetera
    	  res:=0; ts.clear;
//    	  fmtentry(fmt, 000,'Etc/UTC-12:00',	'International Date Line West');
    	  fmtentry(fmt,-660,'Etc/UTC-11:00',	'');
    	  fmtentry(fmt,-600,'Etc/UTC-10:00',	'Hawaii');
    	  fmtentry(fmt,-540,'Etc/UTC-09:00',	'Alaska');
    	  fmtentry(fmt,-480,'Etc/UTC-08:00',	'Pacific Time');
    	  fmtentry(fmt,-420,'Etc/UTC-07:00',	'Mountain Time');
    	  fmtentry(fmt,-360,'Etc/UTC-06:00',	'Central America');
    	  fmtentry(fmt,-300,'Etc/UTC-05:00',	'Eastern Time');
    	  fmtentry(fmt,-240,'Etc/UTC-04:00',	'Atlantic Time');
    	  fmtentry(fmt,-210,'Etc/UTC-03:30',	'');
    	  fmtentry(fmt,-180,'Etc/UTC-03:00',	'');
    	  fmtentry(fmt,-120,'Etc/UTC-02:00',	'Mid-Atlantic');
    	  fmtentry(fmt, -60,'Etc/UTC-01:00',	'Azores');
    	  fmtentry(fmt,   0,'Etc/UTC',			'Greenwich Mean Time'); 
    	  fmtentry(fmt,  60,'Etc/UTC+01:00',	'Amsterdam, Berlin, Bern, Rome, Stockholm, Vienna');
    	  fmtentry(fmt, 120,'Etc/UTC+02:00',	'');
    	  fmtentry(fmt, 180,'Etc/UTC+03:00',	'Moscow');
    	  fmtentry(fmt, 240,'Etc/UTC+04:00',	'');
    	  fmtentry(fmt, 300,'Etc/UTC+05:00',	'Islamabad');
    	  fmtentry(fmt, 330,'Etc/UTC+05:30',	'');
    	  fmtentry(fmt, 345,'Etc/UTC+05:45',	'');
    	  fmtentry(fmt, 360,'Etc/UTC+06:00',	'Almaty');
    	  fmtentry(fmt, 390,'Etc/UTC+06:30',	'');
    	  fmtentry(fmt, 420,'Etc/UTC+07:00',	'Bangkok');
    	  fmtentry(fmt, 480,'Etc/UTC+08:00',	'Beijing');
    	  fmtentry(fmt, 540,'Etc/UTC+09:00',	'Tokyo');
    	  fmtentry(fmt, 570,'Etc/UTC+09:30',	'Adelaide');
    	  fmtentry(fmt, 600,'Etc/UTC+10:00',	'');
    	  fmtentry(fmt, 660,'Etc/UTC+11:00',	'');
    	  fmtentry(fmt, 720,'Etc/UTC+12:00',	'Auckland');
    	  fmtentry(fmt, 780,'Etc/UTC+13:00',	''); 	  
    	end;
    2:	begin	// very short list (working with timedatectl set-timezone [TIMEZONE])
    	  res:=0; ts.clear;
 //   	  fmtentry(fmt, 000,'Etc/GMT+12','International Date Line West');
    	  fmtentry(fmt,-660,'Pacific/Midway',	'Midway Island, Samoa');
    	  fmtentry(fmt,-600,'Pacific/Honolulu',	'Hawaii');
    	  fmtentry(fmt,-540,'US/Alaska',		'Alaska');
    	  fmtentry(fmt,-480,'America/Los_Angeles','Pacific Time (US & Canada)');
    	  fmtentry(fmt,-420,'US/Mountain',		'Mountain Time (US & Canada)');
    	  fmtentry(fmt,-360,'America/Managua',	'Central America');
    	  fmtentry(fmt,-300,'US/Eastern',		'Eastern Time (US & Canada)');
    	  fmtentry(fmt,-240,'Canada/Atlantic',	'Atlantic Time (Canada)');
    	  fmtentry(fmt,-210,'Canada/Newfoundland','Newfoundland');
    	  fmtentry(fmt,-180,'America/Argentina/Buenos_Aires','Buenos Aires, Georgetown');
    	  fmtentry(fmt,-120,'America/Noronha',	'Mid-Atlantic');
    	  fmtentry(fmt, -60,'Atlantic/Azores',	'Azores');
    	  fmtentry(fmt,   0,'Etc/UTC',			'Greenwich Mean Time: Dublin, Edinburgh, Lisbon, London');
    	  fmtentry(fmt,  60,'Europe/Berlin',	'Amsterdam, Berlin, Bern, Rome, Stockholm, Vienna');
    	  fmtentry(fmt, 120,'Europe/Athens',	'Athens, Bucharest, Istanbul');
    	  fmtentry(fmt, 180,'Europe/Moscow',	'Moscow, St. Petersburg, Volgograd');
    	  fmtentry(fmt, 240,'Asia/Muscat',		'Abu Dhabi, Muscat');
    	  fmtentry(fmt, 300,'Asia/Karachi',		'Islamabad, Karachi, Tashkent');
    	  fmtentry(fmt, 330,'Asia/Calcutta',	'Chennai, Kolkata, Mumbai, New Delhi');
    	  fmtentry(fmt, 345,'Asia/Katmandu',	'Kathmandu');
    	  fmtentry(fmt, 360,'Asia/Almaty',		'Almaty, Novosibirsk');
    	  fmtentry(fmt, 390,'Asia/Rangoon',		'Yangon (Rangoon)');
    	  fmtentry(fmt, 420,'Asia/Bangkok',		'Bangkok, Hanoi, Jakarta');
    	  fmtentry(fmt, 480,'Asia/Hong_Kong',	'Beijing, Chongqing, Hong Kong, Urumqi');
    	  fmtentry(fmt, 540,'Asia/Tokyo',		'Osaka, Sapporo, Tokyo');
    	  fmtentry(fmt, 570,'Australia/Adelaide','Adelaide');
    	  fmtentry(fmt, 600,'Australia/Canberra','Canberra, Melbourne, Sydney');
		  fmtentry(fmt, 660,'Asia/Magadan',		'Magadan, Solomon Is., New Caledonia');
    	  fmtentry(fmt, 720,'Pacific/Auckland',	'Auckland, Wellington');
    	  fmtentry(fmt, 780,'Pacific/Tongatapu','Nuku''alofa');    	  
    	end;
    0:	begin	// short list (working with timedatectl set-timezone [TIMEZONE])
		  res:=0; ts.clear;
//		  fmtentry(fmt, 000,'Etc/GMT+12',		'International Date Line West');
		  fmtentry(fmt,-660,'Pacific/Midway',	'Midway Island, Samoa');
    	  fmtentry(fmt,-600,'Pacific/Honolulu',	'Hawaii');
    	  fmtentry(fmt,-540,'US/Alaska',		'Alaska');
    	  fmtentry(fmt,-480,'America/Los_Angeles','Pacific Time (US & Canada)');
    	  fmtentry(fmt,-480,'America/Tijuana',	'Tijuana, Baja California');
    	  fmtentry(fmt,-420,'US/Arizona',		'Arizona');
    	  fmtentry(fmt,-420,'America/Chihuahua','Chihuahua, La Paz, Mazatlan');
    	  fmtentry(fmt,-420,'US/Mountain',		'Mountain Time (US & Canada)');
    	  fmtentry(fmt,-360,'America/Managua',	'Central America');
    	  fmtentry(fmt,-360,'US/Central',		'Central Time (US & Canada)');
    	  fmtentry(fmt,-360,'America/Mexico_City','Guadalajara, Mexico City, Monterrey');
    	  fmtentry(fmt,-360,'Canada/Saskatchewan','Saskatchewan');
    	  fmtentry(fmt,-300,'America/Bogota',	'Bogota, Lima, Quito, Rio Branco');
    	  fmtentry(fmt,-300,'US/Eastern',		'Eastern Time (US & Canada)');
    	  fmtentry(fmt,-300,'US/East-Indiana',	'Indiana (East)');
    	  fmtentry(fmt,-240,'Canada/Atlantic',	'Atlantic Time (Canada)');
    	  fmtentry(fmt,-240,'America/Caracas',	'Caracas, La Paz');
    	  fmtentry(fmt,-240,'America/Manaus',	'Manaus');
    	  fmtentry(fmt,-240,'America/Santiago',	'Santiago');
    	  fmtentry(fmt,-210,'Canada/Newfoundland','Newfoundland');
    	  fmtentry(fmt,-180,'America/Sao_Paulo','Brasilia');
    	  fmtentry(fmt,-180,'America/Argentina/Buenos_Aires','Buenos Aires, Georgetown');
    	  fmtentry(fmt,-180,'America/Godthab',	'Greenland');
    	  fmtentry(fmt,-180,'America/Montevideo','Montevideo');
    	  fmtentry(fmt,-120,'America/Noronha',	'Mid-Atlantic');
    	  fmtentry(fmt, -60,'Atlantic/Cape_Verde','Cape Verde Is.');
    	  fmtentry(fmt, -60,'Atlantic/Azores',	'Azores');
    	  fmtentry(fmt,   0,'Africa/Casablanca','Casablanca, Monrovia, Reykjavik');
    	  fmtentry(fmt,   0,'Etc/UTC',			'Greenwich Mean Time: Dublin, Edinburgh, Lisbon, London');
//		  fmtentry(fmt,   0,'Etc/Greenwich',	'Greenwich Mean Time: Dublin, Edinburgh, Lisbon, London');
    	  fmtentry(fmt,  60,'Europe/Berlin',	'Amsterdam, Berlin, Bern, Rome, Stockholm, Vienna');
    	  fmtentry(fmt,  60,'Europe/Belgrade',	'Belgrade, Bratislava, Budapest, Ljubljana, Prague');
    	  fmtentry(fmt,  60,'Europe/Brussels',	'Brussels, Copenhagen, Madrid, Paris');
    	  fmtentry(fmt,  60,'Europe/Sarajevo',	'Sarajevo, Skopje, Warsaw, Zagreb');
    	  fmtentry(fmt,  60,'Africa/Lagos',		'West Central Africa');
    	  fmtentry(fmt, 120,'Asia/Amman',		'Amman');
    	  fmtentry(fmt, 120,'Europe/Athens',	'Athens, Bucharest, Istanbul');
    	  fmtentry(fmt, 120,'Asia/Beirut',		'Beirut');
    	  fmtentry(fmt, 120,'Africa/Cairo',		'Cairo');
    	  fmtentry(fmt, 120,'Africa/Harare',	'Harare, Pretoria');
    	  fmtentry(fmt, 120,'Europe/Helsinki',	'Helsinki, Kyiv, Riga, Sofia, Tallinn, Vilnius');
    	  fmtentry(fmt, 120,'Asia/Jerusalem',	'Jerusalem');
    	  fmtentry(fmt, 120,'Europe/Minsk',		'Minsk');
    	  fmtentry(fmt, 120,'Africa/Windhoek',	'Windhoek');
    	  fmtentry(fmt, 180,'Asia/Kuwait',		'Kuwait, Riyadh, Baghdad');
    	  fmtentry(fmt, 180,'Europe/Moscow',	'Moscow, St. Petersburg, Volgograd');
    	  fmtentry(fmt, 180,'Africa/Nairobi',	'Nairobi');
    	  fmtentry(fmt, 180,'Asia/Tbilisi',		'(Tbilisi');
    	  fmtentry(fmt, 210,'Asia/Tehran',		'Tehran');
    	  fmtentry(fmt, 240,'Asia/Muscat',		'Abu Dhabi, Muscat');
    	  fmtentry(fmt, 240,'Asia/Baku',		'Baku');
    	  fmtentry(fmt, 240,'Asia/Yerevan',		'Yerevan');
    	  fmtentry(fmt, 270,'Asia/Kabul',		'Kabul');
    	  fmtentry(fmt, 300,'Asia/Yekaterinburg','Yekaterinburg');
    	  fmtentry(fmt, 300,'Asia/Karachi',		'Islamabad, Karachi, Tashkent');
    	  fmtentry(fmt, 330,'Asia/Calcutta',	'Chennai, Kolkata, Mumbai, New Delhi');
    	  fmtentry(fmt, 330,'Asia/Calcutta',	'Sri Jayawardenapura');
    	  fmtentry(fmt, 345,'Asia/Katmandu',	'Kathmandu');
    	  fmtentry(fmt, 360,'Asia/Almaty',		'Almaty, Novosibirsk');
    	  fmtentry(fmt, 360,'Asia/Dhaka',		'Astana, Dhaka');
    	  fmtentry(fmt, 390,'Asia/Rangoon',		'Yangon (Rangoon)');
    	  fmtentry(fmt, 420,'Asia/Bangkok',		'Bangkok, Hanoi, Jakarta');
    	  fmtentry(fmt, 420,'Asia/Krasnoyarsk',	'Krasnoyarsk');
    	  fmtentry(fmt, 480,'Asia/Hong_Kong',	'Beijing, Chongqing, Hong Kong, Urumqi');
    	  fmtentry(fmt, 480,'Asia/Kuala_Lumpur','Kuala Lumpur, Singapore');
    	  fmtentry(fmt, 480,'Asia/Irkutsk',		'Irkutsk, Ulaan Bataar');
    	  fmtentry(fmt, 480,'Australia/Perth',	'Perth');
    	  fmtentry(fmt, 480,'Asia/Taipei',		'Taipei');
    	  fmtentry(fmt, 540,'Asia/Tokyo',		'Osaka, Sapporo, Tokyo');
    	  fmtentry(fmt, 540,'Asia/Seoul',		'Seoul');
    	  fmtentry(fmt, 540,'Asia/Yakutsk',		'Yakutsk');
    	  fmtentry(fmt, 570,'Australia/Adelaide','Adelaide');
    	  fmtentry(fmt, 570,'Australia/Darwin',	'Darwin');
    	  fmtentry(fmt, 600,'Australia/Brisbane','Brisbane');
    	  fmtentry(fmt, 600,'Australia/Canberra','Canberra, Melbourne, Sydney');
    	  fmtentry(fmt, 600,'Australia/Hobart',	'Hobart');
    	  fmtentry(fmt, 600,'Pacific/Guam',		'Guam, Port Moresby');
    	  fmtentry(fmt, 600,'Asia/Vladivostok',	'Vladivostok');
    	  fmtentry(fmt, 660,'Asia/Magadan',		'Magadan, Solomon Is., New Caledonia');
    	  fmtentry(fmt, 720,'Pacific/Auckland',	'Auckland, Wellington');
    	  fmtentry(fmt, 720,'Pacific/Fiji',		'Fiji, Kamchatka, Marshall Is.');
    	  fmtentry(fmt, 780,'Pacific/Tongatapu','Nuku''alofa');
		end;
  	  else
  		begin	// 700 entries, to long for weppage (loadingtime)
  		  res:=call_external_prog(LOG_NONE,'timedatectl list-timezones',ts);
  		  ts.insert(0,'Etc/UTC');
  		end;
	end; // case
  LNX_GetTZList:=res;
end;

function  LNX_GetISOquery(ts:TStringList; opts:string):integer;
// requires isoquery command (apt install isoquery)
var res:integer;
begin
  res:=call_external_prog(LOG_NONE,'isoquery '+opts,ts);
  LNX_GetISOquery:=res;
end;

function  LNX_GetBase64String(str:string):string;
// IN:  fantasticjwt
// OUT: ZmFudGFzdGljand0
var cmd,sh:string;
begin
  cmd:='echo -n '+str+' | base64 | tr ''+/'' ''-_'' | tr -d ''=''';
  call_external_prog(LOG_NONE,cmd,sh);
  LNX_GetBase64String:=sh;
end;

function  LNX_GetRandomAccessToken(typ:longint):string;
// openssl rand -base64 12
// openssl rand -hex 12
const cmd1='openssl rand -base64 12'; cmd2='date | md5sum'; 
var res:integer; token:string;
begin
  res:=call_external_prog	(LOG_INFO,cmd1,token);
  token:=GetAlphaNumChar(token);
  if (res<>0) or (token='') then 
  begin
    res:=call_external_prog	(LOG_INFO,cmd2,token);
    token:=GetAlphaNumChar(token);
    if (res<>0) or (token='') then 
	  token:=FormatDateTime('YYYYMMDDhhmmss',now); // last chance
  end;
  LNX_GetRandomAccessToken:=token;
end;

function  LNX_StrMod(part:byte; mode:TMode):string;
var sh:string;
begin
  sh:='';
  case part of
     1:   begin // USR
        	if ((mode and S_IRUSR)>0) then sh:=sh+'r';
            if ((mode and S_IWUSR)>0) then sh:=sh+'w';
            if ((mode and S_IXUSR)>0) then sh:=sh+'x';
          end;
     2:   begin // GRP
            if ((mode and S_IRGRP)>0) then sh:=sh+'r';
            if ((mode and S_IWGRP)>0) then sh:=sh+'w';
            if ((mode and S_IXGRP)>0) then sh:=sh+'x';
          end;
     3:   begin // OTH
            if ((mode and S_IROTH)>0) then sh:=sh+'r';
            if ((mode and S_IWOTH)>0) then sh:=sh+'w';
            if ((mode and S_IXOTH)>0) then sh:=sh+'x';
          end;
  end; // case
  LNX_StrMod:=sh;
end;

function  LNX_chmod(filename:string; mode:TMode):cint;
var res:cint;
begin
  if FileExists(filename) then
  begin
	res:=0;
	{$IFDEF WINDOWS}
	  res:=call_external_prog(LOG_NONE,'chmod '+HexStr(mode,3)+' '+filename);
	{$ELSE}
	  res:=fpChmod(filename,mode);
	{$ENDIF}
  end else res:=-1;
  LNX_chmod:=res;
end;

function  LNX_chowngrp(filename:string; owner,group:string):integer;
var res:integer; cmd:string;
begin
  res:=0;
  	res:=-1;
	if FileExists(filename) then
	begin
	  cmd:='';
	  if (owner<>'') then cmd:=cmd+'chown '+owner+' '+filename;
	  if (owner<>'') and (group<>'') then cmd:=cmd+' ; ';
	  if (group<>'') then cmd:=cmd+'chgrp '+group+' '+filename;
	  if (cmd<>'') 
		then res:=call_external_prog(LOG_NONE,cmd)
		else res:=0;
    end;
  LNX_chowngrp:=res;
end;

function  LNX_chowngrpmod(filename:string; owner,group:string; mode:TMode):integer;
var res:integer;
begin
  res:=LNX_chowngrp(filename,owner,group);
  if (res=0) then res:=LNX_chmod(filename,mode);
  LNX_chowngrpmod:=res;
end;

procedure LNX_GetUsrPwdString(StrList:TStringList; pwdfile,usrlst:string; carveflds:longint);
// pwdfile: /etc/shadow 
// usrlst:  admin:|pi:
var n:longint;
begin
  if (Trimme(usrlst,3)<>'') and (pwdfile<>'') then
	call_external_prog(LOG_NONE,'grep -E "'+usrlst+'" "'+PrepFilePath(pwdfile)+'"',StrList);
  if (carveflds>0) then
  begin
	for n:= 1 to StrList.count do
	  StrList[n-1]:=Select_LeftItems(StrList[n-1],':','',carveflds);
  end;
end;

function  LNX_UpdPwdFile(pwdfile,usr,pwd:string):integer;
// maintain usr:pwd files (e.g. for lighthttpd webserver)
var res:integer; _idx:longint; _tl:TStringList;
begin
  res:=-1;
  if (pwdfile<>'') and (usr<>'') then
  begin
	_tl:=TStringList.create;
	if FileExists(pwdfile) then
	begin
	  _idx:=SearchStringInListIdx(_tl,usr+':',1,0);
	  if (_idx>=0) then _tl.delete(_idx);
	end;
	_tl.add(usr+':'+pwd);
	if StringList2TextFile(pwdfile,_tl) then res:=0;
	_tl.free;
  end;
  LNX_UpdPwdFile:=res;
end;

function  LNX_ChkUsrPwdValid(usr,pwd,pwddefault:string):integer;
// IN: usr,password // access to /etc/shadow
// OUT -2:mkpasswd  mkpasswd not installed or returned an error -1:not valid 0:valid 1:pwd=pwddefault
// mkpasswd is part of paket whois -> apt install whois
const ma=10;
var res:integer; i,j:longint; dt:TDateTime; tlh:TStringList; 
	sh,salt,algo,cmd,cmd0:string; arr:array[1..ma] of string;
begin
  res:=-1;
  {$IFDEF UNIX}
  if (usr<>'') and (pwd<>'') then
  begin
	tlh:=TStringList.create;
  	res:=call_external_prog(LOG_ERROR,sudo+'cat '+LNX_ShadowFile+' | grep '+usr+':',tlh);  	
  	if (res=0) and (tlh.count>0) then
  	begin
      sh:=tlh[0]; for i:=1 to ma do arr[i]:=CSV_Item(sh,':',i);
      if (arr[2]<>'!') and (arr[2]<>'*') then
      begin
      	algo:=CSV_Item	(arr[2],'$',2); sh:=algo;
      	salt:=CSV_Item	(arr[2],'$',3);
    					 	 algo:='DES';
      	if sh='1' 		then algo:='md5';
      	if sh='2a' 		then algo:='Blowfish';
      	if sh='2y' 		then algo:='Blowfish';
      	if sh='5' 		then algo:='sha-256';
      	if sh='6' 		then algo:='sha-512';
      	if sh=algo		then res:=-1;
      end else res:=-1; 
      if arr[1]<>usr	then res:=-1;
      if Str2Num(arr[8],j) then
      begin // test account deactivation
      	dt:=now; dt:=IncDay(EncodeDate(1970,1,1),j);
      	if dt<=now then res:=-1;
      end;
//	  writeln('salt:',salt); writeln('algo:',algo); for i:=1 to 5 do writeln(i,' ',arr[i]);
	  if (res=0) then
	  begin
		tlh.clear; 
//		if (pwd='') then pwd:='-s \<\<\< /dev/null';
	  	cmd0:=sudo+'mkpasswd -m '+algo+' -S '+salt+' ';
	  	cmd:=				cmd0+pwd;
	  	if (pwddefault<>'') then cmd:=cmd+' ; '+cmd0+pwddefault;	  	
	  	cmd:=cmd+' 2>&1';
	  	res:=call_external_prog(LOG_ERROR,cmd,tlh);  		  
//	  	SAY(LOG_INFO,'LNX_ChkUsrPwdValid:'+Num2Str(res,0)+' '+Num2Str(tlh.count,0)+' '+cmd); SAY_TL(LOG_INFO,tlh);
		if (res=0) then
		begin
	  	  if (tlh.count>0) then
		  begin
	    	if (tlh[0]=arr[2]) then 
	    	begin
	    	  if ((tlh.count>=2) and (tlh[0]=tlh[1])) then res:=1;	// default pwd used
	    	end else res:=-1;	// different pwd
(*		 	SAY(LOG_INFO,'LNX_ChkUsrPwdValid[infos '+Num2Str(res,2)+'/'+Num2Str(tlh.count,0)+']: usr: '+usr+' pwd: '+pwd+' pwddflt: '+pwddefault);
			SAY(LOG_INFO,'LNX_ChkUsrPwdValid[shadowDB]:   '+arr[2]);
			SAY(LOG_INFO,'LNX_ChkUsrPwdValid[PWDgiven]:   '+tlh[0]); 
			SAY_TL(LOG_INFO,tlh);  *)
	  	  end else begin LOG_Writeln(LOG_ERROR,'LNX_ChkUsrPwdValid[4]: '+Num2Str(res,0)+' no output '+cmd); res:=-2; end;
	  	end else begin LOG_Writeln(LOG_ERROR,'LNX_ChkUsrPwdValid[3]: '+Num2Str(res,0)+' mkpasswd erroneous call'); res:=-2; end;
	  end else begin LOG_Writeln(LOG_ERROR,'LNX_ChkUsrPwdValid[2]: '+Num2Str(res,0)+' unknown algo'); res:=-1; end;
	end else begin LOG_Writeln(LOG_ERROR,'LNX_ChkUsrPwdValid[1]: '+Num2Str(res,0)+' no access to '+LNX_ShadowFile); res:=-1; end;  
	tlh.free;
  end else begin LOG_Writeln(LOG_ERROR,'LNX_ChkUsrPwdValid[0]: '+Num2Str(res,0)+' empty usr/pwd '); res:=-1; end;  
  {$ENDIF}
  LNX_ChkUsrPwdValid:=res;
end;

function  LNX_ChgUsrPwd(usr,usrreq,pwd,pwd2,pwddflt,pwdold:string; PWD_OLDsameNEW:boolean; var msg:string):integer;
var res:integer; tlh:TStringList; cmd:string;
begin
  res:=-1; tlh:=TStringList.create; 
  if (usr=usrreq) then
  begin
    if (pwd=pwd2) then
    begin
	  if (pwd<>pwddflt) then
      begin
        {$IFDEF UNIX}
        if (pwdold='') then res:=0 else res:=LNX_ChkUsrPwdValid(usr,pwdold,'');
        if (res=0) then
        begin
    	  if (LNX_ChkUsrPwdValid(usr,pwd,pwddflt)<0) or (PWD_OLDsameNEW) then
          begin
//    	 	cmd:='echo '''+usr+':'+pwd+''' | '+sudo+'chpasswd'; // does not work
		  	cmd:=sudo+'echo -e "'+pwd+'\n'+pwd+'\n" | passwd '+usr;
    	  	res:=call_external_prog(LOG_NONE,cmd,tlh);
			if (res<>0) then 
			begin
			  LOG_Writeln(LOG_ERROR,'LNX_ChgUsrPwd: can not set pwd for usr: '+usr+' '+Num2Str(res,0));
			  LOG_ShowStringList(LOG_ERROR,tlh);
			  res:=-6;
			end else LNX_UsrAuthModDateTime:=GetFileAge(LNX_ShadowFile);	// upd modification date of shadow file
    	  end else res:=-5; // newpwd=oldpwd
    	end else res:=-7; // wrong old pwd
		{$ELSE}
		  res:=-8; // not for windows
		{$ENDIF}
//		SAY(LOG_INFO,'LNX_ChgUsrPwd: '+Num2Str(res,0)+' set new pwd for usr:'+usr+' pwd:'+pwd);
	  end else res:=-4; 
	end else res:=-3; 
  end else res:=-2; 
  case res of
  	-8: msg:='no unix system';
  	-7: msg:='wrong password';
    -6: msg:='can not set pwd';
    -5: msg:='same pwd not allowed';
	-4: msg:='default pwd not allowed'; 
	-3: msg:='passwords do not match'; 
	-2: msg:='wrong usr'; 
	 0: msg:='password changed'; 
   else msg:='unknown error';
  end; // case
  if res=0	then SAY(		 LOG_NOTICE,'LNX_ChgUsrPwd: '+msg)
  			else LOG_Writeln(LOG_ERROR,	'LNX_ChgUsrPwd: '+msg);
  tlh.free;
  LNX_ChgUsrPwd:=res;
end;
function  LNX_ChgUsrPwd(usr,pwd:string; var msg:string):integer;
begin LNX_ChgUsrPwd:=LNX_ChgUsrPwd(usr,usr,pwd,pwd,pwd+'x','',true,msg); end;

function  LNX_RemoveOldFiles(path2files:string; days:longint):integer;
// e.g. LNX_RemoveOldFiles('/path/to/files*',5);
// delete files older than 5 days
// find /path/to/files* -mtime +5 -exec rm {} \;
var res:integer; cmd,sh:string;
begin
  if DirectoryExists(Get_Dir(path2files)) then
  begin
    cmd:=sudo+'find '+path2files+' -mtime '+Num2Str(days,0)+' -exec rm {} \;';
//	SAY(LOG_INFO,'LNX_RemoveOldFiles['+Num2Str(days,0)+'days]: '+cmd);
    res:=call_external_prog(LOG_NONE,cmd,sh); res:=0;
  end else res:=-1; 
  LNX_RemoveOldFiles:=res;
end;

function  LNX_RemoveFilesKeepLatest(fnhdr:string; uniqcnt:integer):integer;
(* e.g. LNX_RemoveFilesKeepLatest('/path/to/files/bckexe_*',6);
   ls -r /path/to/files/bckexe_* | awk -F_ 'a[substr($NF,1,6)]++' | xargs rm -f
will keep latest files of each month
bckexe_10000000556ff033_20210115140823.tgz
bckexe_10000000556ff033_20210113071431.tgz
bckexe_10000000556ff033_20210111191654.tgz
bckexe_10000000556ff033_20210109195131.tgz
bckexe_10000000556ff033_20210108180209.tgz
bckexe_10000000556ff033_20201220162006.tgz
bckexe_10000000556ff033_20201219143332.tgz
bckexe_10000000556ff033_20201218212846.tgz
...
bckexe_10000000556ff033_20201206132455.tgz
bckexe_10000000556ff033_20201203174956.tgz
bckexe_10000000556ff033_20201125121330.tgz
bckexe_10000000556ff033_20201123180211.tgz
...
bckexe_10000000556ff033_20201113180033.tgz
bckexe_10000000556ff033_20201113175733.tgz
...
keep:
bckexe_10000000556ff033_20210115140823.tgz
bckexe_10000000556ff033_20201220162006.tgz
bckexe_10000000556ff033_20201125121330.tgz
delete all other files
*)
var res:integer; cmd,sh:string;
begin
  if (DirectoryExists(Get_Dir(fnhdr)) and (uniqcnt>0)) then
  begin
    cmd:=sudo+'ls -r '+fnhdr+' | awk -F_ ''a[substr($NF,1,'+Num2Str(uniqcnt,0)+')]++'' | xargs rm -f';
//	SAY(LOG_INFO,'LNX_RemoveFilesKeepLatest['+Num2Str(uniqcnt,0)+']: '+cmd);
    res:=call_external_prog(LOG_NONE,cmd,sh); res:=0;
  end else res:=-1; 
  LNX_RemoveFilesKeepLatest:=res;
end;

function  LNX_CertFormatTyp(certtyp:Cert_Type_t):string;
var sh:string;
begin
  sh:=StringReplace(GetEnumName(TypeInfo(Cert_Type_t),Ord(certtyp)),'CT_','',[rfReplaceAll,rfIgnoreCase]);
  LNX_CertFormatTyp:=sh;
end;

function  LNX_CertIDget(filnam:string; certtyp:Cert_Type_t; idouttyp:Cert_Type_t; var id:string):boolean;
// LNX_CertSerialGET('mycert.pem',sha1,id)
var ok:boolean; cmd,cmd2,typs2,typs:string;
begin
  if FileExists(filnam) then
  begin// openssl x509 -in mycert.pem -noout -serial
    typs2:=lowercase(LNX_CertFormatTyp(idouttyp)); cmd2:='';
	cmd:='openssl '+lowercase(LNX_CertFormatTyp(certtyp))+' -in "'+filnam+'" -noout';
	case idouttyp of
		CT_md5:		typs:='MD5 Fingerprint';
		CT_sha1:	typs:='SHA1 Fingerprint';
		CT_sha256:	typs:='SHA256 Fingerprint';
		CT_serial:	typs:='serial';
		CT_modulus:	typs:='Modulus';
		CT_modmd5:	begin 
					  typs2:=lowercase(LNX_CertFormatTyp(CT_modulus));
					  cmd2:=' | sed "s/Modulus=//g" | sed "s/://g" | openssl md5'; 
					  typs:='(stdin)'; 
					end;
	end; // case
	cmd:=cmd+' -'+typs2+cmd2+' | sed "s/'+typs+'=//g" | sed "s/://g"';
//writeln(cmd);
    call_external_prog(LOG_NONE,cmd,id);
    id:=GetHexChar(id);
	ok:=(id<>'');
  end else ok:=false;
  LNX_CertIDget:=ok;
end;

procedure LNX_CertIDtest;
var ok:boolean; hashpub,hashpriv:string;
begin
  SAY(LOG_INFO,'Check validity of .pem and .key file with md5 hash of both moduli');
  ok:=(	LNX_CertIDget(cert0_key_c,		CT_rsa, 	CT_modmd5,	hashpriv) and
  		LNX_CertIDget(cert0_crtORpem_c,	CT_x509,	CT_modmd5,	hashpub) );
  if ok then
  begin
	ok:=(hashpriv=hashpub);
	SAY(LOG_INFO,'LNX_CetIDtest ok:'+Bool2Str(ok));
	SAY(LOG_INFO,hashpriv+' ('+cert0_key_c+')');
	SAY(LOG_INFO,hashpub+ ' ('+cert0_crtORpem_c+')');
  end else LOG_Writeln(LOG_ERROR,'LNX_CetIDtest: files not accessable '+cert0_key_c+' or '+cert0_crtORpem_c);
end;

procedure LNX_CertInit(var certstruct:cert_t);
begin
  with certstruct do
  begin
    ok:=false; filnam:=''; id:='';
  end; // with
end;

procedure LNX_CertShow(lvl:T_ErrorLevel; var certstruct:cert_t);
begin
  with certstruct do
  begin
    if (certtyp=CT_Path)
  	  then SAY(lvl,Get_FixedStringLen(desc+'Path:',15,false)+filnam)
  	  else SAY(lvl,Get_FixedStringLen(desc+':',15,false)+	 filnam+
  	  	' id:'+id+' typ:'+LNX_CertFormatTyp(certtyp));
  end; // with
end;

procedure LNX_CertPackShow(lvl:T_ErrorLevel; var certpack:cert_pack_t);
begin
  with certpack do
  begin
  	SAY(lvl,Get_FixedStringLen('CertInfo['+Num2Str(idx,0)+']:',15,false)+desc+' ok:'+Bool2YN(ok)+' pwdset:'+(Bool2YN(pwd<>'')+' packtyp:'+LNX_CertFormatTyp(packtyp)));
  	LNX_CertShow(lvl,cert[CertPrivKey]);
  	LNX_CertShow(lvl,cert[CertPublic]);
  	LNX_CertShow(lvl,cert[CertCombined]);
  	LNX_CertShow(lvl,cert[CertCA]);
  end; // with
end;

function  LNX_CertDir(var certstruct:cert_t; certfil:string; certtype:Cert_Type_t):boolean;
begin
  LNX_CertInit(certstruct);
  with certstruct do
  begin
  	filnam:=certfil; certtyp:=certtype; ok:=true; id:='';
	LNX_CertDir:=ok;
  end; // with
end;

function  LNX_CertReg(var certstruct:cert_t; certfil:string; certtype:Cert_Type_t):boolean;
begin
  LNX_CertInit(certstruct);
  with certstruct do
  begin
  	filnam:=certfil; certtyp:=certtype;
	ok:=LNX_CertIDget(filnam,certtyp,CT_modmd5,id);
	if not ok then id:='';
	LNX_CertReg:=ok;
  end; // with
//LNX_CertShow(LOG_INFO,certstruct);
end;

procedure LNX_CertInitPack(var certpack:cert_pack_t; num:longint);
var n:longint;
begin
  for n:=CertPublic to CertCombined do 
  begin
    LNX_CertInit(	certpack.cert[n]);
    case n of
      CertPublic:	certpack.cert[n].desc:='PublicCert';
      CertPrivKey:	certpack.cert[n].desc:='PrivateKey';
      CertCA:		certpack.cert[n].desc:='CertAuth';
      CertCombined: certpack.cert[n].desc:='CertCombined';
      else			LOG_Writeln(LOG_ERROR, 'LNX_CertInitPack: invalid idx '+Num2Str(n,0));
    end; // case
  end;
  certpack.desc:=''; certpack.pwd:=''; certpack.ok:=false; certpack.idx:=num;
end;

function  LNX_CertStartPack(var certpack:cert_pack_t; descr,pubcertfil,privkeyfil,cacertfil,combinedfil,passwd:string; certpacktyp:Cert_Type_t):boolean;
// https://gist.github.com/BlueT/ee521743fa0da703af68f37ac0f63a90
begin
  with certpack do
  begin
	LNX_CertInitPack(certpack,idx);
	desc:=descr; pwd:=passwd;	packtyp:=certpacktyp;

//  create a combined .pem file for e.g. lighthttp
	if (combinedfil<>'') and (not FileExists(combinedfil)) and
	  	FileExists(privkeyfil) and (GetFileSize(privkeyfil)>0) and
	  	FileExists(pubcertfil) and (GetFileSize(pubcertfil)>0) then
	  call_external_prog(LOG_NONE,'cat '+privkeyfil+' '+pubcertfil+' > '+combinedfil+
	  							  ' ; chmod 640 '+combinedfil);

	LNX_CertReg(				cert[CertPublic],	pubcertfil,	CT_x509);
	LNX_CertReg(				cert[CertPrivKey],	privkeyfil,	CT_rsa);
	LNX_CertReg(				cert[CertCombined],	combinedfil,CT_Combined);
	if (cacertfil<>'') then
	begin
	  if not ISdir(cacertfil) then 
	  begin
		if FileExists(cacertfil) and (GetFileSize(cacertfil)>0)
		  then LNX_CertReg(		cert[CertCA],		cacertfil,	CT_x509)
		  else cert[CertCA]:=	cert[CertPublic];
	  end else LNX_CertDir(		cert[CertCA],		cacertfil,	CT_Path);
	end else cert[CertCA]:=		cert[CertPublic];
	ok:=(cert[CertPublic].ok and cert[CertPrivKey].ok and cert[CertCA].ok);
//	ok:=(cert[CertPublic].id=cert[CertPrivKey].id);
	LNX_CertStartPack:=ok;
  end; // with
end;

// https://linuxconfig.org/easy-way-to-encrypt-and-decrypt-large-files-using-openssl-and-linux
function  LNX_DecryptFile(filprivkey,filnam,ext:string; flags:s_rpimaintflags):integer;
// e.g. LNX_DecryptFile('/etc/ssl/private/ssl-cert-snakeoil.key','supportfile_123.tgz','ssl',[]);
// openssl smime -decrypt -binary -in supportfile_123.tgz.ssl -out supportfile_123.tgz -inform DEM -inkey /etc/ssl/private/ssl-cert-snakeoil.key
var res:integer; cmd,sh:string;
begin
  res:=-1;
  if FileExists(filnam+'.'+ext) and FileExists(filprivkey) then
  begin
	cmd:=''; if (ext='') then ext:=LNX_CertFormatTyp(CT_ssl);
	cmd:=cmd+	'openssl smime -decrypt -binary'+
						' -in '+				filnam+'.'+ext+' '+
						' -out '+				filnam+' '+
						' -inform DEM -inkey '+	filprivkey;
	res:=call_external_prog(LOG_NONE,cmd,sh); res:=0;
	if (res=0) then res:=GetFileSize(filnam) else res:=-1;
  	if (res>0) then res:=0;	// to set LOG notice
  end else LOG_Writeln(LOG_ERROR,'LNX_DecryptFile: files not exist '+filnam+'.'+ext+' '+filprivkey);
  LNX_DecryptFile:=res;
end;

function  LNX_EncryptFile(filpubkey,filnam,ext:string; flags:s_rpimaintflags):integer;
// e.g. LNX_EncryptFile('/etc/ssl/certs/ssl-cert-snakeoil.pem','supportfile_123.tgz','ssl',[]);
// openssl smime -encrypt -binary -aes-256-cbc -in supportfile_123.tgz -out supportfile_123.tgz.ssl -outform DER /etc/ssl/certs/ssl-cert-snakeoil.pem
var res:integer; cmd,sh:string;
begin
  res:=-1;
  if FileExists(filnam) and FileExists(filpubkey) then
  begin
	cmd:=''; if (ext='') then ext:=LNX_CertFormatTyp(CT_ssl);
	cmd:=cmd+	'openssl smime -encrypt -binary -aes-256-cbc'+
						' -in '+			filnam+
						' -out '+			filnam+'.'+ext+
						' -outform DER '+	filpubkey;
	res:=call_external_prog(LOG_NONE,cmd,sh); res:=0;
//	SAY(LOG_INFO,'LNX_EncryptFile:'+cmd+':'+Num2Str(res,0)+':'+sh+':');
	if (res=0) then res:=GetFileSize(filnam+ext) else res:=-1;
  	if (res>0) then res:=0;	// to set LOG notice
  end else LOG_Writeln(LOG_ERROR,'LNX_EncryptFile: files not exist '+filnam+' '+filpubkey);
  LNX_EncryptFile:=res;
end;

function  LNX_LinkFile(filnam,linknam:string):integer;
var res:integer; cmd:string;
begin
  if (linknam<>'') then
  begin
	if (filnam<>'') and (filnam<>linknam) and (FileExists(filnam))
	  then cmd:='ln -s "'+	filnam+'" "'+linknam+'"'
	  else cmd:='rm "'+	linknam+'"';
	res:=call_external_prog(LOG_NONE,cmd);
//SAY(LOG_WARNING,Num2Str(res,0)+':'+cmd+':'+filnam+':'+linknam);
  end else res:=-1;
  LNX_LinkFile:=res;
end;

function  LNX_GetNewestFile(filnampat:string):string;
// filnampat: /var/lib/BASIS/pump/bck/bckcfg_0000000012345_*
var _tl:TStringList; sh:string;
begin
  _tl:=TStringList.create;
  call_external_prog(LOG_NONE,'ls -1r '+filnampat,_tl);
  if (_tl.count>0) then
  begin
	if ((_tl[0]<>'') and FileExists(_tl[0])) then sh:=_tl[0];
  end else sh:='';
  _tl.free;
//writeln('LNX_GetNewestFile:',filnampat,':',sh);
  LNX_GetNewestFile:=sh;
end;

function  LNX_tarRST(target,fillst:string; flags:s_rpimaintflags):longint;
// restore tar --keep-newer-files -xzvf bck_<snr>.tgz -C / 
var res:longint; cmd:string;
begin
  res:=-1; 
  fillst:=PrepFilePath(Trimme(fillst,3)); 
  target:=PrepFilePath(Trimme(target,3));
  if (fillst<>'') and (FileExists(fillst)) then
  begin
    cmd:='';
	if (target='') then target:=PrepFilePath(c_tmpdir+'/tmp');
	if (UpdNewerOnly	IN flags)		then cmd:=cmd+'--keep-newer-files ';
	cmd:=cmd+'-x';
	if (Pos('.GZ', Upper(fillst))>0) 	or
	   (Pos('.TGZ',Upper(fillst))>0)	then cmd:=cmd+'z';
	if (UpdVerbose 		IN flags)		then cmd:=cmd+'v';
	cmd:='tar '+cmd+'f '+fillst+' -C '+target;
	if not (UpdVerbose	IN flags)		then cmd:=cmd+' >/dev/null 2>&1';
//	SAY(LOG_INFO,'LNX_tarRST: '+cmd);
	res:=call_external_prog(LOG_NONE,cmd); res:=0;
	if (res>=0) then res:=0 else res:=-1;
//  if (res=0) then res:=GetFileSize(fillst) else res:=-1;
  end;
  LNX_tarRST:=res;
end;

function  LNX_tarSAV(target,fillst:string; flags:s_rpimaintflags):longint;
var res:longint; cmd,tflg,ddir,sh:string;
begin
  if not (UpdNoWDOGprevent IN flags) then LNX_WDOG(WDOG_Pause);   // pause
  ddir:=PrepFilePath(AppDataDir_c+'/'+ApplicationName);
  if (fillst='') then fillst:=ddir+'/'+ApplicationName+'.ini';
  if (target='') then target:=PrepFilePath(c_tmpdir+'/bck_'+RPI_snr);
  
//adjust extension will exclusively determined by flags
  target:=StringReplace(target,'.gz','',	[rfReplaceAll,rfIgnoreCase]);
  target:=StringReplace(target,'.tgz','',	[rfReplaceAll,rfIgnoreCase]);
  target:=StringReplace(target,'.tar','',	[rfReplaceAll,rfIgnoreCase]);
  
  if (not (UpdNoCreateDir IN flags)) or DirectoryExists(Get_Dir(target)) then
  begin
    cmd:='';  
    if not	(UpdNoCreateDir IN flags) then cmd:=cmd+'mkdir -p '+Get_Dir(target)+' ; ';
    
    tflg:='';
    if not	(UpdNoZIP 		IN flags) then 
    begin 
	  tflg:=tflg+'z';	target:=target+'.tgz';
    end else 			target:=target+'.tar';

    if 		(UpdFollowLink 	IN flags) then		 tflg:=tflg+'h';
    if 		(UpdVerbose 	IN flags) then		 tflg:=tflg+'v';
    if		(UpdVerify 		IN flags) and
	 		(UpdNoZIP		IN flags) then		 tflg:=tflg+'W'; // tar: Cannot verify compressed archives
    
	cmd:=cmd+	'tar -c'+tflg+'f '+	target
  			 		+' --exclude='+		target
  					+' '+				fillst;
  	if not	(UpdVerbose 	IN flags) then cmd:=cmd+' >/dev/null 2>&1';
//	SAY(LOG_INFO,'LNX_tar: '+cmd);
  	res:=call_external_prog(LOG_NONE,cmd,sh); res:=0;
  	if (res=0) then res:=GetFileSize(target) else res:=-1;
  	
  	if (UseENCrypt IN flags) then
  	begin
	  if (res>0) then
	  begin
		with CertPack[0] do
		begin
		  if (CertPack[0].ok) then
		  begin
			res:=LNX_EncryptFile(
					cert[CertPublic].filnam,
					target,
					cert[CertPublic].id+'.'+LNX_CertFormatTyp(packtyp),
					flags);
		  end else LOG_Writeln(LOG_ERROR,'LNX_tar: CertPack[0] not initialized');
	  	end; // with
	  end else LOG_Writeln(LOG_ERROR,'LNX_tar: can no encrypt file, filesize not ok');
  	end;
  	
  	if (res>0) then res:=0;	// to set LOG notice
  end else LOG_Writeln(LOG_ERROR,'LNX_tar: target dir does not exist '+Get_Dir(target));
  if not (UpdNoWDOGprevent IN flags) then LNX_WDOG(WDOG_Resume);  // resume
  LNX_tarSAV:=res;
end;

procedure MinMaxAdj(var value:real; valmin,valmax:real);
begin
  if not IsNaN(value) then
  begin
	if not IsNaN(valmin) then if (value<valmin) then value:=valmin;
  	if not IsNaN(valmax) then if (value>valmax) then value:=valmax;
  end
  else
  begin
	if not IsNaN(valmin) then value:=valmin;
  end;
end;

function  InLimits(value,minvalue,maxvalue:real):boolean;
begin InLimits:=((value>=minvalue) and (value<=maxvalue)); end;

function  Limits(var value:int64; minvalue,maxvalue:int64):int64;
begin if value>maxvalue then value:=maxvalue; if value<minvalue then value:=minvalue; Limits:=value; end;
function  Limits(var value:longint; minvalue,maxvalue:longint):longint;
begin if value>maxvalue then value:=maxvalue; if value<minvalue then value:=minvalue; Limits:=value; end;
function  Limits(var value:longword; minvalue,maxvalue:longword):longword;
begin if value>maxvalue then value:=maxvalue; if value<minvalue then value:=minvalue; Limits:=value; end;
function  Limits(var value:single; minvalue,maxvalue:single):single;
begin if value>maxvalue then value:=maxvalue; if value<minvalue then value:=minvalue; Limits:=value; end;
function  Limits(var value:real; minvalue,maxvalue:real):real;
begin if value>maxvalue then value:=maxvalue; if value<minvalue then value:=minvalue; Limits:=value; end;

function  MinMax(value:int64; var minvalue,maxvalue:int64):integer;
var res:integer;
begin 
  res:=0;
  if value>maxvalue then begin res:= 1; maxvalue:=value; end;
  if value<minvalue then begin res:=-1; minvalue:=value; end; 
  MinMax:=res;
end;
function  MinMax(value:longint; var minvalue,maxvalue:longint):integer;
var res:integer;
begin 
  res:=0;
  if value>maxvalue then begin res:= 1; maxvalue:=value; end;
  if value<minvalue then begin res:=-1; minvalue:=value; end; 
  MinMax:=res;
end;
function  MinMax(value:longword; var minvalue,maxvalue:longword):integer;
var res:integer;
begin 
  res:=0;
  if value>maxvalue then begin res:= 1; maxvalue:=value; end;
  if value<minvalue then begin res:=-1; minvalue:=value; end; 
  MinMax:=res;
end;

function  MinMax(value:real; var minvalue,maxvalue:real):integer;
var res:integer;
begin 
  res:=0;
  if not IsNan(value) then
  begin
	if IsNaN(maxvalue) 
	  then maxvalue:=value
	  else if value>maxvalue then begin res:= 1; maxvalue:=value; end;
	if IsNaN(minvalue) 
	  then minvalue:=value
	  else if value<minvalue then begin res:=-1; minvalue:=value; end; 
  end;
  MinMax:=res;
end;

procedure RB_Open(var struct:RING_Buffer_t; siz:word; inipat:RING_BufferData_t);
var idx:longint;
begin
  with struct do
  begin
    bufsiz:=siz;
    if (bufsiz<0) then bufsiz:=0;
    SetLength(buf,bufsiz);
    for idx:=0 to (bufsiz-1) do buf[idx]:=inipat;
    WRidx:=0; RDidx:=0; dcnt:=0;
  end; // with
end;

procedure RB_Close(var struct:RING_Buffer_t);
begin RB_Open(struct,0,0); end;

function  RB_RD(var struct:RING_Buffer_t; var dataOUT:RING_BufferData_t):boolean;
var _ok:boolean;
begin
  with struct do
  begin
    if (bufsiz>0) then
  	begin
  	  _ok:=(dcnt>0);
	  if _ok then
      begin
      	dataOUT:=buf[RDidx];
      	inc(RDidx); dec(dcnt);
      	if (RDidx>=bufsiz) then RDidx:=0;
      end; (*else LOG_Writeln(LOG_ERROR,'RB_RD['+
	  		 Num2Str(RDidx,0)+'/'+Num2Str(WRidx,0)+'/'+Num2Str(dcnt,0)+']: underrun'); *)
    end else LOG_Writeln(LOG_ERROR,'RB_RD: no buffer size');
    RB_RD:=(_ok and (dcnt>=0) and (bufsiz>0));
  end; // with
end;

function  RB_WR(var struct:RING_Buffer_t; dataIN:RING_BufferData_t):boolean;
begin
  with struct do
  begin
    if (bufsiz>0) then
  	begin
      buf[WRidx]:=dataIN;
      inc(WRidx); inc(dcnt);
      if (WRidx>=bufsiz) then WRidx:=0;
(*	  if (dcnt>bufsiz)  then
	  	LOG_Writeln(LOG_ERROR,'RB_WR['+
	  		Num2Str(RDidx,0)+'/'+Num2Str(WRidx,0)+'/'+Num2Str(dcnt,0)+
	  		']: overrun data: '+Num2Str(dataIN,0,2)); *)
	end else LOG_Writeln(LOG_ERROR,'RB_WR: no buffer size');
	RB_WR:=((dcnt>0) and (dcnt<bufsiz));
  end; // with
end;

function  RB_RDidx(var struct:RING_Buffer_t; dist:longint):longint;
begin RB_RDidx:=MOD_Euclid(struct.RDidx+dist,struct.bufsiz); end;

function  RB_WRidx(var struct:RING_Buffer_t; dist:longint):longint;
begin RB_WRidx:=MOD_Euclid(struct.WRidx+dist,struct.bufsiz); end;

procedure RING_BufferTest;
const siz=5;
var i:integer; r:real; ok:boolean; rb:RING_Buffer_t;
begin
  RB_Open(rb,siz,0);
  for i:= 1 to siz do RB_WR(rb,i);
  
  for i:= -siz to siz do writeln('RDi',i:2,':',RB_RDidx(rb,i));

  for i:= 1 to 2 do 
  begin 
    ok:=RB_RD(rb,r);
    writeln(r:0:1,' ',ok);
  end;
  for i:= 1 to 1 do RB_WR(rb,i+siz);
  for i:= 1 to siz do 
  begin 
    ok:=RB_RD(rb,r);
    writeln(r:0:1,' ',ok);
  end;
  for i:= 2 to 2 do RB_WR(rb,i+siz);
  for i:= 1 to siz do 
  begin 
    ok:=RB_RD(rb,r);
    writeln(r:0:1,' ',ok);
  end;  
  RB_Close(rb);
end;

function  STAT_Str(var stats:STAT_struct_t; vk,nk:byte):string;
begin
  with stats do
  begin
	STAT_Str:=	Num2Str(MINval,vk,nk)+	' '+Num2Str(MAXval,vk,nk)+' '+
				Num2Str(SUMval,vk,nk)+	' '+
				Num2Str(StdDev,vk,nk)+	' '+Num2Str(MEANval,vk,nk)+' '+
				Num2Str(trend,vk,nk)+	' '+Trend2Ch(Sign(trend));
  end; // with
end;

procedure STAT_Reset(var stats:STAT_struct_t);
var i:longint;
begin
  with stats do
  begin
    statready:=false;
    filled_up:=false;
//	idx:=Length(val_arr)-1;
	idx:=0;			idxLast:=0;
	trend:=0;
	SUMval:=0;		MINval:=0;		MAXval:=0;
	MEANval:=0;		StdDev:=0;
	for i:=1 to Length(val_arr) do 	val_arr[i-1]:=0;
	statready:=true;
  end; // with
end;

procedure STAT_Open(var stats:STAT_struct_t; arrsize:word);
begin
  with stats do
  begin // 0:population standard deviation 1:sample standard deviation
    useSampleDev:=1;
	SetLength(val_arr,arrsize);
  end; // with
  STAT_Reset(stats);
end;
  
procedure STAT_Close(var stats:STAT_struct_t);
begin
  with stats do
  begin
    statready:=false;
	SetLength(val_arr,0);
  end; // with
end;

function  STAT_RingBuffer(
	const data:array of float;
	const StartIdx,Count,useSampleDev:longint; 
	var   SUMval,MINval,MAXval,MEANval,StdDev:float):boolean;
// implements statistics on a ring buffer
var _i,_idx:longint;
begin
  try
  	SUMval:=data[StartIdx];
  	StdDev:=Sqr(SUMval);
  	MAXval:=SUMval; 	
  	MINval:=SUMval;
  	for _i:=(StartIdx+1) to (StartIdx+Count-1) do
  	begin
  	  _idx:= _i mod Length(data);
  	  SUMval:=SUMval+data[_idx];
  	  StdDev:=StdDev+Sqr(data[_idx]);
  	  if (data[_idx]>MAXval) then MAXval:=data[_idx];
  	  if (data[_idx]<MINval) then MINval:=data[_idx];
  	end;
  	
  	MEANval:=SUMval/Count;
	StdDev:=StdDev-Count*Sqr(MEANval);
	
//	0:population standard deviation 1:sample standard deviation
  	if (Count>useSampleDev) 
	  then StdDev:=Sqrt(StdDev/(Count-useSampleDev))
  	  else StdDev:=0;  	

	STAT_RingBuffer:=true;	
  except
	SUMval:=	NaN;
	MINval:=	NaN;
	MAXval:=	NaN;
	MEANval:=	NaN;
	StdDev:=	NaN;
	STAT_RingBuffer:=false;
  end;
end;

function  STAT_Inject(var STATS:STAT_struct_t; newval:float):boolean;
var _stat:boolean; _idx,_cnt:longint; _avg:float;
begin
  try
	with STATS do
  	begin
  	  _stat:=statready;
  	  if _stat then
  	  begin
		val_arr[idx]:=newval; 
		idxLast:=idx;
  	 	inc(idx);
  	 	if (idx>=Length(val_arr)) then
  	 	begin
  	 	  filled_up:=true;
  	 	  idx:=0;
  	 	end;
	  	_avg:=MEANval;	
	  	
	  	if filled_up 
	  	  then begin _idx:=idx; _cnt:=Length(val_arr);	end
	  	  else begin _idx:=0; 	_cnt:=idx; 				end;
	  	
	  	_stat:=STAT_RingBuffer(	
	  			val_arr,_idx,_cnt,
	  			useSampleDev,SUMval,MINval,MAXval,
	  			MEANval,StdDev);

	  	if _stat then trend:=MEANval - _avg;
	  end;
  	end; // with
  except
	_stat:=false;
  end;
  STAT_Inject:=_stat;
end;

procedure STAT_Test;
const vk=8; nk=2; hist=3;
var sim:array[0..20] of real=(1,2,3,4,3,2,1,-1,-2,-3,1,2,3,4,3,2,1,1,1,1,1);
	i:longint; _stat:STAT_struct_t;
begin 
  STAT_Open(_stat,hist);
  writeln('statistic based on recent '+Num2Str(hist,0)+' values');
  writeln('      SimVal      Min      Max      Sum   StdDev     Mean    trend Up/Down/Stay');
  for i:=1 to Length(sim) do 
  begin
	with _stat do
	begin
	  if STAT_Inject(_stat, sim[i-1]) then
		writeln(Bool2YNS(filled_up)+Num2Str(idxLast,2)+' '+Num2Str(sim[i-1],vk,nk)+' '+STAT_Str(_stat,vk,nk));
	end; // with
  end;
  STAT_Close(_stat);
end;

function  ChgArrLW(var arr,adflt:Array of longword; var ArrOut:Array of longint):boolean;
var chg:boolean; i,j:integer;
begin
  chg:=false;
  try
//  SetLength(ArrOut,Length(arr));
  	for i:=1 to Length(arr) do 
  	begin
  	  ArrOut[i-1]:=i;
  	  for j:= 1 to Length(adflt) do
  	  begin
  	 	if (arr[i-1]=adflt[j-1]) then 
  	 	begin
  	 	  if (i<>j) then chg:=true;
//writeln(i,'/',j,' ',(i<>j),' 0x',HexStr(arr[i-1],2),' 0x',HexStr(adflt[i-1],2));
  	 	  ArrOut[i-1]:=j;
  	 	end;
  	  end;
  	end;
  except
	LOG_Writeln(LOG_ERROR,'ChgArrLW');
  end;
  ChgArrLW:=chg;
end;

function  MODarrLI(var arr:Array of longint; idx,newval:longint; sects,keys:string):boolean;
var chg:boolean; i:longint; sh:string;
begin
  chg:=false;
  try
	chg:=(arr[idx-1]<>newval);
//	write('arr:'); for i:= 1 to Length(arr) do write(arr[i-1]:2,' '); writeln;	
	if chg then
	begin
	  arr[idx-1]:=newval;
	  sh:='';
	  for i:= 1 to Length(arr) do 
		sh:=sh+Num2Str(arr[i-1],0)+',';
	  BIOS_SetIniString(sects,keys,CSV_RemLastSep(sh,','),[BIOS_trim4])
//writeln('MODarrLI['+keys+'/'+Num2Str(idx,0)+']: '+Num2Str(newval,0)+' '+Num2Str(arr[idx-1],0));
	end;
  except
	LOG_Writeln(LOG_ERROR,'MODarrLI['+sects+'/'+keys+'/'+Num2Str(idx,0)+']: '+Num2Str(newval,0));
  end;
  MODarrLI:=chg;
end;

function  MODarrLW(var arr:Array of longword; idx:longint; newval:longword; sects,keys:string):boolean;
var chg:boolean; i:longint; sh:string;
begin
  chg:=false;
  try
	chg:=(arr[idx-1]<>newval);
	if chg then
	begin
	  arr[idx-1]:=newval;
	  sh:='';
	  for i:= 1 to Length(arr) do 
		sh:=sh+'0x'+QW2Str(arr[i-1])+',';
//		sh:=sh+Num2Str(arr[i-1],0)+',';
	  BIOS_SetIniString(sects,keys,CSV_RemLastSep(sh,','),[BIOS_trim4])
	end;
  except
	LOG_Writeln(LOG_ERROR,'MODarrLW['+sects+'/'+keys+'/'+Num2Str(idx,0)+']: '+Num2Str(newval,0));
  end;
  MODarrLW:=chg;
end;

function  ReMAParrFL(var arr,adflt:Array of real; sects,keys,values:string):boolean;
var chg:boolean; i,j:integer; sh:string;
begin
  chg:=false;
  try
	for i:=1 to Length(arr) do arr[i-1]:=adflt[i-1];
	
	if (keys<>'') 
	  then sh:=Trimme(BIOS_GetIniString(sects,keys,values),3)
	  else sh:='';
  
  	if (sh<>'') then
  	begin
	  for i:=1 to Length(arr) do 
	  begin
	  	if Str2Num(CSV_Item(sh,i),j) then
	  	begin
	      if (arr[i-1]<>j) then 
	      begin
		  	chg:=true;
		  	arr[i-1]:=j;
		  end;
	  	end;
	  end;
  	end;
  
// 	if chg then LOG_Writeln(LOG_WARNING,'RemMAP['+keys+']: '+sh);

  except
	LOG_Writeln(LOG_ERROR,'RemMAP['+keys+']: '+values);
  end;
  ReMAParrFL:=chg;
end;

function  ReMAParrLI(var arr,adflt:Array of longint; sects,keys,values:string):boolean;
var chg:boolean; i,j:integer; sh:string;
begin
  chg:=false;
  try
	for i:=1 to Length(arr) do arr[i-1]:=adflt[i-1];
	
	if (keys<>'') 
	  then sh:=Trimme(BIOS_GetIniString(sects,keys,values),3)
	  else sh:='';
  
  	if (sh<>'') then
  	begin
	  for i:=1 to Length(arr) do 
	  begin
	  	if Str2Num(CSV_Item(sh,i),j) then
	  	begin
	      if (arr[i-1]<>j) then 
	      begin
		  	chg:=true;
		  	arr[i-1]:=j;
		  end;
	  	end;
	  end;
  	end;
  
// 	if chg then LOG_Writeln(LOG_WARNING,'RemMAP['+keys+']: '+sh);

  except
	LOG_Writeln(LOG_ERROR,'RemMAP['+keys+']: '+values);
  end;
  ReMAParrLI:=chg;
end;

function  ReMAParrLW(var arr,adflt:Array of longword; sects,keys,values:string):boolean;
var chg:boolean; i,j:integer; sh:string;
begin
  chg:=false;
  try
	for i:=1 to Length(arr) do arr[i-1]:=adflt[i-1];
	
	if (keys<>'') 
	  then sh:=Trimme(BIOS_GetIniString(sects,keys,values),3)
	  else sh:='';
  
  	if (sh<>'') then
  	begin
	  for i:=1 to Length(arr) do 
	  begin
	  	if Str2Num(CSV_Item(sh,i),j) then
	  	begin
	      if (arr[i-1]<>j) then 
	      begin
		  	chg:=true;
		  	arr[i-1]:=j;
		  end;
	  	end;
	  end;
  	end;
  
//  if chg then LOG_Writeln(LOG_WARNING,'RemMAP['+keys+']: '+sh);

  except
	LOG_Writeln(LOG_ERROR,'RemMAP['+keys+']: '+values);
  end;
  ReMAParrLW:=chg;
end;

function  Str2Bool(s:string; var ein:boolean):boolean;
var ok:boolean;
begin
  ok:=false;
  if Pos(Upper(s),yes_c) >0 then begin ok:=true; ein:=true;  end;
  if Pos(Upper(s),nein_c)>0 then begin ok:=true; ein:=false; end;
  Str2Bool:=ok;
end;
function  Str2Bool(s:string):boolean; begin Str2Bool:=(Pos(Upper(s),yes_c)>0); end;

function  Bool2Num(b:boolean) : byte;		 begin if b then Bool2Num:=1		else Bool2Num:=0;		 end;
function  Bool2Dig(b:boolean) : string; 	 begin if b then Bool2Dig:='1'		else Bool2Dig:='0';      end;
function  Bool2LVL(b:boolean) : string; 	 begin if b then Bool2LVL:='H'		else Bool2LVL:='L';      end;
function  Bool2Str(b:boolean) : string; 	 begin if b then Bool2Str:='TRUE '	else Bool2Str:='FALSE';  end;
function  Bool2Swc(b:boolean) : string; 	 begin if b then Bool2Swc:='ON '	else Bool2Swc:='OFF';    end;
function  Bool2OC (b:boolean) : string; 	 begin if b then Bool2OC:='OPEN '	else Bool2OC:='CLOSE';   end;
function  Bool2DIR(b:boolean) : string; 	 begin if b then Bool2DIR:='OUT'	else Bool2DIR:='IN ';    end;
function  Bool2YN (b:boolean) : string; 	 begin if b then Bool2YN:='YES'		else Bool2YN:='NO ';     end;
function  Bool2YNS(b:boolean) : string; 	 begin if b then Bool2YNS:='Y'		else Bool2YNS:='N';      end;
function  Bool2PF (b:boolean) : string; 	 begin if b then Bool2PF:='PASS'	else Bool2PF:='FAIL';    end;
function  Bool2EA (b:boolean) : string; 	 begin if b then Bool2EA:='ENABLED 'else Bool2EA:='DISABLED';end;
function  Bool2eas(b:boolean) : string; 	 begin if b then Bool2eas:='enable 'else Bool2eas:='disable';end;
function  Bool2UpDown(b:boolean):string; 	 begin if b then Bool2UpDown:='up  'else Bool2UpDown:='down';end;

function  Trend2Ch(num:longint):char; 
var ch:char; 
begin if (num<0) then ch:='-' else if (num>0) then ch:='+' else ch:=' '; Trend2Ch:=ch; end;

function  Num2Str(num:real;lgt,nk:integer):string;  
var _lgt:integer; s:string; 
begin 
  if not IsNaN(num) then
  begin
	if (nk<0) then
  	begin
      str(num:lgt:15,s);
      s:=adjT0(s);	// strip off trailing 0
  	end else str(num:lgt:nk,s);
  end 
  else 
  begin
    if (lgt>0) then _lgt:=lgt else _lgt:=abs(nk)+2;
	s:=Get_FixedStringLen('NaN',_lgt,false);
  end;
  Num2Str:=s; 
end;

function  Num2Str(num:int64;lgt:byte):string;    var s:string; begin str(num:lgt,s); Num2Str:=s; end;
function  Num2Str(num:longint;lgt:byte):string;  var s:string; begin str(num:lgt,s); Num2Str:=s; end;
function  Num2Str(num:qword;lgt:byte):string; 	 var s:string; begin str(num:lgt,s); Num2Str:=s; end;
function  Num2Str(num:longword;lgt:byte):string; var s:string; begin str(num:lgt,s); Num2Str:=s; end;
function  Num2Str(num:int64):string;   		begin Num2Str:=Num2Str(num,0); end;
function  Num2Str(num:longint):string; 		begin Num2Str:=Num2Str(num,0); end;
function  Num2Str(num:longword):string;		begin Num2Str:=Num2Str(num,0); end;
function  Num2Str(num:real;nk:byte):string;	begin Num2Str:=Num2Str(num,0,nk); end;
function  Num2Bool(num:int64):boolean; begin Num2Bool:=(num>=0); end;
function  Num2Bool(num:real):boolean;  begin Num2Bool:=(num>=0); end;

function  Num2DtyStr(dty:real):string;
var dcs:string;
begin
  if (dty>0) and (dty<1)
	then dcs:=Num2Str((dty*100),2,0)+'%'
	else dcs:=Bool2Swc((dty>0));
  Num2DtyStr:=dcs;
end;

function  Str2Num(s:string; var num:byte):boolean;     var code:integer; begin val(StringReplace(s,'$','0x',[rfReplaceAll,rfIgnoreCase]),num,code); Str2Num:=(code=0); end;
function  Str2Num(s:string; var num:smallint):boolean; var code:integer; begin val(StringReplace(s,'$','0x',[rfReplaceAll,rfIgnoreCase]),num,code); Str2Num:=(code=0); end;
function  Str2Num(s:string; var num:int64):boolean;    var code:integer; begin val(StringReplace(s,'$','0x',[rfReplaceAll,rfIgnoreCase]),num,code); Str2Num:=(code=0); end;
function  Str2Num(s:string; var num:qword):boolean;    var code:integer; begin val(StringReplace(s,'$','0x',[rfReplaceAll,rfIgnoreCase]),num,code); Str2Num:=(code=0); end;
function  Str2Num(s:string; var num:longint):boolean;  var code:integer; begin val(StringReplace(s,'$','0x',[rfReplaceAll,rfIgnoreCase]),num,code); Str2Num:=(code=0); end;
function  Str2Num(s:string; var num:longword):boolean; var code:integer; begin val(StringReplace(s,'$','0x',[rfReplaceAll,rfIgnoreCase]),num,code); Str2Num:=(code=0); end;

function  Str2Num(s:string; var num:single):boolean;     
var code:integer; i64:int64; sh:string;
begin 
  sh:=StringReplace(s,'$','0x',[rfReplaceAll,rfIgnoreCase]);
  val(sh,num,code);
  if (code<>0) and Str2Num(sh,i64) then begin num:=i64; code:=0; end; 
  Str2Num:=(code=0); 
end;
function  Str2Num(s:string; var num:real):boolean;     
var code:integer; i64:int64; sh:string;
begin 
  sh:=StringReplace(s,'$','0x',[rfReplaceAll,rfIgnoreCase]);
  val(sh,num,code);
  if (code<>0) and Str2Num(sh,i64) then begin num:=i64; code:=0; end; 
  Str2Num:=(code=0); 
end;
function  Str2Num(s:string; var num:extended):boolean; 
var code:integer; r:real;
begin
  val(s,num,code); 
  if (code<>0) and Str2Num(s,r) then begin num:=r; code:=0; end;
  Str2Num:=(code=0); 
end;

procedure Str2Num(s:string; var num:byte; dflt:byte);  			begin if not Str2Num(s,num) then num:=dflt; end;
procedure Str2Num(s:string; var num:smallint; dflt:smallint);	begin if not Str2Num(s,num) then num:=dflt; end;
procedure Str2Num(s:string; var num:int64; dflt:int64);			begin if not Str2Num(s,num) then num:=dflt; end;
procedure Str2Num(s:string; var num:qword; dflt:qword);			begin if not Str2Num(s,num) then num:=dflt; end;
procedure Str2Num(s:string; var num:longint; dflt:longint);		begin if not Str2Num(s,num) then num:=dflt; end;
procedure Str2Num(s:string; var num:longword; dflt:longword);	begin if not Str2Num(s,num) then num:=dflt; end;
procedure Str2Num(s:string; var num:single; dflt:single);		begin if not Str2Num(s,num) then num:=dflt; end;
procedure Str2Num(s:string; var num:real; dflt:real);			begin if not Str2Num(s,num) then num:=dflt; end;
procedure Str2Num(s:string; var num:extended; dflt:extended);	begin if not Str2Num(s,num) then num:=dflt; end;

function  Str2NumFMT(s:string; nk:byte):string;
var r:real; i:integer; sh:string;
begin
  if not Str2Num(s,r) then 
  begin
	sh:='';
	if (nk>0) then 
	  begin for i:=1 to nk do sh:=sh+'_'; sh:='.'+sh; end;
	sh:='_'+sh;
  end else sh:=Num2Str(r,nk);
  Str2NumFMT:=sh;
end;
function  Num2StrFMT(num:real;nk:byte):string;
var sh:string;
begin 
  if not IsNaN(num) 
	then sh:=Num2Str(num,0,nk)
  	else sh:=Str2NumFMT(' ',nk);
  Num2StrFMT:=sh;
end;

function  Str2CP437(s:string):string;
var sh:string;
begin
  sh:=StringReplace(s ,'€',#$8e,[rfReplaceAll]); 
  sh:=StringReplace(sh,'…',#$99,[rfReplaceAll]); 
  sh:=StringReplace(sh,'†',#$9a,[rfReplaceAll]); 
  sh:=StringReplace(sh,'Š',#$84,[rfReplaceAll]); 
  sh:=StringReplace(sh,'š',#$94,[rfReplaceAll]); 
  sh:=StringReplace(sh,'Ÿ',#$81,[rfReplaceAll]); 
  sh:=StringReplace(sh,'§',#$e1,[rfReplaceAll]); 
  sh:=StringReplace(sh,'¤',#$15,[rfReplaceAll]);  
  Str2CP437:=sh;
end;

(*function StringReverse(s:string):string;
// ReverseString
var i : integer; sh:string;  
begin 
  sh:='';
  for i := Length(s) downto 1 do sh:=sh+s[i];  
  StringReverse:=sh;
end; *)

function  Str2TimeSpec(s:string; var ts:timespec):boolean;
var c1,c2:integer; 
begin 
  val(CSV_Item(s,'.',1),ts.tv_sec, c1); 
  val(CSV_Item(s,'.',2),ts.tv_nsec,c2); 
LOG_Writeln(LOG_ERROR,'Str2TimeSpec: '+s);
  Str2TimeSpec:=((c1=0) and (c2=0));
end;

function  Get_SameCharString(cnt:longint;c:char):string; var l:longint; s:string; begin s:=''; for l:=1 to cnt do s:=s+c; Get_SameCharString:=s; end;
//function  Hex   (nr:qword;lgt:byte) : string; begin Hex:=Format('%0:-*.*x',[lgt,lgt,nr]); end;
//{$warnings off} function  Hex   (ptr:pointer;lgt:byte): string; begin Hex:=Hex(qword(ptr),lgt); end; {$warnings on}
function  HexStr(s:shortstring):string;overload; var sh:string; i:longint; begin sh:=''; for i := 1 to Length(s) do sh:=sh+HexStr(ord(s[i]),2); HexStr:=sh; end;
function  HexStr(s:string):string;overload; var sh:string; i:longint; begin sh:=''; for i := 1 to Length(s) do sh:=sh+HexStr(ord(s[i]),2); HexStr:=sh; end;
function  LeadingZero(w:word):string; begin LeadingZero:=Format('%0:-*.*d',[2,2,w]); end;
//function  Get_FixedStringLen(s:string;cnt:word;leading:boolean):string; var fmt:string; begin fmt:='%0:'; if not leading then fmt:=fmt+'-'; fmt:=fmt+'*.*s'; Get_FixedStringLen:=Format(fmt,[cnt,cnt,s]); end;
function  Get_FixedStringLen(s:string;cnt:word;leading:boolean):string; var fmt:string; begin if leading then fmt:='%' else fmt:='%-'; fmt:=fmt+Num2Str(cnt,0)+'s'; Get_FixedStringLen:=Format(fmt,[s]); end;
//function  Upper(const s : string) : String; var sh : String; i:word; begin sh:=''; for i:= 1 to Length(s) do sh:=sh+Upcase(s[i]);   Upper:=sh; end;
//function  Lower(const s : string) : String; var sh : String; i:word; begin sh:=''; for i:= 1 to Length(s) do sh:=sh+LowerCase(s[i]);Lower:=sh; end;
function  Upper(const s:string):string; begin Upper:=UpCase(s); end;
function  Lower(const s:string):string; begin Lower:=LowerCase(s); end;

function  CharPrintable(c:char):string; begin if ord(c)<$20 then CharPrintable:=#$5e+char(ord(c) xor $40) else CharPrintable:=c; end;
function  StringPrintable(s:string):string; var sh : string; i : longint; begin sh:=''; for i:=1 to Length(s) do sh:=sh+CharPrintable(s[i]); StringPrintable:=sh; end;

function  URLencode(s:string):string; 
var sh:string; i:longint; 
begin 
  sh:=''; 
  for i:=1 to Length(s) do 
  begin
    case s[i] of
      #$00..'/',
      ':'..'@',
      '['..'`',
      '{'..#$7f: 	sh:=sh+'%'+HexStr(ord(s[i]),2);
      else 			sh:=sh+s[i];
    end; // case 
  end;
  URLencode:=sh;
end;

function  URLdecode(s:string):string; 
var sh,sh1:string; b:byte; i,j:longint; 
begin 
  sh:='';
  j:=Length(s);
  i:=1;
  while (i<=j) do
  begin
    if ((s[i]='%') and (i<=(j-2))) then
    begin
      sh1:=copy(s,i+1,2);
      if not Str2Num('0x'+sh1,b) then
      begin
    	LOG_Writeln(LOG_ERROR,'URLdecode['+Num2Str(i,0)+']: invalid encode %'+sh1);
    	sh:=sh+'%'+sh1;
      end else sh:=sh+char(b);
      inc(i,2);
    end 
    else 
    begin
      if (s[i]='+') 
      	then sh:=sh+' '
      	else sh:=sh+s[i];
    end;
    inc(i);
  end;
  URLdecode:=sh;
end;

procedure ShowStringList(StrList:TStringList); var n:longint; begin for n:= 1 to StrList.Count do writeln(StrList[n-1]); end;
function  AdjZahlDE(r:real;lgt,nk:byte):string; var s:string; begin s:=StringReplace(Num2Str(r,lgt,nk),'.',',',[]); AdjZahlDE:=s; end;
function  AdjZahl(s:string):string;
var hs:string; n,pkt,com:integer; DEformat:boolean; r:real;
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
  if not Str2Num(hs,r) then hs:='';
  AdjZahl:=hs;
end;

function  QW2Str(qw:qword):string;
var lgt:word; sh:string;
begin
  case qw of
  		     0..$0000000000ff:	lgt:= 2;
  		  $100..$00000000ffff:	lgt:= 4;
  		$10000..$0000ffffffff:	lgt:= 8;
  	$100000000..$ffffffffffff:	lgt:=12;
	else 						lgt:=16;
  end;
  sh:=HexStr(qw,lgt);
  QW2Str:=sh;
end;

procedure IPInfo_Init(intface:string; var IPInfo:IP_Info_t);
begin
  with IPInfo do
  begin  
    iface:=intface;		alias:=iface;		timestamp:=now;
	ip4addr:=noip_c;	ip6addr:=noip_c;	gwaddr:=noip_c;	nsaddr:=noip_c;	
  	domain:='';			hwaddr:='';			link:='';	
  	ssid:='';			DNSname:='';
  	signal_link:='';	signal_level:='';	signal_quality:='';
  	stat:=false;		wireless:=false;	chan:=''; 			freq:='';
  end; // with
end;

procedure IPInfos_Init(var IPInfos:IP_Infos_t);
begin
  with IPInfos do
  begin
  	init:=false; 			hostname:=''; 		idx:=0;
  	init1:=false;			samesubnet:=false;	
  	devlst:=''; 		 	hostapd_extdev:=	ifeth_c;
  	ip4ext1:=noip_c;		ip4ext2:=noip_c;	ip4ext:= noip_c;		
	IPInfo_Init(ifwlan_c,	IP_Info[0]);
	IPInfo_Init(ifeth_c,	IP_Info[1]);
	IPInfo_Init(ifuap_c,	IP_Info[2]);
  end; // with
end;

procedure IPInfo_Show(lvl:T_ErrorLevel; var IPInfo:IP_Info_t);
begin
  with IPInfo do
  begin
	if (iface<>'') then
	begin
	  SAY(lvl,alias+' Link:    '+link);
      SAY(lvl,'iface:        '+iface);
      SAY(lvl,'wireless:     '+Bool2YNS(wireless));
      SAY(lvl,'stat:         '+Bool2Str(stat));
	  SAY(lvl,'inet:         '+ip4addr);
	  SAY(lvl,'inet6:        '+ip6addr);
	  SAY(lvl,'ether:        '+hwaddr);
	  SAY(lvl,'default via:  '+gwaddr);
	  SAY(lvl,'nameserver:   '+nsaddr);
	  SAY(lvl,'domain:       '+domain);
	  SAY(lvl,'DNSname:      '+DNSname);
	  if wireless then
	  begin
	  	SAY(lvl,'SSID:         '+ssid);
	  	SAY(lvl,'Channel:      '+chan);
	  	SAY(lvl,'Freq:         '+freq);
	  	SAY(lvl,'Signal link:  '+signal_link);
	  	SAY(lvl,'Signal level: '+signal_level);
	  	SAY(lvl,'Signal qual:  '+signal_quality);
	  end;
	end;
  end; // with
end;

procedure IPInfos_Show(lvl:T_ErrorLevel; var IPInfos:IP_Infos_t);
var i:longint;
begin
  with IPInfos do
  begin
    LOG_Writeln(lvl,'################################################');
	LOG_Writeln(lvl,'idx:'+Num2Str(idx,0)+' init:'+Bool2YNS(init)+' samesubnet:'+Bool2YNS(samesubnet)+' hostname:'+hostname);
	LOG_Writeln(lvl,'devlst: '+devlst);
	LOG_Writeln(lvl,'ip4ext: '+ip4ext+' ip4ext1:'+ip4ext1+' ip4ext2:'+ip4ext2);
	LOG_Writeln(lvl,'hostapd_extdev: '+hostapd_extdev);
  	for i:= 0 to IP_infomax_c do 
  	begin
  	  LOG_Writeln(lvl,Num2Str(i,2)+' #############################################');
  	  IPInfo_Show(lvl,IP_Info[i]);
  	end;
  	LOG_Writeln(lvl,'################################################');
  end; // with
end;

procedure IPInfo_GetOS(var IPInfo:IP_Info_t);
// idee: echo inet `ip a show wlan0 | grep -Po 'inet \K[\d.]+'`
// ip -f inet addr show wlan0 | grep -Po 'inet \K[\d.]+'
// IN: eth0 or wlan0
// eth: enx???????? wlan: wlx????????
// https://www.hpl.hp.com/personal/Jean_Tourrilhes/Linux/Linux.Wireless.Extensions.html
  procedure xx(srch,istr:string; nr:longint; var ostr:string);
  begin 
    if 	(Pos(srch,istr)>0) and ((ostr='') or (ostr=noip_c)) then 
	  ostr:=CSV_Item(istr,' ',nr);
  end;
var res,sig:integer; n:longint; _tl:TStringList; sh,sh1:string;
begin
//LOG_Writeln(LOG_WARNING,'  IPInfo_GetOS+');
  _tl:=TStringList.create;   // echo wlan0 Link: `cat /sys/class/net/wlan0/carrier`
  with IPInfo do
  begin
    IPInfo_Init(iface,IPInfo);
    
    sh:=sudo+'ip a show '+iface+' ; '+
  		 	 'echo '+iface+' Link: `cat /sys/class/net/'+iface+'/carrier` ; ';
  	wireless:=((Pos('wlan',lower(iface))>0) or (Pos('wlx',lower(iface))>0));
  	if wireless then
  	begin
	sh:=sh+	'echo SSID: `iwgetid -r` ; '+
			'echo Chan: `iwgetid -c | awk -F '':'' ''{print $2}''` ; '+
			'echo Freq: `iwgetid -f | awk -F '':'' ''{print $2}''` ; '+
			'echo Signal: `cat /proc/net/wireless | tail -1 | awk ''{print $3","$4}''` ; ';
//  	 wlan0: 0000   60.  -50.  -256        0      0      0     32      0        0
  	end;
  	sh:=sh+	'ip route show ; '+
  			'cat /etc/resolv.conf';
  	res:=call_external_prog(LOG_NONE,sh,_tl); 
//	SAY_TL(LOG_WARNING,_tl);	
  	if (res=0) then
  	begin
      for n:= 1 to _tl.count do
      begin
	  	sh:=Trimme(_tl[n-1],4);	// remove all unnecessary spaces
//		writeln(sh);
		xx('inet ',			sh,2,ip4addr);
		xx('inet6 ',		sh,2,ip6addr);
		xx('ether ',		sh,2,hwaddr);
		xx('default via ',	sh,3,gwaddr);
		xx('nameserver ',	sh,2,nsaddr);
		xx('domain ',		sh,2,domain);
		xx(iface+' Link:',	sh,3,link);
		xx('SSID: ',		sh,2,ssid);
		if wireless then 
		begin
		  if (Pos('Freq: ',sh)>0) then 
      	  begin
      	 	freq:=			Trimme(Select_RightItems(sh,' ','',2),3);
      	  end;
		  if (Pos('Chan: ',sh)>0) then 
      	  begin
      	 	chan:=			Trimme(Select_RightItems(sh,' ','',2),3);
      	  end;
      	  if (Pos('Signal: ',sh)>0) then 
      	  begin
    	  	sh1:=			Trimme(Select_RightItems(sh,' ','',2),3);
		  	signal_link:=	CSV_Item(sh1,1);
		  	signal_level:=	CSV_Item(sh1,2);
    	  	if (signal_link='') or (signal_link='tus') then 
    	  	begin
    	  	  signal_link:=none_c; signal_level:=none_c; signal_quality:=nodata_c;
    	  	end
    		else 
    		begin 
    		  signal_link:= GetNumChar2(signal_link)+'%';
    		  signal_level:=GetNumChar2(signal_level);  
    		  if not Str2Num(signal_level,sig) then sig:=999;
  			  case sig of
 			     -64..  0:	signal_quality:='excellent';	// 66 - 100 %
			     -69..-65:	signal_quality:='very good';	// 59 -	 65
 			     -89..-70:	signal_quality:='acceptable';	// 30 -  58
  			  	-110..-90:	signal_quality:='very poor';	//  0 -  29  
    			else		signal_quality:= nodata_c;
  			  end; // case
  			  signal_level:=signal_level+' dBm';  
    		end;
//    		writeln(sh,' sh1:',sh1,':',signal_link,':',signal_level,':',signal_quality);
      	  end;
      	end;
      end; // for
  	end else LOG_Writeln(LOG_ERROR,'GetIPInfos: '+Num2Str(res,0));
  	
  	link:=Upper(Bool2UpDown(link='1'));
  	
  	_tl.free;
  	stat:=((Upper(link)='UP') and (ip4addr<>noip_c));
  	if stat then DNSname:=LNX_ResolveIP2name(CSV_Item(ip4addr,'/',1));

//GetIPInfos[wlan0]: MAC:b8:27:eb:d9:a6:01 IP4:10.8.81.135/24 IP6:noIPAdr GW:10.8.81.1 DNS:10.8.81.1 Domain:muo.basis.biz ext:188.192.178.135
(*  sh:='GetIPInfos['+alias+'/'+iface+']: MAC:'+hwaddr+
		' IP4:'+ip4addr+' IP6:'+ip6addr+' GW:'+gwaddr+
		' DNS:'+nsaddr+' Domain:'+domain+
		' dnsname:'+DNSname+' wireless:'+Bool2Str(wireless); *)
//	if stat then SAY(LOG_INFO,sh) else SAY(LOG_WARNING,sh);
//	IPInfoShow(LOG_INFO,IPInfo);

  end; // with
//LOG_Writeln(LOG_WARNING,'  IPInfo_GetOS-');
end;

function  TH_IPInfo_GetOS(ptr:pointer):ptrint;
//function  TH_IPInfo_GetOS(var IPInfos:IP_Infos_t):ptrint;
var ok:boolean; n,i1,i2,_idx:longint; devnam:string;
begin
//LOG_Writeln(LOG_WARNING,'start TH_IPInfo_GetOS');
  Thread_SetName('IPInfo_GetOS');  
  ok:=false;
  with IP_Infos_ptr(ptr)^ do
  begin	  
    hostname:=GetHostNameOS;
//	LOG_Writeln(LOG_WARNING,'IPInfo_GetOS#1');
 
    if (call_external_prog(LOG_NONE,'ls -1r /sys/class/net/',devlst)<>0) then devlst:='';
//	LOG_Writeln(LOG_WARNING,'IPInfo_GetOS#2');
    devlst:=StringReplace(devlst,LineEnding,',',[rfReplaceAll]);	// wlan0,lo,eth0,ap0 
// 	writeln('devlist:',devlst,':');
	for n:= 1 to CSV_Count(devlst) do 
	begin
	  devnam:=CSV_Item(devlst,n);	// e.g. wlan0 or wlx?????
	  _idx:=-1;
	  if (Pos('wlan0',devnam)>0) or (Pos('wlx',devnam)>0)	then _idx:=IP_infoWLAN0idx_c;
	  if (Pos('wlan1',devnam)>0) 							then _idx:=IP_infoWLAN1idx_c;
	  if (Pos('eth',  devnam)>0) or (Pos('enx',devnam)>0)	then _idx:=IP_infoETH0idx_c;
	  if (devnam=ifuap_c)									then _idx:=IP_infoUAP0idx_c; // IP_infomax_c

	  if (_idx>=0) and (_idx<=IP_infomax_c) then
	  begin
	    IP_Info[_idx].iface:=devnam;
		IPInfo_GetOS(IP_Info[_idx]);
//		if (IP_Info[_idx].iface=ifuap_c) then IP_Info[_idx].ssid:='';		  
		if not ok then 
		begin // only once
		  if IP_Info[_idx].stat then 
		  begin
			ok:=true;
			idx:=_idx;
		  end;
		end;
// IPInfoShow(LOG_INFO,IP_Info[_idx]);
	  end; // else LOG_Writeln(LOG_ERROR,'IPInfo_GetOS: wrong idx '+Num2Str(_idx,0));
	end; // for
	  
    samesubnet:=false;
//	LOG_Writeln(LOG_WARNING,'IPInfo_GetOS#3');
	hostapd_extdev:=ifeth_c;
	if (not IP_Info[IP_infoETH0idx_c].stat) then
	begin
	  if IP_Info[IP_infoWLAN0idx_c].stat then hostapd_extdev:=IP_Info[IP_infoWLAN0idx_c].iface; // wlan0
	  if IP_Info[IP_infoWLAN1idx_c].stat then hostapd_extdev:=IP_Info[IP_infoWLAN1idx_c].iface; // wlan1
	end else 				  				  hostapd_extdev:=IP_Info[IP_infoETH0idx_c ].iface; // eth0
	
(*	for n:= 1 to 2 do
	begin
	  if not samesubnet then 
		samesubnet:=
		  ((IP_Info[n-1].ip4addr<>noip_c) and (IP_Info[n].ip4addr<>noip_c) and 
	  	    IP4AddrsInSameSubnet(IP_Info[n-1].ip4addr,IP_Info[n].ip4addr));
	end; *)

	i1:=IPInfo_GetIdx(ifeth_c); i2:=IPInfo_GetIdx(ifwlan_c);
	samesubnet:=
	  	((IP_Info[i1].ip4addr<>noip_c) and (IP_Info[i2].ip4addr<>noip_c) and 
		  IP4AddrsInSameSubnet(IP_Info[i1].ip4addr,IP_Info[i2].ip4addr));
//writeln('idx:',idx,' samesubnet:',samesubnet);	  
	  
	init1:=true;

//	https://unix.stackexchange.com/questions/22615/how-can-i-get-my-external-ip-address-in-a-shell-script
//	if (call_external_prog(LOG_NONE,'dig @resolver1.opendns.com ANY myip.opendns.com -4 +short',ip4ext)<>0) then ip4ext:=noip_c;

//	LOG_Writeln(LOG_WARNING,'IPInfo_GetOS#4');
    if (call_external_prog(LOG_NONE,'dig txt o-o.myaddr.test.l.google.com @ns1.google.com +short -4',ip4ext1)=0) then 
    begin
	  ip4ext1:=StringReplace(ip4ext1,'"','',[rfReplaceAll]);	
      if (ip4ext1='') 		then ip4ext1:=noip_c; 
    end else ip4ext1:=noip_c;
    ip4ext:=ip4ext1;	

//	LOG_Writeln(LOG_WARNING,'IPInfo_GetOS#5');
//	curl -s http://whatismyip.akamai.com/	
	if (ip4ext<>noip_c) then
	begin
	  if (call_external_prog(LOG_NONE,'curl -s http://whatismyip.akamai.com/',ip4ext2)=0) then 
      begin
      	ip4ext2:=StringReplace(ip4ext2,'"','',[rfReplaceAll]);	
      	if (ip4ext2='') 		then ip4ext2:=noip_c;
      	if (ip4ext2<>noip_c)	then ip4ext:=ip4ext2; 
      end else ip4ext2:=noip_c;
    end;
	  
//	LOG_Writeln(LOG_WARNING,'IPInfo_GetOS#9');
	init:=true;
  end; // with
  
//LOG_Writeln(LOG_WARNING,'end  TH_IPInfo_GetOS');
  EndThread;  
  TH_IPInfo_GetOS:=0;
end;

procedure  IPInfo_GetOS(var IPInfos:IP_Infos_t);
begin
//LOG_Writeln(LOG_WARNING,'IPInfo_GetOS+');
  with IPInfos do
  begin
    if not init then 	// access HW
    begin
	  BeginThread(@TH_IPInfo_GetOS,@IPInfos); // get infos async
	end; // if
  end; // with
//LOG_Writeln(LOG_WARNING,'IPInfo_GetOS-');
end;

procedure IPInfo_GetOS; 
begin 
  IP_Infos.init1:=false;	
  IP_Infos.init:= false;		// force OS read
  IPInfo_GetOS(IP_Infos); 
end; 

function  IPInfo_Wait:boolean;
var _idx:longint;
begin
  _idx:=0;
  while ((_idx<100) and (not IP_Infos.init)) do
  begin
	delay_msec(10);
	inc(_idx);
  end;
//LOG_Writeln(LOG_ERROR,'delay:'+Num2Str(_idx*10,0)+'ms');
  IPInfo_Wait:=IP_Infos.init;
end;

function  IPInfo_Wait1:boolean;
var _idx:longint;
begin
  _idx:=0;
  while ((_idx<100) and (not IP_Infos.init1)) do
  begin
	delay_msec(10);
	inc(_idx);
  end;
//LOG_Writeln(LOG_ERROR,'delay:'+Num2Str(_idx*10,0)+'ms');
  IPInfo_Wait1:=IP_Infos.init1;
end;

procedure IPInfo_Test;
var i:longint;
begin
  IPInfo_GetOS;
  for i:= 1 to 30 do
  begin
    delay_msec(1000);
    IPInfos_Show(LOG_WARNING, IP_Infos);
  end;
end;

function  IPInfo_GetInterfaceName(intidx:longint):string;
var sh:string;
begin
  case intidx of
	IP_infoWLAN0idx_c: 	sh:=ifwlan_c;
	IP_infoWLAN1idx_c: 	sh:=ifwlan1_c;
	IP_infoETH0idx_c: 	sh:=ifeth_c;
	IP_infoUAP0idx_c: 	sh:=ifuap_c;
	else sh:='';
  end; // case
  IPInfo_GetInterfaceName:=sh;
end;

function  IPInfo_GetIdx(intface:string):longint;
var n,_idx:longint;
begin
  _idx:=IP_infoWLAN0idx_c;
  for n:= 0 to IP_infomax_c do
  begin
    with IP_Infos.IP_Info[n] do
  	begin
  	  if (iface=intface) or (alias=intface) then _idx:=n;
  	end; // with
  end;
  IPInfo_GetIdx:=_idx;
end;

function  IPInfo_GetWLANSignal(iface:string):longint; 	// 999,0-100
// 999: not avail // 0-100%
var _sig:longint;
begin
  _sig:=999;
  with IP_Infos.IP_Info[IPInfo_GetIdx(iface)] do
  begin
	if wireless then 
	  if not Str2Num(GetNumChar2(signal_link),_sig) then _sig:=999;
  end; // with
  IPInfo_GetWLANSignal:=_sig;
end;

function  IPInfo_GetWLANSigDB(iface:string):longint; 	// 999,-100..0
// 999: not avail // -100...0db
var _sig:longint;
begin
  _sig:=999;
  with IP_Infos.IP_Info[IPInfo_GetIdx(iface)] do
  begin
	if wireless then 
	  if not Str2Num(GetNumChar2(signal_level),_sig) then _sig:=999;
  end; // with
  IPInfo_GetWLANSigDB:=_sig;
end;

function  IPInfo_iface(aliasname:string):string;
// IN: wlan0 OUT: wlan0 or wlxxxxxxx
begin IPInfo_iface:=IP_Infos.IP_Info[IPInfo_GetIdx(aliasname)].iface; end;

function  IPInfo_Addr4(iface:string):string;
begin IPInfo_Addr4:=IP_Infos.IP_Info[IPInfo_GetIdx(iface)].ip4addr; end;

function  IPInfo_Addr6(iface:string):string;
begin IPInfo_Addr6:=IP_Infos.IP_Info[IPInfo_GetIdx(iface)].ip6addr; end;

function  IPInfo_GetIPAdr(iface:string; var ipaddr:string; ip4:boolean):boolean;
begin
  if ip4 then ipaddr:=IPInfo_Addr4(iface) else ipaddr:=IPInfo_Addr6(iface);
  IPInfo_GetIPAdr:=((ipaddr<>'') and (ipaddr<>noip_c));
end;

function  IPInfo_GetMACAdr(iface:string; var hwaddr:string):boolean;
begin
  hwaddr:=IP_Infos.IP_Info[IPInfo_GetIdx(iface)].hwaddr; 
  IPInfo_GetMACAdr:=(hwaddr<>'');
end;

function IPInfo_MACAddr(iface:string; fmt:byte):string;
// formats mac addr of given 'iface'. If not avail, cpu snr is used
var n:longint; sh:string;
begin 
  sh:=GetHexChar(IP_Infos.IP_Info[IPInfo_GetIdx(iface)].hwaddr);
  if (Length(sh)<12) then sh:=Trimme(cpu_snr,4);
  case fmt of
    1..12: 	begin // use trailing chars
      		  n:=Length(sh); 
      		  if (n>=fmt) then sh:=copy(sh,n-fmt+1,fmt) else sh:='';
      		end;
  end; // case
  IPInfo_MACAddr:=sh;  
end;

function  IPInfo_AddrExt(ip4:boolean):string;
begin IPInfo_AddrExt:=IP_Infos.ip4ext; end;

function  IPInfo_IsOnline(ip4:boolean):boolean;
begin IPInfo_IsOnline:=(IPInfo_AddrExt(ip4)<>noip_c); end;

function  IPInfo_GetDomainName(iface:string):string;
begin IPInfo_GetDomainName:=IP_Infos.IP_Info[IPInfo_GetIdx(iface)].domain; end;

function  IPInfo_GetDomainName:string;
var sh:string;
begin
  with IP_Infos do
  begin
    if (idx>=0) and (idx<=IP_infomax_c) 
      then sh:=IP_Infos.IP_Info[idx].domain 
      else sh:='';
  end; // with
  IPInfo_GetDomainName:=sh;
end;

function  IPInfo_GetMainDomainName:string;
var n:longint; domain:string;
begin
  domain:=IPInfo_GetDomainName;	// def.ghi.com
  n:=Anz_Item(domain,'.','');
  if (n>=2) then domain:=Select_RightItems(domain,'.','',(n-1)); // ghi.com
  IPInfo_GetMainDomainName:=domain;
end;

function  IPInfo_GetHostName:string;
// 20210729 renamed from GetHostName. conflicting unix unit 
begin IPInfo_GetHostName:=IP_Infos.hostname; end;

function  GetHostNameOS:string;
var computer:string; {$IFDEF Win32}c:array[0..127] of Char; sz:dword;{$ENDIF}
begin
  computer:='';
  {$IFDEF Win32} sz:=SizeOf(c); GetComputerName(c,sz); computer:=c;
  {$ELSE} computer:=unix.GetHostName; {$ENDIF}
  GetHostNameOS:=computer;
end;

function  RPI_cxt_GPIOopts(flgs:s_port_flags):string;
// https://www.raspberrypi.org/documentation/configuration/config-txt/gpio.md
var cmd:string;
begin
  cmd:=''; 
  if (OUTPUT		IN flgs) then flgs:=flgs-[INPUT]; 
  if (PullUP		IN flgs) then flgs:=flgs-[PullDOWN]; 
	
  if ((flgs*[INPUT,OUTPUT,ALT5,ALT4,ALT3,ALT2,ALT1,ALT0])=[])
	then flgs:=flgs+[INPUT]; 

  if (INPUT			IN flgs) then cmd:=cmd+'ip,';
  if (OUTPUT		IN flgs) then cmd:=cmd+'op,';
  if (ALT5			IN flgs) then cmd:=cmd+'a5,';
  if (ALT4			IN flgs) then cmd:=cmd+'a4,';
  if (ALT3			IN flgs) then cmd:=cmd+'a3,';
  if (ALT2			IN flgs) then cmd:=cmd+'a2,';
  if (ALT1			IN flgs) then cmd:=cmd+'a1,';
  if (ALT0			IN flgs) then cmd:=cmd+'a0,';
  if (NOpull 		IN flgs) then begin flgs:=flgs-[PullUP,PullDOWN]; cmd:=cmd+'np,'; end;
  if (PullUP		IN flgs) then cmd:=cmd+'pu,';
  if (PullDOWN		IN flgs) then cmd:=cmd+'pd,';

  if (OUTPUT		IN flgs) then 
	if (InitialHIGH IN flgs) then cmd:=cmd+'dh,' else cmd:=cmd+'dl,';

  RPI_cxt_GPIOopts:=CSV_RemLastSep(cmd);
end;

function  RPI_PWRCtrl(flags:s_PWRflags):integer;
(* 	https://raspberrypi.stackexchange.com/questions/43285/raspberry-pi-3-vs-pi-2-power-consumption-and-heat-dissipation
	When shutting down the HDMI and USB on the Pi3, the current drops to 160 milliAmps. In my tests, this was roughly 200 milliAmps on the Pi2. 
	Thus, shutting down hardware (if you don't need it), can be a huge energy saver.
	Update: Use this command to turn HDMI off: /opt/vc/bin/tvservice -o And this command to turn it on: /opt/vc/bin/tvservice -p
	Use this command to turn USB off entirely: echo 0x0 > /sys/devices/platform/soc/3f980000.usb/buspower 
	and this to turn it on: echo 0x1 > /sys/devices/platform/soc/3f980000.usb/buspower *)
var _res:integer; _off:boolean; _flg:t_PWRflags; _cmd,sh:string;
begin
  _res:=-1;
  if (PWR_OFF IN flags) then _off:=true else _off:=false;
  for _flg IN flags do 
  begin
	_cmd:='';
	case _flg of
	  PWR_HDMI:	begin
	  			  _cmd:='/opt/vc/bin/tvservice ';
	  			  if _off then _cmd:=_cmd+'-o' else _cmd:=_cmd+'-p';
				end;
// todo USB bus power	
	end;
	if (_cmd<>'') then _res:=call_external_prog(LOG_NONE,_cmd,sh); 
  end; // for
  RPI_PWRCtrl:=_res;
end;

function  RPI_config(raspicmd:t_RPI_config; par1,par2:string; var resultstring:string):integer; 
// https://github.com/l10n-tw/rc_gui/blob/master/src/rc_gui.c
// 0 is in general success / yes / selected, 1 is failed / no / not selected
var res:integer; sh:string;
begin
  res:=0;
  sh:=sudo+'raspi-config nonint ';
  case raspicmd of
	GET_CAN_EXPAND:	sh:=sh+'get_can_expand';
	EXPAND_FS:		sh:=sh+'do_expand_rootfs';
	GET_HOSTNAME:	sh:=sh+'get_hostname';
	SET_HOSTNAME:	sh:=sh+'do_hostname '+par1;
	GET_BOOT_CLI:	sh:=sh+'get_boot_cli';
	GET_AUTOLOGIN:	sh:=sh+'get_autologin';
	SET_BOOT_CLI:	sh:=sh+'do_boot_behaviour B1';
	SET_BOOT_CLIA:	sh:=sh+'do_boot_behaviour B2';
	SET_BOOT_GUI:	sh:=sh+'do_boot_behaviour B3';
	SET_BOOT_GUIA:	sh:=sh+'do_boot_behaviour B4';
	GET_BOOT_WAIT:	sh:=sh+'get_boot_wait';
	SET_BOOT_WAIT:	sh:=sh+'do_boot_wait '+par1;
	GET_SPLASH:		sh:=sh+'get_boot_splash';
	SET_SPLASH:		sh:=sh+'do_boot_splash '+par1;
	GET_OVERSCAN:	sh:=sh+'get_overscan';
	SET_OVERSCAN:	sh:=sh+'do_overscan '+par1;
	GET_PIXDUB:		sh:=sh+'get_pixdub';
	SET_PIXDUB:		sh:=sh+'do_pixdub '+par1;
	GET_CAMERA:		sh:=sh+'get_camera';
	SET_CAMERA:		sh:=sh+'do_camera '+par1;
	GET_SSH:		sh:=sh+'get_ssh';
	SET_SSH:		sh:=sh+'do_ssh '+par1;
	GET_VNC:		sh:=sh+'get_vnc';
	SET_VNC:		sh:=sh+'do_vnc '+par1;
	GET_SPI:		sh:=sh+'get_spi';
	SET_SPI:		sh:=sh+'do_spi '+par1;
	GET_I2C:		sh:=sh+'get_i2c';
	SET_I2C:		sh:=sh+'do_i2c '+par1;
	GET_SERIAL:		sh:=sh+'get_serial';
	GET_SERIALHW:	sh:=sh+'get_serial_hw';
	SET_SERIAL:		sh:=sh+'do_serial '+par1;
	GET_1WIRE:		sh:=sh+'get_onewire';
	SET_1WIRE:		sh:=sh+'do_onewire '+par1;
	GET_RGPIO:		sh:=sh+'get_rgpio';
	SET_RGPIO:		sh:=sh+'do_rgpio '+par1;
	GET_PI_TYPE:	sh:=sh+'get_pi_type';
	GET_OVERCLOCK:	sh:=sh+'get_config_var arm_freq /boot/config.txt';
	SET_OVERCLOCK:	sh:=sh+'do_overclock '+par1;
	GET_GPU_MEM:	sh:=sh+'get_config_var gpu_mem /boot/config.txt';
	GET_GPU_MEM_256:sh:=sh+'get_config_var gpu_mem_256 /boot/config.txt';
	GET_GPU_MEM_512:sh:=sh+'get_config_var gpu_mem_512 /boot/config.txt';
	GET_GPU_MEM_1K:	sh:=sh+'get_config_var gpu_mem_1024 /boot/config.txt';
	SET_GPU_MEM:	sh:=sh+'do_memory_split '+par1;
	GET_HDMI_GROUP:	sh:=sh+'get_config_var hdmi_group /boot/config.txt';
	GET_HDMI_MODE:	sh:=sh+'get_config_var hdmi_mode /boot/config.txt';
	SET_HDMI_GP_MOD:sh:=sh+'do_resolution '+par1+' '+par2;
	GET_WIFI_CTRY:	sh:=sh+'get_wifi_country';
	SET_WIFI_CTRY:	sh:=sh+'do_wifi_country '+par1;
	WLAN_INTERFACES:sh:=sh+'list_wlan_interfaces';
	else 			res:=1;
  end; // case
  if (res=0) then res:=call_external_prog(LOG_NONE,sh,resultstring);
//LOG_Writeln(LOG_WARNING,sh+': ('+Num2Str(res,0)+') '+resultstring);
  RPI_config:=res;
end;

function  RPI_WLANavailChan(cntry:string):string;
const _2Ghz='1|2|3|4|5|6|7|8|9|10|11|12|13|';
	  _5Ghz='36|40|44|48|52|56|60|64|100|104|108|112|116|120|124|128|132|136|140|';
var sh:string;
begin
  sh:='';
  case RPI_bType of
  	8,$0a,$0c:	sh:=_2GHz;
	$0d:		sh:=_2GHz+_5GHz;
  end; // case
  RPI_WLANavailChan:=CSV_RemLastSep(sh,'|');
end;

function  MAC_isRPI(macsubstr:string):boolean;
begin
  macsubstr:=FilterChar(upper(macsubstr),'0123456789abcdefABCDEF');
  MAC_isRPI:=( (Pos('B827EB',macsubstr)=1) or (Pos('DCA632',macsubstr)=1) );
end;

function  IP4AddrValid(ipstr:string):boolean;
// e.g. 192.168.1.2/32
const cnt_c=4;
var ok:boolean; n,anz,li:longint; sh,sh1,sh2:string; 
begin
  ok:=false;
  sh1:=CSV_Item(ipstr,'/',1); 	// 192.168.1.2
  sh2:=CSV_Item(ipstr,'/',2); 	// 24
  sh:=FilterChar(sh1,'0123456789.');// filter all valid 
  if (sh=sh1) then
  begin
	anz:=Anz_Item(sh,'.','');
	if (anz=cnt_c) then
	begin
	  ok:=true;
	  for n:= 1 to cnt_c do
	  begin
	    if Str2Num(CSV_Item(sh,'.',n),li) then 
	    begin
	      if ((li<0) or (li>$ff)) then ok:=false;
	    end else ok:=false;
	  end;
	end;
	if (ok and (sh2<>'')) then
	begin // chk netmask
	  if Str2Num(sh2,li) then
	  begin
	    if (li<8) or (li>32) then ok:=false;
	  end else ok:=false;
	end;
  end;
  IP4AddrValid:=ok;
end;

function  IP4AddrListValid(ipliststr:string):boolean;
// e.g. 192.168.1.0/24,10.8.12.34,10.8.12.56
// check for IPTables
var ok:boolean; n:longint; sh:string;
begin
  ok:=true;
  for n:=1 to Anz_Item(ipliststr,',','') do
  begin
    sh:=CSV_Item(ipliststr,n);
	if not IP4AddrValid(sh) then 
	begin
	  ok:=false;
//	  LOG_Writeln(LOG_ERROR,'IP4AddrListValid: '+sh+' no valid entry in list '+ipliststr);
	end;
  end;
  IP4AddrListValid:=ok;
end;

function  IP6AddrValid(ipstr:string):boolean;
// e.g. 2001:0db8:85a3:08d3:1319:8a2e:0370:7344/48
const cnt_c=8;
var ok:boolean; n,anz,li:longint; sh,sh1,sh2:string; 
begin
  ok:=false;
  sh1:=CSV_Item(ipstr,'/',1); 	// 2001:0db8:85a3:08d3:1319:8a2e:0370:7344
  sh2:=CSV_Item(ipstr,'/',2); 	// 48
  sh:=FilterChar(sh1,'0123456789abcdefABCDEF:');	// filter all valid 
  if (sh=sh1) then
  begin
	anz:=CSV_Count(sh,'.');
	if (anz=cnt_c) then
	begin
	  ok:=true;
	  for n:= 1 to cnt_c do
	  begin
	    if Str2Num(CSV_Item(sh,':',n),li) then 
	    begin
	      if ((li<0) or (li>$ffff)) then ok:=false;
	    end else begin if (sh<>'') then ok:=false; end;
	  end;
	end;
	if (ok and (sh2<>'')) then
	begin // chk netmask
	  if Str2Num(sh2,li) then
	  begin
	    if (li<16) or (li>128) then ok:=false;
	  end else ok:=false;
	end;
  end;
  IP6AddrValid:=ok;
end;

function  IP6AddrListValid(ipliststr:string):boolean;
// e.g. 2001:0db8:85a3:08d3:1319:8a2e:0370:7344/48,2001:0db8:85a3:08d3:1319:8a2e:0370:7345
var ok:boolean; n:longint; sh:string;
begin
  ok:=true;
  for n:=1 to CSV_Count(ipliststr) do
  begin
    sh:=CSV_Item(ipliststr,n);
	if not IP6AddrValid(sh) then 
	begin
	  ok:=false;
//	  LOG_Writeln(LOG_ERROR,'IP6AddrListValid: '+sh+' no valid entry in list '+ipliststr);
	end;
  end;
  IP6AddrListValid:=ok;
end;

function  IPAddrListValid(ipliststr:string):boolean;
// e.g. 2001:0db8:85a3:08d3:1319:8a2e:0370:7344/48,2001:0db8:85a3:08d3:1319:8a2e:0370:7345
var ok:boolean; n:longint; sh:string;
begin
  ok:=true;
  for n:=1 to CSV_Count(ipliststr) do
  begin
    sh:=CSV_Item(ipliststr,n);
	if not (IP4AddrValid(sh) or IP6AddrValid(sh)) then 
	begin
	  ok:=false;
//	  LOG_Writeln(LOG_ERROR,'IPAddrListValid: '+sh+' no valid entry in list '+ipliststr);
	end;
  end;
//writeln('IPAddrListValid:',ipliststr,':',ok);
  IPAddrListValid:=ok;
end;

function  IP4AddrsInSameSubnet(ip4adr1,ip4adr2:string):boolean;
// ip4adr1:	192.168.1.172
// ip4adr2:	192.168.1.0/24
// valid:	/8 /16 /24 /32
var _ok:boolean; subm:longint; ipn1,ipn2:string;
begin
  _ok:=false;
  if IP4AddrValid(ip4adr1) and IP4AddrValid(ip4adr2) then
  begin
    if not 	 Str2Num(CSV_Item(ip4adr2,'/',2),subm) then 
	  if not Str2Num(CSV_Item(ip4adr1,'/',2),subm) then subm:=24;

    subm:=round(subm/8);
    
	ipn2:=CSV_Item(ip4adr2,'/',1); 	// 192.168.1.0
	ipn2:=Select_LeftItems(ipn2,'.','',subm); 	// 192.168.1
	
    ipn1:= CSV_Item(ip4adr1,'/',1); 	// 192.168.1.172
    ipn1:= Select_LeftItems(ipn1,'.','',subm); 	// 192.168.1
    
    _ok:=(ipn1=ipn2);
  end;
  IP4AddrsInSameSubnet:=_ok;
end;

function  ShortStrng(fmt,maxlgt,divdr:longint; str:string):string;
const shrtA='..'; shrtE='\u2026'; // horizontalEllipsis
var li1,li2:longint; sh:string;
begin
  if (Length(str)>maxlgt) then
  begin
    if (divdr<2) then fmt:=1; // avoid div 0
    case fmt of
        0:	sh:=str;	// no shorting  
        3:	begin		// break string in 2 parts, break defined by 'divdr' e.g. 3
       		  li1:=((maxlgt-Length(shrtA)) div divdr)*(divdr-1); li2:=maxlgt-li1-Length(shrtA);
       		  sh:=copy(str,1,li1)+shrtA+copy(str,(Length(str)+1-li2),li2);
//writeln('origstr:',str); writeln('shorted:',sh);
       		 end;
        2:	sh:=shrtA+copy(str,Length(str)-maxlgt+1+Length(shrtA),maxlgt);	// cut left
	    4:	sh:=copy(str,1,(maxlgt-Length(shrtA)))+shrtA;					// cut right

       30:	begin // Ellipsis: break string in 2 parts, break defined by 'divdr' e.g. 3
       		  li1:=((maxlgt-1) div divdr)*(divdr-1); li2:=maxlgt-li1-1;
       		  sh:=copy(str,1,li1)+shrtE+copy(str,(Length(str)+1-li2),li2);
//writeln('origstr:',str); writeln('shorted:',sh);      
      		end;
       20:	sh:=shrtE+copy(str,Length(str)-maxlgt+1+1,maxlgt);				// cut left
       40:	sh:=copy(str,1,(maxlgt-1))+shrtE;								// cut right
      else	sh:=ShortStrng(40,maxlgt,divdr,str);
    end;
  end else sh:=str;
  ShortStrng:=sh;
end;

function  Num2Limit(var Value:real; MinOut,MaxOut:real):boolean;
var valold:real;
begin 
  valold:=Value;
  if Value<MinOut then Value:=MinOut 
  				  else if Value>MaxOut then Value:=MaxOut; 
  Num2Limit:=(Value<>valold);
end;

function  FormatFileSize(const Size: Int64):string;
var fSize:real; sh,Fmt,Units:string;
begin
  Fmt:='%.1f%s';
  if (Size>=(1 shl 20)) then 
  begin // Mb
    if (Size>=(1 shl 30)) then 
    begin // Gb
      if (Size>=(1 shl 40)) then 
      begin // Tb
        fSize:=Size*(1/(1 shl 40));
        Units:='Tb';
      end else
      begin
        fSize:=Size*(1/(1 shl 30));
        Units:='Gb';
      end;
    end else
    begin
      fSize:=Size*(1/(1 shl 20));
      Units:='Mb';
    end;
  end else
  if (Size>=(1 shl 10)) then 
  begin //kb
    fSize:=Size*(1/(1 shl 10));
    Units:='kb';
  end else 
  begin
    fSize:=Size;
    Units:=' b';
    Fmt:='%.0f%s';
  end;
  FmtStr(sh,Fmt,[fSize,Units]);
  FormatFileSize:=sh;
end;

function  FormatNumSize(const Size:real):string;
var nSize:real; sh,Fmt,Units:string;
begin
  Fmt:='%.1f%s';
  if (Size>=1000000) then 
  begin // Million
	if (Size>=1000000000) then 
	begin // Milliarde
	  if (Size>=1000000000000) then 
	  begin // Billion
		nSize:=Size/1000000000000;
		Units:='T';
	  end else
	  begin
		nSize:=Size/1000000000;
		Units:='G';
	  end;
	end else
	begin
	  nSize:=Size/1000000;
	  Units:='M';	
	end
  end else
  if (Size>=1000) then 
  begin //k
    nSize:=Size/1000;
    Units:='k';
  end else 
  begin
	nSize:=Size;
	Units:='';
	if (Size>=1.0) or IsZero(Size) 
	  then Fmt:='%.0f%s'
	  else Fmt:='%.3f%s';
  end;
  FmtStr(sh,Fmt,[nSize,Units]);
  FormatNumSize:=sh;  
end;

function  KEYpressedChar(lvl:T_ErrorLevel; msg:string; ch:char):boolean;
var _keypr:boolean;
begin
  if KeyPressed then _keypr:=(ReadKey=ch) else _keypr:=false;
  if (_keypr and (msg<>'')) then LOG_Writeln(lvl,msg); 
  KEYpressedChar:=_keypr;
end;
function KEYpressedChar(ch:char):boolean;
begin KEYpressedChar:=KEYpressedChar(LOG_WARNING,'',ch); end;

function ESCpressed:boolean; begin ESCpressed:=KEYpressedChar(ESC); end;

procedure AskCR(lvl:T_ErrorLevel; msg:string); begin writeln; write(msg+'<CR>'); readln; end;
procedure AskCR(msg:string); begin AskCR(LOG_INFO,msg); end;
procedure AskCR; begin AskCR(''); end;
function  AskStr(msg:string; var outstr:string):boolean;
begin
  write('enter '+msg+' (<string> or <CR> for exit): '); readln(outstr);
  AskStr:=(outstr<>'');
end;
function  AskYN(msg:string; dflt:string):boolean;
const yn_c='y/n';
var outchar,sh:string;
begin
  sh:=yn_c; dflt:=Upper(dflt);
  if dflt='N' then sh:='y/N'; if dflt='Y' then sh:='Y/n';
  repeat
    write('enter '+msg+' ('+sh+'): '); readln(outchar); outchar:=Upper(outchar);
    if (outchar='') and (sh<>yn_c) then outchar:=dflt;
  until ((outchar='Y') or (outchar='N'));
  AskYN:=(outchar='Y');
end;

function  AskNum(von,bis:longint; msg:string; var outnum:longint):boolean;
var _ok:boolean; sh:string;
begin
  repeat
    write('enter '+msg+' (',von:0,'-',bis:0,' or -1 for exit): '); readln(sh);
    _ok:=Str2Num(sh,outnum);
    _ok:=( _ok and (((outnum>=von) and (outnum<=bis)) or (outnum=-1)));
  until _ok;
  AskNum:=(outnum<>-1);
end;

function  AskNumNoExit(von,bis:longint; msg:string; var outnum:longint):boolean;
var _ok:boolean; sh:string;
begin
  repeat
    write('enter '+msg+' (',von:0,'-',bis:0,'): '); readln(sh);
    _ok:=Str2Num(sh,outnum);
    _ok:=( _ok and (((outnum>=von) and (outnum<=bis))));
  until _ok;
  AskNumNoExit:=_ok;
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

function  UnicodeStr2UTF8(unicodestr:string):string;
// unicodestr: 'H\u2082O' -> H2O (subscript 2)
var anz,n:longint; lw:longword; _str,sh:string;
begin
  sh:=''; _str:=unicodestr;	// H\u2082O
  anz:=Anz_Item(_str,'\u','');
  for n:= 1 to anz do
  begin
	sh:=sh+Select_Item(_str,'\u','','',1);			// H
	_str:=Select_RightItems(unicodestr,'\u','',n+1);	// 2082O subscript2 O
	if (Length(_str)>=4) then
	begin
	  if not Str2Num('$'+copy(_str,1,4),lw) then lw:=0; 
	  sh:=sh+UTF8Encode(WideChar(lw));
	  _str:=copy(_str,5,Length(_str));					// O
	end;
  end;
//writeln(sh+' '+HexStr(sh));
  UnicodeStr2UTF8:=sh;
end;

function  scale(x,dflt,in_min,in_max,out_min,out_max:real):real;
var y,r:real;
begin
  try
	if (x <> in_max) then
	begin
	  r:=(in_max - in_min);
	  if (r<>0)
		then y:=(x - in_min) * (out_max - out_min) / r + out_min
		else y:=dflt;
	end else y:=out_max;
  except
    y:=dflt;
//	LOG_Writeln(LOG_ERROR,'ScaleR: wrong value pairs');
  end;
  scale:=y;
end;
function  scale(x,in_min,in_max,out_min,out_max:real):real;
begin scale:=scale(x,x,in_min,in_max,out_min,out_max); end;

function  scale(x,dflt,in_min,in_max,out_min,out_max:longint):longint;
var y:longint;
begin
  try
	if (x = in_max) 
	  then y:=out_max
	  else  if (out_min < out_max)
			  then y:=(x - in_min) * (out_max - out_min+1) div (in_max - in_min) + out_min
			  else y:=(x - in_min) * (out_max - out_min-1) div (in_max - in_min) + out_min;
  except
	y:=dflt;
//	LOG_Writeln(LOG_ERROR,'ScaleI: wrong value pairs');
  end;
  scale:=y;
end;
function  scale(x,in_min,in_max,out_min,out_max:longint):longint;
begin scale:=scale(x,x,in_min,in_max,out_min,out_max); end;

function  scale(x,dflt,in_min,in_max,out_min,out_max:int64):int64;
var y:longint;
begin
  try
	if (x = in_max) 
	  then y:=out_max
	  else  if (out_min < out_max)
			  then y:=(x - in_min) * (out_max - out_min+1) div (in_max - in_min) + out_min
			  else y:=(x - in_min) * (out_max - out_min-1) div (in_max - in_min) + out_min;
  except
	y:=dflt;
//	LOG_Writeln(LOG_ERROR,'ScaleI64: wrong value pairs');
  end;
  scale:=y;
end;
function  scale(x,in_min,in_max,out_min,out_max:int64):int64;
begin scale:=scale(x,x,in_min,in_max,out_min,out_max); end;
  
function  DIST_Init(var struct:Distribution_t; ArrSize:word; fmin,fmax:real):boolean;
var _ok:boolean; _li:longint;
begin
  _ok:=false;
  try
	with struct do
	begin
	  if (Length(range)=0) then
	  begin
	  	siz:=ArrSize+2;	// + below-vmin above-vmax
	  	if (siz<=2) then inc(siz);
	 	SetLength(range,siz);		 	
	  	if (fmin<=fmax) 
		  then begin vmin:=fmin; vmax:=fmax; end
		  else begin vmin:=fmax; vmax:=fmin; end;
	  	step:=(vmax-vmin)/(siz-2);
	  	cnt:=0;
	  	_ok:=(Length(range)=siz);
	  	if _ok then 
		  for _li:=0 to (siz-1) do range[_li]:=0;
	  end else LOG_Writeln(LOG_ERROR,'DIST_Init: already inited');
	end; /// with
  except
	LOG_Writeln(LOG_ERROR,'DIST_Init');
  end;
  DIST_Init:=_ok;
end;

procedure DIST_End(var struct:Distribution_t);
begin 
  try
	with struct do
	begin
	  siz:=0;
  	  SetLength(range,0); 
  	end; // with
  except
	LOG_Writeln(LOG_ERROR,'DIST_End');
  end;
end; 

function  DIST_Insert(var struct:Distribution_t; valIN:real):longint;
var _idx:longint;
begin
  try
	with struct do
	begin
	  if (valIN<vmin) then _idx:=0
		else
		  if (valIN>vmax) 
			then _idx:=(siz-1)
			else _idx:=round(scale(valIN,vmin,vmax,1,(siz-2)));
//writeln('Insert[',_idx:3,']: ',valIN:8:5);
	  inc(range[_idx]);
	  inc(cnt);
	end; // with
  except
    LOG_Writeln(LOG_ERROR,'DIST_Insert['+Num2Str(_idx,0)+']: '+Num2Str(valIN,0,5));
    _idx:=-1;
  end;
  DIST_Insert:=_idx;
end;

procedure DIST_Show(var struct:Distribution_t; hdr,lbl:string; lvl,lcol:T_ErrorLevel);
var _idx:longint; r:real; sh:string;
begin
  with struct do
  begin  	
    if (hdr<>'') then SAY(lvl,lcol,hdr); // writeln(hdr);
    if (Length(range)>0) then
    begin
	  r:=vmin;
//	  sh:='rng: '+Num2Str(vmin,DIST_wid_c,1)+'<';
	  sh:='rng: '+Get_FixedStringLen(FormatNumSize(vmin),DIST_wid_c,true)+'<'; 
      for _idx:= 1 to (siz-2) do 
      begin
	  	r:=r + step; 
//	  	sh:=sh+Num2Str(r,DIST_wid_c,1)+' '; 
	  	sh:=sh+Get_FixedStringLen(FormatNumSize(r),DIST_wid_c,true)+' '; 
	  end;
      sh:=sh+'  rng> '+lbl;	 
//    writeln(sh);
      SAY(lvl,lcol,sh);

      sh:='cnt: ';
	  for _idx:= 0 to (siz-1) do 
	  	sh:=sh+Get_FixedStringLen(FormatNumSize(range[_idx]),DIST_wid_c,true)+' '; 
//	  writeln(sh);
	  SAY(lvl,lcol,sh);
	
	  sh:='dist:';
      for _idx:= 0 to (siz-1) do sh:=sh+Num2Str(range[_idx]/cnt*100,DIST_wid_c,1)+' ';
//    writeln(sh+'%');
  	  SAY(lvl,lcol,sh+'%');
  	end;
  end; // with 
end;

procedure DIST_Test;
// show value distribution: <2.0 [-2.0 ... +2.0] >2.0 // use 2 buckets inside + 2 for below/above
var dist:DISTribution_t;
begin
  if DIST_Init(dist,2,-2.0,2.0) then
  begin
    DIST_Insert	(dist,-2.0001);
    DIST_Insert	(dist,-2);
    DIST_Insert	(dist,-2);
    DIST_Insert	(dist,-2);
    DIST_Insert	(dist, 2);
    DIST_Insert	(dist, 2);
    DIST_Insert	(dist, 2);
    DIST_Insert	(dist, 2.0001);
	DIST_Insert	(dist,-1.9999);
	DIST_Insert	(dist, 0);
	DIST_Insert	(dist, 1.9999);
    DIST_Show	(dist,'value distribution','',LOG_WARNING,LOG_MAGENTA);
    DIST_End	(dist)
  end else writeln('can not init');
end;

function  LeadingZeros(l:longint;digits:byte):string;
var s1,s2:string; i:byte; 
begin
  s1:=''; for i := 1 to digits do s1:=s1+'0'; Str(l:0,s2); s1:=s1+s2; 
  LeadingZeros:=copy(s1,Length(s1)-digits+1,255); 
end;

function  ISdir(filname:string):boolean;
begin ISdir:=((FileGetAttr(PrepFilePath(filname)) and faDirectory)<>0); end;

function  MKdir(dirname:string; mode:word):integer; 
var res:integer; cmd:string;
begin
  res:=-1;
  if (dirname<>'') then
  begin
	if (not DirectoryExists(dirname)) then
	begin
	  cmd:='mkdir'; 
	  if ((mode and $01)<>0) then cmd:=cmd+' -p';
	  cmd:=cmd+' '+PrepFilePath(dirname);
	  if ((mode and $02)<>0) then cmd:=cmd+' > /dev/null 2>&1';
	  res:=call_external_prog(LOG_NONE,cmd);
	end;
  end;
  MKdir:=res;
end;

function  SetFileAge(filname:string; mode:integer; fdat:TDateTime):integer;
// mode: 1:modification date / 2:access date / 0: both dates
var res:integer; fn,cmd,sh:string;
begin
  res:=0; fn:=PrepFilePath(filname);
  if FileExists(fn) then 
  begin
	cmd:='touch';
	case mode of
	  1: cmd:=cmd+' -m';
	  2: cmd:=cmd+' -a';
	end; // case
	cmd:=cmd+' -t '+FormatDateTime('YYYYMMDDhhmm',fdat)+' '+fn;
	if not (call_external_prog(LOG_NONE,cmd,sh)=0) then res:=-1;
  end else res:=-1;
  if res<0 then Log_Writeln(Log_ERROR,'SetFileAge: '+cmd);
  SetFileAge:=res;
end;

function  GetFileAge(filname:string):TDateTime;
var fa:longint; fildat:TDateTime; fn:string;
begin
  fildat:=0; fn:=PrepFilePath(filname);
  if FileExists(fn) then 
  begin
    {$I-} 
      fa:=FileAge(fn); 
      if (fa<>-1) then fildat:=FileDateToDateTime(fa); 
    {$I+}
  end;
  GetFileAge:=fildat;
end;

function  GetFileSize(filname:string):int64;
var filsiz:int64; f:file; fn:string;
begin
  filsiz:=-1; fn:=PrepFilePath(filname);
  if FileExists(fn) then 
  begin
    {$I-} 
      assign(f,fn); 
      reset (f,1);
	  filsiz:=FileSize(f); 
	  close(f); 
	{$I+}
  end;
  GetFileSize:=filsiz;
end;

function  GetFilePackSize(filelist:string):int64;
var n:longint; res,sum:int64;
begin
  sum:=0;
  for n:=1 to Anz_Item(filelist,',','"') do
  begin
    res:=GetFileSize(Select_Item(filelist,',','"','',n));
    if (res>0) then sum:=sum+res;
  end;
  GetFilePackSize:=sum;
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
  ok:=false;
  if FileExists(filepath) then 
  begin
	tdat:=GetFileAge(filepath); 
	ok:=(SecondsBetween(now,tdat)<=GetRNDsec(seconds_old,varianz));
//	LOG_Writeln(LOG_Warning,Bool2Str(ok)+' Delta: '+Num2Str(DeltaTime_in_min(now,tdat),0)+' min FileDate: '+GetXMLTimeStamp(tdat)+' '+Real2Str(v/60,0,2)+' min');
  end;
  FileIsRecent:=ok;
end;

function  FileIsRecent(filepath:string; seconds_old:longint):boolean;
begin
  FileIsRecent:=FileIsRecent(filepath,seconds_old,0);
end;

function  ContentHasChangedTimeStamp(const hashOld,hashNew:string; timeStampOld,timeStampNew:TDateTime):TDateTime;
var modifyTStamp:TDateTime; _modHash,_modDate:boolean;
begin
  _modHash:=(hashOld<>hashNew); 							// hash has changed
  _modDate:=(timeStampOld<timeStampNew);					// content is new
  
//_modDate:=(CompareDateTime(timeStampOld,timeStampNew)<0); // content is new
//negative number if timeStampOld is earlier than timeStampNew, 
//zero if they are equal, or 
//positive number if timeStampOld is later than timeStampNew.

  				   modifyTStamp:=timeStampOld;
  if _modDate then modifyTStamp:=timeStampNew;
  if _modHash then modifyTStamp:=now;
  
//LOG_Writeln(LOG_WARNING,LOG_MAGENTA,'ContentHasChangedTimeStamp['+Bool2YNS(_modHash or _modDate)+'/'+Bool2YNS(_modHash)+'/'+Bool2YNS(_modDate)+']: Hash old:'+HashTagFMT(hashOld)+' new:'+HashTagFMT(hashNew)+' Dat old:'+DateTime2FMT(8,timeStampOld)+' new:'+DateTime2FMT(8,timeStampNew));
  
  ContentHasChangedTimeStamp:=modifyTStamp;
end;

function  Trimme(s:string; modus:byte):string;
begin
  case modus of
    0:   ;
	1:	 s:=TrimLeftSet( s,[' ']);
	2:	 s:=TrimRightSet(s,[' ']);
	3: 	 s:=TrimRightSet(TrimLeftSet(s,[' ']),[' ']);
	4: 	 s:=TrimRightSet(TrimLeftSet(DelSpace1(s),[' ']),[' ']);
	$09: s:=Trimme(StringReplace(s,#$09,' ',[rfReplaceAll]),4);
	$0a: s:=Trimme(StringReplace(s,#$0a,'', [rfReplaceAll]),4);
	$0d: s:=Trimme(StringReplace(s,#$0d,'', [rfReplaceAll]),4);
	else s:=Trimme(s,$09);
  end;
  Trimme:=s;  
end;

procedure TST_Trimme;
const tst='  xx  '+#$09+'   yy  zz   ';
begin
  writeln(tst,':',Trimme(tst,1),':');
  writeln(tst,':',Trimme(tst,2),':');
  writeln(tst,':',Trimme(tst,3),':');
  writeln(tst,':',Trimme(tst,4),':');
  writeln(tst,':',Trimme(tst,5),':');
end;

function  adjL0(s:string):string;
// 0010.12340000 -> 10.12340000
var exp:string; num:extended; nk:longint;
begin
  if Str2Num(s,num) then
  begin
    s:=Upper(s); exp:='0'; 
	if Pos('.',s)<>0 then begin exp:=CSV_Item(s,'.',2); exp:=Num2Str(Length(exp),0); end;	// preserve accuracy
	if Pos('E',s)<>0 then begin exp:=CSV_Item(s,'E',2); end;
    if Str2Num(exp,nk) then s:=Num2Str(num,0,abs(nk));
  end;
  adjL0:=s;
end;

function  adjT0(s:string):string;
// 0010.12340000 -> 0010.1234
var nk0,dp,i:longint; num:extended;
begin
  try
  	if Str2Num(s,num) then
  	begin
  	  dp:=Pos('.',s);
	  if (dp>0) and (Pos('E',Upper(s))=0) then 
	  begin 
	  	i:=Length(s);
	  	nk0:=i;
	    while (i>dp) do
		begin
		  if (s[i]='0') then 
		  begin
		    nk0:=i;
		  	if (i>(dp+1)) then dec(nk0);
		  end else i:=0;
		  dec(i);
	  	end; // while
	  	s:=copy(s,1,nk0);
 	  end;
  	end;
  except
  end;
  adjT0:=s;
end;

function FilterChar(s,filter:string):string;
// filter all char from 's' which 'filter' contains 
var sh:string; i:longint;
begin 
  if Length(filter)>0 then
  begin
    SetLength(sh,0);
	for i:=1 to Length(s) do
	  if (Pos(s[i],filter)<>0) then sh:=sh+s[i];
  end else sh:=s;
  FilterChar:=sh;
end;

function RemoveChar(s,filter:string):string;
// remove all char from 's' which 'filter' contains 
var sh:string; i:integer;
begin
  if Length(filter)>0 then
  begin
    SetLength(sh,0);
	for i:=1 to Length(s) do 
	  if (Pos(s[i],filter)=0) then sh:=sh+s[i];
  end else sh:=s;
  RemoveChar:=sh;
end;

function GetHexChar(s:string):string;
begin GetHexChar:=FilterChar(s,'0123456789ABCDEFabcdef'); end;

function GetNumChar(s:string):string;
begin GetNumChar:=FilterChar(s,'0123456789'); end;

function GetNumChar2(s:string):string;
begin GetNumChar2:=FilterChar(s,'0123456789-+'); end;

function GetAlphaNumChar(s:string):string;
begin GetAlphaNumChar:=FilterChar(s,'0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz'); end;

function GetParserTokenChar(s:string):string;
begin GetParserTokenChar:=FilterChar(s,'0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz_'); end;

function ContainDescenderLetter(s:string):boolean; // string has char with descender (unterlaenge)
begin ContainDescenderLetter:=(FilterChar(s,'gjpqy§_,;')<>''); end;

function ReplaceChars(s,filterchars,replacechar:string):string;
{.c ersetzt aus string s alle char die in filter angegeben sind mit replacechar }
var sh:string; i:integer;
begin
  sh:=s; 
  for i := 1 to Length(filterchars) do 
	sh:=StringReplace(sh,filterchars[i],replacechar,[rfReplaceAll]);
  ReplaceChars:=sh;
end;

function  RM_LF  (s:string):string; begin RM_LF:=  StringReplace(s,#$0a,'',[rfReplaceAll]); end;
function  RM_CR  (s:string):string; begin RM_CR:=  StringReplace(s,#$0d,'',[rfReplaceAll]); end;
function  RM_CRLF(s:string):string; begin RM_CRLF:=StringReplace(s,#$0d+#$0a,'',[rfReplaceAll]); end;

function  SB_Null(s:string):string; begin SB_Null:=StringReplace(s,'\0',#$00,[rfReplaceAll]); end;
function  SB_Bell(s:string):string; begin SB_Bell:=StringReplace(s,'\a',#$07,[rfReplaceAll]); end;
function  SB_BS  (s:string):string; begin SB_BS:=  StringReplace(s,'\b',#$08,[rfReplaceAll]); end;
function  SB_TAB (s:string):string; begin SB_TAB:= StringReplace(s,'\t',#$09,[rfReplaceAll]); end;
function  SB_LF  (s:string):string; begin SB_LF:=  StringReplace(s,'\n',#$0a,[rfReplaceAll]); end;
function  SB_CR  (s:string):string; begin SB_CR:=  StringReplace(s,'\r',#$0d,[rfReplaceAll]); end;
function  SB_FF  (s:string):string; begin SB_FF:=  StringReplace(s,'\f',#$0c,[rfReplaceAll]); end;
function  SB_ESC (s:string):string; begin SB_ESC:= StringReplace(s,'\e',#$1b,[rfReplaceAll]); end;
function  SB_VT  (s:string):string; begin SB_VT:=  StringReplace(s,'\v',#$0b,[rfReplaceAll]); end;
function  SB_CRLF(s:string):string; begin SB_CRLF:=SB_LF(SB_CR(s)); end;
function SB_UnESC(s:string):string; begin SB_UnESC:= SB_CRLF(SB_FF(SB_TAB(SB_BS(SB_VT(SB_Bell(SB_Null(SB_ESC(s)))))))); end;  

function  BS_Null(s:string):string; begin BS_Null:=StringReplace(s,#$00,'\0',[rfReplaceAll]); end;
function  BS_Bell(s:string):string; begin BS_Bell:=StringReplace(s,#$07,'\a',[rfReplaceAll]); end;
function  BS_BS	 (s:string):string; begin BS_BS:=  StringReplace(s,#$08,'\b',[rfReplaceAll]); end;
function  BS_TAB (s:string):string; begin BS_TAB:= StringReplace(s,#$09,'\t',[rfReplaceAll]); end;
function  BS_LF  (s:string):string; begin BS_LF:=  StringReplace(s,#$0a,'\n',[rfReplaceAll]); end;
function  BS_CR  (s:string):string; begin BS_CR:=  StringReplace(s,#$0d,'\r',[rfReplaceAll]); end;
function  BS_FF  (s:string):string; begin BS_FF:=  StringReplace(s,#$0c,'\f',[rfReplaceAll]); end;
function  BS_ESC (s:string):string; begin BS_ESC:= StringReplace(s,#$1b,'\e',[rfReplaceAll]); end;
function  BS_VT  (s:string):string; begin BS_VT:=  StringReplace(s,#$0b,'\v',[rfReplaceAll]); end;
function  BS_CRLF(s:string):string; begin BS_CRLF:=BS_LF(BS_CR(s)); end;
function BS_DoESC(s:string):string; begin BS_DoESC:= BS_CRLF(BS_FF(BS_TAB(BS_BS(BS_VT(BS_Bell(BS_Null(BS_ESC(s)))))))); end; 

function  BS_HK  (s:string):string; begin BS_HK:=  StringReplace(s,#$27,'\''',[rfReplaceAll]); end;
function  BS_dHK (s:string):string; begin BS_dHK:= StringReplace(s,#$22,'\"',[rfReplaceAll]); end;
function  BS_QM  (s:string):string; begin BS_QM:=  StringReplace(s,#$3f,'\?',[rfReplaceAll]); end;
function  BS_Bsl (s:string):string; begin BS_Bsl:= StringReplace(s,#$5c,'\\',[rfReplaceAll]); end; 
function  BS_ALL (s:string):string; begin BS_ALL:= BS_HK(BS_dHK(BS_QM(BS_DoESC((s))))); end; 
//function  BS_ALL (s:string):string; begin BS_ALL:= BS_Bsl(BS_HK(BS_dHK(BS_QM(BS_DoESC((s)))))); end; 

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

function  HashTagFMT(hash:string):string;
begin
  HashTagFMT:=StringReplace(hash,MD5Hash4emptyString,'<---- MD5Hash4emptyContent ---->',[rfReplaceAll]);
end;

function  HashTag(modus:byte; const filname,InString,comment:string):string;
var hash,sh,fn:string; dt:TDateTime; m:TMemoryStream; f:file of byte; oldfilemode:byte; siz:int64;
begin
  hash:=''; fn:=PrepFilePath(filname);
  case modus of
      1 : begin // MD5 Hash constructed with FileDate;FileSize and a comment string
            dt:=GetFileAge(fn);
            if dt>0 then 
		    begin
              {$I-} assign(f,fn); 
			  oldfilemode:=filemode; filemode:=0; 	// readonly
//writeln('HashTag1');			
			  reset(f,1); 	// hier hŠngt darwin, wenn access privs auf datei nicht stimmen!!!	
//writeln('HashTag2');
			  filemode:=oldfilemode;			  
			  siz:=FileSize(f);		  
			  close(f); {$I+} 
			  sh:=FormatDateTime('yyyy-mm-dd',dt)+'T'+ // YEAR-MM-DDThh:mm:ss.zz
			      FormatDateTime('hh:nn:ss.zz',dt)+';'+
				  Num2Str(siz,0)+';'+Num2Str(modus,0)+';'+InString+';'+comment;
		      hash:=MD5Print(MD5String(sh)); 
		    end
		    else LOG_Writeln(LOG_Error,'HashTag: file does not exist: '+fn);
          end;		  
      2 : begin // MD5 Hash of filecontent
	        m:=TMemoryStream.create;
	        if not File2MStream(fn,m,hash) then 
		    begin hash:=''; LOG_Writeln(LOG_Error,'HashTag: file does not exist: '+fn); end;
		    m.free;
	      end;
	   3: begin // MD5 Hash auf String 'InString'
	        hash:=MD5Print(MD5String(InString)); 
	      end;
	 else LOG_Writeln(LOG_ERROR,'HashTag: wrong modus '+Num2Str(modus,0));
  end; // case
//writeln('HashTag:',hash,':',fn);
  HashTag:=hash;
end;

function  HashTag(const InString:string):string; begin HashTag:=HashTag(3,'',InString,''); end;

procedure FSplit(fullfilename:string; var Directory,FName,Extension:string; extwithdot:boolean);
var anz:integer; ext:string;
begin
  anz:=Anz_Item(fullfilename,dir_sep_c,''); ext:='';
  Directory:=Select_LeftItems (fullfilename,dir_sep_c,'',anz-1); 
  Fname:=    Select_RightItems(fullfilename,dir_sep_c,'',anz); 
  Extension:=Select_Item(Fname,ext_sep_c,'','',Anz_Item(Fname,ext_sep_c,''));
  if (Extension<>'') then ext:=ext_sep_c+Extension;
  Fname:=StringReplace(Fname,ext,'',[rfReplaceAll,rfIgnoreCase]);
  if (Extension<>'') and (extwithdot) then Extension:=ext_sep_c+Extension;
//writeln(fullfilename,'|',directory,'|',fname,'|',extension,'-',dir_sep_c);
end;

function  Get_ExtName(fullfilename:string; extwithdot:boolean):string; 
var fext:string;
begin 
  fext:=ExtractFileExt(fullfilename);
  if not extwithdot then
    if Pos(ext_sep_c,fext)=1 then fext:=copy(fext,2,Length(fext));
  Get_ExtName:=fext; 
end;

function  Get_FName(fullfilename:string; withext:boolean):string; 
var Directory,FName,Extension,sh:string;
begin 
  FSplit(fullfilename,Directory,FName,Extension,true); 
  sh:=Fname; if withext then sh:=sh+Get_ExtName(fullfilename,true);
  Get_FName:=sh; 
end;
function  Get_FName(fullfilename:string):string; begin Get_FName:=Get_FName(fullfilename,false); end;

function  Get_FNameExt(fullfilename:string):string; 
var Directory,FName,Extension : string;
begin FSplit(fullfilename,Directory,FName,Extension,true); Get_FNameExt:=Fname+Extension; end;

function  Get_Dir(fullfilename:string):string; 
var Directory,FName,Extension : string;
begin FSplit(fullfilename,Directory,FName,Extension,true); Get_Dir:=Directory;end;

function  Get_Dirs(fullfilenamelist:string):string; 
var n,anz:longint; sh:string;
begin
  sh:=''; anz:=Anz_Item(fullfilenamelist,',','"');
  for n:= 1 to anz do
  begin
    sh:=sh+Get_Dir(Select_Item(fullfilenamelist,',','"','',n));
    if (n<anz) then sh:=sh+',';
  end;
  Get_Dirs:=sh;
end;

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

function  escSEP(const strng:string):string;
var li,lj:longint; sh:string;
begin
  sh:='';
  for li:=1 to Length(strng) do
  begin
    lj:=0;
    while (lj<=sep_max_c) do
    begin
      if strng[li]=sep[lj] then
      begin
        sh:=sh+esc_char_c;
    	lj:=sep_max_c;
      end;
      inc(lj);
    end; // while
    sh:=sh+strng[li];
  end; // for
  escSEP:=sh;
end;

function  Select_Item(const strng,trenner,trenner2,dflt:string;itemno:longint):string;
//const esc_char_c='\';
var   str,hs,tr1,tr2 : string; bcnt,trcnt : longint; dhk_start,esc_start,xx,ende:boolean;
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
  hs:=''; bcnt:=1; dhk_start:=false; ende:=false; esc_start:=false;
  if Length(strng)>0 then trcnt:=1 else trcnt:=0;
  while (bcnt<=Length(str)) and not ende do
  begin
    if (xx) and ((str[bcnt] = tr2)) and (not esc_start) then dhk_start:= not dhk_start;
    if (str[bcnt]=tr1) and (not dhk_start) then INC(trcnt);
	if (str[bcnt]<>esc_char_c) then esc_start := false;
    if (trcnt=itemno) and ((str[bcnt]<>tr1) or dhk_start) then hs:=hs+str[bcnt];
(* writeln(str[bcnt],' ',bcnt:2,' ',trcnt:2,'    '); *) 
	INC(bcnt);
	if (itemno>0) and (trcnt>itemno) then ende:=true;
  end;
  hs:=StringReplace(hs,tr1,trenner, [rfReplaceAll,rfIgnoreCase]);
  if xx then hs:=StringReplace(hs,tr2,'',      [rfReplaceAll,rfIgnoreCase])
        else hs:=StringReplace(hs,tr2,trenner2,[rfReplaceAll,rfIgnoreCase]);
  if (itemno<=0) then system.Str(trcnt:0,hs);
  if (hs='') then hs:=dflt;
  Select_Item:=hs;
end;

(*function  Select_Item(const strng,trenner,trenner2,dflt:string;itemno:longint):string; 
var sel,trcnt,i:longint; sh:string;
begin
  if ((Length(trenner)=1) and (Length(trenner2)=0)) then sel:=1 else sel:=0;
  case sel of
	1:	begin
		  if (itemno=0) then
		  begin
		    if (Length(strng)>0) then trcnt:=1 else trcnt:=0;
	  	 	for i:= 1 to Length(strng) do
	  	 	  if (strng[i]=trenner[1]) then inc(trcnt);
	  	 	system.Str(trcnt:0,sh);
	  	  end else sh:=ExtractDelimited(itemno,strng,[trenner[1]]); // 10x faster
	  	  if (sh='') then sh:=dflt;
	  	end;
  	else sh:=Select_ItemOLD(strng,trenner,trenner2,dflt,itemno); 
  end; // case
  Select_Item:=sh;
end; *)

function  Select_Item(const strng,trenner,trenner2:string;itemno:longint):string;
begin Select_Item:=Select_Item(strng,trenner,trenner2,'',itemno); end; 

function  Anz_Item(const strng,trenner,trenner2:string): longint;
var anz:longint; 
begin
  if Length(strng)>0 then
  begin if not Str2Num(Select_Item(strng,trenner,trenner2,'',0),anz) then anz:=0; end
  else anz := 0;
  Anz_Item := anz;
end;

function  Select_RightItems(const strng,trenner,trenner2:string;startitemno:longint):string; 
var sh:string; n,m : longint;
begin
  sh:=''; m:=Anz_Item(strng,trenner,trenner2);
  for n := startitemno to m do
  begin
    sh:=sh+Select_Item(strng,trenner,trenner2,'',n);
	if n<m then sh:=sh+trenner;
  end;
  Select_RightItems:=sh;
end;

function  Select_LeftItems(const strng,trenner,trenner2:string;enditemno:longint):string; 
var sh:string; n,m : longint;
begin
  sh:=''; m:=enditemno;
  for n := 1 to m do
  begin
    sh:=sh+Select_Item(strng,trenner,trenner2,'',n);
	if n<m then sh:=sh+trenner;
  end;
  Select_LeftItems := sh;
end;

function  Locate_Value(const strng,search,tr1,tr2,tr3,tr4:string; var valoutstrng:string; flags:s_BIOS_Flags):boolean;
// e.g. strng: SMTP_Server=xxx.yyy.com&SMTP_FromAdr=postmaster@yyy.com&SMTP_ToAdr=admin@yyy.com
// tr1='&' tr2='' tr3='=' tr4='' 
// search='SMTP_FromAdr'
// valoutstrng: postmaster@yyy.com
var _found:boolean; n,anz:longint; sh:string;
begin
  valoutstrng:=''; _found:=false; n:=1; anz:=Anz_Item(strng,tr1,tr2);
  while (n<=anz) and (not _found) do	  
  begin
	sh:=Select_Item(strng,tr1,tr2,'',n);
//	if (Pos(Upper(search),Upper(sh))>0) then 
	if (Pos(Upper(search),Upper(sh))=1) then 
	begin
	  valoutstrng:=Trimme(Select_RightItems(sh,tr3,tr4,2),3);
	  if (BIOS_UnEscUrl IN flags) then valoutstrng:=URLdecode(valoutstrng);
	  _found:=true;
	end;
	inc(n);
  end; // while
  Locate_Value:=_found;
end;

function  SepRemove(s:string):string;
var n:longint; sh:string;
begin
  sh:=s;
  for n:=0 to sep_max_c do sh:=StringReplace(sh,sep[n],' ',[rfReplaceAll,rfIgnoreCase]);
  SepRemove:=sh;
end;

function  StringListMinMaxValue(StrList:TStringList; fieldnr:word; tr1,tr2:string; flgs:s_BIOS_Flags; var min,max:extended; var nk:longint):boolean;
var i:longint; e:extended; b1,b2:boolean; nkh,lgt:integer; sh:string;
begin
  min:=NaN; max:=NaN; b1:=false; b2:=false; nk:=0;
  if StrList.count>0 then
  begin
    min:=maxfloat; max:=MinFloat;	// was maxextended , creates error on ARM (rpi) with FPC 2.6.4 
    for i:= 1 to StrList.count do 
    begin
	  sh:=Select_Item(StrList[i-1],tr1,tr2,'',fieldnr); // 12.3456
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

procedure StringListSnap(StrListIn,StrListOut:TStringList; const srchstrng:string);
var i:longint;
begin
  StrListOut.clear;
  for i:=1 to StrListIn.count do
  begin
    if Pos(srchstrng,StrListIn[i-1])=1 then StrListOut.add(StrListIn[i-1]);
  end;
end;

function  xxxSearchStringInList(StrList:TStringList; const srchstrng:string):string;
var sh:string; n:longint;
begin
  n:=StrList.IndexOf(srchstrng); // not case sensitive !!!!!!
  if (n>=0) then sh:=StrList[n] else sh:='';
  xxxSearchStringInList:=sh;
end;

function  SearchStringInList(StrList:TStringList; const srchstrng:string):string;
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

function  SearchStringInListIdx(StrList:TStringList; const srchstrng:string; occurance,StartIdx:longint):longint;
// return idx, where searchstring occurs to the 'occurance' count. If not then return -1;
// if occurence>0 then search list from 1. to last record
// if occurence<0 then search list from end to 1. record
var n,ret,occhelp : longint; found:boolean; 
begin
  found:=false; ret:=-1; occhelp:=0;
  if occurance>0 then
  begin // von 1-Ende durchsuchen
    n:=StartIdx; 
    if n<0 then n:=0;

    while (n<StrList.Count) and not found do
    begin
      if (Pos(srchstrng,StrList[n])>0) then 
	  begin 
	    inc(occhelp); 
	    if (occhelp=occurance) then 
	    begin 
	      found:=true; 
	      ret:=  n; 
	    end; 
	  end;
      inc(n);  
    end;
    
(*  repeat
	  n:=StrList.IndexOf(srchstrng, n);  // would be nice to have a startidx and case sensitivity
	  if (n>=0) then 
	  begin
		inc(occhelp);
		found:=(occhelp>=occurance);
		if found then ret:=n;
		inc(n);
	  end;
    until (n<0) or found; *)

  end;
  if occurance<0 then
  begin // von Ende-1 durchsuchen
    n:=StartIdx; 
    if (n<=0) or (n>=StrList.Count) then n:=StrList.Count-1; // new 20190709
    while (n>=0) and not found do
    begin
      if (Pos(srchstrng,StrList[n])>0) then 
      begin 
    	inc(occhelp); 
    	if (occhelp=abs(occurance)) then 
    	begin 
    	  found:=true; 
    	  ret:=  n; 
    	end; 
      end;
      dec(n);  
    end;
  end;
  SearchStringInListIdx:=ret;
end;

function  GiveStringListIdx(StrList:TStringList; const srchstrng:string; var idx:longint; occurance,StartIdx:longint):boolean;
var ok:boolean;
begin
  idx:=SearchStringInListIdx(StrList, srchstrng, occurance, StartIdx); 
  if (idx>=0) and (idx<StrList.count) then ok:=true else ok:=false;  
  GiveStringListIdx:=ok;
end;
function  GiveStringListIdx(StrList:TStringList; const srchstrng:string; var idx:longint; occurance:longint):boolean;
var StrtIdx:longint;
begin 
  StrtIdx:=0; if (occurance<0) then StrtIdx:=-1;
  GiveStringListIdx:=GiveStringListIdx(StrList,srchstrng,idx,occurance,StrtIdx); 
end;

function  GiveStringListIdx(StrList:TStringList; const srchstrngSTART,srchstrngEND:string; var idx:longint):boolean;
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

function  GiveStringListIdx2(StrList:TStringList; const srchstrng:string; var idxStart,idxEnd:longint):boolean;
begin
  idxStart:=SearchStringInListIdx(StrList,srchstrng, 1,0);
  idxEnd:=  SearchStringInListIdx(StrList,srchstrng,-1,0);
  GiveStringListIdx2:=((idxStart<=idxEnd) and (idxStart>=0));
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

function  GetRndTmpFileName(filhdr,extname:string):string;
var sh:string;
begin  
  sh:=c_tmpdir+'/'+filhdr+FormatDateTime('YYYYMMDDhhmmss',now)+extname;	// was '/tmp_'  ext: .txt
  GetRndTmpFileName:=PrepFilePath(sh); 
end;

procedure StringSplit(const delim:char; const strng:string; const strings:TStrings);
begin
  Assert(Assigned(Strings));
  strings.Clear;
  strings.StrictDelimiter:=	true;
  strings.Delimiter:= 		delim;
  strings.DelimitedText:=	strng;
end;

procedure String2StringList(str:string; StrList:TStringList);
var _tl:TStringList;
begin
  _tl:=TStringList.create;
  StringSplit(LF,str,_tl);
  StringListAdd2List(StrList,_tl,true);
  _tl.free;
end;

function  StringList2String(StrList:TStringList; tr:string):string;
var li,anz:longint; sh:string;
begin
  if (Length(tr)>0) then
  begin
  	sh:=''; anz:=StrList.count;
  	for li:= 1 to anz do
  	begin
      sh:=sh+StrList[li-1];	
      if (li<anz) then sh:=sh+tr;
  	end;
  end else sh:=StrList.Text;
  StringList2String:=sh;
end;

function  StringList2String(StrList:TStringList):string;
begin StringList2String:=StrList.Text; end;

function  StringList2TextFile(filname:string; StrListOut:TStringList):boolean;
{ Write StringList to TextFile }
var _ok:boolean; fn:string;
begin
  fn:=PrepFilePath(filname);
  try
	_ok:=true;
	StrListOut.SaveToFile(fn);
  except
    _ok:=false;
    LOG_Writeln(LOG_Error,'StringList2TextFile: could not write file '+fn);
  end;
  StringList2TextFile:=_ok;
end;

function  StringList2TextFile(filname,owner,group:string; mode:TMode; StrListOut:TStringList):boolean;
var _ok:boolean; fn:string;
begin
  fn:=PrepFilePath(filname);
  _ok:=StringList2TextFile(fn,StrListOut);
  if _ok then
  begin
    _ok:=(LNX_chowngrpmod(fn,owner,group,mode)=0);
	if not _ok then LOG_Writeln(LOG_ERROR,'StringList2TextFile: can not chown/chmod '+fn);
  end;
  StringList2TextFile:=_ok;
end;

function  StringList2TextFile(filname:string; StrListOut:TStringList; append_mode:boolean):boolean;
var b:boolean; sh,fn,fn2:string;
begin
  b:=true;
  if (StrListOut.count>0) then
  begin
    b:=false; fn:=PrepFilePath(filname); 
    if append_mode and FileExists(fn) then
    begin
      fn2:=GetRndTmpFileName('tmp_','.txt');
      if StringList2TextFile(fn2,StrListOut) then
      begin
    	{$ifdef WINDOWS}sh:='type '+fn2;{$else}sh:='cat '+fn2;{$endif}
	  	sh:=sh+' >> '+fn;
		b:=(call_external_prog(LOG_NONE,sh)=0);
		if not b then LOG_Writeln(LOG_ERROR,'StringList2TextFile, failed: '+sh);
		{$I-} DeleteFile(fn2); {$I+} 
	  end else LOG_Writeln(LOG_ERROR,'StringList2TextFile: '+fn2); 
    end else b:=StringList2TextFile(fn,StrListOut);
  end;
  StringList2TextFile:=b;
end;

function  String2TextFile(filname:string; StrOut:string):boolean;
{ Write String to TextFile }
var _ok:boolean; _tl:TStringList; fn:string;
begin
  fn:=PrepFilePath(filname);
  _tl:=TStringList.create;
  try
  	String2StringList(StrOut,_tl);
	_ok:=true;
	_tl.SaveToFile(fn);
  except
    _ok:=false;
    LOG_Writeln(LOG_Error,'String2TextFile: could not write file '+fn);
  end;
  _tl.free;
  String2TextFile:=_ok;
end;

function  StringListAdd2List(StrList1,StrList2:TStringList; append:boolean):longword; 
//Adds StringList2 to Stringlist1. result is size of Stringlist1 in bytes
var lgt:longword; memStream:TMemoryStream;
begin
  try
	memStream:=TMemoryStream.Create;

	if append then
	begin
	  StrList1.SaveToStream(memStream);
	  StrList2.SaveToStream(memStream); 
	end
	else
	begin
	  StrList2.SaveToStream(memStream);
	  StrList1.SaveToStream(memStream); 
	end;

  	memStream.Seek(0, soFromBeginning);
	StrList1.LoadFromStream(memStream);
	lgt:=Length(StrList1.Text);
  
	memStream.free;
  except
	LOG_Writeln(LOG_ERROR,'StringListAdd2List');
	lgt:=0;
  end;
  StringListAdd2List:=lgt;
end;

function  StringListAdd2List(StrList1,StrList2:TStringList):longword; 
begin StringListAdd2List:=StringListAdd2List(StrList1,StrList2,true); end;

function  TextFile2StringList(const filname:string; StrListOut:TStringList):boolean;
{ Read TextFile into a StringList (also possible from stdin, if filename='' ) }
var ok:boolean; fn:string;
begin
  try
	fn:=PrepFilePath(filname);
  	{$I-} 
  	  ok:=FileExists(fn);
  	  if ok then 
  	  begin
    	StrListOut.LoadFromFile(fn);
//		hash:=MD5Print(MD5String(StrListOut.Text)); // do this outside of this func, if needed
		Log_Writeln(LOG_DEBUG,'Read  from file: '+fn+' lines: '+Num2Str(StrListOut.count,0)); 
	  end; 
  	{$I+}
  except
	ok:=false; 
  end;
  if not ok then LOG_Writeln(LOG_Error,'TextFile2StringList: could not read file '+filname);
  TextFile2StringList:=ok;
end;

function  TextFile2StringList(const filname:string; StrListOut:TStringList; append:boolean):boolean;
var tl:TStringList; ok:boolean; 
begin
  if append then
  begin
    tl:=TStringList.create;
    ok:=TextFile2StringList(filname,tl);
	if ok then StringListAdd2List(StrListOut,tl);
	tl.free;
  end
  else 
  begin
    StrListOut.clear;
    ok:=TextFile2StringList(filname,StrListOut);
  end;
  TextFile2StringList:=ok;
end;

function  TextFileContentCheck(file1,file2:string; mode:byte):boolean;
var ok:boolean; ts1,ts2:TStringList; i:longint;
begin
  ok:=false;
  if FileExists(file1) and FileExists(file2) then
  begin
    ts1:=TStringList.create; ts2:=TStringList.create;
    if TextFile2StringList(file1,ts1) then 
      if TextFile2StringList(file2,ts2) then
	    if (ts1.count=ts2.count) and (ts1.count>0) then
        begin
	      ok:=true;
	      for i:= 1 to ts1.count do 
		  begin 
		    case mode of
		       1 : begin if CSV_Item(ts1[i-1],' ',1)<>CSV_Item(ts2[i-1],' ',1) then ok:=false; end;
		      else begin if ts1[i-1]<>ts2[i-1] then ok:=false; end;
		    end; // case
		  end;
        end;  
    ts1.free; ts2.free;
  end;
  TextFileContentCheck:=ok;
end;

function  TailFile(filname:string; LinesCount:longint):RawByteString;
var S:TStream; Validated,BytesToEnd:longint; rbs:RawByteString;
begin
  rbs:='';
  if FileExists(filname) then
  begin
	S:=TFileStream.Create(filname, fmOpenRead or fmShareDenyNone);
	try
	  S.Seek(0,soEnd);
      Validated:=0;
      while (Validated<LinesCount) and (S.Seek(-2,soCurrent)>=0) do
      begin
		if S.ReadByte=10 then inc(Validated);
      end;
      if Validated<LinesCount then S.Position:=0;
	  BytesToEnd:=S.Size-S.Position;
	  SetLength(rbs,BytesToEnd);
	  S.ReadBuffer(PByte(rbs)[0],BytesToEnd);
	finally
	  S.Free;
	end;
  end; // else LOG_Writeln(LOG_ERROR,'TailFile: does not exist '+filname);
  TailFile:=rbs;
end;

procedure TailFileFollow(filname:string; LinesCount:longint);
var timo:TDateTime; so,s:string;
begin
  s:=''; timo:=now;
  repeat
    so:=s;
    s:=TailFile(filname,LinesCount);
    if (s<>so) then 
    begin
//	  write(s,' 0x',HexStr(s));
	  write(s+#$0d);
	  SetTimeOut(timo,10000);
	end else delay_msec(50);
  until TimeElapsed(timo);
end;

procedure BIOS_EndIniFile; 
// https://github.com/graemeg/freepascal/blob/master/packages/fcl-base/src/inifiles.pp
var res:longint;
begin 
  res:=0;
  with IniFileDesc do 
  begin
    if ok then
    begin
      if inifilbuf.CacheUpdates then 
      begin
    	inifilbuf.CacheUpdates:=false;			// forces UpdateFile, if dirty
    	modifydate:=GetFileAge(inifilename);
      end;
      inifilbuf.free; 
      {$IFNDEF WINDOWS} 
      if FileExists(inifilename) then
      begin
		res:=fpChmod (inifilename,&600);
		if (res<>0) then LOG_Writeln(LOG_ERROR,'BIOS_EndIniFile: can not set perm '+inifilename+' 0x'+HexStr(res,8));
	  end else res:=-1;
	  {$ENDIF}
    end;
    ok:=false;
  end;
end;

function  BIOS_DeleteKey(section,name:string):boolean;
begin 
  with IniFileDesc do 
  begin
	if ok then 
	begin
	  inifilbuf.DeleteKey(section,name); 
	  if (not inifilbuf.CacheUpdates) then modifydate:=GetFileAge(inifilename);
	end;
	BIOS_DeleteKey:=ok; 
  end; 
end;

procedure BIOS_EraseSection(section:string);
begin 
  with IniFileDesc do 
  begin
	if ok then 
	begin
	  inifilbuf.EraseSection(section); 
	  if (not inifilbuf.CacheUpdates) then modifydate:=GetFileAge(inifilename);
	end;
  end; // with
end;

procedure BIOS_CacheUpdate(upd:boolean);
begin with IniFileDesc do if ok then inifilbuf.CacheUpdates:=upd; end;

function  BIOS_CacheUpdate:boolean;
var upd:boolean;
begin
  with IniFileDesc do 
  begin
	if ok then upd:=inifilbuf.CacheUpdates else upd:=false; 
  end;
  BIOS_CacheUpdate:=upd;
end;

function  BIOS_GetIniFilename:string;
begin BIOS_GetIniFilename:=IniFileDesc.inifilename; end;

procedure BIOS_ReadIniFile(fname:string);
// e.g. BIOS_ReadIniFile('/etc/configfile.ini')
//var res:longint;
begin
  with IniFileDesc do
  begin
	inifilename:=PrepFilePath(fname); ok:=false; modifydate:=0;
    if inifilename<>'' then 
	begin
	  if not FileExists(inifilename) 
	    then call_external_prog(LOG_NONE,'touch '+inifilename); // just create on
	  {$IFNDEF WINDOWS} 
//		res:=fpChmod (inifilename,&600);
//		if (res<>0) then LOG_Writeln(LOG_ERROR,'BIOS_ReadIniFile: can not set perm '+inifilename+' 0x'+HexStr(res,8));
	  {$ENDIF}
//	  writeln(inifilename,' ',FileExists(inifilename),' ',(inifilbuf=nil));
//	  if FileExists(inifilename) then 
	  begin // will be created, if file does not exist
	    if (inifilbuf<>nil) then inifilbuf.free;
	    inifilbuf:=TIniFile.Create(inifilename); 
	    inifilbuf.CacheUpdates:=false;				// force immediate UpdateFile after a change
		modifydate:=GetFileAge(inifilename);
		ok:=true;
      end
//    else LOG_Writeln(LOG_ERROR,'BIOS_ReadIniFile: no config file found '+inifilename);	  
	end;
  end;
end;

procedure BIOS_SetDfltSection(section:string);   begin IniFileDesc.dfltsection:=section; end;
procedure BIOS_SetDfltFlags(flags:s_BIOS_flags); begin IniFileDesc.dfltflags:=flags; end;

function  GetARRIdx(bracketset:byte; var aidx,algt:longint; var key:string):boolean;
// IN:  bset:1 NGINX_mode{60,4}		OUT: aidx:60 algt:4 key:NGINX_mode 			ok:true
// IN:  bset:1 NGINX_mode{62}		OUT: aidx:62 algt:1 key:NGINX_mode 			ok:true
// IN:  bset:0 NGINX_mode[3]{60,4}	OUT: aidx: 3 algt:1 key:NGINX_mode{60,4}	ok:true
var ok:boolean; li1,li2:longint; brO,brC:char; sh1,sh2:string;
begin
  ok:=false;
  
  case bracketset of
  	  1: begin brO:='{'; brC:='}'; end;
  	  2: begin brO:='('; brC:=')'; end;
  	  3: begin brO:='<'; brC:='>'; end;
    else begin brO:='['; brC:=']'; end;
  end; // case

  li1:=Pos(brO,key); li2:=Pos(brC,key);
  if (li1>0) and (li2>li1) then
  begin // e.g. NGINX_mode{60,4} -> aidx:60 algt:4
    ok:=true;
    algt:=li2-li1-1;					// 4
    sh1:=copy(key,li1+1,algt);			// 60,4

    if (algt>=3) and (Pos(',',sh1)>0) then
    begin								// 60,4
      sh2:=CSV_Item(sh1,2);				// 4
      sh1:=CSV_Item(sh1,1);				// 60
      ok:= Str2Num( sh2,algt);
    end else algt:=1;
    
    if ok then
    begin
      ok:=Str2Num(sh1,aidx);
	  if ok then
	  begin
		key:=copy(key,1,    li1-1) +
			 copy(key,li2+1,Length(key)); // get rid of bracket part -> NGINX_mode
	  end;
	end;
  end;
  
  if not ok then
  begin
	aidx:=-1; algt:=-1;
  end;  
//if (Pos('NGINX_mode',name)>0) then writeln('-GetARRIdx'+brO,aidx,brC+':',name,CR);
  GetARRIdx:=ok;
end;

function  BIOS_GetIniString(section,name,default:string; flgs:s_BIOS_Flags):string;
// e.g. configfile.ini content:
// [SECNAME1]
// PARA1=Value 1234
// [SECNAME2]
// PARA1=Value 1
// PARAX=ValueX
// e.g. BIOS_GetIniString('SECNAME2','PARA1',false);
// return: 'Value 1'
// if Parameter is not found, then return default-string
var bol1,bol2:boolean; aidx1,bidx1,aidx2,algt2:longint; 
	i64:int64; qw:qword; e:extended; sh:string; 
begin
  sh:=default; aidx1:=-1; bidx1:=-1; aidx2:=-1; algt2:=-1; bol1:=false; bol2:=false;
  with IniFileDesc do
  begin
	if ok then
	begin // read in and check. if checks not met then use default value. default val is not checked
	  if (section='') and (dfltsection<>'') then section:=dfltsection;

//writeln('#0 aidx1: ',aidx1:2,' bidx1: ',bidx1,' aidx2: ',aidx2,' algt2: ',algt2,' sh: ',sh);
	  
	  if (BIOS_tryARRidx 	IN flgs) then 
	  begin // indexed access e.g. MYVALARR[3]=A,B,C,D,E,F,G,H
	    bol1:=GetARRIdx(0,aidx1,bidx1,name);
	  end;

//writeln('#1 aidx1: ',aidx1:2,' bidx1: ',bidx1,' aidx2: ',aidx2,' algt2: ',algt2,' sh: ',sh);
	  
	  if (BIOS_tryARRidx 	IN flgs) then
	  begin // indexed BIT access e.g. NGINX_mode{8}=0x000000000007E101
	  	bol2:=GetARRIdx(1,aidx2,algt2,name);
	  end;
	  
	  sh:=inifilbuf.ReadString(section,name,default);

//writeln('#2 aidx1: ',aidx1:2,' bidx1: ',bidx1,' aidx2: ',aidx2,' algt2: ',algt2,' sh: ',sh);
	  
	  if (aidx1>=1) and bol1 and
	  	 (BIOS_tryARRidx 	IN flgs) then 
	  begin
		sh:=CSV_Item(sh,aidx1);
		if (bidx1>0) then sh:=CSV_Item(sh,'|',bidx1);
	  end;	  
//writeln('#3 aidx1: ',aidx1:2,' bidx1: ',bidx1,' aidx2: ',aidx2,' algt2: ',algt2,' sh: ',sh);
	  if (aidx2>=0) and (aidx2<=63) and bol2 and
	  	 (BIOS_tryARRidx 	IN flgs) then 
	  begin
		sh:=Trimme(sh,3);
		if Str2Num(sh,qw)
		  then sh:=Num2Str(((qw and ((qword(1 shl algt2)-1) shl aidx2)) shr aidx2),0)
		  else sh:='';
	  end;  
//writeln('#4 aidx1: ',aidx1:2,' bidx1: ',bidx1,' aidx2: ',aidx2,' algt2: ',algt2,' sh: ',sh);
	  	 
	  if (BIOS_UnESC 		IN flgs) then sh:=SB_UnESC(sh);
	  if (BIOS_Printable 	IN flgs) then sh:=StringPrintable(sh);
	  if (BIOS_trim1 		IN flgs) then sh:=Trimme(sh,1);
	  if (BIOS_trim2 		IN flgs) then sh:=Trimme(sh,2);
	  if (BIOS_trim3 		IN flgs) then sh:=Trimme(sh,3);
	  if (BIOS_trim4 		IN flgs) then sh:=Trimme(sh,4);
// checks
	  if (BIOS_bool 		IN flgs) then if not Str2Bool(sh,bol1)		then sh:=default;
	  if (BIOS_float 		IN flgs) then 
	  begin
	    sh:=Trimme(sh,3);
		if Str2Num(sh,e) then
		begin
		  if (BIOS_NonZero	IN flgs) and IsZero(e) 						then sh:=default; 
		  if (BIOS_lat		IN flgs) and (abs(e)> 90.0)					then sh:=default;
		  if (BIOS_lon		IN flgs) and (abs(e)>180.0)					then sh:=default;
		end else sh:=default;
	  end;
	  if (BIOS_int 			IN flgs) then 
	  begin
	  	sh:=Trimme(sh,3);
		if Str2Num(sh,i64) then
		begin
		  if (BIOS_NonZero	IN flgs) and (i64=0) 						then sh:=default; 
		  if (BIOS_1byte	IN flgs) and ((i64>  127) or (i64<  -128)) 	then sh:=default;
		  if (BIOS_2byte	IN flgs) and ((i64>32767) or (i64<-32768))	then sh:=default;
		  if (BIOS_4byte	IN flgs) and 
			((i64>2147483647) or (i64<-2147483648))						then sh:=default;
		end else sh:=default;
	  end;
	  if (BIOS_uint 		IN flgs) then 
	  begin
	  	sh:=Trimme(sh,3);
		if Str2Num(sh,qw) then
		begin
		  if (BIOS_NonZero	IN flgs) and (qw=0)							then sh:=default; 
		  if (BIOS_1byte	IN flgs) and (qw>$ff)						then sh:=default;
		  if (BIOS_2byte	IN flgs) and (qw>$ffff)						then sh:=default;
		  if (BIOS_4byte	IN flgs) and (qw>$ffffffff)					then sh:=default;
		end else sh:=default;
	  end;	  
	  if (BIOS_tstmp		IN flgs) then 
	  begin
	  	sh:=Trimme(sh,3);
	  	sh:=StringReplace(sh,'T',' ',[rfReplaceAll,rfIgnoreCase]);
		try StrToDateTime(sh); except sh:=default; end;
	  end;
	  if (BIOS_PrefDflt		IN flgs) and (default<>'')					then sh:=default;
	  
(*	  if ((BIOS_RemOnDflt	IN flgs) and (sh=default)) then
  	  begin // not working with ReadString
  	  	BIOS_DeleteKey(section,name);
  	  	LOG_Writeln(LOG_WARNING,'BIOS_GetIniString['+section+'/'+name+'/'+default+']: value=default, entry deleted'); 
  	  end; *)
  	  
	end; // else Log_Writeln(LOG_ERROR,'BIOS_GetIniString: INI-File not opened');
  end; // with
  if (sh='') then sh:=default;
  
  BIOS_GetIniString:=sh;
end;
function  BIOS_GetIniString(section,name,default:string):string;
begin BIOS_GetIniString:=BIOS_GetIniString(section,name,default,IniFileDesc.dfltflags); end;
function  BIOS_GetIniString(name,default:string):string;
begin BIOS_GetIniString:=BIOS_GetIniString(IniFileDesc.dfltsection,name,default,IniFileDesc.dfltflags); end;
function  BIOS_GetIniString(name,default:string; flgs:s_BIOS_Flags):string;
begin BIOS_GetIniString:=BIOS_GetIniString(IniFileDesc.dfltsection,name,default,flgs); end;

function  BIOS_GetIniNum(section,name:string; flgs:s_BIOS_Flags; default,minval,maxval:real):real;
var r:real; sh:string;
begin
  sh:=BIOS_GetIniString(section,name,'',flgs+[BIOS_float]);
  if (sh<>'') then
  begin
	if Str2Num(sh,r) then
	begin
	  if not IsNan(r) then
	  begin
		if not IsNan(minval) then if (r<minval) then r:=minval;
		if not IsNan(maxval) then if (r>maxval) then r:=maxval;
	  end else r:=default;
	end else r:=default;
  end else r:=default;
  BIOS_GetIniNum:=r; 
end;
function  BIOS_GetIniNum(section,name:string; default,minval,maxval:real):real;
begin BIOS_GetIniNum:=BIOS_GetIniNum(section,name,[],default,minval,maxval); end;
function  BIOS_GetIniNum(name:string; default,minval,maxval:real):real;
begin BIOS_GetIniNum:=BIOS_GetIniNum(IniFileDesc.dfltsection,name,[],default,minval,maxval); end;

//function  BIOS_SetIniString(section,name,value:string; secret,overwrite:boolean):boolean;
function  BIOS_SetIniString(section,name,value:string; flgs:s_BIOS_Flags):boolean;	
begin
  with IniFileDesc do
  begin
    if ok then 
    begin
      if (section='') and (dfltsection<>'') then section:=dfltsection;
      if not ((BIOS_noOVR 	IN flgs) and (BIOS_GetIniString(section,name,'',flgs)<>'')) then
      begin
      	if (BIOS_trim1 		IN flgs) then value:=Trimme(value,1);
	  	if (BIOS_trim2 		IN flgs) then value:=Trimme(value,2);
	  	if (BIOS_trim3 		IN flgs) then value:=Trimme(value,3);
	  	if (BIOS_trim4 		IN flgs) then value:=Trimme(value,4);
        if (BIOS_DoESC 		IN flgs) then value:=BS_DoESC(value);
		inifilbuf.WriteString(section,name,value);
		if (not inifilbuf.CacheUpdates) then modifydate:=GetFileAge(inifilename);
	  end;
    end else Log_Writeln(LOG_ERROR,'BIOS_SetIniString: INI-File not opened');
  end;
  BIOS_SetIniString:=true;
end;
function  BIOS_SetIniString(section,name,value:string):boolean;	
begin BIOS_SetIniString:=BIOS_SetIniString(section,name,value,IniFileDesc.dfltflags); end;
function  BIOS_SetIniString(name,value:string):boolean;	
begin BIOS_SetIniString:=BIOS_SetIniString(IniFileDesc.dfltsection,name,value,IniFileDesc.dfltflags); end;

function  BIOS_SetDelIniString(section,name,value:string; flgs:s_BIOS_Flags):boolean;	
var ok:boolean;
begin
  if (value<>'')
	then ok:=BIOS_SetIniString(	section,name,value,flgs)
	else ok:=BIOS_DeleteKey(	section,name);
  BIOS_SetDelIniString:=ok;
end;

procedure BIOS_Test;
var fil:text; sh:string;
begin
  {$IFDEF UNIX} // just create a config file, only for demo reasons
    sh:=GetRndTmpFileName(ApplicationName,'.ini');
    assign (fil,sh); rewrite(fil);
    writeln(fil,'[SECNAME1]'); writeln(fil,'PARA1=Value 1234');
    writeln(fil,'[SECNAME2]'); writeln(fil,'PARA1=Value 1'); writeln(fil,'PARAX=ValueX');
    close(fil);
    writeln('Test start: reading the config file ',sh);
    BIOS_ReadIniFile(sh);	
    sh:=BIOS_GetIniString('SECNAME2','PARA1','DefaultValue',[]);
    writeln(' Read the parameter "PARA1" from section "SECNAME2"=',sh);
    sh:=BIOS_GetIniString('SECNAME1','PARA1','DefaultValue',[]);
    writeln(' Read the parameter "PARA1" from section "SECNAME1"=',sh);  
    sh:=BIOS_GetIniString('SECNAME2','PARA3','DefaultValue',[]);
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

function  File2MString(filname:string; var OutString,hash:string):boolean;
var b:boolean; MStream:TMemoryStream; fn:string;
begin
  b:=true; fn:=PrepFilePath(filname);
  {$I-}
  if FileExists(fn) then 
  begin
    MStream:=TMemoryStream.create;
    MStream.LoadFromFile(fn); 
    OutString:=MStream2String(MStream);
	hash:=MD5Print(MD5String(OutString)); 
	MStream.free;
  end
  else begin b:=false; hash:=''; OutString:=''; end; 
  {$I+}
  File2MString:=b;
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

function LNX_ProgInstalled(progname:string):boolean;
var sh:string;
begin
  if (progname<>'')
	then call_external_prog(LOG_NONE,'which '+progname,sh)
	else sh:='#';
  LNX_ProgInstalled:=(Pos(progname,sh)>0);
end;

procedure LNX_KillProcesses(processlist:string; signal:word);
// IN:  '1234 5678'
var n,num,sig:longint; sh:string;
begin
//say(log_warning,'LNX_KillProcesses:'+processlist+':');
  for n:=1 to Anz_Item(processlist,' ','') do
  begin
	sh:=CSV_Item(processlist,' ',n);
	if (sh<>'') then
	begin
	  case signal of
	  	1..31:	sig:=signal;
	  	else	sig:=1;			// -hup
	  end; // case
	  if Str2Num(sh,num) then 
	  begin
		call_external_prog(LOG_NONE,'kill -'+Num2Str(sig,0)+' '+sh);
//		say(log_warning,'kill -'+Num2Str(sig,0)+' '+sh);
	  end;
	end;
  end;
end;

function  LNX_GetProcessNumsByName(processname:string):string;
// IN:  'tail -f /var/log/syslog'
// OUT: '1234 5678'
var cmd,lst:string;
begin
  cmd:='pgrep -f "'+processname+'"';
  if (call_external_prog(LOG_ERROR,cmd,lst)<>0) then lst:='';
  lst:=Trimme(StringReplace(lst,LineEnding,' ',[rfReplaceAll,rfIgnoreCase]),4);
//say(LOG_WARNING,'LNX_GetProcessNumsByName: '+cmd+' '+lst);
  LNX_GetProcessNumsByName:=lst;
end;

function  HexStrFrm(str:string):string;
var n:longint; sh:string;
begin
  sh:='';
  for n:=1 to Length(str) do sh:=sh+HexStr(ord(str[n]),2)+' ';
  HexStrFrm:=Trimme(sh,4);
end;

procedure BT_PrettyHostName(hnam:string);
const fil_c='/etc/machine-info';
var cmd:string;
begin
  if (hnam<>'') 
	then cmd:='echo "PRETTY_HOSTNAME='+hnam+'" > '+PrepFilePath(fil_c)
	else cmd:='rm '+PrepFilePath(fil_c)+' > /dev/null 2>&1';
	cmd:=cmd+' ; systemctl restart bluetooth';
  call_external_prog(LOG_NONE,cmd);
end;

function  BTLE_GetBeaconHexStr(url:string; TXPower:integer):string;
// IN: TXPower: -12 to 10
// https://circuitdigest.com/microcontroller-projects/turn-your-raspberry-pi-into-bluetooth-beacon-using-eddystone-ble-beacon
// https://pimylifeup.com/raspberry-pi-ibeacon/
// https://developers.google.com/nearby/notifications/get-started
// https://github.com/google/physical-web
// https://learn.adafruit.com/google-physical-web-uribeacon-with-the-bluefruit-le-friend/getting-started
// https://github.com/google/eddystone/tree/master/eddystone-url
// https://play.google.com/store/apps/details?id=com.uriio

//App that will work on IOS: https://apps.apple.com/ch/app/ble-scanner-4-0/id1221763603
(*
hciconfig hci0 up ; hciconfig hci0 noleadv ; hciconfig hci0 noscan
enable advertize: 	hciconfig hci0 leadv 3
disable advertize: 	hciconfig hci0 noleadv
*)
const ServiceID='aafe'; 			// 16Bit EddyStone UUID
	  EddyURL='16'+ServiceID+'10';	// URL FrameType & EddyStoneUUID
var bpwr:byte; pwr:integer; sh:string;
begin
  sh:=url; 
  pwr:=TXPower; 
  Limits(pwr,-12,10);
  if (pwr<0) then pwr:=256+pwr;
  bpwr:=byte(pwr);
//if (Pos('HTTP:',Upper(sh))>0) then LOG_Writeln(LOG_WARNING,'BTLE_GetBeaconHexStr: Nearby Notifications and Physical Web on Chrome require HTTPS URLs');	
  sh:=StringReplace(sh,'http://www.',	#$00,[rfReplaceAll,rfIgnoreCase]);
  sh:=StringReplace(sh,'https://www.',	#$01,[rfReplaceAll,rfIgnoreCase]);
  sh:=StringReplace(sh,'http://',		#$02,[rfReplaceAll,rfIgnoreCase]);
  sh:=StringReplace(sh,'https://',		#$03,[rfReplaceAll,rfIgnoreCase]);
  sh:=StringReplace(sh,'.com/',    		#$00,[rfReplaceAll,rfIgnoreCase]);
  sh:=StringReplace(sh,'.org/',    		#$01,[rfReplaceAll,rfIgnoreCase]);
  sh:=StringReplace(sh,'.edu/',    		#$02,[rfReplaceAll,rfIgnoreCase]);
  sh:=StringReplace(sh,'.net/',    		#$03,[rfReplaceAll,rfIgnoreCase]);
  sh:=StringReplace(sh,'.info/',   		#$04,[rfReplaceAll,rfIgnoreCase]);
  sh:=StringReplace(sh,'.biz/',	    	#$05,[rfReplaceAll,rfIgnoreCase]);
  sh:=StringReplace(sh,'.gov/', 	   	#$06,[rfReplaceAll,rfIgnoreCase]);
  sh:=StringReplace(sh,'.com',    		#$07,[rfReplaceAll,rfIgnoreCase]);
  sh:=StringReplace(sh,'.org',	    	#$08,[rfReplaceAll,rfIgnoreCase]);
  sh:=StringReplace(sh,'.edu',  	  	#$09,[rfReplaceAll,rfIgnoreCase]);
  sh:=StringReplace(sh,'.net',	    	#$0a,[rfReplaceAll,rfIgnoreCase]);
  sh:=StringReplace(sh,'.info', 	   	#$0b,[rfReplaceAll,rfIgnoreCase]);
  sh:=StringReplace(sh,'.biz',	    	#$0c,[rfReplaceAll,rfIgnoreCase]);
  sh:=StringReplace(sh,'.gov',  	  	#$0d,[rfReplaceAll,rfIgnoreCase]);
//writeln('BTLE_GetBeaconHexStr: 0x'+HexStr(sh)+':'+StringPrintable(sh));
  sh:=StrHex(EddyURL)+char(bpwr)+sh;  
  if (Length(sh)>23) then
  begin
    sh:=''; LOG_Writeln(LOG_ERROR,'BTLE_GetBeaconHexStr: url to long: '+url); 
  end else sh:=StrHex('0201060303'+ServiceID+HexStr(Length(sh),2))+sh;
//writeln('0x',HexStrFrm(sh));
  BTLE_GetBeaconHexStr:=sh;
end;
function  BTLE_StopBeaconStr:string;
begin
  BTLE_StopBeaconStr:=	'hciconfig hci0 noleadv >/dev/null 2>&1 ; '+
  						'hciconfig hci0 down >/dev/null 2>&1'
end;
function  BTLE_StopBeacon:boolean; // start async
begin BTLE_StopBeacon:=(RunProcess(BTLE_StopBeaconStr,'','',false)=0); end;

function  BTLE_StartBeacon(hexstrng:string):boolean;
var _ok:boolean; sh:string;
begin
  _ok:=(hexstrng<>'');
  if _ok then 
  begin
//	writeln('BTLE_StartBeacon: hcitool -i hci0 cmd 0x08 0x0008 '+HexStr(Length(hexstrng),2)+' '+HexStrFrm(hexstrng));
	sh:=BTLE_StopBeaconStr+' ; '+
    'sleep 5 ; '+
  	'hciconfig hci0 up >/dev/null 2>&1 ; '+
  	'hciconfig hci0 noscan >/dev/null 2>&1 ; '+
  	'hciconfig hci0 leadv 3 >/dev/null 2>&1 ; '+
  	'hcitool -i hci0 cmd 0x08 0x0008 '+HexStr(Length(hexstrng),2)+' '+HexStrFrm(hexstrng)+' >/dev/null 2>&1';
//writeln('BTLE_StartBeacon: '+sh,CR);
    _ok:=(RunProcess(sh,'','',false)=0); // start async
  end else LOG_Writeln(LOG_ERROR,'BTLE_StartBeacon: no HexSting supplied');
  BTLE_StartBeacon:=_ok;
end;

function  BTLE_StartBeaconURL(url:string; TXPower:integer):boolean;
// IN url: 		https://www.google.com 
// IN url: 		http://192.168.10.200
// IN TXPower:	-12 to 10 -12:Lowest 10:high
var _ok:boolean; sh:string;
begin
  sh:=BTLE_GetBeaconHexStr(url,TXPower);
  _ok:=(sh<>''); 
  if _ok
	then _ok:=BTLE_StartBeacon(sh)
  	else LOG_Writeln(LOG_ERROR,'BTLE_StartBeaconURL: to long for beacon '+url);
  BTLE_StartBeaconURL:=_ok; 
end;
function  BTLE_StartBeaconURL(url:string):boolean;
begin BTLE_StartBeaconURL:=BTLE_StartBeaconURL(url,-12); end;

function OS_ShellExitDesc(ErrNum:integer):string;
// http://www.tldp.org/LDP/abs/html/exitcodes.html
var sh:string;
begin
  sh:='';
  {$IFDEF UNIX}
	case ErrNum of
	  1:	sh:='General error';
	  2:	sh:='Misuse of shell builtins';	
	126:	sh:='Command invoked cannot execute';
	127:	sh:='command not found';
	128:	sh:='Invalid exit argument';
	130:	sh:='Script terminated by Control-C';
	else	sh:='unknown error'
	end; // case
  {$ENDIF}
  if (ErrNum<>0) then sh:=Trimme('('+Num2Str(ErrNum,0)+') '+sh,3);
  OS_ShellExitDesc:=sh;
end;

function  call_external_prog(typ:t_ErrorLevel; cmdline:string; receivelist:TStringList; timo_msec:word):integer;
// http://wiki.freepascal.org/Executing_External_Programs#Reading_large_output
// can return multiple lines in StringList
const BUF_SIZE=2048;
var exitStat,exitCode:integer; BytesRead:LongInt; timo:TDateTime;
	OutputStream:TStream; AProcess:TProcess; 
	Buffer: array[1..BUF_SIZE] of byte;
begin
//writeln('cmdline:',cmdline,':');
  if (cmdline<>'') then 
  begin
    AProcess:=TProcess.Create(nil);
	AProcess.Options:=[poUsePipes (* ,poWaitOnExit *)];	
	{$IFDEF WINDOWS}
      AProcess.Executable:='c:\windows\system32\cmd.exe';
      AProcess.Parameters.Add('/c');
    {$ELSE}
      AProcess.Executable:=sudo+'/bin/sh'; 
	  AProcess.Parameters.Add('-c');   
    {$ENDIF}		// and // was and
    if (typ<>LOG_NONE) or (Pos('2>',cmdline)<>0) then 
      AProcess.Options:=AProcess.Options+[poStderrToOutPut];
    AProcess.Parameters.Add(cmdline);

	AProcess.Execute;
    OutputStream:=	TMemoryStream.Create;

	if (timo_msec>0) then
	begin   
      SetTimeOut(timo,timo_msec);    
      repeat 
      	if (AProcess.Output.NumBytesAvailable>0) then
      	begin
          SetTimeOut(timo,timo_msec);
	      BytesRead:=AProcess.Output.Read(Buffer,BUF_SIZE);
	      OutputStream.Write(Buffer,BytesRead);
      	end else delay_msec(1000);
      until TimeElapsed(timo); 
	end
	else
	begin
	  repeat     
	  	BytesRead:=AProcess.Output.Read(Buffer,BUF_SIZE);
	  	OutputStream.Write(Buffer,BytesRead);
	  until (BytesRead=0);
	end;
       
    OutputStream.Position:=0;
    receivelist.LoadFromStream(OutputStream);
    OutputStream.free;

    exitStat:=AProcess.exitStatus;	// reported by the OS
    exitCode:=AProcess.exitCode;	// exit code of the process
//writeln('exitStat:',exitStat,' exitCode:',exitCode);
    AProcess.free; 
//	ShowStringlist(receivelist);	  
	with receivelist do
	begin
	  if (count>0) then 
	  begin
//		remove last trailing $00 (0 terminated string; remove last trailing LF
		receivelist[count-1]:=CSV_RemLastSep(receivelist[count-1],#$00);
		receivelist[count-1]:=CSV_RemLastSep(receivelist[count-1],LineEnding);
	  end; 
	end; // with

	if 	((typ< LOG_NONE)	and (exitCode<>0)) or 
	   	((typ<=LOG_NOTICE) 	and (exitCode= 0)) then
	begin
	  LOG_Writeln(typ,'ShellExec['+Num2Str(exitStat,0)+']: '+OS_ShellExitDesc(exitCode));
//	  LOG_ShowStringList(typ,receivelist);
	end;
  	  
  end else begin exitCode:=0; exitStat:=0; end;
  call_external_prog:=exitCode;
end;

function  call_external_prog(typ:t_ErrorLevel; cmdline:string; receivelist:TStringList):integer;
begin call_external_prog:=call_external_prog(typ,cmdline,receivelist,0); end;

function  call_external_prog(typ:t_ErrorLevel; cmdline:string; var receivestring:string):integer;
var exitCode:integer; receivelist:TStringList;
begin
  receivelist:=TStringList.create;
  exitCode:=call_external_prog(typ,cmdline,receivelist,0);
//showstringlist(receivelist);
  receivestring:=StringList2String(receivelist,LineEnding);
  receivelist.free;
  call_external_prog:=exitCode;
end;

function  call_external_prog(typ:t_ErrorLevel; cmdline:string):integer;
// no content return
var exitCode,exitStat:integer; fpErrNo:longint; {$IFDEF WINDOWS} sh:string; {$ENDIF}
begin 
  {$IFDEF WINDOWS}
	exitCode:=call_external_prog(typ,cmdline,sh); 
  {$ELSE}
//	if (typ=LOG_ERROR)	and (Pos('2>',cmdline)=0) then cmdline:=cmdline+' 2>&1';
	if (typ=LOG_NONE)	and (Pos('2>',cmdline)=0) then cmdline:=cmdline+' 2>/dev/null';
    exitStat:=fpSystem(cmdline);		// faster than TProcess method
    fpErrNo :=fpgeterrno;
    exitCode:=wexitStatus(exitStat);
	if 	((typ< LOG_NONE)	and (exitCode<>0)) or 
	   	((typ<=LOG_NOTICE) 	and (exitCode= 0)) then
	begin
	  LOG_Writeln(typ,'shellExec['+
	  		Num2Str(exitStat,0)+'/'+
	  		Num2Str(fpErrNo,0)+']: '+OS_ShellExitDesc(exitCode));
  	end;
  {$ENDIF}
  call_external_prog:=exitCode;
end;
function  call_external_prog(cmdline:string):integer; 
begin call_external_prog:=call_external_prog(LOG_ERROR,cmdline); end;

function  RunScript(filname,para:string):integer;
var res:integer;
begin
  if FileExists(filname) then 
  begin
//	res:=call_external_prog(filname);
	res:=call_external_prog(filname+' '+para+' >' +filname+'.log 2>&1');
//	res:=call_external_prog(filname+' | tee ' +filname+'.log 2>&1');
  end
  else 
  begin 
	res:=-1; 
	LOG_Writeln(LOG_ERROR,'RunScript: file not exist '+filname); 
  end;
  RunScript:=res;
end;

function  RunScript(ts:TStringList; filname,para:string):integer;
var res:integer;
begin
  res:=-1;
//SAY_TL(LOG_INFO,ts); 
  if StringList2TextFile(filname,ts) then
  begin
	LNX_chmod	  (filname,&755); 
	res:=RunScript(filname,para)
  end else LOG_Writeln(LOG_ERROR,'RunScript: can not save '+filname);
  RunScript:=res;
end;

function  RunScript(ts:TStringList; para:string):integer;
var res:integer; filname:string;
begin
  {$IFDEF WINDOWS} 
	filname:=GetRndTmpFileName('RunScript_','.bat');
  {$ELSE}
	filname:=GetRndTmpFileName('RunScript_','.sh');
  {$ENDIF}
  res:=RunScript(ts,filname,para);
  DeleteFile(filname);
  RunScript:=res;
end;

function  RunProcess(filname,para:string; syncwait:boolean):integer;
// http://wiki.freepascal.org/Executing_External_Programs#Run_detached_program
var res,i:integer; tl:TStringList; RunProg:TProcess;
begin
  res:=-1; 
  if FileExists(filname) then 
  begin
    res:=0;
	RunProg:=TProcess.create(nil);
	RunProg.Executable:=filname;
	RunProg.Options:=[];
	RunProg.InheritHandles:=false;	// SF new 11.11.2018
	RunProg.ShowWindow:=swoShow;	// SF new 11.11.2018
//	Copy default environment variables including DISPLAY variable for GUI application to work
    for i:= 1 to GetEnvironmentVariableCount do
      RunProg.Environment.Add(GetEnvironmentString(i));	// SF new 11.11.2018
      
	RunProg.Parameters.Add(para);
	if syncwait then 
	begin
	  tl:=TStringList.Create;
	  RunProg.Options:=RunProg.Options+[poWaitOnExit];
	end;
	RunProg.Execute;
	if syncwait then 
	begin
	  tl.LoadFromStream(RunProg.Output);
	  tl.SaveToFile(filname+'.log');
	  tl.Free;
	end;
	RunProg.Free;
  end else LOG_Writeln(LOG_ERROR,'RunProcess: file not exist '+filname);
  RunProcess:=res;
end;

function  RunProcess(ts:TStringList; filname,para:string; syncwait:boolean):integer;
var res:integer;
begin
  res:=-1;
  if (filname='') then
  begin
  	{$IFDEF WINDOWS} 
	  filname:=GetRndTmpFileName('RunScript_','.bat');
  	{$ELSE}
	  filname:=GetRndTmpFileName('RunScript_','.sh');
	{$ENDIF}  
  end;
  if (ts.count>0) then
  begin
  	if StringList2TextFile(filname,ts) then 
  	begin
	  LNX_chmod		 (filname,&755); 
	  res:=RunProcess(filname,para,syncwait);
	end else LOG_Writeln(LOG_ERROR,'RunProcess: can not write '+filname); 
  end else LOG_Writeln(LOG_ERROR,'RunProcess: no commands given');
  RunProcess:=res;
end;

function  RunProcess(cmds,filname,para:string; syncwait:boolean):integer;
var res:integer; _tl:TStringList;
begin
  _tl:=TStringList.create;
  String2StringList(cmds,_tl);
  res:=RunProcess(_tl,filname,para,syncwait); 
  _tl.free;
  RunProcess:=res;
end;

procedure call_external_prog_Test;
const tr='#########################################################';
var res:integer; sh:string='';
begin
  writeln(tr); res:=call_external_prog(LOG_WARNING,	'TryThisUnknownCommand1', sh);	writeln(res:0,' ',sh);	
  writeln(tr); res:=call_external_prog(LOG_INFO,	'TryThisUnknownCommand2', sh);	writeln(res:0,' ',sh);	
{$IFDEF linux}
  writeln(tr); res:=call_external_prog(LOG_INFO,	'timedatectl', sh);				writeln(sh);
  writeln(tr); res:=call_external_prog(LOG_ERROR,	'cat /etc/debian_version',sh);	writeln(res:0,' DebianVers:',sh); 
  writeln(tr); res:=call_external_prog(LOG_ERROR,	'ls -l /usr/local/xxsbin',sh);	writeln(res:0,' ',sh); 
  writeln(tr); res:=call_external_prog(LOG_ERROR,	'ls -l /usr/local/sbin',  sh);	writeln(res:0,' ',sh); 
{$ENDIF}  
  writeln(tr);
end;

function  LNX_SSHFSmount(site,pwd,mnt:string; var err:string):integer;
// experimental. currently not working 23.11.2018
// site IN: myuser@ftp.mysite.com:/
// pwd  IN: mypassword
// mnt  IN: ~/mnt/mysite
// res OUT: 0 -> OK; <>0 -> notOK  err string returns err desc
// https://www.digitalocean.com/community/tutorials/how-to-use-sshfs-to-mount-remote-file-systems-over-ssh
var res:integer;
begin
  if (site<>'') and (pwd<>'') and (mnt<>'') and (DirectoryExists(mnt)) then
  begin
    res:=call_external_prog(LOG_NONE,
    		''''+
//    		'umount '+mnt+' >/dev/null 2>&1; '+
    		'echo "'+pwd+'" | sshfs "'+site+'" "'+mnt+'" -o '+
//			'NumberOfPasswordPrompts=1,ServerAliveInterval=15,ServerAliveCountMax=3,'+
//    		'Compression=no,reconnect,'+
//    		'nonempty,sshfs_debug,debug,loglevel=debug,'+
			'workaround=rename,password_stdin,'+
    		'StrictHostKeyChecking=no,UserKnownHostsFile=/dev/null 2>&1'+'''',err);
  end else begin res:=-1; err:='LNX_SSHFSmount: missing param'; end;
//writeln('LNX_SSHFSmount:',res,' err:',err,':');
  LNX_SSHFSmount:=res;
end;

function  MD5_HashGET(filnam:string; var MD5hash:string):boolean;
// MD5_HashGET('/tmp/rfm.tgz',myhashstr)
//38398e53aa45f86427ada3e9331c24f9  rfm.tgz.md5
var ok:boolean; sh:string;
begin
  ok:=false; MD5hash:='';
  if FileExists(filnam) then
  begin
    call_external_prog(LOG_NONE,'md5sum '+filnam,sh); 
    MD5hash:=CSV_Item(Trimme(sh,4),' ',1);
	ok:=(MD5hash<>'');
  end;
  MD5_HashGET:=ok;
end;

function  MD5_HashCreateFile(filnam,MD5filnam:string; var MD5hash:string):boolean;
// MD5_HashCreateFile('/tmp/rfm.tgz','/tmp/rfm.tgz.md5',myhashstr)
//38398e53aa45f86427ada3e9331c24f9  rfm.tgz.md5
var ok:boolean;
begin
  ok:=false; MD5hash:='';
  if FileExists(filnam) and DirectoryExists(Get_Dir(MD5filnam)) then
  begin
    call_external_prog(LOG_NONE,'md5sum '+filnam+' > '+MD5filnam,MD5hash); 
    MD5hash:=CSV_Item(Trimme(MD5hash,4),' ',1);
	ok:=(MD5hash<>'');
  end;
  MD5_HashCreateFile:=ok;
end;

function  MD5_HashGETFile(MD5filnam:string; var MD5hash:string):boolean;
//38398e53aa45f86427ada3e9331c24f9  rfm.tgz.md5
var ok:boolean; res:longint;
begin
  ok:=false; MD5hash:='';
  if (GetFileSize(MD5filnam)>0) then
  begin
    res:=call_external_prog(LOG_NONE,'tail '+MD5filnam,MD5hash); 
    MD5hash:=CSV_Item(Trimme(MD5hash,4),' ',1);
	ok:=(MD5hash<>''); if res>1 then ;
//SAY(LOG_WARNING,'MD5_HashGETFile:'+Num2Str(res,0)+':'+MD5filnam+':'+MD5hash+':'+Bool2Str(ok));
  end;
  MD5_HashGETFile:=ok;
end;

function  MD5_HashGETVersion(MD5filnam:string; var version:string; var versionmd5:real):boolean;
//38398e53aa45f86427ada3e9331c24f9  rfm.tgz.md5
//...
//0.952  version		<- via echo "0.952  version">>MD5filnam	// 
var ok:boolean; sh:string; 
begin
  ok:=false; versionmd5:=0; version:='';
  if (GetFileSize(MD5filnam)>0) then
  begin
    call_external_prog(LOG_NONE,'tail -1 '+MD5filnam,sh); 
    sh:=Trimme(sh,4);
    version:=CSV_Item(sh,' ',1);
	ok:=( (version<>'') and (Pos('VERSION',Upper(CSV_Item(sh,' ',2)))>0) );
//SAY(LOG_INFO,'MD5_HashGETVersion:'+MD5filnam+':'+sh+':'+version+':'+Bool2Str(ok));
	if ok then
	begin
	  ok:=Str2Num(version,versionmd5);
	  if not ok then begin version:=''; versionmd5:=0; end;
	end;
  end;
  MD5_HashGETVersion:=ok;
end;

function  MD5_Check(file1,file2:string):boolean;
//file1:	38398e53aa45f86427ada3e9331c24f9  rfm.tgz.md5
//file2:	38398e53aa45f86427ada3e9331c24f9  /tmp/rfm.tgz.md5
var ok:boolean; md5f1,md5f2:string;
begin
  ok:=false;
  if MD5_HashGETFile(file1,md5f1) and MD5_HashGETFile(file2,md5f2) then
	ok:=(Upper(md5f1)=Upper(md5f2));
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
  CURL_RemoveProgressfile(FTPLogf+CURLpfext_c); 
end; 
procedure RPI_MaintSetEnvUPD(UpdPkgSrcFile,UpdPkgDstDir,UpdPkgDstFile,UpdPkgMaintDir,UpdPkgLogf:string);
begin
  RpiMaintCmd.WriteString('RPIMAINT','UPDPSF', UpdPkgSrcFile);
  RpiMaintCmd.WriteString('RPIMAINT','UPDPDD', UpdPkgDstDir);
  RpiMaintCmd.WriteString('RPIMAINT','UPDPDF', UpdPkgDstFile);
  RpiMaintCmd.WriteString('RPIMAINT','UPDMDIR',UpdPkgMaintDir);
  RpiMaintCmd.WriteString('RPIMAINT','UPDPLOG',UpdPkgLogf);
  CURL_RemoveProgressfile(UpdPkgLogf+CURLpfext_c); 
end;
procedure RPI_MaintSetEnvUPL(UplSrcPackageRemark,UplSrcFiles,UplDstDir,UplLogf:string);
begin // FTP-Upload
  RpiMaintCmd.WriteString('RPIMAINT','UPLREM', UplSrcPackageRemark);
  RpiMaintCmd.WriteString('RPIMAINT','UPLSF',  UplSrcFiles);
  RpiMaintCmd.WriteString('RPIMAINT','UPLDD',  UplDstDir);
  RpiMaintCmd.WriteString('RPIMAINT','UPLLOG', UplLogf);
  CURL_RemoveProgressfile(UplLogf+CURLpfext_c); 
end;
procedure RPI_MaintSetEnvDWN(DwnSrcDir,DwnlSrcFiles,DwnDstDir,DwnLogf:string);
begin // FTP-Download
  RpiMaintCmd.WriteString('RPIMAINT','DWNSD',  DwnSrcDir);
  RpiMaintCmd.WriteString('RPIMAINT','DWNSF',  DwnlSrcFiles);
  RpiMaintCmd.WriteString('RPIMAINT','DWNDD',  DwnDstDir);
  RpiMaintCmd.WriteString('RPIMAINT','DWNLOG', DwnLogf);
  CURL_RemoveProgressfile(DwnLogf+CURLpfext_c); 
end;

function  LNX_ErrDesc(errno:longint):string; 
begin LNX_ErrDesc:='('+Num2Str(errno,0)+') '+StrError(errno); end;

function  FPC_ErrDesc(ErrNum:integer):string;
var sh:string;
begin
  case ErrNum of
        0 : sh:='Program terminated normally';
        1 : sh:='Invalid function number';
        2 : sh:='File not found';
        3 : sh:='Path not found';
        4 : sh:='Too many open files';
        5 : sh:='File access denied';
        6 : sh:='Invalid file handle';
		8 : sh:='Insufficient memory';
       12 : sh:='Invalid file access mode';
       15 : sh:='Invalid drive number';
       16 : sh:='Cannot remove current directory';
       17 : sh:='Cannot rename accross drives';
      100 : sh:='Disk read error';
      101 : sh:='Disk write error';
      102 : sh:='File not assigned';
      103 : sh:='File not open';
      104 : sh:='File not open for input';
      105 : sh:='File not open for output';
      106 : sh:='Invalid numeric format';
      150 : sh:='Disk is write protected';
      151 : sh:='Bad drive request struct length';
      152 : sh:='Drive not ready';
      153 : sh:='Unknown Command';
      154 : sh:='CRC error in data';
      155 : sh:='Bad drive request structure length';
      156 : sh:='Disk seek error';
      157 : sh:='Unknown media type';
      158 : sh:='Sector not found';
      159 : sh:='Printer out of paper';
      160 : sh:='Device write fault';
      161 : sh:='Device read fault';
      162 : sh:='Hardware failure';
      200 : sh:='Division by zero';
      201 : sh:='Range check error';
      202 : sh:='Stack overflow error';
      203 : sh:='Heap overflow error';
      204 : sh:='Invalid pointer operation';
      205 : sh:='Floating point overflow';
      206 : sh:='Floating point underflow';
      207 : sh:='Invalid floating point operation';
      208 : sh:='Overlay manager not installed';
      209 : sh:='Overlay file read error';
      210 : sh:='Object not initialized';
      211 : sh:='Call to abstract method';
      212 : sh:='Stream register error';
      213 : sh:='Collection index out of range';
      214 : sh:='Collection overflow error';
	  215 : sh:='Arithmetic overflow error';
	  216 : sh:='General Protection fault';
	  217 : sh:='invalid operation code';
	  218 : sh:='Invalid value specified';
	  219 : sh:='Invalid typecast';
	  222 : sh:='Variant dispatch error';
	  223 : sh:='Variant array create';
	  224 : sh:='Variant is not an array';
	  225 : sh:='Var Array Bounds check error';
	  227 : sh:='Assertion failed error';
	  229 : sh:='Safecall error check';
	  231 : sh:='Exception stack corrupted';
	  232 : sh:='Threads not supported';
      255 : sh:='Aborted via ^C';
      300 : sh:='file IO error';
      301 : sh:='non-matched array bounds';
      302 : sh:='non-local procedure pointer';
      303 : sh:='procedure pointer out of scope';
      304 : sh:='function not implemented';
      305 : sh:='breakpoint error';
      306 : sh:='break by ^C';
      307 : sh:='break by ^Break';
      308 : sh:='break by other process';
      309 : sh:='no floating point coprocessor';
      310 : sh:='invalid variant type operation';
      else  sh:='unknown errornum';
  end;
  if ErrNum<>0 then sh:='('+Num2Str(ErrNum,0)+') '+sh;
  FPC_ErrDesc:=sh;
end; // FPC_ErrDesc

function  CURL_ErrDesc(ErrNum:longint):string; // translate some error codes
var sh:string;
begin
  case ErrNum of
  	  0: sh:='ok';
      1: sh:='Unsupported protocol';
	  2: sh:='Failed to initialize';
	  3: sh:='URL malformed';
	  4: sh:='feature not available';
	  5: sh:='Couldn''t resolve proxy';
	  6: sh:='Couldn''t resolve host';
	  7: sh:='Failed to connect to host';
	  8: sh:='FTP weird server reply';
	  9: sh:='FTP access denied';
	 10: sh:='FTP accept failed';
	 11: sh:='FTP weird PASS reply';
	 12: sh:='FTP port timeout';
	 13: sh:='FTP weird PASV reply';
	 14: sh:='FTP weird 227 format';
	 15: sh:='FTP can''t resolve host IP';
	 16: sh:='HTTP/2 error';
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
	 31: sh:='FTP could not use REST';
	 33: sh:='HTTP range error';
	 34: sh:='HTTP post error';
	 35: sh:='SSL connect error';
	 36: sh:='FTP bad download resume';
	 37: sh:='couldn''t read file. Failed to open the file. Permissions?';
	 38: sh:='LDAP can not bind';
	 39: sh:='LDAP search failed';
	 42: sh:='aborted callback';
	 43: sh:='bad function argument';
	 45: sh:='interface error';
	 47: sh:='too many redirects';
	 48: sh:='unknown option specified';
	 49: sh:='Malformed telnet option';
	 51: sh:='The peer''s SSL certificate or SSH MD5 fingerprint was not OK';
	 52: sh:='The server didn''t reply anything';
	 53: sh:='SSL crypto engine not found';
	 54: sh:='can not set SSL crypto engine';
	 55: sh:='failed sending network data';
	 56: sh:='failure in receiving network data';
	 58: sh:='problem with local certificate';
	 59: sh:='can not use specified SSL cipher';
	 60: sh:='Peer certificate can not be authenticated with known CA certificate';
	 61: sh:='Unrecognized transfer encoding';
	 62: sh:='Invalid LDAP URL';
	 63: sh:='Maximum file size exceeded';
	 64: sh:='Requested FTP SSL level failed';
	 65: sh:='Sending the data requires a rewind that failed';
	 66: sh:='Failed to initialize SSL Engine';
	 67: sh:='failed to log in';
	 68: sh:='File not found on TFTP server';
	 69: sh:='Permission problem on TFTP server';
	 70: sh:='Out of disk space on TFTP server';
	 71: sh:='Illegal TFTP operation';
	 72: sh:='Unknown TFTP transfer ID';
	 73: sh:='File already exists (TFTP)';
	 74: sh:='No such user (TFTP)';
	 75: sh:='Character conversion failed';
	 76: sh:='Character conversion functions required';
	 77: sh:='Problem with reading the SSL CA cert';
	 78: sh:='The resource referenced in the URL does not exist';
	 79: sh:='An unspecified error occurred during the SSH session';
	 80: sh:='Failed to shut down the SSL connection';
	 82: sh:='Could not load CRL file, missing or wrong format';
	 83: sh:='TLS certificate issuer check failed';
	 84: sh:='The FTP PRET command failed';
	 85: sh:='RTSP: mismatch of CSeq numbers';
	 86: sh:='RTSP: mismatch of Session Identifiers';
	 87: sh:='unable to parse FTP file list';
	 88: sh:='FTP chunk callback reported error';
	 89: sh:='No connection available, the session will be queued';
	 90: sh:='SSL public key does not matched pinned public key';
	 91: sh:='Invalid SSL certificate status';
	 92: sh:='Stream error in HTTP/2 framing layer';
	else sh:='unknown errornum';
  end; // case
  if ErrNum<>0 then sh:='('+Num2Str(ErrNum,0)+') '+sh;
  CURL_ErrDesc:=sh;
end;

function  PV_Progress(progressfile:string):integer;
// asumes that pv output is redirected to progressfile with -n option
// e.g. dd if=/dev/urandom bs=1M count=100 | pv -n -s 100m 2>/tmp/pv.out | dd of=/dev/null
// percentage is in /tmp/pv.out and is assigned to function result res
// requires apt install pv
var res:integer; sh:string;
begin
  res:=-1;
  if call_external_prog(LOG_NONE,'tail -n 1 '+progressfile,sh)=0 then 
  begin
    sh:=CSV_Item(sh,#$0a,1);
    if not Str2Num(sh,res) then res:=-1;
  end;
  PV_Progress:=res;
end;

function  CURLcmdCreate(usrpwd,proxy,ofil,uri:string; flags:s_rpimaintflags):string;
var cmd:string;
begin
  cmd:='curl ';
//if  	  UpdSUDO			IN flags	then cmd:='sudo '+cmd; 
  if not (UpdNoRedoRequest	IN flags) 	then cmd:=cmd+'-Lf '; 
  if not (UpdNoFTPDefaults 	IN flags) 	then cmd:=cmd+CURLFTPDefaults_c+' ';
  if UAgent 				IN flags 	then cmd:=cmd+'-A "User-Agent: '+UAgentDefault+'" ';
  if usrpwd<>'' 					  	then cmd:=cmd+'-u '+usrpwd+' ';
  if proxy<>''							then cmd:=cmd+'-x '+proxy+' ';
  if UpdVerbose 			IN flags	then cmd:=cmd+'-v ';
  if UpdSSL     			IN flags	then cmd:=cmd+CURLSSLDefaults_c+' ';
  if not (UpdNoCreateDir 	IN flags) 	then cmd:=cmd+'--ftp-create-dirs ';
  if ofil<>'' then 
  begin
    if UpdNewerOnly     	IN flags	then cmd:=cmd+'-z '+ofil+' ';	// additional to -o <ofile>
    										 cmd:=cmd+'-o '+ofil+' ';
  end;
  cmd:=cmd+uri;
  CURLcmdCreate:=cmd;
end;

function  CURL_ProgressUpdateHook(lvl:t_ErrorLevel; msgtype:MSG_Type_t; msg:string):longint; 
// e.g. update external OLED, WEBGuiMsgBoard...
var res:longint; xferdata,perc,filnam:string;
begin 
//1   2   3        4 5     6            7           8         9        10       11           12
//% Total % Received % Xferd AverageDload SpeedUpload TimeTotal TimeSpent TimeLeft CurrentSpeed
// "96 52.3M 96,50.3M 0 0 3101k 0,0:00:17 0:00:16 0:00:01 3549k","filename"
  res:=0;
  xferdata:=Select_Item(msg,',','"',1); filnam:=Select_Item(msg,',','"',2); 
  perc:=Select_Item(xferdata,',','',1)+'%'; 
  writeln(#$0d+'Here is my function, which handles curl progress information asynchronously: '+filnam+' '+perc);
//e.g. code to update OLED Display
  CURL_ProgressUpdateHook:=res;
end;

function  CURL_ProgressThread(ptr:pointer):ptrint;
// e.g. this thread could update a Gauge on an external OLED display
var term:boolean; res:longint; 	sh:string;
begin
  Thread_SetName('CURL_Progress'); 
  if ptr<>nil then
  begin
//	SAY(LOG_DEBUG,'CURL_ProgressThread: start');
	with Thread_Ctrl_ptr(ptr)^ do 
	begin 
	  repeat
		if CURL_DoProgressAction(Thread_Ctrl_ptr(ptr)^,term) then
    	begin //														  
    	  if (CURL_ProgressUpdateHook_ptr<>nil) then
    	  begin
(*% Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed                             
ThreadParaStr[4]:
  0     0    0     0    0     0      0      0 --:--:-- --:--:-- --:--:--     0
100   168    0   168    0     0    132      0 --:--:--  0:00:01 --:--:--   132
  1 52.3M    1  920k    0     0   352k      0  0:02:32  0:00:02  0:02:30  964k
 16 52.3M   16 8719k    0     0  1889k      0  0:00:28  0:00:04  0:00:24 2950k
 96 52.3M   96 50.3M    0     0  3101k      0  0:00:17  0:00:16  0:00:01 3549k
100 52.3M  100 52.3M    0     0  3119k      0  0:00:17  0:00:17 --:--:-- 3490k
100 52.3M  100 52.3M    0     0  3119k      0  0:00:17  0:00:17 --:--:-- 3490k *)
//say(LOG_INFO,'CURL_ProgressThread:'+ThreadParaStr[4]);
			sh:=Trimme(RM_CRLF(ThreadParaStr[4]),4);
//e.g.: 96 52.3M 96,50.3M 0 0 3101k 0,0:00:17 0:00:16 0:00:01 3549k					
    		res:=CURL_ProgressUpdateHook_ptr(
    				LOG_INFO,
    				curlprogmsg,		
    				'"'+sh+'"'+					// csv progress-string: "96 52.3M ..."
    				','+						// csv
    				'"'+ThreadParaStr[2]+'"'	// "filename"
    			);
    		if (res<>0) then ;					// react on exit code, future use
    											// currently only 0 supported
    	  end;
		end;
	  until term or TerminateProg;
	  delay_msec(250);	// let other Threads terminate
//	  SAY(LOG_DEBUG,'CURL_ProgressThread: end');
	end; // with
  end else Log_Writeln(LOG_ERROR,'CURL_ProgressThread: no valid ctlstruct');
  EndThread; 
  CURL_ProgressThread:=0;
end;

procedure CURL_SetPara(var CurlThCtl:Thread_Ctrl_t; info,curlcmd,logfile,filenamelist,dirname:string; updintervall_ms:integer; flgs:s_rpimaintflags);
begin 
  if (CURL_ProgressUpdateHook_ptr<>nil)
	then Thread_InitStruct2(CurlThCtl,@CURL_ProgressThread)	// routine for handling progress bar
	else Thread_InitStruct2(CurlThCtl,nil); 				// routine disabled 
   
  with CurlThCtl do 
  begin
    ThreadInfo:=info;
  	if (UpdCleanUP 		IN flgs)	then ThreadPara[1]:=1 else ThreadPara[1]:=0; // cleanup log-/progressfile yes/no
  	if (UpdShowThInfo	IN flgs)	then ThreadPara[2]:=1 else ThreadPara[2]:=0; 
  	ThreadPara[0]:=updintervall_ms;
  	if updintervall_ms< 1500 then ThreadPara[0]:= 1500;
  	if updintervall_ms>15000 then ThreadPara[0]:=15000;
  	SetTimeOut(ThreadTimeOut,30000);	
	if logfile='' then
	begin
	  ThreadParaStr[0]:=GetRndTmpFileName('curl_','.log');	// random logfilename
	  ThreadPara[1]:=1;										// cleanup log-/progressfile
	end else ThreadParaStr[0]:=PrepFilePath(logfile);
	ThreadParaStr[1]:=	 ThreadParaStr[0]+CURLpfext_c;		// progressfile
	ThreadParaStr[2]:=	 filenamelist;						// list of filenames that are transferred
	ThreadParaStr[3]:=	 dirname;							// dir info
	ThreadParaStr[4]:=	 '';								// reserved, progress threadinfo will be returned
	
	if (curlcmd<>'') then 
	begin
	  ThreadCmdStr:=curlcmd;
	  if (UpdLogAppend	IN flgs)	then ThreadCmdStr:=ThreadCmdStr+' >>'
	  								else ThreadCmdStr:=ThreadCmdStr+' >';
	  ThreadCmdStr:=ThreadCmdStr+'"'+ThreadParaStr[0]+'"';	// logfile
	  
	  if not (UpdNoProgressBar IN flgs) then
		ThreadCmdStr:=ThreadCmdStr+' 2>"'+ThreadParaStr[1]+'"';// progressfile
	end else Log_Writeln(LOG_ERROR,'CURL_SetPara: no valid curlcmd');
  end; // with 
end;

function  CURL_DoProgressAction(var CurlThCtl:Thread_Ctrl_t; var terminate:boolean):boolean;
var ok:boolean;
begin
  with CurlThCtl do 
  begin 
	ok:=((ThreadProgressOld<>ThreadProgress) and ThreadRunning (*and FileExists(ThreadParaStr[1])*));
	if ok then
    begin
	  ThreadProgressOld:=ThreadProgress;
      SetTimeOut(ThreadTimeOut,30000);			// if progress changes, retrig timeout  
      if not TermThread then delay_msec(ThreadPara[0])	// interval in ms
      					else delay_msec(100);
    end;
    terminate:=(TimeElapsed(ThreadTimeOut) or (not ThreadRunning) or TerminateProg);
//	if terminate then writeln(LOG_INFO,'terminate: ',ThreadRunning,' Telapsed',TimeElapsed(ThreadTimeOut),' ok:',ok);
  end; // with
  CURL_DoProgressAction:=ok;
end;

procedure CURL_RemoveProgressfile(progressfile:string);
var sh:string;
begin if progressfile<>'' then call_external_prog(LOG_NONE,'rm -f '+progressfile,sh) end;

function  CURLThread(ptr:pointer):ptrint;
// executes curl thread
begin
  if ptr<>nil then
  begin
	Thread_SetName('CURL_Thread'); 
	with Thread_Ctrl_ptr(ptr)^ do 
	begin 	
//	  SAY(LOG_WARNING,'CURL_Thread: '+ThreadCmdStr);
      ThreadRetCode:=call_external_prog(LOG_NONE,ThreadCmdStr,ThreadRetStr);	// sync. call
//	  if (ThreadRetCode<>0) then LOG_Writeln(LOG_ERROR,'CURLThread: '+CURL_ErrDesc(ThreadRetCode));
	  TermThread:=true;					// signal that Thread will end soon
      delay_msec(ThreadPara[0]); 		// give Threads time to react on termination
	  ThreadRunning:=false; 			// signal final termination to external Threads
	end; // with
  end else Log_Writeln(Log_ERROR,'CURLThread: no parameter pointer supplied');
  EndThread; 
  CURLThread:=0;
end;

function  CURL(var CurlThCtl:Thread_Ctrl_t):integer;
var cleanup:boolean; ival_ms:longint; logf,pfil:string;  

  function  CURL_Progress:integer;
  var sh:string; p:integer;
  begin        
    p:=-1; sh:=TailFile(pfil,1);
    with CurlThCtl do
    begin
	  if (sh<>'') then
      begin
      	sh:=RM_CRLF(CSV_Item(sh,#$0d,CSV_Count(sh,#$0d)));
      	if (sh<>'') then
      	begin
		  ThreadParaStr[4]:=#$0d+sh;	// last bar available a ThreadParamStr 
	  	  write(ThreadParaStr[4]);
	  	end;
      	sh:=Trimme(copy(sh,1,3),3);
      	if Str2Num(sh,p) and (p>=0) and (p<=100) 
      	  then begin if (p>=ThreadProgress) then ThreadProgress:=p; end 
      	  else p:=-1;
	  end;
	end; // with
    CURL_Progress:=p;
  end; // CURL_Progress
  
begin  
  with CurlThCtl do 
  begin 
    if (ThreadPara[2]<>0) then Thread_ShowStruct(CurlThCtl);
	logf:=ThreadParaStr[0];			// logfile
	pfil:=ThreadParaStr[1];			// progress file	
	ival_ms:=ThreadPara[0] div 2;	// interval in ms
	cleanup:=(ThreadPara[1]<>0);	// delete log-/progressfile after execution
	CURL_RemoveProgressfile(pfil); 
	CURL_RemoveProgressfile(logf);
	pfil:=RemoveChar(pfil,'"');
	if (pfil<>'') then
	begin
	  Thread_Start(CurlThCtl,@CURLThread,@CurlThCtl,250,0);	// start curl data transfer
	  if ThreadFunc<>nil then	// do something async with the progress information
	  begin
	    delay_msec(5000);	// wait 5 sec, progress file will deliver reliable values
		BeginThread(ThreadFunc,@CurlThCtl);	
	  end;
	  repeat
		CURL_Progress;
		if (ThreadRunning) 	then delay_msec(ival_ms);
	  	if (not TermThread) then delay_msec(ival_ms);
	  until (not ThreadRunning) or TimeElapsed(ThreadTimeOut) or TerminateProg;
	  
//	  Thread_End(CurlThCtl,0);
	  if (ThreadRetCode<>0) then LOG_Writeln(LOG_ERROR,'CURL: '+CURL_ErrDesc(ThreadRetCode));
	  if cleanup then 
	  begin
	  	delay_msec(100);
//		say(log_info,'CURL cleanup:'+pfil+':'+logf);
	    CURL_RemoveProgressfile(pfil); 
	    CURL_RemoveProgressfile(logf);
	  end;
	  write(#$0d);
	end;
	CURL:=ThreadRetCode;
  end; // with
end;

procedure CURL_Test;
// shows usage curl with progress info update 
const filnam_c='52241088c1da59a359110d39c1875cda56496764';
begin	
  CURL_ProgressUpdateHook_ptr:=@CURL_ProgressUpdateHook;	// install ext. routine
	
  CURL_SetPara(	CurlThreadCtrl,				// control structure, has to be defined globally
				'CURL_Test',				// give the curl task a name
  				CURLcmdCreate(
  						'',					// no usrpwd
  						'',					// no proxyserver
  						'/dev/null',		// dir for outfile (demonstration, just drop all files)
						'https://github.com/Hexxeh/rpi-firmware/tarball/{'+filnam_c+'}',// files2download
  						[UpdNoCreateDir,UpdNoFTPDefaults]	// curl flags
  				),
  				'/tmp/curltest.log',		// logfile
  				filnam_c,					// filenames
  				'/dev/null',				// target dir
  				2500,						// update every 2.5s (2500ms)
  				[UpdShowThInfo]				// additional flags
  			  );
  with CurlThreadCtrl do
  begin
  	writeln(ThreadCmdStr);									// curlcmd: just show what we do 
  	ThreadRetCode:=CURL(CurlThreadCtrl);					// initiate curl download
  	writeln('CURL_Test: RetCode: ',ThreadRetCode);
  end; // with
  
  CURL_ProgressUpdateHook_ptr:=nil;							// deinstall ext. routine
end;

procedure RPI_MaintSetVersions(versmin,versmax:real); 
begin 
  RPI_MaintMinVersion:=versmin; 
  RPI_MaintMaxVersion:=versmax; 
end;

function  RPI_Maint(UpdFlags:s_rpimaintflags; var CurlThCtl:Thread_Ctrl_t):integer; 
const test_c=false; test2_c=false; c_maxp=10; 
type  t_parr = array[1..c_maxp] of string;
var   p2:t_parr; j,res:integer; i64:int64; r,version_new_md5,version_old_md5:real; 
	  noMD5Chk,Reprt,test,test2:boolean;
	  flgs:s_rpimaintflags; cmd:t_rpimaintflags; 
	  tl:TStringList;
	  sh,filnam,DfltMaintDir,cdmod,usrpwd,cmds,cmdsf,version,versold,
	  FTPServer,FTPUser,FTPPwd,FTPlogf,FTPOpts,
	  UpdPkgSrcFile,UpdPkgSrcDir,UpdPkgDstFile,UpdPkgDstDirAndFile,
	  UpdPkgMaintDir,UpdPkgMD5FileOld,UpdPkgDstDir,UpdPkglogf,
	  UplSrcFiles,UplSrcPkgRem,UplDstDir,Upllogf,DwnSrcDir,DwnSrcFiles,DwnDstDir,DwnLogf:string;

  function creaOutFileOpt(ddir,fils:string):string;
  var _i:longint; sh,fil:string;
  begin
    sh:='';
    for _i:=1 to Anz_Item(fils,',','"') do
    begin
      fil:=Trimme(Select_Item(fils,',','"',_i),3);
      if (fil<>'') then
      begin
        if (ddir='/dev/null')	then sh:=sh+'-o /dev/null '
        						else sh:=sh+'-o "'+PrepFilePath(ddir+'/'+fil)+'" ';
      end;
    end;
    sh:=Trimme(sh,3);
    creaOutFileOpt:=sh;
  end;
	  
  function  cmdget(var p:t_parr):string; var i:integer; sh:string; begin sh:=p[1]; for i:=2 to c_maxp do sh:=sh+' '+p[i]; cmdget:=Trimme(sh,4); end;
  procedure parr_clean(var p:t_parr); var i:integer; begin for i:=1 to c_maxp do p[i]:=''; end;
  function  parr_gets (var p:t_parr):string; var i:integer; sh:string; begin sh:=''; if test2 then for i:=1 to c_maxp do if p[i]<>'' then sh:=sh+p[i]+' '; parr_gets:=Trimme(sh,3); end;
  procedure parr_show (s:string; var p:t_parr); begin if test2 then say(LOG_WARNING,'maint: '+s+':'+parr_gets(p)+':'); end;
  function  MD5Chk(oklvl,errlvl:T_errorlevel; file1,file2:string):boolean;
  var ok:boolean; sh:string;
  begin
    ok:=MD5_Check(file1,file2); sh:='MD5_Check: '+file1+' '+file2+' same='+Bool2YN(ok);
    if ok then say(oklvl,sh) else say(errlvl,sh);
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
		if (UpdErrVerbose IN UpdFlags) then 
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
  DfltMaintDir:=	AppDataDir_c+'/'+ApplicationName+'/maint';	// /var/lib/<CompanyShortName>/<appname>/maint
  res:=-1; 

  test:=		(UpdDBG1 		IN UpdFlags); 
  test2:=		(UpdDBG2 		IN UpdFlags);  //test2:=true;
  noMD5Chk:=	(UpdnoMD5Chk 	IN UpdFlags);
  Reprt:=		(not (UpdQuiet 	IN UpdFlags));

//test2:=true; test:=true;
  
  flgs:=UpdFlags+[UpdNOP]; 
  if (UpdOnlyMD5Chk IN flgs) then flgs:=flgs-[UpdPKGGet];
  
  FTPServer:=		RpiMaintCmd.ReadString('RPIMAINT','FTPSRV', '');	
  FTPUser:=  		RpiMaintCmd.ReadString('RPIMAINT','FTPUSR', '');		
  FTPPwd:=	 	 	RpiMaintCmd.ReadString('RPIMAINT','FTPPWD', '');	
  FTPlogf:=	 	 	RpiMaintCmd.ReadString('RPIMAINT','FTPLOG', '/tmp/rpimaint_ftp.log');
  FTPOpts:=	 	 	RpiMaintCmd.ReadString('RPIMAINT','FTPOPT', CURLFTPDefaults_c);
  usrpwd:=			FTPUser; if usrpwd='' then usrpwd:='anonymous';
  if FTPPwd<>'' then usrpwd:=usrpwd+':'+FTPPwd;
  if UpdNoFTPDefaults IN UpdFlags then FTPOpts:='';
  UplSrcFiles:=		RpiMaintCmd.ReadString('RPIMAINT','UPLSF', DfltMaintDir+'/supportfile_'+RPI_SNR+'.tgz');
  UplSrcPkgRem:=	RpiMaintCmd.ReadString('RPIMAINT','UPLREM',UplSrcFiles);
  
  
  UplDstDir:=		RpiMaintCmd.ReadString('RPIMAINT','UPLDD', '/'+ApplicationName+'/upload/'+RPI_SNR);
  Upllogf:=			RpiMaintCmd.ReadString('RPIMAINT','UPLLOG','/tmp/rpimaint_upload.log'); 
  
  DwnSrcDir:=		RpiMaintCmd.ReadString('RPIMAINT','DWNSD', '/'+ApplicationName);
  DwnSrcFiles:=		RpiMaintCmd.ReadString('RPIMAINT','DWNSF', ApplicationName+'.tgz');
  DwnDstDir:=		RpiMaintCmd.ReadString('RPIMAINT','DWNDD', DfltMaintDir);
  Dwnlogf:=			RpiMaintCmd.ReadString('RPIMAINT','DWNLOG','/tmp/rpimaint_dwnload.log'); 
  
  
  UpdPkgSrcDir:=	RpiMaintCmd.ReadString('RPIMAINT','UPDPSF', '/'+ApplicationName);
  UpdPkgSrcFile:=	RpiMaintCmd.ReadString('RPIMAINT','UPDPSF', '/'+ApplicationName+'/'+ApplicationName+'.tgz');
  UpdPkgDstDir:=	RpiMaintCmd.ReadString('RPIMAINT','UPDPDD', '/tmp');
  UpdPkgDstFile:=	RpiMaintCmd.ReadString('RPIMAINT','UPDPDF', ApplicationName+'.tgz');
  UpdPkgMaintDir:=	RpiMaintCmd.ReadString('RPIMAINT','UPDMDIR',DfltMaintDir);
  UpdPkglogf:=		RpiMaintCmd.ReadString('RPIMAINT','UPDPLOG','/tmp/rpimaint_updpkg.log');		    
  UpdPkgMD5FileOld:=   PrepFilePath(UpdPkgMaintDir+'/'+UpdPkgDstFile+'.md5');
  UpdPkgDstDirAndFile:=PrepFilePath(UpdPkgDstDir+  '/'+UpdPkgDstFile); 
  for cmd IN flgs do
  begin
    cmds:=GetEnumName(TypeInfo(t_rpimaintflags),ord(cmd));
    cmdsf:='PKGMGT['+StringReplace(cmds,'Upd','',[])+']:';
//  say(LOG_Info,'maint cmd/attrib['+cmds+']: last: '+Bool2Str(cmd=High(flgs)));
    res:=-1; parr_clean(p2); // clear para array  
	case cmd of
	  UpdExec:		begin // e.g. EXEC=ls -l /tmp 
					  say(LOG_Info,'enter maint step: '+cmds);
	      			  sh:=RpiMaintCmd.ReadString('RPIMAINT','EXEC','');
	      			  if (sh<>'') then
	      			  begin	
	      				for j:=1 to c_maxp do p2[j]:=CSV_Item(sh,' ',j);
//	      				if UpdSUDO IN UpdFlags then p2[1]:='sudo '+p2[1];  
	      				MSG_HUB(LOG_INFO,maintmsg,cmdsf);
	      				res:=cmd_do(p2); 
	      			  end else res:=0;
	      			end;
	  UpdUpld:		begin	
					  say(LOG_Info,'enter maint step: '+cmds);
	  				  if (FTPServer='') then
	  				  begin
	  				    say(LOG_ERROR,cmdsf+' no FTPServerInfo supplied, use RPI_MaintSetEnvFTP');  
	  				    break; 
	  				  end;
	  				  if (UplSrcFiles='') then
	  				  begin
	  				    say(LOG_ERROR,cmdsf+' no UpdPkgInfo supplied, use RPI_MaintSetEnvUPL');
	  				    break;
	  				  end;
//curl -u usr:pwd <curldefaults> -v -k --ssl -T "{file1,file2}" "ftp://host/upload/" > file.log 2> file.log.prog
					  p2[1]:='curl'; 	
//					  if UpdSUDO 		IN UpdFlags 	  then p2[1]:='sudo '+p2[1]; 					  
					  if usrpwd<>'' 					  then p2[2]:='-u '+usrpwd;
					  if UpdVerbose 	IN UpdFlags 	  then p2[2]:=p2[2]+' -v';
					  if UpdSSL     	IN UpdFlags 	  then p2[2]:=p2[2]+' '+CURLSSLDefaults_c;
					  if not (UpdNoCreateDir IN UpdFlags) then p2[2]:=p2[2]+' --ftp-create-dirs';
					  if FTPOpts<>'' then 	p2[2]:=p2[2]+' '+FTPOpts;
					  
					  p2[3]:='-T "{'+UplSrcFiles+'}"';
					  i64:=GetFilePackSize(UplSrcFiles);
					  
					  if (([UpdProtoHTTP,UpdProtoHTTPS] * UpdFlags) <> []) then
					  begin
					    if (UpdProtoHTTPS IN UpdFlags) then p2[4]:='https' else p2[4]:='http'
					  end else p2[4]:='ftp';
					  p2[4]:='"'+  p2[4] +'://'+FTPServer+UplDstDir+'"'; // if you have multiple files, do not forget trailing /
					  
					  parr_show('#1',p2);
//writeln('UplDstDir:',p2[4],' UplSrcFiles:',UplSrcFiles);
					  MSG_HUB(LOG_INFO,maintmsg,cmdsf+' '+FormatFileSize(i64));
					  if CURL_ProgressUpdateHook_ptr<>nil then MSG_HUB(LOG_INFO,maintmsg,cmdsf+' starting...');
					  CURL_SetPara(CurlThCtl,cmdsf,cmdget(p2),Upllogf,UplSrcFiles,Get_Dirs(UplSrcFiles),0,UpdFlags);					  
					  res:=CURL(CurlThCtl);
					  if (res<>0) then 
					  begin
						LOG_Writeln(LOG_ERROR,cmdsf+' Step#1 '+parr_gets(p2));
	      			 	MSG_HUB(	LOG_ERROR,maintmsg,'curl#1: '+CURL_ErrDesc(res));
	      			  end else say(	LOG_NOTICE,cmdsf+' '+Trimme('file '+UplSrcPkgRem+' successfully uploaded',4));
	      			end;  	      			
	  UpdDwnld:		begin // download file(s)
					  say(LOG_Info,'enter maint step: '+cmds);
	  				  if (FTPServer='') and (not (UpdProtoRAW IN UpdFlags)) then
	  				  begin 
	  				    say(LOG_ERROR,cmdsf+' no FTPSupportServer supplied, use RPI_MaintSetEnvFTP before');   
	  				    break;
	  				  end;
	  				  if (DwnSrcDir='') then
	  				  begin
	  				    say(LOG_ERROR,cmdsf+' no DwnSrcDir supplied, use RPI_MaintSetEnvDWN');
	  				    break;
	  				  end;
	  				  if (DwnSrcFiles='') then
	  				  begin
	  				    say(LOG_ERROR,cmdsf+' no DwnSrcFiles supplied, use RPI_MaintSetEnvDWN');
	  				    break;
	  				  end;
	  				  if (DwnDstDir='') then
	  				  begin
	  				    say(LOG_ERROR,cmdsf+' no DwnDstDir supplied, use RPI_MaintSetEnvDWN');
	  				    break;
	  				  end;
	  				  cdmod:='/#1';
	  				  if UpdProtoRAW 		IN UpdFlags then
	  				  begin
	  				  	sh:=DwnSrcDir+'/'+'{'+DwnSrcFiles+'}';
	  				  end
	  				  else
	  				  begin
						if (([UpdProtoHTTP,UpdProtoHTTPS] * UpdFlags) <> []) then
					  	begin
					      if (UpdProtoHTTPS IN UpdFlags) then sh:='https' else sh:='http'
					  	end else sh:='ftp';
					  	sh:=sh +'://'+FTPServer+PrepFilePath(DwnSrcDir+'/')+'{'+DwnSrcFiles+'}';					      
					  end;
					  if DwnDstDir='/dev/null' then cdmod:=''; if cdmod<>'' then ;
//curl -u usr:pwd -v -k --ssl -o "./file1" -o "./file2" "ftp://www.xyz.com/dir/{file1,file2}" > "file.log" 2> "file.log.prog"
					  p2[1]:='curl'; 	
					  if usrpwd<>''						  	then p2[2]:='-u '+usrpwd;
//					  if UpdSUDO		IN UpdFlags 	  	then p2[1]:='sudo '+p2[1];  
					  if not (UpdNoRedoRequest IN UpdFlags) then p2[2]:=p2[2]+' -Lf'; 					  
					  if UpdVerbose 	IN UpdFlags 	  	then p2[2]:=p2[2]+' -v';
					  if UpdSSL     	IN UpdFlags 	  	then p2[2]:=p2[2]+' '+CURLSSLDefaults_c;
					  if not (UpdNoCreateDir IN UpdFlags) 	then p2[2]:=p2[2]+' --ftp-create-dirs';
					  
					  p2[2]:=p2[2]+' '+FTPOpts;
//					  p2[3]:='-o'; 		p2[4]:='"'+PrepFilePath(DwnDstDir+cdmod)+'"'; 
					  p2[3]:=creaOutFileOpt(DwnDstDir,DwnSrcFiles); p2[4]:='';
					  
					  p2[5]:='"'+sh+'"';p2[6]:='';					  					  
					  parr_show('#1',p2);
					  MSG_HUB(LOG_INFO,maintmsg,cmdsf);
					  if CURL_ProgressUpdateHook_ptr<>nil then MSG_HUB(LOG_INFO,maintmsg,cmdsf+' starting...');
					  CURL_SetPara(CurlThCtl,cmdsf,cmdget(p2),Dwnlogf,DwnSrcFiles,DwnDstDir,0,UpdFlags);	
					  res:=CURL(CurlThCtl);
					  if (res<>0) then
					  begin
					  	LOG_Writeln(LOG_ERROR,cmdsf+' Step#1 '+parr_gets(p2)); 
						MSG_HUB(	LOG_ERROR,maintmsg,'curl#1('+Num2Str(res,0)+') '+CURL_ErrDesc(res));
					  end else say(	LOG_Info,cmdsf+' successfully downloaded '+DwnSrcFiles);
					end;	
	 UpdPKGcopy:	begin // copy install package from source directory (e.g. USB-Stick)
	 				  say(LOG_Info,'enter maint step: '+cmds);
	 				  if (UpdPkgSrcDir='') or (UpdPkgDstFile='') then
	  				  begin 
	  				    say(LOG_ERROR,cmdsf+' no UpdPkgSrcFile supplied, use RPI_MaintSetEnvUPD before');   
	  				    break;
	  				  end; 
 					  
 					  p2[1]:='cp';
	  				  if UpdForce	IN UpdFlags then p2[1]:=p2[1]+' -f';
	  				  if UpdVerbose IN UpdFlags then p2[1]:=p2[1]+' -v';
	  				  if UpdUpdate	IN UpdFlags then p2[1]:=p2[1]+' -u';
//					  if UpdSUDO	IN UpdFlags	then p2[1]:='sudo '+p2[1]; 
					  p2[3]:=UpdPkgDstDir;

					  p2[2]:=PrepFilePath(UpdPkgSrcDir+'/'+UpdPkgDstFile);
					  if FileExists(p2[2]) then
					  begin
						parr_show('#1',p2);	cmd_do(p2);
						p2[2]:=p2[2]+'.md5';
						if FileExists(p2[2]) then
					  	begin
						  parr_show('#2',p2);	cmd_do(p2);
						  if FileExists(PrepFilePath(UpdPkgDstDir+'/'+UpdPkgDstFile)) and
						  	 FileExists(PrepFilePath(UpdPkgDstDir+'/'+UpdPkgDstFile)+'.md5')
							then res:=0
							else LOG_Writeln(LOG_ERROR,cmdsf+' Step#3 can not copy required install files '+UpdPkgDstFile); 
					  	end else LOG_Writeln(LOG_ERROR,cmdsf+' Step#2 file '+p2[2]+' does not exist'); 
					  end else LOG_Writeln(LOG_ERROR,cmdsf+' Step#1 file '+p2[2]+' does not exist'); 
					  if (res=0) then MSG_HUB(LOG_NOTICE,maintmsg,cmdsf+' USB-Stick')
					  			 else MSG_HUB(LOG_ERROR, maintmsg,cmdsf+' USB-Stick');
	 				end;			
	  UpdOnlyMD5Chk,
	  UpdPKGGet:	begin // get a whole install package, check if download is needed
					  say(LOG_Info,'enter maint step: '+cmds);
	  				  if FTPServer='' then
	  				  begin 
	  				    say(LOG_ERROR,cmdsf+' no FTPSupportServer supplied, use RPI_MaintSetEnvFTP before');   
	  				    break;
	  				  end;
	  				  SAY(LOG_INFO,cmdsf+' download md5 file');
					  if (([UpdProtoHTTP,UpdProtoHTTPS] * UpdFlags) <> []) then
					  begin
						if (UpdProtoHTTPS IN UpdFlags) then sh:='https' else sh:='http'
					  end else sh:='ftp';
					  sh:=sh+'://'+FTPServer+UpdPkgSrcFile;			  
//curl -u usr:pwd <curldefaults> -v -k --ssl -o <dstfile>.md5 "ftp://ftp.host.com/<MaintUpdPkgSrcFile>.md5" > file.log 2> file.log.prog
					  p2[1]:='curl'; 	
					  if usrpwd<>'' 					  then p2[2]:='-u '+usrpwd;
//					  if UpdSUDO		IN UpdFlags 	  then p2[1]:='sudo '+p2[1];  
					  if UpdVerbose 	IN UpdFlags 	  then p2[2]:=p2[2]+' -v';
					  if UpdSSL     	IN UpdFlags 	  then p2[2]:=p2[2]+' '+CURLSSLDefaults_c;
					  if not (UpdNoCreateDir IN UpdFlags) then p2[2]:=p2[2]+' --ftp-create-dirs';
					  
					  p2[2]:=p2[2]+' '+FTPOpts;
					  p2[3]:='-o'; 			p2[4]:='"'+UpdPkgDstDirAndFile+'.md5"'; 
					  p2[5]:='"'+sh+'.md5"';p2[6]:='';
					  parr_show('#1',p2); 
					  if Reprt then MSG_HUB(LOG_INFO,maintmsg,cmdsf+' md5');
					  CURL_SetPara(CurlThCtl,cmdsf+' md5',cmdget(p2),FTPlogf,UpdPkgDstFile+'.md5',Get_Dirs(UpdPkgDstDirAndFile),0,UpdFlags);
					  res:=CURL(CurlThCtl);
					  if (res=0) then
					  begin
					    MD5_HashGETVersion(UpdPkgMD5FileOld,			versold,version_old_md5);
					    MD5_HashGETVersion(UpdPkgDstDirAndFile+'.md5',	version,version_new_md5);	
						say(LOG_NOTICE,cmdsf+' successfully downloaded '+UpdPkgDstFile+'.md5 ('+Num2Str(version_old_md5,0,3)+' '+Num2Str(version_new_md5,0,3)+')');
                        if not MD5Chk(LOG_INFO,LOG_WARNING,UpdPkgDstDirAndFile+'.md5',UpdPkgMD5FileOld) then res:=-1;
//						if (cmd=UpdOnlyMD5Chk) then LOG_Writeln(LOG_WARNING,'UpdOnlyMD5Chk: '+Num2Str(res,0));
						if (cmd<>UpdOnlyMD5Chk) and (noMD5Chk or (res<0)) then
						begin // get big file, there is a different package available
						  SAY(LOG_INFO,cmdsf+' download tar ball');
						  p2[4]:='"'+UpdPkgDstDirAndFile+'"'; p2[5]:='"'+sh+'"';
						  parr_show('#2',p2);
						  if Reprt then MSG_HUB(LOG_INFO,maintmsg,cmdsf+' '+version);
						  CURL_SetPara(CurlThCtl,cmdsf,cmdget(p2),FTPlogf,UpdPkgDstFile,Get_Dirs(UpdPkgDstDirAndFile),0,UpdFlags+[UpdLogAppend]);
						  res:=CURL(CurlThCtl);
						  if (res=0) then
						  begin
						    i64:=GetFilePackSize(UpdPkgDstFile);
						    if Reprt then MSG_HUB(LOG_NOTICE,maintmsg,cmdsf+' '+FormatFileSize(i64)+' '+version);
							say(LOG_NOTICE,cmdsf+' successfully downloaded '+FormatFileSize(i64)+' '+version+' '+UpdPkgDstFile);
							parr_clean(p2); 
							p2[1]:='md5sum'; p2[2]:=UpdPkgDstDirAndFile; 
//							if UpdSUDO 	  IN UpdFlags then	p2[1]:='sudo '+p2[1];  
							p2[3]:='>'; p2[4]:='"'+UpdPkgDstDirAndFile+'.md5.2"'; 
							parr_show('#3',p2);	
							if (cmd_do(p2)=0) then
							begin
							  if MD5Chk(LOG_INFO,LOG_ERROR,UpdPkgDstDirAndFile+'.md5',UpdPkgDstDirAndFile+'.md5.2') then 
							  begin
								res:=0; say(LOG_NOTICE,cmdsf+' valid md5 of '+UpdPkgDstFile);
								if Reprt then MSG_HUB(LOG_NOTICE,maintmsg,cmdsf+' chk md5');
							  end
							  else
							  begin
								LOG_Writeln(LOG_ERROR,cmdsf+' Step#4 '+parr_gets(p2)); 
								MSG_HUB(LOG_ERROR,maintmsg,cmdsf+' chk md5 bad xfr');
								if UpdKeepFile IN UpdFlags then
								begin	
								  parr_clean(p2); 
								  p2[1]:='cp';
								  p2[2]:=UpdPkgDstDirAndFile; 
								  p2[3]:=UpdPkgDstDirAndFile+'.err'; 
								  parr_show('#4',p2);
								  cmd_do(p2); // cp unvalid package
								end;
								
								parr_clean(p2); 
								p2[1]:='rm'; 				p2[2]:='-f'; 
//								if UpdSUDO IN UpdFlags then	p2[1]:='sudo '+p2[1];  
								p2[3]:=UpdPkgDstDirAndFile; 
								parr_show('#5',p2);
								LOG_Writeln(LOG_ERROR,cmdsf+' invalid md5 of '+UpdPkgDstFile+' '+parr_gets(p2)+' bad xfr');
								cmd_do(p2); // remove unvalid package
							  end;								  
							end else begin LOG_Writeln(LOG_ERROR,cmdsf+' Step#3 '+parr_gets(p2)); end;
						  end 
						  else 
						  begin
							LOG_Writeln(LOG_ERROR,cmdsf+' Step#2 '+parr_gets(p2)); 
							MSG_HUB(	LOG_ERROR,maintmsg,'curl#2('+Num2Str(res,0)+') '+CURL_ErrDesc(res));
						  end;
						end
						else 
						begin
						  if (cmd<>UpdOnlyMD5Chk) then 
						  begin
							res:=0; 
							say(LOG_Info,cmdsf+' valid md5 of '+UpdPkgDstFile+', file was already successfully transferred');
						  end;
						end;
					  end 
					  else 
					  begin
						LOG_Writeln(LOG_ERROR,cmdsf+' Step#1 '+parr_gets(p2)); 
						MSG_HUB(	LOG_ERROR,maintmsg,'curl#1 '+CURL_ErrDesc(res));
					  end;
					end;
	  UpdPKGInstV,			
	  UpdPKGInst:	begin
					  say(LOG_Info,'enter maint step: '+cmds);
	  	  			  if (UpdPkgDstFile='') then
	  				  begin 
	  				    say(LOG_ERROR,cmdsf+' no UpdPkgInfo supplied, use RPI_MaintSetEnvUPD');  
	  				    break;
	  				  end;
	  				  MD5_HashGETVersion(UpdPkgDstDirAndFile+'.md5',version,version_new_md5);
					  if noMD5Chk or (not MD5Chk(LOG_INFO,LOG_WARNING,UpdPkgDstDirAndFile+'.md5',UpdPkgMD5FileOld)) then
					  begin // newer pkg should be available, try to install it
						say(LOG_INFO,cmdsf+' deploying newer package '+UpdPkgDstFile);
						if FileExists(UpdPkgDstDirAndFile) then
						begin						  
						  p2[1]:='tar'; 					p2[2]:='-xvzf';
//						  if UpdSUDO 	  IN UpdFlags then	p2[1]:='sudo '+p2[1];  
						  p2[3]:=UpdPkgDstDirAndFile;		p2[4]:='-C'; 
						  p2[5]:=UpdPkgDstDir;  			p2[6]:='';
						  if UpdLogAppend IN UpdFlags then	p2[7]:='>>' 	else p2[7]:='>';  				
						  p2[8]:=UpdPkglogf; 				p2[9]:='2>&1'; 
						  parr_show('#1',p2);
						  MSG_HUB(LOG_INFO,maintmsg,cmdsf+' UnPck');
						  if (cmd_do(p2)=0) then 
						  begin
							if UpdPKGInstV IN UpdFlags then
							begin
//							  LOG_Writeln(LOG_ERROR,cmdsf+' UpdPKGInstVers currently not implemented'); 
							  r:=0;
							  filnam:=PrepFilePath(UpdPkgDstDir+'/version.txt');
							  if FileExists(filnam) then
							  begin
							    tl:=TStringList.create;
								if TextFile2StringList(filnam,tl) then
								begin
								  if (tl.count>0) then 
								  begin
								    sh:=FilterChar(tl[0],'0123456789.');
									if Str2Num(sh,r) then
									begin
// 												    maint[UpdPKGInstal]: (/tmp/version.txt 0.92) V:0.920
									  SAY(LOG_Info,cmdsf+' ('+filnam+' '+tl[0]+') V:'+Num2Str(r,0,3)+
										' Vmin:'+Num2Str(RPI_MaintMinVersion,0,3)+
										' Vmax:'+Num2Str(RPI_MaintMaxVersion,0,3));
									  if (RPI_MaintMinVersion>0) and (r<RPI_MaintMinVersion) then
									  begin
									    LOG_Writeln(LOG_ERROR,cmdsf+' version '+Num2Str(r,0,3)+' < required minimum version '+Num2Str(RPI_MaintMinVersion,0,3)+' stop installation');
										break;
									  end;
									  if (RPI_MaintMaxVersion>0) and (r>RPI_MaintMaxVersion) then
									  begin
									  	LOG_Writeln(LOG_ERROR,cmdsf+' version '+Num2Str(r,0,3)+' > required maximum version '+Num2Str(RPI_MaintMaxVersion,0,3)+' stop installation');
										break;
									  end;
									end else LOG_Writeln(LOG_ERROR,	cmdsf+' no valid version supplied ('+sh+'), installing package');
								  end else LOG_Writeln(LOG_ERROR,	cmdsf+' version file has no content, installing package');	
								end else LOG_Writeln(LOG_ERROR,		cmdsf+' version file not supplied, installing package');								
								tl.free;
							  end;
							end;  // UpdPKGInstVers		
// !!!!!! install.sh !!!!!! apt install xxx						
							parr_clean(p2); 
							filnam:=PrepFilePath(UpdPkgDstDir+'/install.sh');
							p2[1]:='chmod'; 				p2[2]:='+x'; 
//							if UpdSUDO 	  IN UpdFlags then	p2[1]:='sudo '+p2[1];  
							p2[3]:=filnam;
							p2[7]:='>>'; 	p2[8]:=UpdPkglogf;	p2[9]:='2>&1';
							parr_show('#2',p2);
							if (cmd_do(p2)=0) then 
							begin			
							  parr_clean(p2);  
							  p2[1]:=filnam+' "'+rpi_snr+'" "'+UpdPkgMaintDir+'" "'+UpdPkglogf+'"';   //	execute install.sh
//							  if UpdSUDO IN UpdFlags then		p2[1]:='sudo '+p2[1];  
							  p2[7]:='>>'; 	p2[8]:=UpdPkglogf;	p2[9]:='2>&1';
							  parr_show('#3',p2);
							  if (cmd_do(p2)=0) then 
							  begin	
							    res:=0;
							    parr_clean(p2);  // cp -f /tmp/rfm.tgz.md5 <UpdPkgMaintDir>/rfm.tgz.md5
							    p2[1]:='cp -f '+UpdPkgDstDirAndFile+'.md5 '+UpdPkgMD5FileOld;
//								if UpdSUDO IN UpdFlags then	p2[1]:='sudo '+p2[1];  
							    cmd_do(p2);
							    if res=0 then 
							    begin
							      say(LOG_NOTICE,cmdsf+' package '+UpdPkgDstFile+' successfully deployed');
							      MSG_HUB(LOG_NOTICE,maintmsg,cmdsf+' Inst');
							    end else LOG_Writeln(LOG_ERROR,cmdsf+' Step#5 '+p2[1]); 
							  end else LOG_Writeln(LOG_ERROR,cmdsf+' Step#4 '+p2[1]); 
							end else LOG_Writeln(LOG_ERROR,cmdsf+' Step#3 '+parr_gets(p2)); 
						  end else LOG_Writeln(LOG_ERROR,cmdsf+' Step#2 '+parr_gets(p2)); 
						end else LOG_Writeln(LOG_ERROR,cmdsf+' Step#1, Package not available: '+UpdPkgDstFile);							  
					  end
					  else 
					  begin
					    res:=0; 
					    say(LOG_INFO,cmdsf+' Packages are identical, no update needed');
					    MSG_HUB(LOG_INFO,maintmsg,cmdsf+' already inst');
					  end;					
					end;
		  else		res:=0;	// do nothing, just attribs no commands
	    end; // case
	if res<>0 then break;
  end; // for
  RPI_Maint:=res;
end;

function  TTY_console:string;
var sh:string;
begin
  call_external_prog(LOG_NONE,'cat /sys/class/tty/console/active',sh);
  sh:=Trimme(sh,4);
//writeln('TTY_console:',sh,':');
  TTY_console:=sh;
end;
 
function  TTY_setterm(lvl:t_ErrorLevel; ttydev,ttyopts:string):integer; 	
// setterm --cursor off --clear all > /dev/tty1
var res:integer; sh:string;
begin
  res:=-1;
  if FileExists(ttydev) and (ttyopts<>'') then
  begin
    sh:='setterm '+ttyopts+' > '+ttydev;
//	SAY(lvl,sh);
    res:=call_external_prog(LOG_NONE,sh,sh);
  end else LOG_Writeln(LOG_ERROR,'TTY_setterm: device does not exist: '+ttydev);
  TTY_setterm:=res;
end; 
 
function  TTY_sttySpeed(lvl:t_ErrorLevel; ttyandspeed:string):integer; 	// e.g. /dev/ttyAMA0@9600 -cstopb -parodd
var res:integer; _speed,_par,_tty,sh:string; baudr:longword;
begin
  res:=-1;
  _par:=  Select_RightItems	(ttyandspeed,' ','',2);	// -cstopb -parodd
  _tty:=  CSV_Item			(ttyandspeed,' ','',1);	// /dev/ttyAMA0@9600
  _speed:=CSV_Item			(_tty,'@',2);		// 9600
  _tty:=  CSV_Item			(_tty,'@',1);		// /dev/ttyAMA0
  if not Str2Num(_speed,baudr) then baudr:=9600;
  if FileExists(_tty) then
  begin
    sh:=Trimme('stty -F '+_tty+' '+Num2Str(baudr,0)+' '+_par,3);
SAY(lvl,sh);
    res:=call_external_prog(LOG_NONE,sh,sh);
  end else LOG_Writeln(LOG_ERROR,'TTY_sttySpeed: device does not exist: '+_tty);
  TTY_sttySpeed:=res;
end;

procedure ERR_MGMT_UPD(errhdl:integer; cmdcode,datalgt:integer; modus:boolean);
begin
  try
    with ERR_MGMT[errhdl] do
	begin
	  if modus then
	  begin // ok part
// reset err counter <0: immediate 0:never (sumup all err) >0: after x msec
	    TSokOld:=TSok; TSok:=now;
		if (MilliSecondsBetween(TSok,TSerr)>=AutoReset_ms)
		  then begin RDerr:=0; WRerr:=0; CMDerr:=0; end;
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
  except
  end;
end;

function  ERR_MGMT_GetInfo(errhdl,modus:integer):longword;
var err:longword;
begin
  try
    with ERR_MGMT[errhdl] do 
    begin 
	  case modus of
	    2:	  err:=AutoReset_ms;
	  	1:	  err:=MAXerr; 
	  	else  err:=RDerr+WRerr+CMDerr;
	  end; // case
	end; // with
  except
	case modus of
	  2:	err:=0;
	  1:	err:=0; 
	  else	err:=MaxLongword;
	end; // case
  end;
  ERR_MGMT_GetInfo:=err;
end;

function  ERR_MGMT_GetErrCnt(errhdl:integer):longword;
begin ERR_MGMT_GetErrCnt:=ERR_MGMT_GetInfo(errhdl,0); end;

function  ERR_MGMT_GetMaxErrCnt(errhdl:integer):longword;
begin ERR_MGMT_GetMaxErrCnt:=ERR_MGMT_GetInfo(errhdl,1); end;

function  ERR_MGMT_STAT(errhdl:integer):boolean;
var ok:boolean;
begin
  try
    with ERR_MGMT[errhdl] do begin ok:=((RDerr+WRerr+CMDerr)<=MAXerr); end;
  except
	ok:=false;
  end;
  ERR_MGMT_STAT:=ok;
end;

function  ERR_NEW_HNDL(adr:word; descr:string; maxerrs,AutoResetMsec:longword):integer; 
var h:integer;
begin 
  SetLength(ERR_MGMT,(Length(ERR_MGMT)+1)); 
  h:=(Length(ERR_MGMT)-1); 
  if (h>=0) then 
  begin
    with ERR_MGMT[h] do
	begin
	  addr:=adr; desc:=descr; 
	  RDErr:=0; WRErr:=0; CMDerr:=0; MaxErr:=maxerrs;
	  TSok:=now; TSokOld:=TSok; TSerr:=TSok; TSerrOld:=TSerr;
// 	  reset err counter <0: immediate 0:never (sumup all err) >0: after x msec
	  AutoReset_ms:=AutoResetMsec;
	end; // with
  end;
  ERR_NEW_HNDL:=h;
end;

procedure ERR_Report(errhdl:integer);
var _lvl:T_ErrorLevel;
begin
  if (Length(ERR_MGMT)>0) and (errhdl<Length(ERR_MGMT)) then
  begin
    with ERR_MGMT[errhdl] do 
    begin 
	  if ERR_MGMT_STAT(errhdl) then _lvl:=LOG_NOTICE else _lvl:=LOG_ERROR;
	  LOG_Writeln(_lvl,	'ERR_MGMT[0x'+HexStr(addr,4)+']: '+desc+
						' ERR RD:'+Num2Str(RDerr,0)+
						' WR:'+Num2Str(WRerr,0)+
						' CMD:'+Num2Str(CMDerr,0)+
						' AutoReset:'+Num2Str(AutoReset_ms,0)+'ms');
    end; // with
  end;
end;

procedure ERR_End(hndl:integer); 
var i:integer;
begin 
  for i:= 1 to Length(ERR_MGMT) do ERR_Report(i-1);
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
    slavepath:=''; masterpath:=ptmx_c; linkpath:=link; 
    fdslave:=-1; rlgt:=-1; ridx:=0; linkflag:=true;
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
				    call_external_prog(LOG_NONE,'unlink '+link+' ; ls -l '+link,sh);
					LOG_ShowStringList(LOG_WARNING,tl);
//			        sleep(500);
				  end;
				  if (not FileExists(link)) then
			      begin
			        call_external_prog(LOG_NONE,'ln -s '+slavepath+' '+link+'; ls -l '+link,sh);
//LOG_ShowStringList(LOG_WARNING,tl);
//					sleep(500);
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
 		          end else LOG_WRITELN(LOG_ERROR,'ptmx: link already exists: '+link);
			      tl.free;
			    end;
			  end else LOG_WRITELN(LOG_ERROR,'ptmx: not created '+slavepath);
		    end else LOG_WRITELN(LOG_ERROR,'ptmx: cannot open '+slavepath);
          end else LOG_WRITELN(LOG_ERROR,'ptmx: cannot get slavepath');
	    end else LOG_WRITELN(LOG_ERROR,'ptmx: cannot unlockpt');
	  end else LOG_WRITELN(LOG_ERROR,'ptmx: cannot grantpt');
    end else LOG_WRITELN(LOG_ERROR,'ptmx: cannot open '+ptmx_c);
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
      if fpwrite(fdmaster,str[1],length(str))<0 then 
      	LOG_Writeln(LOG_ERROR,'TermIO_Write: '+LNX_ErrDesc(fpgeterrno));
	end;
  end;
end;

procedure DoActionOnReceivedInput(s:string); 
// just for Demo. Process can react on InputCommands, written to our device /dev/testbidir
begin write('Received: ',s); end;

procedure Test_BiDirectionDevice_in_UserSpace; // write and read from /dev/testbidir
const maxloops=100; devpath_c='/dev/testbidir';
var termio:Terminal_device_t; loop:longint; str:string;
begin
  loop:=1;
  with termio do
  begin
    writeln('Start of Test_BiDirectionDevice_in_UserSpace, do ',maxloops:0,' loops (user root)');
    if Term_ptmx(termio,devpath_c,0,ECHO) then
    begin
	  fpclose(fdslave);
	  writeln('Screen1: pls. open 2 additional terminal sessions (e.g. with putty to your pi user:root)');
	  writeln('filedescriptor master: ',fdmaster,'   fdslave: ',fdslave);
	  writeln('devpath:    ',devpath_c,' exists:',FileExists(devpath_c));
	  writeln('masterpath: ',masterpath);
	  writeln('slavepath:  ',slavepath);
	  writeln('linkpath:   ',linkpath,' linked to ',slavepath);
	  writeln('do a cat ',linkpath,' on screen2, to see data which was written to master device');
	  writeln('do a echo xxxxx >> ',linkpath,' on screen3 to pass data which the master can read');
	  delay_msec(5000); 
	  writeln('Start to write Hello#<nr> to master device');
      repeat   
	    str:=TermIO_Read(termio,true); 					// async read from master device
		if str<>'' then DoActionOnReceivedInput(str);		// process input data, if something was red
	    TermIO_Write(termio,'Hello#'+Num2Str(loop,0)+LF);	// write to  master device
        delay_msec(1000); inc(loop);
      until (loop>maxloops);
	  writeln('closing '+linkpath);
	  fpclose(fdmaster);
	  writeln('End of Test_BiDirectionDevice_in_UserSpace (you should get an Input/output error on screen2 now)');
    end else writeln('ptmx init failed');
  end;
end;
{$ENDIF}
	  
function  TEMP_LVLset(Temp,Tmax:real):t_ERRORLevel;
var lvl:t_ERRORLevel;
begin
  lvl:=LOG_NONE;
  if not (IsNaN(Temp) or IsNaN(Tmax)) then
  begin
	lvl:=LOG_INFO;	
	if (Temp<=Tmax*RPI_CTempCool_c)	then lvl:=LOG_NOTICE;
	if (Temp>=Tmax*RPI_CTempWarn_c)	then lvl:=LOG_WARNING;
	if (Temp>=Tmax*RPI_CTempHot_c)	then lvl:=LOG_ERROR;
	if (Temp>=Tmax)					then lvl:=LOG_URGENT;
  end;
  TEMP_LVLset:=lvl;
end;

procedure TEMP_Free(var TempStruct:RPI_Temps_t); 
begin  SetLength(TempStruct.TempRec,0); end;

procedure TEMP_Show(var TempStruct:RPI_Temps_t; desc:string);
const lvl=LOG_WARNING;
var i:integer; lvl0,lvlA,lvlB:T_ErrorLevel; sh:string;
begin
  lvlA:=lvl; lvlB:=lvl; lvl0:=LOG_ERROR;
  with TempStruct do
  begin
  LOG_Writeln(lvl0,desc+' @ '+GetXMLTimeStamp(LastUpdate));
  LOG_Writeln(lvl,'HDRname:'+HDRname+' section:'+SECTname+' ARRlgt:'+Num2Str(Length(TempRec),2)+' TempUnit:'+TempUnit);
  LOG_Writeln(lvl,'TempCOOL:'+Num2Str(TempCOOL,0,2)+' TempWARN:'+Num2Str(TempWARN,0,2)+' TempHOT:'+Num2Str(TempHOT,0,2)+' TempMax:'+Num2Str(TempMax,0,2));
  if TempMinObservedNEW then lvlA:=LOG_ERROR;
  if TempMaxObservedNEW then lvlB:=LOG_ERROR;
  sh:='';
  for i:= 1 to Length(TempRec) do 
	sh:=sh+Num2Str(i,0)+'. '+Num2Str(TempRec[i-1].Temp,0,2)+'  ';
  if (sh<>'') then LOG_Writeln(lvl,'TempArr: '+sh);
  LOG_Writeln(lvlA,'TempMinObserved:'+Num2Str(TempMinObserved,0,2)+' @ '+GetXMLTimeStamp(TempMinObsTS)+' Chg:'+Bool2YN(TempMinObservedNEW));
  LOG_Writeln(lvlB,'TempMaxObserved:'+Num2Str(TempMaxObserved,0,2)+' @ '+GetXMLTimeStamp(TempMaxObsTS)+' Chg:'+Bool2YN(TempMaxObservedNEW));
  LOG_Writeln(lvl0,'');
  end; // with
end;

procedure TEMP_Create(var TempStruct:RPI_Temps_t; section,HDR_name,Units:string; ARRlgt:word);
var i:longint;
begin
  with TempStruct do
  begin
//  InitCriticalSection(Temp_CS); TempInfo:=''; TempIdx:=1;
	HDRname:=HDR_name; 
	if (section='') then SECTname:=IniFileDesc.dfltsection else SECTname:=section;
  	TempMax:=RPI_TempAlarmCelsius_c; LastUpdate:=0;	TempUnit:=Units;		
    TempCOOL:=TempMax; TempWARN:=TempMax; TempHOT:=TempMax;  	
    TempMaxObservedNEW:=false; TempMinObservedNEW:=false;
    SetLength(TempRec,ARRlgt);
	for i:= 1 to ARRlgt do 
	begin 
	  with TempRec[i-1] do
	  begin
		Temp:=0; TempLvl:=LOG_NONE;
	  end;
	end;
	TempMinObserved:=TempMax;	TempMinObsTS:=LastUpdate;
	TempMaxObserved:=0;			TempMaxObsTS:=LastUpdate;
  end; // with
end;

procedure TEMP_SaveLimits(var TempStruct:RPI_Temps_t);
begin
//TEMP_Show(TempStruct,'TEMP_SaveLimits');
  with TempStruct do
  begin 
	if TempMinObservedNEW then
	begin
	  BIOS_SetIniString(SECTname,HDRname+'MINobserved',Num2Str(TempMINObserved,0,2)+','+GetXMLTimeStamp(TempMinObsTS)+','+CSV_Item(rpi_rev,';',3));
	  TempMinObservedNEW:=false;
	end;
	if TempMaxObservedNEW then
	begin
	  BIOS_SetIniString(SECTname,HDRname+'MAXobserved',Num2Str(TempMaxObserved,0,2)+','+GetXMLTimeStamp(TempMaxObsTS)+','+CSV_Item(rpi_rev,';',3));
	  TempMaxObservedNEW:=false;
//	  BIOS_CacheUpdate(false);
	end;
  end; // with
end;
(*
Temp CPU:      52.0¡C
Temp COOL:    ²58.0¡C
Temp WARN:    ³75.0¡C
Temp HOT:     ³80.0¡C
Temp ALARM:   ³85.0¡C
Temp MIN:      28.0¡C  2019-12-10 13:01:02 UTC
Temp MAX:      63.0¡C  2020-01-27 16:57:59 UTC
*)
procedure TEMP_LoadLimits(var TempStruct:RPI_Temps_t);
var sh:string;
begin
  with TempStruct do
  begin 
//  CPUtempMAXobserved=68.00,2019-07-25T15:13:59.177+00:00,4B
	sh:=BIOS_GetIniString(SECTname,HDRname+'MAXobserved','',[]);
	if (CSV_Item(sh,3)=CSV_Item(rpi_rev,';',3)) then
  	begin
	  if not Str2Num(CSV_Item(sh,1),TempMaxObserved) 
		then TempMaxObserved:=0;
	  if not GetUTCDateTimefromXMLTimeStamp(CSV_Item(sh,2),TempMaxObsTS) 
		then TempMaxObsTS:=0;
	  SAY(LOG_INFO,HDRname+'Max:'+sh+':'+Num2Str(TempMaxObserved,0,2)+'@'+GetXMLTimeStamp(TempMaxObsTS));
  	end 
  	else 
  	begin // not same cpu
  	  TempMaxObserved:=0; TempMaxObsTS:=0;
  	  LOG_Writeln(LOG_WARNING,HDRname+'Max:'+sh+':'+Num2Str(TempMaxObserved,0,2)+'@'+GetXMLTimeStamp(TempMaxObsTS));
  	end;

//  CPUtempMINobserved=45.00,2019-07-25T13:13:59.177+00:00,4B  	
	sh:=BIOS_GetIniString(SECTname,HDRname+'MINobserved','',[]);
	if (CSV_Item(sh,3)=CSV_Item(rpi_rev,';',3)) then
  	begin
	  if not Str2Num(CSV_Item(sh,1),TempMinObserved) 
		then TempMinObserved:=RPI_TempAlarmCelsius_c;
	  if not GetUTCDateTimefromXMLTimeStamp(CSV_Item(sh,2),TempMinObsTS) 
		then TempMinObsTS:=0;
	  SAY(LOG_INFO,HDRname+'Min:'+sh+':'+Num2Str(TempMinObserved,0,2)+'@'+GetXMLTimeStamp(TempMinObsTS));
  	end 
  	else 
  	begin // not same cpu
  	  TempMinObserved:=RPI_TempAlarmCelsius_c; TempMinObsTS:=0;
  	  LOG_Writeln(LOG_WARNING,HDRname+'Min:'+sh+':'+Num2Str(TempMinObserved,0,2)+'@'+GetXMLTimeStamp(TempMinObsTS));
  	end;
  end; // with
//TEMP_Show(TempStruct,'TEMP_LoadLimits');
end;

function  RPI_Temp(logmsg:boolean):T_ERRORLevel;
var n:longint; tag:longword; sh:string; p:array[0..1] of longword;
begin
//TEMP_Show(RPI_Temps,'RPI_Temp');
  with RPI_Temps do
  begin
//	EnterCriticalSection(Temp_CS); 
	  TempMaxLvl:=LOG_NONE; //TempIdx:=1; //TempInfo:='';
  	  if RPI_FW_property(TAG_STATUS_REQUEST,TAG_GET_MAX_TEMPERATURE,addr(p),sizeof(p))>0
	  	then TempMax:=p[1]/1000 else TempMax:=RPI_TempAlarmCelsius_c; 
	  	
	  TempCOOL:=TempMax*RPI_CTempCool_c;
	  TempWARN:=TempMax*RPI_CTempWarn_c;
 	  TempHOT:= TempMax*RPI_CTempHot_c;	  
  
	  for n:= 1 to Length(TempRec) do
  	  begin
  	    with TempRec[n-1] do
  	    begin
	  	  Temp:=NaN; TempLvl:=LOG_NONE;
	  	  case n of
		  	1: 	 begin sh:='CPU'; tag:=TAG_GET_TEMPERATURE; end; // missing fw tag for GPU temp
		  	else begin sh:='GPU'; tag:=TAG_GET_TEMPERATURE; end;
	  	  end; // case
      	  if RPI_FW_property(TAG_STATUS_REQUEST,tag,addr(p),sizeof(p))>0 then
      	  begin
		  	Temp:=p[1]/1000;
		  	if (Temp>TempMaxObserved) then 
		  	begin
		  	  TempMaxObserved:=Temp;
		  	  TempMaxObsTS:=now;
		  	  TempMaxObservedNEW:=true;
		    end;
		    if (Temp<TempMinObserved) then 
		    begin
		  	  TempMinObserved:=Temp;
		  	  TempMinObsTS:=now;
		  	  TempMinObservedNEW:=true;
		  	end;
      	  	TempLvl:=TEMP_LVLset(Temp,TempMax);
      	  	if TempLvl>=TempMaxLvl then TempMaxLvl:=TempLvl;
//	  	  	TempInfo:=TempInfo+sh+':'+Num2Str((Temp[n-1]),0,1)+TempUnit+';';
	  	  	if logmsg and (TempMaxLvl>=LOG_WARNING) then
		  	  SAY(TempLvl,'RPI_TempAlarm['+sh+']: '+Num2Str(Temp,0,1)+TempUnit+' (AlarmTemp: '+Num2Str(TempWARN,0,1)+TempUnit+')');
      	  end;
      	end; // with
	  end; // for
	  LastUpdate:=now;	
	  RPI_Temp:=TempMaxLvl;
//	LeaveCriticalSection(Temp_CS);
  end; // with
end;

function  RPI_Volt:string;	// core:1.2000V;sdram_c:1.2000V;sdram_i:1.2000V;sdram_p:1.2250V
const volt_c='for src in core sdram_c sdram_i sdram_p ; do echo "$src:$(vcgencmd measure_volts $src|awk -F ''='' ''{print $2}'')" ; done';
var   _ts:TStringlist; i:longint; sh:string; 
begin
  _ts:=TStringList.create; sh:='';
  call_external_prog(LOG_NONE,volt_c,_ts); 
  for i:= 1 to _ts.count do
  begin
	sh:=sh+_ts[i-1];
    if i<_ts.count then sh:=sh+';';
  end;
  _ts.free;
  RPI_Volt:=sh;
end;

function  RPI_FREQs:string;	// arm:600000000;core:250000000;h264:250000000;isp:250000000;...
const frq_c= 'for src in arm core h264 isp v3d uart pwm emmc pixel vec hdmi dpi ; do echo "$src:$(vcgencmd measure_clock $src|awk -F ''='' ''{print $2}'')" ; done';
var   _ts:TStringlist; i:longint; sh:string; 
begin
  _ts:=TStringList.create; sh:='';
  call_external_prog(LOG_NONE,frq_c,_ts); 
  for i:= 1 to _ts.count do
  begin
	sh:=sh+_ts[i-1];
    if i<_ts.count then sh:=sh+';';
  end;
  _ts.free;
  RPI_FREQs:=sh;
end;

function  RPI_ThrottleDesc:string;
// vcgencmd get_throttled
var sh:string;
begin
  sh:='';
  if BIT_Get(RPI_Throttle, 0) then sh:=sh+'under-voltage;';						// 0x00001
  if BIT_Get(RPI_Throttle, 1) then sh:=sh+'arm frequency capped;';				// 0x00002
  if BIT_Get(RPI_Throttle, 2) then sh:=sh+'currently throttled;';				// 0x00004
  if BIT_Get(RPI_Throttle, 3) then sh:=sh+'soft temp limit active;';			// 0x00008
  if BIT_Get(RPI_Throttle,16) then sh:=sh+'under-voltage has occurred;';		// 0x10000
  if BIT_Get(RPI_Throttle,17) then sh:=sh+'arm frequency capped has occurred;'; // 0x20000
  if BIT_Get(RPI_Throttle,18) then sh:=sh+'throttling has occurred;';			// 0x40000
  if BIT_Get(RPI_Throttle,19) then sh:=sh+'soft temp limit has occured;';		// 0x80000
  RPI_ThrottleDesc:=CSV_RemLastSep(sh,';');
end;

procedure RPI_FreqARMGet;
var val:longword; sh:string;
begin
  if (call_external_prog(LOG_NONE,'vcgencmd measure_clock arm',sh)=0) then 
  begin // e.g. frequency(48)=1500398464
	if not Str2Num(Select_Item(RM_CRLF(sh),'frequency(48)=','',2),val) then val:=0;
  end;
  RPI_FreqARMFreq:=val; 
end;

procedure RPI_ThrottleGet;
var val:longword; sh:string;
begin
  if (call_external_prog(LOG_NONE,'vcgencmd get_throttled',sh)=0) then 
  begin // e.g. throttled=0x50005
	if not Str2Num(Select_Item(RM_CRLF(sh),'throttled=','',2),val) then val:=0;
  end;
  RPI_Throttle:=val; 
end;
(*
2:0:
...
6:50005:
...
6:50000:
...
2:0:
... *)
function  RPI_ThrottleThread:ptrint;
const fn_c='/sys/devices/platform/soc/soc:firmware/get_throttled';
var fd:Cint; _cnt,_ThrottleOld:longword; Data:string[10]='          ';
begin
  Thread_SetName('RPI_ThrottleThread'); 
  fd:=fpOpen(fn_c,O_RdOnly);
  if (fd>0) then
  begin 
    _ThrottleOld:=0; _cnt:=0;
	repeat 
	  if (fpLseek(fd,0,Seek_Set)=0) then
	  begin
	    if not Str2Num(copy(Data,1,(fpRead(fd,Data[1],10)-1)),RPI_Throttle) then RPI_Throttle:=0;	
	    if (RPI_Throttle<>_ThrottleOld) then 
	    begin
		  LOG_Writeln(LOG_WARNING,'RPI_ThrottleThread: '+RPI_ThrottleDesc);
		  _ThrottleOld:=RPI_Throttle;
		end else if (RPI_Throttle=0) then delay_msec(1); 
	  end 
	  else 
	  begin
		LOG_Writeln(LOG_ERROR,'RPI_ThrottleThread: fpLseek');
//	  	delay_msec(10); 
	  	inc(_cnt);
	  end;
	until terminateProg or (_cnt>=1);
	fpClose(fd);
  end else LOG_Writeln(LOG_ERROR,'RPI_ThrottleThread: can not open '+fn_c);
  RPI_Throttle:=0;
  EndThread;  
  RPI_ThrottleThread:=0;
end;

procedure TMR_Init(var TMR_struct:TMR_struct_t);
begin
  with TMR_struct do
  begin
	TMR_GetStartTime(TMR_struct);	tim_ende:=tim_start;
	tim_ns:=0;						cnt:=0;
	tim_ns_min:=high(int64);		tim_ns_max:=low(int64);
  end; // end;
end;

procedure TMR_GetStartTime(var TMR_struct:TMR_struct_t);
begin
  with TMR_struct do
  begin
	clock_gettime(CLOCK_REALTIME,@tim_start); 
  end; // with
end;

procedure TMR_GetEndTime(var TMR_struct:TMR_struct_t);
begin
  with TMR_struct do
  begin
	clock_gettime(CLOCK_REALTIME,@tim_ende); 
	tim_ns:=NanoSecondsBetween(tim_ende,tim_start);
	MinMax(tim_ns,tim_ns_min,tim_ns_max);
	inc(cnt);
  end; // with
end;

function  RPI_GPU_MEM_BASE:longword; begin RPI_GPU_MEM_BASE:=GPU_MEM_BASE; end;

function  RPI_INFO_Split(info:string; var labl,valu:string):boolean;
begin // in: CPU:41.8'C out: labl:CPU value:41.8'C
  labl:=CSV_Item(info,':',1);
  valu:=CSV_Item(info,':',2);
  RPI_INFO_Split:=((labl<>'') and (valu<>''));
end;

procedure Get_SDcard_RDSpeed;
// requires installed sw package 'hdparm' -> apt-get install hdparm
var cmd,sh:string;
begin
  try
//Timing buffered disk reads: 128 MB in  3.01 seconds =  42.47 MB/sec
  cmd:='hdparm -t /dev/mmcblk0 2>/dev/null | grep -i ''timing'' | awk -F ''='' ''{print $2}''';
  call_external_prog(LOG_NONE,cmd,sh);
  sh:=Trimme(sh,3); // 42.47 MB/sec
  if (sh<>'') then SD_speedRD:=sh;
  except
    
  end;
end;

procedure Get_CPU_INFO_Init;   
// https://en.wikipedia.org/wiki/Raspberry_Pi
const proc1_c='cat /proc/cpuinfo'; proc2_c='cat /sys/devices/system/cpu/cpu0/cpufreq/cpuinfo'; 
	  proc3_c='cat /etc/debian_version'; proc4_c='lsb_release -a 2>/dev/null | grep escription | awk -F '':'' ''{print $2}''';
var ts:TStringlist; sh:string; anz:longint; lw:longword; 
  function cpuinfo_unix(infoline:string; var cnt:longint):string;
  var s:string; i:integer;
  begin
    s:=''; i:=1; cnt:=0;
    while (i<=ts.count) do 
    begin 
      if Pos(Upper(infoline),Upper(ts[i-1]))=1 then 
      begin 
    	s:=ts[i-1]; inc(cnt); // i:=ts.count+1; 
      end; 
      inc(i); 
    end;
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
  function  RPI_SetInfo(cpurevs,desc,manuf:string; cpurev:real; I2Cbusnr,gpioidx,slednr,pincnt,cores:byte;memsizMB:word):string;
//          RPI_SetInfo('0010', 'B', 'Sony UK',    1.0,         0,       2,      47,    40,    1,         512);
  begin
    connector_pin_count:=pincnt; cpu_rev_num:=cpurev; I2C_busnum:=I2Cbusnr; 
    GPIO_map_idx:=gpioidx; 	status_led_GPIO:=slednr; 
    RPI_SetInfo:=	'rev'+Num2Str(cpurev,0,1)+';'+
					Num2Str(memsizMB,0)+'MB;'+
					desc+';'+cpu_hw+';'+cpurevs+';'+
	                Num2Str(connector_pin_count,0)+';'+
	                Num2Str(cores,0)+';'+
	                cpu_machine+';'+
	                manuf;		//	  rev1.0;512MB;B;BCM2709;0010;40;1;Sony UK
  end;
  function  AnalyzeRevCode(cpurevs:string):string;
// https://www.raspberrypi.org/documentation/hardware/raspberrypi/revision-codes/README.md
  var F,M,C,P,R,NOQuuuWu:byte; sh:string;
  begin
	sh:='';
	if Str2Num('0x'+cpurevs,lw) then
	begin
	  F:=((lw and $00800000) shr 23);	// New flag		1Bit
	  if (F=0) then
	  begin // 0: old style
	  	case (lw and $ff) of
		  $00: sh:=RPI_SetInfo(cpurevs,'B',  '',		1.0, 0, 1, 16, 26, 1, 256);
		  $01: sh:=RPI_SetInfo(cpurevs,'B',  '',		1.0, 0, 1, 16, 26, 1, 256);
		  $02: sh:=RPI_SetInfo(cpurevs,'B',  'Egoman',	1.0, 0, 1, 16, 26, 1, 256);
		  $03: sh:=RPI_SetInfo(cpurevs,'B',  'Egoman',	1.0, 0, 1, 16, 26, 1, 256);
	      $04: sh:=RPI_SetInfo(cpurevs,'B',  'Sony UK',	2.0, 1, 2, 16, 26, 1, 256);
	      $05: sh:=RPI_SetInfo(cpurevs,'B',  'Qisda',	2.0, 1, 2, 16, 26, 1, 256);
	      $06: sh:=RPI_SetInfo(cpurevs,'B',  'Egoman',	2.0, 1, 2, 16, 26, 1, 256);
		  $07: sh:=RPI_SetInfo(cpurevs,'A',  'Egoman',	2.0, 1, 2, 16, 26, 1, 256);
		  $08: sh:=RPI_SetInfo(cpurevs,'A',  'Sony UK',	2.0, 1, 2, 16, 26, 1, 256);
		  $09: sh:=RPI_SetInfo(cpurevs,'A',  'Qisda',	2.0, 1, 2, 16, 26, 1, 256);
		  $0d: sh:=RPI_SetInfo(cpurevs,'A',  'Egoman',	2.0, 1, 2, 16, 26, 1, 256);
		  $0e: sh:=RPI_SetInfo(cpurevs,'A',  'Sony UK',	2.0, 1, 2, 16, 26, 1, 256);
		  $0f: sh:=RPI_SetInfo(cpurevs,'B',  'Egoman',	2.0, 1, 2, 16, 26, 1, 512);
		  $10: sh:=RPI_SetInfo(cpurevs,'B+', 'Sony UK',	1.0, 0, 2, 47, 40, 1, 512);
		  $11: sh:=RPI_SetInfo(cpurevs,'CM1','Sony UK',	1.1, 0, 2, 47,  0, 1, 512); 
		  $12: sh:=RPI_SetInfo(cpurevs,'A+', 'Sony UK',	1.1, 0, 2, 47, 40, 1, 256);
		  $13: sh:=RPI_SetInfo(cpurevs,'B+', 'Embest',	1.2, 0, 2, 47, 40, 1, 512);
		  $14: sh:=RPI_SetInfo(cpurevs,'CM1','Embest',	1.1, 0, 2, 47,  0, 1, 512); 
		  $15: sh:=RPI_SetInfo(cpurevs,'A+', 'Embest',	1.1, 0, 2, 47, 40, 1, 256);
		  else LOG_Writeln(LOG_ERROR,'Get_CPU_INFO_Init: (0x'+HexStr(lw,8)+') unknown rev:'+cpurevs+': RPI not supported');
		end; // case
	  end
	  else
	  begin // 1: new style flag
	  	connector_pin_count:=40;	GPIO_map_idx:=2;	cpu_hw:='';
		status_led_GPIO:=47;		I2C_busnum:=1; 
// 		NOQuuuWuFMMMCCCCPPPPTTTTTTTTRRRR			// 32Bit
		R:=			((lw and $0000000f));			// Revision		4Bit
		RPI_bType:=	((lw and $00000ff0) shr  4);	// Type			8Bit
		P:=			((lw and $0000f000) shr 12);	// Processor	4Bit
		C:=			((lw and $000f0000) shr 16);	// Manufacturer	4Bit
		M:=			((lw and $00700000) shr 20);	// Memory size	3Bit
		NOQuuuWu:=	((lw and $f0000000) shr 28); 	// combined 	8Bit
//		writeln(cpurevs,' F:',F,' R:',R,' T:',T,' P:',P,' C:',C,' M:',M,' NOQW:',NOQW);
// a020d3 F:1 R:3 T:13 P:2 C:0 M:2
// rev1.3;1GB;3B+;BCM2837;a020d3;40;4;Sony UK
// rev1.1;2GB;4B;BCM2711;b03111;40;4;armv7l;Sony UK
		sh:=sh+'rev1.'+Num2Str(R,0)+';';
		case M of // Memory size
		    0: sh:=sh+'256MB';
		    1: sh:=sh+'512MB';
		    2: sh:=sh+'1GB';
		    3: sh:=sh+'2GB';
		    4: sh:=sh+'4GB';
		    5: sh:=sh+'8GB';
		  else sh:=sh+'0x'+HexStr(M,2);
		end; // case 
		sh:=sh+';';
		case RPI_bType of // Type
		    0: sh:=sh+'A';
		    1: sh:=sh+'B';
		    2: sh:=sh+'A+';
		    3: sh:=sh+'B+';
		    4: sh:=sh+'2B';
		    5: sh:=sh+'Alpha (early prototype)';
		    6: sh:=sh+'CM1';
		    8: sh:=sh+'3B';
		    9: sh:=sh+'Zero';
		  $0a: sh:=sh+'CM3';
		  $0c: sh:=sh+'Zero W';
		  $0d: sh:=sh+'3B+';
		  $0e: sh:=sh+'3A+';
		  $0f: sh:=sh+'internal use only';
		  $10: sh:=sh+'CM3+';
		  $11: sh:=sh+'4B';
		  $13: sh:=sh+'400';
		  $14: sh:=sh+'CM4';
		  else sh:=sh+'0x'+HexStr(RPI_bType,2);
		end; // case					
		sh:=sh+';';
		case P of // Processor
		    0: cpu_hw:='BCM2835';
		    1: cpu_hw:='BCM2836';
		    2: cpu_hw:='BCM2837';
		    3: cpu_hw:='BCM2711';
		  else cpu_hw:='0x'+HexStr(P,2);
		end; // case
		sh:=sh+cpu_hw+';'+cpurevs+';'+Num2Str(connector_pin_count,0)+';'+Num2Str(cpu_cores,0)+';'+cpu_machine+';';
		case C of // Manufacturer
		    0: sh:=sh+'Sony UK';
		    1: sh:=sh+'Egoman';
		    2: sh:=sh+'Embest';
		    3: sh:=sh+'Sony Japan';
		    4: sh:=sh+'Embest';
		    5: sh:=sh+'Stadium';
		  else sh:=sh+'0x'+HexStr(C,2);
		end; // case
		sh:=sh+';0x'+HexStr(NOQuuuWu,2);
	  end;
	end; // else Log_Writeln(LOG_ERROR,'Get_CPU_INFO_Init: Rev:'+cpurevs+' Hardware:'+cpu_hw+' Processor:'+cpu_proc+' no known platform');
	AnalyzeRevCode:=sh;
  end;

begin
   cpu_snr:='';   cpu_hw:='';   cpu_proc:=''; cpu_rev:=''; cpu_mips:=''; cpu_feat:=''; cpu_rev_num:=0;
   cpu_fmin:='';  cpu_fcur:=''; cpu_fmax:=''; os_rev:='';  uname:=''; 	 cpu_machine:=''; lsb_rel:='';
   cpu_cores:=0;  I2C_busnum:=0; status_led_GPIO:=0;  	   whoami:='';
   RPI_bType:=0;  RPI_ThrottleGet; RPI_FreqARMGet;
   for lw:=1 to max_pins_c do RPIHDR_Desc[lw]:='';
   connector_pin_count:=40; 
   cpu_freq:= 700000000; pll_freq:=2000000000; 
  {$IFDEF UNIX}  
    call_external_prog(LOG_NONE,'whoami',whoami);
	ts:=TStringList.Create;
	call_external_prog(LOG_NONE,proc3_c,sh); 			 os_rev:= 		RM_CRLF(sh); 
	call_external_prog(LOG_NONE,proc2_c+'_min_freq',sh); cpu_fmin:=		RM_CRLF(sh);
	call_external_prog(LOG_NONE,proc2_c+'_cur_freq',sh); cpu_fcur:=		RM_CRLF(sh);
	call_external_prog(LOG_NONE,proc2_c+'_max_freq',sh); cpu_fmax:=		RM_CRLF(sh);
	call_external_prog(LOG_NONE,'uname -srvmo',		sh); uname:=   		RM_CRLF(sh);
	call_external_prog(LOG_NONE,'uname -m',			sh); cpu_machine:=	RM_CRLF(sh);
	call_external_prog(LOG_NONE,proc4_c,sh); lsb_rel:=Trimme(GetPrintableChars(sh,' ',#$7f),4);

    if not getvcgencmd('arm', cpu_freq)	then cpu_freq:= 700000000; 	
    lw:=round(2*pllc_freq_c/1000000);
	pll_freq:=floor(2400 div lw)*lw*1000000; if pll_freq>0 then ;
//  writeln('CPU Freq: ',cpu_fmin,' ',cpu_fcur,' ',cpu_fmax,' ',cpu_freq,' ',pllc_freq_c,' ',pll_freq);
	if call_external_prog(LOG_NONE,proc1_c,ts)=0 then
    begin
      I2C_busnum:=1; 	status_led_GPIO:=47;   
      cpu_rev_num:=0; 	GPIO_map_idx:=2; 
	  cpu_snr:= cpuinfo_unix('Serial',	 anz);		// e.g. 0000...
	  cpu_hw:=  cpuinfo_unix('Hardware', anz);		// e.g. BCM2709
	  cpu_proc:=cpuinfo_unix('Processor',cpu_cores);
	  cpu_mips:=cpuinfo_unix('BogoMIPS', anz);
	  cpu_feat:=cpuinfo_unix('Features', anz);
	  cpu_rev:= cpuinfo_unix('Revision', anz);		// e.g. a01041 
	  cpu_rev:= AnalyzeRevCode(cpu_rev); 			// new style
//	  cpu_rev:= AnalyzeRevCode('c03112'); 			// for test
//	  writeln(cpu_rev);
//	  writeln(cpu_rev_num);
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

procedure RPI_HDR_SetDesc(HWPin:longint; desc:string);
begin if (HWPin>=1) and (HWPin<=max_pins_c) then RPIHDR_Desc[HWPin]:=copy(desc,1,mdl); end;

function  RPI_mmap_get_info(modus:longint):longword;
// https://github.com/raspberrypi/userland/blob/master/host_applications/linux/libs/bcm_host/bcm_host.c
var valu:longword; li,ofs:longint; sh,sh1,sh2,sh3,sh4:string;
begin 
  valu:=0;
  case modus of
	 1,2:	valu:=PAGE_SIZE;
	 30: 	begin // OLD get peri base from device tree
// e.g. for ZeroW:	7e0000002000000002000000...
//		3B+:		7e0000003f00000001000000400000004000000000001000
//		4B:			7e00000000000000fe000000018000007c00000000000000fc000000020000004000000000000000ff80000000800000
			  call_external_prog(LOG_NONE,'xxd -ps -c250 '+PrepFilePath(LNX_DevTree+'/soc/ranges'),sh);
			  ofs:=8;
			  if (Upper(RPI_hw)='BCM2711') then ofs:=16;	// rpi4
			  if not Str2Num('$'+copy(sh,ofs+1,8),valu) then valu:=0;		// $20000000
			  if (valu=0) then
			  begin // old variant
				valu:=BCM2709_PBASE; // for BCM2709 and BCM2835
				if (Upper(RPI_hw)='BCM2708') then valu:=BCM2708_PBASE;	// for old RPI
				if (Upper(RPI_hw)='BCM2711') then valu:=BCM2711_PBASE;	// rpi4
			  end;		 
			end;
	31:		begin // get peri size
			  valu:=BCM270x_PSIZ_Byte;
			end;
	3:		begin // NEW get peri base with iomem
(*	cat /proc/iomem | grep gpio@
	rpi4:	 fe200000-fe2000b3 : gpio@7e200000
	rpi2-3x: 3f200000-3f2000b3 : gpio@7e200000
	zerow:	 20200000-202000b3 : gpio@7e200000	*)
			  call_external_prog(LOG_NONE,'cat /proc/iomem | grep gpio@',sh); // 3f200000-3f2000b3 : gpio@7e200000
			  sh:=CSV_Item(Trimme(sh,3),'-',1);								// 3f200000
(*			  if Str2Num('$'+sh,valu) then valu:=valu-GPIO_BASE_OFS			// 3f000000
									else valu:=RPI_mmap_get_info(30); *)					
			  if not Str2Num('$'+sh,valu) then 
			  begin
			  	valu:=RPI_mmap_get_info(30);
			  	LOG_Writeln(LOG_WARNING,'RPI_mmap_get_info['+Num2Str(modus,0)+']: get peri base with iomem');
			  end else valu:=valu-GPIO_BASE_OFS								// 3f000000
//			  writeln('PBase: 0x',HexStr(valu,8));
		   	end;		   
	 4   : begin {$IFDEF UNIX} valu:=1; {$ELSE} valu:=0; {$ENDIF} end;      (* if run_on_unix ->1 else 0 *)
	 5   : begin 
	 		 sh:={$i %FPCTARGETCPU%};	// arm / aarch64
	 		 if (Upper(sh)='ARM') or (Upper(sh)='AARCH64') then valu:=1; (* if run_on_ARM  ->1 else 0 *)
	 	   end;
	 6	 : begin valu:=1; end;								// if RPI_Piggyback_board_available -> 1 dummy, for future use 
	 7   : if ((RPI_mmap_get_info(5)=1) and 
	           ((Upper(RPI_hw)='BCM2708') or
	            (Upper(RPI_hw)='BCM2835') or 				// new in Linux raspberrypi 4.9.11-v7+ #971 SMP Mon Feb 20 20:44:55 GMT 2017 armv7l GNU/Linux 
			    (Upper(RPI_hw)='BCM2836') or 
			    (Upper(RPI_hw)='BCM2837') or 
			 	(Upper(RPI_hw)='BCM2711') or 				// rpi4
			    (Upper(RPI_hw)='BCM2709'))) then valu:=1;	// runs on known rpi HW
	 8	 : begin valu:=1; end;								// if PiFaceBoard_board_available -> 1 dummy, for future use *)
	 9   : begin 
	 	     call_external_prog(LOG_NONE,'uname -v',sh); 						// e.g. #970 SMP Mon Feb 20 19:18:29 GMT 2017
	 	     sh:=CSV_Item(sh,' ',1);											// #970
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
// nodereturn:=StrHexStr(nodereturn); // if return is ASCII text
  end;
  RPI_BCM2835_GetNodeValue:=res;
end;
  
function  RPI_FW_open:longint;
begin
  with rpi_fw_api do
  begin
	if (hndl=-1) then
	begin
	  hndl:=fpopen(rpi_fw_dev, O_NONBLOCK);
	  if (hndl=-1) then LOG_Writeln(LOG_ERROR,'RPI_FW_open: can not open '+rpi_fw_dev);
	end;
	RPI_FW_open:=hndl;
  end; // with
end;

procedure  RPI_FW_close;
begin
  with rpi_fw_api do
  begin
	if (hndl<>-1) then 
	  if (fpclose(hndl)=-1) then LOG_Writeln(LOG_ERROR,'RPI_FW_close: can not close '+rpi_fw_dev);
  end; // with
end;

function  RPI_FW_property(req,tag:longword; tag_data:pointer; buf_size:byte):longint;
// https://github.com/6by9/rpi3-gpiovirtbuf
// https://github.com/AndrewFromMelbourne/raspi_serialnumber/blob/master/serialnumber_mailbox.c
var res:longint; p:array[0..((256 div 4)+6)] of longword; //n:longint;
begin
  res:=-1;
  if (rpi_fw_api.hndl<>-1) then
  begin
	p[0]:=(5+1 + (buf_size div 4)) * sizeof(tag);
	p[1]:=req;						// TAG_STATUS_REQUEST
	p[2]:=tag;						// tag
	p[3]:=buf_size;					// buf_size
	p[4]:=0;						// req_resp_size
	Move(tag_data^,p[5],buf_size);	// Move(src^, dest^, size);
	p[5+(buf_size div 4)]:=TAG_PROPERTY_END;
//	for n:=0 to (5+(buf_size div 4)) do writeln(n:2,'. ',HexStr(p[n],8)); writeln;	
{$RANGECHECKS OFF} 				
	if (fpioctl(rpi_fw_api.hndl,IOCTL_TAG_PROPERTY,addr(p[0]))<>-1) then
	begin
	  if (p[1]=TAG_STATUS_SUCCESS) then
	  begin
//		for n:=0 to (5+(buf_size div 4)) do writeln(n:2,'. ',HexStr(p[n],8));	
		Move(p[5],tag_data^,buf_size);
		res:=p[4] and $ff;
	  end else LOG_Writeln(LOG_ERROR,'RPI_FW_property: firmware returned 0x'+HexStr(p[1],8));		
	end else LOG_Writeln(LOG_ERROR,'RPI_FW_property: ioctl: IOCTL_TAG_PROPERTY: '+LNX_ErrDesc(fpgeterrno));  
{$RANGECHECKS ON}
  end; // else LOG_Writeln(LOG_ERROR,'RPI_FW_property['+HexStr(req,2)+'/0x'+HexStr(tag,8)+']: device not opened '+rpi_fw_dev+' use InitRPIfw flag at RPI_HW_Start');
  RPI_FW_property:=res;
end;

function  MACpretty(macstr:string):string;
var n:longint; sh,MAChexStr:string;
begin
  sh:=''; MAChexStr:=StrHex(macstr);
  for n:=1 to Length(MAChexStr) do sh:=sh+HexStr(ord(MAChexStr[n]),2)+':';
  MACpretty:=CSV_RemLastSep(sh,':');
end;

function  RPI_FW_Info(req,tag:longword; var FWinfo:string):boolean;
const mm=50;
var _ok:boolean; n,bcnt,wcnt:longint; p:array[0..mm] of longword;
begin
  _ok:=false;
  bcnt:=RPI_FW_property(req,tag,addr(p),sizeof(p)); 
  _ok:=(bcnt>0);
  wcnt:=(bcnt div 4); bcnt:=(bcnt mod 4);
  if _ok then
  begin 
	case tag of
		TAG_GET_BOARD_MAC_ADDRESS:
			begin
			  p[0]:= swap(Hi(p[0])) or (swap(Lo(p[0])) shl 16);
			  p[1]:= swap(Lo(p[1]));
			  FWinfo:=MACpretty(HexStr(p[0],8)+copy(HexStr(p[1],8),8+1-bcnt*2,bcnt*2));
			end;
		TAG_GET_FIRMWARE_REVISION:
			begin
			  FWinfo:=FormatDateTime('YYYY-MM-DD"T"hh:mm:ss',UnixToDateTime(p[0]));
			end;
		TAG_GET_CLOCK_RATE:
			begin
			  FWInfo:='ClockID 0x'+HexStr(p[0],8)+' @ '+Num2Str(p[1],0)+'Hz';
			end;
	  else 	begin
	  		  FWinfo:='';
	  		  if bcnt>0 then FWinfo:=FWinfo+copy(HexStr(p[wcnt],8),8+1-bcnt*2,bcnt*2);
			  for n:=wcnt downto 1 do FWinfo:=FWinfo+HexStr(p[n-1],8);
	  		end;
	end; // case
  end;
  RPI_FW_Info:=_ok;
end;

procedure RPI_FW_test;
const mm=50;
var i:longint; p:array[0..mm] of longword; lw:longword; info:string; // dt1,dt2,dt3:TDateTime; sh:string;

  procedure ShowArr(msg:string; cnt:longint);
  var _n,_cnt:longint;
  begin 
    if cnt>0 then 
    begin
	  writeln(msg+'(',cnt,'byte):');
      _cnt:=(cnt div 4); if (cnt mod 4)>0 then inc(_cnt);
	  for _n:=1 to _cnt do writeln(_n:4,'. 0x',HexStr(p[_n-1],8));
    end;	
  end;

begin
  RPI_FW_open;	// no need, if rpi_hal was init with InitRPIfw flag
  
  i:=RPI_FW_property(TAG_STATUS_REQUEST,TAG_GET_BOARD_REVISION,addr(p),sizeof(p)); 	ShowArr('rev',i); 
  if RPI_FW_Info(TAG_STATUS_REQUEST,TAG_GET_BOARD_REVISION,info) then writeln(info);	writeln;
  
  i:=RPI_FW_property(TAG_STATUS_REQUEST,TAG_GET_BOARD_SERIAL,addr(p),sizeof(p)); 	ShowArr('snr',i); 
  if RPI_FW_Info(TAG_STATUS_REQUEST,TAG_GET_BOARD_SERIAL,info) then writeln(info);	writeln;
  
  i:=RPI_FW_property(TAG_STATUS_REQUEST,TAG_GET_BOARD_MAC_ADDRESS,addr(p),sizeof(p)); ShowArr('MAC',i); 
  if RPI_FW_Info(TAG_STATUS_REQUEST,TAG_GET_BOARD_MAC_ADDRESS,info) then writeln(info);writeln;
  
  i:=RPI_FW_property(TAG_STATUS_REQUEST,TAG_GET_FIRMWARE_REVISION,addr(lw),sizeof(lw));ShowArr('fw',i); 
  if RPI_FW_Info(TAG_STATUS_REQUEST,TAG_GET_FIRMWARE_REVISION,info) then writeln(info);writeln;
  
  p[0]:=$3; // get ARM clock
  i:=RPI_FW_property(TAG_STATUS_REQUEST,TAG_GET_CLOCK_RATE,addr(lw),sizeof(lw));ShowArr('ClockARM',i); 
  if RPI_FW_Info(TAG_STATUS_REQUEST,TAG_GET_CLOCK_RATE,info) then writeln(info);writeln;

  if RPI_FW_property(TAG_STATUS_REQUEST,TAG_GET_TEMPERATURE,addr(p),8)>0
	then writeln('temp: 0x',HexStr(p[1],8),' ',(p[1]/1000):5:2,' celsius'); 
  
  if RPI_FW_property(TAG_STATUS_REQUEST,TAG_GET_MAX_TEMPERATURE,addr(p),8)>0
	then writeln('tmax: 0x',HexStr(p[1],8),' ',(p[1]/1000):5:2,' celsius');
	
  if RPI_FW_property(TAG_STATUS_REQUEST,TAG_GET_VC_MEMORY,addr(p),8)>0
	then writeln('VCmem:  0x',HexStr(p[1],8),' ',p[1]:10,' Bytes @ 0x'+HexStr(p[0],8));
	
  if RPI_FW_property(TAG_STATUS_REQUEST,TAG_GET_ARM_MEMORY,addr(p),8)>0
	then writeln('ARMmem: 0x',HexStr(p[1],8),' ',p[1]:10,' Bytes @ 0x'+HexStr(p[0],8));
	
  p[0]:=$3; // get ARM clock
  i:=RPI_FW_property(TAG_STATUS_REQUEST,TAG_GET_CLOCK_RATE,addr(p),sizeof(p)); 		
  if i>0 then begin ShowArr('ClockArm',i); writeln(p[1],'Hz'); writeln; end;
  
  p[0]:=$4; // get Core clock
  i:=RPI_FW_property(TAG_STATUS_REQUEST,TAG_GET_CLOCK_RATE,addr(p),sizeof(p)); 		
  if i>0 then begin ShowArr('ClockCore',i); writeln(p[1],'Hz'); writeln; end;

  p[0]:=$3; // get config of gpio 3
  i:=RPI_FW_property(TAG_STATUS_REQUEST,TAG_GET_GPIO_CONFIG,addr(p),sizeof(p));		ShowArr('GPIO3 config',i);	writeln;																	

//i:=RPI_FW_property(TAG_STATUS_REQUEST,TAG_GET_CLOCKS,addr(p),sizeof(p)); 			ShowArr('clocks',i); 		writeln;
  
(*dt1:=now;		// speed testing
  writeln(GetXMLTimeStamp(dt1));
  for lw:=1 to 1000 do call_external_prog(LOG_NONE,'cat '+rpi_cpu_temp_dev_c,sh);	// takes 70secs
  dt2:=now; writeln(GetXMLTimeStamp(dt2));
  
  for lw:=1 to 1000 do RPI_FW_property(TAG_GET_TEMPERATURE,addr(p),8);		// takes 30msecs !!
  dt3:=now;	writeln(GetXMLTimeStamp(dt3)); *)
  
//RPI_FW_close; no need to close is done automatically by exit procedure
end;

//RPI_MBX_msg_t

//#define MAILBOX ((volatile __attribute__((aligned(4))) struct MailBoxRegisters*)(uintptr_t)(RPi_IO_Base_Addr + 0xB880));
// http://www.valvers.com/open-software/raspberry-pi/step05-bare-metal-programming-in-c-pt5/
// https://github.com/vanvught/rpidmx512/blob/master/lib-bcm2835/src/bcm2835_vc.c

procedure RPI_MBX_msgshow(msgptr:RPI_MBX_msgPTR_t);
begin
  with msgptr^ do
  begin
	writeln('  msg_size:      0x',HexStr(msg_size,8));
	writeln('  request_code:  0x',HexStr(request_code,8));
//	with tag do
	begin
	  writeln('    tag_id:      0x',HexStr(tag_id,8));
	  writeln('    buffer_size: 0x',HexStr(buffer_size,8));
	  writeln('    data_size:   0x',HexStr(data_size,8)); 
	  writeln('    dev_id:      0x',HexStr(dev_id,8)); 
	  writeln('    val:         0x',HexStr(val,8)); 		
	end; // with
	writeln('  end_tag:       0x',HexStr(end_tag,8));
  end; // with
end;

procedure RPI_MBX_msgfill(var msg:RPI_MBX_msg_t; reqcode,tagid,bsiz,dsiz,devid,value:longword);
begin
  with msg do
  begin
	msg_size:=		sizeof(msg);
	request_code:=	reqcode;		// BCM2837_MBOX_REQUEST_CODE = $00000000;
//	with tag do
	begin
	  tag_id:=		tagid;
	  buffer_size:=	bsiz;			// ResponseLength
	  data_size:=	dsiz;			// RequestLength
	  dev_id:=		devid;
	  val:=			value;		
	end; // with
	end_tag:=		0;				// structure terminator
  end; // with
end;

function  RPI_MBX_empty:boolean;
const RPI3_MAILBOX_TIMEOUT=1000;
var _ok:boolean; lw:longword; timo:TDateTime;
begin
  _ok:=true; SetTimeOut(timo,RPI3_MAILBOX_TIMEOUT);
  while _ok and ((BCM_GETREG(MBX_STATUS0) and MB_EMPTY)<>MB_EMPTY) do
  begin 
    lw:=BCM_GETREG(MBX_READ0); if lw=0 then ; // dummy
	_ok:=(not TimeElapsed(timo));
	delay_msec(1);
  end;
  RPI_MBX_empty:=_ok;
end;

// http://www.valvers.com/open-software/raspberry-pi/step05-bare-metal-programming-in-c-pt5/
// https://www.raspberrypi.org/forums/viewtopic.php?f=72&t=218406&sid=9f24e8b53926acf4c0533b3ec29f5e61
// https://github.com/raspberrypi/userland/blob/master/host_applications/linux/apps/vcmailbox/vcmailbox.c
function  RPI_MBX_read(channel:longword):longword;
// does not work, work in progress
const RPI3_MAILBOX_TIMEOUT=1000;
var _ok:boolean; _value:longword; timo:TDateTime;
begin
  _ok:=false; _value:=MB_CHANNEL_ERROR;
  if (channel<=MB_CHANNEL_GPU) then
  begin
	_ok:=true; SetTimeOut(timo,RPI3_MAILBOX_TIMEOUT);
	repeat
	  while ((BCM_GETREG(MBX_STATUS0) and MB_EMPTY)<>0) and _ok do
	  begin // wait until data is avail in MBX or timeout
	  	_ok:=(not TimeElapsed(timo));
	  	delay_msec(1); // needed ????
	  end;
	  if _ok then _value:=BCM_GETREG(MBX_READ0);
writeln('read1: 0x',HexStr(_value,8),' ',_ok);
	until ((_value and $f)=channel) or (not _ok);
	if (not _ok) then
	begin
	  LOG_Writeln(LOG_ERROR,'RPI_MBX_read['+HexStr(channel,2)+']: timeout');
	  _value:=MB_CHANNEL_ERROR;
	end else _value:=_value shr 4; 
  end else LOG_Writeln(LOG_ERROR,'RPI_MBX_read['+HexStr(channel,2)+']: wrong channel 0x'+HexStr(channel,2));
writeln('read2: 0x',HexStr(_value,8),' ',_ok);
  RPI_MBX_read:=_value;
end;

function  RPI_MBX_write(channel,value:longword; xxx:boolean):boolean;
// https://github.com/raspberrypi/documentation/blob/JamesH65-mailbox_docs/configuration/mailboxes/accessing.md
const RPI3_MAILBOX_TIMEOUT=1000;
// does not work, work in progress
var _ok:boolean; timo:TDateTime;
begin
  _ok:=false;
  writeln('write0: value:0x',HexStr(value,8));
  if (channel<=MB_CHANNEL_GPU) then
  begin 
	_ok:=true; SetTimeOut(timo,RPI3_MAILBOX_TIMEOUT);
	
	while ((BCM_GETREG(MBX_STATUS1) and MB_FULL)<>0) and _ok do
	begin // wait until MBX is empty or timeout
	  _ok:=(not TimeElapsed(timo));
	  delay_msec(1); // needed ????
	end;
	
writeln('write1: value:0x',HexStr(value,8));
	if _ok 	then BCM_SETREG(MBX_WRITE1,((value shl 4) or channel))
			else LOG_Writeln(LOG_ERROR,'RPI_MBX_write['+HexStr(channel,2)+']: timeout');
  end else LOG_Writeln(LOG_ERROR,'RPI_MBX_write['+HexStr(channel,2)+']: wrong channel 0x'+HexStr(channel,2));
writeln('write2: ',_ok);
  RPI_MBX_write:=_ok;
end;

function  RPI_MBX_Call(channel:longword; msgptr:RPI_MBX_msgPTR_t; var value:longword):boolean;
// does not work, work in progress
var _ok:boolean;
begin
  _ok:=Aligned(msgptr,32);
  if _ok then
  begin
RPI_MBX_msgshow(@msg); writeln;
	_ok:=RPI_MBX_empty;
  	if _ok then
  	begin
	  _ok:=RPI_MBX_write(channel,PtrUInt(msgptr),true);
	  if _ok then
	  begin
	  	value:=RPI_MBX_read(channel);
	  	_ok:=(value<>MB_CHANNEL_ERROR);
	  	if not _ok then LOG_Writeln(LOG_ERROR,'RPI_MBX_Call['+HexStr(channel,2)+']: read timeout');
	  end else LOG_Writeln(LOG_ERROR,'RPI_MBX_Call['+HexStr(channel,2)+']: can not write');
	end else LOG_Writeln(LOG_ERROR,'RPI_MBX_Call['+HexStr(channel,2)+']: not empty timeout');
  end else  LOG_Writeln(LOG_ERROR,'RPI_MBX_Call['+HexStr(channel,2)+']: msgptr not aligned');
  RPI_MBX_Call:=_ok;
end;

function  bcm2835_vc_get0408(tag,devid:longword; var value:longword):boolean;
// https://www.raspberrypi.org/forums/viewtopic.php?t=205382
// https://github.com/raspberrypi/firmware/wiki/Mailbox-property-interface
// https://github.com/6by9/rpi3-gpiovirtbuf
var _ok:boolean; msg:RPI_MBX_msg_t;
begin
  _ok:=false;
  RPI_MBX_msgfill(msg,0,tag,8,4,devid,0); 
  _ok:=RPI_MBX_write(MB_CHANNEL_TAGS,PtrUInt(@msg),true);			// sent the message
  if _ok then
  begin													
	RPI_MBX_read  	(MB_CHANNEL_TAGS);					// clear the response
	if (msg.request_code=MB_CHANNEL_SUCCESS) then
	  if (msg.dev_id=devid) then value:=msg.val else _ok:=false
	else _ok:=false;
  end;
  bcm2835_vc_get0408:=_ok;
end;

function  bcm2835_vc_get_temperature(var temp:longword):boolean;
begin bcm2835_vc_get_temperature:=bcm2835_vc_get0408(TAG_GET_TEMPERATURE,0,temp); end;

function  bcm2835_vc_get_temperature_max(var temp:longword):boolean;
begin bcm2835_vc_get_temperature_max:=bcm2835_vc_get0408(TAG_GET_MAX_TEMPERATURE,0,temp); end;
(*Unique clock IDs:
    0x000000000: reserved
    0x000000001: EMMC
    0x000000002: UART
    0x000000003: ARM
    0x000000004: CORE
    0x000000005: V3D
    0x000000006: H264
    0x000000007: ISP
    0x000000008: SDRAM
    0x000000009: PIXEL
    0x00000000a: PWM *)
function  bcm2835_vc_get_clock(clockid:longword; var rateHz:longword):boolean;
begin bcm2835_vc_get_clock:=bcm2835_vc_get0408(TAG_GET_CLOCK_RATE,clockid,rateHz); end;

procedure RPI_MBX_test;
// does not work, work in progress
var lw:longword; _ok:boolean; // xmsg:RPI_MBX_msg_t;
begin
  RPI_MBX_msgfill(	msg,
  	0,						// response
  	$00030002,				// mailbox get clock rates
  	8,						// request is 8 bytes long
  	8,						// response expects 8 bytes back
  	3,						// channel 0
  	0);						// empty data field  	

//RPI_MBX_msgshow(@msg); writeln;
writeln('####1  0x',HexStr(addr(msg)),' ',HexStr(GPU_MEM_BASE,8));
writeln('stat0  0x',HexStr(BCM_REGAdr(MBX_STATUS0),8),' read0  0x',HexStr(BCM_REGAdr(MBX_READ0),8));  
writeln('stat1  0x',HexStr(BCM_REGAdr(MBX_STATUS1),8),' write1 0x',HexStr(BCM_REGAdr(MBX_WRITE1),8)); 

  _ok:=RPI_MBX_Call(MB_CHANNEL_TAGS,@msg,lw);
if _ok then
begin
  writeln('####2  0x',HexStr(lw,8),' ',HexStr(msg.request_code,8),' ',_ok);
  RPI_MBX_msgshow(@msg); 
end;
  if (msg.request_code=MB_CHANNEL_SUCCESS) then
  begin
	writeln('CPU speed: ',msg.val,' lw:0x',HexStr(lw,8));	
  end;
writeln;
//if bcm2835_vc_get_temperature(lw) 	then writeln('GPUtemp: ',lw);
//if bcm2835_vc_get_temperature_max(lw) then writeln('GPUtempm:',lw); 
end;

function  RPI_I2C_ChkDev(bus,adr:byte):integer;
// res=-1 not valid // res=0: adr not found // res=1: adr found // res=2: adr found, allocated by driver
var i,j,nr:integer; tl:TStringList; sh:string;
(*   0  1  2  3  4  5  6  7  8  9  a  b  c  d  e  f
00:          -- -- -- -- -- -- -- -- -- -- -- -- -- 
10: -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- 
20: 20 -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- 
30: -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- 
40: -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- 
50: -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- 
60: -- -- -- -- -- -- -- -- UU -- -- -- -- -- -- -- 
70: 70 71 72 73 -- -- -- -- *)  
begin
  nr:=-1;
{$warnings off}
  if (bus>=  0) and (bus<=  1) and
  	 (adr>=$03) and (adr<=$77) then
{$warnings on}
  begin
	tl:=TStringList.create;
	if (call_external_prog(LOG_NONE,'i2cdetect -y '+Num2Str(bus,0), tl)=0) then
	begin
//	  showstringlist(tl);
	  i:=(adr div $10)*$10;	
	  j:=(adr mod $10);	
//	  writeln('RPI_I2C_ChkDev[0x'+HexStr(bus,2)+'/0x'+HexStr(adr,2)+']: 0x'+HexStr(i,2)+' 0x'+HexStr(j,2));
	  i:=SearchStringInListIdx(tl,HexStr(i,2)+': ',1,0);
	  if (i>=0) then // e.g. 60: -- -- -- -- -- -- -- -- UU -- -- -- -- -- -- -- 
	  begin
	  	sh:=Upper(CSV_Item(Trimme(tl[i],4),' ',(j+2)));
//	  	writeln('RPI_I2C_ChkDev[0x'+HexStr(bus,2)+'/0x'+HexStr(adr,2)+']: '+sh);
		if (sh='--')			then nr:=0;
	  	if (sh=HexStr(adr,2))	then nr:=1;
	  	if (sh='UU')			then nr:=2;
	  end;
	end;
	tl.free;
  end;
//writeln('RPI_I2C_ChkDev[0x'+HexStr(bus,2)+'/0x'+HexStr(adr,2)+']: '+Num2Str(nr,0));
  RPI_I2C_ChkDev:=nr;
end;

function RPI_I2C_GetSpeed(bus:byte):longword; 				begin RPI_I2C_GetSpeed:=I2C_bus[bus].I2C_speed; end;
function RPI_I2C_GetFuncs(bus:byte):longword; 				begin RPI_I2C_GetFuncs:=I2C_bus[bus].I2C_funcs; end;
function RPI_I2C_ChkFuncs(bus:byte; funcs:longword):boolean;begin RPI_I2C_ChkFuncs:=((RPI_I2C_GetFuncs(bus) and funcs)=funcs); end;
function RPI_SPI_GetSpeed(bus:byte):longint; 				begin RPI_SPI_GetSpeed:=spi_bus[bus].spi_maxspeed; end;
function RPI_get_PERI_BASE:longword;						begin RPI_get_PERI_BASE:=RPI_mmap_get_info(3); end;
function RPI_get_PERI_SIZE:longword;						begin RPI_get_PERI_SIZE:=RPI_mmap_get_info(31); end;
function RPI_mmap_run_on_unix:boolean; 						begin RPI_mmap_run_on_unix:=(RPI_mmap_get_info(4)=1); end;
function RPI_run_on_ARM:boolean;       						begin RPI_run_on_ARM :=     (RPI_mmap_get_info(5)=1); end;
function RPI_Piggyback_board_available  : boolean; 			begin RPI_Piggyback_board_available:=(RPI_mmap_get_info(6)=1); end;
function RPI_PiFace_board_available(devadr:byte): boolean; 	begin RPI_PiFace_board_available:=   (RPI_mmap_get_info(8)=1); end;
function RPI_run_on_known_hw:boolean;     					begin RPI_run_on_known_hw := (RPI_mmap_get_info(7)=1); end;
function RPI_platform_ok:boolean; 							begin RPI_platform_ok:= ((RPI_run_on_known_hw) and ((RPI_mmap_get_info(9)=1))) end;

procedure GPIO_MSG_INFO(lvl:T_ERRORlevel; msg:string; gpio:longword; portfkt:t_port_flags);
begin
  Log_Writeln(lvl,msg+'GPIO'+Num2Str(gpio,0)+' set '+GetEnumName(TypeInfo(t_port_flags),ord(portfkt)));   
end;

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
	GPFSEL:	 begin idxofs:=((gpio mod gpiomax_2708_reg_c) div 10); mask:=longword((7 shl ((gpio mod 10)*3))); end;
	GPPUPPDN:begin idxofs:=((gpio mod gpiomax_2711_reg_c) div 16); mask:=longword((3 shl ((gpio mod 16)*2))); end;
	else     begin idxofs:=((gpio mod gpiomax_2708_reg_c) div 32); mask:=(longword(1 shl ( gpio mod 32)));    end;
  end; // case
end;

procedure GPIO_get_mask_and_idx(regidx,gpio:longword; var idxabs,mask:longword);
// out:idxabs gives absolute index
var iofs:longint;
begin
  GPIO_get_mask_and_idxOfs(regidx,gpio,iofs,mask); idxabs:=regidx+iofs; 
end;

function  BCM_REGAdr(idx:longword):longword; 
begin BCM_REGAdr:=RPI_get_PERI_BASE+(idx*BCM270x_RegSizInByte); end;

function  BCM_GETREG (regidx:longword):longword; 
begin BCM_GETREG:=mmap_arr^[regidx]; end;

procedure BCM_SETREG (regidx,newval:longword); begin mmap_arr^[regidx]:=newval; end;

procedure BCM_SETREG (regidx,newval:longword; and_mask,readmodifywrite:boolean);
begin
  if readmodifywrite then
  begin
	if and_mask then BCM_SETREG(regidx,BCM_GETREG(regidx) and newval) 
				else BCM_SETREG(regidx,BCM_GETREG(regidx) or  newval);
  end else BCM_SETREG(regidx,newval); 
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
  writeln('mmap: ',MilliSecondsBetween(dt3,dt2),'ms',' APMIRQCLRACK Value: 0x',HexStr(lw1,4));
end;

function  MMAP_start(gpioonly:boolean):integer;
//Set up a memory mapped region to access peripherals
var rslt,errno:longint; dev:string; 
	peri_base:off_t; prot,flags:cint; {$IFDEF LINUX} lw:longword; {$ENDIF}
begin
  rslt:=-7; errno:=0; restrict2gpio:=gpioonly; GPU_MEM_BASE:=0;
  {$IFDEF LINUX}
    if RPI_run_on_ARM then rslt:=-6 else rslt:=-5; 
    if RPI_run_on_ARM and (mmap_arr=nil) then 
    begin
      rslt:=-1;
      if restrict2gpio 
      	then dev:='/dev/gpiomem'
      	else dev:='/dev/mem';
      
      mem_fd:=fpOpen(dev,(O_RDWR or O_SYNC (*or O_CLOEXEC*)));

      if (mem_fd>=0) then 
      begin // mmap GPIO
	    rslt:=-3;
	    peri_base:=	RPI_get_PERI_BASE;
	    prot:=		PROT_READ or PROT_WRITE;
	    flags:=		MAP_SHARED; //or MAP_LOCKED //or MAP_ANONYMOUS or MAP_NORESERVE	

		mmap_arr:=fpMMap(nil,
						 BCM270x_PSIZ_Byte,
		                 prot,
						 flags,
						 mem_fd,
						 (peri_base div PAGE_SIZE)	// mmap2 peripheral base -> offset (pages)
						);  
						
		if (mmap_arr=MAP_FAILED) then 
		begin // 2nd. try
		  rslt:=-31;
//		  LOG_Writeln(LOG_WARNING,'MMAP_start: mmap2');	
(* https://www.mail-archive.com/fpc-pascal@lists.freepascal.org/msg53664.html
  offset was in earlier days RPI_get_PERI_BASE div 4096, because it uses mmap2 ?
  now it's in bytes to use mmap. off_t = cint64; 
rpi4 armhf   32Bit OS mmap2
rpi4 aarch64 64Bit OS mmap 

./rtl/unix/oscdeclh.inc:157 // mmap / mmap64
function fpmmap(addr:pointer;len:size_t;prot:cint;flags:cint;fd:cint;ofs:off_t):pointer; cdecl; external clib name 'mmap'+suffix64bit;

void *mmap(void *addr, size_t len, int prot, int flags, int fildes, off_t off);
void *mmap64(void *addr, size_t len, int prot, int flags, int fildes, off64_t off); 
*)
		  mmap_arr:=fpMMap(nil,
						 BCM270x_PSIZ_Byte,
		                 prot,
						 flags,
						 mem_fd,
						 peri_base	// mmap: peripheral base -> offset (bytes)
						);						
		end;				

		if (mmap_arr=MAP_FAILED) then 
		begin
		  errno:=fpgeterrno;
//		  MMAP_start: PSIZ:0x02000000 Base: 0xFE000000
		  LOG_Writeln(LOG_ERROR,'RPI_mmap_init, MMAP_start:'+
		  	' '+dev+
		  	' PSIZ: 0x'+HexStr(BCM270x_PSIZ_Byte,8)+
		  	' Base: 0x'+HexStr(peri_base,8)+
		  	' page: 0x'+HexStr(PAGE_SIZE,4)+
		  	' mmap_arr: 0x'+HexStr(PtrInt(mmap_arr),8));	  
		end else rslt:=0; 
		
		fpclose(mem_fd);
		
		if (rslt=0) and (not restrict2gpio) then
		begin 
		  rslt:=-4; // does not work on ZeroW -> 0 ????
		  lw:=BCM_GETREG(APMIRQCLRACK);
// When reading this register it returns 0x544D5241 which is the ASCII reversed value for "ARMT".
		  if (lw=$544D5241) 
		  	then rslt:=0 // ok
		  	else LOG_Writeln(LOG_ERROR,'MMAP_start: APMIRQCLRACK 0x'+HexStr(lw,8));
		end;
      end;
    end;
  {$ENDIF}
  case rslt of
     0:	 Log_writeln(Log_INFO, 'RPI_mmap_init, init successful');
    -1:	 Log_writeln(Log_ERROR,'RPI_mmap_init, can not open '+dev+' on target CPU '+{$i %FPCTARGETCPU%}+', result: '+Num2Str(rslt,0));
    -3:	 Log_writeln(Log_ERROR,'RPI_mmap_init, mmap2 '+LNX_ErrDesc(errno)+' on target CPU '+{$i %FPCTARGETCPU%}+', result: '+Num2Str(rslt,0));
    -31: Log_writeln(Log_ERROR,'RPI_mmap_init, mmap '+LNX_ErrDesc(errno)+' on target CPU '+{$i %FPCTARGETCPU%}+', result: '+Num2Str(rslt,0));
	-4:	 Log_writeln(Log_ERROR,'RPI_mmap_init, can not read test register APMIRQCLRACK');
	-5:	 Log_writeln(Log_ERROR,'RPI_mmap_init, not supported rpi platform');
	-6:  Log_writeln(Log_ERROR,'RPI_mmap_init, mmap already initialized');
	-7:  Log_writeln(Log_ERROR,'RPI_mmap_init, no linux platform');
	else Log_writeln(Log_ERROR,'RPI_mmap_init, unknown error, result: '+Num2Str(rslt,0));
  end;
  if rslt=0 then 
  begin
	GPU_MEM_BASE:=GPU_UNCACHED_BASE;
(* todo, set GPU_MEM_BASE for rpi1
#if RASPPI == 1
	#ifdef GPU_L2_CACHE_ENABLED
		#define GPU_MEM_BASE	GPU_CACHED_BASE
	#else
		#define GPU_MEM_BASE	GPU_UNCACHED_BASE
	#endif
#else
	#define GPU_MEM_BASE	GPU_UNCACHED_BASE
#endif *)	
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

function  GPIO_HWPWM_capable(gpio:longword; pwmnum:byte):boolean;
var ok:boolean;
begin
  ok:=false;
  if not ok then ok:=((pwmnum=0) and ((gpio=GPIO_PWM0) or (gpio=GPIO_PWM0A0) or (gpio=GPIO_PWM0Audio)));
  if not ok then ok:=((pwmnum=1) and ((gpio=GPIO_PWM1) or (gpio=GPIO_PWM1A0) or (gpio=GPIO_PWM1Audio)));
  GPIO_HWPWM_capable:=ok;
end;

function  GPIO_HWPWM_capable(gpio:longword):boolean;
begin GPIO_HWPWM_capable:=(GPIO_HWPWM_capable(gpio,0) or GPIO_HWPWM_capable(gpio,1)); end;

function  GPIO_FCTOK(gpio:longint; flags:s_port_flags):boolean;
var _ok:boolean; 
begin
  _ok:=(((gpio>=0) and (GPIO_MAP_GPIO_NUM_2_HDR_PIN(gpio)>=0)) or 
  		(gpio=GPIO_PWM0Audio) or (gpio=GPIO_PWM1Audio));
  if _ok and (PWMHW IN flags) then _ok:=GPIO_HWPWM_capable(gpio);
  if _ok and (FRQHW IN flags) then 
	 _ok:=((gpio=GPIO_FRQ04_CLK0) or (gpio=GPIO_FRQ05_CLK1) or (gpio=GPIO_FRQ06_CLK2) or 
	       (gpio=GPIO_FRQ20_CLK0) or (gpio=GPIO_FRQ32_CLK0) or (gpio=GPIO_FRQ34_CLK0) or
		   (gpio=GPIO_FRQ42_CLK1) or (gpio=GPIO_FRQ43_CLK2) or (gpio=GPIO_FRQ42_CLK1));
  GPIO_FCTOK:=_ok;
end;

function  GPIO_PortCapabilityFlags(gpio:longint):s_port_flags;
var flgs:s_port_flags;
begin
  if GPIO_FCTOK(gpio,[]) then
  begin // valid GPIO num
	flgs:=[INPUT,OUTPUT,PullUP,PullDOWN,RisingEDGE,FallingEDGE,PWMSW];
  	if GPIO_FCTOK(gpio,[PWMHW])  then flgs:=flgs+[PWMHW];
  	if GPIO_FCTOK(gpio,[FRQHW])  then flgs:=flgs+[FRQHW];
  end else flgs:=[];
//writeln('GPIO_PortCapabilityFlags:',gpio,' ',GPIO_PortFlags2String(flgs));
  GPIO_PortCapabilityFlags:=flgs;
end;

function  GPIO_String2PortFlags(flagstring:string):s_port_flags;
var i,j:longint; flagsOUT:s_port_flags; sh:string;
begin
  flagsOUT:=[]; flagstring:=Trimme(flagstring,4);
  for i:=1 to CSV_Count(flagstring,' ') do
  begin
    sh:=CSV_Item(flagstring,' ',i);
	j:=ord(Low(t_port_flags));
	while (j<=ord(High(t_port_flags))) do 
	begin
      if (Upper(GetEnumName(TypeInfo(t_port_flags),j))=Upper(sh)) then 
      begin
      	flagsOUT:=flagsOUT+[t_port_flags(j)]; 
      	j:=ord(High(t_port_flags));
      end;
      inc(j);
    end;
  end;
  GPIO_String2PortFlags:=flagsOUT;
end;

(*function  GPIO_PortFlags(flagstring:string; flagsALLOW:s_port_flags; var flagsOUT:s_port_flags):boolean;
var _ok:boolean; j:t_port_flags; i:longint; sh:string;
begin
  _ok:=false; flagsOUT:=[]; flagstring:=Trimme(flagstring,4);
  for i:=1 to CSV_Count(flagstring,' ') do
  begin
    sh:=CSV_Item(flagstring,' ',i);
	for j IN flagsALLOW do 
	begin
      if (Upper(GetEnumName(TypeInfo(t_port_flags),ord(t_port_flags(j))))=Upper(sh)) then 
      begin
      	_ok:=true;
      	flagsOUT:=flagsOUT+[j];
      end;
    end;
  end;
  GPIO_PortFlags:=_ok;
end;*)

function GPIO_get_AltDesc(gpio:longint; altpin:byte; dfltifempty:string):string;
// https://github.com/RPi-Distro/raspi-gpio/blob/master/raspi-gpio.c
const altcnt_c=6;
      Alt_2709_hdr_dsc_c: array[0..(gpiomax_2708_reg_c*altcnt_c-1)] of string[mdl] = 
(//ALT 0		    1,				2,				3,				4,			5,
    'SDA0'      , 'SA5'        , 'PCLK'      , 'AVEOUT VCLK'   , 'AVEIN VCLK' , '-'         ,
    'SCL0'      , 'SA4'        , 'DE'        , 'AVEOUT DSYNC'  , 'AVEIN DSYNC', '-'         ,
    'SDA1'      , 'SA3'        , 'LCD VSYNC' , 'AVEOUT VSYNC'  , 'AVEIN VSYNC', '-'         ,
    'SCL1'      , 'SA2'        , 'LCD HSYNC' , 'AVEOUT HSYNC'  , 'AVEIN HSYNC', '-'         ,
    'GPCLK0'    , 'SA1'        , 'DPI D0'    , 'AVEOUT VID0'   , 'AVEIN VID0' , 'ARM TDI'   ,
    'GPCLK1'    , 'SA0'        , 'DPI D1'    , 'AVEOUT VID1'   , 'AVEIN VID1' , 'ARM TDO'   ,
    'GPCLK2'    , 'SOE/ SE'    , 'DPI D2'    , 'AVEOUT VID2'   , 'AVEIN VID2' , 'ARM RTCK'  ,
    'SPI0 CE1/' , 'SWE/ SRW/'  , 'DPI D3'    , 'AVEOUT VID3'   , 'AVEIN VID3' , '-'         ,
    'SPI0 CE0/' , 'SD0'        , 'DPI D4'    , 'AVEOUT VID4'   , 'AVEIN VID4' , '-'         ,
    'SPI0 MISO' , 'SD1'        , 'DPI D5'    , 'AVEOUT VID5'   , 'AVEIN VID5' , '-'         ,
    'SPI0 MOSI' , 'SD2'        , 'DPI D6'    , 'AVEOUT VID6'   , 'AVEIN VID6' , '-'         ,
    'SPI0 SCLK' , 'SD3'        , 'DPI D7'    , 'AVEOUT VID7'   , 'AVEIN VID7' , '-'         ,
    'PWM0'      , 'SD4'        , 'DPI D8'    , 'AVEOUT VID8'   , 'AVEIN VID8' , 'ARM TMS'   ,
    'PWM1'      , 'SD5'        , 'DPI D9'    , 'AVEOUT VID9'   , 'AVEIN VID9' , 'ARM TCK'   ,
    'TXD0'      , 'SD6'        , 'DPI D10'   , 'AVEOUT VID10'  , 'AVEIN VID10', 'TXD1'      ,
    'RXD0'      , 'SD7'        , 'DPI D11'   , 'AVEOUT VID11'  , 'AVEIN VID11', 'RXD1'      ,
    'FL0'       , 'SD8'        , 'DPI D12'   , 'CTS0'          , 'SPI1 CE2/'  , 'CTS1'      ,
    'FL1'       , 'SD9'        , 'DPI D13'   , 'RTS0'          , 'SPI1 CE1/'  , 'RTS1'      ,
    'PCM CLK'   , 'SD10'       , 'DPI D14'   , 'I2CSL SDA MOSI', 'SPI1 CE0/'  , 'PWM0'      ,
    'PCM FS'    , 'SD11'       , 'DPI D15'   , 'I2CSL SCL SCLK', 'SPI1 MISO'  , 'PWM1'      ,
    'PCM DIN'   , 'SD12'       , 'DPI D16'   , 'I2CSL MISO'    , 'SPI1 MOSI'  , 'GPCLK0'    ,
    'PCM DOUT'  , 'SD13'       , 'DPI D17'   , 'I2CSL CE/'     , 'SPI1 SCLK'  , 'GPCLK1'    ,
    'SD0 CLK'   , 'SD14'       , 'DPI D18'   , 'SD1 CLK'       , 'ARM TRST'   , '-'         ,
    'SD0 CMD'   , 'SD15'       , 'DPI D19'   , 'SD1 CMD'       , 'ARM RTCK'   , '-'         ,
    'SD0 DAT0'  , 'SD16'       , 'DPI D20'   , 'SD1 DAT0'      , 'ARM TDO'    , '-'         ,
    'SD0 DAT1'  , 'SD17'       , 'DPI D21'   , 'SD1 DAT1'      , 'ARM TCK'    , '-'         ,
    'SD0 DAT2'  , 'TE0'        , 'DPI D22'   , 'SD1 DAT2'      , 'ARM TDI'    , '-'         ,
    'SD0 DAT3'  , 'TE1'        , 'DPI D23'   , 'SD1 DAT3'      , 'ARM TMS'    , '-'         ,
    'SDA0'      , 'SA5'        , 'PCM CLK'   , 'FL0'           , '-'          , '-'         ,
    'SCL0'      , 'SA4'        , 'PCM FS'    , 'FL1'           , '-'          , '-'         ,
    'TE0'       , 'SA3'        , 'PCM DIN'   , 'CTS0'          , '-'          , 'CTS1'      ,
    'FL0'       , 'SA2'        , 'PCM DOUT'  , 'RTS0'          , '-'          , 'RTS1'      ,
    'GPCLK0'    , 'SA1'        , 'RING OCLK' , 'TXD0'          , '-'          , 'TXD1'      ,
    'FL1'       , 'SA0'        , 'TE1'       , 'RXD0'          , '-'          , 'RXD1'      ,
    'GPCLK0'    , 'SOE/ SE'    , 'TE2'       , 'SD1 CLK'       , '-'          , '-'         ,
    'SPI0 CE1/' , 'SWE/ SRW/'  , '-'         , 'SD1 CMD'       , '-'          , '-'         ,
    'SPI0 CE0/' , 'SD0'        , 'TXD0'      , 'SD1 DAT0'      , '-'          , '-'         ,
    'SPI0 MISO' , 'SD1'        , 'RXD0'      , 'SD1 DAT1'      , '-'          , '-'         ,
    'SPI0 MOSI' , 'SD2'        , 'RTS0'      , 'SD1 DAT2'      , '-'          , '-'         ,
    'SPI0 SCLK' , 'SD3'        , 'CTS0'      , 'SD1 DAT3'      , '-'          , '-'         ,
    'PWM0'      , 'SD4'        , '-'         , 'SD1 DAT4'      , 'SPI2 MISO'  , 'TXD1'      ,
    'PWM1'      , 'SD5'        , 'TE0'       , 'SD1 DAT5'      , 'SPI2 MOSI'  , 'RXD1'      ,
    'GPCLK1'    , 'SD6'        , 'TE1'       , 'SD1 DAT6'      , 'SPI2 SCLK'  , 'RTS1'      ,
    'GPCLK2'    , 'SD7'        , 'TE2'       , 'SD1 DAT7'      , 'SPI2 CE0/'  , 'CTS1'      ,
    'GPCLK1'    , 'SDA0'       , 'SDA1'      , 'TE0'           , 'SPI2 CE1/'  , '-'         ,
    'PWM1'      , 'SCL0'       , 'SCL1'      , 'TE1'           , 'SPI2 CE2/'  , '-'         ,
    'SDA0'      , 'SDA1'       , 'SPI0 CE0/' , '-'             , '-'          , 'SPI2 CE1/' ,
    'SCL0'      , 'SCL1'       , 'SPI0 MISO' , '-'             , '-'          , 'SPI2 CE0/' ,
    'SD0 CLK'   , 'FL0'        , 'SPI0 MOSI' , 'SD1 CLK'       , 'ARM TRST'   , 'SPI2 SCLK' ,
    'SD0 CMD'   , 'GPCLK0'     , 'SPI0 SCLK' , 'SD1 CMD'       , 'ARM RTCK'   , 'SPI2 MOSI' ,
    'SD0 DAT0'  , 'GPCLK1'     , 'PCM CLK'   , 'SD1 DAT0'      , 'ARM TDO'    , '-'         ,
    'SD0 DAT1'  , 'GPCLK2'     , 'PCM FS'    , 'SD1 DAT1'      , 'ARM TCK'    , '-'         ,
    'SD0 DAT2'  , 'PWM0'       , 'PCM DIN'   , 'SD1 DAT2'      , 'ARM TDI'    , '-'         ,
    'SD0 DAT3'  , 'PWM1'       , 'PCM DOUT'  , 'SD1 DAT3'      , 'ARM TMS'    , '-'
);
      Alt_2711_hdr_dsc_c: array[0..(gpiomax_2708_reg_c*altcnt_c-1)] of string[mdl] = 
(//ALT 0		    1,				2,				3,				4,					5,
    'SDA0'      , 'SA5'        , 'PCLK'      , 'SPI3 CE0/'     , 'TXD2'            , 'SDA6'        ,
    'SCL0'      , 'SA4'        , 'DE'        , 'SPI3 MISO'     , 'RXD2'            , 'SCL6'        ,
    'SDA1'      , 'SA3'        , 'LCD VSYNC' , 'SPI3 MOSI'     , 'CTS2'            , 'SDA3'        ,
    'SCL1'      , 'SA2'        , 'LCD HSYNC' , 'SPI3 SCLK'     , 'RTS2'            , 'SCL3'        ,
    'GPCLK0'    , 'SA1'        , 'DPI D0'    , 'SPI4 CE0/'     , 'TXD3'            , 'SDA3'        ,
    'GPCLK1'    , 'SA0'        , 'DPI D1'    , 'SPI4 MISO'     , 'RXD3'            , 'SCL3'        ,
    'GPCLK2'    , 'SOE/ SE'    , 'DPI D2'    , 'SPI4 MOSI'     , 'CTS3'            , 'SDA4'        ,
    'SPI0 CE1/' , 'SWE/ SRW/'  , 'DPI D3'    , 'SPI4 SCLK'     , 'RTS3'            , 'SCL4'        ,
    'SPI0 CE0/' , 'SD0'        , 'DPI D4'    , 'I2CSL CE/'     , 'TXD4'            , 'SDA4'        ,
    'SPI0 MISO' , 'SD1'        , 'DPI D5'    , 'I2CSL SDI MISO', 'RXD4'            , 'SCL4'        ,
    'SPI0 MOSI' , 'SD2'        , 'DPI D6'    , 'I2CSL SDA MOSI', 'CTS4'            , 'SDA5'        ,
    'SPI0 SCLK' , 'SD3'        , 'DPI D7'    , 'I2CSL SCL SCLK', 'RTS4'            , 'SCL5'        ,
    'PWM0 0'    , 'SD4'        , 'DPI D8'    , 'SPI5 CE0/'     , 'TXD5'            , 'SDA5'        ,
    'PWM0 1'    , 'SD5'        , 'DPI D9'    , 'SPI5 MISO'     , 'RXD5'            , 'SCL5'        ,
    'TXD0'      , 'SD6'        , 'DPI D10'   , 'SPI5 MOSI'     , 'CTS5'            , 'TXD1'        ,
    'RXD0'      , 'SD7'        , 'DPI D11'   , 'SPI5 SCLK'     , 'RTS5'            , 'RXD1'        ,
    '-'         , 'SD8'        , 'DPI D12'   , 'CTS0'          , 'SPI1 CE2/'       , 'CTS1'        ,
    '-'         , 'SD9'        , 'DPI D13'   , 'RTS0'          , 'SPI1 CE1/'       , 'RTS1'        ,
    'PCM CLK'   , 'SD10'       , 'DPI D14'   , 'SPI6 CE0/'     , 'SPI1 CE0/'       , 'PWM0 0'      ,
    'PCM FS'    , 'SD11'       , 'DPI D15'   , 'SPI6 MISO'     , 'SPI1 MISO'       , 'PWM0 1'      ,
    'PCM DIN'   , 'SD12'       , 'DPI D16'   , 'SPI6 MOSI'     , 'SPI1 MOSI'       , 'GPCLK0'      ,
    'PCM DOUT'  , 'SD13'       , 'DPI D17'   , 'SPI6 SCLK'     , 'SPI1 SCLK'       , 'GPCLK1'      ,
    'SD0 CLK'   , 'SD14'       , 'DPI D18'   , 'SD1 CLK'       , 'ARM TRST'        , 'SDA6'        ,
    'SD0 CMD'   , 'SD15'       , 'DPI D19'   , 'SD1 CMD'       , 'ARM RTCK'        , 'SCL6'        ,
    'SD0 DAT0'  , 'SD16'       , 'DPI D20'   , 'SD1 DAT0'      , 'ARM TDO'         , 'SPI3 CE1/'   ,
    'SD0 DAT1'  , 'SD17'       , 'DPI D21'   , 'SD1 DAT1'      , 'ARM TCK'         , 'SPI4 CE1/'   ,
    'SD0 DAT2'  , '-'          , 'DPI D22'   , 'SD1 DAT2'      , 'ARM TDI'         , 'SPI5 CE1/'   ,
    'SD0 DAT3'  , '-'          , 'DPI D23'   , 'SD1 DAT3'      , 'ARM TMS'         , 'SPI6 CE1/'   ,
    'SDA0'      , 'SA5'        , 'PCM CLK'   , '-'             , 'MII A RX ERR'    , 'RGMII MDIO'  ,
    'SCL0'      , 'SA4'        , 'PCM FS'    , '-'             , 'MII A TX ERR'    , 'RGMII MDC'   ,
    '-'         , 'SA3'        , 'PCM DIN'   , 'CTS0'          , 'MII A CRS'       , 'CTS1'        ,
    '-'         , 'SA2'        , 'PCM DOUT'  , 'RTS0'          , 'MII A COL'       , 'RTS1'        ,
    'GPCLK0'    , 'SA1'        , '-'         , 'TXD0'          , 'SD CARD PRES'    , 'TXD1'        ,
    '-'         , 'SA0'        , '-'         , 'RXD0'          , 'SD CARD WRPROT'  , 'RXD1'        ,
    'GPCLK0'    , 'SOE/ SE'    , '-'         , 'SD1 CLK'       , 'SD CARD LED'     , 'RGMII IRQ'   ,
    'SPI0 CE1/' , 'SWE/ SRW/'  , '-'         , 'SD1 CMD'       , 'RGMII START STOP', '-'           ,
    'SPI0 CE0/' , 'SD0'        , 'TXD0'      , 'SD1 DAT0'      , 'RGMII RX OK'     , 'MII A RX ERR',
    'SPI0 MISO' , 'SD1'        , 'RXD0'      , 'SD1 DAT1'      , 'RGMII MDIO'      , 'MII A TX ERR',
    'SPI0 MOSI' , 'SD2'        , 'RTS0'      , 'SD1 DAT2'      , 'RGMII MDC'       , 'MII A CRS'   ,
    'SPI0 SCLK' , 'SD3'        , 'CTS0'      , 'SD1 DAT3'      , 'RGMII IRQ'       , 'MII A COL'   ,
    'PWM1 0'    , 'SD4'        , '-'         , 'SD1 DAT4'      , 'SPI0 MISO'       , 'TXD1'        ,
    'PWM1 1'    , 'SD5'        , '-'         , 'SD1 DAT5'      , 'SPI0 MOSI'       , 'RXD1'        ,
    'GPCLK1'    , 'SD6'        , '-'         , 'SD1 DAT6'      , 'SPI0 SCLK'       , 'RTS1'        ,
    'GPCLK2'    , 'SD7'        , '-'         , 'SD1 DAT7'      , 'SPI0 CE0/'       , 'CTS1'        ,
    'GPCLK1'    , 'SDA0'       , 'SDA1'      , '-'             , 'SPI0 CE1/'       , 'SD CARD VOLT',
    'PWM0 1'    , 'SCL0'       , 'SCL1'      , '-'             , 'SPI0 CE2/'       , 'SD CARD PWR0',
    'SDA0'      , 'SDA1'       , 'SPI0 CE0/' , '-'             , '-'               , 'SPI2 CE1/'   ,
    'SCL0'      , 'SCL1'       , 'SPI0 MISO' , '-'             , '-'               , 'SPI2 CE0/'   ,
    'SD0 CLK'   , '-'          , 'SPI0 MOSI' , 'SD1 CLK'       , 'ARM TRST'        , 'SPI2 SCLK'   ,
    'SD0 CMD'   , 'GPCLK0'     , 'SPI0 SCLK' , 'SD1 CMD'       , 'ARM RTCK'        , 'SPI2 MOSI'   ,
    'SD0 DAT0'  , 'GPCLK1'     , 'PCM CLK'   , 'SD1 DAT0'      , 'ARM TDO'         , 'SPI2 MISO'   ,
    'SD0 DAT1'  , 'GPCLK2'     , 'PCM FS'    , 'SD1 DAT1'      , 'ARM TCK'         , 'SD CARD LED' ,
    'SD0 DAT2'  , 'PWM0 0'     , 'PCM DIN'   , 'SD1 DAT2'      , 'ARM TDI'         , '-'           ,
    'SD0 DAT3'  , 'PWM0 1'     , 'PCM DOUT'  , 'SD1 DAT3'      , 'ARM TMS'         , '-'
);
var sh:string;
begin
{$warnings off}
  if (altpin>=0) and (altpin<altcnt_c) and 
	 (gpio>=0) 	 and (gpio<gpiomax_2708_reg_c) then 
  begin
    if (Upper(RPI_hw)='BCM2711')
	  then sh:=Alt_2711_hdr_dsc_c[gpio*altcnt_c+altpin]
	  else sh:=Alt_2709_hdr_dsc_c[gpio*altcnt_c+altpin];
  end else sh:='-';
{$warnings on}  
  if sh='-' then sh:=dfltifempty;
  GPIO_get_AltDesc:=sh;
end; //GPIO_get_AltDesc

function oldGPIO_get_AltDesc(gpio:longint; altpin:byte; dfltifempty:string):string;
// datasheet page 102 
const maxalt_c=5; res=''; intrnl='<intrnl>';
      Alt_2709_hdr_dsc_c: array[0..maxalt_c] of array[0..gpiomax_2708_reg_c-1] of string[mdl] = 
  (	// ALT0
    ( ('SDA0'),			('SCL0'),		('SDA1'),		('SCL1'),		('GPCLK0'),
	  ('GPCLK1'),		('GPCLK2'),		('SPI0 CE1/'),	('SPI0 CE0/'),	('SPI0 MISO'),
	  ('SPI0 MOSI'),	('SPI0 SCLK'),	('PWM0'),		('PWM1'),		('TxD0'),
	  ('RxD0'),			('FL0'),		('FL1'),		('PCM CLK'),	('PCM FS'),
	  ('PCM DIN'),		('PCM DOUT'),	('SD0 CLK'),	('SD0 CMD'),	('SD0 DAT0'),
	  ('SD0 DAT1'),		('SD0 DAT2'),	('SD0 DAT3'),	('SDA0'),		('SCL0'),
	  ('TE0'),			('FL0'),		('GPCLK0'),		('FL1'),		('GPCLK0'),
	  ('SPI0 CE1/'),	('SPI0 CE0/'),	('SPI0 MISO'),	('SPI0 MOSI'),	('SPI0 SCLK'),
	  ('PWM0'),		 	('PWM1'),		('GPCLK1'),		('GPCLK2'),		('GPCLK1'),
	  ('PWM1'),			('SDA0'),		('SCL0'),		('SD0 CLK'),	('SD0 CMD'),
	  ('SD0 DAT0'),		('SD0 DAT1'),	('SD0 DAT2'),	('SD0 DAT3')	),
	// ALT1
    ( ('SA5'),			('SA4'),		('SA3'),		('SA2'),		('SA1'),
	  ('SA0'),			('SOE/'),		('SWE/'),		('SD0'),		('SD1'),
	  ('SD2'),			('SD3'),		('SD4'),		('SD5'),		('SD6'),
	  ('SD7'),			('SD8'),		('SD9'),		('SD10'),		('SD11'),
	  ('SD12'),			('SD13'),		('SD14'),		('SD15'),		('SD16'),
	  ('SD17'),			('TE0'),		('TE1'),		('SA5'),		('SA4'),
	  ('SA3'),			('SA2'),		('SA1'),		('SA0'),		('SOE/'),
	  ('SWE/'),			('SD0'),		('SD1'),		('SD2'),		('SD3'),
	  ('SD4'),			('SD5'),		('SD6'),		('SD7'),		('SDA0'),
	  ('SCL0'),			('SDA1'),		('SCL1'),		('FL0'),		('GPCLK0'),	
	  ('GPCLK1'),		('GPCLK2'),		('PWM0'),		('PWM1')		),
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
	 (gpio>=0) 	 and (gpio<gpiomax_2708_reg_c) 
	then sh:=Alt_2709_hdr_dsc_c[altpin,gpio]
  	else sh:='';
{$warnings on}  
  if sh='' then sh:=dfltifempty;
  oldGPIO_get_AltDesc:=sh;
end; //GPIO_get_AltDesc

function GPIO_get_altval(RegAltVal:byte):byte;
var b:byte;
begin
  b:=(RegAltVal and $07);
  case b of 
    $02..$03: 	b:=$07-b; 	// A04 A05
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
  if (gpio>=0) and (gpio<gpiomax_2708_reg_c) then
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
	GPREN ..GPREN+1: 		s:='GPREN'+   Num2Str(longword(regidx-GPREN),0); 	
	GPFEN ..GPFEN+1: 		s:='GPFEN'+   Num2Str(longword(regidx-GPFEN),0); 
	GPHEN ..GPHEN+1: 		s:='GPHEN'+   Num2Str(longword(regidx-GPHEN),0);
	GPLEN ..GPLEN+1: 		s:='GPLEN'+   Num2Str(longword(regidx-GPLEN),0); 
	GPAREN..GPAREN+1: 		s:='GPAREN'+  Num2Str(longword(regidx-GPAREN),0);
	GPAFEN..GPAFEN+1: 		s:='GPAFEN'+  Num2Str(longword(regidx-GPAFEN),0);
	GPPUD: 					s:='GPPUD'+   Num2Str(longword(regidx-GPPUD),0);
	GPPUDCLK..GPPUDCLK+1: 	s:='GPPUDCLK'+Num2Str(longword(regidx-GPPUDCLK),0);
	GPPUPPDN: 				s:='GPPUPPDN'+Num2Str(longword(regidx-GPPUPPDN),0);
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
	else 					s:='['+HexStr(RPI_get_PERI_BASE+(regidx*BCM270x_RegSizInByte),8)+']'; 
						  //s:='Reg['+Num2Str(longword(regidx),0)+']';
  end; // case
  s:=Get_FixedStringLen(s,wid1,false)+': '+Bin(regcontent,32)+' 0x'+HexStr(regcontent,8);  
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

function  CEPstring(cmd:string):string; var sh:string; 
begin 
  call_external_prog(Log_NONE,cmd,sh); 
  CEPstring:=CSV_RemLastSep(sh,#$00);
end;

function  HAT_custom(tl:TStringList; const keys,dflts:string):string;
// entry: KEYS=<valueString>
var sh:string;
begin
  sh:=tl.values[keys];	// <valueString>
  if (Length(sh)=0) then sh:=dflts;
  HAT_custom:=CSV_RemLastSep(sh,#$00);
end;

function  HAT_custom(tl:TStringList; const keys:string):string; // with no default
begin HAT_custom:=HAT_custom(tl,keys,''); end; 

function  HAT_vendor:string;	 begin HAT_vendor:= 	CEPstring('cat '+PrepFilePath(LNX_DevTree+'/hat/vendor')); end;
function  HAT_product:string; 	 begin HAT_product:=	CEPstring('cat '+PrepFilePath(LNX_DevTree+'/hat/product')); end;
function  HAT_product_id:string; begin HAT_product_id:=	CEPstring('cat '+PrepFilePath(LNX_DevTree+'/hat/product_id')); end;
function  HAT_product_ver:string;begin HAT_product_ver:=CEPstring('cat '+PrepFilePath(LNX_DevTree+'/hat/product_ver')); end;
function  HAT_uuid:string; 		 begin HAT_uuid:=		CEPstring('cat '+PrepFilePath(LNX_DevTree+'/hat/uuid')); end;
function  HAT_GetInfo(ovrwrt:boolean; duuid,dvendor,dproduct,dsnr:string; dpid,dpver:longword):boolean;
begin
  with HAT_info do
  begin
    uuid:=''; vendor:=''; product:=''; snr:=''; product_id:=0; product_ver:=0; 
    available:=DirectoryExists(PrepFilePath(LNX_DevTree+'/hat')); 
    overwrite:=false; if not available then overwrite:=ovrwrt;
    if available then
    begin
      uuid:=		HAT_uuid;
      vendor:=		HAT_vendor;
      product:=		HAT_product;				// e.g. productname@snr
      snr:=			CSV_Item(product,'@',2);	// snr
      product:=		CSV_Item(product,'@',1);	// productname
      if not Str2Num(HAT_product_id, product_id)  then product_id:= 0;
      if not Str2Num(HAT_product_ver,product_ver) then product_ver:=0;
    end
    else
    begin
      if overwrite then
      begin // e.g. for testing
        SAY(LOG_WARNING,'HAT_GetInfo: HAT_OVRwrite');
		available:=	true;
		uuid:=		duuid;
		vendor:=	dvendor;
		product:=	dproduct;
		snr:=		dsnr;
		product_id:=dpid;
		product_ver:=dpver;
      end;
    end;
    HAT_GetInfo:=available;
  end; // with
end;
function  HAT_GetInfo:boolean; 
begin HAT_GetInfo:=HAT_GetInfo(false,'00000000-0000-0000-0000-000000000000','vendor','product',rpi_snr,0,0); end;

procedure HAT_GetStructInfo(HAT_INFO_tl:TStringList; lgt:byte);
var ovrstr:string;
begin
  with HAT_info do
  begin
    if overwrite then ovrstr:=' (ovr)' else ovrstr:='';
    HAT_INFO_tl.add(Get_FixedStringLen('uuid:',lgt,false)+uuid+ovrstr);
    HAT_INFO_tl.add(Get_FixedStringLen('vendor:',lgt,false)+vendor);
    HAT_INFO_tl.add(Get_FixedStringLen('product:',lgt,false)+product);
    if snr<>'' then HAT_INFO_tl.add(Get_FixedStringLen('snr:',lgt,false)+snr);
    HAT_INFO_tl.add(Get_FixedStringLen('prod_id:',lgt,false)+'0x'+HexStr(product_id, 4));
    HAT_INFO_tl.add(Get_FixedStringLen('prod_ver:',lgt,false)+'0x'+HexStr(product_ver,4));
  end; // with
end;
procedure HAT_ShowStruct;
var _tl:TStringList;
begin
  _tl:=TStringList.create;
  HAT_GetStructInfo(_tl,10);
  ShowStringList(_tl);
  _tl.free;
end;
procedure HAT_Info_Test;
begin
  if HAT_GetInfo then
  begin
    writeln('HAT Info:');
    HAT_ShowStruct;
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
	la('product_id 0x'+ HexStr(prodid, 4));
	la('product_ver 0x'+HexStr(prodver,4));
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

PIN Header (rev3;1GB;PI2B;BCM2709;a01041):
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
	tl.add('PIN Header ('+RPI_rev+'):');
	tl.add(Get_FixedStringLen('Signal',mdl,false)+' DIR V Pin  Pin V DIR Signal');
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
  writeln(Get_FixedStringLen(desc,wid1,false)+': ',HexStr(RPI_get_PERI_BASE+ofs,8));
  if showhdr then
  begin
    write  (Get_FixedStringLen('Adr(1F-00)',wid1,false)+': ');
    for idx:=31 downto 0 do 
      begin write(HexStr((idx mod $10),1)); if (idx mod 4)=0 then write(' '); end; writeln;
  end;
  if (not skip) then
  begin
    for idx:=startidx to endidx do writeln(show_reg(idx,mode));
  end
  else writeln(RPI_hw,' processor has no registers here');
end;
procedure show_regs(desc:string; ofs,startidx,endidx,mode:longword);
begin show_regs(desc,ofs,startidx,endidx,mode,true); end;

procedure PADS_show_regs;begin 	show_regs('PADSBase',	PADS_BASE_OFS, PADS_BASE_START,PADS_BASE_LAST,0); end;
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

(*procedure GPIO_set_RESET(gpio:longword); 
var idx,mask:longword;
begin // RESET 3Bits @ according gpio location within register GPFSELn
  GPIO_get_mask_and_idx(GPFSEL,gpio,idx,mask);
  BCM_SETREG(idx,(not GPIO_get_ALTMask(gpio,INPUT)),true,true); 
end; *)
  
procedure GPIO_set_INPUT (gpio:longword); 
var idx,mask:longword;
begin 
  GPIO_MSG_INFO(LOG_DEBUG,'GPIO_set_INPUT: ',gpio,INPUT); 
//GPIO_set_RESET(gpio);
  GPIO_get_mask_and_idx(GPFSEL,gpio,idx,mask);
  BCM_SETREG(idx,(not GPIO_get_ALTMask(gpio,INPUT)),true,true);
end;

procedure GPIO_set_OUTPUT(gpio:longword); 
var idx,mask:longword;
begin 
  GPIO_MSG_INFO(LOG_DEBUG,'GPIO_set_OUTPUT: ',gpio,OUTPUT);
  GPIO_get_mask_and_idx(GPFSEL,gpio,idx,mask);
  BCM_SETREG(idx,(not GPIO_get_ALTMask(gpio,INPUT)),true,true);
//GPIO_set_RESET(gpio); // Always use GPIO_set_RESET(x) before using GPIO_set_OUTPUT(x), to reset Bits
  BCM_SETREG(idx,GPIO_get_ALTMask(gpio,OUTPUT),false,true); 
end; 

procedure GPIO_set_ALT(gpio:longword; altfunc:t_port_flags);
var idx,mask:longword;
begin
  GPIO_MSG_INFO(LOG_DEBUG,'GPIO_set_ALT: ',gpio,altfunc);
  GPIO_get_mask_and_idx(GPFSEL,gpio,idx,mask);
//GPIO_set_RESET(gpio); // Always use GPIO_set_RESET(x) before using GPIO_set_ALT(x,y), to reset Bits
  BCM_SETREG(idx,(not GPIO_get_ALTMask(gpio,INPUT)),true,true);
  BCM_SETREG(idx,GPIO_get_ALTMask(gpio,altfunc),false,true);
end;

function  RPI_ShutDown_Thread(ptr:pointer):ptrint;
(*	pushbutton connected to this GPIO pin, using GPIO3/HWPIN:5 (default) also has the benefit of
	wakeing / powering up Raspberry Pi when button is pressed *)
var buttonPressedTime:TDateTime; tog,noovrpres,TermThread:boolean; elapsedTime_msec:int64; sh,msg:string; 
begin
  Thread_SetName('RPIShutDown');
  tog:=false; noovrpres:=true; TermThread:=false; buttonPressedTime:=now;
  with RPI_ShutDown_struct do
  begin
    msg:='RPI_ShutDown[Pin#'+Num2Str(HWPin,0)+'/GPIO'+Num2Str(gpio,0)+']: Thread START debounce:'+Num2Str(RPI_ShutDownDebounce_ms,0)+'msec  ShutdownTime:'+Num2Str(RPI_ShutDownMin_ms,0)+'msec';
	SAY(LOG_WARNING,msg); 
	repeat
	  GPIO_Switch(RPI_ShutDown_struct);
	  if ein and noovrpres then
	  begin // OnOff-Button
//		if not tog then SAY(LOG_INFO,'+########################################################## '+Bool2Str(ein)+' '+Bool2Str(tog));
		if not tog
		  then begin tog:=true; buttonPressedTime:=now; end 
		  else noovrpres:=(MilliSecondsBetween(buttonPressedTime,now)<=(RPI_ShutDownMin_ms+RPI_ShutDownDebounce_ms));
	  end
	  else  
	  begin  
		if tog then
	  	begin
		  elapsedTime_msec:=MilliSecondsBetween(buttonPressedTime,now);
	  	  tog:=false;
	  	  msg:='RPI_ShutDown[Pin#'+Num2Str(HWPin,0)+'/GPIO'+Num2Str(gpio,0)+'/'+Num2Str(elapsedTime_msec,0)+'msec]:';
//	  	  SAY(LOG_INFO,'-########################################################## '+Bool2Str(ein)+' 0x'+Bool2Str(tog)+' '+Num2Str(RPI_ShutDownMin_ms,0)+' '+Num2Str(RPI_ShutDownDebounce_ms,0));
	  	  if (elapsedTime_msec<RPI_ShutDownMin_ms) then
	  	  begin
	  	 	if (elapsedTime_msec>RPI_ShutDownDebounce_ms) then 
	  	  	begin // button pressed for a shorter time, reboot
	  	  	  SAY(LOG_WARNING,msg+' rebooting requested'); 
	  	  	  if (RPI_ShutDown_RebootCall=nil) then
	  	  	  begin
	  	  	    terminateProg:=true;
	  	  	    delay_msec(10);	// let other Threads time to terminate
	  	  		call_external_prog(LOG_INFO,sudo+' shutdown -r now',sh); 
	  	  	  end else RPI_ShutDown_RebootCall;
	  	  	  TermThread:=true;
			end else SAY(LOG_WARNING,msg+' debounce');
	  	  end 
	  	  else 
	  	  begin // button pressed for more than specified time, shutdown
	  		SAY(LOG_WARNING,msg+' shutdown requested');
	  		if (RPI_ShutDown_Call=nil) then
	  		begin
	  		  terminateProg:=true;
	  		  delay_msec(10);	// let other Threads time to terminate
	  		  call_external_prog(LOG_INFO,sudo+' shutdown -h now',sh); 
	  		end else RPI_ShutDown_Call;
	  		TermThread:=true;
	  	  end;
//	  	  SAY(LOG_INFO,'');
	  	end; 
	  end;	// OnOff-Button
	  if ein then delay_msec(1) else delay_msec(10);
	until (TermThread or terminateProg);
  end; // with
  SAY(LOG_INFO,'RPI_ShutDown: Thread END');
  terminateProg:=true;
  EndThread;
  RPI_ShutDown_Thread:=0;
end;

function  RPI_ShutDownInit(hwpin:longint; shutdownMIN_msec,debounce_msec:word; 
				RebootCall,ShutDownCall:TProcedureNoArgCall; 
				desc:string; flags:s_port_flags):boolean;
var _ok:boolean;
begin
  _ok:=false;
  RPI_ShutDownMin_ms:=shutdownMIN_msec;
  RPI_ShutDownDebounce_ms:=debounce_msec;
  RPI_ShutDown_RebootCall:=	RebootCall;
  RPI_ShutDown_Call:=		ShutDownCall;
  if (hwpin>0) then
  begin
  	RPI_ShutDownGPIO:=GPIO_MAP_HDR_PIN_2_GPIO_NUM(hwpin);
  	if (RPI_ShutDownGPIO>=0) then
  	begin
	  _ok:=true;    
	  GPIO_SetStruct(RPI_ShutDown_struct,1,RPI_ShutDownGPIO,desc,flags);
	end;
  end;
  RPI_ShutDownInit:=_ok;
end;
function  RPI_ShutDownInit(hwpin:longint):boolean; 
begin 
  RPI_ShutDownInit:=RPI_ShutDownInit(hwpin,3100,7,nil,nil,'PIShutDown',[INPUT,PullUP,ReversePOLARITY]); 
end;

function  RPI_ShutDownStart:boolean; 
var _ok:boolean;
begin 
  _ok:=GPIO_Setup(RPI_ShutDown_struct);
  if _ok then BeginThread(@RPI_ShutDown_Thread,nil)
  		 else LOG_Writeln(LOG_ERROR,'RPI_ShutDownStart: can not GPIO_Setup'); 
  RPI_ShutDownStart:=_ok;
end;

function  pwm_SW_Thread(ptr:pointer):ptrint;
begin
  with GPIO_ptr(ptr)^ do
  begin
    if (gpio>=0) and (ptr<>nil) then
	begin	
//	  writeln('pwm_SW_Thread: Start of ',description,' with PWMSW (GPIO',Num2Str(gpio,0),')');
//	  , period(us):',PWM.pwm_period_us,' dtycycl(us):',PWM.pwm_dutycycle_us,' restcycl(us):',PWM.pwm_restcycle_us);
      Thread_SetName(description);
	  while (not terminateProg) and (not ThreadCtrl.TermThread) do
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
	end else LOG_Writeln(LOG_ERROR,'pwm_SW_Thread: GPIO not supported or no valid datastruct pointer');
//	writeln('pwm_SW_Thread: END of ',description);
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

procedure PWM_WriteRange(gpio,range:longword);
begin
  case gpio of 
    GPIO_PWM0,GPIO_PWM0A0,GPIO_PWM0Audio: BCM_SETREG(PWM0RNG,range); // HW PWM
	GPIO_PWM1,GPIO_PWM1A0,GPIO_PWM1Audio: BCM_SETREG(PWM1RNG,range); // HW PWM
  end; // case
end;

procedure PWM_Write(gpio,value:longword);
begin
  case gpio of  
    GPIO_PWM0,GPIO_PWM0A0,GPIO_PWM0Audio: BCM_SETREG(PWM0DAT,value); // HW PWM
	GPIO_PWM1,GPIO_PWM1A0,GPIO_PWM1Audio: BCM_SETREG(PWM1DAT,value); // HW PWM
  end; // case
end;

procedure PWM_Write(var GPIO_struct:GPIO_struct_t; value:longword); // value: 0-(pwm_dutyrange-1)
begin
  with GPIO_struct do
  begin
	with PWM do
	begin
      pwm_value:=pwm_GetMODVal(value,pwm_dutyrange); //value: 0-(pwm_dutyrange-1)
	  pwm_dutycycle_us:=pwm_GetDCSWVal(pwm_period_us,pwm_value,pwm_dutyrange);	
	  pwm_restcycle_us:=0; 
	  if pwm_period_us>pwm_dutycycle_us 
	  	then pwm_restcycle_us:=pwm_period_us-pwm_dutycycle_us
	  	else pwm_dutycycle_us:=pwm_period_us;
	  pwm_period_ms:=trunc(pwm_period_us/1000); 
	  if pwm_period_ms<=0 then pwm_period_ms:=1;
	  pwm_sigalt:=true;
	  
	  if (pwm_dutyrange<>0) then pwm_dtycycl:=pwm_value/pwm_dutyrange
	  						else pwm_dtycycl:=0;
	  
(*  writeln('PWM_Write:'+
		' GPIO'+			Num2Str(gpio,0)+
		' value:'+			Num2Str(pwm_value,0)+
		' dtyrange:'+		Num2Str(pwm_dutyrange,0)+
		' dtyperiod(us):'+	Num2Str(pwm_period_us,0)+
		' dtycycl(us):'+	Num2Str(pwm_dutycycle_us,0)+
		' dtyrest(us):'+	Num2Str(pwm_restcycle_us,0)
		); *)
      if (PWMHW IN portflags) then
	  begin
      	case gpio of	  
         GPIO_PWM0,GPIO_PWM0A0,GPIO_PWM0Audio: BCM_SETREG(PWM0DAT,pwm_value,false,false); // HW PWM
	     GPIO_PWM1,GPIO_PWM1A0,GPIO_PWM1Audio: BCM_SETREG(PWM1DAT,pwm_value,false,false); // HW PWM
      	end; // case
	  end;
  	end; // with
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
//writeln('PWMCTL: 0x',HexStr(pwm_control,8));
  BCM_SETREG(PWMCTL,0,false,false);  			// stop PWM 
  ok:=CLK_Write(regctlidx,regdividx,DIVI,0,$01);// $01: clock src from osci
  BCM_SETREG(PWMCTL,pwm_control,false,false); 	// restore PWM_CONTROL	
  PWM_ClkWrite:=ok;
end;

function  PWM_GetMinFreq(dutycycle:longword):real; 
var r:real; 
begin
  if dutycycle<>0 then r:=(CLK_GetFreq(1)/(PWM_DIVImax*dutycycle)) else r:=0;
  PWM_GetMinFreq:=r;
end;

function  PWM_GetMaxFreq(dutycycle:longword):real;
var r:real;   
begin
  if dutycycle<>0 then r:=(CLK_GetFreq(1)/(PWM_DIVImin*dutycycle)) else r:=0;
  PWM_GetMaxFreq:=r;
end;

function  PWM_GetMaxDtyC(freq:real):longword;
var lw:longword;
begin
  if freq<>0 then lw:=round(CLK_GetFreq(1)/(PWM_DIVImin*freq)) else lw:=0;
  PWM_GetMaxDtyC:=lw;
end;

procedure PWM_setClock(var GPIO_struct:GPIO_struct_t); 
// same clock for PWM0 and PWM1. Needs only to be set once
var DIVI:longword; r:real;
begin
  with GPIO_struct do
  begin
    with PWM do
    begin
	  if (PWMHW IN portflags) then
	  begin
      	DIVI:=PWM_DIVImin;  // default
      	r:=pwm_freq_Hz*pwm_dutyrange;
      	if (r>0) then DIVI:=round(CLK_GetFreq(1)/r) else DIVI:=0; 
//    	writeln('PWM_setClock0: ',CLK_GetFreq(1):0:5,' freq(Hz):',pwm_freq_Hz:0:5,' dty:',pwm_dutyrange:0,' DIVI:',DIVI);
	  	if (DIVI<PWM_DIVImin) or (DIVI>PWM_DIVImax) then 
	  	begin
	      LOG_Writeln(LOG_ERROR,'PWM_setClock['+Num2Str(gpio,0)+'|'+Num2Str(DIVI,0)+'/'+Num2Str(PWM_DIVImin,0)+'/'+Num2Str(PWM_DIVImax,0)+']: desired PWM-Freq '+Num2Str(pwm_freq_Hz,0,2)+'Hz will not be set. use other duty cycle');
	      if (DIVI<PWM_DIVImin) then DIVI:=PWM_DIVImin else DIVI:=PWM_DIVImax;
	  	end;
//     	writeln('PWM_setClock1: ',DIVI);
	  	PWM_ClkWrite(PWMCLKCTL,PWMCLKDIV,DIVI);	
	  end;
	end; // with
  end; // with
end;
		
function  GPIO_PortFlags2String(flgs:s_port_flags):string;
var j:t_port_flags; sh:string;
begin
  sh:=''; 
  for j IN flgs do 
    sh:=sh+GetEnumName(TypeInfo(t_port_flags),ord(t_port_flags(j)))+' ';
  GPIO_PortFlags2String:=sh;
end;
		
procedure GPIO_ShowStruct(var GPIO_struct:GPIO_struct_t);
begin
  with GPIO_struct do
  begin 
    writeln('GPIO_ShowStruct: ',description,' Portflags:',GPIO_PortFlags2String(portflags),' initok:',initok,' Simulation:',simulation);
	writeln('HWPin:',HWPin,' GPIO',gpio:0,' nr:',nr:0,' State:',ein);
	writeln('idxofs_1Bit:0x',HexStr(idxofs_1Bit,2),' mask_1Bit:0x',HexStr(mask_1Bit,8),' idxofs_3Bit:0x',HexStr(idxofs_3Bit,2),' mask_3Bit:0x',HexStr(mask_3Bit,8));
	writeln('pwm_mode:',PWM.pwm_mode,' pwm_freq:',PWM.pwm_freq_hz:0:2,' pwm_dutyrange:',PWM.pwm_dutyrange,' value:',PWM.pwm_value,
	       ' pwm_dutycycle_us:',PWM.pwm_dutycycle_us,' pwm_period_us:',PWM.pwm_period_us);
  end;
end;

procedure  Thread_SetName(name:string);
const PR_SET_NAME=$0f;
var   thread_name:Thread_name_t;
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

procedure Thread_ShowStruct(var ThreadCtrl:Thread_Ctrl_t);
var n:longint; sh:string;
begin
  with ThreadCtrl do
  begin 
    SAY(LOG_INFO,'');
	SAY(LOG_INFO,'ThreadInfo:        '+ThreadInfo);
//	SAY(LOG_INFO,'ThreadID:          ',TThreadID);
	SAY(LOG_INFO,'ThreadRunning:     '+Bool2YNS(ThreadRunning)+' TermThread: '+Bool2YNS(TermThread));
	SAY(LOG_INFO,'ThreadFunc:      0x'+HexStr(ThreadFunc));
	SAY(LOG_INFO,'ThreadTimeOut:     '+FormatDateTime('YYYYMMDD hh:mm:ss.zzz',ThreadTimeOut));
	SAY(LOG_INFO,'ThreadCmdStr:      '+ThreadCmdStr);
	SAY(LOG_INFO,'ThreadRetStr:      '+ThreadRetStr);
	SAY(LOG_INFO,'ThreadRetCode:     '+Num2Str(ThreadRetCode,0));
	SAY(LOG_INFO,'ThreadProgressOld: '+Num2Str(ThreadProgressOld,0));
	SAY(LOG_INFO,'ThreadProgress:    '+Num2Str(ThreadProgress,0));
	sh:='UsrData[0-4]:      '; for n:=0 to 4 do sh:=sh+Num2Str(UsrData[n],0)+' ';  SAY(LOG_INFO,sh);
	sh:='ThreadPara[0-4]:   '; for n:=0 to 4 do sh:=sh+Num2Str(ThreadPara[n],0)+' ';  SAY(LOG_INFO,sh);
	sh:='ThreadParaStr[0-4]:'; for n:=0 to 4 do sh:=sh+ThreadParaStr[n]+' ';  SAY(LOG_INFO,sh);
	SAY(LOG_INFO,'');
  end;
end;

procedure Thread_InitStruct(var ThreadCtrl:Thread_Ctrl_t);
begin
  with ThreadCtrl do
  begin
    TermThread:=true; 	ThreadRunning:=false; ThreadRetCode:=0; 
    ThreadRetStr:='';	ThreadInfo:=''; 	  ThreadPrio:=0;
    ThreadProgress:=0; 	ThreadProgressOld:=-maxint; ThreadTimeOut:=now; 
    ThreadID:=TThreadID(0);
  end; // with
end;

procedure Thread_InitStruct2(var ThreadCtrl:Thread_Ctrl_t; ThFunc:TThFunctionOneArgCall);
var n:longint;
begin
  with ThreadCtrl do 
  begin
	ThreadFunc:=ThFunc;
  	ThreadCmdStr:='';
  	ThreadFlags:=[];
  	for n:=0 to 4 do
  	begin
  	  ThreadPara[n]:=0; UsrData[n]:=0; ThreadParaStr[n]:='';
  	end;
  end; // with
end;

procedure Thread_InitStruct0(var ThreadCtrl:Thread_Ctrl_t);
begin
  Thread_InitStruct (ThreadCtrl);
  Thread_InitStruct2(ThreadCtrl,nil);
end;
 
(*function  Thread_SetPriority(aThreadID:TThreadID; class_priority:Thread_ClassPrio_t; prio:integer):boolean;
// https://forum.lazarus.freepascal.org/index.php?topic=19968.0
// https://www.mail-archive.com/fpc-devel@lists.freepascal.org/msg17573.html
// https://bugs.freepascal.org/view.php?id=16785
// https://man7.org/linux/man-pages/man7/sched.7.html
//   Thread_ClassPrio_t = (SCHED_OTHER,SCHED_FIFO,SCHED_RR); 
var aPriority,res:integer; param:sched_param;
begin // 0-99
  param.sched_priority:=prio;
  aPriority:=ord(class_priority);
  res:=pthread_setschedparam(pthread_t(aThreadID),aPriority,@param);
  Thread_SetPriority:=(res=0);
end; *)

procedure Thread_mySetPrio(aThreadID:TThreadID; prio:longint);
var sh:string;
begin
  if (aThreadID<>TThreadID(0)) then
  begin // how to map ThreadID to id from top command ? work in progress
	sh:='renice -n '+Num2Str(Limits(prio,-15,15),0)+' -p '+Num2Str(aThreadID,0);
	LOG_Writeln(LOG_WARNING,'Thread_mySetPrio['+Num2Str(aThreadID,0)+']: '+Num2Str(prio,0)+' '+sh);
  end;
end;

function  Thread_Start(var ThreadCtrl:Thread_Ctrl_t; funcadr:TThreadFunc; 
					   paraadr:pointer; delaymsec:longword; prio:integer):boolean;
begin
  with ThreadCtrl do
  begin
	Thread_InitStruct(ThreadCtrl); TermThread:=false; 
	ThreadID:=BeginThread(funcadr,paraadr);
	ThreadRunning:=(ThreadID<>TThreadID(0));
	if ThreadRunning and (delaymsec>0) then delay_msec(delaymsec); // let thread time to start
	if ThreadRunning and (prio<>0) then ThreadSetPriority(ThreadID,prio);
//	if ThreadRunning and (prio<>0) then Thread_mySetPrio(ThreadID,prio);
//	if ThreadRunning and (prio<>0) then Thread_SetPriority(ThreadID,SCHED_OTHER,prio);
	ThreadPrio:=ThreadGetPriority(ThreadID);
	if ThreadRunning then SetTimeOut(ThreadTimeOut,15000); 
	Thread_Start:=ThreadRunning;
  end;
end;

function  Thread_End(var ThreadCtrl:Thread_Ctrl_t; waitmsec:longword):boolean;
begin
  with ThreadCtrl do
  begin
    TermThread:=true;
//  if ThreadRunning then ThreadRunning:=(WaitForThreadTerminate(ThreadID,waitmsec)=0); // does not work on raspian
(*)	if (waitmsec>0) then
	begin
	  delay_msec(waitmsec); 
	  if ThreadRunning then ThreadRunning:=(not (KillThread(ThreadID)=0));
	end else ThreadRunning:=false; *)

	if (waitmsec>0) then delay_msec(waitmsec); 
	if ThreadRunning then ThreadRunning:=(not (KillThread(ThreadID)=0));

	Thread_InitStruct(ThreadCtrl); 
	Thread_End:=ThreadRunning;
  end;
end;

procedure HDMI_Switch(ein:boolean);
var sh:string;
begin
  sh:='tvservice '; if ein then sh:=sh+'-p' else sh:=sh+'-o';
  call_external_prog(LOG_NONE,sh,sh);
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
//      writeln('PWM_End: PWMCTL 0x',HexStr(regsav,8));			
		if GPIO_HWPWM_capable(gpio,0) // // maskout Bits for channel1/2
		  then regsav:=(regsav and $0000ff00) and (not PWM0_ENABLE)
		  else regsav:=(regsav and $000000ff) and (not PWM1_ENABLE); 	
//      writeln('PWM_End: PWMCTL 0x',HexStr(regsav,8));
		BCM_SETREG(PWMCTL,regsav,false,false); // Disable channel PWM
	  end;
    end
	else Thread_End(ThreadCtrl,100);
  end;  // with
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

procedure PWM_SetStruct(var GPIO_struct:GPIO_struct_t; mode:byte; freq_Hz,freq_min,freq_max:real; dutyrange,startval:longword);
begin
  with GPIO_struct do
  begin
    with PWM do
    begin
      pwm_mode:=mode;
      pwm_freq_hz:=freq_Hz; PWM_freq_min:=freq_min; 	PWM_freq_max:=freq_max;
      if (PWMHW IN portflags) then
      begin
		Limits(PWM_freq_min,PWM_GetMinFreq(dutyrange),	PWM_GetMaxFreq(dutyrange));  	
	  	Limits(PWM_freq_max,PWM_freq_min,				PWM_GetMaxFreq(dutyrange));  	
	  end
	  else
	  begin // SW PWM
		Limits(PWM_freq_min,10,							100);  	
	  	Limits(PWM_freq_max,PWM_freq_min,				150); 
	  end;
	  Limits(  PWM_freq_hz, PWM_freq_min,				PWM_freq_max);  
	  with ThreadCtrl do begin TermThread:=true; ThreadRunning:=false; ThreadID:=TThreadID(0); end;
	  if (pwm_freq_hz<>0) then pwm_period_us:=round(1000000/pwm_freq_hz) else pwm_period_us:=0; 
	  pwm_dutyrange:=dutyrange; 
	  
	  if (pwm_dutyrange<>0) then pwm_dtycycl:=startval/pwm_dutyrange
	  						else pwm_dtycycl:=0;

//	  PWM_Write(GPIO_struct,startval);

(*	  pwm_value:=startval; 
	  pwm_dutycycle_us:=pwm_GetDCSWVal(pwm_period_us,pwm_value,pwm_dutyrange);
      if pwm_period_us>pwm_dutycycle_us 
	  	then pwm_restcycle_us:=pwm_period_us-pwm_dutycycle_us
	  	else pwm_dutycycle_us:=pwm_period_us;
	  pwm_period_ms:=trunc(pwm_period_us/1000); 
	  if pwm_period_ms<=0 then pwm_period_ms:=1;*)
	end; // with
  end;
end;

procedure PWM_SetStruct(var GPIO_struct:GPIO_struct_t; mode:byte; freq_Hz:real; dutyrange,startval:longword);
begin PWM_SetStruct(GPIO_struct,PWM_MS_MODE,freq_Hz,0,0,dutyrange,0); end;

procedure PWM_SetStruct(var GPIO_struct:GPIO_struct_t); 
//HW-PWM: Mark Space mode // set pwm hw clock div to 32 (19.2Mhz/32 = 600kHz) // Default range of 1024
//SW-PWM: Mark Space mode // set pwm sw clock to 50Hz // DutyCycle range of 1000 (0-999)
const dcycl=1000;
var freq_Hz:real;
begin 
  if (PWMHW IN GPIO_struct.portflags) then freq_Hz:=PWM_GetMaxFreq(dcycl) else freq_Hz:=50;
  PWM_SetStruct(GPIO_struct,PWM_MS_MODE,freq_Hz,dcycl,0);
end;

function  PWM_Setup(var GPIO_struct:GPIO_struct_t):boolean;
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
	      GPIO_PWM0,GPIO_PWM0A0,GPIO_PWM1A0,GPIO_PWM0Audio,GPIO_PWM1Audio,
		  GPIO_PWM1 : begin // PWM0:Pin12:GPIO18 PWM1:Pin35:GPIO19 
					    initok:=true; 
//				    	writeln('PWM_Setup (HW):'); GPIO_ShowStruct(GPIO_struct);
					    GPIO_set_PINMODE(gpio,PWMHW);					  
						regsav:=BCM_GETREG(PWMCTL);			// save ctl register
						BCM_SETREG(PWMCTL,0,false,false);  	// stop PWM 
					    PWM_setClock(GPIO_struct);			// set clock external before PWM_Setup
//                      writeln('PWM_Setup: PWMCTL 0x',HexStr(regsav,8));			
//  					writeln('PWM_Setup: pwm_dutyrange ',PWM.pwm_dutyrange);
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
//                      writeln('PWM_Setup: pwm_value ',PWM.pwm_value);
						PWM_Write  (GPIO_struct,PWM.pwm_value);	// set start value
//                      writeln('PWM_Setup: PWMCTL 0x',HexStr(regsav,8));			// 					
					    BCM_SETREG(PWMCTL,regsav,false,false);		// Enable channel PWM
					  end;
		  else Log_Writeln(LOG_ERROR,'PWM_Setup: GPIO'+Num2Str(gpio,0)+' not supported for HW PWM'); 
		end;
	  end
	  else
	  begin // SW PWM
        case gpio of
		  -999..-1: Log_Writeln(LOG_ERROR,'PWM_Setup: GPIO'+Num2Str(gpio,0)+' not supported for PWM'); 
		  else		begin 
		              if (gpio>=0) and (PWMSW IN portflags) then
					  begin
					    initok:=true;
						GPIO_set_PINMODE(gpio,OUTPUT); portflags:=portflags+[OUTPUT];
//                      writeln('PWM_Setup (SW):'); GPIO_ShowStruct(GPIO_struct);
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
					  else Log_Writeln(LOG_ERROR,'PWM_Setup: wrong neg. GPIO Error Code: '+Num2Str(gpio,0)+' '+GPIO_PortFlags2String(portflags));
					end;
	    end; // case
	  end;
    end
	else Log_Writeln(LOG_ERROR,'PWM_Setup: GPIO_struct is not initialized'); 
  end;
  PWM_Setup:=GPIO_struct.initok;
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

function  OSC_Setup(_gpio:longint; pwm_freq_Hz,pwm_dty:real):longint;
var flgh:s_port_flags; gpio_struct:GPIO_struct_t;  
    pwm_dutyrange,_dtyw:longint;
begin
  if GPIO_FCTOK(_gpio,[PWMHW]) then flgh:=[PWMHW] else flgh:=[PWMSW];
  if pwm_dty<0 then pwm_dty:=0; if pwm_dty>1 then pwm_dty:=1; 
  if ((PWMSW IN flgh) and (pwm_freq_Hz>200)) then pwm_freq_Hz:=200;
  pwm_dutyrange:=PWM_GetMaxDtyC(pwm_freq_Hz); _dtyw:=round(pwm_dutyrange*pwm_dty);
  writeln('OSC_Setup: ',(PWMHW IN flgh),' f:',pwm_freq_Hz:0:1,'Hz range:',pwm_dutyrange:0,' dty:',_dtyw:0);
  GPIO_SetStruct (gpio_struct,1,_gpio,'OSC',[OUTPUT]+flgh);
  PWM_SetStruct  (gpio_struct,PWM_MS_MODE,pwm_freq_Hz,pwm_dutyrange,_dtyw); 
  PWM_setClock   (gpio_struct);
  if not GPIO_Setup(gpio_struct) then pwm_dutyrange:=-1;
  OSC_Setup:=pwm_dutyrange;
end;

procedure OSC_Write(_gpio,pwm_dutyrange:longint; pwm_dty:real);
begin
  if pwm_dutyrange>0 then
  begin
    if pwm_dty<0 then pwm_dty:=0; if pwm_dty>1 then pwm_dty:=1; 
    PWM_Write(_gpio,round(pwm_dty*(pwm_dutyrange-1)));
  end else LOG_Writeln(LOG_ERROR,'OSC_Write: invalid pwm_dutyrange '+Num2Str(pwm_dutyrange,0));
end;
	
procedure FREQ_CounterReset(var FREQ_Struct:FREQ_Determine_t);
begin
  with FREQ_Struct do begin fcnt:=0; fcntold:=0; fTurnRate_Hz:=0; fdet_enab:=false; end;
end;

procedure FREQ_InitStruct(var FREQ_Struct:FREQ_Determine_t; detint_ms:longint);
begin
  with FREQ_Struct do
  begin
	fSyncTime:=now;		fdet_ms:=detint_ms; fdet_enab:=false;
	FREQ_CounterReset(	FREQ_Struct);
  end; // with
end;

procedure FREQ_DetTurnRate(var FREQ_Struct:FREQ_Determine_t; steps:longint); 
var ms:longint;
begin
  with FREQ_Struct do
  begin  
	fcnt:=fcnt+steps;
  	if TimeElapsed(fSyncTime,fdet_ms) then 
	begin
	  if fdet_enab then
	  begin
	  	ms:=MilliSecondsBetween(fSyncTime,now); 
	  	if (ms<>0) then 
	  	begin
		  fTurnRate_Hz:=((fcnt-fcntold)*1000/ms); fcntold:=fcnt;
		  if (fTurnRate_Hz=0) then FREQ_CounterReset(FREQ_Struct);	// new SF 22.5.2018
		end;   
	  end
	  else
	  begin
	  	FREQ_CounterReset(FREQ_Struct);
	    fdet_enab:=true; // prepare fdet on next step update
	  end;
    end;
  end; // with
end;

function  WAVE_InitArray(wavelist:TStringList; var wa:WAVE_Array_t; var valmin,valmax:real):longint;
//IN:	 StringList which has a number in each line
//OUT: 	 filled Array, min,max value
//Result:ArrayCount 
var res,n:longint; r:real;
begin
  res:=0; valmin:=MaxFloat; valmax:=MinFloat; 
  SetLength(wa,wavelist.count);
  for n:=1 to wavelist.count do
  begin
	if Str2Num(Trimme(wavelist[n-1],3),r) then
	begin
	  wa[res]:=r;
	  if r<valmin then valmin:=r;
	  if r>valmax then valmax:=r;
	  inc(res);
	end;
  end;
  if res<>Length(wa) then SetLength(wa,res); 
  WAVE_InitArray:=res;
end;

function  WAVE_InitArray(var wa:WAVE_Array_t; wavemode:WAVE_RampShape_t; valstart,valend:real; valcnt:longint; dtycycle:real):longint;
const k=1.0; Scnt=21; 
var ok:boolean; res,n,siglow,sighig:longint; delta,x,x0:real;
begin
  ok:=false; 
  if valcnt>0 then
  begin
	SetLength(wa,valcnt); delta:=0;
	if (not ok) and (wavemode IN [LIN_Ramp,LIN_Triangle,LIN_SawTooth]) then
	begin
	  ok:=true;
      if (valcnt>1) then delta:=(valend-valstart)/(valcnt-1);
      wa[valcnt-1]:=valend; wa[0]:=valstart; 
      for n:=1 to (valcnt-2) do wa[n]:=wa[n-1]+delta;
	end;
	
	if (not ok) and (wavemode IN [SINusoidal]) then
	begin
	  ok:=true;
	  if (valcnt>0) then delta:=(2*pi)/(valcnt-0);	// prevent 2x same value (0)
	  for n:= 0 to (valcnt-1) do wa[n]:=(valend-valstart)*(sin(n*delta))+valstart;
	end;
	
	if (not ok) and (wavemode IN [LIN_Square]) then
	begin
	  if (dtycycle<0) or (dtycycle>1) then dtycycle:=0.5;	// 0-100% default 50%
	  sighig:=round(valcnt*dtycycle);
	  siglow:=valcnt-sighig;
	  ok:=((sighig>0) or (siglow>0));
	  if ok then
	  begin
	    for n:= 1 to siglow do wa[n-1]:=valstart;
	    for n:= siglow to (valcnt-1) do wa[n]:=valend;
	  end;
	end;
	
	if (not ok) and (wavemode IN [S_Shape]) then
	begin // https://en.wikipedia.org/wiki/Logistic_function
	  if (valcnt>0) then
	  begin
	  	ok:=true; x0:=(valcnt-1)/2; x:=0; 
	  	delta:=Scnt/valcnt;
	  	for n:= 0 to (valcnt-1) do 
	  	begin
	  	  wa[n]:=1/(1+exp(-k*(x-x0)));
	  	  if n=0 			then wa[n]:=0.0;
	  	  if n>=(valcnt-1)	then wa[n]:=1.0;
		  wa[n]:=(valend-valstart) * wa[n] + valstart;
		  x:=x+delta;
	  	end;
	  end;
	end;
	
(*	if (not ok) and (wavemode IN [S_Shape]) then
	begin // http://www.pmean.com/04/scurve.html	// old approach
	  if (valcnt>0) then
	  begin
	  	ok:=true; x:=-10; 
	  	delta:=abs(x*2.0)/valcnt;
	  	for n:= 0 to (valcnt-1) do 
	  	begin
		  wa[n]:=(valend-valstart) * roundto(1.0/(1.0+exp(-k*x)),4) + valstart;
		  x:=x+delta;
	  	end;
	  end;
	end; *)
	
	if not ok then for n:=1 to valcnt do wa[n-1]:=valstart; 
  end else SetLength(wa,0);
  res:=Length(wa); if not ok then res:=-1;
  WAVE_InitArray:=res;
end;

function  WAVE_SetIdx(var wstruct:WAVE_Signal_Struct_t; var wa:WAVE_Array_t; startidx:longint):boolean;
var ok:boolean;
begin
  ok:=false;
  with wstruct do
  begin
    idx:=startidx;
    ok:=((idx>=0) and (idx<Length(wa))); 
	if up then dec(idx) else inc(idx);
  end;
  WAVE_SetIdx:=ok;
end;

procedure WAVE_Enable(var wstruct:WAVE_Signal_Struct_t; enab:boolean); begin wstruct.enable:=enab; end;
procedure WAVE_InitStruct(var wstruct:WAVE_Signal_Struct_t; var wa:WAVE_Array_t; wavemode:WAVE_RampShape_t; intervall_ms:longint);
begin
  with wstruct do
  begin
	timer:=now;
	int_ms:=intervall_ms;
	mode:=wavemode;
	enable:=false;
	up:=true;
//	if not WAVE_SetIdx(wstruct,wa,0) then LOG_Writeln(LOG_ERROR,'WAVE_IniStruct: startidx vs. size of WAVE_Array');
  end;
end;

procedure WAVE_Show(var wstruct:WAVE_Signal_Struct_t; var wa:WAVE_Array_t);
var n:longint;
begin
  writeln;
  with wstruct do
  begin
	writeln('WAVE_Show:');
	writeln('mode:',GetEnumName(TypeInfo(WAVE_RampShape_t),ord(mode)),' interval:',int_ms:0,' enable:',enable,' up:',up,' nextidx:',idx+1);  
  end; // with
  for n:=1 to Length(wa) do writeln((n-1):3,' ',wa[n-1]:7:3);
  writeln;
end;

//(LIN_Ramp,LIN_Triangle,LIN_SawTooth,LIN_Square,SINusoidal);
function  WAVE_GetIdx(var wstruct:WAVE_Signal_Struct_t; var wa:WAVE_Array_t):boolean;
var ok:boolean;
begin
  ok:=true;
  with wstruct do
  begin
	if (Length(wa)>=1) and enable then
	begin
	  if up then 
	  begin // direction up: idx will increase
		inc(idx);
		if idx>=length(wa) then
		begin
		  case mode of
			LIN_Ramp:		begin idx:=Length(wa)-1; end;	// remain at highest idx
			LIN_Triangle:	begin  // symmetric linear waveform, change up/down direction 
							  if idx>=2 then idx:=Length(wa)-2 else idx:=0; up:=false; 
							end;
	  	 	else			begin idx:=0; end;				// start again from 1. indx
		  end; // case
		end;
	  end
	  else
	  begin // direction down: idx will decrease
		dec(idx);
		if idx<=0 then begin up:=true; idx:=0; end;
	  end;
	  SetTimeOut(timer,int_ms);
	end else ok:=false;
  end; // with
  WAVE_GetIdx:=ok;
end;

procedure WAVE_Test;
const iv_ms=500; valcnt=8; dty=0.5; valstart=0; valend=1; startidx=0;
var n,j:longint; wstruct:WAVE_Signal_Struct_t; wa:WAVE_Array_t; 
begin
  for j:= ord(low(WAVE_RampShape_t)) to ord(high(WAVE_RampShape_t)) do
  begin // test all wave shapes
// useful valcnt to S_Shape: 21
	write('WAVE_Test: '+GetEnumName(TypeInfo(WAVE_RampShape_t),j)+' '+
						'valcnt:'+	Num2Str(valcnt,0)+' '+
						'valstart:'+Num2Str(valstart,0,3)+' '+
						'valend:'+	Num2Str(valend,0,3)+' '+
						'idxstart:'+Num2Str(startidx,0)+' '+
						'interval:'+Num2Str(iv_ms,0)+'ms'
		);
	if j=ord(LIN_Square) then write(' DtyCycle:'+Num2Str(dty*100,0,0)+'%');
	writeln; 
  	if WAVE_InitArray(wa,WAVE_RampShape_t(j),valstart,valend,valcnt,dty)>0 then
	begin
	  WAVE_InitStruct(wstruct,wa,WAVE_RampShape_t(j),iv_ms);
	  WAVE_SetIdx	 (wstruct,wa,0);
	  WAVE_Enable	 (wstruct,true);
	  n:=0;
	  while (n<=(2*valcnt-1)) do
	  begin	// 2 full cycles
		with wstruct do 
		begin
		  if TimeElapsed(timer) then
		  begin // every 'iv_ms' a new idx to address wa[idx]
			if enable and WAVE_GetIdx(wstruct,wa)
			  then writeln('WAVE_Test['+Num2Str(n,2)+']: '+Num2Str(wa[idx],6,3))
			  else LOG_Writeln(LOG_ERROR,'WAVE_Test: #2');
			inc(n);
		  end else delay_msec(10); 
		end; // with
	  end; // while
	
	end else LOG_Writeln(LOG_ERROR,'WAVE_Test: #1');  
	writeln;
  end; // for
  SetLength(wa,0);
end;

procedure FRQ_Switch(var GPIO_struct:GPIO_struct_t; ein:boolean);
var regsav:longword;
begin 
  with GPIO_struct do
  begin
	if ein then
	begin // freq on
	  Log_Writeln(Log_ERROR,'FRQ_ON: currently not implemented');	/// !!!!! TODO !!!!!
//	  ThreadCtrl.TermThread:=true; 
	  if (FRQHW IN portflags) then
	  begin 	
//		regsav:=(BCM_GETREG(FRQ_CTLIdx) and $70f); // mask out Enable and unused Bits
//		BCM_SETREG(FRQ_CTLIdx,(BCM_PWD or regsav),false,false); 	// Disable clock 
	  end;	
	end
	else
	begin // freq off
	  ThreadCtrl.TermThread:=true; 
	  if (FRQHW IN portflags) then
	  begin 	
    	regsav:=(BCM_GETREG(FRQ_CTLIdx) and $70f); // mask out Enable and unused Bits
		BCM_SETREG(FRQ_CTLIdx,(BCM_PWD or regsav),false,false); 	// Disable clock 
	  end;
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

procedure FRQ_SetStruct(var GPIO_struct:GPIO_struct_t; freq_Hz,freq_min,freq_max:real);
begin
  with GPIO_struct do
  begin
    FRQ_freq_Hz:=freq_Hz; FRQ_freq_min:=freq_min; FRQ_freq_max:=freq_max;
    Limits(FRQ_freq_min,CLK_GetMinFreq,CLK_GetMaxFreq);
    Limits(FRQ_freq_max,FRQ_freq_min,  CLK_GetMaxFreq);
    Limits(FRQ_freq_Hz, FRQ_freq_min,  FRQ_freq_max);
  end; // with
end;
procedure FRQ_SetStruct(var GPIO_struct:GPIO_struct_t; freq_Hz:real);
begin FRQ_SetStruct(GPIO_struct,freq_Hz,CLK_GetMinFreq,CLK_GetMaxFreq); end;
procedure FRQ_SetStruct(var GPIO_struct:GPIO_struct_t);
begin FRQ_SetStruct(GPIO_struct,CLK_GetMinFreq); end;

function  FRQ_Setup(var GPIO_struct:GPIO_struct_t):boolean;
var _mode:byte; _clksrc,_msk,_divi,_divf,_mash:longword; 
begin
  with GPIO_struct do
  begin
//  initok:=CLK_ValidFreq(freq_Hz);
    initok:=InLimits(FRQ_freq_Hz,FRQ_freq_min,FRQ_freq_max);
    if initok and (FRQHW IN portflags) then 
	begin
	  _mash:=0;
	  initok:=CLK_GetSource(FRQ_freq_Hz,_clksrc,_divi,_divf,_mash); 
	  if initok then
	  begin	  	  
//writeln('FRQ_Setup: freq(Hz):',FRQ_freq_Hz:0:2,' divi:0x',HexStr(_divi,3),' divf:0x',HexStr(_divf,3),' clksrc:',_clksrc:0,' mash:',_mash:0);
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
          if not initok then LOG_Writeln(LOG_ERROR,'FRQ_Setup['+Num2Str(gpio,0)+']: ALTx');		  
          _msk:=((_mash and $3) shl 9) or (_clksrc and $0f); // set mash and clk-src	  
		  if initok then initok:=CLK_Write(FRQ_CTLIdx,FRQ_DIVIdx,_divi,_divf,_msk);
//        writeln('Mash:0x',HexStr(CLK_GetMashValue(_mode),2),' mode:',_mode,' clksrc:',_clksrc);
		  if not initok then LOG_Writeln(LOG_ERROR,'FRQ_Setup['+Num2Str(gpio,0)+']: CLK_Write');		  
        end else LOG_Writeln(LOG_ERROR,'FRQ_Setup['+Num2Str(gpio,0)+']: CLK_GetRegIdx');					
	  end else LOG_Writeln(LOG_ERROR,'FRQ_Setup['+Num2Str(gpio,0)+']: CLK_GetSource');	
	end else LOG_Writeln(LOG_ERROR,'FRQ_Setup['+Num2Str(gpio,0)+']: for freq(Hz): '+Num2Str(FRQ_freq_Hz,0,2)+' not possible');
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
  RPI_HW_Start([InstSignalHandler]);
  SetLength(range,maxcnt);
  FillWaveTable;
  GPIO_SetStruct(GPIO_struct,1,gpio,'WAVE-TEST',[FRQHW]);
  FRQ_SetStruct(GPIO_struct,freqHz);
  if GPIO_Setup (GPIO_struct) then 
  begin
    if FRQ_Setup(GPIO_struct) then
	begin
	  FRQ_Switch(GPIO_struct,true);	// switch freq ON 
      repeat
        for n:= 0 to (maxcnt-1) do 
	    begin
//	      mmap_arr^[GPIO_struct.FRQ_DIVIdx]:=(BCM_PWD or ((range[n] and $fff) shl 12));	
writeln('#',n,' val:',range[n]);		
	    end;
      until terminateProg;
      FRQ_Switch(GPIO_struct,false);	// switch freq OFF
      GPIO_set_INPUT(gpio);
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
	    writeln(HexStr(BCM_REGAdr(regdiv),8),':  ',HexStr(reg,8),' divisor:',CLK_GetDivisor(reg):0:5);
      end;
	  initok:=FRQ_GetClkRegIdx(gpio,_mode); 	
      if initok then initok:=CLK_GetRegIdx(_mode,FRQ_CTLIdx,FRQ_DIVIdx); 
	  if initok then
	  begin
	    for b:=0 to 3 do
	    begin
		  writeln('Mash: ',b:0,' ',HexStr(CLK_GetMashValue(b),4)); 
		end;
	    show_regs('GMGP'+Num2Str(_mode,0)+'CTL',CLK_BASE_OFS,FRQ_CTLIdx,FRQ_DIVIdx,0,false); 
	    FRQ_SetStruct(GPIO_struct,freqHz);
        initok:=FRQ_Setup(GPIO_struct);
	    show_regs('GMGP'+Num2Str(_mode,0)+'CTL',CLK_BASE_OFS,FRQ_CTLIdx,FRQ_DIVIdx,0,false); 
//	    Clock_show_regs;
	    delay_msec(60000);
	    FRQ_Switch(GPIO_struct,false);
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
  writeln('CLK_Tst, mode:',mode_pll:0,' f:',fr:0:2,' fmin:',FREQ_O_min:0:2,' favg:',FREQ_O_avg:0:2,' fmax:',FREQ_O_max:0:2,' MASH:',MASH,' DIVIF:0x',HexStr(DIVIF,8),' ok:',ok);
  for n:= 0 to 3 do
  begin
    CLK_GetRegIdx(n,regctl,regdiv);
    reg:=BCM_GETREG(regdiv);  
	writeln(HexStr(BCM_REGAdr(regdiv),8),':  ',HexStr(reg,8),' divisor:',CLK_GetDivisor(reg):0:5);
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
    I2C:	begin
			  akft:=INPUT; 
			  case gpio of
					 0,1,2,3,28,29:	akft:=ALT0;
			  end; // case
			  if (akft<>INPUT)	then GPIO_set_ALT(gpio,akft)
								else GPIO_MSG_INFO(LOG_ERROR,'GPIO_set_PINMODE: ',gpio,portfkt);   		
    		end;
	PWMHW : begin
			  akft:=INPUT; 
			  case gpio of
					 12,13,40,41,45:akft:=ALT0;
					 18,19: 		akft:=ALT5;
					 52,53:			akft:=ALT1;
			  end; // case
			  if (akft<>INPUT)	then GPIO_set_ALT(gpio,akft)
								else GPIO_MSG_INFO(LOG_ERROR,'GPIO_set_PINMODE: ',gpio,portfkt); 		
		    end;
    else GPIO_MSG_INFO(LOG_ERROR,'GPIO_set_PINMODE: ',gpio,portfkt); 
  end; // case
end;

procedure GPIO_Switch(var GPIO_struct:GPIO_struct_t); // Read GPIOx Status in Struct
var sh:string;
begin
  with GPIO_struct do
  begin
    if initok then
    begin	
	  if (simulation IN portflags) then 
	  begin 
	    sh:=description;
	    if sh='' then sh:='GPIO_Switch(Num#'+Num2Str(nr,0)+'/GPIO#'+Num2Str(gpio,0)+
					'/HWPin#'+Num2Str(HWPin,0)+')';
	    writeln(sh+	' ReversePolarity: '+Bool2Str((mask_pol<>0))+' SignalLevel: '+Bool2Str(ein));
	  end
	  else
	  begin
		ein:=(GPIO_get_PIN(gpio) xor (mask_pol<>0));	
//		ein:=(((mmap_arr^[regget] and mask_1Bit) xor (mask_pol<>0))<>0);
	  end;
    end else LOG_Writeln(LOG_ERROR,'GPIO_Switch HDRPin:'+Num2Str(HWPin,0)+' not registered');
  end;
end;

procedure GPIO_Switch(var GPIO_struct:GPIO_struct_t; switchon:boolean); // switch GPIOx on/off
var sh:string; 
begin
  with GPIO_struct do
  begin
    if initok then
    begin 
      if (switchon<>ein) then 
	  begin // only on level change
	    if (simulation IN portflags) then 
		begin
	      sh:=description;
		  if sh='' then sh:='GPIO_Switch(Num#'+Num2Str(nr,0)+'/GPIO#'+Num2Str(gpio,0)+
					'/HWPin#'+Num2Str(HWPin,0)+')';
		  writeln(sh+' ReversePolarity: '+Bool2Str((mask_pol<>0))+' SignalLevel: '+Bool2Str(switchon));
		end
		else
		begin 
		  if switchon then mmap_arr^[regset]:=mask_1Bit 
		  			  else mmap_arr^[regclr]:=mask_1Bit;
		end;
		ein:=switchon;
	  end;
    end else LOG_Writeln(LOG_ERROR,'GPIO_Switch HDRPin:'+Num2Str(HWPin,0)+' not registered');
  end;
end;

procedure GPIO_SIO_BBout(gpio:longword; WRbuf:string; speedIdx:byte; invertLogic:boolean);
// Serial bit bang does not work reliable @ speeds > 4800Baud (speedIdx=3)
//Serial comm. via bit bang           Baud:   300  1200  2400  4800  9600 19200 38400 57600
const SIO_BIT_Time:array[0..7] of longword=((3333),(833),(416),(208),(104),(52), (26), (17));
var bitnr:byte; i,setIdx,setmsk,clrIdx,clrmsk:longword;
  
  procedure SetGPIO(setbit:boolean);
  begin
	if setbit then mmap_arr^[setIdx]:=setmsk
			  else mmap_arr^[clrIdx]:=clrmsk;
  end;
  
begin
  if (speedIdx>(length(SIO_BIT_Time)+1)) then speedIdx:=3; 	// default 4800
  
  GPIO_get_mask_and_idx(GPSET,gpio,setIdx,setmsk);
  GPIO_get_mask_and_idx(GPCLR,gpio,clrIdx,clrmsk); 
    
  for i:= 1 to Length(WRbuf) do
  begin
	SetGPIO(invertLogic); 					// write start bit
	delay_us(SIO_BIT_Time[speedIdx]);
  	
  	for bitnr:= 0 to 7 do
  	begin // Write each bit
      SetGPIO((((ord(WRbuf[i]) and (1 shl bitnr))<>0) and (not invertLogic)));
      delay_us(SIO_BIT_Time[speedIdx]);
  	end;
  
  	SetGPIO((not invertLogic));				// set pin to original state
  	delay_us(SIO_BIT_Time[speedIdx]+(SIO_BIT_Time[speedIdx] shr 1)); // 1.5 stop bit    
  end; // for
  
end;

function  GPIO_SIO_Write(var GPIO_struct:GPIO_struct_t; cmd:string):longint;
// BitBang serial Out
var res:integer;
begin 
  res:=-1;
  cmd:=Trimme(cmd,3);
  if (cmd<>'') then
  begin
	with GPIO_struct do
    begin
      if (gpio>=0) then
      begin
        if (INPUT IN portflags) then
        begin
    	  if GPIO_get_PIN  (gpio) then
  	  	  begin // pin not activated by button press (pullup)
	  	  	GPIO_set_OUTPUT(gpio);
	  	  	GPIO_set_PIN   (gpio,(not SIOinvLogic));
		  	res:=0;
		  end else LOG_Writeln(LOG_ERROR,'GPIO_SIO_Write['+Num2Str(res,0)+']: GPIO_get_PIN has failed');
        end else res:=0;
        
  	  	if (res=0) then
  	  	begin
	  	  GPIO_SIO_BBout (gpio,cmd,SIOspeedIdx,SIOinvLogic);
	      if (INPUT IN portflags) then 
	      begin
	        GPIO_SetStruct(GPIO_struct,nr,gpio,description,portflags); // reset to old state(input)
	      	GPIO_Setup    (GPIO_struct);
	      end;
	    end else LOG_Writeln(LOG_ERROR,'GPIO_SIO_Write['+Num2Str(res,0)+']: GPIO_get_PIN has failed');
  	  end else LOG_Writeln(LOG_ERROR,'GPIO_SIO_Write['+Num2Str(res,0)+']: GPIO not defined');
  	end; // with 
  end;
  LOG_Writeln(LOG_WARNING,'GPIO_SIO_Write['+Num2Str(res,0)+']: '+BS_DoESC(cmd));
  GPIO_SIO_Write:=res; 
end;

procedure GPIO_SetStruct(var GPIO_struct:GPIO_struct_t; num,gpionum:longint; desc:string; flags:s_port_flags);
//e.g. GPIO_SetStruct(structure,3,8,'description',[INPUT,PullUP,ReversePOLARITY]);
begin  
  with GPIO_struct do
  begin
	gpio:=gpionum; HWPin:=GPIO_MAP_GPIO_NUM_2_HDR_PIN(gpio); 
	nr:=num; description:=desc; 
	portflags:=flags; portCapabilityFlags:=GPIO_PortCapabilityFlags(gpio);
	RPI_HDR_SetDesc(HWPin,desc);
	idxofs_1Bit:=0; idxofs_3Bit:=0; mask_1Bit:=0; mask_3Bit:=0; mask_pol:=0; 
	regget:=GPIOONLYREAD; regset:=GPIOONLYREAD; regclr:=GPIOONLYREAD; ein:=false;
	with ThreadCtrl do begin TermThread:=true; ThreadRunning:=false; end; 
//	plausibility check and clean-up of port flags 
	if (PWMHW 		IN portflags)  or 
	   (PWMSW 		IN portflags)  then portflags:=portflags+[OUTPUT];

    if (INPUT  	    IN portflags)  and 
	   (OUTPUT      IN portflags)  then portflags:=portflags-[OUTPUT,PWMHW,PWMSW]; // cannot be both
   
	if ((portflags * [INPUT,OUTPUT])=[]) then portflags:=portflags+[INPUT]; // must be IN- or OUTPUT		  

	if (PullUP      IN portflags)  and 
	   (PullDOWN    IN portflags)  then portflags:=portflags-[PullDOWN]; // cannot be both
	   
	if (not(INPUT   IN portflags)) then
	begin
	 if(RisingEDGE 	IN portflags)  then portflags:=portflags-[RisingEDGE];
	 if(FallingEDGE IN portflags)  then portflags:=portflags-[FallingEDGE];
	end;	
 
	SIOspeedIdx:=2; // 2400Baud
	if (Baud300     IN portflags) then SIOspeedIdx:=0;
	if (Baud1k2     IN portflags) then SIOspeedIdx:=1;
	if (Baud2k4     IN portflags) then SIOspeedIdx:=2;
	if (Baud4k8     IN portflags) then SIOspeedIdx:=3;
	if (Baud9k6     IN portflags) then SIOspeedIdx:=4;
	if (Baud19k2	IN portflags) then SIOspeedIdx:=5;
	if (Baud38k4	IN portflags) then SIOspeedIdx:=6;
	if (Baud57k6	IN portflags) then SIOspeedIdx:=7;
	
	SIOinvLogic:=false;
	if (SIOinvertLogic IN portflags) then SIOinvLogic:=true;
	
	if (PWMHW IN portflags) and (not GPIO_FCTOK(gpio,[PWMHW])) then
	begin
	  LOG_writeln(LOG_WARNING,'GPIO_SetStruct: GPIO'+Num2Str(gpio,0)+' can not be PWMHW');
	  portflags:=portflags-[PWMHW]+[PWMSW];		
	end;
	
	if (FRQHW IN portflags) then
    begin
//	  portflags:=portflags-[OUTPUT,ALT0,ALT5];
	  portflags:=portflags-[ALT0,ALT5];
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
	
//	if (portflags=[]) then portflags:=[INPUT]; 
	
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
	FRQ_SetStruct (GPIO_struct);	 FRQ_freq_Hz:=-1; // set default values for frq
    PWM_SetStruct (GPIO_struct); PWM.PWM_freq_hz:=-1; // set default values for pwm
//  GPIO_ShowStruct(GPIO_struct);
  end;
end;

procedure GPIO_SetStruct(var GPIO_struct:GPIO_struct_t);
begin GPIO_SetStruct(GPIO_struct,0,-1,'',[INPUT]); end;


procedure GPIO_set_edge(gpio:longword; flgs:s_port_flags; enable:boolean);
begin
  if (FallingEDGE IN flgs) then GPIO_set_edge_falling(gpio,enable); 
  if (RisingEDGE  IN flgs) then GPIO_set_edge_rising (gpio,enable);
end;

procedure GPIO_set_pull(gpio:longword; flgs:s_port_flags; enable:boolean);
// natural pull of the GPIO (0-8 pull high, 9-27 pull low)
begin
  if (PullDOWN	  IN flgs) then GPIO_set_PULLDOWN	 (gpio,enable); 
  if (PullUP	  IN flgs) then GPIO_set_PULLUP  	 (gpio,enable);
end;

procedure GPIO_set_PAD(gpio:longword; flgs:s_port_flags);
var DS:byte;
begin						DS:=$b;	// default: 0x03
  if (DS2mA	 IN flgs) then	DS:= 0;
  if (DS4mA	 IN flgs) then 	DS:= 1;
  if (DS6mA	 IN flgs) then 	DS:= 2;
  if (DS8mA	 IN flgs) then 	DS:= 3;
  if (DS10mA IN flgs) then 	DS:= 4;
  if (DS12mA IN flgs) then 	DS:= 5;
  if (DS14mA IN flgs) then 	DS:= 6;
  if (DS16mA IN flgs) then 	DS:= 7;

  if ((DS<=7) or (noPADslew IN flgs) or (noPADhyst IN flgs)) then
	GPIO_set_PAD(gpio,(noPADslew IN flgs),(noPADhyst IN flgs),(DS and $07));
end;

function  GPIO_Setup(var GPIO_struct:GPIO_struct_t):boolean;
begin
  with GPIO_struct do
  begin
    if initok then 
	begin
	  if (gpio<0) then
	  begin
	    gpio:=-1; initok:=false;
	    LOG_Writeln(LOG_ERROR,'GPIO_Reg for HDRPin: '+Num2Str(HWPin,0)+' can not be mapped to GPIO num');
	  end
	  else
	  begin
	    if not (simulation IN portflags)then
	    begin
          if (([OUTPUT,PWMSW,PWMHW,FRQHW] * portflags)<>[]) then
          begin // OUTPUTS
        	if (([PWMSW,PWMHW] * portflags)<>[]) then
        	begin
			  initok:=PWM_Setup(GPIO_struct); 
		    end
		    else
		    begin
			  if (([FRQHW] * portflags)<>[]) then
			  begin
				initok:=FRQ_Setup(GPIO_struct);
			  end
			  else
			  begin // pure OUTPUT
				GPIO_set_PINMODE(gpio,OUTPUT);
				GPIO_Switch(GPIO_struct,(InitialHIGH 	 IN portflags) or
										(ReversePolarity IN portflags) ); 
			  end;
		    end;
		    GPIO_set_PAD	(gpio,portflags);
		  end
		  else
		  begin
		    GPIO_set_PINMODE(gpio,INPUT); 
			GPIO_set_pull	(gpio,portflags,true);
			GPIO_set_edge	(gpio,portflags,true); 
		  end;
        end;		
	  end;
	end else Log_Writeln(LOG_ERROR,'GPIO_Setup: GPIO_struct is not initialized');
	GPIO_Setup:=initok; 
  end; // with
end;
  
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
	  writeln('Start with ',cnt:0,' samples, GPIO',gpio:0,' Pin:',HWPin:0,' Mask:0x',HexStr(mask_1Bit,8),' idxofs_1Bit:0x',HexStr(idxofs_1Bit,2),')');
      s:=now; // start measuring time 
	  repeat 
	    {$warnings off} 
	      if fastway then
		  begin // >20MHz
	        mmap_arr^[regset]:=mask_1Bit; (* High*) 
	        mmap_arr^[regclr]:=mask_1Bit; (* Low *)
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
    writeln(looptimes-lw+1:3,'. Set StatusLED (GPIO',RPI_status_led_GPIO,') to 1'); LED_Status(true);  delay_msec(waittime_ms);
	writeln(looptimes-lw+1:3,'. Set StatusLED (GPIO',RPI_status_led_GPIO,') to 0'); LED_Status(false); delay_msec(waittime_ms);
	writeln;
  end;
  writeln('End of GPIO_PIN_TOGGLE_TEST');
end;
  
procedure GPIO_set_BIT(regidx,gpio:longword;setbit,readmodifywrite:boolean); { set or reset pin in gpio register part }
var idx,mask:longword;
begin
  GPIO_get_mask_and_idx(regidx,gpio,idx,mask);
//Writeln('GPIO_set_BIT: GPIO'+Num2Str(gpio,0)+' level: '+Bool2Str(setbit)+' Reg: 0x'+HexStr(regidx,8)+' idx: 0x'+HexStr(idx,8)+' mask: 0x'+HexStr(mask,8));   
  if setbit then BCM_SETREG(idx,    mask ,false,readmodifywrite)
            else BCM_SETREG(idx,not(mask),true, readmodifywrite);
end;
  
procedure GPIO_set_PIN(gpio:longword;highlevel:boolean);
{ Set RPi GPIO to high or low level: Speed @ 700MHz ->  1.25MHz }
begin
//Log_Writeln(LOG_DEBUG,'GPIO_set_PIN: '+Num2Str(gpio,0)+' level '+Bool2Str(highlevel));
//Writeln('GPIO_set_PIN: '+Num2Str(gpio,0)+' level '+Bool2Str(highlevel));
  if highlevel then GPIO_set_BIT(GPSET,gpio,true,false) else GPIO_set_BIT(GPCLR,gpio,true,false);
  { delay_msec(1); }
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
  if (not terminateProg) then delay_msec(pulse_ms);
  GPIO_set_pin(gpio,false);
end;

procedure GPIO_set_GPPUD(enable,pullup:boolean); 
begin
  if enable then
  begin
	if pullup then BCM_SETREG(GPPUD,$02,false,false) else BCM_SETREG(GPPUD,$01,false,false);
  end else BCM_SETREG(GPPUD,$00,false,false);
  delay_msec(1);
end; { set GPIO Pull-up/down Register (GPPUD) } 

procedure GPIO_set_PAD(gpio:longword; noSLEW,noHYST:boolean; drivestrength:byte);
// https://www.raspberrypi.org/documentation/hardware/raspberrypi/gpio/gpio_pads_control.md
// https://de.scribd.com/doc/101830961/GPIO-Pads-Control2
var mask:longword; lvl:T_ErrorLevel; sh:string;
begin
  lvl:=LOG_INFO;
  mask:=BCM_PWD or (drivestrength and	$00000007);	// default: 0x3
  if (not noHYST) then mask:=mask or 	$00000008;	// default: 0x1
  if (not noSLEW) then mask:=mask or 	$00000010;	// default: 0x1
  case gpio of
	00..27:	begin sh:='00-27'; BCM_SETREG(PADS_GPIO00_27,mask,false,false); end; // 0x7e10 002c PADS (GPIO  0-27)
	28..45:	begin sh:='28-45'; BCM_SETREG(PADS_GPIO28_45,mask,false,false); end; // 0x7e10 0030 PADS (GPIO 28-45)
	46..53:	begin sh:='46-53'; BCM_SETREG(PADS_GPIO46_53,mask,false,false); end; // 0x7e10 0034 PADS (GPIO 46-53)
	else	begin sh:=Num2str(gpio,0)+' no valid num'; lvl:=LOG_ERROR; end;
  end; // case
  LOG_Writeln(lvl,'GPIO_set_PAD['+sh+']: DRIVE:'+Num2Str(drivestrength,0)+' SLEW:'+Bool2Dig(not noSLEW)+' HYST'+Bool2Dig(not noHYST)); 
end;

procedure GPIO_set_PULLUPORDOWN(gpio:longword; enable,pullup:boolean); // pulldown: pullup=false;
// https://github.com/RPi-Distro/raspi-gpio/blob/master/raspi-gpio.c
// natural pull of the GPIO (0-8 pull high, 9-27 pull low)
// approximately 50K½
const no2711=true;
var idx,mask,pull:longword;
begin 
  LOG_Writeln(LOG_DEBUG,'GPIO_set_PULLUPORDOWN: GPIO'+Num2Str(gpio,0)+' '+Bool2Str(enable)+' '+Bool2Str(pullup));
  if (Upper(RPI_hw)='BCM2711') then
  begin 
	GPIO_get_mask_and_idx(GPPUPPDN,gpio,idx,mask);
	if enable then begin if pullup then pull:=1 else pull:=2; end else pull:=0;
	pull:=(pull shl ((gpio mod 16)*2));
//	writeln('BCM2711 PullSet['+Num2Str(gpio,2)+']: reg: GPPUPPDN'+Num2Str(idx-GPPUPPDN,0)+' msk: 0x'+HexStr(mask,8)+' pull: 0x'+HexStr(pull,2));
	BCM_SETREG(idx,(BCM_GETREG(idx) and (not mask) or pull));
  end
  else
  begin
	GPIO_get_mask_and_idx(GPPUDCLK,gpio,idx,mask);
	GPIO_set_GPPUD(enable,pullup); 				// assert clock to GPPUDCLKn
	delay_us(10);
	BCM_SETREG(idx,mask,false,false);
	delay_us(10);
	GPIO_set_GPPUD(false, pullup); 				// deassert clock from GPPUDCLKn
	delay_us(10);
	BCM_SETREG(idx,0,false,false);  
	delay_us(10);
  end;
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
  if HWPWM	then GPIO_SetStruct(GPIO_struct,1,gpio,'HW PWM_TEST',[PWMHW])
			else GPIO_SetStruct(GPIO_struct,1,gpio,'SW PWM_TEST',[PWMSW]);
  PWM_SetStruct (GPIO_struct,PWM_MS_MODE,freq_Hz,dutyrange,startval); // ca. 50Hz (50000/1000) -> divisor: 384	
  PWM_setClock  (GPIO_struct);
  if GPIO_Setup (GPIO_struct) then
  begin
    GPIO_ShowConnector; GPIO_ShowStruct(GPIO_struct); 		
	i:=0; cnt:=1;
	repeat
	  if (i>(dutyrange-1)) then 
	  begin 
	    PWM_Write(GPIO_struct,dutyrange-1);	
		writeln('Loop(',cnt,'/',dutyrange,'): reached max. pwm value: ',dutyrange-1); delay_msec(30); 
		GPIO_ShowStruct(GPIO_struct); 
		i:=0; inc(cnt);
	  end else PWM_Write(GPIO_struct,i);
//    if (i=(dutyrange div 2)) then readln;  // for measuring with osci
	  if HWPWM then begin inc(i); delay_msec(10); end else begin inc(i,10); delay_msec(10); end;	// ms
	until (cnt>maxcnt);
	PWM_Write     (GPIO_struct,0);	// set last value to 0
	PWM_SetStruct (GPIO_struct); 	// reset to PWM default values
    delay_msec(100); // let SW Thread time to terminate
  end else Log_Writeln(LOG_ERROR,'GPIO_PWM_Test: GPIO'+Num2Str(GPIO_struct.gpio,0)+' Init has failed'); 	
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
  end else Writeln('GPIO_Test: can not Map HWPin:'+Num2Str(HWPinNr,0)+' to valid GPIO num');	
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
	  PWM_Write(SERVO_struct.HWAccess,setval);
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
    PWM_SetStruct  (SERVO_struct.HWAccess,PWM_MS_MODE,freq,maxval,dcmid);
    PWM_setClock   (SERVO_struct.HWAccess);
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
  RPI_HW_Start([InstSignalHandler]);
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
	until (nr>50) or terminateProg;
	for nr:=1 to Length(SERVO_struct) do SERVO_Write(SERVO_struct[nr-1],0,false);  
	delay_msec(SERVO_Speed*round(90/60)); // let servos time to turn to neutral position
	SERVO_End(-1);
	writeln('SERVO_Test: END');
  end else LOG_Writeln(LOG_ERROR,'SERVO_Test: could not be initialized');
end;

function  GPIO_MAP_GPIO_NUM_2_HDR_PIN(gpio:longint; mapidx:byte):longint; { Maps GPIO Number to the HDR_PIN, respecting rpi rev1 or rev2 board }
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

function  GPIO_MAP_GPIO_NUM_2_HDR_PIN(gpio:longint):longint;
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

procedure BEEP_SetStruct(var BEEP_struct:BEEP_struct_t; beepgpio:longint; beepcnt,beepHighms,beepLOWms:longword);
begin
  with BEEP_struct do
  begin
    gpio:=beepgpio; cnt:=beepcnt; High_ms:=beepHighms; Low_ms:=beepLOWms; USRbrk:=true;
  end; // with
end;

procedure GPIO_Beep(var BEEP_struct:BEEP_struct_t);
var _cnt:longword;
begin
  with BEEP_struct do
  begin
	if (gpio>=0) then
	begin
	  _cnt:=1; USRbrk:=false;
      while (_cnt<=cnt) and (not USRbrk) and (not terminateProg) do
      begin
	  	GPIO_Pulse(gpio,High_ms);
      	if (Low_ms>0) and (_cnt<cnt) and (not USRbrk) 
      	  then delay_msec(Low_ms);
      	inc(_cnt);
      end;
	end;
  end; // with
end;

function  GPIO_BeepThread(BEEPstructPTR:pointer):ptrint;
begin
  try
	with BEEP_struct_t(BEEPstructPTR^) do
	begin
//	  Thread_SetName('GPIO_BeepThread['+Num2Str(gpio,0)+']'); 
      GPIO_Beep(BEEP_struct_t(BEEPstructPTR^));
    end; // with
  except
	LOG_Writeln(LOG_ERROR,'GPIO_BeepThread');
  end;
  EndThread;  
  GPIO_BeepThread:=0;
end;

function  ENC_GetVal(hdl:integer; ctrsel:integer):real; 
var val:real;
begin 
  val:=0;
  {$warnings off}
  if (hdl>=0) and (hdl<Length(ENC_struct)) then {$warnings on}
  begin
    with ENC_struct[hdl] do
    begin
      with CNTInfo do
      begin
	  	EnterCriticalSection(ENC_CS); 		
          case ctrsel of
        	  0: val:=counter;
	    	  1: val:=cycles;
	    	  2: val:=switchcounter;
	    	  3: if (countermax<>0) then val:=counter/countermax;
	    	  4: val:=TurnRateStruct.fTurnRate_Hz;
	    	  5: val:=switchlastpresstime;	// no reset last value
			  6: begin val:=switchlastpresstime; switchlastpresstime:=0; end;
			  7: val:=ord(kbdupcnt);
			  8: val:=ord(kbddwncnt);
			  9: val:=ord(kbdswitch); 
			 10: val:=countermark;
			 11: begin countermark:=counter; val:=countermark; end;
			 12: if ENC_WasActive then val:=1;
	    	else val:=counter;
	      end; // case
	    end; // with
	  LeaveCriticalSection(ENC_CS);
    end; // with
  end else LOG_Writeln(LOG_ERROR,'ENC_GetVal: hdl '+Num2Str(hdl,0)+' out of range');
  ENC_GetVal:=val;  
end;

function  ENC_GetVal       (hdl:integer):real;		begin ENC_GetVal:=       ENC_GetVal(hdl, 0); end;
function  ENC_GetCycles    (hdl:integer):real;		begin ENC_GetCycles:=    ENC_GetVal(hdl, 1); end;
function  ENC_GetValPercent(hdl:integer):real;		begin ENC_GetValPercent:=ENC_GetVal(hdl, 3); end;
function  ENC_GetSwitch    (hdl:integer):real;		begin ENC_GetSwitch:=    ENC_GetVal(hdl, 2); end;
function  ENC_GetSwPtime   (hdl:integer):real;		begin ENC_GetSwPtime:=   ENC_GetVal(hdl, 5); end;
function  ENC_GetMark	   (hdl:integer):real;		begin ENC_GetMark:=		 ENC_GetVal(hdl,10); end;
function  ENC_SetMark	   (hdl:integer):real;		begin ENC_SetMark:=		 ENC_GetVal(hdl,11); end;
function  ENC_WasActive	   (hdl:integer):boolean;	begin ENC_WasActive:=	(ENC_GetVal(hdl,12)<>0); end;

procedure ENC_IncSwCnt (var ENCInfo:ENC_CNT_struct_t; cnt:integer);
begin inc(ENCInfo.switchcounter,cnt); end;

procedure ENC_IncEncCnt(var ENCInfo:ENC_CNT_struct_t; cnt:integer);
begin inc(ENCInfo.counter,cnt); end;

function  ENC_GetCounter(var ENCInfo:ENC_CNT_struct_t):boolean;
begin
  with ENCInfo do
  begin
    switchlastpresstime:=round(ENC_GetSwPtime(Handle)); 
	switchcounterold:=	switchcounter; 	
	switchcounter:=		round(ENC_GetSwitch(Handle)); 
	counterold:=		counter; 		
	counter:=  			round(ENC_GetVal   (Handle));
	cyclesold:=			cycles;
	cycles:=			round(ENC_GetCycles(Handle));
	swsteps:=			switchcounter-switchcounterold;
	encsteps:=			counter-	  counterold;
	enccycles:=			cycles-	  	  cyclesold;
	case activitymodedetect of
	    1: ENC_activity:=	((encsteps <>0) or (swsteps<>0));
	    2: ENC_activity:=	((swsteps  <>0));
	    3: ENC_activity:=	((enccycles<>0));
	    4: ENC_activity:=	((encsteps <>0));
	  else ENC_activity:=	((enccycles<>0) or (swsteps<>0));
	end; // case
	if ENC_activity then
	begin
  	  if (enccycles>0) then kbdcode:=char(round(ENC_GetVal(Handle,7))); 
	  if (enccycles<0) then kbdcode:=char(round(ENC_GetVal(Handle,8))); 
  	  if (swsteps<>0)  then kbdcode:=char(round(ENC_GetVal(Handle,9)));
  	  ENC_WasActive:=true;
	end;
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

function  ENC_Device(ptr:pointer):ptrint;
(* seq	B	A	  AxorB		  delta	meaning	
	0	0	0		0			0	no change
	1	0	1		1			1	1 step clockwise
	2	1	1		0			2	2 steps clockwise or counter-clockwise (fault condition)
	3	1	0		1			3	1 step counter clockwise *)
var	hdl,cyclold:longint; regval:longword; dt,dt2:TDateTime;
	sw_change,swpress,sw1stpress:boolean; wtim:longword;
begin 
  hdl:=PtrUInt(ptr); 
  if (hdl>=0) and (hdl<Length(ENC_struct)) then
  begin
    with ENC_struct[hdl] do
    begin
      with ThreadCtrl do
      begin
    	ThreadRunning:=true; TermThread:=false;
		Thread_SetName(desc);

	  	InitCriticalSection(ENC_CS);  
	  	SyncTime:=now; dt:=SyncTime; dt2:=dt; 
	  	sw1stpress:=true; wtim:=sleeptime_ms;
	  	
      	repeat
      	  sw_change:=false;
          cyclold:=CNTInfo.cycles;
		  										regval:=mmap_arr^[A_Sig.regget];
		  if (((regval and A_Sig.mask_1Bit) xor A_Sig.mask_pol)>0) then a:=1 else a:=0;

		  if (A_Sig.regget<>B_Sig.regget) then 	regval:=mmap_arr^[B_Sig.regget];
	      if (((regval and B_Sig.mask_1Bit) xor B_Sig.mask_pol)>0) then b:=1 else b:=0;

		  seq:=(a xor b) or (b shl 1);

		  if (S_Sig.gpio>=0) then 
		  begin  // switch
		  	if (B_Sig.regget<>S_Sig.regget) then regval:=(mmap_arr^[S_Sig.regget]);

		 	swpress:=(((regval and S_Sig.mask_1Bit) xor S_Sig.mask_pol)>0);
		  	if swpress then
		  	begin // switch is pressed
			  if sw1stpress then 
		  	  begin	
		      	SetTimeOut(dt,sleeptime_ms);	// Retrigger press time	
		      	dt2:=now;						// switch pressed start time 
			  	sw1stpress:=false;  
		  	  end
		  	  else 
		  	  begin
			  	EnterCriticalSection(ENC_CS); 
			  
			  	  if TimeElapsed(dt,SwitchRepeatTime_ms) then 
			  	  begin
				  	inc(CNTInfo.switchcounter);
			  	  	sw_change:=true; 
			  	  end;
			  	
			 	LeaveCriticalSection(ENC_CS); 
		  	  end;
		  	end else sw1stpress:=true;
		  
		  	if sw_change or (swpress and not sw1stpress) then 
			  CNTInfo.switchlastpresstime:=MilliSecondsBetween(now,dt2); // last switch press time	  
		  end; // switch
		  
		  delta:=0;
		  if (seq<>seqold) then  
		  begin // turning wheel
		  	if (seqold>seq) 
		  	  then delta:=4-(abs(seq-seqold) mod 4) 
		  	  else delta:=(seq-seqold) mod 4;
		  	  
		  	if (delta<>3) then
		  	begin
		  	  if (delta=2) then 
		  	  begin
		  	    if (deltaold<0) then delta:=-delta;
		  	  end; 
		  	end else delta:=-1;
			  
		  	SetTimeOut(CNTInfo.fIntervalResetTime,CNTInfo.Interval_ms); 
		  	SetTimeOut(CNTInfo.DelayResetTime,100);

		  	EnterCriticalSection(ENC_CS); 
			  FREQ_DetTurnRate(CNTInfo.TurnRateStruct,delta); 
			  
			  inc(CNTInfo.counter,delta);
			  if s2minmax 	// 0 - countermax-1
				then Limits(CNTInfo.counter,0,CNTInfo.countermax-1)		
			  	else CNTInfo.counter:=MOD_Euclid(CNTInfo.counter,CNTInfo.countermax);

			  CNTInfo.cycles:= CNTInfo.counter div CNTInfo.steps_per_cycle;
		  	LeaveCriticalSection(ENC_CS);

//        	writeln('Seq:',seq,' seqold:',seqold,' delta:',delta,' deltaold:',deltaold,' b:',b,' a:',a,CR);	
//writeln('cycles:',CNTInfo.cycles,' counter:',CNTInfo.counter,' cmax:',CNTInfo.countermax,' delta:',delta,CR);	 
 
		  	deltaold:=delta; seqold:=seq; wtim:=0;
		  end 
		  else 
		  begin
		  	if TimeElapsed(CNTInfo.fIntervalResetTime) 
		  	  then FREQ_CounterReset(CNTInfo.TurnRateStruct);
		  	
		  	if TimeElapsed(CNTInfo.DelayResetTime)
		  	  then wtim:=sleeptime_ms; 
		  end;

		  if ((cyclold<>CNTInfo.cycles) or sw_change) then
		  begin 
		    if (BEEP.gpio>=0) then BeginThread(@GPIO_BeepThread,@BEEP);
		  end else if (wtim>0) then delay_msec(wtim);

	  	until terminateProg or TermThread;

	  	DoneCriticalSection(ENC_CS);
	  	ThreadRunning:=false;
	  end; // with
	  EndThread;
	end; // with
  end else LOG_Writeln(LOG_ERROR,'ENC_Device: hdl '+Num2Str(hdl,0)+' out of range');
  ENC_Device:=0;
end;

procedure ENC_InfoKBDInit(var CNTInfo:ENC_CNT_struct_t; kbdup,kbddwn,kbdsw:char);
begin
  with CNTInfo do
  begin
	kbdcode:=' '; kbdupcnt:=kbdup; kbddwncnt:=kbddwn; kbdswitch:=kbdsw;
  end;
end;

procedure ENC_InfoInit(var CNTInfo:ENC_CNT_struct_t);
begin
  with CNTInfo do
  begin
    Handle:=-1; 		steps_per_cycle:=4;
    ENC_activity:=false;						activitymodedetect:=0;	
    encsteps:=0;		swsteps:=0;				enccycles:=0;			
    counter:=0;			counterold:=0; 			countermax:=$ffff;			
    switchcounter:=0;	switchcounterold:=0;	switchcountermax:=$ffff;	
    enc:=0; 			encold:=0;  			Interval_ms:=1000;
    fIntervalResetTime:=now;					DelayResetTime:=now;
    switchlastpresstime:=0;
    ENC_InfoKBDInit		(CNTInfo,#38,#40,#13);  countermark:=0;
    FREQ_InitStruct		(TurnRateStruct, 250);	
    ENC_WasActive:=false;
  end; // with
end;

function  ENC_Setup(hdl:integer; stick2minmax:boolean; 
					ctrpreset,ctrmax,stepspercycle:longword; 
					beepergpio:integer):boolean;
//in: 	hdl:			1..ENC_cnt
//		A/B_Sig:		2 GPIOs, which should be used for the Encoder A,B Signal
//      S_Sig:			GPIO, which handles SwitchButton of Encoder. e.g. the KY-040 encoder has a switch. 
//		stick2minmax: 	true,  if we don't want an immediate counter transition from <ctrmax> to 0 or from 0 to <ctrmax>  
//		ctrpreset:		set an initial counter value. multiple of stepspercycle
//		ctrmax:			counter is always between 0 and <ctrmax>
//		stepspercycle:	an regular encoder generates 4 steps per cycle (resolution)
//out:					true, if we could allocate the HW-Pins (success)
var _ok:boolean;
begin
  _ok:=false;
  if (hdl>=0) and (hdl<Length(ENC_struct)) then
  begin
    with ENC_struct[hdl] do
    begin 
	  ok:=(GPIO_Setup(A_Sig) and GPIO_Setup(B_Sig));
	  if (S_Sig.gpio>=0) then ok:=ok and GPIO_Setup(S_Sig);
      if ok then 
      begin	// Pins are available     
        ENC_InfoInit(CNTInfo);  CNTInfo.Handle:=hdl; 
		s2minmax:=stick2minmax; sleeptime_ms:=ENC_SyncTime_c; 
		SwitchRepeatTime_ms:=ENC_SwRepeatTime_c;
	    seqold:=2; deltaold:=0; SwitchFiredSpecFunc:=nil;
		if stepspercycle>0 then CNTInfo.steps_per_cycle:=stepspercycle;
		CNTInfo.cycles:=round(ctrpreset/CNTInfo.steps_per_cycle);
		idxcounter:=0;

		if ((beepergpio>=0) and 
		   (GPIO_MAP_GPIO_NUM_2_HDR_PIN(beepergpio)>=0)) then 
		begin
      	  BEEP_SetStruct (BEEP,beepergpio,1,1,0); // 1x Beep with 1msec
		  GPIO_set_output(BEEP.gpio);	  
		end else BEEP_SetStruct(BEEP,UKN,0,0,0);	
		
		with CNTInfo do
		begin
		  ENC_activity:=false;
		  counter:=(cycles*steps_per_cycle); 
		  counterold:=counter; countermax:=counter+1;
		  if ctrmax>counter then countermax:=ctrmax+1; // wg. counter mod countermax
		end; // with
		
		ENC_GetCounter(CNTInfo);
//		ThreadCtrl.ThreadID:=BeginThread(@ENC_Device,pointer(hdl)); // Start Encoder Thread
		Thread_Start(ThreadCtrl,@ENC_Device,pointer(PtrUInt(hdl)),0,-1); // Start Encoder Thread
      end else LOG_Writeln(LOG_ERROR,'ENC_RotEncInit: Checked Pins not ok');
      _ok:=ok;	  
    end; // with
  end
  else 
  begin
  	if (hdl>ENC_cnt) then 
  	  LOG_Writeln(LOG_ERROR,'ENC_RotEncInit: increase ENC_Cnt:'+Num2Str(ENC_cnt,0)+' hdl:'+Num2Str(hdl,0));
  end;
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
    if ENC_Setup(ENC_hdl,true,0,MAXCount,StepsPerRev,UKN) then
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
	    writeln( 'Counter: ',	round(ENC_GetVal(ENC_hdl,0)):5,
		  	    ' Cycles: ', 	round(ENC_GetVal(ENC_hdl,1)):5,
			    ' Switch: ',	(swcnt mod MAXSWCount):5,
			    ' PressTime: ',	round(ENC_GetSwPtime(ENC_hdl)):5,		// msec
			    ' TurnRate: ',	ENC_GetVal(ENC_hdl,4):4:0,'Hz' 
			    );  // switch cnt 0..(MAXSWCount-1)
        inc(cnt);
      until (swcnt>=term) or TimeElapsed(dt);  // end, if Encoder Switch was pressed <term> times
//    DoneCriticalSection(ENC_CS);
	  writeln('Encoder Thread will terminate');
	  ENC_End(ENC_hdl);
    end else Log_Writeln(Log_ERROR,'ENC_Test: can not init ENC datastruct');
  end; // with
  writeln('ENC Test end.');
end;

function  TRIG_GetValue(hdl:integer; var timesig_ms:longint):integer;
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
  _hdl:=PtrInt(ptr);
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
	  until terminateProg or ThreadCtrl.TermThread;
	  DoneCriticalSection(TRIG_CS);
	end; // with
  end;
  EndThread;
  TRIG_IN_Thread:=0;
end;

procedure TRIG_SetValue(hdl:integer; timesig_ms:longint);
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
  _hdl:=PtrInt(ptr);
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
		    end;
		    if (tim_ms<0) then
		    begin
			  GPIO_set_pin(gpio,false);
			  delay_msec(abs(tim_ms));
			  GPIO_set_pin(gpio,true);
		    end;
		    tim_ms:=0;		  
		  LeaveCriticalSection(TRIG_CS); 
		  delay_msec(SyncTime_ms);
		end; // with
	  until terminateProg or ThreadCtrl.TermThread;
	  DoneCriticalSection(TRIG_CS);
	end; // with
  end;
  EndThread;
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
		     then Thread_Start(ThreadCtrl,@TRIG_IN_Thread, pointer(PtrUInt(_hdl)),0,-1) 
		     else _hdl:=-1;
	    1: if GPIO_Setup (TGPIO)
		     then Thread_Start(ThreadCtrl,@TRIG_OUT_Thread,pointer(PtrUInt(_hdl)),0,-1)
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
var hdl:integer; timesig_ms:longint;
begin
  RPI_HW_Start([InstSignalHandler]);
  hdl:=TRIG_Reg(GPIO_MAP_HDR_PIN_2_GPIO_NUM(HWPIN),'TrigInTest',[INPUT],TRIG_SyncTime_c);
  if (hdl>=0) then
  begin
    repeat
	  if TRIG_GetValue(hdl,timesig_ms)=1 then
	    writeln('Got a TimeSignal on HWPIN#',HWPIN,' with ',timesig_ms,' msec');
	  delay_msec(1000);	// only for report timing
	until terminateProg;
  end;
end;

procedure Show_Buffer(var data:I2C_databuf_t);
begin
  if LOG_Level<=LOG_DEBUG then LOG_Writeln(LOG_DEBUG,HexStr(data.buf.str)); 
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
    for i:=1 to CSV_Count(buspath) do
	begin
	  devpath:=CSV_Item(buspath,i);
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
	      if (rc<0)	then begin LOG_Writeln(LOG_ERROR,'USB_Reset: Error in ioctl '+LNX_ErrDesc(fpgeterrno)+' '+devpath);    end
	                else begin LOG_Writeln(LOG_DEBUG,'USB_Reset: successful '+Num2Str(rc,0)+' '+devpath); rc:=0; end;
	      fpclose(fd);
	      if rc=0 then delay_msec(2000);
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

procedure I2C_EnterCriticalSection(busnum:byte); begin EnterCriticalSection(I2C_bus[busnum].I2C_CS); end;
procedure I2C_LeaveCriticalSection(busnum:byte); begin LeaveCriticalSection(I2C_bus[busnum].I2C_CS); end;

procedure I2C_Show_struct(busnum:byte);
begin
  with I2C_buf[busnum] do
  begin
    Log_Writeln(LOG_DEBUG,'I2C Struct[0x'+HexStr(busnum,2)+']:');
	Log_Writeln(LOG_DEBUG,' .hdl: '+Num2Str(hdl,0));
	Log_Writeln(LOG_DEBUG,' .buf: 0x'+HexStr(buf.str)); 
  end;  
end;

procedure I2C_Display_struct(busnum:byte; comment:string);
begin
  LOG_LevelSave; 
  LOG_LEVEL(LOG_DEBUG); 
  Log_Writeln(LOG_Level,comment); 
  I2C_show_struct(busnum); 
  LOG_LevelRestore;
end;

function  I2C_ChkBusAdr(busnum,baseadr:word):boolean; 
var _ok:boolean;
begin 
  _ok:=((busnum<=I2C_max_bus) and (baseadr>=$03) and (baseadr<=$77));
  if not _ok then 
    LOG_Writeln(LOG_ERROR,'I2C_ChkBusAdr['+HexStr(busnum,2)+'/0x'+HexStr(baseadr,2)+']: not valid');
  I2C_ChkBusAdr:=_ok; 
end; 

function  I2C_GetSpeed(bus:byte):longint;
var _speed_Hz:longint; sh:string;
begin
  {$warnings off}  
  if (bus>=0) and (bus<=1) then
  {$warnings on}  
  begin
// 								 xxd -ps /sys/class/i2c-adapter/i2c-1/of_node/clock-frequency
    _speed_Hz:=RPI_BCM2835_GetNodeValue('/sys/class/i2c-adapter/i2c-'+Num2Str(bus,0)+'/of_node/clock-frequency',sh);
    if _speed_Hz<0 then
    begin // last chance, try dmesg
      call_external_prog(LOG_NONE,'dmesg | grep bcm2708_i2c',sh); 
      sh:=Select_Item(Upper (sh),	'(BAUDRATE','',2);	//  400000)
      sh:=Select_Item(Trimme(sh,4), ')','',1);		//  400000
      if not Str2Num(sh,_speed_Hz) then _speed_Hz:=-1;
    end;
  end else _speed_Hz:=100000;
  I2C_GetSpeed:=_speed_Hz;
end;

function  I2C_GetFuncs(bus:byte):longword;
var funcs:longword;
begin
  funcs:=0;
  with I2C_buf[bus] do
  begin
    if (hdl>=0) then
    begin
	  if fpIOctl(hdl,I2C_FUNCS,@funcs)<0 then LOG_Writeln(LOG_ERROR,'I2C_GetFuncs: '+LNX_ErrDesc(fpgeterrno));
    end;
  end; // with
  I2C_GetFuncs:=funcs;
end;

procedure I2C_ShowFuncs(bus:byte);
var i:integer; sh:string;
begin
  sh:='';
  for i:=0 to 30 do
  begin
    case ((1 shl i) and RPI_I2C_GetFuncs(bus)) of
	  I2C_FUNC_I2C:						sh:=sh+'I2C_FUNC_I2C';
	  I2C_FUNC_10BIT_ADDR:				sh:=sh+'I2C_FUNC_10BIT_ADDR';
	  I2C_FUNC_PROTOCOL_MANGLING:		sh:=sh+'I2C_FUNC_PROTOCOL_MANGLING'; 
  	  I2C_FUNC_SMBUS_PEC:				sh:=sh+'I2C_FUNC_SMBUS_PEC';
  	  I2C_FUNC_NOSTART:					sh:=sh+'I2C_FUNC_NOSTART';
  	  I2C_FUNC_SLAVE:				  	sh:=sh+'I2C_FUNC_SLAVE';
  	  I2C_FUNC_SMBUS_BLOCK_PROC_CALL:	sh:=sh+'I2C_FUNC_SMBUS_BLOCK_PROC_CALL';
  	  I2C_FUNC_SMBUS_QUICK:				sh:=sh+'I2C_FUNC_SMBUS_QUICK';
  	  I2C_FUNC_SMBUS_READ_BYTE:			sh:=sh+'I2C_FUNC_SMBUS_READ_BYTE';
	  I2C_FUNC_SMBUS_WRITE_BYTE:		sh:=sh+'I2C_FUNC_SMBUS_WRITE_BYTE';
	  I2C_FUNC_SMBUS_READ_BYTE_DATA:	sh:=sh+'I2C_FUNC_SMBUS_READ_BYTE_DATA';
	  I2C_FUNC_SMBUS_WRITE_BYTE_DATA:	sh:=sh+'I2C_FUNC_SMBUS_WRITE_BYTE_DATA';
	  I2C_FUNC_SMBUS_READ_WORD_DATA:	sh:=sh+'I2C_FUNC_SMBUS_READ_WORD_DATA'; 
	  I2C_FUNC_SMBUS_WRITE_WORD_DATA:	sh:=sh+'I2C_FUNC_SMBUS_WRITE_WORD_DATA';
	  I2C_FUNC_SMBUS_PROC_CALL:			sh:=sh+'I2C_FUNC_SMBUS_PROC_CALL';
	  I2C_FUNC_SMBUS_READ_BLOCK_DATA:	sh:=sh+'I2C_FUNC_SMBUS_READ_BLOCK_DATA';
	  I2C_FUNC_SMBUS_WRITE_BLOCK_DATA:	sh:=sh+'I2C_FUNC_SMBUS_WRITE_BLOCK_DATA'; 
	  I2C_FUNC_SMBUS_READ_I2C_BLOCK:	sh:=sh+'I2C_FUNC_SMBUS_READ_I2C_BLOCK';
	  I2C_FUNC_SMBUS_WRITE_I2C_BLOCK:	sh:=sh+'I2C_FUNC_SMBUS_WRITE_I2C_BLOCK';
    end;
    sh:=sh+' ';
  end;
  sh:=Trimme(StringReplace(sh,'I2C_FUNC_','',[rfReplaceAll,rfIgnoreCase]),4);
  writeln('I2C_FUNC_ ',sh); 
end;

procedure I2C_CleanBuffer(busnum:byte);
begin with I2C_buf[busnum] do begin hdl:=-1; buf.str:=''; reperr:=true; test:=false; end; end;

procedure I2C_Start(busnum:integer);
var _I2C_path:string;
begin
  _I2C_path:='';
  with I2C_buf[busnum] do
  begin
    I2C_CleanBuffer(busnum);
    I2C_bus[busnum].I2C_useCS:=false;
    I2C_bus[busnum].I2C_speed:=0;
    I2C_bus[busnum].I2C_funcs:=0;
    {$IFDEF UNIX}
      if RPI_run_on_ARM then 
      begin 
	    _I2C_path:=I2C_path_c+Num2Str(busnum,0);
	    if (_I2C_path<>'') and FileExists(_I2C_path) then hdl:=fpOpen(_I2C_path,O_RdWr);
	    if hdl>=0 then 
	    begin
		 {$R-}
	      I2C_bus[busnum].I2C_useCS:=false;
	      InitCriticalSection(I2C_bus[busnum].I2C_CS);
	      I2C_bus[busnum].I2C_speed:=I2C_GetSpeed(busnum);
	      I2C_bus[busnum].I2C_funcs:=I2C_GetFuncs(busnum);	      
	     {$R+}
      	  if not RPI_I2C_ChkFuncs(busnum,I2C_FUNC_I2C) then
			LOG_Writeln(LOG_ERROR,'I2C_start[0x'+HexStr(busnum,2)+']: no I2C_FUNC_I2C');
	    end;
      end;
    {$ENDIF}
    if (hdl<0) and (busnum=RPI_I2C_busgen) then 
      LOG_Writeln(LOG_ERROR,'I2C_start[0x'+HexStr(busnum,2)+']: '+_I2C_path);
  end; // with
end;

procedure I2C_Start; var b:byte; begin for b:=0 to I2C_max_bus do I2C_Start(b); end;

procedure I2C_End(busnum:integer);
begin
  {$IFDEF UNIX}
    if RPI_run_on_ARM then   
      if I2C_buf[busnum].hdl>=0 then 
      begin
//      DoneCriticalSection(I2C_bus[busnum].I2C_CS); // waits forever
        fpClose(I2C_buf[busnum].hdl);
      end;
  {$ENDIF}
  I2C_buf[busnum].hdl:=-1;
end;

procedure I2C_Close_All; var b:byte; begin for b:=0 to I2C_max_bus do I2C_End(b); end;

function  I2C_bus_read(busnum,baseadr:word; cmds:string; len:byte; errhdl:integer):integer;
var rslt,Lcmds:integer; lgt:byte; info:string;
begin
  rslt:=-1;
 try 
  with I2C_buf[busnum] do
  begin
    if (hdl>=0) then
    begin
      lgt:=len; Lcmds:=Length(cmds);
	  info:='I2C_bus_read[0x'+HexStr(busnum,2)+'/0x'+HexStr(baseadr,2);
	  if (Lcmds>0) then info:=info+'/0x'+HexStr(cmds);
	  info:=info+']: ';
//	  writeln(info+' 0x'+HexStr(cmds));
	  {$warnings off}
      if lgt>SizeOf(buf) then 
      begin
        LOG_Writeln(LOG_ERROR,info+'Length exceed buflgt, got: '+Num2Str(len,0)+' max: '+Num2Str(SizeOf(buf),0));
        lgt:=SizeOf(buf.str);
      end;
      {$warnings on}
      {$IFDEF UNIX}
//      if hdl<0 then I2C_start(data);
	    {$warnings off}
//		  rslt:=0;
//        rslt:=fpIOctl(hdl,I2C_TIMEOUT,	pointer(1)); if rslt<0 then begin LOG_Writeln(LOG_ERROR,'I2C_TIMEOUT: '+LNX_ErrDesc(fpgeterrno)); exit(rslt); end; 
//        rslt:=fpIOctl(hdl,I2C_RETRIES,	pointer(2)); if rslt<0 then begin LOG_Writeln(LOG_ERROR,'I2C_RETRIES: '+LNX_ErrDesc(fpgeterrno)); exit(rslt); end;
//        rslt:=fpIOctl(hdl,I2C_SLAVE,  	pointer(baseadr));
          rslt:=fpIOctl(hdl,I2C_SLAVE_FORCE,pointer(baseadr));
	    {$warnings on}
        if rslt<0 then
        begin
          LOG_Writeln(LOG_ERROR,info+'failed to select device: '+LNX_ErrDesc(fpgeterrno));
          ERR_MGMT_UPD(errhdl,_IOC_NONE,lgt,false);	  
	      buf.str:='';
		  exit(rslt);
        end;
	    if (Lcmds>0) then
	    begin
          rslt:=fpWrite(hdl,cmds[1],Lcmds);
          if rslt<>1 then
          begin
            LOG_Writeln(LOG_ERROR,info+'failed to write Register: '+LNX_ErrDesc(fpgeterrno));
            ERR_MGMT_UPD(errhdl,_IOC_WRITE,lgt,false);
		    buf.str:='';
			exit(rslt);
          end;
	    end;
		SetLength(buf.str,1);
        rslt:=fpRead(hdl,buf.str[1],lgt);  
      {$ENDIF}
      if test then I2C_Display_struct(busnum,'I2C_bus_read:');
      if rslt<0 then
      begin
        LOG_Writeln(LOG_DEBUG,info+'failed to read device: '+LNX_ErrDesc(fpgeterrno));
        ERR_MGMT_UPD(errhdl,_IOC_READ,lgt,false);
		buf.str:='';
      end
      else
      begin
	    SetLength(buf.str,rslt);
		ERR_MGMT_UPD(errhdl,_IOC_READ,rslt,true);
        if rslt<lgt then
	      LOG_Writeln(LOG_ERROR,info+'Short read, errnum: '+Num2Str(rslt,0)+' expected length: '+Num2Str(lgt,0)+' got: '+Num2Str(rslt,0));
      end;  
    end;
  end; // with
 except
  On E_rpi_hal_Exception :Exception do writeln('I2C_bus_read: ',E_rpi_hal_Exception.Message); 
 end;
  I2C_bus_read:=rslt;
end;

function  I2C_bus_read(busnum,baseadr,basereg:word; len:byte; errhdl:integer):integer;
var cmds:string;
begin 
  if basereg<>I2C_UseNoReg then cmds:=char(byte(basereg)) else cmds:='';
  I2C_bus_read:=I2C_bus_read(busnum,baseadr,cmds,len,errhdl); 
end;

procedure I2C_prep_IOmsg(var iomsg:I2C_msg_t; baseadr,flgs,lgt:word; bufptr:pointer);
begin
  with iomsg do
  begin
	addr:=	baseadr;
	flags:=	flgs;
	len:=	lgt;	
	bptr:=	bufptr;
  end; // with
end;

procedure I2C_prep_IOmsg(var rdwr:I2C_rdwr_ioctl_data_t; var multmsgs:I2C_rdwr_mult_msgs_t; baseadr:word; const WRbuf:string; WRflgs:word; var RDbuf:I2C_stringbuf_t; RDflgs,RDlen:word);
begin
  with multmsgs do
  begin
  	with rdwr do
  	begin
  	
	  if (Length(WRbuf)>0) and (nmsgs<I2C_RDWR_IOCTL_MAX_MSGS) then
	  begin
	  	I2C_prep_IOmsg(msgs[nmsgs],baseadr,(I2C_M_WR or WRflgs),Length(WRbuf),@WRbuf[1]);	  	
	  	inc(nmsgs);
	  end;
	  
	  if (RDlen>0) and (nmsgs<I2C_RDWR_IOCTL_MAX_MSGS) then
	  begin
	  	if (RDlen<=c_max_Buffer) then
	  	begin
	  	  SetLength(RDbuf.str,0);
		  I2C_prep_IOmsg(msgs[nmsgs],baseadr,(I2C_M_RD or RDflgs),RDlen,@RDbuf.str[1]);
	  	  inc(nmsgs);
	  	end else LOG_Writeln(LOG_ERROR,'I2C_prep_IOmsg['+Num2Str(busno,0)+'/'+HexStr(baseadr,2)+']: rdlen:'+Num2Str(RDlen)+'/'+Num2Str(c_max_Buffer,0)+' max reached');
	  end;	 
	   
	end; // with
  end; // with
end;
  
procedure I2C_init_ROOTmsg(var rdwr:I2C_rdwr_ioctl_data_t; msgptr:I2C_msg_ptr; msgcnt:longword);
begin
  with rdwr do
  begin
	rdwr.msgs:=	msgptr;
	rdwr.nmsgs:=msgcnt;	
  end; // with
end;

procedure I2C_init_MULTmsgs(var multmsgs:I2C_rdwr_mult_msgs_t; busnum:word; errhndl:integer; wipe:boolean);
var i:integer;
begin
  with multmsgs do
  begin
	errhdl:=	errhndl;
	busno:=		busnum;
	if wipe then
	begin
	  for i:= 1 to Length(msgs) do
	  	I2C_prep_IOmsg(msgs[i-1],I2C_UseNoReg,I2C_M_RD,0,nil);
	end;
  end; // with
end;
 
procedure I2C_show_MULTmsgs(var rdwr:I2C_rdwr_ioctl_data_t; var multmsgs:I2C_rdwr_mult_msgs_t);
var i:integer; _bptr:I2C_stringbuf_ptr; sh,sh1:string;
begin
  with multmsgs do
  begin
	sh:='hdl:'+Num2Str(I2C_buf[busno].hdl,0);
  	for i:=1 to rdwr.nmsgs do
  	begin
	  with msgs[i-1] do
  	  begin
  	    _bptr:=I2C_stringbuf_ptr(bptr-1);
  	  	if ((flags and I2C_M_RD)<>0) then 
  	  	begin
  	  	  sh1:=' buf:0x'+HexStr(ShortString(_bptr^.str));
		  sh1:=sh+' msg:'+Num2Str(i,0)+'/'+Num2Str(rdwr.nmsgs,0)+' addr:0x'+HexStr(addr,2)+' bptr:0x'+HexStr(_bptr)+' len:'+Num2Str(len,0)+' flags:0x'+HexStr(flags,4)+sh1;
		  writeln(sh1,CR);
		end else sh1:='';
	  end; // with
  	end;
  end; // with
end;

function  I2C_xfer(var rdwr:I2C_rdwr_ioctl_data_t; var multmsgs:I2C_rdwr_mult_msgs_t):integer;
// https://github.com/raspberrypi/linux/blob/rpi-5.10.y/drivers/i2c/busses/i2c-bcm2835.c#L436
var rslt,i:integer; fperr:longint; rdlen:longword; _bptr:I2C_stringbuf_ptr; _sh:string;
begin
  with multmsgs do
  begin
  	try
//    writeln('I2C_xfer+:',I2C_buf[busno].hdl);
	  if (rdwr.nmsgs>0) then
	  begin	
	  	if (I2C_buf[busno].hdl>=0) then
	  	begin
        {$IFDEF UNIX}
          rslt:=fpIOCTL(I2C_buf[busno].hdl,I2C_RDWR,@rdwr);
		{$ELSE}
		  rslt:=-1;
      	{$ENDIF}
      	  
		  if (rslt<0) then
    	  begin
    	    fperr:=fpgeterrno;
    	    if I2C_buf[busno].reperr then
    	    begin
    	      _sh:='I2C_xfer[0x'+HexStr(busno,2)+'/0x'+HexStr(msgs[0].addr,2)+'/'+Num2Str(rslt,0)+'/'+Num2Str(fperr,0)+'/'+Num2Str(I2C_buf[busno].hdl,0);
    		  if (errhdl<>NO_ERRHNDL) 
    		    then _sh:=_sh+' '+
    				Num2Str(ERR_MGMT_GetInfo(errhdl,0),0)+'/'+
    	  			Num2Str(ERR_MGMT_GetInfo(errhdl,1),0)+'/'+
    	  			Num2Str(ERR_MGMT_GetInfo(errhdl,2),0);
    	  	  _sh:=_sh+']: failed to read device';
    	  	  if (fperr<>0) then _sh:=_sh+': '+LNX_ErrDesc(fperr);
    	      LOG_Writeln(LOG_ERROR,_sh);
//I2C_xfer[0x01/0x73/-1/6 0/5/10]: failed to read device: (0) Success
//    	      I2C_show_MULTmsgs(rdwr,multmsgs);
    	    end;
    	  end;
    	  
    	  rdlen:=0; 
    	  for i:= 1 to rdwr.nmsgs do 
    	  begin
    	    with msgs[i-1] do
    	    begin
    		  if (bptr<>nil) then
    		  begin
    	      	if ((flags and I2C_M_RD)<>0) then
    	      	begin
    	      	  _bptr:=I2C_stringbuf_ptr(bptr-1);	// position to length byte of bufferpointer (ShortString)
    		  	  if (rslt<0)
    		  	  	then SetLength(_bptr^.str,0)
    		  	  	else SetLength(_bptr^.str,len);
//writeln(i:2,': 0x',HexStr(_bptr^.str),' len:',len,' ',HexStr(_bptr),' ',HexStr(pointer(_bptr)-1)+CR);
    		      inc(rdlen,len);
    			end;
    		  end;
    		end; // with
    	  end; // for
    	  
    	  if (rslt>=0) then rslt:=rdlen;
    	  ERR_MGMT_UPD(errhdl,_IOC_READ,rdlen,(rslt>=0));
      	end 
      	else 
      	begin
      	  LOG_Writeln(LOG_ERROR,'I2C_xfer: invalid I2C handle: '+Num2Str(I2C_buf[busno].hdl,0));
      	  rslt:=-3; 
      	end; 
	  end 
	  else 
	  begin
	  	LOG_Writeln(LOG_ERROR,'I2C_xfer: Length=0');
	  	rslt:=-2;
	  end;
   
	except
	  On E_rpi_hal_Exception 		:Exception do 
	  begin
	  	LOG_Writeln(LOG_ERROR,	'I2C_xfer[0x'+HexStr(busno,2)+'/0x'+HexStr(msgs[0].addr,2)+']: exception: '+E_rpi_hal_Exception.Message); 
	  	rslt:=					-9;
	  end; 
  	end;	
  
  end; // with
  I2C_xfer:=rslt;
end;

function  I2C_bus_WrRd(busnum,baseadr:word; const WRbuf:string; WRflgs:word; var RDbuf:I2C_stringbuf_t; RDflgs:word; RDlen:byte; errhdl:integer):integer;
// https://elixir.bootlin.com/linux/v3.19.8/source/drivers/i2c/i2c-core.c
// https://gist.github.com/JamesDunne/9b7fbedb74c22ccc833059623f47beb7 
// http://home.hiwaay.net/~jeffj1/i2c-bcm2708.c
// https://www.raspberrypi.org/forums/viewtopic.php?f=44&t=15840&hilit=i2c+repeated+start&start=50
// not ready, experimental
// @400khz bus speed, each spacing time betweeen two transfers: ca. 30us
// with (I2C_M_RD or I2C_M_NOSTART) 2.5us 
// without 14us between I2C_M_WR / I2C_M_RD
var rdwr:I2C_rdwr_ioctl_data_t; multmsgs:I2C_rdwr_mult_msgs_t;
begin			
  I2C_init_MULTmsgs		(multmsgs, busnum, errhdl, false);
  I2C_init_ROOTmsg		(rdwr,@multmsgs.msgs[0],0);
  I2C_prep_IOmsg		(rdwr,multmsgs, baseadr,WRbuf,WRflgs,RDbuf,RDflgs,RDlen);
  I2C_bus_WrRd:=		I2C_xfer(rdwr,multmsgs);
end;

procedure  I2C_SwitchCombined(openmode:boolean);
var fd:cint; sh:string;
begin
  {$IFDEF UNIX} 
	fd:=fpOpen(I2C_COMBINED_path_c,O_WRONLY);
	if (fd>=0) then
	begin
      if openmode then sh:='1'+#$0a else sh:='0'+#$0a;
      fpwrite(fd,sh,Length(sh));				
      fpclose(fd);
	end;
  {$ENDIF}
end;
		
procedure I2C_ZIP_Test;
// work in progress, not ready
// also not working: i2ctransfer -y -v 1 r2@0x70 r2@0x70
// Error: Sending messages failed: Operation not supported
// https://www.raspberrypi.org/forums/viewtopic.php?f=44&t=315143&p=1891160#p1891160
// it works with old i2c driver (/boot/config.txt: dtoverlay=i2c-bcm2708)
const scnt=4; adr1=$70; adr2=$71; adr3=$73; adr4=$74; lgt=2; tcnt=2; // tcnt=10000;
	  I2CADR:array[1..scnt] of longword=(adr1,adr2,adr3,adr4);

var rslt,i,j:longint; dt1:TDateTime;
	rdwr:I2C_rdwr_ioctl_data_t; multmsgs:I2C_rdwr_mult_msgs_t; 
	buf:array[1..scnt] of I2C_stringbuf_t; 
begin
  writeln('I2C_ZIP_Test:');
//writeln('Funcs: 0x'+HexStr(RPI_I2C_GetFuncs(RPI_I2C_busgen),8)); I2C_ShowFuncs(RPI_I2C_busgen); 

  dt1:=now;
  for j:= 1 to tcnt do
	for i:= 1 to scnt do // single IO per I2C-Addr
	  rslt:=I2C_bus_WrRd(RPI_I2C_busgen,I2CADR[i],'',0,buf[i],0,lgt,NO_ERRHNDL);
  writeln('I2C_bus_WrRd Time:',MilliSecsBetween(dt1),'ms'); 

  for i:= 1 to scnt do
	writeln('I2C single IO test: 0x',HexStr(buf[i].str));	// show single results
  writeln('rslt:',rslt);


  with multmsgs do
  begin	// prepare IOs		
    I2C_init_MULTmsgs(multmsgs,RPI_I2C_busgen,NO_ERRHNDL,true);
    I2C_init_ROOTmsg (rdwr,@multmsgs.msgs[0],0);
	for i:= 1 to scnt do
	  I2C_prep_IOmsg (rdwr,multmsgs,I2CADR[i],'',0,buf[i],0,lgt);  
  end; // with
  
  writeln;
  dt1:=now;
  for j:= 1 to tcnt do
    rslt:=I2C_xfer	 (rdwr,multmsgs);	// do all IOs in one OS call
  writeln('I2C_xfer Time:',MilliSecsBetween(dt1),'ms'); 
  
  I2C_show_MULTmsgs	 (rdwr,multmsgs);
  writeln('rslt:',rslt);
end;  

function oldI2C_string_read(busnum,baseadr:word; cmds:string; len:byte; errhdl:integer; var outs:string):integer; 
var rslt:integer; lgt:byte;
begin   
  with I2C_buf[busnum] do
  begin
    lgt:=len; 
    if len>c_max_Buffer then 
    begin
      LOG_Writeln(LOG_ERROR,'I2C_string_read[0x'+HexStr(busnum,2)+'/0x'+HexStr(baseadr,2)+'/0x'+HexStr(cmds)+']: Length exceed buflgt, got: '+Num2Str(len,0)+' max: '+Num2Str(c_max_Buffer,0));
      buf.str:='';
	  exit(-1);
	  lgt:=c_max_Buffer;
    end;
//  writeln('I2C_string_read1: I2Caddr:0x'+HexStr(baseadr,2)+' reg:0x'+HexStr(cmds)+' busnum:0x'+HexStr(busnum,2)+' lgt:0x'+HexStr(lgt,2));
    rslt:=I2C_bus_read(busnum,baseadr,cmds,lgt,errhdl); 
//  writeln('I2C_string_read2: I2Caddr:0x'+HexStr(baseadr,2)+' reg:0x'+HexStr(cmds)+' busnum:0x'+HexStr(busnum,2)+' lgt:0x'+HexStr(lgt,2)+' rslt:'+Num2Str(rslt,0));  
	outs:=buf.str;
	oldI2C_string_read:=rslt;
  end; // with
end;
function oldI2C_string_read(busnum,baseadr,basereg:word; len:byte; errhdl:integer; var outs:string):integer;
var cmds:string;
begin
  if basereg<>I2C_UseNoReg then cmds:=char(byte(basereg)) else cmds:='';
  oldI2C_string_read:=oldI2C_string_read(busnum,baseadr,cmds,len,errhdl,outs);
end;

function I2C_string_read(busnum,baseadr,basereg:word; RDlen:byte; errhdl:integer; var RDbuf:string):integer;
var rslt:integer; _rdbuf:I2C_stringbuf_t; _wrbuf:string;
begin 
  if (basereg<>I2C_UseNoReg) then _wrbuf:=char(byte(basereg)) else _wrbuf:=''; 
  rslt:=I2C_bus_WrRd(busnum,baseadr,_wrbuf,0,_rdbuf,0,RDlen,errhdl);
  if (rslt>0) then RDbuf:=_rdbuf.str;
  I2C_string_read:=rslt; 
end; 
            
function I2C_string_read(busnum,baseadr:word; const WRbuf:string; RDlen:byte; errhdl:integer; var RDbuf:I2C_stringbuf_t):integer;
var rslt:integer;
begin 
  rslt:=I2C_bus_WrRd(busnum,baseadr,WRbuf,0,RDbuf,0,RDlen,errhdl);
  I2C_string_read:=rslt; 
end;

function I2C_string_read(busnum,baseadr:word; const WRbuf:string; RDlen:byte; errhdl:integer; var RDbuf:string):integer;
var rslt:integer; _rdbuf:I2C_stringbuf_t;
begin 
  rslt:=I2C_string_read(busnum,baseadr,WRbuf,RDlen,errhdl,_rdbuf);
  if (rslt>0) then RDbuf:=_rdbuf.str;
  I2C_string_read:=rslt; 
end; 

function  I2C_string_write(busnum,baseadr:word; const WRbuf:string; errhdl:integer):integer; 
var _rdbuf:I2C_stringbuf_t; 
begin I2C_string_write:=I2C_bus_WrRd(busnum,baseadr,WRbuf,0,_rdbuf,0,0,errhdl); end;

function  I2C_string_write(busnum,baseadr,basereg:word; WRbuf:string; errhdl:integer):integer; 
var _rdbuf:I2C_stringbuf_t; 
begin 
  if (basereg<>I2C_UseNoReg) then WRbuf:=char(byte(basereg))+WRbuf; 
  I2C_string_write:=I2C_bus_WrRd(busnum,baseadr,WRbuf,0,_rdbuf,0,0,errhdl); 
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

function  I2C_byte_read(busnum,baseadr,basereg:word; errhdl:integer):byte; 
// read from the I2C general purpose bus e.g. s:=I2C_string_read($68,$00,7)
var b:byte; sh:string;
begin
  I2C_string_read(busnum,baseadr,basereg,1,errhdl,sh);
  if Length(sh)>=1 then b:=ord(sh[1]) else b:=0;
  I2C_byte_read:=b;
end;

function  oldI2C_bus_write(busnum,baseadr:word; errhdl:integer):integer;
var rslt:integer; lgt:byte;
begin
  rslt:=-1; 
 try
  with I2C_buf[busnum] do
  begin
    if (hdl>=0) then
    begin
      lgt:=Length(buf.str);	
      {$IFDEF UNIX}
//      writeln('i2cwr: 0x'+HexStr(buf)+' ',hdl); 
        {$warnings off} rslt:=fpIOctl(hdl,I2C_SLAVE,pointer(baseadr)); {$warnings on}
        if rslt<0 then
        begin
          LOG_Writeln(LOG_ERROR,'I2C_bus_write[0x'+HexStr(busnum,2)+'/0x'+HexStr(baseadr,2)+']: failed to open device: '+LNX_ErrDesc(fpgeterrno));
          ERR_MGMT_UPD(errhdl,_IOC_NONE,lgt,false);
	      exit(rslt);
        end;
	    rslt:=fpWrite(hdl,buf.str[1],lgt);
      {$ENDIF}
//    I2C_Display_struct(busnum,'I2C_bus_write:');
      if rslt<0 then
      begin
        LOG_Writeln(LOG_ERROR,'I2C_bus_write[0x'+HexStr(busnum,2)+'/0x'+HexStr(baseadr,2)+']: failed to write to device: '+LNX_ErrDesc(fpgeterrno));
        ERR_MGMT_UPD(errhdl,_IOC_WRITE,lgt,false);
      end
      else
      begin
	    ERR_MGMT_UPD(errhdl,_IOC_WRITE,lgt,true);
        if (rslt<lgt) then
	      LOG_Writeln(LOG_ERROR,'I2C_bus_write[0x'+HexStr(busnum,2)+'/0x'+HexStr(baseadr,2)+']: short write, errnum: '+Num2Str(rslt,0)+' expected: '+Num2Str(lgt+1,0)+' got: '+Num2Str(rslt,0));
      end;
    end;
  end; // with
 except
   On E_rpi_hal_Exception :Exception do writeln('I2C_bus_write: ',E_rpi_hal_Exception.Message); 
 end;
  oldI2C_bus_write:=rslt;
end;

function  oldI2C_string_write(busnum,baseadr:word; datas:string; errhdl:integer):integer; 
begin   
  if length(datas)>=c_max_Buffer then 
  begin
    LOG_Writeln(LOG_ERROR,'I2C_string_write['+HexStr(busnum,2)+'/'+HexStr(baseadr,2)+'/'+HexStr(datas)+']: data length:'+Num2Str(length(datas),0)+' exceeds buffer size:'+Num2Str(c_max_Buffer,0));
	exit(-1);
  end;	 
  I2C_buf[busnum].buf.str:=datas; 
  oldI2C_string_write:=oldI2C_bus_write(busnum,baseadr,errhdl); 
end;

function  oldI2C_string_write(busnum,baseadr,basereg:word; datas:string; errhdl:integer):integer;
var _datas:string;
begin
  _datas:=datas; if basereg<>I2C_UseNoReg then _datas:=char(byte(basereg))+_datas;
  oldI2C_string_write:=oldI2C_string_write(busnum,baseadr,_datas,errhdl);
end;
						
function  I2C_word_write(busnum,baseadr,basereg:word; data:word; flip:boolean; errhdl:integer):integer; 
var sh:string;								// e.g: 0x4321
begin
  if flip 	then sh:=char(byte(data))+char(byte(data shr 8))	// 2143
			else sh:=char(byte(data shr 8))+char(byte(data));	// 4321
  I2C_word_write:=I2C_string_write(busnum,baseadr,basereg,sh,errhdl);
end;

function  I2C_word_write(baseadr,basereg:word; data:word; flip:boolean; errhdl:integer):integer;
begin I2C_word_write:=I2C_word_write(RPI_I2C_busgen,baseadr,basereg,data,flip,errhdl); end;

function  I2C_byte_write(busnum,baseadr,basereg:word; data:byte; errhdl:integer):integer; 
begin I2C_byte_write:=I2C_string_write(busnum,baseadr,basereg,char(data),errhdl); end;

procedure eeprom_SetAddr(devaddr:word); begin eeprom_devadr:=devaddr; end;

function  eeprom_write_page(startadr:word; datas:string):integer;
//write a string to the EEPROM @ I2C-Adr 0x50 startaddr 
begin eeprom_write_page:=I2C_string_write(RPI_I2C_bus2nd,eeprom_devadr,startadr,datas,NO_ERRHNDL); end;

function  eeprom_read_page(startadr:word; len:byte; var outs:string):integer;
begin eeprom_read_page:=I2C_string_read(RPI_I2C_bus2nd,eeprom_devadr,startadr,len,NO_ERRHNDL,outs); end;

//https://www.raspberrypi.org/forums/viewtopic.php?p=521067#p521067
function  BT_RFCOMM(chan:word; bindatstart:boolean; btdev,desc:string):boolean;
// http://www.raspberry-projects.com/pi/pi-operating-systems/raspbian/bluetooth/serial-over-bluetooth
//IN: chan: eg. 1
//IN: bindatstart: e.g. true
//IN: btdev: xx:xx:xx:xx:xx:xx
//IN: desc: My Bluetooth Connection 
const fil='/etc/bluetooth/rfcomm.conf';
var ts:TStringList;
begin
  if btdev<>'' then
  begin
    if desc='' then desc:='BT';
	ts:=TStringList.create;
	ts.add('rfcomm'+Num2Str(chan,0)+' {');
	ts.add('  # Automatically bind the device at startup');
	ts.add('  bind '+lower(Bool2YN(bindatstart))+';');
	ts.add('');
	ts.add('  # Bluetooth address of partner device');
	ts.add('  device '+btdev+';');
	ts.add('');
	ts.add('  # RFCOMM channel for the connection');
	ts.add('  channel '+Num2Str(chan,0)+';');
	ts.add('');
	ts.add('  # Description of the connection');
	ts.add('  comment "'+desc+'";');
	ts.add('}');
	StringList2TextFile(fil,ts);
	ts.free;
  end;
  BT_RFCOMM:=(FileExists(fil));
end;

procedure HW_SetInfoStruct(var DeviceStruct:HW_DevicePresent_t; DevTyp:t_IOBusType; BusNr,HWAdr:integer; ManufType:t_Manu_flag; dsc:string);
begin with DeviceStruct do begin BusNum:=BusNr; HWAddr:=HWAdr; DevType:=DevTyp; descr:=dsc; Manuf:=ManufType; end; end;

procedure HW_IniInfoStruct(var DeviceStruct:HW_DevicePresent_t);
begin
  HW_SetInfoStruct(DeviceStruct,UnknDev,hdl_unvalid,hdl_unvalid,unknownManufacturer,'');
  with DeviceStruct do begin Xpresent:=false; Hndl:=hdl_unvalid; end;
end;

function  SPI_HWpresent(var DeviceStruct:HW_DevicePresent_t):boolean;
begin
  with DeviceStruct do
  begin
	SPI_HWpresent:=Xpresent;
  end;
end;

function  SPI_HWT(var DeviceStruct:HW_DevicePresent_t; bus,adr,lgt:word; ManufType:t_Manu_flag; cmds:string; Handle:integer; rv1,nv1,nv2,dsc:string):boolean;
var _devpath:string;
begin
  with DeviceStruct do
  begin
    HW_IniInfoStruct(DeviceStruct);
    HW_SetInfoStruct(DeviceStruct,SPIDev,0,hdl_unvalid,ManufType,dsc);
    
    _devpath:=spi_path_c+Num2Str(bus,0)+'.'+Num2Str(adr,0);
	Xpresent:=((_devpath<>'') and FileExists(_devpath));

    if Xpresent  then begin BusNum:=bus; HWaddr:=adr; hndl:=Handle; end;
    SPI_HWT:=Xpresent;
  end;
end;

function  I2C_HWpresent(var DeviceStruct:HW_DevicePresent_t):boolean;
begin
  with DeviceStruct do
  begin
	I2C_HWpresent:=(HWaddr<>i2c_unvalid_addr);
  end;
end;

function  I2C_HWT(var DeviceStruct:HW_DevicePresent_t; bus,adr,lgt:word; ManufType:t_Manu_flag; cmds:string; Handle:integer; rv1,nv1,nv2,dsc,dsc2:string):boolean;
// I2C HardwareTest. used to determine, device available on i2c bus
// usage e.g. DisplayPresent:=I2C_HWT(RPI_I2C_busnum,LCD_I2C_ADR,#$01,1,'','','LCD');
var _lvl:t_errorlevel; _oreperr,_present:boolean; info:string; 
begin
  with DeviceStruct do
  begin
	with I2C_buf[bus] do
	begin
      HW_IniInfoStruct(DeviceStruct); _present:=false; _lvl:=LOG_WARNING;
      HW_SetInfoStruct(DeviceStruct,I2CDev,bus,i2c_unvalid_addr,ManufType,dsc);
      info:=dsc+'[0x'+HexStr(bus,2)+'/0x'+HexStr(adr,2);
      if (cmds<>'') then info:=info+'/0x'+HexStr(cmds);
      if (dsc2<>'') then info:=info+'/'+  dsc2;
      info:=info+']: ';    
//    writeln('info:',info);
      if I2C_ChkBusAdr(bus,adr) then
      begin  
      	_oreperr:=reperr;
      	reperr:=false; 
      	I2C_string_read(bus,adr,cmds,lgt,NO_ERRHNDL,buf);
      	reperr:=_oreperr;  
      	_present:=(buf.str<>'');     
      	if _present 			  then _present:=_present and (Length(buf.str)= lgt);
      	if _present and (rv1<>'') then _present:=_present and (HexStr(buf.str)= rv1); 
      	if _present and (nv1<>'') then _present:=_present and (HexStr(buf.str)<>nv1); 
      	if _present and (nv2<>'') then _present:=_present and (HexStr(buf.str)<>nv2); 
      	if _present then 
      	begin
    	  _lvl:=LOG_NOTICE;
    	  BusNum:=bus; HWaddr:=adr; hndl:=Handle;
      	end;
      	if (buf.str<>'')	then 
      	  info:=info+'0x'+HexStr(buf.str) else info:=info+'nodata';
      	SAY(_lvl,info);
      end;
      I2C_HWT:=_present;
  	end; // with
  end; // with
end;
function  I2C_HWT(var DeviceStruct:HW_DevicePresent_t; bus,adr,lgt:word; ManufType:t_Manu_flag; cmds:string; Handle:integer; rv1,nv1,nv2,dsc:string):boolean;
begin I2C_HWT:=I2C_HWT(DeviceStruct,bus,adr,lgt,ManufType,cmds,Handle,rv1,nv1,nv2,dsc,''); end;

function  I2C_HWSpeedT(BusNum,HWaddr,rdlgt:word; loops:longword; cmds,dsc:string):real;
// out: kb/sec
const rdflgs=I2C_M_NOSTART;
var n,bcnt,rdcnt,wrcnt:longword; hndl:integer; ok:boolean; r,r2:real; 
  	BusRDtime:TMR_struct_t; data:I2C_stringbuf_t;
begin
  hndl:=ERR_NEW_HNDL(HWaddr,'I2C_HWSpeedT['+dsc+']:',0,0);
  bcnt:=0; wrcnt:=Length(cmds); ok:=true; 
  TMR_Init(BusRDtime);
  for n:=1 to loops do
  begin
	TMR_GetStartTime(BusRDtime);
	rdcnt:=I2C_bus_WrRd(BusNum,HWaddr,cmds,0,data,rdflgs,rdlgt,hndl);
	TMR_GetEndTime(BusRDtime);
	{$warnings off}  
	  if (rdcnt>=0) then inc(bcnt,rdcnt+wrcnt) else ok:=false;
	{$warnings on}  
  end;
//writeln('data: ',HexStr(data.str));
  with BusRDtime do
  begin
	r:=tim_ns_min/1000000*cnt;
  end; // with
  if ok and (r>0) and (loops>0) then
  begin	
// https://www.kernel.org/doc/Documentation/i2c/i2c-protocol
//							WRBytes+1			 				RDBytes+1										
//I2C:		S Addr Wr [A] 	[Data] NA 		S Addr Rd [A] 		Data [A]	P
//Bits: 	1  7   1   1     8     1 		1  7   1   1   		 8    1  	1
//Sum:		---- 10 ----					---- 10 ----					1
	r2:=(bcnt+21)/8; 	// protocol overhead, 1Bit (ACK/NACK) per Byte + 21 Bit
	r:=((bcnt+r2)/1024)/(r/1000);	// kB/sec
  end else r:=0;
  if (loops>1) then
  begin
	with BusRDtime do
	begin
	  SAY(LOG_INFO,'I2C_HWSpeedT['+dsc+']: RDtime MinMax: '+Num2Str(tim_ns_min,5)+' - '+Num2Str(tim_ns_max,5)+'ns cnt: '+Num2Str(cnt,0));
	end; // with
  end;
//if not ok then 
  ERR_Report(hndl);
  I2C_HWSpeedT:=r;
end;

function  I2C_HWSpeedT(var DeviceStruct:HW_DevicePresent_t; lgt:word; loops:longword; cmds,dsc:string):real;
var r:real;
begin
  r:=0;
  with DeviceStruct do
  begin
	if (HWaddr<>i2c_unvalid_addr)	
	  then r:=I2C_HWSpeedT(BusNum,HWaddr,lgt,loops,cmds,dsc)
	  else LOG_Writeln(LOG_ERROR,'I2C_HWSpeedT[0x'+HexStr(BusNum,2)+'/0x'+HexStr(HWaddr,2)+']: '+dsc+' not present');
  end; // with
  I2C_HWSpeedT:=r;
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
    LOG_Level(LOG_DEBUG); 
	I2C_show_struct(RPI_I2C_busgen); 
	LOG_Level(LOG_WARNING);
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
	LOG_Level(LOG_DEBUG); 
	I2C_show_struct(RPI_I2C_busgen); 
	LOG_Level(LOG_WARNING); 
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
    Log_Writeln(errlvl,'SPI Struct:    0x'+HexStr(PtrUInt(addr(spi_strct)),8)+' struct size: 0x'+HexStr(sizeof(spi_strct),4));
    Log_Writeln(errlvl,' .tx_buf_ptr:  0x'+HexStr(tx_buf_ptr,8));
    Log_Writeln(errlvl,' .rx_buf_ptr:  0x'+HexStr(rx_buf_ptr,8));
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
	Log_Writeln(errlvl,' .spi_maxspeed:    '+Num2Str(spi_maxspeed,0));
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
      Log_Writeln(errlvl,' .spi_IOC_mode:0x'+HexStr(spi_IOC_mode,8));
 //   Log_Writeln(errlvl,' .dev_GPIO_int:  '+Num2Str(dev_GPIO_int,0));
      Log_Writeln(errlvl,' .dev_GPIO_en:   '+Num2Str(dev_GPIO_en,0));
	  Log_Writeln(errlvl,' .dev_GPIO_ook:  '+Num2Str(dev_GPIO_ook,0));
   end; // with
 end else Log_Writeln(Log_ERROR,'SPI_show_dev_info_struct: busnum/devnum out of range');
end; 

procedure SPI_show_buffer(busnum,devnum:byte);
const errlvl=LOG_INFO; maxshowbuf=35;
var i,eidx:longint; sh:string;
begin
  with spi_buf[busnum,devnum] do
  begin
    eidx:=endidx; if eidx>maxshowbuf then eidx:=maxshowbuf; // just show the beginning of the buffer
    SAY(errlvl,'SPI Buffer['+Num2Str(busnum,0)+'/'+Num2Str(devnum,0)+']:');
    SAY(errlvl,' .reg:         0x'+HexStr(reg,4));
    if (posidx<=eidx) and (eidx>0) then
    begin
	  sh:=' .buf['+Num2Str(posidx,2)+'..'+Num2Str(eidx,2)+']:  0x';
      for i:= posidx to (eidx+1)*2 do sh:=sh+HexStr(ord(buf[i]),2); sh:=sh+' ... ';                                                              
      for i:= posidx to (eidx+1) do sh:=sh+StringPrintable(buf[i]);
      SAY(errlvl,sh);
    end
    else
    begin
      SAY(errlvl,' .buf:           <empty>');
    end;
    SAY(errlvl,' .posidx:        '+Num2Str(posidx,0));
    SAY(errlvl,' .endidx:        '+Num2Str(endidx,0));
  end;
end;

function  _IOC(dir:byte; typ:char; nr,size:word):longword;
{ source http://www.cs.fsu.edu/~baker/devices/lxr/http/source/linux/include/asm-i386/ioctl.h?v=2.6.11.8
         http://lkml.indiana.edu/hypermail/linux/kernel/0108.2/0125.html
		  |dd|ssssssssssssss|tttttttt|nnnnnnnn|
}
begin
  _ioc:=(dir      shl _IOC_DIRSHIFT)  or		// dir  shl 30
        (ord(typ) shl _IOC_TYPESHIFT) or		// typ 	shl  8
        (nr       shl _IOC_NRSHIFT)   or		// nr  	shl  0
        (size     shl _IOC_SIZESHIFT); 			// size shl 16
end;
 
function  _IO  (typ:char; nr:word):longword;      begin _IO  :=_IOC(_IOC_NONE,                typ,nr,0);         end;
function  _IOR (typ:char; nr,size:word):longword; begin _IOR :=_IOC(_IOC_Read,                typ,nr,size);      end;
function  _IOW (typ:char; nr,size:word):longword; begin _IOW :=_IOC(_IOC_Write,               typ,nr,size);      end;
function  _IOWR(typ:char; nr,size:word):longword; begin _IOWR:=_IOC((_IOC_Write or _IOC_Read),typ,nr,size);      end;

function  SPI_GetSpeed(bus:byte):longint;
var _speed_Hz:longint; sh:string;
begin
  {$warnings off}  
  if (bus>=0) and (bus<=1) then
  {$warnings on}  
  begin
    _speed_Hz:=RPI_BCM2835_GetNodeValue('/sys/class/spidev/spidev0.'+Num2Str(bus,0)+'/device/of_node/spi-max-frequency',sh);
//	writeln('SPI_GetSpeed',bus,' ',_speed_Hz);
    if _speed_Hz<=0 then _speed_Hz:=spi_speed_c;
  end else _speed_Hz:=spi_speed_c;
  SPI_GetSpeed:=_speed_Hz;
end;

function SPI_ClockDivider(spi_hz:real):word;
// Clock Divider // SCLK = Core Clock / CDIV // page 156
var cdiv:word; lw:longword; coreclk:real;
begin
  coreclk:=CLK_GetFreq(5);
  if (spi_hz<(coreclk/2)) then
  begin
    cdiv:=0;
	if (spi_hz>0) then
    begin // CDIV must be a power of two. Odd numbers rounded down.
      lw:=RoundUpPow2(DivRoundUp(coreclk,spi_hz));
	  if (lw<=$ffff) then cdiv:=word(lw) else cdiv:=0 // 0 is the slowest we can go
    end;
  end else cdiv:=2; // coreclk/2 is the fastest we can go
  SPI_ClockDivider:=cdiv;
end;

function SPI_GetFreq(spi_hz:real):longword; 
var cdiv:longword;
begin 
  cdiv:=SPI_ClockDivider(spi_hz);
  if cdiv=0 then cdiv:=$10000;	// handle slowest
  SPI_GetFreq:=round(CLK_GetFreq(5)/cdiv);
end;

function  SPI_ClkWrite(spi_hz:real):longword;
//https://github.com/raspberrypi/linux/blob/rpi-4.9.y/drivers/spi/spi-bcm2835.c
var cdiv:word; hz:longword;
begin
  cdiv:=SPI_ClockDivider(spi_hz);
  hz:=SPI_GetFreq(spi_hz);
  SAY(LOG_INFO,'SPI_ClkWrite: '+Num2Str((hz/1000),0,0)+'kHz cdiv:0x'+HexStr(cdiv,4)+' cdivold:0x'+HexStr(BCM_GETREG(SPI0_CLK),8));
  BCM_SETREG(SPI0_CLK,cdiv,false,false);
  SPI_ClkWrite:=hz;
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
  if rslt<0 then Log_Writeln(LOG_ERROR,'SPI_Mode Mode: 0x'+HexStr(mode,8)+' spifd:'+Num2Str(spifd,0)+' err:'+LNX_ErrDesc(fpgeterrno));
  SPI_Mode:=rslt;
end;

procedure SPI_EnterCriticalSection(busnum:byte); begin EnterCriticalSection(SPI_bus[busnum].SPI_CS); end;
procedure SPI_LeaveCriticalSection(busnum:byte); begin LeaveCriticalSection(SPI_bus[busnum].SPI_CS); end;

procedure SPI_SetDevErrHndl(busnum,devnum:byte; errhdl:integer);
begin spi_dev[busnum,devnum].errhndl:=errhdl; end;

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
	    len				:= xferlen; 
	    pad				:= 0;
	    tx_nbits		:= 0;
	    rx_nbits		:= 0;
	    if ((spi_mode and SPI_TX_QUAD)<>0)
	      then tx_nbits:=4
	      else if ((spi_mode and SPI_TX_DUAL)<>0) then tx_nbits:=2;
	    if ((spi_mode and SPI_RX_QUAD)<>0)
	      then rx_nbits:=4
	      else if ((spi_mode and SPI_RX_DUAL)<>0) then rx_nbits:=2;  
		if ((spi_mode and SPI_LOOP)<>0) then
		begin
			if ((spi_mode and SPI_TX_DUAL)<>0) then spi_mode:=spi_mode or SPI_RX_DUAL;
			if ((spi_mode and SPI_TX_QUAD)<>0) then spi_mode:=spi_mode or SPI_RX_QUAD;
		end;    
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
  USBDEVFS_RESET:=				_IO  ('U',			20);
  SPI_IOC_RD_MODE:=				_IOR (SPI_IOC_MAGIC, 1, 1);
  SPI_IOC_WR_MODE:=				_IOW (SPI_IOC_MAGIC, 1, 1);
  SPI_IOC_RD_LSB_FIRST:=		_IOR (SPI_IOC_MAGIC, 2, 1);
  SPI_IOC_WR_LSB_FIRST:=		_IOW (SPI_IOC_MAGIC, 2, 1);
  SPI_IOC_RD_BITS_PER_WORD:=	_IOR (SPI_IOC_MAGIC, 3, 1);
  SPI_IOC_WR_BITS_PER_WORD:=	_IOW (SPI_IOC_MAGIC, 3, 1);
  SPI_IOC_RD_MAX_SPEED_HZ:=		_IOR (SPI_IOC_MAGIC, 4, 4);	// SizeOf(longint) ??
  SPI_IOC_WR_MAX_SPEED_HZ:=		_IOW (SPI_IOC_MAGIC, 4, 4); // SizeOf(longint) ??
  IOCTL_TAG_PROPERTY:=			_IOWR('d',			 0, SizeOf(pointer));
//IOCTL_MBOX_PROPERTY:=			_IOWR(char(100), 	 0, SizeOf(pointer));
  WDIOC_SETTIMEOUT:=			_IOWR('W',			 6, SizeOf(longint));
  WDIOC_GETTIMEOUT:=			_IOR ('W',			 7, SizeOf(longint));
  WDIOC_KEEPALIVE:=				_IOR ('W',			 5, SizeOf(longint));
  WDIOC_GETBOOTSTATUS:=			_IOR ('W',			 2, SizeOf(longint));
  WDIOC_GETSTATUS:=				_IOR ('W',			 1, SizeOf(longint));
  WDIOC_GETSUPPORT:=			_IOR ('W',			 0, SizeOf(watchdog_info_t));
end;

function  SPI_Transfer(busnum,devnum:byte; cmdseq:string):integer;
// http://www.netzmafia.de/skripten/hardware/RasPi/RasPi_SPI.html
const numxfer=1;
var rslt,xlen:integer; xfer:array[0..(numxfer-1)] of spi_ioc_transfer_t; 
begin
  rslt:=-1; xlen:=Length(cmdseq); 
 try
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
        SPI_Struct_Init(busnum,devnum,xfer[0],addr(buf[1]),addr(buf[1]),xlen); 
        buf:=copy(cmdseq,1,xlen); endidx:=xlen;
//		SPI_show_buffer(busnum,devnum);
//      SPI_Show_Struct(xfer[0]);
        {$IFDEF UNIX} 
          rslt:=fpioctl(spi_dev[busnum,devnum].spi_fd,SPI_IOC_MESSAGE(numxfer),addr(xfer[0])); 
        {$ENDIF}
        if rslt<0 then 
        begin
	      buf:='';
          Log_Writeln(LOG_ERROR,	
		    'SPI_transfer['+Num2Str(busnum,0)+'/'+Num2Str(devnum,0)+'/fd:'+Num2Str(spi_dev[busnum,devnum].spi_fd,0)+']: '+
		    'cmdseq: 0x'+HexStr(cmdseq)+' '+
		    LNX_ErrDesc(fpgeterrno));
//	      ERR_MGMT_UPD(spi_dev[busnum,devnum].errhndl,_IOC_WRITE,xlen,false);
        end
        else 
	    begin
	      posidx:=1; endidx:=rslt; SetLength(buf,rslt);
//	      ERR_MGMT_UPD(spi_dev[busnum,devnum].errhndl,_IOC_READ, rslt,true);
//	      ERR_MGMT_UPD(spi_dev[busnum,devnum].errhndl,_IOC_WRITE,rslt,true);
	    end;
      end; // with
    end;
  end else LOG_Writeln(LOG_ERROR,'SPI_Transfer[0x'+HexStr(busnum,2)+'/0x'+HexStr(devnum,2)+']: invalid busnum/devnum');
 except
   On E_rpi_hal_Exception :Exception do writeln('SPI_Transfer: ',E_rpi_hal_Exception.Message); 
 end;
  SPI_Transfer:=rslt;
end;

function  SPI_Write(busnum,devnum:byte; basereg,data:word):integer;
var rslt:integer; xfer:spi_ioc_transfer_t; buf:array[0..1] of byte;
begin
  rslt:=-1; 
Log_Writeln(LOG_WARNING,'SPI_write Reg: 0x'+HexStr(basereg,4)+' Data: 0x'+HexStr(data,4));
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
                          ' spi_busnum: '+Num2Str(busnum,0)+' '+
                          LNX_ErrDesc(fpgeterrno));
    end
    else
    begin
    writeln('SPI_WRITE: result',rslt);
      ERR_MGMT_UPD(spi_dev[busnum,devnum].errhndl,_IOC_WRITE,2,true);
    end;
  end else LOG_Writeln(LOG_ERROR,'SPI_Write[0x'+HexStr(busnum,2)+'/0x'+HexStr(devnum,2)+']: invalid busnum/devnum');
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
//    Log_Writeln(LOG_ERROR,'SPI_read Reg: 0x'+HexStr(reg,4)+' err: '+LNX_ErrDesc(fpgeterrno));
	  ERR_MGMT_UPD(spi_dev[busnum,devnum].errhndl,_IOC_READ,1,false);
    end
    else 
    begin 
	  SetLength(xbuf.buf,rslt);
      b:=byte(xbuf.buf[1]); 
//    Log_Writeln(LOG_ERROR,'SPI_read Reg: 0x'+HexStr(basereg,4)+' Data: 0x'+HexStr(xbuf.buf)+' rslt:'+Num2Str(rslt,0));
      ERR_MGMT_UPD(spi_dev[busnum,devnum].errhndl,_IOC_READ,1,true);	
    end;
  end else LOG_Writeln(LOG_ERROR,'SPI_Read[0x'+HexStr(busnum,2)+'/0x'+HexStr(devnum,2)+']: invalid busnum/devnum');
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
  end else LOG_Writeln(LOG_ERROR,'SPI_BurstRead[0x'+HexStr(busnum,2)+'/0x'+HexStr(devnum,2)+']: invalid busnum/devnum');
  SPI_BurstRead:=b;
end;

procedure SPI_BurstRead2Buffer(busnum,devnum,basereg:byte; len:longword);
{ full duplex, see example spidev_fdx.c}
var rslt:integer; xfer : array[0..1] of spi_ioc_transfer_t;
begin
//  Log_Writeln(LOG_DEBUG,'SPI_BurstRead2Buffer devnum:0x'+HexStr(devnum,4)+' reg:0x'+HexStr(start_reg,4)+' len:0x'+HexStr(len,8));
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

//    Log_Writeln(LOG_DEBUG,'fpioctl('+Num2Str(spi_bus[busnum].spi_fd,0)+', 0x'+HexStr(SPI_IOC_MESSAGE(2),8)+', 0x'+HexStr(longword(addr(xfer)),8)+')'); 
      {$IFDEF UNIX}
	    rslt:=fpioctl(spi_dev[busnum,devnum].spi_fd,SPI_IOC_MESSAGE(2),addr(xfer)); { full duplex }
      {$ENDIF} 
      if rslt<0 then 
	  begin
//	    Log_Writeln(LOG_ERROR,'SPI_BurstRead2Buffer fpioctl err: '+LNX_ErrDesc(fpgeterrno));
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
  end else LOG_Writeln(LOG_ERROR,'SPI_BurstRead2Buffer[0x'+HexStr(busnum,2)+'/0x'+HexStr(devnum,2)+']: invalid busnum/devnum');
//  Log_Writeln(LOG_DEBUG,'SPI_BurstRead2Buffer (end)');
end;

procedure SPI_BurstWriteBuffer(busnum,devnum,basereg:byte; len:longword);
// Write 'len' Bytes from Buffer SPI Dev startig at address 'reg'
var rslt:integer; xfer : spi_ioc_transfer_t;
begin
//  Log_Writeln(LOG_DEBUG,'SPI_BurstWriteBuffer devnum:0x'+HexStr(devnum,4)+' reg:0x'+HexStr(start_reg,4)+' xferlen:0x'+HexStr(xferlen,8));
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
// 	  if LOG_Get_Level<=LOG_DEBUG then Log_Writeln(LOG_DEBUG,'fpioctl('+Num2Str(spi_bus[busnum].spi_fd,0)+', 0x'+HexStr(SPI_IOC_MESSAGE(1),8)+', 0x'+HexStr(longword(addr(xfer)),8)+')'); 
	  {$IFDEF UNIX}
	    rslt:=fpioctl(spi_dev[busnum,devnum].spi_fd,SPI_IOC_MESSAGE(1),addr(xfer)); 
	  {$ENDIF}
      if rslt<0 then Log_Writeln(LOG_ERROR,'SPI_BurstWriteBuffer fpioctl err: '+LNX_ErrDesc(fpgeterrno))
	            else inc(spi_buf[busnum,devnum].posidx,rslt-1); //rslt-1 wg. reg + buffer content
//	  if LOG_Get_Level<=LOG_DEBUG then show_spi_buffer(busnum,devnum);
    end;
  end else LOG_Writeln(LOG_ERROR,'SPI_BurstWriteBuffer[0x'+HexStr(busnum,2)+'/0x'+HexStr(devnum,2)+']: invalid busnum/devnum');
end;

procedure SPI_StartBurst(busnum,devnum:byte; reg:word; writeing:byte; len:longint);
begin
//Log_Writeln(LOG_DEBUG,'StartBurst StartReg: 0x'+HexStr(reg,4)+' writing: '+Bool2Str(writeing<>0));
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
  end else LOG_Writeln(LOG_ERROR,'SPI_StartBurst[0x'+HexStr(busnum,2)+'/0x'+HexStr(devnum,2)+']: invalid busnum/devnum');
end;

procedure SPI_EndBurst(busnum,devnum:byte);
begin
//Log_Writeln(LOG_DEBUG,'SPI_EndBurst');
  if (busnum<=spi_max_bus) and (devnum<=spi_max_dev) then
  begin
    spi_buf[busnum,devnum].endidx:=0; 
    spi_buf[busnum,devnum].posidx:=1; // initiate BurstRead2Buffer
  end else LOG_Writeln(LOG_ERROR,'SPI_EndBurst[0x'+HexStr(busnum,2)+'/0x'+HexStr(devnum,2)+']: invalid busnum/devnum');
end;

function  xxSPI_Dev_Init(busnum,devnum:byte):boolean;
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
	  spi_speed		:= SPI_GetSpeed(busnum); 
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
	    Log_Writeln(LOG_ERROR,'SPI_Dev_Init[0x'+HexStr(busnum,2)+'/'+HexStr(devnum,2)+']: '+spi_path);
	    if LOG_Level<=LOG_DEBUG then SPI_show_dev_info_struct(busnum,devnum);
	  end
	  else ok:=true;
    end; // with
  end else LOG_Writeln(LOG_ERROR,'SPI_Dev_Init[0x'+HexStr(busnum,2)+'/0x'+HexStr(devnum,2)+']: invalid busnum/devnum');
//SPI_show_dev_info_struct(spi_dev[devnum], devnum);
  xxSPI_Dev_Init:=ok;
end;

function  SPI_Dev_Init(busnum,devnum,bpw,cs_change:byte; mode,maxspeed_hz:longword; delay_usec:word):boolean;
var ok:boolean; res:integer; 
begin
  ok:=false;
  if (busnum<=spi_max_bus) and (devnum<=spi_max_dev) then
  begin
    with spi_dev[busnum,devnum] do 
    begin 
	  errhndl		:= NO_ERRHNDL;
	  isr_enable	:= false;
	  isr.gpio		:= -1;
	  spi_bpw		:= bpw;
      spi_delay		:= delay_usec;
      if cs_change<>0  then spi_cs_change:=1 else spi_cs_change:=0;     
	  spi_speed		:= maxspeed_hz;
      spi_mode		:= mode;
	  spi_IOC_mode	:= SPI_IOC_RD_MODE; 
	  spi_path		:=spi_path_c+Num2Str(busnum,0)+'.'+Num2Str(devnum,0);
//writeln('SPI_Dev_Init: ',spi_path,' speed:',(spi_speed div 1000),'kHz');
	  if (spi_path<>'') and FileExists(spi_path) then
      begin
	    {$IFDEF UNIX} 
	      if spi_fd<0 then spi_fd:=fpOpen(spi_path,O_RdWr); 	 
		  res:=fpioctl(spi_fd,SPI_IOC_WR_MODE,@spi_mode);
		  if (res=-1) then Log_Writeln(Log_ERROR,'SPI_Dev_Init: can''t set SPI mode 0x'+HexStr(spi_mode,8)+' '+LNX_ErrDesc(fpgeterrno));   	      	      
	      res:=fpioctl(spi_fd,SPI_IOC_WR_BITS_PER_WORD,@spi_bpw);
		  if (res=-1) then Log_Writeln(Log_ERROR,'SPI_Dev_Init: can''t set bits per word '+Num2Str(spi_bpw,0)+' '+LNX_ErrDesc(fpgeterrno));            
		  res:=fpioctl(spi_fd,SPI_IOC_WR_MAX_SPEED_HZ,@spi_speed);
          if (res=-1) then Log_Writeln(Log_ERROR,'SPI_Dev_Init: can''t set max speed '+Num2Str(spi_speed,0)+'hz '+LNX_ErrDesc(fpgeterrno));	  
 		  {$RANGECHECKS OFF}		  
 		    res:=fpioctl(spi_fd,SPI_IOC_RD_MODE,@spi_mode); 
		    if (res=-1) then Log_Writeln(Log_ERROR,'SPI_Dev_Init: can''t get SPI mode '+LNX_ErrDesc(fpgeterrno));   
		    res:=fpioctl(spi_fd,SPI_IOC_RD_MAX_SPEED_HZ,@spi_speed);
//writeln('SPI-MaxSpeed: ',spi_speed);
		    if (res=-1) then Log_Writeln(Log_ERROR,'SPI_Dev_Init: can''t get max speed '+LNX_ErrDesc(fpgeterrno));	
		    res:=fpioctl(spi_fd,SPI_IOC_RD_BITS_PER_WORD,@spi_bpw);
		    if (res=-1) then Log_Writeln(Log_ERROR,'SPI_Dev_Init: can''t get bits per word '+LNX_ErrDesc(fpgeterrno));
		  {$RANGECHECKS ON}    
	    {$ENDIF}
	  	if (spi_fd<0) then 
	  	begin
	      Log_Writeln(LOG_WARNING,'SPI_Dev_Init[0x'+HexStr(busnum,2)+'/'+HexStr(devnum,2)+']: '+spi_path);
	      if LOG_Level<=LOG_DEBUG then SPI_show_dev_info_struct(busnum,devnum);
	  	end else ok:=true;
      end; // else LOG_Writeln(LOG_ERROR,'path not exist '+spi_path);
    end; // with
  end else LOG_Writeln(LOG_ERROR,'SPI_Dev_Init[0x'+HexStr(busnum,2)+'/0x'+HexStr(devnum,2)+']: invalid busnum/devnum');
//SPI_show_dev_info_struct(spi_dev[devnum], devnum);
  SPI_Dev_Init:=ok;
end;

function  SPI_Dev_Init(busnum,devnum:byte):boolean;
begin SPI_Dev_Init:=SPI_Dev_Init(busnum,devnum,8,0,SPI_MODE_0,spi_bus[busnum].spi_maxspeed,0); end;

procedure SPI_AdrMuxInit(CSnum,adr0gpio,adr1gpio:longint);
// SPI and chip select pins
// https://www.raspberrypi.org/forums/viewtopic.php?f=44&t=30765
var i:integer;
begin
  if (CSnum<=spi_max_dev) then
  begin
	with SPI_AddrMux[CSnum] do
  	begin
  	  AdrCSgpio[0]:=adr0gpio; 	AdrCSgpio[1]:=adr1gpio;
      AdrMuxEnable:=((GPIO_MAP_GPIO_NUM_2_HDR_PIN(AdrCSgpio[0])>0) and 
    				 (GPIO_MAP_GPIO_NUM_2_HDR_PIN(AdrCSgpio[1])>0));
      if AdrMuxEnable then
      begin // using valid HWpins only
	  	for i:= 0 to 1 do
	    begin
	  	  LOG_Writeln(LOG_WARNING,'SPI_AdrMuxInit['+Num2Str(i,0)+']: using GPIO#'+Num2Str(AdrCSgpio[i],0));
		  GPIO_set_OUTPUT(AdrCSgpio[i]);	 
		  GPIO_set_pin   (AdrCSgpio[i], true);	// active low -> deselect	  
	  	end; // for
	  end;
  	end; // with
  end else LOG_Writeln(LOG_ERROR,'SPI_AdrMuxInit: CS'+Num2Str(CSnum,0)+' not valid');
end;

procedure SPI_AdrMux(CSnum,adr:byte);
// for using e.g. 74HC139 Dual 2-to-4 line decoder/demultiplexer
// connect CS0 to 1E (Pin 1); GPIO<0> to 1A0 (Pin 2); GPIO<1> to 1A1 (Pin 3) 
// connect CS1 to 2E (Pin15); GPIO<2> to 2A0 (Pin14); GPIO<3> to 2A1 (Pin13) 
// using only 2 GPIOs: short 1A0 and 2A0; 1A1 and 2A1
begin
  if (CSnum<=spi_max_dev) then
  begin
	with SPI_AddrMux[CSnum] do
  	begin
	  if AdrMuxEnable then
	  begin
	  	case adr of // using negative logic (active low)
		  0: begin GPIO_set_pin(AdrCSgpio[1],true);  GPIO_set_pin(AdrCSgpio[0],true);  end;
		  1: begin GPIO_set_pin(AdrCSgpio[1],true);  GPIO_set_pin(AdrCSgpio[0],false); end;
		  2: begin GPIO_set_pin(AdrCSgpio[1],false); GPIO_set_pin(AdrCSgpio[0],true);  end;
		  3: begin GPIO_set_pin(AdrCSgpio[1],false); GPIO_set_pin(AdrCSgpio[0],false); end;
		  else LOG_Writeln(LOG_ERROR,'SPI_AdrMux[CS'+Num2Str(CSnum,0)+'/'+Num2Str(adr,0)+']: not valid');
	  	end; // case
	  end else LOG_Writeln(LOG_ERROR,'SPI_AdrMux['+Num2Str(CSnum,0)+'/'+Num2Str(adr,0)+']: not enabled, GPIOs not defined');
  	end; // with
  end else LOG_Writeln(LOG_ERROR,'SPI_AdrMux: CS'+Num2Str(CSnum,0)+' not valid');
end;

procedure SPI_AdrMux(adr:byte);
// select adr (0..7) before calling e.g. SPI_Transfer ...
begin 
  case adr of
	0..3: SPI_AdrMux(0,(adr and $03));	// CS0
	4..7: SPI_AdrMux(1,(adr and $03)); 	// CS1
  end; // case
end;

procedure SPI_Start(busnum:byte);
var devnum:byte;
begin
  Log_Writeln(LOG_DEBUG,'SPI_Start busnum: '+Num2Str(busnum,0));
  if (busnum<=spi_max_bus) then
  begin
    with spi_bus[busnum] do 
    begin 
	  spi_maxspeed:=SPI_GetSpeed(busnum);
	  SPI_useCS:=false;
	  InitCriticalSection(SPI_CS);
      for devnum:=0 to spi_max_dev do 
    	SPI_Dev_Init(busnum,devnum);
    end;
  end else LOG_Writeln(LOG_ERROR,'SPI_Start[0x'+HexStr(busnum,2)+']: invalid busnum');
end;

procedure SPI_Start;  
var i:integer; 
begin 
  for i:=0 to spi_max_dev do SPI_AdrMuxInit(i,-1,-1);
  for i:=0 to spi_max_bus do SPI_Start(i); 
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
        {$IFDEF UNIX} 
          if (spi_fd>=0) then 
          begin
            DoneCriticalSection(SPI_bus[busnum].SPI_CS);
            fpclose(spi_fd); 
          end;
        {$ENDIF}
        spi_fd:=-1; 
      end;
	end; // for
  end else LOG_Writeln(LOG_ERROR,'SPI_Bus_Close[0x'+HexStr(busnum,2)+']: invalid busnum');
end;

procedure SPI_Bus_Close_All; 
var i:integer; 
begin 
  for i:=0 to spi_max_dev do SPI_AdrMuxInit(i,-1,-1);
  for i:=0 to spi_max_bus do SPI_Bus_Close(i); 
end;

procedure SPI_Loop_Test;
const busnum=0; devnum=0; 		// test on /dev/spidev0.0 // spidev<busnum.devnum>
	  requestedspeed=1000000;	// MaxBusSpeed ~7.8MHz
	  seq=	'HELLO';
//	seq=	'HELLO - this is a SPI-Loop-Test'; // 31 Bytes
var rslt,cnt:integer; tv_start,tv_end:timespec; us:int64; 
begin
  writeln('SPI_Loop_Test+: Start');
  writeln('  pls. connect/short MOSI and MISO line (GPIO10/GPIO9).');
  writeln('  If you remove the wire between MOSI and MISO, and connect the MISO');
  writeln('  "H"-Level (+3.3 V), you should be able to read 0xFFs.');
  writeln('  If you connect MISO to ground (GND), you should receive 0x00s for each byte instead.');
  writeln('  we will send 8x byte sequence 0x'+HexStr(seq));
  writeln('  with a length of '+Num2Str(Length(seq),0)+' bytes and should also receive it. <CR>');
  readln;
  cnt:=0;
  SPI_Dev_Init(busnum,devnum,8,0,SPI_MODE_0,requestedspeed,10);	
  repeat
    clock_gettime(CLOCK_REALTIME,@tv_start);
    rslt:=SPI_Transfer(busnum,devnum,	seq(*+seq+seq+seq+seq+seq+seq+seq*));
    clock_gettime(CLOCK_REALTIME,@tv_end);
    if rslt>=0 then
    begin
      us:=MicroSecondsBetween(tv_end,tv_start);
      writeln('SPI_Loop_Test: success, NumBytes:',rslt:0,' within ',us:0,'us (',(rslt/us*1000):0:1,'kB/s MaxBusSpeed:',(SPI_GetFreq(requestedspeed)/1000):0:1,'kHz)');
      SPI_Show_Buffer(busnum,devnum); 
      writeln('responsestr: 0x',HexStr(spi_buf[busnum,devnum].buf));
    end else LOG_Writeln(LOG_ERROR,'SPI_Loop_Test: errnum: '+Num2Str(rslt,0));
	delay_msec(1000); 
	inc(cnt);
  until (cnt>=1);
  writeln('SPI_Loop_Test-: End');
end;

procedure rfm22B_ShowChipType;
(* just to test SPI Read Function. Installed RFM22B Module on piggy back board is required!! *)
const RF22_REG_01_VERSION_CODE = $01; busnum=0; devnum=0;
  function  GDVC(b:byte):string;
  var t:string;
  begin
    case (b and $1f) of
      $01 : t:='SIxxx_X4';
      $02 : t:='SI4432_V2';
      $03 : t:='SIxxx_A0';
	  $04 : t:='SI4431_A0';
	  $05 : t:='SI443x_B0';
      $06 : t:='SI443x_B1';
      else  t:='RFM_UNKNOWN';
    end;
    GDVC:='0x'+HexStr(b,2)+' '+t;
  end;
begin
  writeln('Chip-Type: '+
    GDVC(SPI_Read(busnum,devnum,RF22_REG_01_VERSION_CODE))+
	' (correct answer should be 0x06)');  
end;
procedure SPI_Test; begin rfm22B_ShowChipType; end;

function RPI_lsbrel:string;  		begin RPI_lsbrel:=lsb_rel;end;
function RPI_OSrev:string;  		begin RPI_OSrev:=os_rev;  end;
function RPI_uname:string;  		begin RPI_uname:=uname;   end;
function RPI_hw  :string;  			begin RPI_hw  :=cpu_hw;   end;
function RPI_fw  :string;  			begin RPI_fw  :=cpu_fw;   end;
function RPI_proc:string;  			begin RPI_proc:=cpu_proc; end;
function RPI_mips:string;  			begin RPI_mips:=cpu_mips; end;
function RPI_feat:string;  			begin RPI_feat:=cpu_feat; end;
function RPI_rev :string;  			begin RPI_rev :=cpu_rev; end;
function RPI_machine:string;  		begin RPI_machine:=cpu_machine; end;
function RPI_cores:longint;  		begin RPI_cores:=cpu_cores; end;
function RPI_revnum:real;  			begin RPI_revnum:=cpu_rev_num; end;
function RPI_gpiomapidx:byte;  		begin RPI_gpiomapidx:=GPIO_map_idx; end;
function RPI_hdrpincount:byte;  	begin RPI_hdrpincount:=connector_pin_count; end; 
function RPI_freq :string; 			begin RPI_freq :=cpu_fmin+';'+cpu_fcur+';'+cpu_fmax+';Hz'; end;
function RPI_status_led_GPIO:byte;	begin RPI_status_led_GPIO:=status_led_GPIO; end;
function RPI_snr :string;  			begin RPI_snr :=cpu_snr;  end;
function RPI_whoami:string;  		begin RPI_whoami:=whoami; end;

function RPI_GetBuildDateTimeString:string;
begin
  RPI_GetBuildDateTimeString:=StringReplace(prog_build_date,'/','-',[rfReplaceAll])+
  			'T'+prog_build_time;
end;

function RPI_GetBuildDateTime:TDateTime;
var dt:TDateTime;
begin 
  Str2DateTime(RPI_GetBuildDateTimeString,9,dt); // 'yyyy-mm-dd"T"hh:nn:ss'
  RPI_GetBuildDateTime:=dt; 
end;

function  RPI_I2C_BRadj(i2c_speed_kHz:longint):longint;	
// https://periph.io/platform/raspberrypi/ 
// http://forum.weihenstephan.org/forum/phpBB3/viewtopic.php?t=684
var br:longint; //vs:string;
begin // RPI_rev e.g: rev4;1024MB;3B;BCM2835;a02082;40
//  vs:=Upper(CSV_Item(RPI_rev,';','',3));	// e.g. 3B
  br:=i2c_speed_kHz;
//  if (Pos('3B',vs)<>0)	then br:=round(i2c_speed_kHz*1.6);	// RPI3
//	if (Pos('2B',vs)<>0)	then br:=round(i2c_speed_kHz*2.0);	// RPI2
  RPI_I2C_BRadj:=br;
end;

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
  delay_msec(waittim_ms);
  my_isr:=999;
end;

//* Bits from:
//https://www.ridgerun.com/developer/wiki/index.php/Gpio-int-test.c */
//static void *
// https://github.com/omerk/pihwm/blob/master/lib/pi_gpio.c
// https://github.com/omerk/pihwm/blob/master/demo/GPIO_int.c
// https://github.com/omerk/pihwm/blob/master/lib/pihwm.c
function isr_handler(p:pointer):ptrint; // (void *isr)
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
        if (fpread(fdset[1].fd,buf,SizeOf(buf))=-1) then
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
        if (fpread(fdset[0].fd,buf,1)=-1) then
        begin
          if testrun then writeln('read failed for stdin read');
          rslt:=-1;
		  exit(rslt);
        end;
        if testrun then writeln('poll() stdin read 0x',HexStr(buf[0],2));
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
	  {$warnings off}
      if lgt>SizeOf(buf) then 
	  begin
	    LOG_Writeln(LOG_ERROR,'WriteStr2UnixDev: string to long: '+Num2Str(lgt,0)+'/'+Num2Str(SizeOf(buf),0));
	    exit(-1);
      end;		
      {$warnings on}
      buf.str:=s;
      hdl:=fpopen(dev, Open_RDWR or O_NONBLOCK);
      if hdl<0 then exit(-2); 
	  rslt:=fpWrite(hdl,buf.str[1],lgt);
	  if (rslt<0)	then LOG_Writeln(LOG_ERROR,'WriteStr2UnixDev: '+LNX_ErrDesc(fpgeterrno));
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
procedure GPIO_int_disable(var isr:isr_t); begin isr.int_enable:=false; (*writeln('int Disable ',isr.gpio);*) end;

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
    write  ('doing nothing, waiting for an interrupt on GPIO',GPIO_nr:0,' loopcnt: ',cnt:3,' int_cnt: ',isr.int_cnt:3,' ThreadID: ',PtrUInt(isr.ThreadID),' ThPrio: ',isr.ThreadPrio);
	if isr.rslt<>0 then begin write(' result: ',isr.rslt,' last service time: ',isr.last_isr_servicetime:0,'ms'); isr.rslt:=0; end;
	writeln;
    delay_msec(1000);
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

function  SearchValIdx(var InpArr:array of real; srchval,Epsilon:real; up:boolean):longint;
// in: search a value 'srchval' in an array. 
// return: index of the value. -1 if not found
var i,idx,cnt:longint;
begin  
  idx:=-1; cnt:=Length(InpArr);
  if up then
  begin
	i:=1;
  	while i<=cnt do
  	begin
      if SameValue(InpArr[i-1],srchval,Epsilon) then 
      	begin idx:=i-1; i:=Length(InpArr); end;
      inc(i);
  	end; // while
  end
  else
  begin
	i:=cnt;
  	while i>=1 do
  	begin
      if SameValue(InpArr[i-1],srchval,Epsilon) then 
      	begin idx:=i-1; i:=1; end;
      dec(i);
  	end; // while
  end;
  SearchValIdx:=idx;
end; 

function  CSV_ESCvalue(const value:string):string;
var sh:string;
begin
  if (value<>'')
	then sh:=StringReplace(value,'"','""',[rfReplaceAll]) // esc '"' for CSV_ITEM
  	else sh:='';
  CSV_ESCvalue:=sh;
end;

procedure CSV_Pos(const strng:string; const delim:char; itemno:longint; var ps,pe:longint);
var len,itc,qtc:longint;
begin
  itc:=0; qtc:=0; len:=Length(strng); ps:=1; pe:=1;
  while (pe<=len) and (itc<>itemno) do
  begin
    if (strng[pe]='"') then inc(qtc);
	if (not ((strng[pe]<>delim) or odd(qtc))) then
	begin
	  inc(itc);
	  qtc:=0;
	end;
	inc(pe);
	if (itc<(itemno-1)) then inc(ps);
  end; // while
  if (pe<len) then dec(pe); 
end;

function  CSV_Count(const strng:string; const delim:char):longint;
var i,len,itc,qtc:longint;
begin
  i:=1; qtc:=0; len:=Length(strng);
  if (len>0) then itc:=1 else itc:=0;
  while (i<=len) do
  begin
    if (strng[i]='"') then inc(qtc);
	if (not ((strng[i]<>delim) or odd(qtc))) then
	begin
	  inc(itc);
	  qtc:=0;
	end;
	inc(i);
  end; // while
  CSV_Count:=itc; 
end;
function  CSV_Count(const strng:string):longint;
begin CSV_Count:=CSV_Count(strng,','); end;

function  CSV_Item(const strng:string; const delim:char; const dflt:string; itemno:longint):string;
// https://www.rfc-editor.org/rfc/rfc4180.txt
var i,len,itc,qtc:longint; sh,sh1:string;
begin
  SetLength(sh,0);
  if (itemno>0) then
  begin
	itc:=0; i:=1; qtc:=0; len:=Length(strng);
 	while (i<=len) and (itc<>itemno) do
  	begin
      if (strng[i]='"') then  inc(qtc);
	  if (strng[i]<>delim) or odd(qtc) then
      begin
      	if ((itemno-1)=itc) then sh:=sh+strng[i]; // extract full field content
	  end
	  else 
	  begin
	  	inc(itc);
	  	if (itc<>itemno) then qtc:=0;
	  end;
	  inc(i);
  	end; // while	

	len:=Length(sh);
  
	if (len>0) then
	begin
	  if (sh[1]=' ') or (sh[len]=' ') then
	  begin 
		sh:=TrimSet(sh,[' ']);					// remove leading & trailing spaces
	  	len:=Length(sh);
	  end;
	end;
		
	if (qtc>=2) and (len>0) then
	begin  
	  i:=1; qtc:=0; SetLength(sh1,0);
	  if (sh[1]=  '"') then inc(i);				// remove leading  quote
	  if (sh[len]='"') then dec(len);	  		// remove trailing quote
	  while (i<=len) do
	  begin
	  	if (sh[i]='"') then inc(qtc);
		if (odd(qtc) or (sh[i]<>'"')) 
		  then sh1:=sh1+sh[i];					// remove escaped quote
	  	inc(i);
	  end; // while
	  sh:=sh1;
	end;
		
  end; // else system.Str(CSV_Count(strng,delim):0,sh); // cnt
  
  if (sh='') then sh:=dflt;  
  CSV_Item:=sh; 
end;

function  CSV_Item(const strng:string; const delim:char; itemno:longint):string;
begin CSV_Item:=CSV_Item(strng,delim,'',itemno); end;
function  CSV_Item(const strng:string; itemno:longint):string;
begin CSV_Item:=CSV_Item(strng,',','',itemno); end;

procedure CSV_Explode(const strng:string; const delim:char; const dflt:string; var fields:CSV_array_t);
var i:longint;
begin 
  for i:= 1 to Length(fields) do fields[i-1]:=CSV_Item(strng,delim,dflt,i); 
end;
procedure CSV_Explode(const strng:string; var fields:CSV_array_t);
begin CSV_Explode(strng,',','',fields); end;

function  CSV_RightItems(const strng:string; const delim:char; itemno:longint):string; 
var ps,pe:longint; 
begin 
  CSV_Pos(strng,delim,itemno,ps,pe);
  CSV_RightItems:=copy(strng,ps+1,Length(strng)); 
end;

function  CSV_LeftItems(const strng:string; const delim:char; itemno:longint):string; 
var ps,pe:longint; 
begin 
  CSV_Pos(strng,delim,itemno,ps,pe);
  CSV_LeftItems:=copy(strng,1,pe-1); 
end;

function  CSV_FileList(const cmd:string):string;
var i:longint; _tl:TStringList; sh:string;
begin
  sh:=''; _tl:=TStringList.create;
  i:=call_external_prog(LOG_ERROR,cmd,_tl);
  if (i>=0) then
  begin
	for i:= 1 to _tl.count do
    begin	
	  if (_tl[i-1]<>'') then sh:=sh+_tl[i-1]+',';
	end; // for   
	CSVRemLastSep(sh,',');
  end;
  _tl.free;
  CSV_Filelist:=sh;
end;

procedure TST_Select_Item;
const 
  racecnt=50000; fcnt=6;
  tst:array[1..4] of string= (
  'f1,"",f3,"",  , f"" 6 ',
  '"John ""Da Man""",Repici,120 Jefferson St.,Riverside, NJ,08075',
  'Stephen,Tyler,"7452 Terrace ""At the Plaza"" road",SomeTown,SD, 91234',
  ' "Joan ""the bone"", Anne",Jet,"9th, at Terrace plc",Desert City, CO,  " 00123" ');
var i,j,k,ps,pe:longint; dt1:TdateTime; fields:CSV_array_t;
begin
  for k:= 1 to Length(tst) do
  begin
	writeln(':',tst[k],':'); 
	for i:= 1 to fcnt do writeln(i:0,':',CSV_Item(tst[k],i),':');
  	writeln('Anz:',CSV_Count(tst[k]));
  	CSV_Pos(tst[k],',',4,ps,pe); writeln('Pos:',ps,':',pe);
  	writeln('Lft:',CSV_LeftItems( tst[k],',',4),':');
  	writeln('Rgt:',CSV_RightItems(tst[k],',',4),':');
  	writeln('Lft:',Select_LeftItems( tst[k],',','"',4),':');
  	writeln('Rgt:',Select_RightItems(tst[k],',','"',4),':');
  	writeln;
  end;
  
  SetLength(fields,fcnt);
  for k:=1 to Length(tst) do
  begin
    writeln(':',tst[k],':'); 
	CSV_Explode(tst[k],fields);
	for i:= 1 to Length(fields) do writeln(i:0,':',fields[i-1],':');
	writeln;
  end;

(*k:=0;
  writeln(tst[k]); for i:= 1 to fcnt do writeln(i:0,':',CSV_Item(tst[k],i));
  writeln('Anz:',CSV_Count(tst[k],','),':');
  
  writeln(tst[k]); for i:= 1 to fcnt do writeln(i:0,':',Select_Item(tst[k],',','','',i));
  writeln('Anz:',Select_Item(tst[k],',','','',0),':');
  writeln; *)
  
  writeln('SpeedTest:');
  k:=4;
  dt1:=now;
  for j:=1 to racecnt do
    for i:= 1 to fcnt do CSV_Item(tst[k],i); // >10x faster
  writeln('CSV_Item Time:   ',MilliSecsBetween(dt1),'ms');
   
  dt1:=now; 
  for j:=1 to racecnt do
    for i:= 1 to fcnt do Select_Item(tst[k],',','','',i);
  writeln('Select_Item Time:',MilliSecsBetween(dt1),'ms');  
end;

function  CSV_RemFirstSep(const strng:string; const delim:char):string;
var sh:string;
begin
  sh:=strng;
  if (Length(strng)>0) and (strng[1]=delim) then 
    sh:=copy(strng,2,Length(strng));
  CSV_RemFirstSep:=sh;
end;

procedure CSVRemLastSep(var strng:string; const delim:char);
var lgt:longint;
begin
  lgt:=Length(strng);
  if (lgt>0) then
	if (strng[lgt]=delim) then SetLength(strng,(lgt-1));
end;

function  CSV_RemLastSep(const strng:string; const delim:char):string;
var lgt:longint; sh:string;
begin
  sh:=strng; lgt:=Length(sh);
  if (lgt>0) then
	if (sh[lgt]=delim) then SetLength(sh,(lgt-1));
  CSV_RemLastSep:=sh;
end;
function  CSV_RemLastSep(const strng:string):string;
begin CSV_RemLastSep:=CSV_RemLastSep(strng,','); end;

procedure CSV_MaintList(var csvlst:string; entry:string; addit:boolean);
begin
  if (entry<>'') then
  begin
	if addit then 
	begin
	  if (csvlst<>'') then 
	  begin
		  if (Pos(entry+',',csvlst+',')=0) then csvlst:=csvlst+','+entry; 
	  end else csvlst:=entry;
	end else csvlst:=StringReplace(csvlst+',',entry+',','',[rfReplaceAll]);
	csvlst:=CSV_RemLastSep(csvlst,',');  
  end;
end;

function  CSV_MaintListToogleField(var csvlst:string; entry:string):boolean;
var addit:boolean;
begin
  addit:=(Pos(entry+',',csvlst+',')=0);
  CSV_MaintList(csvlst,entry,addit);
  CSV_MaintListToogleField:=addit;
end;

function  MovAvg(interval:longword; var InpArr,OutArr:array of single):longint; // moving average
var i,j,l:longint; res:real;
begin
  res:=0; 
  if Length(InpArr)>Length(OutArr) then l:=Length(OutArr) else l:=Length(InpArr); 
  for i:= 1 to l do
  begin
    res:=res+InpArr[i-1];
    if i>=interval then 
    begin
      res:=0;
      for j:= 1 to interval do 
      begin
        res:=res+InpArr[i-interval+j-1];
      end;
      if interval<>0 then OutArr[i-1]:=res/interval else OutArr[i-1]:=0;
    end else OutArr[i-1]:=res/i;
  end;
  MovAvg:=l;
end;

function  MovAvg(interval:longword; var InpArr,OutArr:array of real):longint; // moving average
var i,j,l:longint; res:real;
begin
  res:=0; 
  if Length(InpArr)>Length(OutArr) then l:=Length(OutArr) else l:=Length(InpArr); 
  for i:= 1 to l do
  begin
    res:=res+InpArr[i-1];
    if i>=interval then 
    begin
      res:=0;
      for j:= 1 to interval do 
      begin
        res:=res+InpArr[i-interval+j-1];
      end;
      if interval<>0 then OutArr[i-1]:=res/interval else OutArr[i-1]:=0;
    end else OutArr[i-1]:=res/i;
  end;
  MovAvg:=l;
end;


function Sigmoid(A,k,x,x0:real):real;
// create S-Shape curve
// A: maxHeight, k:steepness, x0:midpoint
// e.g. Sigmoid(10,1,0, 5) -> 0.0669285
// e.g. Sigmoid(10,1,5, 5) -> 5
// e.g. Sigmoid(10,1,10,5) -> 9.9330715
begin
  try
    Sigmoid:=A/(1+exp(-k*(x-x0)));
  except
    Sigmoid:=NaN;
  end;
end;

function SigmoidIsA(A,k,epsilon,x0:real):real;
// determine x value, where Sigmoid is nearly A (epsilon is allowed error e.g. 0.001)
begin
  try
	SigmoidIsA:=-(ln(A/(A-epsilon)-1)/k)+x0; // for (epsilon>0)
  except
	SigmoidIsA:=NaN;
  end;
end;

procedure tst_Sigmoid;
const A=1.0; x0=0.0; k=1.0; eps=0.00000001; cnt=10;
var xMinMax:real; n:longint;
procedure _sig(x:real);    begin writeln('x: ',x:11:7,' y: ',Sigmoid(A,k,x,x0):11:7); end;
begin 
  writeln('x0:',x0:11:7,' k: ',k:11:7,' (steepness)');
  writeln('A: ',A:11:7,' eps: ',eps:0:12); writeln;
  xMinMax:=SigmoidIsA(A,k,eps,x0); 
  _Sig(-xMinMax+2*x0); _Sig(0+x0); _Sig(xMinMax);
  writeln;
  for n:= 1 to (cnt+1) do _Sig( (n-1) * xMinMax*2/cnt - xMinMax ); 
end;

procedure tst_Sigmoid_normalized;
// normalized x- and y-range 0..1 
const A=1.0; x0=0.0; k=1.0; eps=0.00000001; cnt=10;
var xMinMax:real; n:longint;
procedure _sig(x:real);    begin writeln('x: ',x:11:7,' y: ',Sigmoid(A,k,x*xMinMax*2,xMinMax-(x0*xMinMax*2)):11:7); end;
begin 
  xMinMax:=SigmoidIsA(A,1,eps,0); 
  writeln('x0:',x0:11:7,' k: ',k:11:7,' (steepness)');
  writeln('A: ',A:11:7,' eps: ',eps:0:12); writeln;
  _Sig(0); _Sig(0.5); _Sig(1);
  writeln;
  for n:= 1 to (cnt+1) do _Sig( (n-1) * 1/cnt ); 
end;

function  PID_DetAvgs(IdxStart,IdxEnd:longint; var avgnumIst,avgnumPInc:longint):boolean; 
begin
  avgnumIst:=(IdxEnd-IdxStart+1) div 10; // try moving average with lines/10 values
  if avgnumIst>PID_AVGmaxNum_c then avgnumIst:=PID_AVGmaxNum_c; 
  if avgnumIst<PID_AVGminNum_c then avgnumIst:=PID_AVGminNum_c;
  avgnumPInc:=avgnumIst;  
  PID_DetAvgs:=true;
end;

function  PID_FileLoad(StrList:TStringList; filnam,SearchCrit:string; var IdxStart,IdxEnd:longint):boolean;
var _ok:boolean;
begin
  _ok:=TextFile2StringList(filnam,StrList);
  if _ok	then _ok:=GiveStringListIdx2(StrList,SearchCrit,IdxStart,IdxEnd)
  			else LOG_Writeln(Log_ERROR,'PID_FileLoad: input file '+filnam);
  PID_FileLoad:=_ok;
end;

function  PID_TDR(var TickArr,ValArr,OutTickDeltaArr,OutValArr:array of PID_float_t):longint;
//time derivative response
var i,l:longint;
begin 
  if Length(ValArr)>Length(OutValArr) then l:=Length(OutValArr) else l:=Length(ValArr); 
  if l>Length(TickArr) then l:=Length(TickArr); 
  for i:= 1 to l do
  begin
    OutValArr[i-1]:=0; OutTickDeltaArr[i-1]:=0;
    if (i>1) then
    begin
      OutTickDeltaArr[i-1]:=(TickArr[i-1]-TickArr[i-2]);
      if OutTickDeltaArr[i-1]<>0 then 
        OutValArr[i-1]:=	(ValArr [i-1]-ValArr [i-2])/OutTickDeltaArr[i-1];
    end;
  end;
  PID_TDR:=l;
end;

function  PID_VectorStr(var pidarr:PID_array_t; vk,nk:integer; sep:char):string;
var sh:string;
begin 
  sh:=	Num2Str(pidarr[iKp],vk,nk)+sep+
  		Num2Str(pidarr[iKi],vk,nk)+sep+
  		Num2Str(pidarr[iKd],vk,nk);
  PID_VectorStr:=sh;
end;

function PID_VectorStr(var pidarr:PID_array_t; vk,nk:integer):string;
var sh:string;
begin 
  sh:=	'Kp:'+Num2Str(pidarr[iKp],vk,nk)+' '+
  		'Ki:'+Num2Str(pidarr[iKi],vk,nk)+' '+
  		'Kd:'+Num2Str(pidarr[iKd],vk,nk);
  PID_VectorStr:=sh;
end;

function  PID_Vector(Kp,Ki,Kd:PID_float_t):PID_array_t;
var i:longint; pa:PID_array_t;
begin
  for i:=1 to Length(pa) do pa[i-1]:=0;
  pa[iKp]:=Kp; pa[iKi]:=Ki; pa[iKd]:=Kd;
  PID_Vector:=pa;
end;

function  PID_DetType(Te,Tb:PID_float_t):PID_Method_t;
var meth:PID_Method_t; r:PID_float_t;
begin
  meth:=P_Default;
  if not ( (Te=0) or (Tb=0) or IsNaN(Tb) or IsNaN(Te) ) then 
  begin
	r:=Tb/Te;									
					 meth:=P_Default;	// gut regelbar 		-> P
	if (r<=10)	then meth:=PI_Default;	// regelbar 			-> PI	
	if (r<3)	then meth:=PID_Default; // schlecht regelbar	-> PID
  end;
  PID_DetType:=meth;
end;

function  PID_TimAdj(timadjfct:real; var Te,Tb,TSum:PID_float_t):integer;
var res:integer; 
begin
  res:=-1;
  if (not IsNaN(timadjfct)) and (timadjfct>0) then
  begin 
    res:=0;
    if not IsNaN(Te) 	then begin Te:=Te	 *timadjfct; inc(res); end;
    if not IsNaN(Tb) 	then begin Tb:=Tb	 *timadjfct; inc(res); end;
    if not IsNaN(Tsum) 	then begin Tsum:=Tsum*timadjfct; inc(res); end;
  end;
  PID_TimAdj:=res;
end;

function  PID_sim(StrList:TStringList; simnr:integer):real;
//PID_loctusec=4; PID_locsollval=5; PID_locistval=6; 
const hdr1=';;;';
var timadj:real; i:longint;
//Prof. Dr. R. Kessler, FH-Karlsruhe, FB-MN, http://www.home.fh-karlsruhe.de/~kero0001, WendeTangReg3.doc
// returns timebase and a list of values in csv format (for testing)
// Strecke aus 10 gleichen PT1-Gliedern (WT10PT1.MDL)
  procedure tlx(hdr,xs,ys,zs:string); begin StrList.add(hdr+xs+';'+zs+';'+ys); end;
  procedure tl0(x,y:real); begin tlx(hdr1,AdjZahlDE(x/timadj,0,PID_nk8),AdjZahlDE(y,0,PID_nk8),'0'); end;
  procedure tl1(x,y:real); begin tlx(hdr1,AdjZahlDE(x/timadj,0,PID_nk8),AdjZahlDE(y,0,PID_nk8),'1'); end;
  procedure tl2(x,y:real); begin tlx('',  AdjZahlDE(x/timadj,0,PID_nk8),'',AdjZahlDE(y,0,PID_nk8)); end;
begin
  timadj:=1;
  case simnr of
    1:begin
    	for i:=0 to 400 do 
    	begin
    	  if i<10 then tl2((i/10),0) else tl2((i/10),1);
    	end;
      end;
    2:begin
//    	for i:=0 to 300 do tl1(i/10,Sigmoid(1,0.5,i/10,10));
    	for i:=0 to 19 do tl1(i/10,Sigmoid(1,0.5,i,10));
      end;
    else 
      begin // WT10PT1.MDL
  		tl0(0,0); 		tl1(1,0); 		tl1(2,0); 		tl1(3,0); 		tl1(4,0);
  		tl1(5,0.01); 	tl1(6.25,0.05); tl1(7.5,0.15); 	tl1(8.75,0.25); 	
  		tl1(10,0.4); 	tl1(11.25,0.6); tl1(12.5,0.75); tl1(13.75,0.85); 
  		tl1(15,0.9);  	tl1(16.25,0.95);tl1(17.5,0.97); tl1(18.75,0.99);
  		tl1(20,1);
  		for i:=21 to 40 do tl1(i,1);
      end;
  end; // case
  PID_sim:=timadj;
end;

procedure PID_DetShow(var struct:PID_Det_t; loglvl,collvl:T_ErrorLevel; hdr,trl:string);
begin
  with struct do
  begin
	SAY(loglvl,collvl, hdr+
		' Ks:'+Num2Str(Ks,0,1)+' Ti:'+Num2Str(Ti,0,PID_nk8)+' Td:'+Num2Str(Td,0,PID_nk8)+
		' Te:'+Num2Str(Te,0,PID_nk8)+' Tb:'+Num2Str(Tb,0,PID_nk8)+' PIDmeth:'+GetEnumName(TypeInfo(PID_Method_t),ord(PIDMethod))+
		' SmplTim: Avg='+Num2Str(SampleTimeAvg,0,1)+' AdjFctr='+Num2Str(SampleTimeAdjFactor,0,6)+trl);
  end;
end;

function  PID_DetPara(loglvl:t_ErrorLevel; StrList:TStringList; idxStart,idxEnd,smoothdata,smoothtdr,loctim,locist,locSetPoint:longint; StoerSprung,timadjfct:real; var PID_Det:PID_Det_t; tst:boolean; filout:string):integer;
//function  PID_DetPara(loglvl:t_ErrorLevel; StrList:TStringList; idxStart,idxEnd,smoothdata,smoothtdr,loctim,locist,locSetPoint:longint; StoerSprung,timadjfct:real; var Ks,Te,Tb,Tsum,SampleTimeAvg:PID_float_t; tst:boolean; filout:string):integer;
//determines Ks,Te,Tb out of a given sensor data (.csv)
//Ks,Te,Tb for feeding PID_GetPara
//Prof. Dr. R. Kessler, FH-Karlsruhe, FB-MN, http://www.home.fh-karlsruhe.de/~kero0001, WendeTangReg3.doc
//StepResponseList.csv	-> using values t(usec) and ist. FieldNum 4&6. SetPoint/soll FieldNum 5
//pwm%;pidnr;cnt;t(usec);soll;ist;avg;preached;t2preach;preachedmax;t2preachmax;pincms;pok;calc;stdev;pon;ppc
//0,45;6;0;0;132;-0,15259;-0,15259;133,28756;552630;133,44015;557774;0,24146382;1;0;7,92544758;1;0
//...
//0,45;6;1081;619469;132;129,85428;129,85428;133,28756;552630;133,44015;557774;0,24146382;1;133,4401502;7,92544758;0;0
var _ok:boolean; res,i,linecnt,idx,avgnumIst,avgnumTDR:longint; _tl:TStringList;
	maxZ,minZ,tZ,maxXp,tWP,XWP,t1,t2,_Te,_Tb,wt,scaleXp:PID_float_t; 
  	A_t,A_td,A_W,A_U,A_X,A_TDR,A_Xp: array of PID_float_t;
begin
  _tl:=TStringList.create; 
  with PID_Det do
  begin
//writeln('PID_DetPara filout:',filout,' ',idxStart,' ',idxEnd,' ',tst);
  	linecnt:=idxEnd-idxStart+1; res:=-1; 
  	SampleTimeAdjFactor:=timadjfct; // PID_timadj_c=0.000001; // usec sensor data
  	Ks:=NaN; Te:=Nan; Tb:=NaN; Tsum:=Nan; 
  	if (linecnt>0) then
  	begin
      Ks:=1; scaleXp:=1; //anno:='';
      SetLength(A_U,  linecnt); 	SetLength(A_X, linecnt); 	SetLength(A_t,linecnt); 
      SetLength(A_TDR,linecnt); 	SetLength(A_Xp,linecnt);  	SetLength(A_W,linecnt);
      SetLength(A_td, linecnt);
      for i:=idxStart to idxEnd do
      begin // ArrFill 
      	_ok:=true;
      	if not Str2Num(AdjZahl(CSV_Item(StrList[i],',',loctim)),	 A_t[i-idxStart]) then _ok:=false;	// timeval
      	if not Str2Num(AdjZahl(CSV_Item(StrList[i],',',locist)),	 A_U[i-idxStart]) then _ok:=false;	// istval
      	
      	if (locSetPoint>0) then 
      	begin
      	  if not Str2Num(AdjZahl(CSV_Item(StrList[i],',',locSetPoint)),A_W[i-idxStart]) then _ok:=false;// SetPoint
      	end	else A_W[i-idxStart]:=0;
      	
      	if not _ok then LOG_Writeln(LOG_ERROR,'PID_DetPara['+Num2Str(i,0)+'] value not ok: '+StrList[i]);
//	  	writeln(i:5,' ',A_t[i-idxStart]:8:5,' SP:',A_W[i-idxStart]:8:5,' PV:',A_U[i-idxStart]:8:5);
//	  	writeln(i:5,' ',A_t[i-idxStart]:8:5,' PV:',A_U[i-idxStart]:8:5);
      end;
              
      avgnumIST:=smoothdata; if avgnumIST<1 then avgnumIST:=1; // 1=no smoothing
      avgnumTDR:=smoothtdr;  if avgnumTDR<1 then avgnumTDR:=1;
      
//writeln('ok ',_ok,' ',avgnumIST,' ',avgnumTDR);
    			
      MovAvg(avgnumIst,A_U,A_X);		// smoothen raw input sensor data
      if (locSetPoint<=0) then
      begin				
      	maxZ:=MaxValue(A_X);
      	minZ:=maxZ;
      	for i:= 1 to Length(A_W) do A_W[i-1]:=maxZ;
      end
      else
      begin
        minZ:=MinValue(A_W);				
      	maxZ:=MaxValue(A_W);
      end;
  
      PID_TDR(A_t,A_X,A_td,A_TDR);	
      SampleTimeAvg:=Mean(PDouble(@A_td[1]),(Length(A_td)-1))*SampleTimeAdjFactor;
//      writeln('SampleTimeAvg: ',SampleTimeAvg:0:4);

      MovAvg(avgnumTDR,A_TDR,A_Xp);		// smoothen t-derived response
      if minZ=maxZ then minZ:=0;
      idx:=SearchValIdx(A_W,maxZ,PID_epsilon_c,true);
      if idx<0 then tZ:=0 else tZ:=A_t[idx];		// Zeit tZ des Z-Sprungs finden 
      maxXp:=MaxValue(A_Xp);
      idx:=SearchValIdx(A_Xp,maxXp,PID_epsilon_c,true); 	// Koordinaten tWP und XWP suchen
      if (idx>=0) then
      begin
      	maxXp:= maxXp;
      	tWP:=A_t[idx]; XWP:=A_X[idx];	// Wendepunkt
      	t1:= (XWP-minZ)/maxXp;			// t1= Zeitabschn. unter Wendetangente bis minZ
      	t2:= (maxZ-XWP)/maxXp;			// t2= Zeitabschn. oberhalb Wendetangente bis maxZ
      	Te:= tWP-t1-tZ;					// Te= Verzugszeit (Tu)
      	Tb:= t1+t2;						// Tb= Ausgleichszeit (Tg)
      	if (StoerSprung<>0) then
    	  Ks:=maxZ/StoerSprung;			// Ks= StreckenverstŠrkung = Endwert der Sprungantwort geteilt durch Hšhe des Stšrsprungs. 

      	if tst then
      	begin
//	      create .csv output // overwrite Input StringList !!!!!!!!
	      _tl.clear;
	  
	      scaleXp:=maxZ/maxXp;				// normalize TDR
          _tl.add('time,U,W,U(avg='+Num2Str(avgnumIst,0)+'),Xp(scale='+Num2Str(scaleXp,0,PID_nk8)+'),WT');
          for i:=1 to linecnt do
          begin            
		  	if A_t[i-1]<(tWP-t1) then wt:=minZ else 
		      if A_t[i-1]>(tWP+t2) then wt:=maxZ 
			  	else wt:=(A_t[i-1]-(tWP-t1))/Tb*(maxZ-minZ); // calc Wendetangente        
          	_tl.add(
        		Num2Str(A_t [i-1],0)+','+
        		Num2Str(A_U [i-1],0,PID_nk8)+','+
            	Num2Str(A_W [i-1],0,PID_nk8)+','+
            	Num2Str(A_X [i-1],0,PID_nk8)+','+
    	  		Num2Str(A_Xp[i-1]*scaleXp,0,PID_nk8)+','+
    	  		Num2Str(wt,0,PID_nk8)
				);
          end;  
          if (filout<>'') then 
          begin
    	  	SAY(loglvl,'PID_DetPara: writing to ('+Num2Str(_tl.count,0)+') '+filout);
    	  	if not StringList2TextFile(filout,_tl) then
			  LOG_Writeln(LOG_ERROR,'PID_DetPara: can not write '+filout);
          end;
//    	  ShowStringList(_tl);   
          scaleXp:=1;
      	end; // tst

(*      anno:=
      	'WP='+Num2Str(tWP,0,PID_nk8)+';'+Num2Str(XWP, 0,PID_nk8)+','+
      	'Te='+Num2Str(Te, 0,PID_nk8)+','+'Tb='+Num2Str(Tb,0,PID_nk8)+','+
        'Ks='+Num2Str(Ks, 0,PID_nk8)+','+'STAvg='+Num2Str(SampleTimeAvg,0,PID_nk8); *)
      
      	_Te:=Te; _Tb:=Tb;					// keep calced Te and Tb
      	if PID_TimAdj(SampleTimeAvg,Te,Tb,TSum)>0 then
      	begin
      	  PIDMethod:=PID_DetType(Te,Tb);	// Determine P/PI/PID
      	  res:=ord(PIDMethod);
          SAY(loglvl,	'tZ/minZ/maxZ/maxXp/SampleTimeAvg/StoerSprung: '+
          				Num2Str(tZ,0,PID_nk8)+' '+Num2Str(minZ,0,PID_nk8)+' '+
          				Num2Str(maxZ,0,PID_nk8)+' '+Num2Str(maxXp,0,PID_nk8)+' '+
          				Num2Str(SampleTimeAvg,0,PID_nk8)+' '+Num2Str(StoerSprung,0,PID_nk8)); 
          SAY(loglvl,	'avgnumIST/avgnumTDR: '+Num2Str(avgnumIST,0,PID_nk8)+' '+Num2Str(avgnumTDR,0,PID_nk8)); 
          SAY(loglvl,	'WendePunkt['+Num2Str(idx,0)+']: '+
          				Num2Str(tWP,0,PID_nk8)+'/'+Num2Str(XWP,0,PID_nk8));
	      SAY(loglvl,	't1/t2: '+Num2Str(t1,0,PID_nk8)+' '+Num2Str(t2,0,PID_nk8));
	      SAY(loglvl,	'Ks/Te/Tb: '+
	      				Num2Str(Ks,0,PID_nk8)+' '+ Num2Str(_Te,0,PID_nk8)+' '+
	      				Num2Str(_Tb,0,PID_nk8));    
	      SAY(loglvl,	'TimAdj SampleTimeAvg/Te/Tb/suggestedPIDMethod: '+
	      				Num2Str(SampleTimeAvg,0,PID_nk8)+' '+Num2Str(Te,0,PID_nk8)+' '+Num2Str(Tb,0,PID_nk8)+' '+GetEnumName(TypeInfo(PID_Method_t),res));
      	end else LOG_Writeln(LOG_ERROR,'PID_DetPara: timeadj wrong paras');
      end else LOG_Writeln(LOG_ERROR,'PID_DetPara: Xp not found (wrong epsilon?)');
      SetLength(A_U,0);		SetLength(A_X,0); 	SetLength(A_t,0);	SetLength(A_td,0);
      SetLength(A_TDR,0);	SetLength(A_Xp,0);	SetLength(A_W,0);	
  	end else LOG_Writeln(LOG_ERROR,'PID_DetPara: wrong parameter/empty list');
  end; // with
  _tl.free;
  PID_DetPara:=res;
end;

function  PID_WT(fnIN,fnOUT:string; PID_loctTIMusec,PID_locPVval,PID_locSPval:integer; lvl:T_ErrorLevel; var PID_Det:PID_Det_t):boolean;
// Wendetangentenverfahren
// e.g. call PID_WT('myfile.csv',4,6,5)
// out: PID_Det as input for PID_GetPara
// out: csv-file:
// time,U,W,U(avg=50),Xp(scale=467374.46494810),WT
// 0,7.24804000,242.00000000,7.24804000,0.00000000,0.00000000
// in:  csv-file
// pwm%,pidnr,cnt,t(usec),soll,ist,avg,preached,t2preach,preachedmax,t2preachmax,pincms,pok,calc,stdev,pon,ppc,pmethod
// define in PID_loctTIMusec,PID_locPVval,PID_locSPval field nums that should used for timeus,ProcessValue,SetPoint
const PID_timadj_c=0.0000001; // us adjust
var _ok:boolean; _idxa,_idxe,avgnumPV,avgnumTDR:longint;
	_tl:TStringList; 
begin
  _tl:=TStringList.create;
  _ok:=TextFile2StringList(fnIN,_tl); // read csv file
  if _ok then
  begin
    if (_tl.count>0) then
    begin
      _idxe:=_tl.count-1;
      _idxa:=1; // ommit Hdr e.g. time,U,W,U(avg=50),Xp(scale=467374.46494810),WT
      
      PID_DetAvgs(_idxa,_idxe,avgnumPV,avgnumTDR);
      avgnumTDR:=2*avgnumTDR;    
	  PID_DetPara(lvl,_tl,_idxa,_idxe,avgnumPV,avgnumTDR,PID_loctTIMusec,PID_locPVval,PID_locSPval,1,PID_timadj_c,PID_Det,true,fnOUT); 
	end;
  end else LOG_Writeln(LOG_ERROR,'PID_WT: file not exist '+fnIN);
  _tl.free;
  PID_WT:=_ok;
end;

function  PID_DetCreate(myPIDmethod:PID_Method_t; myKS,myTe,myTb,myTimeBase_sec,mySampleTime:PID_float_t):PID_Det_t;
// mySampleTime: Zeitschritt e.g. 0.01 for 10ms
// Input Structure for PID_GetPara
var PID_Det:PID_Det_t;
begin
  with PID_Det do 
  begin 
    Ti:=NaN; Td:=NaN;
    PIDMethod:=myPIDmethod;
	SampleTimeAdjFactor:=myTimeBase_sec;	// time base. for microsec (us) -> 0.000001 
	SampleTimeAvg:=		 mySampleTime;		// will hold sensor data sample time. e.g. 500us -> 500
	Ks:=myKs; 
	Te:=myTe; Tb:=myTb; 
	Tsum:=0; // currently not implemented
  end;
  PID_DetCreate:=PID_Det;
end;
function  PID_DetCreate(myKS,myTe,myTb,myTimeBase_sec,mySampleTime:PID_float_t):PID_Det_t;
begin PID_DetCreate:=PID_DetCreate(PID_DetType(myTe,myTb),myKS,myTe,myTb,myTimeBase_sec,mySampleTime); end;

function  PID_GetPara(loglvl:t_ErrorLevel; var PID_Det:PID_Det_t; var K:PID_array_t; loginfo:string):integer;
//function  PID_GetPara(loglvl:t_ErrorLevel; Ks,Te,Tb,Tsum:PID_float_t; Method:PID_Method_t; var Ti,Td:PID_float_t; var K:PID_array_t; loginfo:string):integer;
//calcs Kp,Ki,Kd,Ti,Td for feeding PID_Init
//Input:  Statische VerstŠrkung (Ks), 
//Input:  Verzugszeit (Te) und Ausgleichszeit (Tb) in sec
//Input:  Px_SUM (TSum)
//Input:  Einstellregel (Method)
//Output: Ti,Td; Karray:Kp,Ki,Kd
//
//https://de.wikipedia.org/wiki/Faustformelverfahren_(Automatisierungstechnik)
//Script: Spezialgebiete der Steuer- und Regelungstechnik WS 2008/09 FH Dortmund Schriftliche Ausarbeitung Thema: PID - Einstellregeln
//http://www.home.hs-karlsruhe.de/~kero0001/wendtang/wendtang1.html
//Einstellregeln nach Oppelt, ZieglerNichols oder 
//Chien/Hrones/Reswick, Samal:  
//GSA:  gutes Stšrverhalten, aperiodisch (schwingungsfrei)
//GFA:  gutes FŸhrungsverhalten, aperiodisch (schwingungsfrei)
//GS20: gutes Stšrverhalten, 20% †berschwingen
//GF20: gutes FŸhrungsverhalten, 20% †berschwingen
//
//Tn/Ti: Nachstellzeit	(DIN19226/DIN EN 60027-6)
//Tv/Td: Vorhaltzeit	(DIN19226/DIN EN 60027-6)
var res:integer;
begin 
  with PID_Det do
  begin
    K:=PID_Vector(1,0,0); Ti:=NaN; Td:=NaN; res:=-1;
	try
  	  if PIDMethod IN [P_SUM..PID_SUM_Fast] 
      	then if IsNaN(Ks) or IsNaN(Tsum)			or (Ks=0) then exit(res)
      	else if IsNaN(Ks) or IsNaN(Tb) or IsNaN(Te) or (Ks=0) or (Te<=0) or (Tb<0) then exit(res);
  	  res:=ord(PIDMethod);
  	  case PIDMethod of
      	P_Oppelt:		begin K[iKp]:=(1.00/Ks)*(Tb/Te); end; 
      	PI_Oppelt:		begin K[iKp]:=(0.80/Ks)*(Tb/Te); Ti:=3.00*Te; end; 
      	PID_Oppelt:		begin K[iKp]:=(1.20/Ks)*(Tb/Te); Ti:=2.00*Te; Td:=0.42*Te; end; 
      	P_ZiegNich:		begin K[iKp]:=(1.00/Ks)*(Tb/Te); end;
      	PI_ZiegNich:	begin K[iKp]:=(0.90/Ks)*(Tb/Te); Ti:=3.33*Te; end; 
      	PID_ZiegNich:	begin K[iKp]:=(1.20/Ks)*(Tb/Te); Ti:=2.00*Te; Td:=0.50*Te; end;       
      	P_SUM:			begin K[iKp]:=(1.00/Ks); Td:=0; end;
      	PD_SUM:			begin K[iKp]:=(1.00/Ks); Td:=0.33*Tsum; end;
      	PI_SUM:			begin K[iKp]:=(0.50/Ks); Ti:=0.50*Tsum; Td:=0; end;
      	PID_SUM:		begin K[iKp]:=(1.00/Ks); Ti:=0.66*Tsum; Td:=0.167*Tsum; end;
	  	PI_SUM_Fast:	begin K[iKp]:=(1.00/Ks); Ti:=0.70*Tsum; Td:=0; end;
      	PID_SUM_Fast:	begin K[iKp]:=(2.00/Ks); Ti:=0.80*Tsum; Td:=0.194*Tsum; end;      
      	P_CHR_GSA,
      	P_CHR_GFA: 		begin K[iKp]:=(0.30/Ks)*(Tb/Te); end;
	  	P_CHR_GS20,
	  	P_CHR_GF20: 	begin K[iKp]:=(0.70/Ks)*(Tb/Te); end; 
      	PI_CHR_GSA:		begin K[iKp]:=(0.60/Ks)*(Tb/Te); Ti:=4.00*Te; end;
      	PI_CHR_GFA:		begin K[iKp]:=(0.35/Ks)*(Tb/Te); Ti:=1.20*Tb; end;
	  	PI_CHR_GS20:	begin K[iKp]:=(0.70/Ks)*(Tb/Te); Ti:=2.30*Te; end;
      	PI_CHR_GF20:	begin K[iKp]:=(0.60/Ks)*(Tb/Te); Ti:=1.00*Tb; end;    
      	PID_CHR_GSA:	begin K[iKp]:=(0.95/Ks)*(Tb/Te); Ti:=2.40*Te; Td:=0.42*Te; end;
      	PID_CHR_GFA:	begin K[iKp]:=(0.60/Ks)*(Tb/Te); Ti:=1.00*Tb; Td:=0.50*Te; end;    
      	PID_CHR_GS20:	begin K[iKp]:=(1.20/Ks)*(Tb/Te); Ti:=2.00*Te; Td:=0.42*Te; end;
      	PID_CHR_GF20:	begin K[iKp]:=(0.95/Ks)*(Tb/Te); Ti:=1.35*Tb; Td:=0.47*Te; end; 
	  	P_Default,
	  	P_SAMAL_GSA,
      	P_SAMAL_GFA: 	begin K[iKp]:=(0.30/Ks)*(Tb/Te); end;
      	P_SAMAL_GS20,
	  	P_SAMAL_GF20:	begin K[iKp]:=(0.71/Ks)*(Tb/Te); end;
      	PI_SAMAL_GFA:	begin K[iKp]:=(0.34/Ks)*(Tb/Te); Ti:=1.20*Tb; end;
      	PI_SAMAL_GF20:	begin K[iKp]:=(0.59/Ks)*(Tb/Te); Ti:=1.00*Tb; end;
      	PI_Default,
	  	PI_SAMAL_GSA:	begin K[iKp]:=(0.59/Ks)*(Tb/Te); Ti:=4.00*Te; end;
	  	PI_SAMAL_GS20:	begin K[iKp]:=(0.71/Ks)*(Tb/Te); Ti:=2.30*Te; end;
      	PID_SAMAL_GFA:	begin K[iKp]:=(0.59/Ks)*(Tb/Te); Ti:=1.00*Tb; Td:=0.50*Te; end; 
      	PID_SAMAL_GF20:	begin K[iKp]:=(0.95/Ks)*(Tb/Te); Ti:=1.35*Tb; Td:=0.47*Te; end;
      	PID_Default,
      	PID_SAMAL_GSA:	begin K[iKp]:=(0.95/Ks)*(Tb/Te); Ti:=2.40*Te; Td:=0.42*Te; end;   
      	PID_SAMAL_GS20:	begin K[iKp]:=(1.20/Ks)*(Tb/Te); Ti:=2.00*Te; Td:=0.42*Te; end;
      	else			begin K[iKp]:=(1.00/Ks); end;
  	  end; // case
  	  if not IsNaN(Ti) and (Ti<>0) then K[iKi]:=K[iKp]/Ti; 
  	  if not IsNan(Td) then K[iKd]:=K[iKp]*Td;
  	  SAY(loglvl,'PID_GetParaIn ['+Trimme(GetEnumName(TypeInfo(PID_Method_t),ord(PIDMethod))+' '+loginfo,3)+']: Ks: '+Num2Str(Ks,0,PID_nk8)+' Te: '+Num2Str(Te,0,PID_nk8)+'s Tb: '+Num2Str(Tb,0,PID_nk8)+'s');
  	  SAY(loglvl,'PID_GetParaOut['+Trimme(GetEnumName(TypeInfo(PID_Method_t),ord(PIDMethod))+' '+loginfo,3)+']: Kp: '+Num2Str(K[0],0,PID_nk8)+' Ki: '+Num2Str(K[1],0,PID_nk8)+'  Kd: '+Num2Str(K[2],0,PID_nk8)+' Ti: '+Num2Str(Ti,0,PID_nk8)+'s Td: '+Num2Str(Td,0,PID_nk8)+'s');
  	except
	  LOG_Writeln(LOG_ERROR,'PID_GetPara['+GetEnumName(TypeInfo(PID_Method_t),ord(PIDMethod))+' '+loginfo+']: Ks: '+Num2Str(Ks,0,PID_nk8)+' Te: '+Num2Str(Te,0,PID_nk8)+'s Tb: '+Num2Str(Tb,0,PID_nk8)+'s');
  	end;
  end; // with
  PID_GetPara:=res;
end;

procedure PID_Test_GetPara;
var PID_Det:PID_Det_t; K:PID_array_t;
begin
  with PID_Det do begin PIDMethod:=PID_SAMAL_GSA; Ks:=1; Tb:=1; Te:=1; end;
  PID_GetPara(LOG_INFO,PID_Det,K,'Test GetPara');

  with PID_Det do begin PIDMethod:=PI_CHR_GFA; Ks:=1; Tb:=1; Te:=1; end;
  PID_GetPara(LOG_INFO,PID_Det,K,'Test GetPara');  
  
  with PID_Det do begin PIDMethod:=PI_Default; Ks:=1; Tb:=1; Te:=1; end;
  PID_GetPara(LOG_INFO,PID_Det,K,'Test GetPara');
  
  with PID_Det do begin PIDMethod:=PID_Default; Ks:=1; Tb:=1; Te:=1; end;
  PID_GetPara(LOG_INFO,PID_Det,K,'Test GetPara');
  
  with PID_Det do begin PIDMethod:=PI_SAMAL_GSA; Ks:=1; Tb:=1; Te:=1; end;
  PID_GetPara(LOG_INFO,PID_Det,K,'Test GetPara');
  
  with PID_Det do begin PIDMethod:=PI_Default; Ks:=242; Tb:=468.782315971190660; Te:=30.625848362291332; end;
  PID_GetPara(LOG_INFO,PID_Det,K,'Test GetPara');  
  
  with PID_Det do begin PIDMethod:=PI_Default; Ks:=242; Tb:=0.468782315971190660; Te:=0.030625848362291332; end;
  PID_GetPara(LOG_INFO,PID_Det,K,'Test GetPara'); 
  
  with PID_Det do begin PIDMethod:=PI_Default; Ks:=242; Tb:=0.000468782315971190660; Te:=0.000030625848362291332; end;
  PID_GetPara(LOG_INFO,PID_Det,K,'Test GetPara'); 
end;

procedure PID_SimCSV(tl:TStringList; var PID_Det:PID_Det_t; var pid:PID_Struct_t);
// time;td;U;cnt;W;U(avg);Xp;WT
var i:longint; r,OldVal,NewVal,Stellgroesse,SetPoint:PID_float_t; sh:string; 
begin
  with pid do
  begin
	r:=0; OldVal:=0; 
    for i:=1 to tl.count do
    begin
      if i>1 then 
      begin
        sh:=tl[i-1]; 
        if Str2Num(AdjZahl(CSV_Item(sh,';',5)),SetPoint)	and
           Str2Num(AdjZahl(CSV_Item(sh,';',6)),NewVal) 		then
        begin
	      PID_Calc(pid,SetPoint,NewVal,false);
	      Stellgroesse:=pid.PID_ControlOut;
	      r:=				r+(Stellgroesse/(SetPoint/PID_Det.Ks))*(NewVal-OldVal);
	      tl[i-1]:=tl[i-1]+';'+AdjZahlDE(r,0,PID_nk8)+';'+AdjZahlDE(Stellgroesse*PID_Det.Ks, 0,PID_nk8);
	      OldVal:=NewVal;
	    end;
	  end else tl[i-1]:=tl[i-1]+';X;Y(scale='+Num2Str(PID_Det.Ks,0,4)+')'; // csv Hdr
    end;
  end; // with
end;

function  Twiddle_Info(var PID_Twiddle:PID_Twiddle_t; fmt:longint):string;
const nkc=15; gkc=nkc+5;
var li:longint; outstr:string;
begin
  outstr:='';
  with PID_Twiddle do
  begin
	case fmt of
	   10: 	begin  // show start p0 
			  outstr:='p0 [0-2]:    '; 
			  for li:=1 to Length(p0)		do outstr:=outstr+Num2Str(p0[li-1],gkc,nkc)+' ';
			end;
	   11: 	begin  // show Twiddle p 
			  outstr:='p  [0-2]:    '; 
			  for li:=1 to Length(p)		do outstr:=outstr+Num2Str(p[li-1],gkc,nkc)+' ';
			end;
	   12: 	begin  // show Twiddle dp 
			  outstr:='dp [0-2]:    '; 
			  for li:=1 to Length(dp) 		do outstr:=outstr+Num2Str(dp[li-1],gkc,nkc)+' ';
			end;
	   13: 	begin  // show Twiddle ps 
			  outstr:='pS [0-2/'+Bool2Dig(sum(ps)<>0)+']:  '; 
			  for li:=1 to Length(ps) 		do outstr:=outstr+Num2Str(ps[li-1],gkc,nkc)+' ';
			end;
	   14: 	begin  // show Twiddle dps 
			  outstr:='dpS[0-2/'+Bool2Dig(sum(dps)<>0)+']:  '; 
			  for li:=1 to Length(dps) 		do outstr:=outstr+Num2Str(dps[li-1],gkc,nkc)+' ';
			end;
	   15: 	begin  // show Twiddle err 
			  outstr:='err[0-2]:    '; 
			  for li:=1 to Length(err) 		do outstr:=outstr+Num2Str(err[li-1],gkc,nkc)+' ';
			end;
	   else	LOG_Writeln(LOG_ERROR,'Twiddle_Info: unknown fmt: '+Num2Str(fmt,0));
	end; // case
  end; // with
  Twiddle_Info:=outstr;
end;

function  PID_Info(var PID_Struct:PID_Struct_t; fmt:longint):string;
const nkc=15; gkc=nkc+5;
var li:longint; outstr:string;
begin
  outstr:='';
  with PID_Struct do
  begin
	  case fmt of
	    1:	begin
			  outstr:='Kp,Ki,Kd:    '; 
			  for li:=1 to Length(PID_K)	do outstr:=outstr+Num2Str(PID_K[li-1],gkc,nkc)+' ';
			end;
	    2:	begin
			  outstr:='KpS,KiS,KdS: '; 
			  for li:=1 to Length(PID_Ksav)	do outstr:=outstr+Num2Str(PID_Ksav[li-1],gkc,nkc)+' ';
			end;
	    3:	begin
			  outstr:='ControlOut,MinOutput,MaxOutput:   ';
			  outstr:=outstr+Num2Str(PID_ControlOut,gkc,nkc)+' '+Num2Str(PID_MinOutput,gkc,nkc)+' '+Num2Str(PID_MaxOutput,gkc,nkc);
			end;			
	    4:	begin
			  outstr:='PID_SampleTime,WindupResetValue,TwiddleEnable,PID_IntImprove,PID_DifImprove: ';
			  outstr:=outstr+Num2Str(PID_SampleTime_us/1000,0,4)+'ms '+Num2Str(PID_IntegratedWindupResetValue,0,2)+' '+Bool2Str(PID_Twiddle.twiddle_on)+' '+Bool2Str(PID_IntImprove)+' '+Bool2Str(PID_DifImprove);
			end;
	    5:	begin
			  outstr:='TAKp,Ki,Kd:  '; 
			  for li:=1 to Length(PID_KTa)	do outstr:=outstr+Num2Str(PID_KTa[li-1],gkc,nkc)+' ';
			end;
	    6:	begin
			  outstr:='LimsKp,Ki,Kd:'; 
			  for li:=1 to Length(PID_Lims)	do outstr:=outstr+Num2Str(PID_Lims[li-1],gkc,nkc)+' ';
			end;
		7:	outstr:=PID_Info(PID_Struct,1)+LF+PID_Info(PID_Struct,5)+LF+PID_Info(PID_Struct,6)+LF+
					PID_Info(PID_Struct,3)+LF+PID_Info(PID_Struct,4);
	    10..15: outstr:=Twiddle_Info(PID_Twiddle,fmt);
	   else	LOG_Writeln(LOG_ERROR,'PID_Info: unknown fmt: '+Num2Str(fmt,0));
	  end; // case
  end; // with
  PID_Info:=outstr;
end;

procedure PID_Twiddle_LogLevel(var PID_Twiddle:PID_Twiddle_t; lvl1,lvl2:T_ErrorLevel);
begin
  with PID_Twiddle do
  begin
    twiddle_LogLevel:=	lvl1;
    twiddle_LogColor:=	lvl2;
  end; // with
end;

procedure PID_EnableTwiddle_Save(var PID_Twiddle:PID_Twiddle_t; enable:boolean);
// enable/disable writing optimization data to .ini-file
begin
  with PID_Twiddle do
  begin
  	if enable then 
  	begin
  	  twiddle_save:=((Trimme(twiddle_INI_sect,3)<>'') and (Trimme(twiddle_INI_key,3)<>''));
  	  if not twiddle_save then
  	   LOG_Writeln(LOG_ERROR,'PID_EnableTwiddle_Save: no enable, due to missing sect/key name');
  	end else twiddle_save:=false;
  end; // with
end;

procedure PID_SetTwiddle_KeyName(var PID_Twiddle:PID_Twiddle_t; sect,key:string);
// set section and key name for .ini-file
begin
  with PID_Twiddle do
  begin
	twiddle_INI_sect:=sect;
	twiddle_INI_key:= key;
	if ((Trimme(sect,3)='') or (Trimme(key,3)=''))
	  then PID_EnableTwiddle_Save(PID_Twiddle,false);
  end; // with
end;
  
procedure PID_SaveTwiddle(var PID_Twiddle:PID_Twiddle_t; K,dK:PID_array_t);
// save twiddle data, to .ini-file
var _sav:boolean; sh:string;
begin
  with PID_Twiddle do
  begin
    if twiddle_save then
    begin
      if twiddle_saved then
      begin
    	_sav:=(twiddle_sum_dp<twiddle_sum_dps);
    	if _sav then twiddle_tolnoreachcnt:=0
    			else inc(twiddle_tolnoreachcnt);
      end else _sav:=true;

      if _sav then
      begin
    	ps:=K; dps:=dK; twiddle_sum_dps:=twiddle_sum_dp;

  	  	sh:=PID_VectorStr(ps,			0,-1,'|')+';'+
		  	PID_VectorStr(dps,			0,-1,'|')+';'+
		  	PID_VectorStr(twiddle_tol,	0,-1,'|')+';'+
			GetXMLTimeStamp(now);
	
	  	BIOS_SetIniString(twiddle_INI_sect,twiddle_INI_key,sh,[]);

	  	sh:='PID_SaveTwiddle['+Num2Str(twiddle_ID,0)+'/'+
				twiddle_INI_sect+'/'+twiddle_INI_key+']:'+
				' sumdp:'+Num2Str(twiddle_sum_dp,0,PID_nk15);

	  	if (twiddle_sum_dps<twiddle_tol[1]) then
	  	begin
	  	  twiddle_save:=false; // minimum tolerance reached
	  	  		 sh:=sh+' tol[0]:'+ Num2Str(twiddle_tol[1],0,PID_nk15);
	  	end else sh:=sh+' tol[0]:'+ Num2Str(twiddle_tol[0],0,PID_nk15);
	  
	  	SAY(twiddle_LogLevel,twiddle_LogColor,sh);
	  	twiddle_saved:=true;
	  end
	  else
	  begin
	    if (twiddle_tolnoreachcnt>=3) then // can not reach minimum tol[1] 3x above tol[0]
	    begin
	      twiddle_save:=false;
	      SAY(twiddle_LogLevel,twiddle_LogColor,
		  	'PID_SaveTwiddle['+Num2Str(twiddle_ID,0)+'/OFF]: could not reach tol[1]:'+
		  	Num2Str(twiddle_tol[1],0,PID_nk15));	      
	    end;
	  end;
	  
	end;
  end; // with
end;

function  PID_ReadTwiddle(sect,key:string; var K,dK,tol:PID_array_t; replvl1,replvl2:T_ErrorLevel):boolean;
// restore twiddle data, to continue/benefit from previous optimizations
//            Kp     Ki     Kd     dKp         dKi            dKd         tols tol    na  savedate
// <sect/key>=3.1089|0.0089|0.7695;0.000004245|0.000000011910|0.000005511;0.01|0.0001|0.0;2017-12-12..
var ok:boolean; i:longint; r:PID_float_t; sh:string;
begin
  ok:=false;
  if ((sect<>'') and (key<>'')) then
  begin
	sh:=Trimme(BIOS_GetIniString(sect,key,''),3);
	if (sh<>'') then
	begin
	  ok:=true;
	  for i:= 0 to 2 do 
	  begin
		if ok then ok:=Str2Num(CSV_Item(CSV_Item(sh,';',1),'|',i+1),r); 
		if ok then K[i]:=r;
		
		if not 		   Str2Num(CSV_Item(CSV_Item(sh,';',2),'|',i+1),dK[i]) then
		begin // default values, if dK-part is wrong/missing
		  case i of 
			  0: dK[i]:=0.10;
			  1: dK[i]:=0.20;
			  2: dK[i]:=0.01;
		  end; // case
		  LOG_Writeln(LOG_ERROR,'PID_ReadTwiddle['+sect+'/'+key+']: using default  dK['+Num2Str(i,0)+']='+Num2Str(dK[i],0,2));
		end; // if
		
		if not 		   Str2Num(CSV_Item(CSV_Item(sh,';',3),'|',i+1),tol[i]) then
		begin // default values, if tol-part is wrong/missing
		  case i of 
			  0: tol[i]:=PID_twiddle_tolerance*PID_twiddleSavAtTolScal_c; // 0:twiddle_savetol
			  1: tol[i]:=PID_twiddle_tolerance;							  // 1:twiddle_tol
			  2: tol[i]:=0;												  // 2:not used
		  end; // case
		  LOG_Writeln(LOG_ERROR,'PID_ReadTwiddle['+sect+'/'+key+']: using default tol['+Num2Str(i,0)+']='+Num2Str(tol[i],0,2));
		end; // if
		
	  end;
	  SAY(replvl1,replvl2,'PID_ReadTwiddle['+sect+'/'+key+']: '+CSV_Item(sh,';',4)+' stat:'+Bool2YNS(ok));
	  SAY(replvl1,replvl2,'K:  '+PID_VectorStr(K,  0,PID_nk15));
	  SAY(replvl1,replvl2,'dK: '+PID_VectorStr(dK, 0,PID_nk15));
	  SAY(replvl1,replvl2,'tol:'+PID_VectorStr(tol,0,PID_nk15));
	end;
  end else LOG_Writeln(LOG_ERROR,'PID_ReadTwiddle: no sect/key pair');  
  PID_ReadTwiddle:=ok;
end;

function  PID_ReadTwiddle(sect,key:string;  var K,dK,tol:PID_array_t):boolean;
begin PID_ReadTwiddle:=PID_ReadTwiddle(sect,key,K,dK,tol,LOG_WARNING,LOG_MAGENTA); end;

procedure PID_Init(var PID_Struct:PID_Struct_t; SampleTime_us:int64; K:PID_array_t);
begin 
  PID_Init(PID_Struct,0,10000,false,NaN,NaN,0,SampleTime_us,
  	K,
  	PID_Vector(0.25,0.2,0.01),
  	PID_Vector(PID_twiddle_tolerance*PID_twiddleSavAtTolScal_c,PID_twiddle_tolerance,0)); 
end;

procedure PID_EnableTwiddle(var PID_Twiddle:PID_Twiddle_t; enab:boolean);
begin PID_Twiddle.twiddle_on:=enab; end;

procedure PID_InitTwiddle(var PID_Twiddle:PID_Twiddle_t; ID:longint; enab:boolean; itermax:longword; ap,dK,tol:PID_array_t);
begin
  with PID_Twiddle do
  begin
    twiddle_ID:=			ID;
	twiddle_best_error:=	MaxFloat;
	twiddle_sum_dp:=		MaxFloat;
	twiddle_sum_dps:=		twiddle_sum_dp;	
	twiddle_idx:=			0;
	twiddle_state:=			0;
	twiddle_iterations:=	0;
	twiddle_repdt:=			0;
	twiddle_tolnoreachcnt:=	0;
	twiddle_intermax:=		itermax;
	twiddle_tol:=			tol;
	twiddle_saved:=			false;
	p:=ap; p0:=p;

//	calc twiddle delta array
	dp[iKp]:=dK[iKp]*p[iKp];
	dp[iKi]:=dK[iKi]*p[iKi];
	dp[iKd]:=dK[iKd]*p[iKd];

	PID_Twiddle_LogLevel(	PID_Twiddle,LOG_WARNING,LOG_MAGENTA);
	PID_SetTwiddle_KeyName(	PID_Twiddle,'','');
  	PID_EnableTwiddle(	 	PID_Twiddle,enab);
//writeln(ID,' twiddle:',twiddle_on,' ',Twiddle_Info(PID_Twiddle,11)+' '+Twiddle_Info(PID_Twiddle,12)+' ',CR); 
  end; // with  
end;

procedure PID_UpdateError(var PID_Twiddle:PID_Twiddle_t; error:PID_float_t);
begin
  with PID_Twiddle do
  begin
	err[iKd]:= 	error - err[iKp];	// error - OLD_error
	err[iKi]:= 	err[iKi] + error;
	err[iKp]:=	error;				// NEWerror
  end; // with
end;

function  PID_TotalError(var PID_Twiddle:PID_Twiddle_t; K:PID_array_t):PID_float_t;
begin
  with PID_Twiddle do
  begin
//	PID_TotalError:= - K[iKp]*err[iKp] - K[iKi]*err[iKi] - K[iKd]*err[iKd];
	PID_TotalError:= abs(err[iKp]) + abs(err[iKi]) + abs(err[iKd]);
  end; // with
end;

function  PID_CalcTwiddle(var PID_Twiddle:PID_Twiddle_t; var Karr:PID_array_t):boolean;
// https://github.com/anupriyachhabra/PID-Controller/blob/master/src/PID.cpp
// https://github.com/antevis/CarND_T2_P4_PID/tree/master/src
// https://www.youtube.com/watch?v=2uQ2BSzDvXs
// http://www.htw-mechlab.de/index.php/numerische-optimierung-in-matlab-mit-twiddle-algorithmus/
// https://junshengfu.github.io/PID-controller/
const tw_dlta=0.1; tw_finc=1.0+tw_dlta; tw_fdec=1.0-tw_dlta;
var _res:boolean; _err:PID_float_t; _cnt:longint;
begin
	_res:=false;
	with PID_Twiddle do
  	begin
      twiddle_sum_dp:=sum(dp);
//writeln('  PID_CalcTwiddle[',twiddle_idx:0,'/',twiddle_state:0,']: sumdp:',twiddle_sum_dp:0:5,' tol:',twiddle_tol[1]:0:5,' dp:',dp[twiddle_idx]:0:5,' wr2ini:',(twiddle_tol[0]<>twiddle_tol[2]));

	  if twiddle_save then
	  begin	  	
	  	if (twiddle_sum_dp<=twiddle_tol[0]) 
	  	  then PID_SaveTwiddle(PID_Twiddle,p,dp);
	  end; // keep results
	  
	  if (twiddle_sum_dp>twiddle_tol[1]) then
	  begin	
//if (twiddle_idx=0) then writeln('    twiddle_sum_dp: ',twiddle_sum_dp:0:5,' twiddle_tol[1]: ',twiddle_tol[1]:0:5,' err:',twiddle_best_error:0:2);
	  	case twiddle_state of
		  0:begin // twNEW:		use new delta 
			  p[twiddle_idx]:=p[twiddle_idx] + dp[twiddle_idx];
    		  twiddle_state:=1;
			end;			
		  1:begin // twTST		test how new delta behaves (better/worse)
			  _err:=PID_TotalError(PID_Twiddle,Karr);
    		  if (_err < twiddle_best_error) then
    		  begin	// better
        		twiddle_best_error:=_err;
				dp[twiddle_idx]:=	dp[twiddle_idx] * tw_finc; // * 1.1	try next UPdelta
				twiddle_state:=3;	// better -> ok, keep it
          	  end
          	  else
          	  begin // worsen
				p[twiddle_idx]:=p[twiddle_idx] - 2 * dp[twiddle_idx];
				if (p[twiddle_idx]<0) then p[twiddle_idx]:=0; 			//**
				twiddle_state:=2;	// go to modification track
          	  end;
			end;
		  2:begin // twMDFY		revoke active delta
			  _err:=PID_TotalError(PID_Twiddle,Karr);
			  if (_err < twiddle_best_error) then
			  begin
				twiddle_best_error:= _err;
				dp[twiddle_idx]:=	 dp[twiddle_idx] * tw_finc; // 1.1
          	  end
          	  else
          	  begin	// correct value and delta to old levels
				 p[twiddle_idx]:=	 p[twiddle_idx] + dp[twiddle_idx];
				dp[twiddle_idx]:=	dp[twiddle_idx] * tw_fdec; // 0.9
          	  end;
			  twiddle_state:=3;
			end;
		  3:begin // twOK	try next para
		  	  _cnt:=0;
			  repeat
			  	twiddle_idx:=((twiddle_idx+1) mod Length(p));
			  	inc(_cnt);
			  until (dp[twiddle_idx]<>0) or (_cnt>Length(p));			  
			  twiddle_state:=0;
			end;
		  else twiddle_state:=0;
	  	end; // case
	
//if TimeElapsed(twiddle_repdt,2500) then writeln(twiddle_ID,' ',Twiddle_Info(PID_Twiddle,11)+' '+Twiddle_Info(PID_Twiddle,12)+' '+Twiddle_Info(PID_Twiddle,10),CR);
(*if (twiddle_idx=0) then begin  	
writeln(Twiddle_Info(PID_Twiddle,11));
writeln(Twiddle_Info(PID_Twiddle,12));
writeln(Twiddle_Info(PID_Twiddle,15));
writeln;end; *)
	  	
	  end else _res:=true;	// required error tolerance reached	
	  Karr:=p; err:=PID_Vector(0,0,0);	
//	  SAY(LOG_WARNING,'Twiddle['+Num2Str(twiddle_ID,0)+']: '+Num2Str(p[0],9,6)+' '+Num2Str(p[1],9,6)+' '+Num2Str(p[2],9,6));
	end; // with
  PID_CalcTwiddle:=_res;
end;

function  PID_ExecTwiddle(var PID_Twiddle:PID_Twiddle_t; var PID_K:PID_array_t; errorUpdate:PID_float_t):boolean;
var _res:boolean;
begin 
  _res:=false;
  with PID_Twiddle do
  begin
	if twiddle_on then
	begin // PID self tuning
	  inc(twiddle_iterations);
	  PID_UpdateError(PID_Twiddle,errorUpdate);
	  if (twiddle_iterations>twiddle_intermax) then
	  begin
		_res:=PID_CalcTwiddle(PID_Twiddle,PID_K);
		twiddle_iterations:=0;
		if _res then 
		begin
		  twiddle_on:=false;
		  PID_SaveTwiddle(PID_Twiddle,p,dp);	// prevent overwrite
		  SAY(twiddle_LogLevel,twiddle_LogColor,
		  	'PID_ExecTwiddle['+Num2Str(twiddle_ID,0)+'/OFF]: '+
		  	Twiddle_Info(PID_Twiddle,11));//+' '+Twiddle_Info(PID_Twiddle,15));
		end;
	  end;
	end;
  end; // with
  PID_ExecTwiddle:=_res;
end;

procedure Twiddle_Test;
const
  scale_c=1000;
  Kp=1;  Ki=2;   Kd=3;			// PID parameter
  ID=0;	 dm_c=8; tol_c=(1/scale_c);

  ERR_Feed_c:array[0..(dm_c-1)] of PID_float_t = ( 000, 0, -1, 0, 2, 3, -1, 0 );
  
var loop,n:integer; tolreach:boolean; PID_Twiddle:PID_Twiddle_t; Karr:PID_array_t; Err:PID_float_t;
begin
  RPI_HW_Start([InstSignalHandler]);
  loop:=0; n:=0; 
  Karr:=PID_Vector(Kp,Ki,Kd);
//Karr:=PID_Vector(Kp*scale_c,Ki*scale_c,Kd*scale_c);
  
  PID_InitTwiddle(PID_Twiddle,ID,true,
  	0,	// itermax					// 0:no iterations
  	Karr,							// array with params to optimize, based on ERROR Feedack
  	PID_Vector(0.1, 0,  0),			// start deltas, optimize 1.value only
  	PID_Vector(0,1*tol_c,0)			// tol: 0.01	/ no save to .ini-file (tol[0]=tol[2])
  );
  	
  repeat
    if (n<5) then Err:=ERR_Feed_c[0]/(n+1) else Err:=0;	// Error feedback
//  Err:=ERR_Feed_c[loop];	// Error feedback
	tolreach:=PID_ExecTwiddle(PID_Twiddle,Karr,-Err);
	inc(n); 
	inc(loop); if (loop>=dm_c) then loop:=0; // idx update for ERR_Feed
  until tolreach or (n>15000) or terminateProg;
  
  writeln;
  writeln(Twiddle_Info(PID_Twiddle,10));
  writeln(Twiddle_Info(PID_Twiddle,11));
  writeln('END Twiddle_Test: ',n);
end;

function  PID_Limit(var Value:PID_float_t; MinOut0,MinOut,MaxOut:PID_float_t):PID_float_t;
begin
  if IsZero(Value,0.01) then
  begin
	if Value<MinOut0 then Value:=MinOut0 else if Value>MaxOut then Value:=MaxOut; 
  end
  else
  begin
	if Value<MinOut  then Value:=MinOut  else if Value>MaxOut then Value:=MaxOut; 
  end;
  PID_Limit:=Value;
end;

procedure PID_SetPrevInput (var PID_Struct:PID_Struct_t; pval:PID_float_t); begin PID_Struct.PID_ProcessValue:=pval; end;
procedure PID_SetSelfTuning(var PID_Struct:PID_Struct_t; On_:boolean); begin PID_Struct.PID_Twiddle.twiddle_on:=On_; end;

procedure PID_SetIntImprove(var PID_Struct:PID_Struct_t; On_:boolean); 
// Default: on
// Switches on or off the "Integration Improvement" mechanism of "PID_Struct". 
// This mechanism prevents overshoot/ringing/oscillation 
// due to integration. To be used after "PID_Init"
begin PID_Struct.PID_IntImprove:=On_; end;

procedure PID_SetDifImprove(var PID_Struct:PID_Struct_t; On_:boolean); 
// Default: on
// Switches on or off the "Differentiation Improvement" mechanism of "PID_Struct".
// This mechanism prevents unnecessary correction
// delay when the actual value is changing towards the SetPoint.
// To be used after "PID_Init"
begin PID_Struct.PID_DifImprove:=On_; end;

procedure PID_ResetIntegrator(var PID_Struct:PID_Struct_t); 
// Re-initialises the PID engine of "PID_Struct" without change of settings
begin PID_Struct.PID_Integrated:=PID_Struct.PID_IntegratedWindupResetValue; end;

procedure PID_IntegratedWindupReset(var PID_Struct:PID_Struct_t; WindupResetValue:PID_float_t); 
begin PID_Struct.PID_IntegratedWindupResetValue:=WindupResetValue; end;

procedure PID_csv_fname(var PID_Struct:PID_Struct_t; csvfilename,fown,fgrp:string);
begin
  with PID_Struct do
  begin
    PID_csv_fown:=fown;
    PID_csv_fgrp:=fgrp;
	if (csvfilename='')
	  then PID_csv_fn:='PID'+Num2Str(PID_nr,0)+'.csv'
	  else PID_csv_fn:=csvfilename;
  end;
end;
procedure PID_csv_fname(var PID_Struct:PID_Struct_t; csvfilename:string);
begin PID_csv_fname(PID_Struct,csvfilename,'',''); end;

procedure PID_csv_SetPointMax(var PID_Struct:PID_Struct_t; spmax:PID_float_t);
begin 
  with PID_Struct do
  begin
  	PID_csv_SetPointMaximum:=spmax;
  	
  	if (PID_KTa[iKp]<>0) 
  	  then PID_csv_Lims[iKp]:=PID_KTa[iKp]*spmax else PID_csv_Lims[iKp]:=1;

  	if (PID_KTa[iKi]<>0) 
  	  then PID_csv_Lims[iKi]:=PID_KTa[iKi]*spmax else PID_csv_Lims[iKi]:=1;
  	  
  	if (PID_KTa[iKd]<>0) 
  	  then PID_csv_Lims[iKd]:=PID_KTa[iKd]*spmax else PID_csv_Lims[iKd]:=1;
  end; // with
end;

procedure PID_csv_RECtime(var PID_Struct:PID_Struct_t; rectim_ms:word);
begin PID_Struct.PID_csv_RECtime_ms:=rectim_ms; end;

procedure PID_csv_USE(var PID_Struct:PID_Struct_t; use:boolean);
begin
  with PID_Struct do
  begin
    if not use then 
    begin
      if PID_csv_enable then 
      begin
        if (PID_csv_TL.count>0) then
        begin
          PID_csv_enable:=false; // prevent further record adds
          PID_csv_TL.insert(0,'tim,sp,pv,out,d,i,p');//',integrated'); // add csv header
          LOG_Writeln(LOG_WARNING,'PID_csv_USE: write '+Num2Str(PID_csv_TL.count,0)+' records to '+PID_csv_fn);
          StringList2TextFile(PID_csv_fn,PID_csv_TL);
          PID_csv_TL.clear; 
          LNX_chowngrp(PID_csv_fn,PID_csv_fown,PID_csv_fgrp);
        end else LOG_Writeln(LOG_ERROR,'PID_csv_USE no data');
      end;
    end 
    else
    begin
      LOG_Writeln(LOG_WARNING,'PID_csv_USE: enable and write to '+PID_csv_fn);
      if assigned(PID_csv_TL) 
      	then PID_csv_TL.clear
      	else PID_csv_TL:=TStringList.create;
    end;
    PID_csv_enable:=use;   
  end; // with
end;

procedure PID_close(var PID_Struct:PID_Struct_t);
begin
  PID_csv_USE(PID_Struct,false);
  with PID_Struct do
  begin
  	if assigned(PID_csv_TL) then PID_csv_TL.free;
  end; // with
end;

procedure PID_SetMinMaxLimit(var PID_Struct:PID_Struct_t; MinOutput,MaxOutput:PID_float_t);
begin
  with PID_Struct do 
  begin
	PID_MinOutput:= MinOutput; 
	PID_MaxOutput:= MaxOutput; 
	
	if (PID_KTa[iKp]=0) or IsNaN(PID_MaxOutput)
	  then PID_Lims[iKp]:=NaN
	  else PID_Lims[iKp]:=PID_MaxOutput/PID_KTa[iKp];
	  
	if (PID_KTa[iKi]=0) or IsNaN(PID_MaxOutput)
	  then PID_Lims[iKi]:=NaN
	  else PID_Lims[iKi]:=PID_MaxOutput/PID_KTa[iKi];
	  
	if (PID_KTa[iKd]=0) or IsNaN(PID_MaxOutput)
	  then PID_Lims[iKd]:=NaN
	  else PID_Lims[iKd]:=PID_MaxOutput/PID_KTa[iKd];
  end; // with
end;

procedure PID_SetSampleTime(var PID_Struct:PID_Struct_t; SampleTime_us:int64);
begin
  with PID_Struct do 
  begin
	if (SampleTime_us<=0) then
	begin
	  PID_SampleTime_us:=10000;	// 10ms
	  LOG_Writeln(LOG_ERROR,'PID_SetSampleTime['+Num2Str(PID_nr,0)+']: adjusted sample time to default '+Num2Str(PID_SampleTime_us,0)+'us');	
	end else PID_SampleTime_us:=SampleTime_us;  
  end; // with
end;

procedure PID_Reset(var PID_Struct:PID_Struct_t);
begin
  with PID_Struct do
  begin 
    PID_ResetIntegrator(PID_Struct); PID_SetPrevInput(PID_Struct,0.0);
	PID_Error:=0; PID_LastError:=0.0; PID_PrevAbsError:=0.0;	PID_cnt:=0;
  end; // with
end;
  
procedure PID_Init(var PID_Struct:PID_Struct_t; nr:longint; itermax:longword; enab_twiddle:boolean; MinOutput,MaxOutput,WindupResetValue:real; SampleTime_us:int64; K,dK,tol:PID_array_t);
// Initialises the PID engine of "PID_Struct"
// Ks = Amplification
// Kp = the "proportional" error multiplier
// Ki = the "integrated value" error multiplier
// Kd = the "derivative" error multiplier
// MinOutput = the minimal value the output value can have, if switched on
// MaxOutput = the maximal value the output can have, 		if switched on
var _pa:PID_array_t;
begin
  with PID_Struct do
  begin
  	PID_nr:=nr;
  	PID_ovr:=false;
  	PID_SetSampleTime			(PID_Struct,SampleTime_us);
  	PID_csv_fname				(PID_Struct,'');
  	PID_csv_RECtime				(PID_Struct,5000);
  	PID_IntegratedWindupReset	(PID_Struct,WindupResetValue); 
  	PID_Reset				 	(PID_Struct); 	 
  	PID_SetIntImprove		 	(PID_Struct,true); 
  	PID_SetDifImprove			(PID_Struct,true);

    PID_csv_enable:=false;
    PID_csc_RECstop:=now;
    PID_SetPointLast:=0;
    PID_SetPoint:=0;
    
	PID_ControlOut:=0; 
    PID_Twiddle.err:=	PID_Vector(0,0,0);
    PID_pid:=		 	PID_Vector(0,0,0);
    PID_K:=K; 			PID_Ksav:=K;

    PID_KTa:=K;
    PID_KTa[iKi]:=PID_K[iKi] * (PID_SampleTime_us / 1000000);	// precalc Ki * Ta // Ta = SampleTime in seconds
    PID_KTa[iKd]:=PID_K[iKd] / (PID_SampleTime_us / 1000000);	// precalc Kd / Ta
    
    PID_SetMinMaxLimit	 	(PID_Struct,MinOutput,MaxOutput);

	clock_gettime(CLOCK_REALTIME,@PID_LastTime);
	if (PID_SampleTime_us>=1000000)
	  then PID_LastTime.tv_sec:=PID_LastTime.tv_sec - ceil(PID_SampleTime_us/1000000)
	  else dec(PID_LastTime.tv_sec);

	clock_gettime(CLOCK_REALTIME,@PID_Time);

	PID_InitTwiddle(PID_Struct.PID_Twiddle,nr,enab_twiddle,itermax,PID_KTa,dK,tol); // tol=0.00001   20211112
  end; // with
end;

// http://rn-wissen.de/wiki/index.php/Regelungstechnik
// https://rn-wissen.de/wiki/index.php/Regelungstechnik#Dimensionierung_nach_Einstellregeln
function  xPID_Calc(var PID_Struct:PID_Struct_t; SetPoint,ProcessValue:PID_float_t; Stoersprung:boolean):PID_float_t;
// To be called at a regular time interval (e.g. every 100 msec)
// SetPoint: the target value for "ProcessValue" to be reached
// ProcessValue: the actual value measured in the system
// Stoersprung:	 SetPoint change, used to prevent twiddle adjust during SetPoint change
// Functionresult: PID function of (SetPoint-ProcessValue) of "PID_Struct",
//   a positive value means "ProcessValue" is too low  (< SetPoint), the process should take action to increase it
//   a negative value means "ProcessValue" is too high (> SetPoint), the process should take action to decrease it
// y = Kp * e + Ki * Ta * esum + Kd / Ta * (e Ð ealt)
begin
  with PID_Struct do
  begin
	clock_gettime(CLOCK_REALTIME, @PID_Time);
	if PID_ovr or (MicroSecondsBetween(PID_Time,PID_LastTime)>=PID_SampleTime_us) then
	begin
	  inc(PID_cnt); 
	  PID_Error:=		SetPoint - ProcessValue;

//	  calc p term
	  PID_pid[iKp]:=	PID_K[iKp] * PID_Error;
	
//	  calc i term and limit integral windup
	  if (Stoersprung or
	  	 (PID_IntImprove and (Sign(PID_Error)<>Sign(PID_Integrated)))) 
	  	then PID_Integrated:= PID_IntegratedWindupResetValue;
	
	  PID_Integrated:=	PID_Integrated + PID_Error;
//	  PID_pid[iKi]:=	PID_KTa[iKi] * PID_Integrated;
	  PID_pid[iKi]:=	PID_K[iKi] * PID_Integrated;
//	  PID_Limit(PID_pid[iKi], PID_MinOutput, PID_MinOutput, PID_MaxOutput);
	
//	  calc d term
	  PID_pid[iKd]:=	PID_K[iKd] * (PID_Error - PID_LastError);
//	  PID_pid[iKd]:=	PID_KTa[iKd] * (PID_Error - PID_LastError);
	  if PID_DifImprove and (abs(PID_Error)<abs(PID_LastError)) 
	  	then PID_pid[iKd]:= 0.0; 

	  PID_LastError:= 	PID_Error;
	  PID_ControlOut:=	(PID_pid[iKp] + PID_pid[iKi] + PID_pid[iKd]);
//	  writeln(pid_cnt:2,' err: ',PID_Error:0:4,' res: ',PID_ControlOut:0:4,' p:',PID_pid[iKp]:0:4,' i:',PID_pid[iKi]:0:4,' d:',PID_pid[iKd]:0:4);

	  PID_Limit(PID_ControlOut, PID_MinOutput, PID_MinOutput, PID_MaxOutput);
	  if not Stoersprung
	  	then PID_ExecTwiddle(PID_Twiddle,PID_K,PID_ControlOut);	
	
	  PID_SetPoint:=	SetPoint;
	  PID_ProcessValue:=ProcessValue;
	  PID_LastTime:=	PID_Time;
	end;
	
	xPID_Calc:=			PID_ControlOut;
  end; // with
end;

// new 20211112
function  PID_Calc(var PID_Struct:PID_Struct_t; SetPoint,ProcessValue:PID_float_t; Stoersprung:boolean):boolean;
// To be called at a regular time interval (e.g. every 100 msec)
// calc time: 9us @ rpi4B
// SetPoint: the target value for "ProcessValue" to be reached
// ProcessValue: the actual value measured in the system
// Stoersprung:	 SetPoint change, used to prevent twiddle adjust during SetPoint change
// Functionresult: PID function of (SetPoint-ProcessValue) of "PID_Struct",
//   a positive value means "ProcessValue" is too low  (< SetPoint), the process should take action to increase it
//   a negative value means "ProcessValue" is too high (> SetPoint), the process should take action to decrease it
// y = Kp * e + Ki * Ta * esum + Kd / Ta * (e Ð ealt)
var _ok:boolean;
begin
  with PID_Struct do
  begin
	clock_gettime(CLOCK_REALTIME, @PID_Time);
	_ok:=(MicroSecondsBetween(PID_Time,PID_LastTime)>=PID_SampleTime_us);
	if _ok or PID_ovr then
	begin
	  inc(PID_cnt); 
	  PID_Error:=		SetPoint - ProcessValue;

//	  calc p term
	  PID_pid[iKp]:=	PID_KTa[iKp] * PID_Error;

//	  calc i term
	  if (PID_KTa[iKi]<>0) then
	  begin
	    if Stoersprung
	  	  then PID_Integrated:= PID_IntegratedWindupResetValue;  	
	  	
	  	PID_Integrated:=PID_Integrated + PID_Error;

// 		limit integral windup
		if (PID_IntImprove and (Sign(PID_Error)<>Sign(PID_Integrated)))
	  	  then Limits(PID_Integrated, -PID_Lims[iKi], PID_Lims[iKi]);
	  	
	  	PID_pid[iKi]:=	PID_KTa[iKi] * PID_Integrated;
	  end else PID_pid[iKi]:=0;

//	  calc d term	
	  if (PID_KTa[iKd]<>0) then
	  begin
	    if  (not PID_DifImprove) or
	    	(PID_DifImprove and (abs(PID_Error)>abs(PID_LastError))) then
	  	begin
	  	  PID_pid[iKd]:=	PID_KTa[iKd] * (PID_Error - PID_LastError);
	  	end else PID_pid[iKd]:=0.0;
	  end else PID_pid[iKd]:=0.0;

	  PID_LastError:= 	PID_Error;
	  PID_ControlOut:=	PID_pid[iKp] + PID_pid[iKi] + PID_pid[iKd];

	  if not (IsNaN(PID_MinOutput) or IsNaN(PID_MaxOutput)) then
	  	Limits(PID_ControlOut,PID_MinOutput,PID_MaxOutput);
	  
	  
	  if PID_Twiddle.twiddle_on and (not Stoersprung) then
		PID_ExecTwiddle(PID_Twiddle,PID_KTa,PID_ControlOut);
	
	  if (SetPoint<>PID_SetPoint) then PID_SetPointLast:=PID_SetPoint;
	  PID_SetPoint:=	SetPoint;
	  PID_ProcessValue:=ProcessValue;
	  PID_LastTime:=	PID_Time;

//writeln('sp:',PID_SetPoint:0:2,' pv:',PID_ProcessValue:0:5,' p:',PID_pid[iKp]:0:5,' i:',PID_pid[iKi]:0:5,' d:',PID_pid[iKd]:0:5,' out:',PID_ControlOut:0:5);

//if (PID_nr=1) then writeln('pid ',PID_csv_enable,' ',PID_csv_RECtime_ms,' ',PID_csv_fn,CR);
	  
	  if PID_csv_enable then
	  begin	// reporting
	    if (PID_csv_TL.count=0) then 
	    begin
	      SetTimeOut(PID_csc_RECstop,PID_csv_RECtime_ms);
	      PID_StartTime:=PID_Time;
	    end;
	    if (PID_csv_RECtime_ms=0) or (not TimeElapsed(PID_csc_RECstop)) then
	    begin
	  	  PID_csv_TL.add(
	  		Num2Str(MicroSecondsBetween(PID_Time,PID_StartTime),0)+','+
	  		Num2Str( scale(PID_SetPoint,-PID_csv_SetPointMaximum,PID_csv_SetPointMaximum,-1,1) ,0,2)+','+
	  		Num2Str( scale(PID_ProcessValue,-PID_csv_SetPointMaximum,PID_csv_SetPointMaximum,-1,1) ,0,5)+','+
	  		Num2Str( scale(PID_ControlOut,PID_MinOutput,PID_MaxOutput,-1,1) ,0,5)+','+	
	  		Num2Str( scale(PID_pid[iKd],-PID_csv_Lims[iKd],PID_csv_Lims[iKd],-1,1) ,0,5)+','+
	  		Num2Str( scale(PID_pid[iKi],-PID_Lims[iKi],PID_Lims[iKi],-1,1) ,0,5)+','+
	  		Num2Str( scale(PID_pid[iKp],-PID_csv_Lims[iKp],PID_csv_Lims[iKp],-1,1) ,0,5)
	  	  );
	  	end;
	  end;
	end;
		
	PID_Calc:=_ok;
  end; // with
end;

function  PID_Calc(var PID_Struct:PID_Struct_t; SetPoint,ProcessValue:PID_float_t):boolean;
begin PID_Calc:=PID_Calc(PID_Struct,SetPoint,ProcessValue,false); end;

procedure PID_Test(csvuse:boolean; csvfn,fusr,fgrp:string);
//just for demo purposes
//simulate PID. How the to be adjusted Value approaches a SetPoint value
const
  scale_c=50; 
  PID_Max=scale_c;	PID_Min=-PID_Max; 	// MaxOutput MinOutput
//Kp=0.4;  Ki=0.2;    Kd=0.0;		// PID parameter
//Kp=0.6;  Ki=0.15;   Kd=0.0;		// PID parameter PI_CHR_GSA xx
  Kp=0.59; Ki=0.1475; Kd=0.0;		// PID parameter PI_SAMAL_GSA Test GetPara]: Kp: 0.59000000 Ki: 0.14750000 Kd: 0.00000000 Ti: 4.00000000 Td: Nan
//Kp=0.35; Ki=0.292;  Kd=0.0;		// PID parameter PI_CHR_GFA Test GetPara]: Kp: 0.35000000 Ki: 0.29166667
//Kp=0.34; Ki=0.283;  Kd=0.0;		// PID parameter PI_Default  Test GetPara]: Kp: 0.34000000 Ki: 0.28333333 Kd: 0.00000000 Ti: 1.20000000 Td: Nan
//Kp=0.59; Ki=0.59;   Kd=0.295;		// PID parameter PID_Default Test GetPara]: Kp: 0.59000000 Ki: 0.59000000 Kd: 0.29500000 Ti: 1.00000000 Td: 0.50000000
  STim_msec=1;						// sample time millisecs
  delta_ms=20/(1000*STim_msec);		// +- delta on data per second -> (+-20mb/sec) delta_sec

  dm_c=8; ntimes_c=64*dm_c; errind_c=false;
  PID_SetPoints_c:array[0..(dm_c-1)] of PID_float_t = ( 0, 1, 1, 1, 1, 0, 0, 0 );
var loop,n,errinject,hwval:integer; bool:boolean; li:longint; dt:TDateTime;
	pid1:PID_Struct_t; NewVal,SetPoint,delta,erri:PID_float_t;
begin
  RPI_HW_Start([InstSignalHandler]); 
//  PID_Init(pid1,STim_msec*1000,PID_Vector(Kp,Ki,Kd));

  PID_Init(pid1,0,3,false,
  	PID_Min,PID_Max,0,STim_msec*1000,
  	PID_Vector(Kp,Ki,Kd),
  	PID_Vector(0.25,0.2,0.01),
  	PID_Vector(PID_twiddleSavAtTolScal_c*PID_twiddle_tolerance,PID_twiddle_tolerance,0));
  	
  PID_SetIntImprove(pid1,true); 
  PID_SetDifImprove(pid1,true);	// enable improvements
//pid1.PID_ovr:=true;			// no timesync block
  PID_csv_RECtime(pid1,0);
  PID_csv_fname	 (pid1,csvfn,fusr,fgrp);
  PID_csv_SetPointMax(pid1,scale_c);
  PID_csv_USE	 (pid1,csvuse);
  PID_EnableTwiddle(pid1.PID_Twiddle,false);
  writeln('PID_INFO:'+LF+PID_Info(pid1,7));
  NewVal:=0; loop:=0; n:=0; errinject:=0; delta:=0;
  li:=10000;	// 10sec
  writeln('RunTime:',(li/1000):0:1,'sec, keypress will terminate');
  SetTimeOut(dt,li);  
  repeat
    SetPoint:=PID_SetPoints_c[loop]*scale_c;
//writeln(loop:3,' sp:',setpoint:0:2);
    erri:=1;
	if PID_Calc(pid1,SetPoint,NewVal,false) then 
	begin
	  delta:=pid1.PID_ControlOut;
	  hwval:=round(scale(delta,PID_Min,PID_Max,0,255));
//	  writeln('PID_Test: SetPoint:',SetPoint:7:2,'  PV:',NewVal:7:2,'   adjVal:',delta:7:2,' e.g. HWval:',hwval:4);
	  {$warnings off} 
	  if errind_c then 
	  begin
	    inc(errinject);
	  	if (errinject>5) then
	  	begin
	  	  erri:=random;
		  if (random<0.5) then erri:=-erri;
		  erri:=5*erri;
//	  	  writeln('PID_Test: Error inject ',erri:7:2);
	  	  errinject:=0;
	  	end; 
	  end;
	  {$warnings on} 
	  inc(n);
	  if n>=ntimes_c then 
	  begin 
	    n:=0;	inc(loop);
	    if loop>=dm_c then loop:=0;
	  end;
	end;
	NewVal:=NewVal+delta*delta_ms*erri;
	delay_msec(STim_msec); 
  until terminateProg or keypressed or TimeElapsed(dt);
  PID_close(pid1);
end;

procedure PID_TestSim;
var _tl:TStringList; idxa,idxe,avgnumIst,avgnumPInc:longint;
	timadj,StoerSprung:PID_float_t; K:PID_array_t;
	pid1:PID_Struct_t; PID_Det:PID_Det_t;
begin
  _tl:=TStringList.create; 
  timadj:=PID_sim(_tl,0); idxa:=0; idxe:=_tl.count-1; ShowStringList(_tl); 
  PID_DetAvgs(idxa,idxe,avgnumIst,avgnumPInc);     
  StoerSprung:=1; avgnumIst:=1; avgnumPInc:=1; // demo, no data smoothing.
  PID_DetPara(LOG_INFO,_tl,idxa,idxe,avgnumIst,avgnumPInc,PID_loctusec,PID_locistval,PID_locsollval,StoerSprung,timadj,PID_Det,true,''); 
  PID_Det.PIDMethod:=PID_ZiegNich;
  PID_GetPara(LOG_INFO,PID_Det,K,'');
  writeln('PID_TestSim Kp:',K[iKp]:0:2,' Ki:',K[iKi]:0:2,' Kd:',K[iKd]:0:2);
//  Kp:=1.1;  Ki:=0.2;  Kd:=0.1;	// Kp=1.1,Ki=0.2,Kd=0.1; //   Kp:=1; Ki:=0; Kd:=0.5;
  PID_Init(pid1,1,500,false,-25,25,0,1000000,K,
  	PID_Vector(-1.25,1.25,1000),
  	PID_Vector(PID_twiddleSavAtTolScal_c*PID_twiddle_tolerance,PID_twiddle_tolerance,0));
  PID_SimCSV(_tl,PID_Det,pid1);
  ShowStringList(_tl); 
  _tl.free;
end; 

procedure PID_TestSim2(fil,fusr,fgrp:string);
// call it: PID_TestSim2('./pid.csv','www-data','www-data');
// https://www.hs-koblenz.de/maschinenbau/laboratorien/regelungstechnik
// testing/comparing PID_Calc with simulation Versuch 3 (lab experiment3)
// result: with same paras, PID_Calc produces exact same output compared to PIDout1 Versuch3
const dt=0.01; // Zeitschritt 10ms
	  walt=3.0; wneu=7.0; PT=3;
	  yoffs=wneu-walt;
	  myKs=0.75; Tt=2.0; T=4.0; nk=5;
	  myKp=0.8; myTn=10.0;
	  useDataSet=3;	// 3: uses pid profile of Versuch3 // 0: auto calc pid profile
var i,idTt,arrlgt,arrlgt1:longint; Ks,Kp,Tn:PID_Float_t; sh:string;
	w,y,x,y2,y2d,xh1,xh2,xh3,ap,ai,ad: array of real;
	smpltim_us:int64;
	PID_Det:PID_Det_t; K:PID_array_t;
	pid1:PID_Struct_t;
	f:text;
	
  function gs(n:longint):string;
  begin
    gs:=Num2Str(dt*n,0,nk)+','+ Num2Str(w[n],0,nk)+','+
    	Num2Str(y[n],0,nk)+','+ Num2Str(x[n],0,nk)+','+
    	Num2Str(y2[n],0,nk)+','+Num2Str(y2d[n]-yoffs,0,nk)+','+
    	Num2Str(ap[n],0,nk)+','+Num2Str(ai[n],0,nk)+','+Num2Str(ad[n],0,nk);
  end;
  
begin
  smpltim_us:=round(dt*1000000);	// in microsec (us)
//determine pid paras
  if (useDataSet<>3) then
  begin // try to determine pid paras by PID_GetPara
  	PID_Det:=PID_DetCreate(PI_Default,myKS,Tt,T,dt,smpltim_us);
  	PID_GetPara(LOG_WARNING,PID_Det,K,'PID_TestSim');
//	K:=PID_Vector(K[iKp]/2,K[iKi]/2,K[iKd]); // will produce 50% better result then hard coded pid paras
  	Ks:=PID_Det.Ks;
  	Kp:=K[iKp];
  	Tn:=Kp/K[iKi];
  end
  else
  begin // useDataSet=3 use hard coded pid paras from Versuch3 and adjust to PID_Calc K[iKp/iKi] array
    Ks:=myKs;
  	Kp:=myKp;
  	Tn:=myTn;
    K:=PID_Vector(Kp,Kp/Tn,0); // K: datastruct to provide PID_Calc Kp and Tn via K[iKp] 
  end;
  
  writeln(PID_VectorStr(K, 0,nk));
  PID_Init(pid1,smpltim_us,K);
  pid1.PID_ovr:=true;
//PID_SetMinMaxLimit(pid1,-10,10);

  iDTt:=round(Tt / dt);
  arrlgt1:=iDTt; 
  arrlgt:=80*arrlgt1;

  SetLength(w,  arrlgt); SetLength(y,  arrlgt); SetLength(x,  arrlgt);
  SetLength(y2, arrlgt); SetLength(y2d,arrlgt);
  SetLength(xh1,arrlgt); SetLength(xh2,arrlgt); SetLength(xh3,arrlgt); 
  SetLength(ap, arrlgt); SetLength(ai, arrlgt); SetLength(ad, arrlgt); 
  
  assign(f,fil);
  rewrite(f); // writing result to .csv file, which can be viewed e.g. dygraph...
  writeln(f,'t,w,y,x,PID_Calc,deltaY,p,i,d');
   
  for i:= 0 to (arrlgt-1) do
  begin
    if (i<arrlgt1) then w[i]:=walt else w[i]:=wneu;	// Sollwertverlauf
	x[i]:=  walt; 
    y[i]:=  walt/Ks; y2[i]:=0; 		y2d[i]:=yoffs;
	xh1[i]:=walt;    xh2[i]:=walt; 	xh3[i]:=walt;
	ap[i]:=  0;		 ai[i]:=  0;	ad[i]:=  0;
	
	if (i<arrlgt1) then writeln(f,gs(i));
  end;
  
  i:=arrlgt1;
  while (i<arrlgt-1) do
  begin
	y[i]:= y[i-1]+ Kp * ((1 + dt / Tn) * (w[i] - x[i]) - (w[i-1] - x[i-1])); // PIDout1
	
    PID_Calc(pid1,w[i],x[i],false);	
    with pid1 do
    begin
      y2[i]:=PID_ControlOut;	// PIDout2, for comparison with PIDout1
      ap[i]:=PID_pid[iKp];		// p value
      ai[i]:=PID_pid[iKi];		// i value
      ad[i]:=PID_pid[iKd];		// d value
    end;
    
    y2d[i]:=y[i]-y2[i];			// compare algos, calc delta between y and y2

	writeln(f,gs(i));

	inc(i);
    
//	generate input value (response value) for both PID algos
	xh1[i]:=xh1[i-1] + dt / T * (Ks * y2[i-idTt] - xh1[i-1]); 	// PT1 + Tt
	xh2[i]:=xh2[i-1] + dt / T * (xh1[i-1] - xh2[i-1]);			// PT1
	xh3[i]:=xh3[i-1] + dt / T * (xh2[i-1] - xh3[i-1]);			// PT1
	
	case PT of
	  1:   x[i]:=xh1[i];		// Regelstrecke PT1
	  else x[i]:=xh3[i];		// Regelstrecke PT3
	end; // case
	
  end; // while
  
  close(f); 
  LNX_chowngrp(fil,fusr,fgrp);
  
  SetLength(w,  0); SetLength(y,  0); SetLength(x,  0); SetLength(y2, 0);
  SetLength(xh1,0); SetLength(xh2,0); SetLength(xh3,0); SetLength(y2d,0);
  SetLength(ap, 0); SetLength(ai, 0); SetLength(ad, 0); 
end;

function  CL_Compose(cmdLine:string):string;	
//inspired by Wolverrum
  function  _AddQuotes(str:string):string;
  var sh:string;
  begin
    if Pos(' ',str)>0 then sh:=Format('"%s"',[str]) else sh:=str;
    _AddQuotes:=sh;
  end;
  
var i:longword; sh:string;
begin
  sh:='';
  if Length(cmdLine)=0 then
  begin
    for i:= 1 to ParamCount() do
    begin
      if sh='' 	then sh:=_AddQuotes(ParamStr(i))
            	else sh:=Format('%s %s',[sh,_AddQuotes(ParamStr(i))]);
    end;
  end else sh:=cmdLine;
  CL_Compose:=sh;
end;

function  CL_Parse(cmdLine:string):t_CLOptions;	// Posix CommandLine Parser
// inspired by Wolverrum
const
  _SpaceChars = [#$20,#$09,#$0D,#$0A];
  _EqChars    = [':','='];
  _QChars     = ['''','"'];

  procedure _SkipSpace(var str:string; var i:longword);
  begin while cmdLine[i] IN _SpaceChars do inc(i) end;

  function  _Getstring (var str:string; var i:longword):string;
  var chPos:longword; sh:string;
  begin
    chPos:=i+1;
    while (str[chPos]<>str[i]) AND (chPos<=Length(str)) do inc(chPos);
    sh:=copy(str,i+1,chPos-i-1);
    if str[i]<>str[chPos] then 
      Log_Writeln(Log_ERROR,Format('CL_Parse: string {%c}[[ %s ]]{%c} must be have quote on the end',[str[i],sh,str[chPos]]));
    i:=chPos+1;
    _Getstring:=sh;
  end;

  function  _GetValue(var str:string; var i:longword):string;
  var chPos:longword; sh:string;
  begin
    chPos:=i;
    while (NOT (str[chpos] IN _SpaceChars)) AND (chPos<=Length(str)) do inc(chPos);
    sh:=copy(str,i,chPos-i);
    i:=chPos;
    _GetValue:=sh;
  end;

  function  _GetOptionName(var str:string; var i:longword):string;
  var chBeg,chend:longword; sh:string;
  begin
    if str[i+1]='-' then chBeg:=i+2 else chBeg:=i+1;
    chend:=chBeg;
    while (chend<=Length(str)) AND (NOT (str[chend] IN (_EqChars+_SpaceChars))) do inc(chend);
    sh:=copy(str,chBeg,chend-chBeg);
    i:=chend;
    _GetOptionName:=sh;
  end;

  function  _GetOptionValue(var str:string; var i:longword):string;
  var chPos:longword; sh:string;
  begin
    sh:=''; chPos:=i;
    if (i<Length(str)) then
    begin
	  if str[i] IN _EqChars then 
      begin
      	chPos:=i+1;
      	if str[i+1] IN _QChars	then sh:=_Getstring(str,chPos) 
      						 	else sh:=_GetValue (str,chPos);
      end;
      i:=chPos;
    end;
    _GetOptionValue:=sh;
  end;
  
var i,pPos:longword; _CLO:t_CLOptions;
begin
  try
	pPos:=0; i:=1; SetLength(_CLO,0);
  	while i<Length(cmdLine) do 
  	begin
      _SkipSpace(cmdLine,i);
      case cmdLine[i] OF
    	'''','"': begin
            	  	inc(pPos);
				  	SetLength(_CLO,Length(_CLO)+1);
				  	with _CLO[Length(_CLO)-1] do
				  	begin
				      Name:= Format('%d',[pPos]);
				      Value:=_Getstring(cmdLine,i);
				  	end;
				  end;
    	'-','/':  begin
				  	SetLength(_CLO,Length(_CLO)+1);
				  	with _CLO[Length(_CLO)-1] do
				  	begin
					  Name:= _GetOptionName (cmdLine,i);
					  Value:=_GetOptionValue(cmdLine,i);
				  	end;
          		  end;
    	else	  begin
				  	inc(pPos); 
				  	SetLength(_CLO,Length(_CLO)+1);
				  	with _CLO[Length(_CLO)-1] do 
				  	begin
					  Name:= Format('%d',[pPos]);
					  Value:=_GetValue(cmdLine,i);
            	  	end;
          		  end;
      end; // case
  	end; // while
  except
	SetLength(_CLO,0);
  end;
  CL_Parse:=_CLO;
end;

function  CL_OptGiven(var cl_opts:t_CLOptions; opt:string):integer;
// returns index. if index is >=0, then 'opt' was given 
var idx,i:integer;
begin
  try
	idx:=-1; i:=1;
  	while (i<=Length(cl_opts)) do
  	begin
      if (opt=cl_opts[i-1].Name) then begin idx:=i-1; i:=Length(cl_opts); end;
      inc(i);
  	end; // while
  except
	idx:=-1;
  end;
  CL_OptGiven:=idx;	
end;

procedure CL_Test;	// CommandLine Parser Test
var i:integer; opts:t_CLOptions; sh:string;
begin
  sh:='-oabc -h --def="ijk lmno" eben abc -k "klm xyz" --help /? '; // simulates given commandline parameter
  writeln(sh); writeln;
//writeln(CL_Compose(sh)); writeln;
  opts:=CL_Parse(sh);
  
  for i:= 1 to Length(opts) do
  begin
    writeln(i,'.:',opts[i-1].Name,'=',opts[i-1].Value);
  end;
  writeln;
  
  i:=CL_OptGiven(opts,'def');
  if i>=0 then writeln('given option "',opts[i].Name,'" with value "',opts[i].Value,'"');
  writeln('is help option given?: ',(CL_OptGiven(opts,'help')>=0) or (CL_OptGiven(opts,'?')>=0));
end;
 
procedure RPI_hal_exit;
begin
//writeln('Exit unit RPI_hal+');  
  if (ExitCode<>0) then 
  begin
	DUMP_CallStack('rpi_hal['+Num2Str(ExitCode,0)+']:');
	if ExitCode=217 then LOG_Writeln(LOG_ERROR,'RPI_hal_exit: maybe RPI_hal was not initialized, check usage of RPI_HW_Start');
  end;  
  
  if RPI_platform_ok then
  begin
    TRIG_End(-1); 
    ENC_End(-1);
	SERVO_End(-1);
	ERR_END(-1);
    SPI_Bus_Close_All;
    I2C_Close_All;
    RPI_FW_close;
    MMAP_end;
  end;
//RPI_TempSaveLimits(RPI_Temps,ApplicationName);
//writeln('Exit unit RPI_hal-');
  TEMP_Free(RPI_Temps);
  BIOS_EndIniFile;
  RpiMaintCmd.free;
  if (wdog.Hndl>=0) then 
  begin
//	SAY(LOG_WARNING,'LNX_WDOG['+Num2Str(wdog.Hndl,0)+']: do not forget to close WDOG with LNX_WDOG(0) at end of your application');
	LNX_WDOG(WDOG_Close);	// DISABLE&close WDOG device
  end;
  if _OnExitShowRuntime then SAY(LOG_INFO,LOG_GetEndMsg(''));
  MSG_HUB_ptr:=nil; CURL_ProgressUpdateHook_ptr:=nil; RPI_SignalHandlerHook_ptr:=nil;
  LOG_LevelColor(false);
  SetLength(CLOptions,0);
//say(log_info,'RPI_hal_exit-')
end;

procedure RPI_SignalHandlerErrExit(errno:longint);
begin
  LOG_Writeln(LOG_ERROR,'RPI_SignalHandlerErrExit['+Num2Str(errno,0)+']: '+LNX_ErrDesc(errno));
end;

procedure RPI_SignalHandler(sig:cint); cdecl;
// example signal handler
begin
  LOG_Writeln(LOG_ERROR,'RPI_SignalHandler: receiving signal: '+Num2Str(sig,0));
  case sig of
	SIGUSR1:begin	// set errorlevel from external e.g. kill -USR1 <pid>
			  LOG_SAY_Level($33); // LOG_Level(LOG_INFO); SAY_Level(LOG_INFO); 
			end;
	SIGUSR2:begin	// set errorlevel from external e.g. kill -USR2 <pid>
			  LOG_SAY_Level($22); // LOG_Level(LOG_WARNING); SAY_Level(LOG_WARNING); 
			end;
	SIGTERM,SIGINT,
	SIGHUP:	begin
			  terminateProg:=true;
			end;
	else 	begin
			  LOG_WRITELN(LOG_WARNING,'RPI_SignalHandler: unregistered signal ('+Num2Str(sig,0)+'), set variable terminateProg');
			  terminateProg:=true;
			end;
  end; // case
end;

procedure RPI_intSignalHandler(sig:cint); cdecl;
begin if (RPI_SignalHandlerHook_ptr<>nil) then RPI_SignalHandlerHook_ptr(sig); end;

function  RPI_Init_Allowed:boolean;
var ok:boolean; i:longint;
begin
  ok:=false;
  for i:=1 to ParamCount do if Upper(ParamStr(i))='-RPIHAL=HWINIT' then ok:=true;  
  RPI_Init_Allowed:=ok;
end;

function  RPI_HW_Start(initpart:s_initpart; p1,p2:string):boolean;
var ok,gpio_only:boolean; _flgtodo:s_initpart; sh:string; // j:t_initpart;
begin
  ok:=true; _flgtodo:=initpart; RPI_HW_initpart:=initpart;
//for j IN initpart do SAY(LOG_WARNING,GetEnumName(TypeInfo(t_initpart),Ord(j)));

  if (OSGetIPinfos IN RPI_HW_initpart) then 
  begin
    _flgtodo:=_flgtodo-[OSGetIPinfos];
    IPInfo_GetOS;
  end;
  
  if (InitOnExitShowRuntime 	IN RPI_HW_initpart) then 
  begin
    _flgtodo:=_flgtodo-[InitOnExitShowRuntime];
    _OnExitShowRuntime:=true;
  end;
  
  if (InitCertServer			IN RPI_HW_initpart) then 
  begin
	_flgtodo:=_flgtodo-[InitCertServer];
	if (not CertPack[CertPackServer].ok) then
	begin // just start it, if not already started
	  ok:=LNX_CertStartPack(
	  		CertPack[CertPackServer],
  			'ServerCert',
  			cert1_crtORpem_c,
  			cert1_key_c,
  			PrepFilePath(cert_crt_dir_c),
  			cert1_combined_c,
  			p2,CT_ssl );
	  if ok then
	  begin
  	  	if not CertPack[CertPackRPIMaint].ok then 
  	  	  CertPack[CertPackRPIMaint]:=CertPack[CertPackServer];
  	 	LNX_CertPackShow(LOG_INFO,CertPack[CertPackServer]);
  	  end; // else LOG_Writeln(LOG_ERROR,'LNX_CertStartPack: can not start cert pack '+CertPack[CertPackServer].desc);
	end;
  end;
  
  if (InitCertLetsEncrypt		IN RPI_HW_initpart) then 
  begin
    _flgtodo:=_flgtodo-[InitCertLetsEncrypt];
	if (not CertPack[CertPackLetsEncrypt].ok) then
	begin // just start it, if not already started, para = domain
	  if (p1<>'') then 
	  begin
	  	sh:=letsencryptdir_c+'/'+p1;
	  	ok:=LNX_CertStartPack(
	  		CertPack[CertPackLetsEncrypt],
  				'Lets Encrypt ('+p1+')',
  				PrepFilePath(sh+'/fullchain.pem'),	// PrepFilePath(sh+'/cert.pem'),
  				PrepFilePath(sh+'/privkey.pem'),
  				PrepFilePath(sh+'/fullchain.pem'),	// PrepFilePath(sh+'/chain.pem'),
  				PrepFilePath(sh+'/combined.pem'),
  				p2,CT_ssl );
	  	if ok then
	  	begin
  	  	  if not CertPack[CertPackRPIMaint].ok then 
  	  	  	CertPack[CertPackRPIMaint]:=CertPack[CertPackLetsEncrypt];
  	 	  LNX_CertPackShow(LOG_INFO,CertPack[CertPackLetsEncrypt]);
  	 	end; // else LOG_Writeln(LOG_ERROR,'LNX_CertStartPack: can not start cert pack '+CertPack[CertPackLetsEncrypt].desc);
  	  end else LOG_Writeln(LOG_ERROR,'LNX_CertStartPack: Lets Encrypt, missing domain name');
	end;
  end;
  
  if (InitCertSnakeOil			IN RPI_HW_initpart) then 
  begin
    _flgtodo:=_flgtodo-[InitCertSnakeOil];
	if (not CertPack[CertPackSnakeOil].ok) then
	begin // just start it, if not already started
	  ok:=LNX_CertStartPack(
	  		CertPack[CertPackSnakeOil],
  			'snakeoil (self signed)',
  			cert0_crtORpem_c,
  			cert0_key_c,
  			cert0_crtORpem_c,	// PrepFilePath(cert_crt_dir_c),
  			cert0_combined_c,
  			p2,CT_ssl );
	  if ok then
	  begin
  	  	if not CertPack[CertPackRPIMaint].ok then 
  	  	  CertPack[CertPackRPIMaint]:=CertPack[CertPackSnakeOil];
  	 	LNX_CertPackShow(LOG_INFO,CertPack[CertPackSnakeOil]);
  	  end else LOG_Writeln(LOG_ERROR,'LNX_CertStartPack: can not start cert pack '+CertPack[CertPackSnakeOil].desc);
	end;
  end;
  
  if ok and (UPDAuthDBDateTime	IN RPI_HW_initpart) then 
  begin
	_flgtodo:=_flgtodo-[UPDAuthDBDateTime];
	{$IFDEF UNIX} 
	  LNX_UsrAuthModDateTime:=GetFileAge(LNX_ShadowFile);
	{$ENDIF}
  end;
  
  if (InstSignalHandler	IN RPI_HW_initpart) then 
  begin
	_flgtodo:=_flgtodo-[InstSignalHandler];
	{$IFDEF UNIX} 
  	  new(na); new(oa); terminateProg:=false;
  	  na^.sa_Handler:=SigActionHandler(@RPI_intSignalHandler);
  	  fillchar(na^.Sa_Mask,sizeof(na^.sa_mask),#0);
  	  na^.Sa_Flags:=0;
	  {$ifdef Linux}               // Linux specific
	  	na^.Sa_Restorer:=nil;
	  {$endif}
	  if (fpSigAction(SIGALRM,na,oa)<>0) then RPI_SignalHandlerErrExit(fpgeterrno);
	  if (fpSigAction(SIGHUP, na,oa)<>0) then RPI_SignalHandlerErrExit(fpgeterrno);
	  if (fpSigAction(SIGTERM,na,oa)<>0) then RPI_SignalHandlerErrExit(fpgeterrno);
	  if (fpSigAction(SIGINT, na,oa)<>0) then RPI_SignalHandlerErrExit(fpgeterrno);
	  if (fpSigAction(SIGUSR1,na,oa)<>0) then RPI_SignalHandlerErrExit(fpgeterrno);
	  if (fpSigAction(SIGUSR2,na,oa)<>0) then RPI_SignalHandlerErrExit(fpgeterrno);
	{$ENDIF}
  end;
  
  if (InitWDOG IN RPI_HW_initpart) or (InitWDOGnoThread IN RPI_HW_initpart) then
  begin
	{$IFDEF UNIX} 
  	  _flgtodo:=_flgtodo-[InitWDOG];
      LNX_WDOG_Init(wdog);
	  if LNX_WDOG_Start then 
		begin
	  	LNX_WDOG(WDOG_GSup);	 	// WDIOC_GETSUPPORT
	  	LNX_WDOG(WDOG_STO);			// Set timeout to default (15 sec)
	  	LNX_WDOG(WDOG_BSTAT);	 	// Get last boot stat
	  	if not (InitWDOGnoThread	IN RPI_HW_initpart)
	  	  then Thread_Start(wdog.ThreadCtrl,@LNX_WDOG_Thread,nil,0,0)
	  	  else _flgtodo:=_flgtodo-[InitWDOGnoThread];							
	  end else LOG_Writeln(LOG_ERROR,'WDOG: can not init');
	{$ELSE}
	  _flgtodo:=_flgtodo-[InitWDOG,InitWDOGnoThread];
	{$ENDIF}
  end;
  		
//rpi HW dependent:
  if (_flgtodo<>[]) then
  begin
	ok:=RPI_platform_ok;  gpio_only:=false; 
(*if (InitGPIOonly IN RPI_HW_initpart) then 
  begin // not supported, does not work on rpi3
    RPI_HW_initpart:=[InitGPIO]; gpio_only:=true;
    if (StartShutDownWatcher 	IN initpart) then RPI_HW_initpart:=RPI_HW_initpart+[StartShutDownWatcher];
  end; *)
  
    if ok and (InitCreateScript IN RPI_HW_initpart) then
    begin
	  _flgtodo:=_flgtodo-[InitCreateScript];
	  {$IFDEF UNIX} 
    	GPIO_create_int_script(int_filn_c); // no need for it. Just for convenience 
      {$ENDIF} 
    end;

  	if ok and (InitRPIfw 		IN RPI_HW_initpart) then 
  	begin
  	  _flgtodo:=_flgtodo-[InitRPIfw];
      RPI_FW_open;
      if not RPI_FW_Info(TAG_STATUS_REQUEST,TAG_GET_FIRMWARE_REVISION,cpu_fw) then cpu_fw:='';
	end;
  
  	if (InitI2C IN RPI_HW_initpart) or (InitSPI IN RPI_HW_initpart) 
      then RPI_HW_initpart:=RPI_HW_initpart+[InitGPIO]; // GPIO is mandatory
    
  	if ok and (InitGPIO 			IN RPI_HW_initpart) or 
  	  (StartShutDownWatcher 		IN RPI_HW_initpart) then 
  	begin
  	  _flgtodo:=_flgtodo-[InitGPIO];
  	  ok:=(MMAP_start(gpio_only)=0);
  	end;

  	if ok and (InitI2C				IN RPI_HW_initpart) then
  	begin 
  	  _flgtodo:=_flgtodo-[InitI2C];
      ok:=(not restrict2gpio);
      if ok then I2C_Start else Log_Writeln(Log_ERROR,'RPI_HW_Start: can not start I2C, try with sudo');
  	end;

  	if ok and (InitSPI				IN RPI_HW_initpart) then 
  	begin
  	  _flgtodo:=_flgtodo-[InitSPI];
      ok:=(not restrict2gpio);
      if ok then SPI_Start else Log_Writeln(Log_ERROR,'RPI_HW_Start: can not start SPI, try with sudo');
  	end;
    
  	if ok and (StartShutDownWatcher IN RPI_HW_initpart) then 
  	begin
  	  _flgtodo:=_flgtodo-[StartShutDownWatcher];
  	  ok:=RPI_ShutDownStart;
  	end;
      
  	if not ok then
  	begin
      if not RPI_run_on_known_hw 
      	then Log_Writeln(Log_ERROR,'RPI_hal: not running on supported rpi HW');
//	  	else Log_Writeln(Log_ERROR,'RPI_hal: supported min-/maximum kernel #'+Num2Str(supminkrnl,0)+' - #'+Num2Str(supmaxkrnl,0)+' ( uname -a )');

      if (InitHaltOnError 			IN RPI_HW_initpart) then 
	  begin
	  	_flgtodo:=_flgtodo-[InitHaltOnError];
//      LOG_Writeln(LOG_ERROR,'RPI_hal: can not initialize MemoryMap.');
//	    Halt(1);
      end;
	end;
  end;

  RPI_HW_Start:=ok;
end;
function  RPI_HW_Start(initpart:s_initpart):boolean; begin RPI_HW_Start:=RPI_HW_Start(initpart,'',''); end;

function  RPI_HW_Start:boolean; 
begin 
  RPI_HW_Start:=RPI_HW_Start([InitHaltOnError,InitRPIfw,InitGPIO,InitI2C,InitSPI,UPDAuthDBDateTime]);
end;

procedure inivar;
var i,j:integer; b:byte; sh:string;
begin
//i:=0; i:=4 div i;
  RPI_ProgramStartTime:=now; 	_OnExitShowRuntime:=false;
  try
	call_external_prog(LOG_NONE,'uptime -s',sh);	// 2019-07-03 09:05:57 
	if not Str2DateTime(sh,4,RPI_BootTime)
	  then RPI_BootTime:=RPI_ProgramStartTime; 
  except
	RPI_BootTime:=RPI_ProgramStartTime; 
  end;
  terminateProg:=false;			
  LNX_sudo(false);
  MSG_HUB_ptr:=nil;				CURL_ProgressUpdateHook_ptr:=nil;
  RPI_SignalHandlerHook_ptr:=	@RPI_SignalHandler;
  rpi_fw_api.hndl:=-1; 			GPU_MEM_BASE:=0;
  
  sh:=''; for i:=1 to ParamCount do sh:=sh+ParamStr(i)+' ';
  LOG_LevelColor(true);
  LOG_SAY_Level($32); // SAY_Level(LOG_INFO); LOG_Level(LOG_Warning); // default
  CLOptions:=CL_Parse(Trimme(sh,3));
  if (CL_OptGiven(CLOptions,'v-')>=0)	then LOG_SAY_Level($00);	// -v-
  i:=CL_OptGiven(CLOptions,'v');
  if (i>=0) then
  begin
//	Str2Num(CLOptions[i].Value,b); writeln(i,' val=',CLOptions[i].Value,':b:',b);
	if Str2Num(CLOptions[i].Value,b)
	  then LOG_SAY_Level(b)											// -v=0x02
	  else LOG_SAY_Level($11);										// -v
  end;
  if (CL_OptGiven(CLOptions,'vv')>=0)	then LOG_SAY_Level($22);	// -vv
  if (CL_OptGiven(CLOptions,'vvv')>=0)	then LOG_SAY_Level($33);	// -vvv
  if (CL_OptGiven(CLOptions,'vvvv')>=0)	then LOG_SAY_Level($44);	// -vvvv
  
  SD_speedRD:=noData_c;
  MD5Hash4emptyString:=HashTag('');
  
  IPInfos_Init(IP_Infos);
  
  with IniFileDesc do begin inifilename:=''; ok:=false; end;
 
  BIOS_ReadIniFile(PrepFilePath(AppDataDir_c+'/'+ApplicationName+'/'+ApplicationName+'.ini'));
  BIOS_SetDfltFlags([]);
  BIOS_SetDfltSection(Upper(DfltSect_c));
  LOG_Level(Str2LogLvl(BIOS_GetIniString('LOGERRLVL','WARNING'))); 
  SAY_Level(Str2LogLvl(BIOS_GetIniString('LOGAPPLVL','INFO'))); 
//LOG_Level(LOG_Warning); 		
//SAY_Level(LOG_INFO);
  BIOS_SetDfltSection(Upper(ApplicationName));
  cpu_fw:='';
  RpiMaintCmd:=TIniFile.Create('');
  RPI_MaintSetVersions(0,0);	// disable VersionCheck@RPI_Maint PKGInstall
  TEMP_Create(RPI_Temps,'','CPUtemp','''C',2);
  RTC3231_LastTemp:=NaN; RTC3231_NextRead:=now;
  SetUTCOffset;  		// set _TZlocal 
  TimeZoneString(''); 	// set _TZstring e.g. Etc/UTC
  mem_fd:=-1; mmap_arr:=nil; cpu_rev_num:=0; GPIO_map_idx:=2; 
  
  eeprom_SetAddr(eeprom_devadr_c);
  for i:=0 to spi_max_bus do for j:=0 to spi_max_dev do spi_dev[i,j].spi_fd:=-1;
  if not clock_getres(CLOCK_REALTIME,@rpi_timespecresolution)=0 then
  begin
    rpi_timespecresolution.tv_nsec:=1;
    Log_Writeln(Log_ERROR,'Get_CPU_INFO_Init: can not get timeresolution');
  end;
  LNX_UsrAuthModDateTime:=0;
  LNX_WDOG_Init(wdog);
  for i:= CertPackRPIMaint to CertPackLast do LNX_CertInitPack(CertPack[i],i);
//LNX_CertInitPack(CertPackServer);
//LNX_CertInitPack(CertPackLetsEncrypt);
  {$IFDEF WINDOWS} SDcard_root_hdl:=3; {$ELSE} SDcard_root_hdl:=AddDisk('/'); {$ENDIF} 
  
  for i:=0 to max_EndLoop_c do SIG_EndLoop(i,false);
  
  USR_BreakSetFunc(@USRBreakFunc);
end;

begin
//writeln('Enter unit rpi_hal');
  AddExitProc(@RPI_hal_exit);
  try
	inivar;
  	Get_CPU_INFO_Init; 
//	RPI_ShutDownInit(-1);			// just init data struct, no HW-Pin
  	IO_Init_Const;
  	RPI_HW_initpart:=[];
  	if RPI_Init_Allowed then RPI_HW_Start;
//	writeln('Leave unit rpi_hal');
  except
	On E_rpi_hal_Exception :Exception do 
	  DUMP_ExceptionCallStack('rpi_hal:',E_rpi_hal_Exception);
  end;
end.
