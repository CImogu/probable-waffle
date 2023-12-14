import time
from manta import Manta
m = Manta('fproj.yaml') # create manta python instance using yaml

triangle = [(0, 0), (40, 60), (70, 40)]
point = (50, 30)

def in_triangle(triangle, point):
    m.fproj_io_core.val2_out.set(triangle[0][0]) 
    m.fproj_io_core.val3_out.set(triangle[0][1]) 
    m.fproj_io_core.val4_out.set(triangle[1][0])
    m.fproj_io_core.val5_out.set(triangle[1][1]) 
    m.fproj_io_core.val6_out.set(triangle[2][0]) 
    m.fproj_io_core.val7_out.set(triangle[2][1]) 
    m.fproj_io_core.val8_out.set(point[0]) 
    m.fproj_io_core.val9_out.set(point[1]) 

in_triangle(triangle, point)
time.sleep(0.01) # wait a little amount...though honestly this is isn't needed since Python is slow.
is_inside = m.fproj_io_core.val1_in.get() # read in the output from our divider
print(f"Values in were {triangle} and {point} with results {bool(is_inside)}.")