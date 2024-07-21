#include "Vtop.h"

#include <memory>

int main(int argc, char **argv)
{
    auto contextp = std::make_shared<VerilatedContext>();
    contextp->commandArgs(argc, argv);

    auto top = std::make_shared<Vtop>(contextp.get());

    while (!contextp->gotFinish())
    {
        top->eval();
    }
    return 0;
}
