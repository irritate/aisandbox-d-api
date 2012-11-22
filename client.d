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
import aisandbox.networker;
import std.concurrency;
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
    Tid worker = start_worker(host, port);
    while (true)
    {
        string result = receiveOnly!(string)();
        debug(message_passing) writefln("[networker -> client] result: %s\n", result);
        if (result == "<connect>")
        {
            result = receiveOnly!(string)();
            debug(message_passing) writefln("[networker -> client] result: %s", result);
            writeln("Connected!  Handshaking...");
            ConnectServer cs = fromJSON!(ConnectServer)(result);
            ConnectClient cc = new ConnectClient(commander, "D");
            string reply = format("<connect>\n%s\n", toJSON(cc));
            debug(message_passing) writefln("[client -> networker] reply: %s", reply);
            send(worker, reply);
        }
    }

    return 0;
}
