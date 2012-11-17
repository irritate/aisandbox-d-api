AI Sandbox / Capture The Flag API for the D programming language
================================================================

A network client to handle connection with a http://aisandbox.com/ game server and provide
an API for implementing Capture The Flag commanders in D.

Inspired by errnoh's Go bindings (https://github.com/errnoh/aisandbox) and the official C++ pack (http://aisandbox.com/AiGD-CaptureTheFlag-cpp-1.0.1-pack.zip).

Instructions
------------
1. Download the AI Sandbox and Capture The Flag game server/SDK from http://aisandbox.com.
2. Modify simulate.bat in the CaptureTheFlag-sdk folder to take a game.NetworkCommander as a competitor.
3. Compile the client using a D compiler (only DMD has been tested).
4. Run the client with the name of the commander to run, and optionally the host/port of the game server.

**NOTE: The commander API is not fully implemented yet.  Currently the client only connects to the server and does the initial handshake.**
