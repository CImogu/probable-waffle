#include "Encoder.hpp"
#include "Frame.hpp"
#include "RTPSender.hpp"
#include <chrono>

int main(int argc, char** argv) {
    size_t height = 288;
    size_t width = 352;

    srand(101);

    Encoder encoder;

    RTPSender* rtpSender = new RTPSender();    

    encoder.AddListener(rtpSender);

    double overshoot = 0.0; // us

    for(size_t a = 0; a < 10000; a++) {
        auto t = std::chrono::high_resolution_clock::now();

        uint8_t* rgbdata = new uint8_t[height*width*3];

        for(size_t i = 0; i < height; i++) {
            for(size_t j = 0; j < width; j++) {
                rgbdata[(width*i + j)*3 + 0] = 8*a % 256;
                rgbdata[(width*i + j)*3 + 1] = 16*(i % 16);
                rgbdata[(width*i + j)*3 + 2] = 16*(j % 16);
            }
        }

        Frame* f = new Frame(rgbdata, height, width);

        encoder.ReceiveFrame(f);

        auto t2 = std::chrono::high_resolution_clock::now();
        double elapsed = std::chrono::duration<double, std::micro>(t2 - t).count();
        double desired = 1000000.0*(1001.0/30000.0);

        if(elapsed + overshoot < desired) {
            usleep(desired - elapsed - overshoot);
        } else {
            overshoot += elapsed - desired;
        }

        auto t3 = std::chrono::high_resolution_clock::now();
     //   std::cout << std::chrono::duration<double, std::milli>(t3 - t).count() << "ms" << std::endl;
    }

    //std::cout << bs.ToString() << std::endl;

    return 0;
}