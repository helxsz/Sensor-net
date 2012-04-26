void printStr(const prog_char *p)
{
  while (1)
  {
    char c = pgm_read_byte(p++);
    if (!c) break;
    Serial.print(c);
  }
}
