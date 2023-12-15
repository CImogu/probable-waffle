packet = "ff ff ff ff ff ff f2 6a 34 90 cc 01 08 00 00 01 02 03 04 05 06 07 08 09 0a 0b 0c 0d 0e 0f 10 11 12 13 14 15 16 17 18 19 1a 1b 1c 1d 1e 1f 20 21 22 23 24 25 26 27 28 29 2a 2b 2c 2d 2e 2f 30 31".replace(" ", "")
nbytes = len(packet)//2

print(packet)

crc_table = []
poly = 0xEDB88320
for i in range(256):
  crc = i
  for j in range(8):
    crc = (crc >> 1) ^ (-int(crc & 1) & poly)
  crc_table.append(crc)
  #print(hex(crc))

def flip(x, l):
    s = "".join(list(reversed(bin(x)[2:])))
    return int(s + "0"*(l - len(s)), 2)

print(hex(flip(0x37840962, 32)))

crc = 0xffffffff
for i in range(nbytes):
    byte = int(packet[2*i:2*(i+1)], 16)
    byte_flipped = flip(byte, 8)
    #print(bin(byte_flipped), bin(byte))
    #crc = crc ^ (2**32 - 1)
    crc = ((crc & (2**32 - 1)) >> 8) ^ crc_table[(crc & (2**8-1)) ^ byte]
    #crc = (crc & (2**24 - 1)) ^ crc_table[((crc & (2**32-1)) >> 24) ^ byte_flipped]
crc = crc ^ (2**32 - 1)

print(
    hex(crc),
    hex(flip(crc, 32)))