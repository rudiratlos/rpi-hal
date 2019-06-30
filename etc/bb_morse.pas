unit bb_morse; // V5.1 // 2019-03-17
  {$H+}  // Ansistrings
Interface 
uses rpi_hal,typinfo,sysutils;  	 

procedure BB_OOK_PIN(state:boolean);
procedure BB_SetPin(gpio:longint); 
function  BB_GetPin:longint; 
procedure BB_SendCode(switch_type:T_PowerSwitch; adr,id,desc:string; ein:boolean);
procedure BB_InitPin(id:string); // e.g. id:'TLP434A' or id:'13'  (direct RPI Pin on HW Header P1 )
procedure MORSE_speed(speed:integer); // 1..5, -1=default_speed
procedure MORSE_tx(s:string);
procedure MORSE_test;
procedure ELRO_TEST;

implementation  

var 
  BB_pin:longint;
  MORSE_dit_lgt:word; 

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
	delay_msec(1);	
  end;
end;

procedure BB_SetPin(gpio:longint); 
begin 
  BB_pin:=gpio; 
  Log_Writeln(LOG_DEBUG,'BB_SetPin: '+Num2Str(BB_pin,0)); 
  if (BB_pin>0) then GPIO_set_OUTPUT(BB_pin); 
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
    writeln(cnt:2,'. EIN: '+id_c); LED_Status(true); BB_SendCode(ELRO,SystemCode_c+Unit_A_c,id_c,'ELRO Switch A, System-Code: ON  OFF OFF OFF ON   Unit-Code: ON  OFF OFF OFF OFF', true);  delay_msec(1500); LED_Status(false); 
	writeln(cnt:2,'. AUS: '+id_c); LED_Status(true); BB_SendCode(ELRO,SystemCode_c+Unit_A_c,id_c,'ELRO Switch A, System-Code: ON  OFF OFF OFF ON   Unit-Code: ON  OFF OFF OFF OFF', false); delay_msec(2000); LED_Status(false); 
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

begin
  BB_pin:=RPI_status_led_GPIO;
  MORSE_speed(-1);				// set to default speed 10WpM=50BpM	-> 120ms 
end.
