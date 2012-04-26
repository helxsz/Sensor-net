//https://github.com/thiseldo/EtherCardExamples/blob/master/EtherCard_RESTduino/EtherCard_RESTduino.ino
// https://github.com/openenergymonitor/NanodeRF/blob/master/NanodeRF_singleCT_RTCrelay_GLCDtemp/NanodeRF_singleCT_RTCrelay_GLCDtemp.ino
#include <Ports.h>
#include <RF12.h>
#include <JeeLib.h>

#define MYNODE 1            
#define freq RF12_868MHZ      // frequency
#define group 1            // network group
//---------------------------------------------------
// Data structures for transfering data between units
//---------------------------------------------------
typedef struct { 
               int temperature, humidity;
               char mac[20]; 
} PayloadTX;
typedef struct {
    byte  type;
    byte  data[14];
} Payload;
Payload incNodeData;

PayloadTX emontx;    


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
    char buf[100];
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
static byte hisip[] = { 74,125,79,99 };
// remote website name
char website[] PROGMEM = "google.com";
#define APIKEY  "b872449aa3ba74458383a798b740a378"

// buffer 
byte Ethernet::buffer[300];   // a very small tcp/ip buffer is enough here
static BufferFiller bfill;  // used as cursor while filling the buffer
char line_buf[100];                        // Used to store line of http reply header

static uint32_t timer;/////////////////////



const int redLED = 6;                     // NanodeRF RED indicator LED
const int greenLED = 5;                   // NanodeRF GREEN indicator LED

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

void setup () {
 // config the leds 
 /* */ 
 pinMode(redLED, OUTPUT); digitalWrite(redLED,LOW);            
 pinMode(greenLED, OUTPUT); digitalWrite(greenLED,LOW);       
 delay(100); digitalWrite(redLED,HIGH);                          // turn off redLED  

  Serial.begin(9600);  
  
  Serial.println("[getStaticIP]");  
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
      
    /* 
    /////////////////////// PROBLEM ///////////////////////////////////////////
    /////////////////////////////////////////////////////////////////////////
      //// test resend the packet back  
      delay(5);
      rf12_sendStart( (RF12_HDR_ACK |RF12_HDR_DST | 18), &emontx, sizeof emontx);
      rf12_sendWait(2);   
    ///////////////////////////////////////////////////////////////////////// 
      
      http://www.22balmoralroad.net/wordpress/wp-content/uploads/homeBase.pde
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

    //byte lenfth = rf12_len;
    Serial.print(emontx.temperature);Serial.print("    "); 
    Serial.print(emontx.humidity);Serial.print("    ");
    Serial.println(emontx.mac);
    
  
    
    /**/
    Serial.println(millis()-last_rf);
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
      Serial.println("GET / request");
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

  int8_t index = 0;
  
#ifdef DEBUG
  Serial.println( str );
#endif

  char ch = str[index];
  
  while( ch != ' ' && index < CMDBUF) {
    line_buf[index] = ch;
    index++;
    ch = str[index];
  }
  line_buf[index] = '\0';

#ifdef DEBUG
  Serial.println( line_buf );
#endif

  // convert clientline into a proper
  // string for further processing
  String urlString = String(line_buf);
  // extract the operation
  String op = urlString.substring(0,urlString.indexOf(' '));
  // we're only interested in the first part...
  urlString = urlString.substring(urlString.indexOf('/'), urlString.indexOf(' ', urlString.indexOf('/')));
  // put what's left of the URL back in client line
  urlString.toCharArray(line_buf, CMDBUF);
  // get the first two parameters
  char *pin = strtok(line_buf,"/");
  char *value = strtok(NULL,"/");
  // this is where we actually *do something*!
  char outValue[10] = "MU";
  
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


/////////////////////////////////////////////////
// called when the client request is complete
static void callback (byte status, word off, word len) {
  Serial.println(">>>");    
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


static int freeRam () {
  extern int __heap_start, *__brkval; 
  int v; 
  return (int) &v - (__brkval == 0 ? (int) &__heap_start : (int) __brkval); 	
}

