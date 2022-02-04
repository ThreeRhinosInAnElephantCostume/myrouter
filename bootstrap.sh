#!/bin/bash

echo "Installing fish..."

sudo apt update
sudo apt install fish -y

echo "Starting the install script"

sudo ./install.fish


echo "Bootstraping complete"