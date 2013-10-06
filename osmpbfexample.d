/**
 * Explaination comments taken from:
 * http://wiki.openstreetmap.org/wiki/PBF_Format#Design
 *
 * This gives a very basic parsing of osm.pbf files. The purpose was several
 * fold.
 *
 * - Read PBF files
 * - Learn the file layout
 * - Verify the bytes match
 * - Test the Protocol Buffer compiler for D
 *
 * It uses a bremen file specified in the documentation (not tested with the
 * same version). This should allow others to examine the data and specific
 * bytes (through modification).
 *
 * This code does not provide any high level processing or logic. It only shows
 * the low-level access to the data.
 *
 * Definitions:
 * - Delta-encoding: consecutive nodes in a way or relation have a tendency
 * that nearby nodes have IDs numerically close allowing storage by delta,
 * resulting in small integers. (I.E., instead of encoding x_1, x_2, x_3,
 * encoding is x_1, x_2-x_1, x_3-x_2, ...).
 *
 * License: Boost 1.0
 */
import std.algorithm;
import std.conv;
import std.exception;
import std.file;
import std.range;
import std.stdio : writeln, writefln, File;
import std.string;
import std.typecons;
import std.zlib;

import util.filerange;

import osmpbf;
import osmpbffile;

// Converts ubyte num to proper endian
// Used on initial 4 bytes before a HeaderBlock
private int toNative(ubyte[] num) {
    import std.system;
    union Hold {
        ubyte[4] arr;
        int number;
    }
    Hold a;
    a.arr = num;
    version(LittleEndian)
        a.arr[0..4].reverse();
    return a.number;
}

enum supportedFeaturs = ["DenseNodes", "OsmSchema-V0.6"];

// Type stored in BlobData
enum BlobType { osmHeader, osmData }

/*
 * This stores the raw file data.
 *
 * Cast this type to a HeaderBlock or PrimitaveBlock.
 * Check the type to identify what is stored.
 * If the type is PrimitiveBlock decompression will be handled automatically
 * and upon casting.
 */
private struct BlobData {
    string type_;
    ubyte[] data;
    bool compressed;
    ubyte[] index;

    // Returns the decompressed PB encoded data
    private ubyte[] rawData() {
        if(compressed)
            return cast(ubyte[]) uncompress(data);
        else
            return data;
    }

    /// contains the type of data in this block message.
    BlobType type() {
        switch(type_) {
            case "OSMHeader":
                return BlobType.osmHeader;
            case "OSMData":
                return BlobType.osmData;
            default:
                throw new Exception("Blob Unknown Type: " ~ type_);
        }
    }

    /*
     * Converts the type to HeaderBlock
     */
    T opCast(T)() if(is(T == HeaderBlock)) {
        assert(type == BlobType.osmHeader);
        return HeaderBlock(rawData);
    }

    /*
     * Converts the type to PrimitiveBlock
     */
    T opCast(T)() if(is(T == PrimitiveBlock)) {
        assert(type == BlobType.osmData);
        return PrimitiveBlock(rawData);
    }
}

unittest {
    auto rawData = cast(ubyte[]) "This is uncompressed";
    auto bdata = BlobData("OSMHeader", rawData, false);
    assert(bdata.rawData == rawData);

    auto compData = cast(ubyte[]) compress("This is uncompressed");
    bdata = BlobData("OSMData", compData, true);
    assert(bdata.rawData == rawData);
}

auto osmBlob(string file) {
    auto ans = OpenStreetMapBlob(FileRange(file));
    ans.prime();
    return ans;
}

struct OpenStreetMapBlob {
    FileRange datastream;
    private BlobData bdata;
    private bool _empty;

    auto empty() {
        return _empty;
    }

    auto front() {
        assert(!empty, "Can't front empty range.");
        return bdata;
    }

    auto popFront() {
        assert(!empty, "Can't popFront of empty range.");
        if(datastream.empty)
            _empty = true;
        else
            prime();
    }
    auto prime() {
        // Each header starts with 4 bytes
        enforce(datastream.length > 3,
            "Cannot obtain header length from remaning byte count: "
            ~ to!string(datastream.length));

        // The format is a repeating sequence of:
        // * int4: length of the BlobHeader message in network byte order
        auto size = toNative(datastream[0..4]);
        datastream.popFrontN(4);

        // serialized BlobHeader message
        auto osmData = datastream[0..size];
        datastream.popFrontN(size);
        auto header = BlobHeader(osmData);

        // * serialized Blob message (size is given in the header)
        // Blob is currently used to store an arbitrary blob of data, either
        // uncompressed or in zlib/deflate compressed format.
        osmData = datastream[0..header.datasize];
        datastream.popFrontN(header.datasize);
        auto blob = Blob(osmData);
        // index may include metadata about the following blob
        auto index = header.indexdata.isNull ? [] : header.indexdata;

        // Obtain Blob data: See osmformat.proto
        if(!blob.zlib_data.isNull)
            bdata = BlobData(header.type, blob.zlib_data, true, index);
        else if(!blob.raw.isNull)
            bdata = BlobData(header.type, blob.raw, false, index);
        else
            throw new Exception("Unsupported compression.");
    }

    auto save() {
        return this;
    }
}

struct OpenStreetMapHeader {
    HeaderBlock headerBlock;
    ubyte[] index;
    OpenStreetMapDataRange data;
}

auto openStreetMapRange(string file) {
    // Need to figure out how to link header to data ranges
    auto fileHeadings = osmBlob(file);
    OpenStreetMapRange h;
    h.fileHeadings = fileHeadings;
    h.popFront();
    return h;
}

struct OpenStreetMapRange {
    OpenStreetMapBlob fileHeadings;
    OpenStreetMapHeader header;

    auto empty() {
        return fileHeadings.empty;
    }

    auto front() {
        return header;
    }

    auto popFront() {
        for(;!fileHeadings.empty; fileHeadings.popFront())
            if(fileHeadings.front.type == BlobType.osmHeader)
                break;
        if(!fileHeadings.empty) {
            header.headerBlock = to!HeaderBlock(fileHeadings.front);
            header.index = fileHeadings.bdata.index;
            fileHeadings.popFront();
            header.data.fileHeadings = fileHeadings;
        }
    }

    auto save() {
        return this;
    }
}

struct OpenStreetMapDataRange {
    OpenStreetMapBlob fileHeadings;

    auto empty() {
        if(fileHeadings.empty || fileHeadings.front.type == BlobType.osmHeader)
            return true;
        return false;
    }

    auto front() {
        return to!PrimitiveBlock(fileHeadings.front);
    }

    auto popFront() {
        fileHeadings.popFront();
    }

    auto save() {
        return this;
    }
}

void main(string[] args) {
    enforce(args.length == 2, "Usage: " ~ args[0] ~ " [file]");
    // A file contains a header followed by a sequence of fileblocks.
    auto osmRange = openStreetMapRange(args[1]);

    size_t headerCount, dataCount, bytesCount;

    scope(exit) {
        writeln("Headers: ", headerCount);
        writeln("Datas: ", dataCount);
        writeln("Bytes: ", bytesCount);
    }

    foreach(header; osmRange) {
        // In order to robustly detect illegal or corrupt files, the maximum
        // size of BlobHeader and Blob messages is limited. The length of the
        // BlobHeader *should* be less than 32 KiB (32*1024 bytes) and *must*
        // be less than 64 KiB. The uncompressed length of a Blob *should* be
        // less than 16 MiB (16*1024*1024 bytes) and *must* be less than 32
        // MiB.

        // There are currently two fileblock types for OSM data. These textual
        // type strings are stored in the type field in the BlobHeader
        //
        // The design lets other software extend the format to include
        // fileblocks of additional types for their own purposes. Parsers
        // should ignore and skip fileblock types that they do not recognize.
        headerCount++;
        // Contains a serialized HeaderBlock message (See osmformat.proto).
        // Every file must have one of these blocks before the first
        // 'OSMData' block.
        auto osmHeader = header.headerBlock;
        writeln("OSM bbox ", osmHeader.bbox);
        writeln("OSM author ", osmHeader.writingprogram);
        writeln("OSM required ", osmHeader.required_features);
        if(!osmHeader.source.isNull)
            writeln("OSM source ", osmHeader.source);
        foreach(osmDataBlock; header.data) {
            dataCount++;
            // Contains a serialized PrimitiveBlock message. (See
            // osmformat.proto). These contain the entities.
            writeln("OSM lat_off ", osmDataBlock.lat_offset);
            writeln("OSM lon_off ", osmDataBlock.lon_offset);
            writeln("OSM date ", !osmDataBlock.date_granularity.isNull);

            enforce(!osmDataBlock.stringtable.isNull);
            auto stringTable = osmDataBlock.stringtable.s.get.
                map!(x=>cast(char[])x);
            writeln("OSM String: ", stringTable.take(5), "...");
            writeln("OSM String Length: ", stringTable.length);

            // Nodes can be encoded one of two ways, as a Node and a special
            // dense format.
            if(!osmDataBlock.primitivegroup.front.nodes.isNull) {
                Node[] nodes = osmDataBlock.primitivegroup.front.nodes;
                if(!nodes.front.keys.isNull)
                    writefln("Node Tags: %s...",
                           zip(nodes.front.keys.get, nodes.front.vals.get).
                           map!(x=>tuple(stringTable[x[0]], stringTable[x[1]])).
                           map!(x=> x[0] ~"="~ x[1]).take(2));
            }
            if(!osmDataBlock.primitivegroup.front.dense.isNull) {
                // Keys and values for all nodes are encoded as a single array
                // of stringid's. Each node's tags are encoded in alternating
                // <keyid> <valid>. We use a single stringid of 0 to delimit
                // when the tags of a node ends and the tags of the next node
                // begin. The storage pattern is: ((<keyid> <valid>)* '0' )*
                DenseNodes nodes = osmDataBlock.primitivegroup.front.dense;
                if(!nodes.keys_vals.isNull) {
                    auto nodeTags = nodes.keys_vals.get().
                        splitter(0).array.front.chunks(2).
                        map!(x=>tuple(stringTable[x[0]],stringTable[x[1]])).
                        map!(x=> x[0] ~"="~ x[1]).take(2);
                    if(!nodeTags.empty)
                        writefln("Node Tags: %s...", nodeTags);
                }
            }
            if(!osmDataBlock.primitivegroup.front.ways.isNull) {
                Way[] ways = osmDataBlock.primitivegroup.front.ways;
                if(!ways.front.keys.isNull)
                    writefln("Way Tags: %s...",
                             zip(ways.front.keys.get, ways.front.vals.get).
                             map!(x=>tuple(stringTable[x[0]],stringTable[x[1]])).
                             map!(x=> x[0] ~"="~ x[1]).take(2));
            }
            if(!osmDataBlock.primitivegroup.front.relations.isNull) {
                Relation[] relations =
                    osmDataBlock.primitivegroup.front.relations;
                if(!relations.front.keys.isNull)
                    writefln("Relation Tags: %s...",
                             zip(relations.front.keys.get,
                                 relations.front.vals.get).
                             map!(x=>tuple(stringTable[x[0]],stringTable[x[1]])).
                             map!(x=> x[0] ~"="~ x[1]).take(2));
            }

            writeln("==============");
            writeln();
        }
    }
}
