#!/usr/bin/python3
import subprocess
import sys
import pathlib
import os
import re
from pathlib import Path, PosixPath
from random import *

if os.geteuid() != 0:
    print("ERROR: not root!")
    exit()

class connection:
    host="" # ip
    unique=False
    devname=""
    path=""
    country=""
    tables=[]# list of tables (strings)
    def __repr__(self)->str:
        s = "connection("
        f = lambda st: "\'" + st + "\'"
        s += f(self.host) + ","
        s += str(self.unique) + ","
        s += f(self.devname) + ","
        s += f(self.path) + ","
        s += f(self.country) + ","
        s += str(self.tables)
        s += ")"
        return s
    def __init__(self, host="", unique=False, devname="", path="", country="", tables=[]):
        self.host = host
        self.unique = unique
        self.devname = devname
        self.path = path
        self.country = country
        self.tables = tables
maxremotes=5
tablestart=1000
tableend=1100
statepath=""
serverpath=""
devip = ""
permpath=""

serversbycountry = {} # dict<code:str, list<path:str>>
servers = [] # list<path:str>
connections = [] # list<connection>
activebycountry = {} # dict<code, list<connection>>
activeservers = [] # list<path:str>
connectedhosts={} # dict<ip:str, devname:str>
tables = []  #list<bool>
drydefault=False
def nconnections()->int:
    return len(activeservers)
def allocatetable()->int:
    i = 0
    while i < len(tables):
        if(not tables[i]):
            tables[i] = True
            return i + tablestart
        i+=1
    raise "out of tables"
def freetable(n:int):
    tables[n-tablestart] = False
def bash(commandline:str, quiet=False, dry=drydefault):
    if(type(commandline) is not list):
        commandline = commandline.split(" ")
    if(not quiet):
        print(" ".join(commandline))
    if not dry:
        return subprocess.run(commandline)
    return ""
def printusage():
    print("autovpn.py <confpath> [reload]")
    print("autovpn.py <confpath> [add] <ip>")
    print("autovpn.py <confpath> [del/rem/delete/remove] <ip> <country>")
def createdevice(name, config):
    bash("ip link del " + name)
    bash("ip link add " + name + " type wireguard")
    bash("ip addr add dev " + name + " " + devip + "/32")
    bash("wg setconf " + name + " " + config)
    bash("ip link set up " + name)
def attachtodevice(name, host)->list: # returns tables used
    global ethlan
    table:str = str(allocatetable())
    btable:str = str(allocatetable()) # blackhole table
    bash("iptables -t nat -I POSTROUTING 1 -s " + host + " -o " + name + " -j MASQUERADE")
    bash("iptables -I FORWARD 1 -s " + host + " -i " + name +" -j ACCEPT")
    bash("iptables -I FORWARD 2 -i " + name + " -o " + ethlan + "  -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT")

    #bash("iptables -t nat ")

    #delete old killswitch, if exists
    bash("ip rule del from " + host + " lookup " + btable)
    bash("ip route flush table " + btable)

    #add a killswitch
    bash("ip rule add from " + host + " lookup " + btable)
    bash("ip route add table " + btable + " blackhole default")

    #delete old route, if exists
    bash("ip rule del from " + host + " lookup " + table)
    bash("ip route flush table " + table)

    #add new
    bash("ip rule add from " + host + " lookup " + table)
    bash("ip route add table " + table + " default via " + devip + " dev " + name)
    #bash("ip route add table " + table + " default dev " + name + " scope link")

    return [table, btable]
def destroydevice(name):
    bash("ip link del " + name)
def detachfromdevice(ip, name, tables):
    global connections
    global ethlan
    host = ip
    bash("iptables -t nat -D POSTROUTING -s " + host + " -o " + name + " -j MASQUERADE")
    bash("iptables -D FORWARD -s " + host + " -i " + name +" -j ACCEPT")
    bash("iptables -D FORWARD -i " + name + " -o " + ethlan + "  -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT")
    print("tables: ", tables)
    for table in tables:
        bash("ip rule del from " + ip + " lookup " + table)
        bash("ip route flush table " + table)
def add(args):
    global activebycountry
    global connectedhosts
    global connections
    global servers
    global serversbycountry
    if(len(args) < 2):
        print("ERROR: missing arguments")
        return 
    forcedname = ""
    for it in args:
        if("--name=" in it):
            forcedname = it.replace("--name=", "").replace("\"", "").replace("\'", "").replace(" ", "-")
            print("forced name:", forcedname)
    noip = "--noip" in args
    if(forcedname == "" and noip):
        print("ERROR: attempting to create a noip device without a custom name")
        return
    ip = ""
    if noip:
        print("no ip selected")
        ip = "--noip --name=" + forcedname
        for it in connections:
            if(it.devname == forcedname):
                print("noip already connected, disconnecting...")
                remove(["--noip", forcedname])
                break
    else:
        ip = args[0]
        print("ip is", ip)
        if(ip in connectedhosts.keys()):
            print("host already connected, disconnecting...")
            remove([ip])
    country:str = ""
    if noip:
        for it in args:
            if(not "--" in it):
                country = it
                break
    else:
        country = args[1]
    country = country.lower()
    nums = ""
    for it in country:
        if(it.isnumeric()):
            nums += it
    forcespecific:bool = False
    if(nums != ""):
        nc = country.replace(nums, "")
        if(nc != country):
            forcespecific = True
            country = nc
    unique:bool = ("-u" in args or "--unique" in args)
    atcap:bool = (nconnections() == maxremotes)
    createnew=False
    if unique or noip:
        if(atcap):
            print("ERROR: Cannot create an unique connection (at capacity)")
            return 
        createnew=True
    else:
        if(country in activebycountry):
            for ocon in activebycountry[country]:
                if(forcespecific and nums in ocon.devname):
                    continue
                if(not ocon.unique):
                    connectedhosts[ip] = ocon.devname
                    con = connection(ip, False, ocon.devname, ocon.path, country)
                    print("Found compatible device, attaching to " + ocon.devname)
                    con.tables = attachtodevice(ocon.devname, ip)
                    if(country in activebycountry.keys()):
                        activebycountry[country].append(con)
                    else:
                        activebycountry[country] = [con]
                    connections.append(con)
                    return
    if(createnew and atcap):
        print("ERROR: Unable to create a new connection (at capacity)")
        return
    if(country not in serversbycountry.keys()):
        print("ERROR:", country, "country not found")
        return
    l = serversbycountry[country].copy()
    shuffle(l)
    for serv in l:
        if(serv in activeservers):
            continue
        if(not os.path.exists(serv)):
            print("ERROR: server file does not exist: " + serv)
            return
        devname = "av" + os.path.splitext(os.path.basename(serv))[0]
        if(forcespecific and nums in devname):
            continue
        #in this order, otherwise it will conflict with forcespecific
        if(forcedname != ""):
            devname = forcedname
        con = connection(ip, unique, devname, serv, country)
        activeservers.append(serv)
        print("starting from conf file", serv, "devname is", devname)
        createdevice(devname, serv)
        print("attacking to device")
        if noip:
            con.tables = []
        else:
            con.tables = attachtodevice(devname, ip)
            connectedhosts[ip] = serv
        connections.append(con)
        if(country in activebycountry.keys()):
            activebycountry[country].append(con)
        else:
            activebycountry[country] = [con]
        return
    print("ERROR: Cound not find an unused server on", country)
def remove(args):
    global connectedhosts
    global connections
    if(len(args) == 0):
        print("ERROR: Not enough arguments")
        return
    noip = "--noip" in args
    if(noip):
        for it in args:
            if(not "--" in it):
                ip = it
                break
    else:
        ip = args[0]
    if not noip and not ip in connectedhosts.keys():
        print("ERROR: host not found")
        return
    con:connection = None
    for it in connections:
        if(noip):
            if(it.devname == ip):
                con=it
                break
        elif(it.host == ip):
            con = it
            break
    i = 0
    tables = []
    while i < len(connections):
        if((not noip and connections[i].host == ip) or (noip and connections[i].devname == ip)):
            tables = connections[i].tables
            connections.remove(connections[i])
            break
        i+=1
    if(con == None):
        print("ERROR: Connection " + ip + " not found!")
        return
    print("removing", con.host, "from dev", con.devname, "country", con.country)
    if not noip:
        detachfromdevice(ip, connectedhosts[ip], tables)
        connectedhosts[ip] = None
    for it in activebycountry[con.country]:
        if(it.host == ip):
            activebycountry[con.country].remove(it)
    emptyserver: bool = True
    others = []
    for it in connections:
        if(it.devname == con.devname and it.host != con.host):
            emptyserver = False
            others.append(it)
    if(emptyserver or noip):
        print("killing the server")
        destroydevice(con.devname)
        activeservers.remove(con.path)
    else:
        s = ""
        for it in others:
            s += it.host + " "
        print("not killing the server, following hosts are remaining:", s)
def removeresidual(killall=False):
    residue = []
    if killall:
        residue = activeservers
    else:
        taken = []
        for it in connections:
            con:connection = it
            taken.append(con.path)
        for it in activeservers:
            if(it not in taken):
                residue.append(it)
    if(len(residue) > 0):
        print("residual servers detected, removing (" + str(len(residue)) + ")")
        for it in residue:
            devname = "av" + os.path.splitext(os.path.basename(it))[0]
            print("destroying", devname)
            destroydevice(devname)
            activeservers.remove(it)
def killall(ignoreerrors = False):
    print("killing all connections")
    for it in connections:
        if(ignoreerrors):
            try:
                remove([it.host])
            except:
                print("encountered an exception while removing, ignoring")
        else:
            remove([it.host])
    removeresidual(True)
def loadperm(filepath):
    print("loading state from", filepath)
    with open(filepath) as file:
        for line in file:
            if(len(line) == 0):
                continue
            args = line.replace("\n", "").split(" ")
            add(args)
def saveperm(filepath):
    with open(filepath, "w") as file:
        for it in connections:
            con:connection = it
            file.write(con.host + " " + con.country)
            if(con.unique):
                file.write(" --unique")
            file.write("\n")
    print("perm saved to", filepath)
def loadservers(folderpath):
    global serversbycountry
    global servers
    print("loading servers from", folderpath)
    for it in os.listdir(folderpath):
        country:str = it
        npath = folderpath
        if npath[-1] != '/' and npath[-1] != '\\':
            npath += '/'
        npath += country + '/'
        serversbycountry[country] = []
        for serv in os.listdir(npath):
            serv = npath + serv
            servers.append(serv)
            serversbycountry[country].append(serv)
def savestate(filepath):
    with open(filepath, "w") as file:
        file.write("\nconnections = " + str(connections))
        file.write("\nactivebycountry = " + str(activebycountry))
        file.write("\nactiveservers = " + str(activeservers))
        file.write("\nconnectedhosts = " + str(connectedhosts))
        file.write("\ntables = " + str(tables))
def loadconfig(filepath):
    print("loading config from", filepath)
    with open(filepath) as file:
        exec("".join(file.readlines()))
    global tables
    loadservers(serverpath)
    rang = tableend-tablestart
    tables = [False for it in range(0, rang)]
if len(sys.argv) <= 2:
    print("ERROR: Not enough arguments!")
    printusage()
    exit()
confpath:str = sys.argv[1]
print (confpath)
try:
    if not os.path.exists(confpath):
        print("ERROR: Invalid/no path to config (" + confpath + ")")
        exit()
except:
    print("ERROR: Invalid path to config! (os.path threw an exception)")
    exit()
os.chdir(os.path.dirname(confpath))
args:list = sys.argv
if(args[2] == 'configure' or args[2] == 'config' or args[2] == 'c'):
    if(len(args) < 4):
        print("ERROR: Missing argument/s (conffolder)")
        exit()
    conffolder = args[3]
    devip = ""
    if(len(args) == 5):
        devip = args[4]
        print("forced devip is", devip)
    else:
        l = os.listdir(conffolder)
        fname = l[randrange(len(l))]
        fpath = conffolder
        if fpath[-1] != '/' and fpath[-1] != '\\':
            fpath += '/'
        fpath += fname
        with open(fpath) as file:
            devip = re.search("[^ ]{7,17}/32", file.read())[0].replace("/32", "")
            print("devip is", devip, "taken from", fpath)
    lines = []
    with open(confpath, 'r') as file:
        lines = file.readlines()
    nlines = []
    for it in lines:
        if("devip=" in it or "devip =" in it or it == ""):
            pass
        else:
            nlines.append(it)
    nlines.append("devip = \"" + devip + "\"")
    with open(confpath, 'w') as file:
        file.writelines(nlines)
    loadconfig(confpath)
    opath = serverpath
    if opath[-1] != '/' and opath[-1] != '\\':
        opath += '/'
    for it in os.listdir(conffolder):
        if(".conf" not in it):
            continue
        ctn = it.split('-')[1].replace(".conf", "")
        ctn = re.sub('[0-9]', "", ctn)
        print(it+":", "from country", ctn)
        npath = conffolder
        if npath[-1] != '/' and npath[-1] != '\\':
            npath += '/'
        npath += it
        l = []
        with open(npath, 'r') as file:
            print("reading", npath)
            l = file.readlines()
        bash("mkdir " + opath+ctn)
        with open(opath + ctn + "/" + it, "w") as file:
            print("writing", file)
            for line in l:
                if("Address" not in line and "DNS" not in line):
                    if(line[-1] != '\n'):
                        line += "\n"
                    file.write(line)
    exit()
loadconfig(confpath)
args[2] = args[2].lower()
if(args[2] == 'restore' or args[2] == "reconfigure" or args[2] == "restart" or args[2] == "reload" or args[2] == "start"):
    print("restoring previous state")
    if(args[2] != "start"):
        killall(True)
    loadperm(permpath)
    savestate(statepath)
    saveperm(permpath)
    exit()
file = open(statepath)
exec("".join(file.readlines())) #load state 
file.close()
if args[2] == 'killall' or args[2] == 'deleteall' or args[2] == "removeall":
    killall()
elif args[2] == "add":
    add(args[3:])
elif args[2] == "set":
    add(args[3:])
elif args[2] == "del" or args[2] == "delete" or args[2] == "rem" or args[2] == "remove" or args[2] == "kill":
    if(len(args) > 3 and args[3] == 'all'):
        killall()
    remove(args[3:])
elif args[2] == "removeresidue" or args[2] == "removeresidual":
    removeresidual()
elif args[2] == "status" or args[2] == "state":
    print(nconnections(), "out of", maxremotes, "servers used")
    for it in connections:
        con:connection = it
        print(con.host, con.country, con.devname, "unique" if con.unique else "")
    exit()
else:
    print("ERROR: Command not found:", args[2])
savestate(statepath)
saveperm(permpath)
    
