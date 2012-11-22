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

// This is necessary because the parser is reading floats
// with no decimal point as integers, and .floating is returning -nan.
float asFloat(JSONValue jVal)
{
    float result;

    if (jVal.type == JSON_TYPE.INTEGER)
    {
        result = cast(float)jVal.integer;
    }
    else if (jVal.type == JSON_TYPE.FLOAT)
    {
        result = jVal.floating;
    }
    else
    {
        enforce(false, "Not a float type.");
    }

    return result;
}

T[] toArray(T)(JSONValue[] jArray)
{
    debug(verbose) writefln("toArray: %s", jArray[0].type);
    T[] result;
    foreach (jVal; jArray)
    {
        static if (is(T == float))
        {
            result ~= asFloat(jVal);
        }
        else static if (is(T == string))
        {
            result ~= jVal.str;
        }
        else static if (is(T ident : U[], U))
        {
            result ~= toArray!(U)(jVal.array);
        }
        else
        {
            enforce(false, "Unsupported array type");
        }
    }
    return result;
}

T[string] toMap(T)(JSONValue[string] jMap)
{
    debug(verbose) writefln("toMap: %s", jMap.values[0].type);
    T[string] result;
    foreach (key, jVal; jMap)
    {
        static if (is(T == float))
        {
            result[key] = asFloat(jVal);
        }
        else static if (is(T == string))
        {
            result[key] = jVal.str;
        }
        else static if (is(T ident : U[], U))
        {
            result[key] = toArray!(U)(jVal.array);
        }
        else
        {
            enforce(false, "Unsupported map type");
        }
    }
    return result;
}

/***** GameInfo *****/
// Provides information about the level the game is played in.
class LevelInfo
{
    //alias float[2] vector2;
    @property int width;  // The width of the game world
    @property int height; // The height of the game world
    @property float[][] blockHeights;  // A width x height array showing the height of the block at each position in the world. indexing is based on x + y * width
    @property string[] teamNames;  // A list of the team names supported by this level.
    @property float[/*2*/][string] flagSpawnLocations;  // The map of team name the spawn location of the team's flag
    @property float[/*2*/][string] flagScoreLocations;  // The map of team name the location the flag must be taken to score
    @property float[/*2*/][/*2*/][string] botSpawnAreas; // The map of team name the extents of each team's bot spawn area

    @property float characterRadius; // The radius of each character, used to determine the passability region around blocks
    @property float FOVangle;        // The visibility radius of the bots
    @property float firingDistance;  // The maximum firing distance of the bots
    @property float walkingSpeed;    // The walking speed of the bots
    @property float runningSpeed;    // The running speed of the bots

    // private to module
    private void setFromJSONValue(JSONValue value)
    {
        debug(verbose) writefln("setFromJSONValue: %s", value);
        width = cast(int)value.object["width"].integer;
        height = cast(int)value.object["height"].integer;
        blockHeights = toArray!(float[])(value.object["blockHeights"].array);
        teamNames = toArray!(string)(value.object["teamNames"].array);
        flagSpawnLocations = toMap!(float[])(value.object["flagSpawnLocations"].object);
        flagScoreLocations = toMap!(float[])(value.object["flagScoreLocations"].object);
        botSpawnAreas = toMap!(float[][])(value.object["botSpawnAreas"].object);
        characterRadius = asFloat(value.object["characterRadius"]);
        FOVangle = asFloat(value.object["FOVangle"]);
        firingDistance = asFloat(value.object["firingDistance"]);
        walkingSpeed = asFloat(value.object["walkingSpeed"]);
        runningSpeed = asFloat(value.object["runningSpeed"]);
        debug(verbose) writefln("width: %s", width);
        debug(verbose) writefln("height: %s", height);
        debug(verbose) writefln("blockHeights: %s", "<...>"); // blockHeights);
        debug(verbose) writefln("teamNames: %s", teamNames);
        debug(verbose) writefln("flagSpawnLocations: %s", flagSpawnLocations);
        debug(verbose) writefln("flagScoreLocations: %s", flagScoreLocations);
        debug(verbose) writefln("botSpawnAreas: %s", botSpawnAreas);
        debug(verbose) writefln("characterRadius: %s", characterRadius);
        debug(verbose) writefln("FOVangle: %s", FOVangle);
        debug(verbose) writefln("firingDistance: %s", firingDistance);
        debug(verbose) writefln("walkingSpeed: %s", walkingSpeed);
        debug(verbose) writefln("runningSpeed: %s", runningSpeed);
    }
};

unittest
{
    string json = "{\"__class__\": \"LevelInfo\","
        "\"__value__\": {"
            "\"runningSpeed\": 6.0,"
            "\"flagSpawnLocations\": {"
                    "\"Blue\": [82.0, 20.0],"
                    "\"Red\": [6.0, 30.0]"
                "},"
                "\"teamNames\": [\"Blue\", \"Red\"]," 
                "\"blockHeights\": ["
                    "[0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],"
                    "[0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],"
                    "[0,0,0,0,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],"
                    "[0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,0,0,0,0,0,0,0,0,0,0],"
                    "[0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],"
                    "[0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,0,0,0,0,0,0,0,0,0,0,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],"
                    "[0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],"
                    "[0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],"
                    "[0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],"
                    "[0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],"
                    "[0,0,0,0,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],"
                    "[0,0,0,0,0,0,0,0,0,0,0,0,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],"
                    "[0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,0,0,0,0,0,0,0,0,0],"
                    "[0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0],"
                    "[0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],"
                    "[0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],"
                    "[0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],"
                    "[0,0,0,2,2,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],"
                    "[0,1,1,2,2,2,2,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],"
                    "[4,4,4,4,1,2,2,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,0,0,0,0],"
                    "[4,4,4,4,1,2,2,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],"
                    "[4,4,4,4,1,2,2,0,0,0,0,0,0,0,0,0,0,0,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],"
                    "[4,4,4,4,1,0,0,0,0,0,0,0,0,0,0,0,1,1,1,2,2,2,2,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,0,0,0,0,0,0,0,0,0,0,0,0],"
                    "[1,1,1,0,0,0,0,0,0,0,0,0,0,0,4,4,4,4,1,2,2,2,2,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],"
                    "[0,0,0,0,0,0,0,0,0,0,0,0,0,1,4,4,4,4,4,4,4,4,1,0,0,0,0,0,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],"
                    "[0,0,0,0,0,0,0,0,0,0,0,0,0,1,4,4,4,4,4,4,4,4,2,2,0,0,0,4,4,4,4,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],"
                    "[0,0,0,0,0,0,0,0,0,0,0,0,0,1,4,4,4,4,4,4,4,4,2,2,0,0,0,4,4,4,4,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],"
                    "[0,0,0,0,0,0,2,2,1,0,0,0,0,0,1,1,2,2,4,4,4,4,1,1,0,0,0,4,4,4,4,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],"
                    "[0,0,0,0,0,0,2,2,2,2,0,0,0,0,0,0,2,2,1,0,0,0,0,0,0,0,0,4,4,4,4,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],"
                    "[0,0,0,1,4,4,4,4,2,2,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,1,1],"
                    "[0,0,0,1,4,4,4,4,2,2,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,2,2,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,4,4,4,4,2,2],"
                    "[0,0,0,1,4,4,4,4,2,2,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,2,2,0,0,0,0,0,0,1,1,1,0,0,0,0,0,1,4,4,4,4,2,2],"
                    "[0,0,0,0,4,4,4,4,1,1,0,0,0,0,0,0,0,0,0,4,4,4,4,0,0,0,1,1,1,0,0,0,2,2,2,2,2,2,0,0,0,0,0,1,4,4,4,4,2,2],"
                    "[0,0,0,0,0,2,2,2,2,1,0,0,0,0,0,0,0,0,0,4,4,4,4,0,0,0,0,0,0,0,0,0,2,2,2,2,2,2,0,0,0,0,0,1,4,4,4,4,2,2],"
                    "[0,0,0,0,0,2,2,2,2,1,0,0,0,0,0,4,4,4,4,4,4,4,4,0,0,0,0,0,0,0,0,4,4,4,4,2,2,1,0,0,0,0,0,0,0,0,2,2,2,2],"
                    "[0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,4,4,4,4,4,4,4,4,0,0,0,0,0,0,0,1,4,4,4,4,2,2,1,0,0,0,0,0,0,0,0,2,2,2,2],"
                    "[0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,4,4,4,4,1,0,0,0,0,0,0,0,0,0,0,1,4,4,4,4,2,2,0,0,0,0,0,0,0,0,0,0,0,2,2],"
                    "[2,2,0,0,0,0,0,0,0,0,0,0,0,0,1,4,4,4,4,1,0,0,0,0,0,0,0,0,0,0,1,4,4,4,4,2,2,0,0,0,0,0,0,0,0,0,0,0,2,2],"
                    "[2,2,1,0,0,0,0,0,0,0,0,0,0,0,0,1,2,2,2,2,0,0,0,0,0,0,0,0,0,0,0,0,2,2,2,2,0,0,0,0,0,0,0,0,0,0,0,0,0,0],"
                    "[2,2,1,0,0,0,0,2,2,1,0,0,0,0,0,0,2,2,2,2,0,0,0,0,1,1,1,0,0,0,0,0,2,2,2,2,0,0,0,0,0,0,0,0,0,0,0,0,0,0],"
                    "[2,2,1,0,0,0,0,2,2,1,0,0,0,0,0,0,2,2,1,1,0,0,0,0,4,4,4,4,0,0,0,0,0,0,0,0,0,0,0,0,2,2,1,0,0,0,0,0,0,0],"
                    "[1,0,0,0,0,0,0,4,4,4,4,0,0,0,0,0,2,2,1,0,0,0,0,0,4,4,4,4,0,0,0,0,0,0,0,0,0,0,0,0,2,2,1,2,2,0,0,0,0,0],"
                    "[0,0,0,0,0,0,0,4,4,4,4,2,2,0,0,0,0,0,0,0,0,0,0,1,4,4,4,4,0,0,0,0,0,0,0,0,0,0,0,4,4,4,4,2,2,0,0,0,0,0],"
                    "[0,0,0,0,0,0,0,4,4,4,4,2,2,0,0,0,0,0,0,0,0,0,0,1,4,4,4,4,0,0,0,0,0,0,0,0,0,2,2,4,4,4,4,1,1,0,0,0,0,0],"
                    "[0,0,0,0,0,2,2,4,4,4,4,1,1,0,0,0,0,0,0,0,0,0,4,4,4,4,1,0,0,0,0,0,0,0,0,0,0,2,2,4,4,4,4,0,0,0,0,0,0,0],"
                    "[0,0,0,0,0,2,2,2,2,1,1,0,0,0,0,0,0,0,0,0,0,0,4,4,4,4,1,0,0,0,0,0,0,0,0,0,0,1,1,4,4,4,4,0,0,0,0,0,0,0],"
                    "[0,0,0,0,0,1,1,2,2,1,0,0,0,0,0,0,0,0,0,0,0,0,4,4,4,4,0,0,0,0,0,1,1,1,0,0,0,0,0,1,1,1,1,0,0,0,0,0,0,1],"
                    "[0,0,0,0,0,0,0,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,4,4,4,4,0,0,0,0,4,4,4,4,0,0,0,0,0,0,1,2,2,0,0,0,0,2,2,1],"
                    "[0,0,0,0,0,0,0,0,0,0,0,0,0,0,4,4,4,4,0,0,0,0,0,1,1,1,0,0,0,0,4,4,4,4,0,0,0,0,0,0,1,2,2,0,0,0,0,2,2,1],"
                    "[0,0,0,0,0,0,0,0,0,0,0,0,0,0,4,4,4,4,0,0,0,0,0,0,0,0,0,0,0,0,4,4,4,4,1,0,0,0,0,0,0,0,0,0,0,0,0,1,2,2],"
                    "[2,2,0,0,0,0,0,0,0,0,0,0,0,1,4,4,4,4,2,2,0,0,0,0,0,0,0,0,0,0,4,4,4,4,1,1,0,0,0,0,0,0,0,0,0,0,0,0,2,2],"
                    "[2,2,0,0,0,0,0,0,0,0,0,0,0,1,4,4,4,4,2,2,0,0,0,0,0,0,0,0,0,0,1,2,2,2,2,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0],"
                    "[4,4,4,4,0,0,0,0,0,0,0,0,4,4,4,4,2,2,1,1,0,0,0,0,0,0,0,4,4,4,4,2,2,2,2,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0],"
                    "[4,4,4,4,0,0,0,0,0,0,0,0,4,4,4,4,2,2,1,0,0,0,0,0,0,0,0,4,4,4,4,1,1,1,1,0,0,0,0,0,4,4,4,4,1,0,0,0,0,0],"
                    "[4,4,4,4,1,1,1,0,0,0,0,0,4,4,4,4,2,2,0,0,0,0,0,0,0,0,0,4,4,4,4,0,0,0,0,0,0,0,0,0,4,4,4,4,1,0,0,0,0,0],"
                    "[4,4,4,4,1,2,2,0,0,0,0,0,4,4,4,4,2,2,0,0,0,2,2,1,0,0,0,4,4,4,4,0,0,0,0,0,0,0,0,0,4,4,4,4,2,2,0,0,0,0],"
                    "[2,2,1,1,1,2,2,0,0,0,0,0,1,1,1,0,0,0,0,0,0,2,2,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,4,4,4,4,2,2,1,0,0,0],"
                    "[2,2,1,2,2,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,2,2,2,2,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,2,2,2,2,2,2,1,0,0,0],"
                    "[1,1,1,2,2,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,2,2,2,2,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,2,2,2,2,2,2,1,0,0,0],"
                    "[0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,4,4,4,4,0,0,0,0,0,0,0,0,1,1,1,0,0,0,0,0,0,1,2,2,1,0,0,0,0,0,0],"
                    "[0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,4,4,4,4,0,0,0,2,2,2,2,2,2,2,2,2,2,0,0,0,0,0,2,2,1,0,0,0,0,0,0],"
                    "[0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,4,4,4,4,0,0,0,2,2,2,2,2,2,2,2,2,2,1,0,0,0,0,0,0,0,0,0,0,0,0,0],"
                    "[0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,4,4,4,4,0,0,0,1,2,2,4,4,4,4,2,2,2,2,0,0,0,0,0,0,0,0,0,0,0,0,0],"
                    "[0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,0,0,0,0,0,2,2,4,4,4,4,2,2,2,2,0,0,0,0,0,0,0,0,0,0,0,0,0],"
                    "[0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,2,2,4,4,4,4,1,1,1,0,0,0,0,0,0,0,0,0,0,0,1,1,1],"
                    "[0,0,0,0,0,0,0,0,0,0,0,0,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,2,2,4,4,4,4,1,0,0,0,0,0,0,0,0,0,0,0,1,1,1,2,2],"
                    "[0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,0,0,0,0,0,0,0,0,0,0,0,4,4,4,4,1,2,2],"
                    "[0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,4,4,4,4,2,2,1],"
                    "[0,0,0,0,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,4,4,4,4,2,2,1],"
                    "[0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,4,4,4,4,1,1,0],"
                    "[0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,0,0,0],"
                    "[0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],"
                    "[0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],"
                    "[0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],"
                    "[0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],"
                    "[0,0,0,0,0,0,0,0,0,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],"
                    "[0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,0,0,0,0,0,0,0,0,0,0,0,0],"
                    "[0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,0,0,0,0],"
                    "[0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],"
                    "[0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],"
                    "[0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],"
                    "[0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],"
                    "[0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,0,0,0,0,0,0,0,0,0,0,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],"
                    "[0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],"
                    "[0,0,0,0,0,0,0,0,0,0,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],"
                    "[0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,0,0,0,0],"
                    "[0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],"
"[0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0]"
                "],"
                "\"height\": 50,"
                "\"characterRadius\": 0.25,"
                "\"walkingSpeed\": 3.0,"
                "\"FOVangle\": 1.5707963267948966,"
                "\"botSpawnAreas\": {"
                    "\"Blue\": ["
                        "[79.0,2.0],"
                        "[85.0,9.0]"
                        "],"
                    "\"Red\": ["
                        "[3.0,41.0],"
                        "[9.0,48.0]"
                        "]"
                "},"
                "\"firingDistance\": 15.0,"
                "\"width\": 88,"
                "\"flagScoreLocations\": {"
                    "\"Blue\": [82.0,20.0],"
                    "\"Red\": [6.0,30.0]"
                "}"
        "}"
    "}";
    LevelInfo li = fromJSON!(LevelInfo)(json);
    assert(li.walkingSpeed == 3.0);
    assert(li.width == 88);
    assert(li.height == 50);
    assert(li.blockHeights.length == li.width);
    assert(li.blockHeights[0].length == li.height);
    assert(li.teamNames == ["Blue", "Red"]);
    assert(li.flagSpawnLocations["Blue"] == [82.0, 20.0]);
    assert(li.flagSpawnLocations["Red"] == [6.0, 30.0]);
    assert(li.flagScoreLocations["Blue"] == [82.0, 20.0]);
    assert(li.flagScoreLocations["Red"] == [6.0, 30.0]);
    assert(li.botSpawnAreas["Blue"][0] == [79.0, 2.0]);
    assert(li.botSpawnAreas["Red"][1] == [9.0, 48.0]);
    assert(std.math.abs(li.characterRadius - 0.25) < float.epsilon);
    assert(std.math.abs(li.FOVangle - 1.5707963267948966) < float.epsilon);
    assert(li.firingDistance == 15.0);
    assert(li.walkingSpeed == 3.0);
    assert(li.runningSpeed == 6.0);
}
