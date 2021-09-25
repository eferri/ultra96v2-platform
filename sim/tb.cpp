#include <cstdint>
#include <memory>

#include <verilated.h>

#include "Vverilator_top.h"

int main(int argc, char **argv)
{
    Verilated::mkdir("logs");

    auto context = std::make_unique<VerilatedContext>();

    context->debug(0);
    context->randReset(2);
    context->traceEverOn(true);
    context->commandArgs(argc, argv);

    auto counter = std::make_unique<Vverilator_top>();

    while (!context->gotFinish() && context->time() < (2 * 1000))
    {
        context->timeInc(1);

        counter->clk = !counter->clk;

        if (!counter->clk)
        {
            if (context->time() > 10)
            {
                counter->reset = 0;
            }
        }
        counter->eval();
    }
    counter->final();
    return 0;
}
