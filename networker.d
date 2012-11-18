/*
 * networker.d
 *
 * Provides network service as a worker thread.
 *
 * Copyright (c) 2012, irritate
 *
 */
module aisandbox.networker;

import std.concurrency;
import std.socket;
import std.stdio;
import std.string;

Tid start_worker(string host, ushort port)
{
    return spawn(&start_worker_impl, thisTid, host, port);
}

void start_worker_impl(Tid parent, string host, ushort port)
{
    writefln("Connecting to %s on port %s...", host, port);
    Address[] addrs = getAddress(host, port);
    Address addrToUse;
    foreach (addr; addrs)
    {
        // Fixes a problem where the same host has INET and INET6 addresses.
        debug writeln(addr);
        if (addr.addressFamily == AddressFamily.INET)
        {
            addrToUse = addr;
            break;
        }
    }
    try
    {
        Socket sock = new Socket(addrToUse.addressFamily, SocketType.STREAM);
        //sock.blocking = false;
        sock.connect(addrToUse);
        loop(parent, sock, new ubyte[0]);
    }
    catch (SocketOSException e)
    {
        writeln(e.msg);
    }
    catch (Exception e)
    {
        writeln(e);
    }

}

void loop(Tid parent, Socket sock, ubyte[] buf)
{
    ubyte[4096] tempBuf;
    int size = sock.receive(tempBuf);
    assert(size != 0);
    buf ~= tempBuf[0..size];
    debug writefln("size: %d, buf: %s", size, cast(string)tempBuf[0..size]);
    int pos = indexOf(cast(char[])buf, '\n');
    while (pos != -1)
    {
        string line = cast(string)buf[0..pos];
        debug writefln("line: %s", line);
        send(parent, line);
        buf = buf[pos+1..$];
        pos = indexOf(cast(char[])buf, '\n');
    }

    string result;
    bool received = receiveTimeout(dur!"msecs"(10),
            (string str) { result = str; }
            );
    if (received)
    {
        writeln("[networker] result: %s", result);
        sock.send(result);
    }

    loop(parent, sock, buf);
}
