#pragma once

#include "Encoder.hpp"
#include <sys/socket.h>
#include <netinet/in.h>
 #include <arpa/inet.h>
 #include <unistd.h>

const size_t RECV_BUF_SIZE = 1000;

class RTPSender : public Encoder::Listener
{
public:
    RTPSender() : port(1998)
    {
        this->seq_num = rand() % 32768;
        this->ssrc = rand() % 2147483648;

        this->dest_addr.sin_family = AF_INET;
        this->dest_addr.sin_port = htons(this->port);
        inet_pton(AF_INET, "127.0.0.1", &(this->dest_addr.sin_addr));

        this->sock = socket(AF_INET, SOCK_DGRAM, 0);
        if(this->sock == -1) {
            std::cerr << "Error creating socket" << std::endl;
        }
    }

    /*void Initialize()
    {
        std::string sdp = 
            "\r\nv=0\r\n"
            "o=jdoe 3724394400 3724394405 IN IP4 localhost\r\n"
            "s=Test\r\n"
            "t=0 0\r\n"
            "m=video " + std::to_string(this->port) + " RTP/AVP " + std::to_string(Encoder::PayloadType) + "\r\n";
        
        uint16_t msg_hash = this->seq_num;

        BitStream sap_hdr;
        sap_hdr.AddByte(1u << 6); // V, A, R, T, E, C
        sap_hdr.AddByte(0); // auth len
        sap_hdr.AddBytes(&msg_hash, 2); // msg id hash
        sap_hdr.AddBytes({ 127, 0, 0, 1 }); // originating source
        sap_hdr.AddString("application/sdp");
        sap_hdr.AddByte(0);

        BitStream bs;
        bs.AddBitStream(sap_hdr);
        bs.AddString(sdp);

        struct sockaddr_in multicast_addr;
        multicast_addr.sin_family = AF_INET;
        multicast_addr.sin_port = htons(2000);
        inet_pton(AF_INET, "127.0.0.1", &(multicast_addr.sin_addr));

        int r = sendto(this->sock, (void*)&bs.GetBuffer()[0], bs.GetBuffer().size(), 0, (const sockaddr*)&multicast_addr, sizeof(multicast_addr));
        if(r == -1) {
            std::cerr << "ERROR: Failed to send sap announcement" << std::endl;
        }
    }*/

    void OnRTPPacket(BitStream bs_payload, uint32_t timestamp, bool marker) override
    {
        BitStream bs;

        bs.AddByte(1u << 7); // V, P, X, CC
        bs.AddByte((static_cast<uint8_t>(marker) << 7) + (Encoder::PayloadType & ((1u << 7) - 1u))); // M, PT
        bs.AddBytes(&this->seq_num, 2);
        bs.AddBytes(&timestamp, 4);
        bs.AddBytes(&this->ssrc, 4);
        bs.AddBitStream(bs_payload);

        this->seq_num++;

        //std::cout << "Packet:" << std::endl << bs.ToString() << std::endl;
    
        std::vector<uint8_t>& buffer = bs.GetBuffer();
        int res = sendto(this->sock, (void*)(buffer.data()), buffer.size(), 0, (const sockaddr*)&this->dest_addr, sizeof(this->dest_addr));
        if(res == -1) {
            std::cerr << "ERROR: error sending packet: " << errno << std::endl;
        }
    }
protected:
    uint16_t seq_num;
    uint32_t ssrc;
    int sock;
    in_port_t port;
    struct sockaddr_in dest_addr;
};