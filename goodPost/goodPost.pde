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
     
}


void loop () {

  /*   */
  if (millis() > timer) {
    timer = millis() + 5000;
    Serial.println();
    Serial.print("<<< REQ ");       
    ether.httpPost(PSTR("/test"),NULL,NULL,"cc",my_result_cb);
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
 }
 
 // called when the client request is complete
static void my_result_cb (byte status, word off, word len) {
  Serial.print("<<< reply ");
  Serial.print(millis() - timer);
  Serial.println(" ms");
  Serial.println((const char*) Ethernet::buffer + off);
}
