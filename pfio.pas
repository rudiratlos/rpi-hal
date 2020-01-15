unit pfio; 
  {$MODE OBJFPC}
  { $T+}
  {$R+} {$Q+}
  {$H+}  // Ansistrings
Interface 
uses rpi_hal;
const
  pfio_busnum_default	= 0; 
  pfio_devnum_default	= 1; // SPI Devicenumber for PiFace Board1  (Default)
//Port configuration for PIFace Board
  pfio_IODIRA=$00; 	// I/O direction A
  pfio_IODIRB=$01; 	// I/O direction B
  pfio_IOCON=$0A; 	// I/O config
  pfio_GPIOA=$12; 	// port A
  pfio_GPIOB=$13; 	// port B
  pfio_GPPUA=$0C; 	// port A pullups
  pfio_GPPUB=$0D; 	// port B pullups
  pfio_OUTPUT_PORT=pfio_GPIOA;
  pfio_INPUT_PORT= pfio_GPIOB;

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

implementation  
var OldExitProc : Pointer;
// PiFace routines
// code converted from C 2 pascal c-source:
// https://github.com/thomasmacpherson/piface/blob/master/c/src/piface/pfio.c
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
  {$warnings off} 
    if not avail_c then LOG_WRITELN(LOG_ERROR,'PiFace board not available or not initialized'); 
  {$warnings on} 
  pfio_avail:=avail_c; 
end;

function  pfio_SPI_Read (devadr:byte; reg:word):byte;
const SPI_READ_CMD=$41;
var b:byte;
begin
  b:=0;
  if devadr>$03 then Log_Writeln(LOG_ERROR,'pfio_spi_read: devadr '+HexStr(devadr,2)+' not valid')
  else
    begin
    if pfio_avail(devadr) then
    begin  
      spi_transfer(pfio_busnum_default,pfio_devnum_default, 
				   char(SPI_READ_CMD or (devadr shl 1))+char(byte(reg))+char($ff));
      b:=ord(spi_buf[pfio_busnum_default,pfio_devnum_default].buf[2]);
    end;
  end;
  pfio_SPI_Read:=b;
end;

procedure pfio_spi_write(devadr:byte; reg,data:word);
const SPI_WRITE_CMD=$40;
begin
  if devadr>$03 then Log_Writeln(LOG_ERROR,'pfio_spi_write: devadr '+HexStr(devadr,2)+' not valid')
                else if pfio_avail(devadr) then 
				spi_transfer(pfio_busnum_default,pfio_devnum_default, 
							 char(SPI_WRITE_CMD or (devadr shl 1))+
							 char(byte(reg))+char(byte(data)) );
end;

procedure pfio_showregs(devadr:byte);
begin
  writeln('IOCON  0x'+HexStr(pfio_spi_read(devadr, pfio_IOCON), 2));
  writeln('GPIOA  0x'+HexStr(pfio_spi_read(devadr, pfio_GPIOA), 2));
  writeln('IODIRA 0x'+HexStr(pfio_spi_read(devadr, pfio_IODIRA),2));
  writeln('IODIRB 0x'+HexStr(pfio_spi_read(devadr, pfio_IODIRB),2));
  writeln('GPPUB  0x'+HexStr(pfio_spi_read(devadr, pfio_GPPUB), 2));
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
    // to the desired mask, in this case pin_bit_mask.
    pfio_digital_read:=(current_pin_values and pin_bit_mask ) = pin_bit_mask;
end;

procedure pfio_digital_write(devadr,pin_number,value:byte);
var pin_bit_mask,old_pin_values,new_pin_values:byte;
begin
  pin_bit_mask:=  pfio_get_pin_bit_mask(pin_number);
  old_pin_values:=pfio_read_output(devadr);
  if (value > 0) then new_pin_values := old_pin_values or       pin_bit_mask
                 else new_pin_values := old_pin_values and (not pin_bit_mask);
//if (LOG_Get_Level>=LOG_DEBUG) then
  begin
    Log_Writeln(LOG_DEBUG,'digital_write: pin number '+HexStr(pin_number,2)+' value '+HexStr(value,2));
    Log_Writeln(LOG_DEBUG,'pin bit mask:   0x'+HexStr(pin_bit_mask,2));
    Log_Writeln(LOG_DEBUG,'old pin values: 0x'+HexStr(old_pin_values,2));
    Log_Writeln(LOG_DEBUG,'new pin values: 0x'+HexStr(new_pin_values,2));
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
	else LOG_WRITELN(LOG_ERROR,'pfio_RELAY: num '+HexStr(num,2)+' not valid');
  end;	
end;

procedure pfio_OUTPUT(devadr, num:byte; state:boolean);
begin
  case num of
     1..8 : pfio_write_output(devadr, SetBitINByte(pfio_read_output(devadr),num,state));
	else LOG_WRITELN(LOG_ERROR,'pfio_OUTPUT: num '+HexStr(num,2)+' not valid');
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
    write  ('Input port: 0x'+HexStr(b,2)); if b>0 then write(' Button pressed S'+Num2Str(pfio_button_pressed(b),0)); writeln;
	delay_msec(1000); // ms
  end;
end;

procedure pfio_test2(devadr:byte);
var cnt:word; 
begin
  writeln('Output test (runtime 20secs)');
  for cnt := 1 to 8 do begin writeln('OUTPUT ',cnt:0,' ON');  pfio_OUTPUT(devadr, cnt, an);  delay_msec(1000); end;
  for cnt := 1 to 8 do begin writeln('OUTPUT ',cnt:0,' OFF'); pfio_OUTPUT(devadr, cnt, aus); delay_msec(1000); end;
end;

procedure pfio_test3(devadr:byte);
var cnt,cnt1:word; 
begin
  writeln('Relay test (runtime 20secs)');
  for cnt1 := 1 to 5 do 
  begin 
    for cnt := 1 to 2 do 
    begin 
      writeln('Relay ',cnt:0,' ON');  pfio_RELAY(devadr, cnt, an);  delay_msec(1000); 
	  writeln('Relay ',cnt:0,' OFF'); pfio_RELAY(devadr, cnt, aus); delay_msec(1000); 
    end;
  end;
end;

procedure pfio_test4(devadr:byte);
const maxP_c=3; patterns:array[0..maxP_c] of byte = ($84, $48, $30, $48);                                      
var cnt,cnt1,cnt2:word; 
begin
  writeln('LED test (runtime infinite)');
  repeat
    for cnt1 := 1 to  2 do begin for cnt := 3 to 8 do begin pfio_OUTPUT(devadr, cnt, an); delay_msec(100); pfio_OUTPUT(devadr, cnt, aus); delay_msec(100); end; end;
	for cnt2 := 1 to 10 do begin for cnt1 := 0 to maxP_c do begin pfio_write_output(devadr, patterns[cnt1]); delay_msec(100); end; pfio_write_output(devadr, $00); end;
  until false;
end;

procedure pfio_test(devadr:byte);
begin
  pfio_test1(devadr);
  pfio_test2(devadr);
  pfio_test3(devadr);
  pfio_test4(devadr);
end;

procedure pfio_exit;
begin
  if ExitCode<>0 then begin LOG_Writeln(LOG_ERROR,'pfio_exit: Exitcode: '+Num2Str(ExitCode,3)); end;
  ExitProc:=OldExitProc;
end;

begin
  OldExitProc:=ExitProc;  ExitProc:=@pfio_exit;
end.
