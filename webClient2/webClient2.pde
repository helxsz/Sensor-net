// Demo using DHCP and DNS to perform a web client request.
// 2011-06-08 <jc@wippler.nl> http://opensource.org/licenses/mit-license.php

#include <EtherCard.h>

// ethernet interface mac address, must be unique on the LAN
static byte mymac[] = { 0x74,0x69,0x69,0x2D,0x30,0x31 };

byte Ethernet::buffer[700];
static uint32_t timer;

char website[] PROGMEM = "www.google.com";

// called when the client request is complete
static void my_callback (byte status, word off, word len) {
  Serial.println(">>>");
  Ethernet::buffer[off+300] = 0;
  Serial.print((const char*) Ethernet::buffer + off);
  Serial.println("...");
}

void setup () {
  Serial.begin(9600);
  Serial.println("\n[webClient]");

  if (ether.begin(sizeof Ethernet::buffer, mymac) == 0) 
    Serial.println( "Failed to access Ethernet controller");
  if (!ether.dhcpSetup())
    Serial.println("DHCP failed");

  ether.printIp("IP:  ", ether.myip);
  ether.printIp("GW:  ", ether.gwip);  
  ether.printIp("DNS: ", ether.dnsip);  

  if (!ether.dnsLookup(website))
    Serial.println("DNS failed");
    
  ether.printIp("SRV: ", ether.hisip);
}

void loop () {
  ether.packetLoop(ether.packetReceive());
  
  if (millis() > timer) {
    timer = millis() + 5000;
    Serial.println();
    Serial.print("<<< REQ ");
    ether.browseUrl(NULL, NULL, PSTR("www.google.com"), my_callback);
    
    /*
    BufferFiller bfill = EtherCard::tcpOffset();
    bfill.emit_p(PSTR("POST http://192.168.210.5 HTTP/1.1\r\n"
                        "Host: http://192.168.210.5\r\n"
                        "Accept: text/html\r\n"
                        "Connection: close\r\n"
                        "Content-Length: 12\r\n"
                        "Content-Type: application/x-www-form-urlencoded\r\n"
                        "\r\n"
                        "$S"), 
                                "ddddafdddd");
    */
  }
}
/*
iota(integer_variable,...)
sprintf(my_temporary_string _variable,"%d",integer_variable)

*/
