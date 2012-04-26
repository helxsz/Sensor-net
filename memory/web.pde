


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




prog_char mac[20] PROGMEM = "";
void getMac()
{
  char buf[20];
  boolean r = true;
  NanodeUNIO unio(NANODE_MAC_DEVICE) ;
  r= unio.read(mymac, NANODE_MAC_ADDRESS, 6) ;
  if (r) Serial.println("success");
  else Serial.println("failure");
  /*
  sprintf(buf,"%02X:%02X:%02X:%02X:%02X:%02X",
          mymac[0],mymac[1],mymac[2],
          mymac[3],mymac[4],mymac[5]);
  */
  sprintf(buf,"%X%X%X%X%X%X",
          mymac[0],mymac[1],mymac[2],
          mymac[3],mymac[4],mymac[5]);
  sprintf(mac,"%X%X%X%X%X%X",
          mymac[0],mymac[1],mymac[2],
          mymac[3],mymac[4],mymac[5]);        
  Serial.print("MAC address is ");
  Serial.println(buf);
  Serial.println(mac);
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


void initWebConfig()
{
   if (ether.begin(sizeof Ethernet::buffer, mymac) == 0) 
   Serial.println( "Failed to access Ethernet controller");
   
   ether.staticSetup(myip, gwip); 
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
   while (ether.clientWaitingGw())
   ether.packetLoop(ether.packetReceive());
   Serial.println("Gateway found");  
   

  ether.hisip[0] = 192;
  ether.hisip[1] = 168;
  ether.hisip[2] = 210;
  ether.hisip[3] = 5;

     ether.copyIp(ether.hisip, hisip);
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
