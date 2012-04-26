
void getMac()
{
  NanodeUNIO unio(NANODE_MAC_DEVICE);  
  boolean r = true;
  
  Serial.println("Nanode MAC reader\n");
  Serial.print("Reading MAC address... ");
  r=unio.read(macaddr,NANODE_MAC_ADDRESS,6);
  if (r) Serial.println("success");
  else Serial.println("failure");
  sprintf(mymac,"%02X%02X%02X%02X%02X%02X",
          macaddr[0],macaddr[1],macaddr[2],
          macaddr[3],macaddr[4],macaddr[5]);
  
 
  Serial.print("MAC address is ");
  Serial.println(mymac);
}
