# rpi5-image-builder(UPDATED: 2024-02-21)
######################################################################################
# This script builds a SD-Card image for raspberry pi 5 as it follows:
    - Building the rootfile system inside a docker container.
    - Compiling a Custom RPi-Kernel and installing it.
    - Put everything together to create a bootable SD-Card image.

# Installation:
----------------------
    git clone https://github.com/byte4RR4Y/rpi5-image-builder
    cd debian-rpi5-self
    chmod +x ./*
    chmod +x scripts/*
    Using package manager install docker docker-buildx docker-compose and building esentials
----------------------

# To build an SD-Card image follow the instructions after:
    sudo ./build.sh

You will find your image in the output folder.

(If you want to conntrol the build by the commandline type './build.sh -h' for further information)

# Adding custom packages to install
    -If you want to add packages to install, append it to pkg.txt
     instead of modifying the Dockerfile

# What you can build?
DEBIAN:
  - Bookworm


  - XFCE (Not yet tested, report any issues)
