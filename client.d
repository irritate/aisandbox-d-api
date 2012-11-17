/*
 * client.d
 *
 * A network-based client for AI Sandbox, to provide an API to the D programming language.
 *
 * Copyright (c) 2012, irritate
 *
 */
module aisandbox.client;

import aisandbox.json;
import std.conv;
import std.json;
import std.socket;
import std.stdio;
import std.string;

int main(string[] args)
{
    string host = "localhost";
    ushort port = 41041;
    string commander;

    if (args.length == 2)
    {
        commander = args[1];
    }
    else if (args.length == 4)
    {
        host = args[1];
        port = to!(ushort)(args[2]);
        commander = args[3];
    }
    else
    {
        writeln("Usage:");
        writeln("    client <commander>");
        writeln("    client <host> <port> <commander>");
        return 1;
    }

    writefln("Connecting to %s on port %s...", host, port);
    Address[] addrs = getAddress(host, port);
    Address addrToUse;
    foreach (addr; addrs)
    {
        debug writeln(addr);
        if (addr.addressFamily == AddressFamily.INET)
        {
            addrToUse = addr;
            break;
        }
    }
    Socket sock = new Socket(addrToUse.addressFamily, SocketType.STREAM);
    //sock.blocking = true;
    sock.connect(addrToUse);
    ubyte[1024] buf;
    while (true)
    {
        int size = sock.receive(buf);
        string bufStr = cast(string)buf[0..size];
        debug writefln("size: %d, buf: %s", size, bufStr);
        string[] lines = splitLines(bufStr);
        debug foreach (i, line; lines)
        {
            writefln("%d: %s", i, line);
        }
        if (lines[0] == "<connect>")
        {
            writeln("Connected!  Handshaking...");
            ConnectServer cs = fromJSON!(ConnectServer)(lines[1]);
            ConnectClient cc = new ConnectClient(commander, "D");
            string reply = format("<connect>\n%s\n", toJSON(cc));
            debug writeln(reply);
            sock.send(reply);
        }
    }

    return 0;
}
