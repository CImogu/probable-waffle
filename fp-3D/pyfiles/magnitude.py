import time
import struct
import math
from manta import Manta
m = Manta('fproj.yaml') # create manta python instance using yaml

to_int = lambda x: struct.unpack("i", struct.pack("f", x))[0]
to_float = lambda x: struct.unpack("f", struct.pack("i", x))[0]

def magnitude(vec):
    square_vector = (i * i for i in vec)
    return math.sqrt(sum(square_vector))

vector = (10, 11, 12)
print('setting intput')
m.fproj_io_core.val2_out.set(to_int(vector[0])) # set the value val2_out
m.fproj_io_core.val3_out.set(to_int(vector[1])) # set the value val3_out
m.fproj_io_core.val4_out.set(to_int(vector[2])) # set the value val4_out
time.sleep(0.05) # wait a little amount...though honestly this is isn't needed since Python is slow.
print('reading output')
vector_mag = m.fproj_io_core.val1_in.get() # read in the output from our divider
print(f"Values in were {vector} with results {magnitude(vector)}.")
print(f"Actual results were: {vector_mag}!")