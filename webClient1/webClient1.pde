// Demo using DHCP and DNS to perform a web client request.
// 2011-06-08 <jc@wippler.nl> http://opensource.org/licenses/mit-license.php
#include <Ports.h>
#include <RF12.h>
#include <JeeLib.h>

#define MYNODE 15            
#define freq RF12_868MHZ      // frequency
#define group 210            // network group


#define DEBUG

//---------------------------------------------------
// Data structures for transfering data between units
//---------------------------------------------------
typedef struct { int power, battery; } PayloadTX;
PayloadTX emontx;    

typedef struct { int temperature; } PayloadGLCD;
PayloadGLCD emonglcd;

typedef struct { int hour, mins, sec; } PayloadBase;
PayloadBase emonbase;

//---------------------------------------------------------------------
// The PacketBuffer class is used to generate the json string that is send via ethernet - JeeLabs
//---------------------------------------------------------------------
class PacketBuffer : public Print {
public:
    PacketBuffer () : fill (0) {}
    const char* buffer() { return buf; }
    byte length() { return fill; }
    void reset()
    { 
      memset(buf,NULL,sizeof(buf));
      fill = 0; 
    }
    virtual void write(uint8_t ch)
        { if (fill < sizeof buf) buf[fill++] = ch; }
    byte fill;
    char buf[150];
    private:
};
PacketBuffer packet;

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
static byte hisip[] = { 192,168,210,5 };
// remote website name
char website[] PROGMEM = "google.com";

byte Ethernet::buffer[700];
static BufferFiller bfill;  // used as cursor while filling the buffer

static uint32_t timer;/////////////////////
#define REQUEST_RATE 5000 // milliseconds

const int redLED = 6;                     // NanodeRF RED indicator LED
const int greenLED = 5;                   // NanodeRF GREEN indicator LED

int ethernet_error = 0;                   // Etherent (controller/DHCP) error flag
int rf_error = 0;                         // RF error flag - high when no data received 
int ethernet_requests = 0;                // count ethernet requests without reply                 

int dhcp_status = 0;
int dns_status = 0;

int emonglcd_rx = 0;                      // Used to indicate that emonglcd data is available
int data_ready=0;                         // Used to signal that emontx data is ready to be sent
unsigned long last_rf;                    // Used to check for regular emontx data - otherwise error

char line_buf[50];                        // Used to store line of http reply header

// called when the client request is complete
static void my_result_cb (byte status, word off, word len) {
  Serial.print("<<< reply ");
  Serial.print(millis() - timer);
  Serial.println(" ms");
  Serial.println((const char*) Ethernet::buffer + off);
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
  char buf[20];
  boolean r;
  NanodeUNIO unio(NANODE_MAC_DEVICE) ;
  r= unio.read(mymac, NANODE_MAC_ADDRESS, 6) ;
  if (r) Serial.println("success");
  else Serial.println("failure");
  sprintf(buf,"%02X:%02X:%02X:%02X:%02X:%02X",
          mymac[0],mymac[1],mymac[2],
          mymac[3],mymac[4],mymac[5]);
  Serial.print("MAC address is ");
  Serial.println(buf);
}

//-------------------------------------------------------------------
// -- power --
//
byte gbEthEnabled = true;
#define kEnEtherPin  4  // ethernet only enabled if this pin is high
//http://alexmole.co.uk/blog/wp-content/uploads/2011/12/rgb.pde
void tickEthPower()
{
  // do we need to power up/down the eth chip?
  byte bEthShouldBeOn = digitalRead( kEnEtherPin );
  if( gbEthEnabled != bEthShouldBeOn )
  {
    if( !bEthShouldBeOn )
    {
      ether.powerDown();
    }
    else
    {
      ether.powerUp();
    }
    
    gbEthEnabled = bEthShouldBeOn;
  }
}

void setup () {
 // config the leds 
 /* */ 
 pinMode(redLED, OUTPUT); digitalWrite(redLED,LOW);            
 pinMode(greenLED, OUTPUT); digitalWrite(greenLED,LOW);       
 delay(100); digitalWrite(redLED,HIGH);                 
  
  Serial.begin(9600);
  Serial.println("\n[webClient]");

  if (ether.begin(sizeof Ethernet::buffer, mymac) == 0) 
    Serial.println( "Failed to access Ethernet controller");

  getMac();      
  ether.staticSetup(myip, gwip);
 /*
  if (!ether.dhcpSetup())
    Serial.println("DHCP failed");

  ether.printIp("IP:  ", ether.myip);
  ether.printIp("GW:  ", ether.gwip);  
  ether.printIp("DNS: ", ether.dnsip);  
*/
  while (ether.clientWaitingGw())
    ether.packetLoop(ether.packetReceive());
  Serial.println("Gateway found");
/*  
#if 1
  // use DNS to locate the IP address we want to ping
  if (!ether.dnsLookup(PSTR("www.google.com")))
    Serial.println("DNS failed");
#else
  ether.parseIp(ether.hisip, "192.168.210.5");
#endif
  ether.printIp("SRV: ", ether.hisip);
  ether.hisport = 80;
  Serial.println(ether.hisip[0]);
  
  ether.hisip[0] = 192;
  ether.hisip[1] = 168;
  ether.hisip[2] = 210;
  ether.hisip[3] = 5;
*/  
  ether.copyIp(ether.hisip, hisip);
  
  // config the rf12
  /*
  rf12_initialize(MYNODE, freq,group);
  last_rf = millis()-40000;                                       // setting lastRF back 40s is useful as it forces the ethernet code to run straight away   
  digitalWrite(greenLED,HIGH);                                    // Green LED off - indicate that setup has finished 
   */  
   
   
}

void loop () {

  /*   */
  if (millis() > timer) {
    timer = millis() + 5000;
    Serial.println();
    Serial.print("<<< REQ ");
    
     packet.reset();                                                   // Reset json string      
     packet.print("{rf_fail:0");                                       // RF recieved so no failure
     packet.print(",power:");        packet.print(23);          // Add power reading 
     packet.print(",battery:");      packet.print(23);    
    ether.httpPost(PSTR("/test"),NULL,NULL,"c",callback);
   }
   
   /**********************************************************/

    uint16_t plen, dat_p;
    int8_t cmd;
    // read packet, handle ping and wait for a tcp packet:
    dat_p=ether.packetLoop(ether.packetReceive());

    //
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
      Serial.println("GET / request");
    #endif
      dat_p = print_webpage();
      goto SENDTCP;
    }
    dat_p = process_request((char *)&(Ethernet::buffer[dat_p+4]));
    
   SENDTCP:
   if( dat_p )
   ether.httpServerReply( dat_p);   
   
  #ifdef UNO
  //if (request_attempt > 10) delay(10000); // Reset the nanode if more than 10 request attempts have been tried without a reply
  #endif  
}

#define CMDBUF 50

int16_t process_request(char *str)
{
  int8_t r=-1;
  int8_t i = 0;
  char clientline[CMDBUF];
  int index = 0;
  int plen = 0;
  
#ifdef DEBUG
  Serial.println( str );
#endif

  char ch = str[index];
  
  while( ch != ' ' && index < CMDBUF) {
    clientline[index] = ch;
    index++;
    ch = str[index];
  }
  clientline[index] = '\0';

#ifdef DEBUG
  Serial.println( clientline );
#endif

  // convert clientline into a proper
  // string for further processing
  String urlString = String(clientline);
  // extract the operation
  String op = urlString.substring(0,urlString.indexOf(' '));
  // we're only interested in the first part...
  urlString = urlString.substring(urlString.indexOf('/'), urlString.indexOf(' ', urlString.indexOf('/')));
  // put what's left of the URL back in client line
  urlString.toCharArray(clientline, CMDBUF);
  // get the first two parameters
  char *pin = strtok(clientline,"/");
  char *value = strtok(NULL,"/");

  // this is where we actually *do something*!
  char outValue[10] = "MU";
  char jsonOut[50];  
  
     Serial.println("test");
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


// called when the client request is complete
static void callback (byte status, word off, word len) {
  Serial.println(">>>");
  /*
  char* data = (char *) Ethernet::buffer + off;
  if (strncmp("HTTP/1.1 200 OK",data,16)!=0){
      // head, post and other methods:
    #ifdef DEBUG 
     Serial.println(" get the 200 ok");
     Serial.print(data+16);
    #endif  
 }
    int line_number = 0;
    int index = 0;    // index of request
    int line_index=0;  // index of line           
    // the length of the line     
    while(index < strlen(data))
    {
      char clientline[CMDBUF];  
      char ch = data[index];      
      while( ch != '\n' && line_index < CMDBUF) {
       clientline[line_index++] = ch;
       index++;
       ch = data[index];
       //if(ch == '\r') Serial.println("break");
      }
      index ++;
      line_index = 0;
      line_number++;

      
    #ifdef DEBUG    
      Serial.print("line is:");
      Serial.println( clientline ); 
      Serial.print( index );  Serial.print("   :    ");Serial.println(line_number);
      if(strlen(clientline)==1 && clientline[0]=='\r') Serial.println("into body");
    #endif
      memset(&clientline[0], 0, sizeof(clientline)); 
    }
    */
    
    //get_header_line(2, off);
    get_header_line("X-Powered-By",off);
    Serial.println(line_buf);
    
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


void processRF()
{
//-----------------------------------------------------------------------------------------------------------------
  // 1) On RF recieve
  //-----------------------------------------------------------------------------------------------------------------
  if (rf12_recvDone()){      
      if (rf12_crc == 0 && (rf12_hdr & RF12_HDR_CTL) == 0)
      {
        
        // https://github.com/helxsz/SerettaLabs/blob/master/etherNodeAlex/etherNodeAlex.pde
        int node_id = (rf12_hdr & 0x1F);
        
        if (node_id == 10)                                               // EMONTX
        {
          emontx = *(PayloadTX*) rf12_data;                              // get emontx data
          Serial.println();                                              // print emontx data to serial
          Serial.print("1 emontx: ");  
          Serial.print(emontx.power);
          Serial.print(' ');
          Serial.print(emontx.battery);
          Serial.print(" | time: ");          
          Serial.println(millis()-last_rf);
          last_rf = millis();                                            // reset lastRF timer
          
          delay(50);                                                     // make sure serial printing finished
                               
          // JSON creation: JSON sent are of the format: {key1:value1,key2:value2} and so on
          
          packet.reset();                                                   // Reset json string      
          packet.print("{rf_fail:0");                                       // RF recieved so no failure
          packet.print(",power:");        packet.print(emontx.power);          // Add power reading 
          packet.print(",battery:");      packet.print(emontx.battery);        // Add emontx battery voltage reading
    
          data_ready = 1;                                                // data is ready
          rf_error = 0;
        }
        
        if (node_id == 20)                                               // EMONGLCD 
        {
          emonglcd = *(PayloadGLCD*) rf12_data;                          // get emonglcd data
          Serial.print("5 emonglcd: ");                                  // print output
          Serial.println(emonglcd.temperature);  
          emonglcd_rx = 1;        
        }
      }
    }

  //-----------------------------------------------------------------------------------------------------------------
  // 2) If no data is recieved from rf12 module the server is updated every 30s with RFfail = 1 indicator for debugging
  //-----------------------------------------------------------------------------------------------------------------
  if ((millis()-last_rf)>30000)
  {
    last_rf = millis();                                                 // reset lastRF timer
    packet.reset();                                                        // reset json string
    packet.print("{rf_fail:1");                                            // No RF received in 30 seconds so send failure 
    data_ready = 1;                                                     // Ok, data is ready
    rf_error=1;
  }


  //-----------------------------------------------------------------------------------------------------------------
  // 3) Send data via ethernet
  //-----------------------------------------------------------------------------------------------------------------
  ether.packetLoop(ether.packetReceive());
  
  if (data_ready) {
    
    // include temperature data from emonglcd if it has been recieved
    if (emonglcd_rx) {
      packet.print(",temperature:");  
      packet.print(emonglcd.temperature/100.0);
      emonglcd_rx = 0;
    }
    
    packet.print("}\0");  //  End of json string
    
    Serial.print("2 "); Serial.println(packet.buf); // print to serial json string

    // Example of posting to emoncms v3 demo account goto http://vis.openenergymonitor.org/emoncms3 
    // and login with sandbox:sandbox
    // To point to your account just enter your WRITE APIKEY 
    ethernet_requests ++;
    ether.browseUrl(PSTR("/emoncms3/api/post.json?apikey=2d177d7311daf401d054948ce29efe74&json="),packet.buf, website, callback);
    data_ready =0;
  }
  
  if (ethernet_requests > 10) delay(10000); // Reset the nanode if more than 10 request attempts have been tried without a reply  
}

 /*
 // Build up a json string: {key:value,key:value}
    // dtostrf - converts a double to a string!
    // strcat  - adds a string to another string
    // strcpy  - copies a string
    strcpy(str,"{a0:"); dtostrf(a0,0,1,fstr); strcat(str,fstr); strcat(str,",");
    strcat(str,"a1:"); dtostrf(a1,0,1,fstr); strcat(str,fstr); strcat(str,"}");

https://github.com/openenergymonitor/emonTxFirmware/blob/master/emonTx_onewire_temperature_Example/emonTx_onewire_temperature_Example.pde
randomSeed(analogRead(0));           
  myNodeID=(random(28)+1);   
 */  
 
 
// https://groups.google.com/forum/#!topic/nanode-users/1OMx2tAEA2Q 
// A dirty hack to jump to start of boot loader
void reboot() {
    asm volatile ("  jmp 0x7C00");
}
