/**
 * Exception definitions specific to the JSON processing functions.
 *
 * Copyright: Copyright 2012 - 2014, Sönke Ludwig.
 * License:   $(WEB www.boost.org/LICENSE_1_0.txt, Boost License 1.0).
 * Authors:   Sönke Ludwig
 * Source:    $(PHOBOSSRC std/data/json/foundation.d)
 */
module stdx.data.json.foundation;

import std.format;

import stdx.data.json.lexer;

/**
 * Represents a location in an input range/file.
 *
 * The indices are zero based and the column is represented in code units of
 * the input (i.e. in bytes in case of a UTF-8 input string).
 */
struct Location
{
    /// Optional file name.
    string file;
    /// The zero based line of the input file.
    size_t line = 0;
    /// The zero based code unit index of the referenced line.
    size_t column = 0;

    /// Returns a string representation of the location.
    string toString() const @safe
    {
        import std.string;
        return format("%s(%s:%s)", this.file, this.line, this.column);
    }
}


/**
 * JSON specific exception.
 *
 * This exception is thrown during the lexing and parsing stages.
*/
class JSONException : Exception
{
    /// The location where the error occured
    Location location;

    /// Constructs a new empty exception
    private this() @safe
    {
        super(string.init, string.init, 0);
    }

    /// Writes to the sink, avoid GC allocations when possible
    override void toString(scope void delegate(scope const(char)[]) sink) const
    {
        formattedWrite(sink, "%s(%s:%s) %s", this.location.file,
                       this.location.line, this.location.column, this.msg);
        // Print stack trace
        if (info)
        {
            try
            {
                sink("\n----------------");
                foreach (t; info)
                {
                    sink("\n"); sink(t);
                }
            }
            catch (Throwable)
            {
                // ignore more errors
            }
        }
    }
}

private struct Static (Exc : Exception)
{
    Exc value = new Exc();
    alias value this;
}

package void enforceJson(bool cond, string message, Location loc,
    string file = __FILE__, size_t line = __LINE__) @nogc @safe
{
    static Static!JSONException exc;
    if (!cond)
    {
        exc.msg = message;
        exc.file = file;
        exc.line = line;
        exc.location = loc;
        throw exc.value;
    }
}
