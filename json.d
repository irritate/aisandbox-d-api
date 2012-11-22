/*
 * json.d
 *
 * Provides the translations to and from the JSON protocol used by the AI Sandbox
 * game server and D classes.
 *
 * Copyright (c) 2012, irritate
 *
 */
module aisandbox.json;

// JSON marshal/unmarshal is pending integration to Phobos, but is here:
// https://github.com/beatgammit/phobos/commit/0d7ae93b30a713f2f4c595c4665629b0c10e5617
//import std.conv;
import std.exception;
import std.json;
import std.stdio;
import std.string;

T fromJSON(T)(string json)
{
    JSONValue value = parseJSON(json);
    enforce(value.type != JSON_TYPE.NULL);
    string className = "aisandbox.json."~value.object["__class__"].str;
    debug(verbose) writefln("className: %s", className);
    enforce(typeid(T).name == className);
    T obj = cast(T)Object.factory(className);
    static if (__traits(compiles, obj.setFromJSONValue(value)))
    {
        obj.setFromJSONValue(value.object["__value__"]);
    }
    return obj;
}

string toJSON(T)(T obj)
{
    JSONValue value = obj.toJSONValue();
    string result = format("{\"__class__\": \"%s\", \"__value__\": %s}",
        T.stringof,
        std.json.toJSON(&value));
    return result;
}

class ConnectServer
{
    private string expectedVersion = "1.0";
    @property string protocolVersion;
    // private to module
    private void setFromJSONValue(JSONValue value)
    {
        debug(verbose) writefln("setFromJSONValue: %s", value);
        protocolVersion = value.object["protocolVersion"].str;
        debug(verbose) writefln("protocolVersion: %s", protocolVersion);
        validate();
    }
    void validate()
    {
        enforce(protocolVersion == expectedVersion, "Unexpected protocol version!  Need to update the API.");
    }
}

unittest
{
    ConnectServer cs = fromJSON!(ConnectServer)(`{"__class__": "ConnectServer", "__value__": {"protocolVersion": "1.0"}}`);
    try
    {
        ConnectServer cs2 = fromJSON!(ConnectServer)(`{"__class__": "ConnectServer", "__value__": {"protocolVersion": "2.0"}}`);
        assert(false);
    }
    catch (Exception e)
    {
    }
    try
    {
        class Dummy {};
        Dummy obj = fromJSON!(Dummy)("");
        assert(false);
    }
    catch (Exception e)
    {
    }
}

class ConnectClient
{
    @property string commanderName;
    @property string language;
    this(string cmdr, string lang)
    {
        commanderName = cmdr;
        language = lang;
    }
    private JSONValue toJSONValue()
    {
        JSONValue result;
        result.type = JSON_TYPE.OBJECT;
        result["commanderName"].str = commanderName;
        result["language"].str = language;
        return result;
    }
}
