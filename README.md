# Android Common Kernel Buildsystem

## Overview
------------

This is a buildsystem for building Android Common Kernels. It provides a flexible and customizable way to build kernels for various Android devices.

## Features
------------

* Supports building kernels for multiple devices
* Support for overlaying core functions via `Kitchen/functions/functions-overlay.sh`
* Allows customization of kernel configurations and build options via `append_config`
* Support for CI Building via script flags. Check `-h` for available flags.
* Support for automatically downloading defined toolchains
* Supports building boot.img files

## Configuration
---------------

The buildsystem uses a configuration file to define build options and kernel configurations. An example configuration file is provided in `Kitchen/profiles/flavour-stub.sh`. You will need to create your own configuration file based on this example, tailored to your specific build requirements.

## Requirements
------------ 
* **Operating System**: Linux or Windows Subsystem For Linux
* **Target Kernel Version**: Linux 4.14 or older for now.
* **Software Dependencies**: Distro Provided Linux Build Tools, Bash

## License
-------

**This buildsystem is released under the GNU General Public License version 2.**

**A copy of this license has been left in the source**