#pragma once

#include <cstdint>
#include <cstddef>
#include <cmath>
#include <iostream>

class Frame
{
public:
    Frame(uint8_t* rgbdata, size_t height, size_t width)
    {
        this->rgbdata = rgbdata;
        this->height = height;
        this->width = width;
    }

    uint8_t* GetYBR()
    {
        uint8_t* data = new uint8_t[this->height*this->width*3];

        for(size_t y = 0; y < this->height; y++) {
            for(size_t x = 0; x < this->width; x++) {
                size_t base = y*this->width*3 + x*3;

                uint8_t y = static_cast<uint8_t>(roundf(219.0*(
                        0.299*(float)this->rgbdata[base]/256.0
                        + 0.587*(float)this->rgbdata[base + 1]/256.0
                        + 0.114*(float)this->rgbdata[base + 2]/256.0
                    ) + 16.0));
                
                uint8_t cb = static_cast<uint8_t>(roundf(224.0*0.564*(
                        - 0.299*(float)this->rgbdata[base]/256.0
                        - 0.587*(float)this->rgbdata[base + 1]/256.0
                        + 0.886*(float)this->rgbdata[base + 2]/256.0
                    ) + 128.0));
                
                uint8_t cr = static_cast<uint8_t>(roundf(224.0*0.713*(
                        0.701*(float)this->rgbdata[base]/256.0
                        - 0.587*(float)this->rgbdata[base + 1]/256.0
                        - 0.114*(float)this->rgbdata[base + 2]/256.0
                    ) + 128.0));

                data[base] = y;
                data[base + 1] = cb;
                data[base + 2] = cr;
            }
        }

        return data;
    }

    size_t GetWidth()
    {
        return this->width;
    }

    size_t GetHeight()
    {
        return this->height;
    }

private:
    uint8_t* rgbdata;
    size_t height, width;
};