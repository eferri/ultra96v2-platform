#include "Vtb.h"
#include "verilated.h"

#include <csignal>
#include <cstdlib>
#include <iostream>
#include <memory>

namespace {

void sigint_handler(int signal) {
  if (signal == SIGINT) {
    std::cerr << "SIGINT received, exiting ...\n";
  } else {
    std::cerr << "Unexpected signal " << signal << " received\n";
  }
  std::abort();
}

} // namespace

int main(int argc, char **argv) {
  // Catch ctrl-C (SIGINT)
  auto previous_handler = std::signal(SIGINT, sigint_handler);
  if (previous_handler == SIG_ERR) {
    std::cerr << "Setup failed\n";
    return 1;
  }

  auto contextp = std::make_shared<VerilatedContext>();

  contextp->traceEverOn(true);
  contextp->commandArgs(argc, argv);

  auto top = std::make_shared<Vtb>(contextp.get());

  int status = 0;

  std::cout << "Starting simulation C++...\n";

  // Simulate until $finish
  while (!contextp->gotFinish()) {
    // Evaluate model
    top->eval();

    // Advance time
    if (!top->eventsPending()) {
      break;
    }

    contextp->time(top->nextTimeSlot());
  }

  if (!contextp->gotFinish()) {
    std::cerr << "Exiting without $finish, no events left\n";
    status = 1;
  }

  top->final();

  contextp->statsPrintSummary();

  return status;
}
