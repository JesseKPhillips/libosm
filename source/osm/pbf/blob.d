module osm.pbf.blob;

import std.algorithm;
import std.conv;
import std.exception;
import std.range;
import std.zlib;

import util.filerange;

import osm.pbf.osmpbf;
import osm.pbf.osmpbffile;

// Converts ubyte num to proper endian
// Used on initial 4 bytes before a HeaderBlock
private int toNative(ubyte[] num) {
	import std.system;
	union Hold {
		ubyte[4] arr;
		int number;
	}
	Hold a;
	a.arr[] = num[];
	version(LittleEndian)
		a.arr[0..4].reverse();
	return a.number;
}

enum supportedFeaturs = ["DenseNodes", "OsmSchema-V0.6"];

// Type stored in BlobData
enum BlobType { unknown = -1, osmData, osmHeader }

/*
 * This stores the raw file data.
 *
 * Cast this type to a HeaderBlock or PrimitaveBlock.
 * Check the type to identify what is stored.
 * If the type is PrimitiveBlock decompression will be handled automatically
 * and upon casting.
 */
package struct BlobData {
    string type_;
    ubyte[] data;
    bool compressed;
    ubyte[] index;

    // Returns the decompressed PB encoded data
    ubyte[] rawData() {
        if(compressed) {
            data = cast(ubyte[]) uncompress(data);
            compressed = false;
        }

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
                return BlobType.unknown;
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
    auto ans = OpenStreetMapBlob!FileRange(FileRange(file));
    ans.prime();
    return ans;
}

auto osmBlob(Range)(Range data) if(hasSlicing!Range && is(ElementType!Range == ubyte)) {
	auto ans = OpenStreetMapBlob!Range(data);
	ans.prime();
	return ans;
}

struct OpenStreetMapBlob(Range) if(hasSlicing!Range) {
    Range datastream;
    private BlobData bdata;
    private bool _empty;

    auto index() {
        return bdata.index;
    }

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
        auto size = toNative(datastream[0..4].array);
        datastream.popFrontN(4);

        // serialized BlobHeader message
        auto osmData = datastream[0..size].array;
        datastream.popFrontN(size);
        auto header = BlobHeader(osmData);

        // * serialized Blob message (size is given in the header)
        // Blob is currently used to store an arbitrary blob of data, either
        // uncompressed or in zlib/deflate compressed format.
        osmData = datastream[0..header.datasize].array;
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
