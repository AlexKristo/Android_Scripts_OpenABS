#!/bin/bash
#
# This script is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License version 2
# as published by the Free Software Foundation.
#
# This script is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License v2
# along with this script; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
# Author: Alex Kristo <202012252+AlexKristo@users.noreply.github.com>
# Date: 6th of July, 2025
#

# This is a stub overlay for functions header
# Modify this as you need..
# You can overlay core functions here, modify the way they work..
# For example

# Original Function defined in functions.sh
err() {
    echo "ERROR: $1"
}

# Function redefined here
err() {
    echo "ERROR: $1"
    exit 1
}