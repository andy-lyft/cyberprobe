
#ifndef HARDWARE_ADDR_UTILS_H
#define HARDWARE_ADDR_UTILS_H

#include <string>

namespace cybermon {
namespace hw_addr_utils {

  // no bounds checking, must be done in caller
  std::string to_string(const uint8_t* addr);

}
}

#endif
