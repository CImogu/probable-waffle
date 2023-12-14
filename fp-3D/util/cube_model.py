from ieee754 import single
import numpy as np

#https://www.researchgate.net/figure/Scheme-for-the-numerical-representation-of-a-cube-The-Vertices-matrix-contains-the_fig1_233375602

unit_cube = np.array([
    [0, 0, 0],
    [1, 0, 0],
    [1, 0, 1],
    [0, 0, 1],
    [0, 1, 0],
    [1, 1, 0],
    [1, 1, 1],
    [0, 1, 1]
    ])

# zero z-coordinates dangerous because camera ray and screen parallel
def translate(dir):
    def shift(x):
        return list(i + j for i, j in zip(x, dir))
    return shift 

shifted_uc = np.apply_along_axis(translate((0, 0, 1)), axis=1, arr=unit_cube)

size = 10
def rot_x(angle):
    return np.array([
        [1, 0, 0],
        [0, np.cos(angle), np.sin(angle)],
        [0, -np.sin(angle), np.cos(angle)]
    ])

def rot_y(angle):
    return np.array([
        [np.cos(angle), 0, -np.sin(angle)],
        [0, 1, 0],
        [np.sin(angle), 0, np.cos(angle)],
    ])

def rot_z(angle):
    return np.array([
        [np.cos(angle), np.sin(angle), 0],
        [-np.sin(angle), np.cos(angle), 0],
        [0, 0, 1]
    ])

angle = np.pi/4
shifted = np.matmul(shifted_uc, rot_x(angle)).tolist()

# need to generate triangles -> S[0] to S[2] forms a diagonal
surface = [ 
    [1, 2, 3, 4],
    [5, 6, 7, 8], 
    [2, 3, 7, 6],
    [3, 4, 8, 7], 
    [1, 4, 8, 5],
    [1, 2, 6, 5]
]

scale_clip = lambda x: single(round(x * size)).hex()[0] #scaled by 5

# generate triangles, for each surface
triangles = [] # points represented as tuple, triangles as list of tuples
for s in surface:
    first = [tuple(shifted[ix-1]) for ix in s[:3]]
    second = [tuple(shifted[ix-1]) for ix in ([s[0]] + s[2:])]
    triangles.extend([first, second])

# write to file
with open('model.mem', 'w') as f:
    for triangle in triangles:
        w_str = ''
        for vertex in triangle:
            w_str += ''.join((scale_clip(x) for x in vertex))
        f.write(w_str+'\n')
