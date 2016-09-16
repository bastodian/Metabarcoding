#!/bin/bash

meh="$(cd "$(dirname "$1")"; pwd)/$(basename "$1")"
echo $meh
