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
int toNative(ubyte[] num) {
    import std.system;
    union Hold {
        ubyte[4] arr;
        int number;
    }
    Hold a;
    a.arr = num;
    if(endian == Endian.littleEndian)
        a.arr[0..4].reverse();
    return a.number;
}

void main(string[] args) {
    enforce(args.length == 2, "Usage: " ~ args[0] ~ " [file]");
    // A file contains a header followed by a sequence of fileblocks.
    auto datastream = FileRange(args[1]);

    size_t headerCount, dataCount, bytesCount;

    scope(exit) {
        writeln("Headers: ", headerCount);
        writeln("Datas: ", dataCount);
        writeln("Bytes: ", bytesCount);
    }

    while(!datastream.empty) {
        if(datastream.bufferLength < 4) {
            // This shows bytes which haven't been read.
            assert(false, "Should parse all bytes?");
        }

        // The format is a repeating sequence of:
        // * int4: length of the BlobHeader message in network byte order
        auto size = toNative(datastream[0..4]);
        datastream.popFrontN(4);
        bytesCount += 4;

        // serialized BlobHeader message
        auto osmData = datastream[0..size];
        datastream.popFrontN(size);
        bytesCount += size;
        auto header = BlobHeader(osmData);
        // contains the type of data in this block message.
        writeln("Blob Type: ", header.type);
        // index may include metadata about the following blob
        writeln("Has Index Data: ", !header.indexdata.isNull);
        // contains the serialized size of the subsequent Blob message
        writeln("Blob Size: ", header.datasize);
        writeln();

        // * serialized Blob message (size is given in the header)
        // Blob is currently used to store an arbitrary blob of data, either
        // uncompressed or in zlib/deflate compressed format.
        osmData = datastream[0..header.datasize];
        datastream.popFrontN(header.datasize);
        bytesCount += header.datasize;
        auto blob = Blob(osmData);
        // No compression
        writeln("Has raw data: ", !blob.raw.isNull);
        // Only set when compressed, to the uncompressed size
        writeln("Blob raw_size: ", blob.raw_size);
        writeln("Has zlib: ", !blob.zlib_data.isNull);
        writeln();

        // Obtain Blob data: See osmformat.proto
        if(!blob.zlib_data.isNull)
            osmData = cast(ubyte[]) uncompress(blob.zlib_data);
        else if(!blob.raw.isNull)
            osmData = blob.raw;
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
        if(header.type == "OSMHeader") {
            headerCount++;
            // Contains a serialized HeaderBlock message (See osmformat.proto).
            // Every file must have one of these blocks before the first
            // 'OSMData' block.
            auto osmHeader = HeaderBlock(osmData);
            writeln("OSM bbox ", osmHeader.bbox);
            writeln("OSM author ", osmHeader.writingprogram);
            writeln("OSM required ", osmHeader.required_features);
            if(!osmHeader.source.isNull)
                writeln("OSM source ", osmHeader.source);
        } else if(header.type == "OSMData") {
            dataCount++;
            // Contains a serialized PrimitiveBlock message. (See
            // osmformat.proto). These contain the entities.
            auto osmDataBlock = PrimitiveBlock(osmData);
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
