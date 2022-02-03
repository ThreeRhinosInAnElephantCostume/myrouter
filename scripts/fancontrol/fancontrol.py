#!/usr/bin/python
import lgpio
import time
import json
import io
import os
import os.path
import argparse

ADDRESS=0x42


ADDR_POWER=0x0
ADDR_CONFIG=0x1

parser = argparse.ArgumentParser(description="Fancontrol: Control a fan over I2C")
parser.add_argument("--set-power", dest="power", type=float, nargs="?")
args = parser.parse_args()

class Config:
    fan_enable = False
    test = False
    def convert(self)->int:
        return (self.fan_enable << 0) | (self.test << 1)
    def __init__(self, v:int=None):
        if(v is not None):
            self.fan_enable = bool(v & (1 << 0))
            self.test = bool(v & (1 << 1))

i2c = lgpio.i2c_open(1, ADDRESS)

def get_config()->Config:
    lgpio.i2c_write_byte(i2c, ADDR_CONFIG)
    dt = lgpio.i2c_read_byte(i2c)
    print("get config", dt)
    return Config(dt)

def get_power()->int:
    lgpio.i2c_write_byte(i2c, ADDR_POWER)
    dt = lgpio.i2c_read_byte(i2c)
    print("get power", dt)
    return dt

def set_config(_dt):
    dt = 0
    if isinstance(_dt, int):
        dt = _dt
    else:
        dt = _dt.convert()
    print("set config",  dt)
    lgpio.i2c_write_byte(i2c, ADDR_CONFIG)
    lgpio.i2c_write_byte(i2c, dt)

def set_test(b: bool):
    conf = get_config()
    conf.test = b
    set_config(conf)

def set_enabled(b: bool):
    conf = get_config()
    conf.fan_enable = b
    set_config(conf)

def set_power(v: float):
    n = int(v * 255)
    print("set power", n)
    lgpio.i2c_write_byte(i2c, ADDR_POWER)
    lgpio.i2c_write_byte(i2c, n)
    print("returned power:", get_power())

if(args.power is not None):
    conf = Config()
    conf.fan_enable = True
    set_config(conf)
    set_power(args.power)
    exit(0)

if(not os.path.isfile("/etc/fanctonrol/fancontrol.config.json")):
    print("Config not found, copying:")
    os.system("sudo cp fanctonrol.config.json /etc/fancontrol/fancontrol.config.json")
    if(not os.path.isfile("/etc/fanctonrol/fancontrol.config.json")):
        print("Could not copy config, ensure /etc/fancontrol/fancontrol.config.json exists")

json.parse()
