#pragma once

#include "Frame.hpp"
#include "BitStream.hpp"
#include <vector>
#include <array>
#include <tuple>
#include <iostream>
#include <chrono>

class Encoder
{
public:
    Encoder() : frameCount(0), isOnlyIntra(true), maxPacketLengthBits(10000)
    {
        this->timestamp_offset = rand() % 2147483648;
    }

    void ReceiveFrame(Frame* frame)
    {
        // Send every 4 frames (7.5 fps)
        
        last_m_bs.Clear();

        uint8_t* ybrdata = frame->GetYBR();

        size_t width = frame->GetWidth();
        size_t height = frame->GetHeight();

        bool isIntra = this->isOnlyIntra; // || this->frameCount % 132 == 0;

        // Use QCIF
        size_t s_height = 144;
        size_t s_width = 176;

        std::vector<uint16_t> sampled_Y = this->SampleDataTuples(ybrdata, width, height, s_width, s_height, 0);
        std::vector<uint16_t> sampled_Cb = this->SampleDataTuples(ybrdata, width, height, s_width/2, s_height/2, 1);
        std::vector<uint16_t> sampled_Cr = this->SampleDataTuples(ybrdata, width, height, s_width/2, s_height/2, 2);
        SampledFrame sampled = {sampled_Y, sampled_Cb, sampled_Cr};
      
        SampledFrame sampled_diff = sampled;
        if(!isIntra && this->lastSampled[0].size() > 0) {
            sampled_diff = this->GetFrameDiff(sampled, this->lastSampled);
        }
        this->lastSampled = sampled;

        std::vector<MacroBlock> mbs = this->GetMacroBlocks(sampled, s_height, s_width);

        // Optional: motion compensation, spatial filter
        // Optional: filter blocks
        // Optional: other QUANT values besides 8
        // Optional: other intra/inter strategies

        uint8_t gquant = 8;

        BitStream bs;

        bs.AddBytes({ 0, 1 }); // PSC
        bs.AddByte((this->frameCount & 31u) >> 1); // PSC, TR
        bs.AddByte(((this->frameCount & 1u) << 7) + (1u << 4) + (1u << 2) + (1u << 1)); // TR, PTYPE, PEI

        size_t numMBsinPacket = 0;
        size_t gob_num = 0;
        size_t last_mba_abs = 0;
        bool beginsWithGobHeader = true;

        for(size_t gob_idx = 0; gob_idx < 3; gob_idx++) {
            gob_num = 2*gob_idx + 1;

            BitStream gob_bs;

            size_t prev_mba_abs = 0;
            last_mba_abs = 0;
            if(numMBsinPacket == 0) {
                beginsWithGobHeader = true;
            }
            gob_bs.AddBytes({ 0, 1 }); // GBSC
            gob_bs.AddByte((gob_num << 4) + (gquant >> 1)); // GQUANT
            gob_bs.AddBit(gquant & 1u); // GQUANT
            gob_bs.AddBit(0); // GEI

            /*if(this->frameCount % 8 != 0) {
                bs.AddBitStream(gob_bs);
                continue;
            }*/

            //bs.AddBitStream(gob_bs);
            //std::string payload = "100010110010010011001001001100100100110010010011001001001100100101000101100100100110010010011001001001100100100110010010011001001010001011001001001100100100110010010011001001001100100100110010010100010110010010011001001001100100100110010010011001001001100100101000101100100100110010010011001001001100100100110010010011001001010001011001001001100100100110010010011001001001100100100110010010100010110010010011001001001100100100110010010011001001001100100101000101100100100110010010011001001001100100100110010010011001001010001011001001001100100100110010010011001001001100100100110010010100010110010010011001001001100100100110010010011001001001100100101000101100100100110010010011001001001100100100110010010011001001010001011001001001100100100110010010011001001001100100100110010010100010110010010011001001001100100100110010010011001001001100100101000101100100100110010010011001001001100100100110010010011001001010001011001001001100100100110010010011001001001100100100110010010100010110010010011001001001100100100110010010011001001001100100101000101100100100110010010011001001001100100100110010010011001001010001011001001001100100100110010010011001001001100100100110010010100010110010010011001001001100100100110010010011001001001100100101000101100100100110010010011001001001100100100110010010011001001010001011001001001100100100110010010011001001001100100100110010010100010110010010011001001001100100100110010010011001001001100100101000101100100100110010010011001001001100100100110010010011001001010001011001001001100100100110010010011001001001100100100110010010100010110010010011001001001100100100110010010011001001001100100101000101100100100110010010011001001001100100100110010010011001001010001011001001001100100100110010010011001001001100100100110010010100010110010010011001001001100100100110010010011001001001100100101000101100100100110010010011001001001100100100110010010011001001010001011001001001100100100110010010011001001001100100100110010010100010110010010011001001001100100100110010010011001001001100100101000101100100100110010010011001001001100100100110010010011001001010001011001001001100100100110010010011001001001100100100110010010";
            //std::cout << payload.length() << std::endl;
            //bs.AddStringBits(payload);
            //continue;

            bool firstMB = true;

            // TODO: filter inter macroblocks that are all 0's, adjust MBA accordingly
            for(size_t i = 33*gob_idx; i < 33*(gob_idx + 1); i++) {
                BitStream m_bs;
                
                size_t mba_abs = (i - 33*gob_idx) + 1;

                if(last_m_bs.GetLength() == 0) {
                    MacroBlock& mb = mbs[i];

                    mb.TransformAndQuantize(isIntra);

                    m_bs.AddBit(1); // MBA
                    if(isIntra) { // MTYPE
                        m_bs.AddBits({ 0, 0, 0, 1 });
                    } else {
                        m_bs.AddBit(1);
                        // TODO: filter inter blocks that are all zeros, adjust CBP accordingly
                        // m_bs.AddBits({ 0, 0, 1, 1, 0, 0 }); // CBP
                    }

                    // Blocks
                    for(size_t i = 0; i < 4; i++) {
                        m_bs.AddBitStream(mb.GetYBlock(i).GetBitStream(isIntra));
                    }
                    m_bs.AddBitStream(mb.GetCbBlock().GetBitStream(isIntra));
                    m_bs.AddBitStream(mb.GetCrBlock().GetBitStream(isIntra));
                    
                    this->last_m_bs = m_bs;
                } else {
                    m_bs = this->last_m_bs;
                }

                if(bs.GetLength() + m_bs.GetLength() + (firstMB ? gob_bs.GetLength() : 0) > this->maxPacketLengthBits) {
                    this->SendPacket(bs, last_mba_abs, gquant, gob_num, beginsWithGobHeader, false);
                    bs.Clear();
                    beginsWithGobHeader = firstMB;
                    numMBsinPacket = 1;
                    last_mba_abs = prev_mba_abs;
                } else {
                    numMBsinPacket++;
                }

                if(firstMB) {
                    bs.AddBitStream(gob_bs);
                }
                bs.AddBitStream(m_bs);
                firstMB = false;

                prev_mba_abs = mba_abs;
            }
        }

        //std::cout << "yes total length:" << bs.GetLength() << std::endl;

        if(bs.GetLength() > 0) {
            beginsWithGobHeader = true;
            gquant = 0;
            this->SendPacket(bs, last_mba_abs, gquant, gob_num, beginsWithGobHeader, true);
        }

        this->frameCount++;

        //std::cout << this->frameCount << std::endl;
    }

    class Listener
    {
    public:
        virtual void OnRTPPacket(BitStream bs, uint32_t timestamp, bool marker) = 0;
    };

    void AddListener(Listener* listener)
    {
        this->listeners.push_back(listener);
    }
 
    static const uint8_t PayloadType = 31u;

protected:
    BitStream last_m_bs;

    typedef std::array<std::array<uint16_t, 8>,8> BlockData;

    typedef std::array<std::vector<uint16_t>,3> SampledFrame;

    bool isOnlyIntra;
    size_t maxPacketLengthBits;
    uint32_t timestamp_offset;

    void SendPacket(BitStream data, size_t last_mba_abs, size_t quant, size_t gob_num, bool beginsWithGobHeader, bool isLastInFrame)
    {
        BitStream bs;

        if(beginsWithGobHeader) {
            last_mba_abs = 0;
            quant = 0;
            gob_num = 0;
        } else {
            if(last_mba_abs != 0) {
                last_mba_abs -= 1; // TODO: check
            }
        }

        //std::cout << data.ToString() << std::endl;
        //std::cout << gob_num << last_mba_abs << std::endl;
        // H.261 Header
        bs.AddByte((((8u - data.GetBytePos()) & 7u) << 2) + 2u*this->isOnlyIntra); // SBIT, EBIT, I, V
        bs.AddByte(((gob_num & 15u) << 4) + ((last_mba_abs >> 1) & 15u)); // GOB, MBAP
        bs.AddBit(last_mba_abs & 1u); // MBAP
        bs.AddByte((quant & 31u) << 3); // QUANT, HMVD
        bs.AddBits({ 0, 0, 0, 0, 0, 0, 0 }); // HMVD, VMVD

        // Payload
        bs.AddBitStream(data);

        //std::cout << "Send packet" << std::endl;

        uint32_t timestamp = this->timestamp_offset + this->frameCount*3*1001; // 90 kHz clock

        for(auto listener : this->listeners) {
            listener->OnRTPPacket(bs, timestamp, isLastInFrame);
        }
    }

    class Block
    {
    public:
        Block() { }

        Block(BlockData& data)
        {
            this->SetData(data);
        }

        void SetData(BlockData& data)
        {
            this->data = data;
        }

        void SetLine(size_t idx, std::vector<uint16_t>::iterator begin)
        {
            std::copy(begin, begin + 8, this->data[idx].begin());
        }

        BlockData& GetData()
        {
            return this->data;
        }

        void TransformAndQuantize(bool isIntra)
        {
            BlockData out_data;

            for(size_t u = 0; u < 8; u++) {
                for(size_t v = 0; v < 8; v++) {
                    double Cu = u == 0.0 ? 0.707107 : 1;
                    double Cv = v == 0.0 ? 0.707107 : 1;
                    double val = 0.0;
                    for(size_t x = 0; x < 8; x++) {
                        for(size_t y = 0; y < 8; y++) {
                            val += 0.25*Cu*Cv*this->data[y][x]
                                *cos(M_PI*(2.0*static_cast<double>(x)+1.0)*static_cast<double>(u)/16.0)
                                *cos(M_PI*(2.0*static_cast<double>(y)+1.0)*static_cast<double>(v)/16.0);
                        }
                    }

                    int16_t ival = static_cast<int16_t>(round(val));
                    ival = ival > 2047 ? 2047 : (ival < -2048 ? -2048 : ival);

                    // Quantize
                    if(isIntra && u == 0 && v == 0) { 
                        out_data[u][v] = ival/8 == 128 ? 255 : ival/8; // First coefficint in intra block
                    } else {
                        // Using quant 8 for now
                        out_data[u][v] = (ival - 7*(2*(ival >= 0) - 1))/16;
                        // 16*level = rec - 7*sign(rec)
                    }
                }
            }

            this->data = out_data;
        }

        BitStream GetBitStream(bool isIntra)
        {
            BitStream bs;

            size_t run = 0;

            // Zig zag

            // left top half
            size_t idx = 0;
            for(size_t line = 0; line < 8; line++) {
                bool up = line % 2 == 0;
                for(size_t i = 0; i < line + 1; i++) {
                    size_t x = up ? i : (line - i);
                    size_t y = up ? (line - i) : i;
                    BitStream vlc = this->GetVLC(static_cast<int8_t>(this->data[y][x]), idx, &run, isIntra);
                    bs.AddBitStream(vlc);
                    idx++;
                }
            }

            // bottom right half
            for(size_t line_x = 1; line_x < 8; line_x++) {
                bool up = line_x % 2 == 1;
                for(size_t i = 0; i < (8 - line_x); i++) {
                    size_t x = up ? line_x + i : (7 - i);
                    size_t y = up ? (7 - i) : line_x + i;
                    bs.AddBitStream(this->GetVLC(static_cast<int8_t>(this->data[y][x]), idx, &run, isIntra));
                    idx++;
                }
            }

            if(bs.GetLength() == 0) {
                std::cerr<< "ERROR: sending block with no data" << std::endl;
            }

            bs.AddBits({ 1, 0 }); // EOB

            return bs;
        }
    private:
        BitStream GetVLC(int8_t level, size_t idx, size_t* run, bool isIntra)
        {
            BitStream bs;

            level = 10;

            if(idx == 0 && isIntra) {
                bs.AddByte(static_cast<uint8_t>(level));
            } else {
                uint8_t abslevel = abs(level);
                uint8_t sign = level >> 7;
                if(idx == 0 && abslevel == 1) {
                    bs.AddBits({ 1, sign });
                } else if(level == 0) {
                    *run = *run + 1;
                } else {
                    BitStream tcoeff = TcoeffTable::Get(*run, level);
                   // std::cout << tcoeff.ToString() << std::endl;
                    *run = 0;
                    bs.AddBitStream(tcoeff);
                }
            }

            return bs;
        }

        BlockData data;
    };

    class TcoeffTable
    {
    public:
        static BitStream Get(size_t run, int8_t level) {
            BitStream bs;

            uint8_t abslevel = abs(level);
            uint8_t sign = level >> 7;

            switch(run) {
            case 0:
                switch(abslevel) {
                case 1:
                    bs.AddBits({ 1, 1 });
                    break;
                case 2:
                    bs.AddBits({ 0, 1, 0, 0 });
                    break;
                case 3:
                    bs.AddBits({ 0, 0, 1, 0, 1 });
                    break;
                case 4:
                    bs.AddBits({ 0, 0, 0, 0, 1, 1, 0 });
                    break;
                case 5:
                    bs.AddByte(38);
                    break;
                case 6:
                    bs.AddByte(33);
                    break;
                case 7:
                    bs.AddByte(2);
                    bs.AddBits({ 1, 0 });
                    break;
                case 8:
                    bs.AddByte(1);
                    bs.AddBits({ 1, 1, 0, 1 });
                    break;
                case 9:
                    bs.AddByte(1);
                    bs.AddBits({ 1, 0, 0, 0 });
                    break;
                case 10:
                    bs.AddByte(1);
                    bs.AddBits({ 0, 0, 1, 1 });
                    break;
                case 11:
                    bs.AddByte(1);
                    bs.AddBits({ 0, 0, 0, 0 });
                    break;
                case 12:
                    bs.AddByte(0);
                    bs.AddBits({ 1, 1, 0, 1, 0 });
                    break;
                case 13:
                    bs.AddByte(0);
                    bs.AddBits({ 1, 1, 0, 0, 1 });
                    break;
                case 14:
                    bs.AddByte(0);
                    bs.AddBits({ 1, 1, 0, 0, 0 });
                    break;
                case 15:
                    bs.AddByte(0);
                    bs.AddBits({ 1, 0, 1, 1, 1 });
                    break;
                default:
                    goto uncommon;
                };
                break;
            case 1:
                switch(abslevel) {
                case 1:
                    bs.AddBits({ 0, 1, 1 });
                    break;
                case 2:
                    bs.AddBits({ 0, 0, 0, 1, 1, 0 });
                    break;
                case 3:
                    bs.AddByte(37);
                    break;
                case 4:
                    bs.AddByte(3);
                    bs.AddBits({ 0, 0 });
                    break;
                case 5:
                    bs.AddByte(1);
                    bs.AddBits({ 1, 0, 1, 1 });
                    break;
                case 6:
                    bs.AddByte(0);
                    bs.AddBits({ 1, 0, 1, 1, 0 });
                    break;
                case 7:
                    bs.AddByte(0);
                    bs.AddBits({ 1, 0, 1, 0, 1 });
                    break;
                default:
                    goto uncommon;
                };
                break;
            case 2:
                switch(abslevel) {
                case 1:
                    bs.AddBits({ 0, 1, 0, 1 });
                    break;
                case 2:
                    bs.AddBits({ 0, 0, 0, 0, 1, 0, 0 });
                    break;
                case 3:
                    bs.AddByte(2);
                    bs.AddBits({ 1, 1 });
                    break;
                case 4:
                    bs.AddByte(1);
                    bs.AddBits({ 0, 1, 0, 0 });
                    break;
                case 5:
                    bs.AddByte(0);
                    bs.AddBits({ 1, 0, 1, 0, 0 });
                    break;
                default:
                    goto uncommon;
                };
                break;
            case 3:
                switch(abslevel) {
                case 1:
                    bs.AddBits({ 0, 0, 1, 1, 1 });
                    break;
                case 2:
                    bs.AddByte(36);
                    break;
                case 3:
                    bs.AddByte(1);
                    bs.AddBits({ 1, 1, 0, 0 });
                    break;
                case 4:
                    bs.AddByte(0);
                    bs.AddBits({ 1, 0, 0, 1, 1 });
                    break;
                default:
                    goto uncommon;
                };
                break;
            case 4:
                switch(abslevel) {
                case 1:
                    bs.AddBits({ 0, 0, 1, 1, 0 });
                    break;
                case 2:
                    bs.AddByte(3);
                    bs.AddBits({ 1, 1 });
                    break;
                case 3:
                    bs.AddByte(1);
                    bs.AddBits({ 0, 0, 1, 0 });
                    break;
                default:
                    goto uncommon;
                };
                break;
            case 5:
                switch(abslevel) {
                case 1:
                    bs.AddBits({ 0, 0, 0, 1, 1, 1 });
                    break;
                case 2:
                    bs.AddByte(2);
                    bs.AddBits({ 0, 1 });
                    break;
                case 3:
                    bs.AddByte(0);
                    bs.AddBits({ 1, 0, 0, 1, 0 });
                    break;
                default:
                    goto uncommon;
                };
                break;
            case 6:
                switch(abslevel) {
                case 1:
                    bs.AddBits({ 0, 0, 0, 1, 0, 1 });
                    break;
                case 2:
                    bs.AddByte(1);
                    bs.AddBits({ 1, 1, 1, 0 });
                    break;
                default:
                    goto uncommon;
                };
                break;
            case 7:
                switch(abslevel) {
                case 1:
                    bs.AddBits({ 0, 0, 0, 1, 0, 0 });
                    break;
                case 2:
                    bs.AddByte(1);
                    bs.AddBits({ 0, 1, 0, 1 });
                    break;
                default:
                    goto uncommon;
                };
                break;
            case 8:
                switch(abslevel) {
                case 1:
                    bs.AddBits({ 0, 0, 0, 0, 1, 1, 1 });
                    break;
                case 2:
                    bs.AddByte(1);
                    bs.AddBits({ 0, 0, 0, 1 });
                    break;
                default:
                    goto uncommon;
                };
                break;
            case 9:
                switch(abslevel) {
                case 1:
                    bs.AddBits({ 0, 0, 0, 0, 1, 0, 1 });
                    break;
                case 2:
                    bs.AddByte(0);
                    bs.AddBits({ 1, 0, 0, 0, 1 });
                    break;
                default:
                    goto uncommon;
                };
                break;
            case 10:
                switch(abslevel) {
                case 1:
                    bs.AddByte(39);
                    break;
                case 2:
                    bs.AddByte(0);
                    bs.AddBits({ 1, 0, 0, 0, 0 });
                    break;
                default:
                    goto uncommon;
                };
                break;
            case 11:
                if(abslevel == 1) {
                    bs.AddByte(35);
                    break;
                }
                goto uncommon;
            case 12:
                if(abslevel == 1) {
                    bs.AddByte(34);
                    break;
                }
                goto uncommon;
            case 13:
                if(abslevel == 1) {
                    bs.AddByte(32);
                    break;
                }
                goto uncommon;
            case 14:
                if(abslevel == 1) {
                    bs.AddByte(3);
                    bs.AddBits({ 1, 0 });
                    break;
                }
                goto uncommon;
            case 15:
                if(abslevel == 1) {
                    bs.AddByte(3);
                    bs.AddBits({ 0, 1 });
                    break;
                }
                goto uncommon;
            case 16:
                if(abslevel == 1) {
                    bs.AddByte(2);
                    bs.AddBits({ 0, 0 });
                    break;
                }
                goto uncommon;
            case 17:
                if(abslevel == 1) {
                    bs.AddByte(1);
                    bs.AddBits({ 1, 1, 1, 1 });
                    break;
                }
                goto uncommon;
            case 18:
                if(abslevel == 1) {
                    bs.AddByte(1);
                    bs.AddBits({ 1, 0, 1, 0 });
                    break;
                }
                goto uncommon;
            case 19:
                if(abslevel == 1) {
                    bs.AddByte(1);
                    bs.AddBits({ 1, 0, 0, 1 });
                    break;
                }
                goto uncommon;
            case 20:
                if(abslevel == 1) {
                    bs.AddByte(1);
                    bs.AddBits({ 0, 1, 1, 1 });
                    break;
                }
                goto uncommon;
            case 21:
                if(abslevel == 1) {
                    bs.AddByte(1);
                    bs.AddBits({ 0, 1, 1, 0 });
                    break;
                }
                goto uncommon;
            case 22:
                if(abslevel == 1) {
                    bs.AddByte(0);
                    bs.AddBits({ 1, 1, 1, 1, 1 });
                    break;
                }
                goto uncommon;
            case 23:
                if(abslevel == 1) {
                    bs.AddByte(0);
                    bs.AddBits({ 1, 1, 1, 1, 0 });
                    break;
                }
                goto uncommon;
            case 24:
                if(abslevel == 1) {
                    bs.AddByte(0);
                    bs.AddBits({ 1, 1, 1, 0, 1 });
                    break;
                }
                goto uncommon;
            case 25:
                if(abslevel == 1) {
                    bs.AddByte(0);
                    bs.AddBits({ 1, 1, 1, 0, 0 });
                    break;
                }
                goto uncommon;
            case 26:
                if(abslevel == 1) {
                    bs.AddByte(0);
                    bs.AddBits({ 1, 1, 0, 1, 1 });
                    break;
                }
                goto uncommon;
            };

            bs.AddBit(sign);

            return bs;

        uncommon:
            bs.AddBits({ 0, 0, 0, 0 }); // Escape
            bs.AddByte((1u << 6) + (run & ((1u << 6) - 1u)));
            if(level == -127) {
                std::cerr << "ERROR: sending invalid level -127" << std::endl;
            }
            bs.AddByte(level);

            if (bs.GetLength() > 0)
                std::cout << bs.ToString() << std::endl;

            return bs;
        }
    };

    class MacroBlock
    {
    public:
        MacroBlock(std::array<Block,4>& Yblocks, Block& CbBlock, Block& CrBlock)
        {
            for(int i = 0; i < 4; i++)
            {
                this->Yblocks[i].SetData(Yblocks[i].GetData());
            }
            this->CbBlock.SetData(CbBlock.GetData());
            this->CrBlock.SetData(CrBlock.GetData());
        }

        void SetCbBlock(Block block)
        {
            this->CbBlock.SetData(block.GetData());
        }

        Block& GetCbBlock()
        {
            return this->CbBlock;
        }

        void SetCrBlock(Block block)
        {
            this->CrBlock.SetData(block.GetData());
        }

        Block& GetCrBlock()
        {
            return this->CrBlock;
        }

        void SetYBlock(size_t idx, Block block)
        {
            this->Yblocks[idx].SetData(block.GetData());
        }

        Block& GetYBlock(size_t idx)
        {
            return this->Yblocks[idx];
        }

        void TransformAndQuantize(bool isIntra)
        {
            for(size_t i = 0; i < 4; i++) {
                this->Yblocks[i].TransformAndQuantize(isIntra);
            }
            this->CbBlock.TransformAndQuantize(isIntra);
            this->CrBlock.TransformAndQuantize(isIntra);
        }


    private:
        std::array<Block,4> Yblocks;
        Block CbBlock;
        Block CrBlock;
    };

    std::vector<MacroBlock> GetMacroBlocks(SampledFrame& sampled, size_t nsamples_x, size_t nsamples_y)
    {
        std::vector<MacroBlock> mbs;

        size_t nmb_y = nsamples_y/16;
        size_t nmb_x = nsamples_x/16;

        for(size_t mb_y = 0; mb_y < nmb_y; mb_y++) {
            for(size_t mb_x = 0; mb_x < nmb_x; mb_x++) {
                std::array<Block,4> Yblocks;
                for(size_t yblock_y = 0; yblock_y < 2; yblock_y++) {
                    for(size_t yblock_x = 0; yblock_x < 2; yblock_x++) {
                        for(size_t line_i = 0; line_i < 8; line_i++) {
                            size_t line_start = (mb_y*nmb_x + mb_x)*16 + (yblock_y*nsamples_x + yblock_x)*8 + line_i*nsamples_x;
                            Yblocks[yblock_y*2 + yblock_x].SetLine(line_i, sampled[0].begin() + line_start);
                        }
                    }
                }
                Block Cbblock, Crblock;
                for(size_t line_i = 0; line_i < 8; line_i++) {
                    size_t line_start = (mb_y*nmb_x + mb_x)*8 + line_i*(nsamples_x/2);
                    Cbblock.SetLine(line_i, sampled[1].begin() + line_start);
                    Crblock.SetLine(line_i, sampled[2].begin() + line_start);
                }
                mbs.push_back(MacroBlock(Yblocks, Cbblock, Crblock));
            }
        }

        return mbs;
    }

    SampledFrame GetFrameDiff(SampledFrame& fa, SampledFrame& fb)
    {
        SampledFrame out;

        for(size_t i = 0; i < 3; i++) {
            for(size_t j = 0; j < fa[i].size(); j++) {
                int16_t val = static_cast<int16_t>(fa[i][j]) - static_cast<int16_t>(fa[i][j]);
                out[i].push_back(val > 255 ? 255 : (val < -256 ? -256 : val));
            }
        }

        return out;
    }

    std::vector<uint16_t> SampleDataTuples(uint8_t* data, size_t data_width, size_t data_height, size_t nsamples_x, size_t nsamples_y, size_t tuple_idx, size_t tuple_size=3)
    {
        float y_c = static_cast<float>(data_height)/static_cast<float>(nsamples_y);
        float x_c = static_cast<float>(data_width)/static_cast<float>(nsamples_x);

        std::vector<uint16_t> sampled_out(nsamples_y*nsamples_x);

        for(size_t y = 0; y < nsamples_y; y++) {
            for(size_t x = 0; x < nsamples_x; x++) {
                size_t s_y = static_cast<size_t>(roundf(y_c*(0.5 + static_cast<float>(y))));
                size_t s_x = static_cast<size_t>(roundf(x_c*(0.5 + static_cast<float>(x))));

                size_t base = y*nsamples_x + x;
                size_t s_base = (s_y*data_width + s_x)*tuple_size;

                sampled_out[base] = static_cast<uint16_t>(data[s_base + tuple_idx]);
            }
        }

        return sampled_out;
    }

    std::vector<Listener*> listeners;

    SampledFrame lastSampled;

    size_t frameCount;
};