void configRF(){
  // config the rf12
  /* */  
  rf12_initialize(MYNODE, freq,group);
  last_rf = millis()-40000;                                       // setting lastRF back 40s is useful as it forces the ethernet code to run straight away   
  digitalWrite(greenLED,HIGH);                                    // Green LED off - indicate that setup has finished 
  
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
