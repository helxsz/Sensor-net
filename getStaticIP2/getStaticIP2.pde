// This demo does web requests to a fixed IP address, using a fixed gateway.
// 2010-11-27 <jc@wippler.nl> http://opensource.org/licenses/mit-license.php

#include <EtherCard.h>
#include <NanodeUNIO.h>

#define REQUEST_RATE 5000 // milliseconds



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


// buffer 
byte Ethernet::buffer[300];   // a very small tcp/ip buffer is enough here
static BufferFiller bfill;  // used as cursor while filling the buffer
static long timer;



// called when the client request is complete
static void my_result_cb (byte status, word off, word len) {
  Serial.print("<<< reply ");
  Serial.print(millis() - timer);
  Serial.println(" ms");
  Serial.println((const char*) Ethernet::buffer + off);
}



char okHeader[] PROGMEM =
    "HTTP/1.0 200 OK\r\n"
    "Content-Type: text/html\r\n"
    "Pragma: no-cache\r\n"
    "\r\n" ;
 
char responseHeader[] PROGMEM =
    "HTTP/1.1 200 OK\r\n"
    "Content-Type: text/html\r\n"
    "Access-Control-Allow-Origin: *\r\n"
    "\r\n" ;
    
void homepage(BufferFiller& buf)
{
  buf.emit_p(PSTR(
    "$F"
    "<html>"
    "<head>"
    "<title>webserver remote</title>"
    "<style type=\"text/css\">"
    "body   { width: 640px ; }"
    "</style>"
    "</head>"
    "<body>"
    "<h1>webserver remote</h1>"
    "<p>"
    "This webserver is running on a <a href=\"http://nanode.eu\">Nanode</a>, an "
    "Arduino-compatible microcontroller with web connectivity. It uses the <a"
    "href=\"https://github.com/jcw/ethercard\">EtherCard library</a> written by "
    "<a href=\"http://jeelabs.net/projects/cafe/wiki/EtherCard\">JeeLabs</a>.  "
        "Inspired by Jason Gullickson's <a href=\"http://www.youtube.com/watch?v=X-s2se-34-g\">RESTduino</a>."
    "</p>"
    "<hr/>"
    "<p style=\"text-align: right;\">Written by Mark VandeWettering</p>"
    "</body>"
    "</html>"
    ), okHeader) ;
}
     


void setup () {
  Serial.begin(9600);
  Serial.println("[getStaticIP]");  
  if (ether.begin(sizeof Ethernet::buffer, mymac) == 0) 
    Serial.println( "Failed to access Ethernet controller");

  // get the mac address of this device
  getMac();

  ether.staticSetup(myip, gwip);
 
  ether.copyIp(ether.hisip, hisip);
  ether.printIp("Server: ", ether.hisip);

  while (ether.clientWaitingGw())
    ether.packetLoop(ether.packetReceive());
  Serial.println("Gateway found");
  
  timer = - REQUEST_RATE; // start timing out right away
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

void loop () {
  /*
  ether.packetLoop(ether.packetReceive());
  
  if (millis() > timer + REQUEST_RATE) {
    timer = millis();
    Serial.println("\n>>> REQ");
    ether.browseUrl(PSTR("/foo/"), "bar", website, my_result_cb);
  }
  */
 // handle any incoming http
  tickServer(); 
  
  delay( 14 );
}

//-------------------------------------------------------------------
// -- http --
//
void tickServer()
{ 
  word len = ether.packetReceive();
  word pos = ether.packetLoop(len); 
  // check if valid tcp data is received
  if (pos)
  {
    bfill = ether.tcpOffset();
    char* data = (char *) Ethernet::buffer + pos;
    // we only support GET
    Serial.println(data) ;
    
    Serial.println(strncmp( "GET ", data, 4 ));
    Serial.println(strncmp( "GET ", data, 5 ));
    Serial.println(strncmp( "GET /", data, 5 ));
    
    
    if(strncmp( "GET ", data, 4 ) == 0)
    {
      Serial.println("GET request");
      //homepage(bfill) ;
      /* */
          bfill.emit_p(PSTR(
                "HTTP/1.0 200 OK\r\n"
                "Content-Type: text/plain\r\n"
                "\r\n"
                "bingo bongo"                                               
                ));
          
         
      ether.httpServerReply( bfill.position() ); // send web page data
      return;
    }
    
    if(strncmp( "PUT ", data, 4 ) == 0)
    {
      //process_request(data+5,bfill);
      Serial.println("PUT request");
      
    }
    //process_request(data+5,bfill);
    
    
   Serial.println("sendtcp");
   
  }
}

// handle an HTTP GET request, dispatching to appropriate handler
byte handleGet( const char* lpRequest, BufferFiller& buf )
{
  /*
  if( strncmp( "hsl?", lpRequest, 4 ) == 0 )
    return handleHsl( lpRequest+4, buf );
  if( strncmp( "speed?", lpRequest, 6 ) == 0 )
    return handleSpeed( lpRequest+6, buf );  
  */  
  if( *lpRequest == ' ' )
  {
    buf.emit_p(PSTR(
                "HTTP/1.0 200 OK\r\n"
                "Content-Type: text/plain\r\n"
                "\r\n"
                "bingo bongo"));
    return 1;
  }
  
  return 0;
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




//  get mac  https://raw.github.com/gist/1143787/2ed595744f24f425e59c6bf9c70d5ce6d66caf73/nanode_pachube.pde
