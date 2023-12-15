import time
import numpy as np
from manta import Manta
import struct

m = Manta('manta.yaml') # create manta python instance using yaml

while True:
    a = struct.unpack("d", struct.pack("q", m.core.val1_in.get()))[0] # read in the output
    b = struct.unpack("d", struct.pack("q", m.core.val2_in.get()))[0] # read in the output
    print("%f  %f" % (a, b))
    time.sleep(1) 