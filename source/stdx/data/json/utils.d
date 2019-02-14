/**
 * A set of utility types/function for convenient use of `std.data.json`
 *
 * One common need is to deserialize a JSON object into a struct.
 * The `Deserializer` type provides such a functionality,
 * and support different level of matching (see `MatchingPolicy`)
 * for convenient use.
 */
module stdx.data.json.utils;

import std.traits;
import stdx.data.json.value;

/**
 * Deserialize a `JSONValue` into a `T`
 *
 * This convenience struct will match the content of an object
 * and a `JSONValue`.
 */
struct Deserializer (T)
{
    /// Just a constant to simplify writing
    private enum BitPack = size_t.sizeof;
    /// Number of fields
    private enum FieldCount = T.tupleof.length;
    /// Number of size_t required to represent the number of fields
    /// More often than not this will just be 1
    private enum FieldMapSize = (FieldCount / (BitPack * 8))
        + ((FieldCount % (BitPack * 8)) ? 1 : 0);
    /// Aggregate to fill
    private T* aggr;
    /// Bitmap of the fields already filled (`MatchingPolicy.Value`)
    private size_t[FieldMapSize] fieldmap;

    /// Constructor
    public this (T* aggregate)
    in { assert(aggregate !is null); }
    do
    {
        this.aggr = aggregate;
    }
    /// Default ctor is disabled
    @disable public this();

    /// Do the actual deserialization work
    public void deserialize (JSONValue val, MatchingPolicy policy = MatchingPolicy.Exact)
    {
        assert(val.hasType!(JSONValue[string]));
        this.deserialize(val.get!(JSONValue[string]), policy);
    }

    public void deserialize (JSONValue[string] fields, MatchingPolicy policy = MatchingPolicy.Exact)
    {
        // If JSON is part of the matching policy (it could very well be `All`),
        // iterate over the JSON object and fill the fieldmap.
        // Once we are done, check if all fields were filled (if need be)
        if (policy & MatchingPolicy.JSON)
            this.iterateJSON(fields);
        else
            this.iterateFields(fields);

        if (policy & MatchingPolicy.Value)
            for (size_t idx; idx < T.tupleof.length; ++idx)
                if (((this.fieldmap[idx / BitPack] >> (idx % BitPack)) & 1)
                    == 0)
                {
                    string[T.tupleof.length] fname = void;
                    static foreach (Index, Field; FieldNameTuple!T)
                        fname[Index] = Field;
                    assert(0, "Field '" ~ fname[idx] ~ "' is missing a value.");
                }
    }

    private void iterateJSON (JSONValue[string] fields)
    {
        import std.meta;

        import std.stdio;
        writeln("Iterating on fields... ", fields);
        foreach (name, field; fields)
        {
        SWITCH:
            switch (name)
            {
                static foreach (Index, FieldName; FieldNameTuple!T)
                {
                case FieldName:
                    alias FType = typeof(T.tupleof[Index]);
                    assert(field.hasType!FType);
                    (*this.aggr).tupleof[Index] = field.get!FType;
                    this.fieldmap[Index / BitPack] |= 1 << (Index % BitPack);
                    break SWITCH;
                }
            default:
                assert(0, name);
            }
        }
    }

    private void iterateFields (JSONValue[string] fields)
    {
    }
}

/**
 * Describe the policy used by `JSONDeserializer`
 *
 * The `MatchingPolicy` describes how field names should match.
 *
 * The default, `MatchingPolicy.Exact`, requires the aggregate and the
 * `JSONValue` to have an exact match, so that first-time users do not
 * get surprised. It is a combination of the `Value` and `JSON` policy.
 *
 * In case of exploratory work / mocking, using `MatchingPolicy.Lax`
 * allows to add and remove fields at will.
 *
 * `MatchingPolicy.Value` requires the `JSONValue` to have an entry for
 * all fields of the aggregate, while `MatchingPolicy.JSON` requires
 * the aggregate to fully utilize the `JSONValue`.
 *
 * A policy only applies to field names. If a field in the aggregate have
 * a type that does not match the one in the `JSONValue`, it will always
 * result in an error. For example:
 * ---
 * enum JSONString = `{ "foo": "some string" }`;
 * struct Value { int foo; }
 * ---
 */
enum MatchingPolicy
{
    /**
     * Errors out if the JSONValue and the aggregate do not exactly match
     *
     * Example:
     * ---
     * // The following would satisfy the `MatchingPolicy.Exact`
     * enum JSONString = `{ "foo": 42, "bar": "foobar" }`;
     * struct Value { int foo; string bar; }
     * ---
     */
    Exact = Value | JSON,
    /**
     * Never errors out, even if no fields are in common
     *
     * Example:
     * ---
     * // The following would not error with `MatchingPolicy.None`
     * enum JSONString = `{ "foo": 42, "bar": "foobar" }`;
     * struct Value { string bar; int irrelevant; }
     * ---
     */
    Lax  = 0,
    /**
     * Require `JSONValue` to contain at least all members of the aggregate
     *
     * Example:
     * ---
     * // The following would satisfy the `MatchingPolicy.Value`
     * enum JSONString = `{ "foo": 42, "bar": "foobar" }`;
     * struct Value { string bar; }
     * ---
     */
    Value = 1,
    /**
     * Require the aggregate to contain at least all members in the `JSONValue`
     *
     * Example:
     * ---
     * // The following would satisfy the `MatchingPolicy.JSON`
     * enum JSONString = `{ "bar": "foobar" }`;
     * struct Value { string bar; int irrelevant; }
     * ---
     */
    JSON  = 2,
}

void deserializeJSON(T)(ref T dst, JSONValue src)
{
    Deserializer!T deserializer = Deserializer!(T)(&dst);
    deserializer.deserialize(src);
}

T deserializeJSON(T)(JSONValue src)
{
    T v = void;
    deserializeJSON(v, src);
    return v;
}

@nogc unittest
{
    import stdx.data.json.parser;

    static struct Simple { long a; string b; double c; }
    JSONValue value = toJSONValue(`{ "a": 42, "b": "Hello world!", "c": 42.42 }`);
    //Simple result = deserializeJSON!(Simple)(value);
    //assert(result.a == 42);
    //assert(result.b == "Hello world!");
    //assert(result.c == 42.42);
}

// T deserializeJson(T, R) (R input)
//     if (!is(R == JSONValue) && isInputRange!R);
