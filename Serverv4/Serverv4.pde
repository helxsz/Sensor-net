//https://github.com/thiseldo/EtherCardExamples/blob/master/EtherCard_RESTduino/EtherCard_RESTduino.ino
// https://github.com/openenergymonitor/NanodeRF/blob/master/NanodeRF_singleCT_RTCrelay_GLCDtemp/NanodeRF_singleCT_RTCrelay_GLCDtemp.ino
#include <Ports.h>
#include <RF12.h>
#include <JeeLib.h>
#include <avr/pgmspace.h>

#include <SPI.h>
#include <SRAM9.h>
typedef struct {
    //byte deviceType;
    //long last;  /* 4 byte */
    char id[10];             /* id */
    //int value[8];                 /* e.g. 12.75 per hour */    
    char type[15];              /* id */
    //char vendor[10];
}Sensor;
Sensor sensor;

#define type_sensor 0;
#define type_actuator 1;

int INDEX_SENSOR_LENGTH=500;
int INDEX_ACTUATOR_LENGTH=501;
int LIST_SENSOR_BEGIN = 2000;
int LIST_ACTUATOR_BEGIN = 12000;
int QUEUE_BEGIN = 20000;
////////////////////////////////////////////
#include <avr/eeprom.h>
#define CONFIG_EEPROM_ADDR ((byte*) 0x10)

// configuration, as stored in EEPROM
struct Config {
    byte band;
    byte group;
    byte valid; // keep this as last byte
} config;

static void loadConfig() {
    for (byte i = 0; i < sizeof config; ++i)
        ((byte*) &config)[i] = eeprom_read_byte(CONFIG_EEPROM_ADDR + i);
    if (config.valid != 253) {
        config.valid = 253;
        config.band = 8;
        config.group = 1;
    }
    byte freq = config.band == 4 ? RF12_433MHZ :
                config.band == 8 ? RF12_868MHZ :
                                   RF12_915MHZ;
}

static void saveConfig() {
    for (byte i = 0; i < sizeof config; ++i)
        eeprom_write_byte(CONFIG_EEPROM_ADDR + i, ((byte*) &config)[i]);
}


////////////////////////////////////////////
#include <avr/pgmspace.h>
prog_char type_temp[] PROGMEM = "http://webinos.org/api/sensors.temperature";   // "String 0" etc are strings to store - change to suit.
prog_char type_hum[] PROGMEM = "http://webinos.org/api/sensors.humidity";
prog_char type_light[] PROGMEM = "http://webinos.org/api/sensors.light";
prog_char type_volt[] PROGMEM = "http://webinos.org/api/sensors.voltage";
prog_char type_elec[] PROGMEM = "http://webinos.org/api/sensors.electrcity";

PROGMEM const char *string_table[] = 	   // change "string_table" name to suit
{   
  type_temp,
  type_hum,
  type_light,
  type_volt,
  type_elec 
};
#define s_temp 1;
#define s_hum 2;
#define s_light 3;
#define s_volt 4;
#define s_elec 5;
////////////////////////////////////////////
#define MYNODE 1            
#define freq RF12_868MHZ      // frequency
#define group 1            // network group
//---------------------------------------------------
// Data structures for transfering data between units
//---------------------------------------------------
typedef struct { 
               int temperature, humidity;
               char mac[15]; 
} PayloadTX;


PayloadTX emontx;    


//---------------------------------------------------------------------
// The PacketBuffer class is used to generate the json string that is send via ethernet - JeeLabs
//---------------------------------------------------------------------



//--------------------------------------------------------------------------
// Ethernet
//--------------------------------------------------------------------------
#include <EtherCard.h>
#include <NanodeUNIO.h>

// ethernet interface mac address
static byte mymac[] = { 0x74,0x69,0x69,0x2D,0x30,0x31 };
// ethernet interface ip address
static byte myip[] = { 192,168,210,203 };
// gateway ip address
static byte gwip[] = { 192,168,210,1 };
// remote website ip address and port
static byte hisip[] = { 74,125,79,99 };
// remote website name
char website[] PROGMEM = "google.com";
#define APIKEY  "b872449aa3ba74458383a798b740a378"

// buffer 
byte Ethernet::buffer[300];   // a very small tcp/ip buffer is enough here
static BufferFiller bfill;  // used as cursor while filling the buffer
char line_buf[80];                        // Used to store line of http reply header

static uint32_t timer;/////////////////////



const byte redLED = 6;                     // NanodeRF RED indicator LED
const byte greenLED = 5;                   // NanodeRF GREEN indicator LED

byte ethernet_error = 0;                   // Etherent (controller/DHCP) error flag
byte rf_error = 0;                         // RF error flag - high when no data received 
byte ethernet_requests = 0;                // count ethernet requests without reply                 

byte dhcp_status = 0;
byte dns_status = 0;

byte emonglcd_rx = 0;                      // Used to indicate that emonglcd data is available
byte data_ready=0;                         // Used to signal that emontx data is ready to be sent
unsigned long last_rf;                    // Used to check for regular emontx data - otherwise error





// called when the client request is complete
static void my_result_cb (byte status, word off, word len) {
  //Serial.print("<<< reply ");Serial.print(millis() - timer);Serial.println(" ms");
  Serial.println("server reply");
  //
  //Serial.println((const char*) Ethernet::buffer + off);
}


uint16_t http200ok(void)
{
  bfill = ether.tcpOffset();
  bfill.emit_p(PSTR(
    "HTTP/1.0 200 OK\r\n"
    "Content-Type: text/html\r\n"
    "Pragma: no-cache\r\n"
    "\r\n"));
  return bfill.position();
}

uint16_t http404(void)
{
  bfill = ether.tcpOffset();
  bfill.emit_p(PSTR(
    "HTTP/1.0 404 OK\r\n"
    "Content-Type: text/html\r\n"
    "\r\n"));
  return bfill.position();
}

// prepare the webpage by writing the data to the tcp send buffer
uint16_t print_webpage()
{
  bfill = ether.tcpOffset();
  bfill.emit_p(PSTR(
    "HTTP/1.0 200 OK\r\n"
    "Content-Type: text/html\r\n"
    "Pragma: no-cache\r\n"
    "\r\n"
    "<html><body>Invalid option selected</body></html>"));
  return bfill.position();
}
     
void getMac()
{
  boolean r;
  NanodeUNIO unio(NANODE_MAC_DEVICE) ;
  r= unio.read(mymac, NANODE_MAC_ADDRESS, 6) ;
  if (r) Serial.println("success");
  else Serial.println("failure");
  sprintf(line_buf,"%02X:%02X:%02X:%02X:%02X:%02X",
          mymac[0],mymac[1],mymac[2],
          mymac[3],mymac[4],mymac[5]);
  //Serial.print("MAC address is ");
  Serial.println(line_buf);
}

void setup () {
 // config the leds 
 /* */
  Serial.begin(9600);  
  for (int i = 0; i < 5; i++)
  {
    strcpy_P(line_buf, (char*)pgm_read_word(&(string_table[i]))); // Necessary casts and dereferencing, just copy. 
    Serial.println( line_buf );
  } 
  
 testram();
 
 loadConfig();
 
 pinMode(redLED, OUTPUT);             
 pinMode(greenLED, OUTPUT);     
 delay(100);  
  
  if (ether.begin(sizeof Ethernet::buffer, mymac) == 0) 
    Serial.println( "Failed to access Ethernet controller");
    
    
    
 /*
  if (!ether.dhcpSetup())
    Serial.println("DHCP failed");

  ether.printIp("IP:  ", ether.myip);
  ether.printIp("GW:  ", ether.gwip);  
  ether.printIp("DNS: ", ether.dnsip);  
*/
  // get the mac address of this device
  getMac();  
  // config the ethernets
  ether.staticSetup(myip, gwip);
  //ether.copyIp(ether.hisip, hisip);
  
 /**/
  while (ether.clientWaitingGw())
    ether.packetLoop(ether.packetReceive());
  Serial.println("Gateway found");

  #if 1
  // use DNS to locate the IP address we want to ping
  if (!ether.dnsLookup(PSTR("www.abcd.com")))
    Serial.println("abcd DNS failed");
  #else
  ether.parseIp(ether.hisip, "192.168.210.5");  // doesn't know what it means
  #endif
  ether.printIp("Server: ", ether.hisip);
  ether.hisport = 80; 
  Serial.println(ether.hisip[0]);
  
  ether.hisip[0] = 192;
  ether.hisip[1] = 168;
  ether.hisip[2] = 210;
  ether.hisip[3] = 5;

 rf12_initialize(MYNODE, RF12_868MHZ, 1);   
 


 
}



void loop () {
  

  
  if (millis() > timer) {
    timer = millis() + 5000;
    Serial.print("polling   timers........................");
    Serial.println( freeRam ());
    
      
  }    
  
  // http://www.22balmoralroad.net/wordpress/wp-content/uploads/homeBase.pde
  if (rf12_recvDone() && rf12_crc == 0 )
  {
      //rf12_len == sizeof emontx
      /*
      Serial.print("rf12_hdr=");Serial.print(rf12_hdr,HEX);Serial.print("     ");
      Serial.print("RF12_HDR_DST=");Serial.print(rf12_hdr & RF12_HDR_DST,HEX);Serial.println("     ");
      Serial.print("RF12_HDR_CTL=");Serial.print(rf12_hdr & RF12_HDR_CTL,HEX);Serial.println("     "); // what it means
      //http://scurvyrat.com/2011/05/24/getting-the-nodeid-in-a-rf12-packet/
      int SenderID = (RF12_HDR_MASK & rf12_hdr);
      Serial.print("SENDID:");Serial.println(SenderID);Serial.print("     ");
      //http://www.22balmoralroad.net/wordpress/wp-content/uploads/homeBase.pde
      int node_id = (rf12_hdr & 0x1F);
      Serial.print("receiverID:");Serial.print( node_id );Serial.print("    "); 
       
       // http://talk.jeelabs.net/topic/727
      if (rf12_hdr == (RF12_HDR_DST | RF12_HDR_CTL | MYNODE)) // ?
      {
        //Serial.println("receiving something for this node");         
      }
      if ((rf12_hdr & RF12_HDR_CTL) == 0)
      {
        Serial.println("receiving something for this node"); 
      }else{
        Serial.println("receiving something for ANOTHER node"); 
      }  
          
      if(RF12_WANTS_ACK) //if they want an ACK packet  // http://evolveelectronics.tumblr.com/
      {
            Serial.println("want an ACK packet");
            rf12_sendStart(RF12_ACK_REPLY,0,0);
      }
      */
          /* 
    /////////////////////// PROBLEM ///////////////////////////////////////////
    /////////////////////////////////////////////////////////////////////////
      //// test resend the packet back  
      delay(5);
      rf12_sendStart( (RF12_HDR_ACK |RF12_HDR_DST | 18), &emontx, sizeof emontx);
      rf12_sendWait(2);   

    /////////////////////////////////////////////////////////////////////////
      */ 
    /*  http://www.22balmoralroad.net/wordpress/wp-content/uploads/homeBase.pde
    incNodeData = *(Payload*) rf12_data;
    incNodeType = incNodeData.type;
    switch(incNodeType) {
       case 1:
          incRoomNodeData = *(RoomNode*) incNodeData.data;
          sprintf(str,"{\"type\":%d,\"roomnode_ID\":%d,\"roomnode_light\":%d,\"roomnode_moved\":%d,\"roomnode_humi\":%d,\"roomnode_temp\":%d,\"roomnode_lobat\":%d}",incNodeType, incNodeID, incRoomNodeData.light,incRoomNodeData.moved,incRoomNodeData.humi,incRoomNodeData.temp,incRoomNodeData.lobat);
          break;
       case 2:
          incemonTXData = *(emonTX*) incNodeData.data;
          sprintf(str,"{\"type\":%d,\"emontx_ID\":%d,\"emontx_ctA\":%d,\"emontx_ctB\":%d,\"nPulse\":%d,\"emontx_temp1\":%d,\"emontx_temp2\":%d,\"emontx_temp3\":%d,\"emontx_V\":%d}",incNodeType, incNodeID,incemonTXData.ct1, incemonTXData.ct2, incemonTXData.nPulse, incemonTXData.temp1,incemonTXData.temp2,incemonTXData.temp3,incemonTXData.supplyV);
          break;
    } */        
    
    // Copy the received data into payload:
    memcpy(&emontx, (byte*) rf12_data, sizeof(emontx));

    // Flash LED:
    digitalWrite(6, HIGH);
    delay(100);
    digitalWrite(6, LOW);
    
    // Print it out:
    //Serial.print("Received: ");

    byte lenfth = rf12_len;
    Serial.print("temp:"); Serial.print(emontx.temperature);Serial.print("    "); 
    Serial.print("hum:"); Serial.print(emontx.humidity);Serial.print("    ");
    Serial.print("mac:"); Serial.println(emontx.mac);
    
    ///////////////////////////////////////////////////////////////////

    String temp_id = String(emontx.mac).substring(9,12)+"_temp";
    String hum_id = String(emontx.mac).substring(9,12)+"_hum";
   
    byte value[8];   
    
    //value[0] = emontx.humidity;
    hum_id.toCharArray(line_buf,20);
    
    if( !findDevice(0,line_buf) )
    {
      Serial.println("no hum sensor");
      storeDevice(0,line_buf,"humidity");
    }else{
      Serial.println("find hum sensor-");
    }
    /**/    
    
    //value[0] = emontx.temperature;
    temp_id.toCharArray(line_buf,20);
    /*    
    if( !findDevice(0,line_buf) )
    {
       Serial.println("not find temp sensor");
       storeDevice(0,line_buf,"temperature");
       
    }else{
      Serial.println("find tempe sensor  ---");
    } 
    */
       /*  */
    //////////////////////////////////////////////////////////////////////////
    //Serial.println(millis()-last_rf);
    last_rf = millis();     
    
    data_ready = 1;                                                // data is ready
    rf_error = 0;
    
    sprintf(line_buf,"{\'temperature\':%d,\'humidity\':%d}", emontx.temperature,emontx.humidity);  
    Serial.println(line_buf); 
    ether.browseUrl(PSTR("/test?apikey="APIKEY"&data="), line_buf, NULL, my_result_cb);     
    
   }  
    
 /**/
    uint16_t  dat_p;

    // read packet, handle ping and wait for a tcp packet:
    dat_p=ether.packetLoop(ether.packetReceive());

   
    if(dat_p==0){
      // no http request
      return;
    }

    // tcp port 80 begin
    if (strncmp("GET ",(char *)&(Ethernet::buffer[dat_p]),4)!=0){
      // head, post and other methods:
      dat_p = print_webpage();
      goto SENDTCP;
    }

    // just one web page in the "root directory" of the web server
    if (strncmp("/ ",(char *)&(Ethernet::buffer[dat_p+4]),2)==0){
    #ifdef DEBUG
      //Serial.println("GET / request");
    #endif
      dat_p = print_webpage();
      goto SENDTCP;
    }
    dat_p = process_request((char *)&(Ethernet::buffer[dat_p+4]));
    
   SENDTCP:
      if( dat_p )
        ether.httpServerReply( dat_p);


  delay( 34 );

}


#define CMDBUF 50
//-------------------------------------------------------------------
// -- http --
//

int16_t process_request(char *str)
{
  memset(line_buf,NULL,sizeof(line_buf));
  int8_t index = 0;
  
#ifdef DEBUG
  //Serial.println( str );
#endif

  char ch = str[index];
  
  while( ch != ' ' && index < CMDBUF) {
    line_buf[index] = ch;
    index++;
    ch = str[index];
  }
  line_buf[index] = '\0';

#ifdef DEBUG
  //Serial.println( line_buf );
#endif

  // convert clientline into a proper
  // string for further processing
  //String urlString = String(line_buf);
  // extract the operation
  //String op = urlString.substring(0,urlString.indexOf(' '));
  // we're only interested in the first part...
  //urlString = urlString.substring(urlString.indexOf('/'), urlString.indexOf(' ', urlString.indexOf('/')));
  // put what's left of the URL back in client line
  //urlString.toCharArray(line_buf, CMDBUF);
  // get the first two parameters
  char *pin = strtok(line_buf,"/");
  char *value = strtok(NULL,"/");
  // this is where we actually *do something*!

     if(strncmp(pin, "sensors", 7) == 0)
     {
       Serial.println("sensors");
       // list of sensors       
     }else if(strncmp(pin, "actuators", 9) == 0)
     {
       // list of actuators
       Serial.println("actuators");

     }else if(strncmp(pin, "actuator", 8) == 0 && value !=NULL)
     {
       // actuator info
       Serial.print("single actuator  id:");
       Serial.println(value);

     }else if(strncmp(pin, "sensor", 6) == 0 && value !=NULL)
     {
       // sensor info
       Serial.print("singel sensor  id:");
       Serial.println(value);

     }  
 
      bfill = ether.tcpOffset();
      bfill.emit_p(PSTR(
        "HTTP/1.0 200 OK\r\n"
        "Content-Type: text/html\r\n"
        "Pragma: no-cache\r\n"
        "\r\n"
        "{\"$S\":\"$S\"}"), "aa", "bb");
      return bfill.position();    
}


/////////////////////////////////////////////////
// called when the client request is complete
static void callback (byte status, word off, word len) {
  //Serial.println(">>>");    
    //get_header_line(2, off);
    //get_header_line("X-Powered-By",off);
    //Serial.println(line_buf);
    
  get_reply_data(off);
  Serial.print("body:");
  Serial.println(line_buf);
  if (strcmp(line_buf,"ok")) 
  {
    Serial.println("ok recieved"); //request_attempt = 0;
  }    
}

int get_header_line(char* line,word off)
{
  memset(line_buf,NULL,sizeof(line_buf));
  if (off != 0)
  {
    uint16_t pos = off;
    int line_num = 0;
    int line_pos = 0;
    
    while (Ethernet::buffer[pos])
    {
      if (Ethernet::buffer[pos]=='\n')
      {
        line_num++; line_buf[line_pos] = '\0';
        line_pos = 0;
        //if (line_num == line) return 1;
        if (strncmp(line,line_buf,50)==0)  return 1;
       
      }
      else
      {
        if (line_pos<49) {line_buf[line_pos] = Ethernet::buffer[pos]; line_pos++;}
      }  
      pos++; 
    } 
  }
  return 0;
}

int get_reply_data(word off)
{
  memset(line_buf,NULL,sizeof(line_buf));
  if (off != 0)
  {
    uint16_t pos = off;
    int line_num = 0;
    int line_pos = 0;
    
    // Skip over header until data part is found
    while (Ethernet::buffer[pos]) {
      if (Ethernet::buffer[pos-1]=='\n' && Ethernet::buffer[pos]=='\r') break;
      pos++; 
    }
    pos+=4;
    while (Ethernet::buffer[pos])
    {
      if (line_pos<49) {line_buf[line_pos] = Ethernet::buffer[pos]; line_pos++;} else break;
      pos++; 
    }
    line_buf[line_pos] = '\0';
  }
  return 0;
}

///////////////////////////////////////////////////////////////////////////////


int getLength(byte type)
{
  switch(type)
  {
    case 0:
    SRAM9.readstream(INDEX_SENSOR_LENGTH);   // start address from 0   
    break;
    case 1:
    SRAM9.readstream(INDEX_ACTUATOR_LENGTH);   // start address from 0
    break; 
  }
  
  byte t = SRAM9.RWdata(0xFF);
  SRAM9.closeRWstream();
  return t;
}

void storeDevice(int devicetype,char *id,char *type){
  int length = 0;
  length = getLength(devicetype);
  //Serial.println(strlen(id));
    switch(devicetype)
    {
      case 0:
      //Serial.println("0 type -----");
      SRAM9.writestream(LIST_SENSOR_BEGIN +length*sizeof(Sensor));   // start address from 0
      break;
      case 1:
      // Serial.println("1 type -----");
      SRAM9.writestream(LIST_ACTUATOR_BEGIN +length*sizeof(Sensor)); 
      break;//SRAM9.readstream(LIST_BEGIN+i*sizeof(Sensor));   // start address from 0
    } 

  /// time
  /*
  long longInt = millis();
  SRAM9.RWdata( (int)((longInt >> 8) & 0xFF) );
  SRAM9.RWdata( (int)((longInt) & 0xFF) );
  */
  /// store id
  for(byte i=0;i<20;i++)  
  {
    if(i<strlen(id))
    SRAM9.RWdata(id[i]);
    else 
    SRAM9.RWdata(0);
  }
  /// store value
  /*
  for(byte i=0;i<8;i++)  
  {
    if(i<sizeof(values))
    SRAM9.RWdata(values[i]);
    else 
    SRAM9.RWdata(0);
  } 
 */ 
  /// type
  for(byte i=0;i<20;i++)  
  {
    if(i<strlen(type))
    SRAM9.RWdata(type[i]);
    else 
    SRAM9.RWdata(0);
  }  
  /// vendor
  /*
  for(byte i=0;i<10;i++)  
  {
    if(i<strlen(vendor))
    SRAM9.RWdata(vendor[i]);
    else 
    SRAM9.RWdata(0);
  }
  */
  switch(devicetype)
  {
    case 0:
    SRAM9.writestream(INDEX_SENSOR_LENGTH);   // start address from 0   
    break;
    case 1:
    SRAM9.writestream(INDEX_ACTUATOR_LENGTH);   // start address from 0
    break; 
  }   
  SRAM9.RWdata(++length);
  SRAM9.closeRWstream();
  
  //Serial.print("len:");  Serial.println(length);  
}

boolean findDevice(int type,char *id){
  // empty the sensor structure
  memcpy(&sensor,NULL,sizeof(Sensor));
  // flag to break 
  boolean found = false;
  
  switch(type)
  {
    case 0:
    SRAM9.readstream(INDEX_SENSOR_LENGTH);   // start address from 0   
    break;
    case 1:
    SRAM9.readstream(INDEX_ACTUATOR_LENGTH);   // start address from 0
    break; 
  } 
  
   
  byte length = SRAM9.RWdata(0xFF); // get the length of devices
  for(byte i=0;i<length;i++)
  {  
    if(found ==true) break;    
    switch(type)
    {
      case 0:
      SRAM9.readstream(LIST_SENSOR_BEGIN+i*sizeof(Sensor));   // start address from 0
      break;
      case 1:
      SRAM9.readstream(LIST_ACTUATOR_BEGIN+i*sizeof(Sensor)); 
      break;//SRAM9.readstream(LIST_BEGIN+i*sizeof(Sensor));   // start address from 0
    }
    //Serial.print("device type:");Serial.println(SRAM9.RWdata(0xFF),HEX);// type
    
    // time
    //SRAM9.RWdata(0xFF);SRAM9.RWdata(0xFF); 
     // id
    memcpy(line_buf,0,strlen(line_buf));
    for(byte j=0;j<20;j++)
    line_buf[j]= SRAM9.RWdata(0xFF);
    //Serial.print("id:  ");Serial.println(line_buf);
    if(strcmp(line_buf,id)==0)
    {
      found = true;
      Serial.print("found id111:    ");Serial.print(id);Serial.print("   compares:  ");Serial.println(line_buf);
      memcpy(&sensor.id,&line_buf,sizeof(line_buf));
      break;
    }
    
    /// get data
    /*
    Serial.print("data:  ");
    for(byte j=0;j<8;j++)
    {
      ///Serial.print(SRAM9.RWdata(0xFF),HEX);Serial.print("    ");
    }
    //Serial.println();
    */
    // type
    memcpy(line_buf,0,strlen(line_buf));
    for(byte j=0;j<20;j++)
    line_buf[j]= SRAM9.RWdata(0xFF);
    //Serial.print("type:  ");Serial.println(line_buf);
    
    // vendor
    /*
    memcpy(line_buf,0,strlen(line_buf));
    for(byte j=0;j<10;j++)
    line_buf[j]= SRAM9.RWdata(0xFF);
    //Serial.print("vendor:  ");Serial.println(line_buf);    
    */
  }
  SRAM9.closeRWstream();
  return found;  
}


void testram()
{
  SRAM9.writestream(0);  // start address from 0
  unsigned long stopwatch = millis(); //start stopwatch

  for(unsigned int i = 0; i < 32768; i++)
    SRAM9.RWdata(0x00); //write to every SRAM address 

  //Serial.print(millis() - stopwatch);
  //Serial.println("   ms to write full SRAM");

  SRAM9.readstream(0);   // start address from 0 

  for(unsigned int i = 0; i < 32768; i++)
  {
    if(SRAM9.RWdata(0xFF) != 0x00)  //check every address in the SRAM
    {
      Serial.println("error in location  ");
      Serial.println(i);
      break;
    }//end of print error
    if(i == 32767)
      Serial.println("no errors in the 32768 bytes");
  }//end of get byte
  SRAM9.closeRWstream();
}
static int freeRam () {
  extern int __heap_start, *__brkval; 
  int v; 
  return (int) &v - (__brkval == 0 ? (int) &__heap_start : (int) __brkval); 	
}
