cmake_minimum_required(VERSION 3.10)
project(proton_bridge_bootstrap LANGUAGES C)

# The Go library is built and packaged exclusively by hook/build.dart.
add_library(proton_bridge_bootstrap SHARED bootstrap.c)
target_compile_options(proton_bridge_bootstrap PRIVATE -Wall -Wextra -Werror)
