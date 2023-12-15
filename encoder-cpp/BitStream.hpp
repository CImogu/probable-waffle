#pragma once

#include <vector>
#include <array>
#include <tuple>
#include <iostream>

class BitStream
{
public:
    BitStream() : bytePos(0) { }

    /*BitStream(BitStream& bs) : bytePos(bs.GetBytePos())
    {
        if(bs.GetBuffer().size() > 0) {
            this->buffer.assign(bs.GetBuffer().begin(), bs.GetBuffer().end());
        }
    }*/

   /* BitStream& operator=(BitStream& bs)
    {
        std::cout << "here!" << std::endl;
        std::flush(std::cout);
        this->buffer.assign(bs.GetBuffer().begin(), bs.GetBuffer().end());
        return *this;
    }*/

    void AddBitStream(BitStream b)
    {
        std::vector<uint8_t> o_buffer = b.GetBuffer();
        uint8_t o_bytePos = b.GetBytePos();

        if(o_buffer.size() == 0) {
            return;
        }

        for(size_t i = 0; i < o_buffer.size() - (o_bytePos != 0); i++) {
            this->AddByte(o_buffer[i]);
        }
        for(uint8_t i = 0; i < o_bytePos; i++) {
            this->AddBit(!!(o_buffer[o_buffer.size() - 1] & (1u << (7 - i))));
        }
    }

    void AddBytes(void* data, size_t n)
    {
        // Adds in big-endian order
        for(size_t i = 0; i < n; i++) {
            uint8_t byte = *(reinterpret_cast<uint8_t*>(data) + (n - i) - 1);
            this->AddByte(byte);
        }
    }

    void AddByte(uint8_t b) {
        if(this->bytePos == 0) {
            this->buffer.push_back(b);
        } else {
            this->buffer[this->buffer.size() - 1] += b >> this->bytePos;
            
            this->buffer.push_back((b << (8u - this->bytePos)) & 255u);
        }
    }

    void AddBytes(std::vector<uint8_t> bs)
    {
        for(auto b : bs) {
            this->AddByte(b);
        }
    }
    
    void AddBit(uint8_t b) {
        uint8_t bit = b & 1u;
        if(this->bytePos == 0) {
            this->buffer.push_back(bit << (7 - this->bytePos));
        } else {
            if(bit) {
                this->buffer[this->buffer.size() - 1] =
                    (1u << (7u - this->bytePos)) | this->buffer[this->buffer.size() - 1];
            } else {
                this->buffer[this->buffer.size() - 1] =
                    ~(1u << (7u - this->bytePos)) & this->buffer[this->buffer.size() - 1];
            }
        }
        this->bytePos = (this->bytePos + 1) % 8;
    }

    void AddBits(std::vector<uint8_t> bs)
    {
        for(auto b : bs) {
            this->AddBit(b);
        }
    }

    void AddString(std::string s)
    {
        for(size_t i = 0; i < s.length(); i++) {
            this->AddByte(s[i]);
        }
    }

    void AddStringBits(std::string s)
    {
        for(size_t i = 0; i < s.length(); i++) {
            this->AddBit(s[i] == '1');
        }
    }

    void Clear()
    {
        this->buffer.clear();
        this->bytePos = 0;
    }

    std::vector<uint8_t>& GetBuffer()
    {
        return this->buffer;
    }

    uint8_t GetBytePos()
    {
        return this->bytePos;
    }

    size_t GetLength()
    {
        if(this->bytePos == 0) {
            return this->buffer.size()*8;
        }
        return (this->buffer.size() - 1)*8 + this->bytePos;
    }

    std::string ToString()
    {
        std::string str = "";
        for(size_t i = 0; i < this->GetLength(); i++) {
            str += std::to_string(!!(this->buffer[i/8u] & (1u << (7u - i%8u))));
            if(i % (8*6) == (8*6 - 1)) {
                str += "\n";
            } else if(i % 8 == 7) {
                str += " ";
            }
        }
        return str;
    }

private:
    std::vector<uint8_t> buffer;
    uint8_t bytePos;
};