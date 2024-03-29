#!/usr/bin/python
import lgpio
import time
import json
import io
import os
import os.path
import argparse
import subprocess
import sys
import pathlib

READ_RETRIES = 5
READ_FAIL_DELAY = 1

TEMP_PATH = "/sys/class/thermal/thermal_zone0/temp"
CONFIG_PATH_REQ_DIRS = ["/etc/fancontrol"]
CONFIG_PATH = "/etc/fancontrol/fancontrol.config.json"
DEFAULT_CONFIG_PATH = "fancontrol.default.json"

DELAY=2

ADDRESS=0x42

DRYDEFAULT = False

def bash(commandline:str, quiet=False, dry=DRYDEFAULT):
    if(type(commandline) is not list):
        commandline = commandline.split(" ")
    if(not quiet):
        print(" ".join(commandline))
    if not dry:
        return subprocess.run(commandline)
    return ""

i2c = lgpio.i2c_open(1, ADDRESS)

def set_power(v: float):
    if v > 1.0 or v < 0:
        raise Exception("Power must be in range from 0.0 to 1.0")
    n = int(v * 255)
    if(v > 0 and n == 0):
        n = 1
    lgpio.i2c_write_byte(i2c, n)
    
# <<-------------------->> 
#       LOGIC  START
# <<-------------------->> 

parser = argparse.ArgumentParser(description="Fancontrol: Control a fan over I2C")
parser.add_argument("--set-power", dest="power", type=float, nargs="?")
args = parser.parse_args()

if(args.power is not None):
    set_power(args.power)
    exit(0)

if(not os.path.isfile(CONFIG_PATH)):
    print("Config not found, copying:")
    for it in CONFIG_PATH_REQ_DIRS:
        bash("sudo mkdir " + str(it))
    bash("sudo cp " + DEFAULT_CONFIG_PATH + " " + CONFIG_PATH)
    if(not os.path.isfile(CONFIG_PATH)):
        print("ERROR: Could not copy config, ensure", CONFIG_PATH, "and", DEFAULT_CONFIG_PATH, "exist")
        exit(1)
while(True):
    i2c = lgpio.i2c_open(1, ADDRESS)
    jsondata = ""

    readfails = 0
    while True:
        try:
            with open(CONFIG_PATH) as file:
                jsondata = file.read()
            break
        except:
            readfails += 1
            print("Error reading", CONFIG_PATH)
            if(readfails < READ_RETRIES):
                print("Trying again in", READ_FAIL_DELAY, "seconds")
                time.sleep(READ_FAIL_DELAY)
            else:
                print("Failed to read", CONFIG_PATH, "aborting...")
                exit(1)

    config = json.loads(jsondata, parse_int=float)
    mintemp = config["min_temperature"]
    if not isinstance(mintemp, float):
        print("No min_temperature specified")
        exit(1)
    curve = config["curve"]
    if not isinstance(curve, list):
        print("No curve specified/curve is not a list")
        exit(1)
    for p in curve:
        if not isinstance(p, list) or len(p) != 2 or not isinstance(p[0], float) or not isinstance(p[1], float):
            print("All elements of the curve must be arrays of two floats (temp, power)")
            exit(1)
    temp = 0

    readfails = 0
    while True:
        try: 
            temp = float(subprocess.check_output(["cat", TEMP_PATH]))/1000.0
            break
        except:
            readfails += 1
            print("Error reading temperature from", TEMP_PATH)
            if(readfails < READ_RETRIES):
                print("Retrying in", READ_FAIL_DELAY, "seconds")
                time.sleep(READ_FAIL_DELAY)
            else:
                print("Failed to read temperature from", TEMP_PATH, "aborting...")
                exit(1)

    power = 0
    if len(curve) == 0:
        if temp >= mintemp:
            power = 1.0
    elif len(curve) == 1:
        print("Error: the curve must have at least 2, or 0 points")
        exit(1)
    elif temp < curve[0][0]:
        power = curve[0][1]
    elif temp > curve[-1][0]:
        power = curve[-1][1]
    else:
        prev = curve[0]
        i = 1
        while i < len(curve):
            if temp >= prev[0] and temp <= curve[i][0]:
                power = prev[1] + ((temp-prev[0])/(curve[i][0]-prev[0]))*(curve[i][1]-prev[1])
                break
            prev = curve[i]
            i+=1
    if(power < 0 or power > 1):
        print("Invalid config (got power of", power, "at temp", temp, ")")
        exit(1)
    print("New power:", power, "at temp", temp)
    try:
        set_power(power)    
        time.sleep(0.1)
        set_power(power)    
    except:
        print("Failed to write I2C!")
    time.sleep(DELAY)