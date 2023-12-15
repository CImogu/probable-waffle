import numpy as np

poly = 0xEDB88320

for i in range(256):
  crc = i
  for j in range(8):
    crc = (crc >> 1) ^ (-int(crc & 1) & poly)
  print("%d: %x" % (i, crc))
