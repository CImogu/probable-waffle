import numpy as np

cos_table = []

for root2 in range(2):
    for x in range(8):
        for u in range(8):
            cos_table.append(0.5*(1/2**0.25 if root2 else 1)* \
                np.cos(np.pi*(2*x + 1)*u/16)*np.cos(np.pi*(2*y + 1)*v/16))

print(cos_table)