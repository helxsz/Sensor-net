/* linked list example */
#include <stdio.h>
#include <stdlib.h>
#include <Ports.h>
#include <RF12.h>
#include <JeeLib.h>




//---------------------------------------------------
// Data structures for transfering data between units
//---------------------------------------------------

#define MYNODE 15            
#define freq RF12_868MHZ      // frequency
#define group 210            // network group

#define DEBUG

typedef struct { int power, battery; } PayloadTX;
PayloadTX emontx;    

typedef struct { int temperature; } PayloadGLCD;
PayloadGLCD emonglcd;

typedef struct { int hour, mins, sec; } PayloadBase;
PayloadBase emonbase;




//--------------------------------------------------------------------------
// Sensor
//--------------------------------------------------------------------------
struct node {
   char id[20];
   int  value;
   prog_char *type;              /* id */
   struct node *next;
};

/* head points to first node in list, end points to last node in list */
/* initialise both to NULL, meaning no nodes in list yet */
struct node *head = (struct node *) NULL;
struct node *end = (struct node *) NULL;

prog_char type_temp[] PROGMEM = "http://webinos.org/api/sensors.temperature";   // "String 0" etc are strings to store - change to suit.
prog_char type_hum[] PROGMEM = "http://webinos.org/api/sensors.humidity";
prog_char type_light[] PROGMEM = "http://webinos.org/api/sensors.light";
prog_char type_vol[] PROGMEM = "http://webinos.org/api/sensors.voltage";
prog_char type_ele[] PROGMEM = "http://webinos.org/api/sensors.electrcity";

#define MAX_SENSORS 5
#define MAX_ACTUATORS 3

//---------------------------------------------------------------------
// The temperature and humidity sensor
//---------------------------------------------------------------------
#include <DHT22.h>
#define DHT22_PIN 7// Setup a DHT22 instance
DHT22 myDHT22(DHT22_PIN);

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
#define APIKEY  "b872449aa3ba74458383a798b740a378"
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

void setup()
{
  Serial.begin(9600);
  Serial.println("\n[webClient]");  
   
  struct node *ptr;
  ptr = initnode( "name1", 1, type_temp );
  add( ptr );

  ptr = initnode( "name2", 2, type_hum );
  add( ptr );  
 /*   
  printlist(head);
  ptr =  searchname(head,"name1");
  prog_char *type = ptr->type;

    if( strcmp_P("http://webinos.org/api/sensors.temperature",type) ==0)
    {
      Serial.println("temperatuer");
    }
    else if(strcmp_P("http://webinos.org/api/sensors.humidity",type) ==0)
    {
      Serial.println("humidity");
    }
    else if(strcmp_P("http://webinos.org/api/sensors.light",type) ==0)
    {
      Serial.println("light");
    }
    else if(strcmp_P("http://webinos.org/api/sensors.voltage",type) ==0)
    {
      Serial.println("voltage");
    }
    else if(strcmp_P("http://webinos.org/api/sensors.electrcity",type) ==0)
    {
      Serial.println("electrcity");
    }else
    {
       Serial.println("no type");
    }
 */
  getMac();
  if (ether.begin(sizeof Ethernet::buffer, mymac) == 0) 
    Serial.println( "Failed to access Ethernet controller");
  if (!ether.dhcpSetup())
    Serial.println("DHCP failed");

  ether.printIp("IP:  ", ether.myip);
  ether.printIp("GW:  ", ether.gwip);  
  ether.printIp("DNS: ", ether.dnsip);  
  
  ether.hisip[0] = 192;
  ether.hisip[1] = 168;
  ether.hisip[2] = 210;
  ether.hisip[3] = 5;

    
  ether.printIp("SRV: ", ether.hisip);  
  
}

void loop()
{
  ether.packetLoop(ether.packetReceive());
  
  if (millis() > timer) {
    timer = millis() + 5000;
    Serial.println();
    Serial.print("<<< REQ ");
     char str[50]="";
     //sprintf(str,"{\"temp1\":\"%d\",\"temp2\":\"%d\"}", 1,2);    
    
     sprintf(str,"{\'a\':\'%d\',\'b\':\'%d\'}", 1,2);  
     Serial.println(str); 
     ether.browseUrl(PSTR("/test?apikey="APIKEY"&data="), str, NULL, my_result_cb);   
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





