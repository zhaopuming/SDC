/**
 * Copyright 2010 Bernard Helyer
 * This file is part of SDC. SDC is licensed under the GPL.
 * See LICENCE or sdc.d for more details.
 */
module runner;

import std.conv;
import std.file;
import std.process;
import std.stdio;
import std.string;


string getTestFilename(int n)
{
    return "test" ~ to!string(n) ~ ".d";
}

bool getBool(string s)
{
    return s == "yes";
}

int getInt(string s)
{
    return parse!int(s);
}

bool test(string filename)
{
    void malformed() { stderr.writeln("Malformed test."); }
    
    bool expectedToCompile;
    int expectedRetval;
    
    assert(exists(filename));
    auto f = File(filename, "r");
    foreach (line; f.byLine) {
        if (line.length < 3 || line[0 .. 3] != "//T") {
            continue;
        }
        auto words = split(line);
        if (words.length != 2) {
            malformed();
            return false;
        }
        auto set = split(words[1], ":");
        if (set.length != 2) {
            malformed();
            return false;
        }
        auto var = set[0].idup;
        auto val = set[1].idup;
        
        switch (var) {
        case "compiles":
            expectedToCompile = getBool(val);
            break;
        case "retval":
            expectedRetval = getInt(val);
            break;
        default:
            stderr.writeln("Bad variable '" ~ val ~ "'.");
            return false;
        }
    }
    
    auto command = "../sdc.bin " ~ filename;
    auto retval = system(command);
    if (expectedToCompile && retval != 0) {
        stderr.writeln("Program expected to compile did not.");
        return false;
    }
    if (!expectedToCompile && retval == 0) {
        stderr.writeln("Program expected not to compile did.");
        return false;
    }
    retval = system("./a.out");
    if (retval != expectedRetval) {
        stderr.writeln("Retval was '" ~ to!string(retval) ~ "', expected '" ~ to!string(expectedRetval) ~ "'.");
        return false;
    }
    return true;
}

void main()
{
    int testNumber;
    auto testName = getTestFilename(testNumber);
    while (exists(testName)) {
        write(testName ~ ":");
        auto succeeded = test(testName);
        writeln(succeeded ? "SUCCEEDED" : "FAILED");
        testName = getTestFilename(++testNumber);
    }
}
