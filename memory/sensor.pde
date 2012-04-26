void sendSensorData()
{
  DHT22_ERROR_t errorCode;

  Serial.print("Requesting data...");
  errorCode = myDHT22.readData();
  switch(errorCode)
  {
    case DHT_ERROR_NONE:
      Serial.print("Got Data ");
      Serial.print(myDHT22.getTemperatureC());
      Serial.print("C ");
      Serial.print(myDHT22.getHumidity());
      Serial.println("%");
     
     
     //https://github.com/helxsz/NanodeRF/blob/master/NanodeRF_singleCT_RTCrelay_GLCDtemp/NanodeRF_singleCT_RTCrelay_GLCDtemp.ino
      char var[1];
     var[0] ='2'; var[1]='3';
    atoi(var);
    Serial.println(atoi(var)); 
   //Serial.println(hour); 
      
     packet.reset();                                                   // Reset json string                                           
     packet.print("{\"a\":\"");        packet.print(66);          // Add power reading 
     packet.print("\",\"b\":\"");      packet.print(77);    
     packet.print("\"}");
     Serial.println(packet.buf);
     
     //packet.reset();
     //packet.print("{temperature:32,humidity:32}\0");
     //packet.print("{'temperature':32,'humidity':32}\0");
     //packet.print("{'temperature':'32','humidity':'32'}\0");// wrong
     //packet.print("{'temperature':'32'}");
     //packet.print("{'temperature':'32'}");
      
      //ether.browseUrl(PSTR("/test?apikey="APIKEY"&data="), packet.buf, NULL, callback);   
      
      
      break;
    case DHT_ERROR_CHECKSUM:
      Serial.print("check sum error ");
      Serial.print(myDHT22.getTemperatureC());
      Serial.print("C ");
      Serial.print(myDHT22.getHumidity());
      Serial.println("%");
      break;
    case DHT_BUS_HUNG:
      Serial.println("BUS Hung ");
      break;
    case DHT_ERROR_NOT_PRESENT:
      Serial.println("Not Present ");
      break;
    case DHT_ERROR_ACK_TOO_LONG:
      Serial.println("ACK time out ");
      break;
    case DHT_ERROR_SYNC_TIMEOUT:
      Serial.println("Sync Timeout ");
      break;
    case DHT_ERROR_DATA_TIMEOUT:
      Serial.println("Data Timeout ");
      break;
    case DHT_ERROR_TOOQUICK:
      Serial.println("Polled to quick ");
      break;
  }  
}
