module osmpbffile;
import ProtocolBuffer.conversion.pbbinary;
import std.conv;
import std.typecons;

string makeString(T)(T v) {
	return to!string(v);
}
///protoc --java_out=../.. fileformat.proto

///
///  STORAGE LAYER: Storing primitives.
///
struct Blob {
	// deal with unknown fields
	ubyte[] ufields;
	///
	Nullable!(ubyte[]) raw;
	/// No compression
	Nullable!(int) raw_size;
	/// When compressed, the uncompressed size

	/// Possible compressed versions of the data.
	Nullable!(ubyte[]) zlib_data;
	/// PROPOSED feature for LZMA compressed data. SUPPORT IS NOT REQUIRED.
	Nullable!(ubyte[]) lzma_data;
	/// Formerly used for bzip2 compressed data. Depreciated in 2010.
	deprecated ref Nullable!(ubyte[]) OBSOLETE_bzip2_data() {
		return OBSOLETE_bzip2_data_dep;
	}
	private Nullable!(ubyte[])	 OBSOLETE_bzip2_data_dep;

	ubyte[] Serialize(int field = -1) const {
		ubyte[] ret;
		// Serialize member 1 Field Name raw
		if (!raw.isNull) ret ~= toByteString(raw.get(),1);
		// Serialize member 2 Field Name raw_size
		if (!raw_size.isNull) ret ~= toVarint(raw_size.get(),2);
		// Serialize member 3 Field Name zlib_data
		if (!zlib_data.isNull) ret ~= toByteString(zlib_data.get(),3);
		// Serialize member 4 Field Name lzma_data
		if (!lzma_data.isNull) ret ~= toByteString(lzma_data.get(),4);
		// Serialize member 5 Field Name OBSOLETE_bzip2_data
		if (!OBSOLETE_bzip2_data_dep.isNull) ret ~= toByteString(OBSOLETE_bzip2_data_dep.get(),5);
		ret ~= ufields;
		// take care of header and length generation if necessary
		if (field != -1) {
			ret = genHeader(field,WireType.lenDelimited)~toVarint(ret.length,field)[1..$]~ret;
		}
		return ret;
	}

	// if we're root, we can assume we own the whole string
	// if not, the first thing we need to do is pull the length that belongs to us
	static Blob Deserialize(ubyte[] manip) {
		return Blob(manip,true);
	}
	this(ubyte[] manip,bool isroot=true) {
		this(manip,isroot);
	}
	this(ref ubyte[] manip,bool isroot=true) {
		ubyte[] input = manip;
		// cut apart the input string
		if (!isroot) {
			uint len = fromVarint!(uint)(manip);
			input = manip[0..len];
			manip = manip[len..$];
		}
		while(input.length) {
			int header = fromVarint!(int)(input);
			auto wireType = getWireType(header);
			switch(getFieldNumber(header)) {
			case 1:// Deserialize member 1 Field Name raw
				if (wireType != WireType.lenDelimited)
					throw new Exception("Invalid wiretype " ~
					   to!(string)(wireType) ~
					   " for variable type bytes");

				raw =
				   fromByteString!(ubyte[])(input);
			break;
			case 2:// Deserialize member 2 Field Name raw_size
				if (wireType != WireType.varint)
					throw new Exception("Invalid wiretype " ~
					   to!(string)(wireType) ~
					   " for variable type int32");

				raw_size = fromVarint!(int)(input);
			break;
			case 3:// Deserialize member 3 Field Name zlib_data
				if (wireType != WireType.lenDelimited)
					throw new Exception("Invalid wiretype " ~
					   to!(string)(wireType) ~
					   " for variable type bytes");

				zlib_data =
				   fromByteString!(ubyte[])(input);
			break;
			case 4:// Deserialize member 4 Field Name lzma_data
				if (wireType != WireType.lenDelimited)
					throw new Exception("Invalid wiretype " ~
					   to!(string)(wireType) ~
					   " for variable type bytes");

				lzma_data =
				   fromByteString!(ubyte[])(input);
			break;
			case 5:// Deserialize member 5 Field Name OBSOLETE_bzip2_data
				if (wireType != WireType.lenDelimited)
					throw new Exception("Invalid wiretype " ~
					   to!(string)(wireType) ~
					   " for variable type bytes");

				OBSOLETE_bzip2_data_dep =
				   fromByteString!(ubyte[])(input);
			break;
			default:
					// rip off unknown fields
				if(input.length)
					ufields ~= toVarint(header)~
					   ripUField(input,getWireType(header));
				break;
			}
		}
	}

	void MergeFrom(Blob merger) {
		if (!merger.raw.isNull) raw = merger.raw;
		if (!merger.raw_size.isNull) raw_size = merger.raw_size;
		if (!merger.zlib_data.isNull) zlib_data = merger.zlib_data;
		if (!merger.lzma_data.isNull) lzma_data = merger.lzma_data;
		if (!merger.OBSOLETE_bzip2_data_dep.isNull) OBSOLETE_bzip2_data_dep = merger.OBSOLETE_bzip2_data_dep;
	}

}
/// A file contains an sequence of fileblock headers, each prefixed by
/// their length in network byte order, followed by a data block
/// containing the actual data. types staring with a "_" are reserved.
struct BlobHeader {
	// deal with unknown fields
	ubyte[] ufields;
	///
	Nullable!(string) type;
	///
	Nullable!(ubyte[]) indexdata;
	///
	Nullable!(int) datasize;

	ubyte[] Serialize(int field = -1) const {
		ubyte[] ret;
		// Serialize member 1 Field Name type
		ret ~= toByteString(type.get(),1);
		// Serialize member 2 Field Name indexdata
		if (!indexdata.isNull) ret ~= toByteString(indexdata.get(),2);
		// Serialize member 3 Field Name datasize
		ret ~= toVarint(datasize.get(),3);
		ret ~= ufields;
		// take care of header and length generation if necessary
		if (field != -1) {
			ret = genHeader(field,WireType.lenDelimited)~toVarint(ret.length,field)[1..$]~ret;
		}
		return ret;
	}

	// if we're root, we can assume we own the whole string
	// if not, the first thing we need to do is pull the length that belongs to us
	static BlobHeader Deserialize(ubyte[] manip) {
		return BlobHeader(manip,true);
	}
	this(ubyte[] manip,bool isroot=true) {
		this(manip,isroot);
	}
	this(ref ubyte[] manip,bool isroot=true) {
		ubyte[] input = manip;
		// cut apart the input string
		if (!isroot) {
			uint len = fromVarint!(uint)(manip);
			input = manip[0..len];
			manip = manip[len..$];
		}
		while(input.length) {
			int header = fromVarint!(int)(input);
			auto wireType = getWireType(header);
			switch(getFieldNumber(header)) {
			case 1:// Deserialize member 1 Field Name type
				if (wireType != WireType.lenDelimited)
					throw new Exception("Invalid wiretype " ~
					   to!(string)(wireType) ~
					   " for variable type string");

				type =
				   fromByteString!(string)(input);
			break;
			case 2:// Deserialize member 2 Field Name indexdata
				if (wireType != WireType.lenDelimited)
					throw new Exception("Invalid wiretype " ~
					   to!(string)(wireType) ~
					   " for variable type bytes");

				indexdata =
				   fromByteString!(ubyte[])(input);
			break;
			case 3:// Deserialize member 3 Field Name datasize
				if (wireType != WireType.varint)
					throw new Exception("Invalid wiretype " ~
					   to!(string)(wireType) ~
					   " for variable type int32");

				datasize = fromVarint!(int)(input);
			break;
			default:
					// rip off unknown fields
				if(input.length)
					ufields ~= toVarint(header)~
					   ripUField(input,getWireType(header));
				break;
			}
		}
		if (type.isNull) throw new Exception("Did not find a type in the message parse.");
		if (datasize.isNull) throw new Exception("Did not find a datasize in the message parse.");
	}

	void MergeFrom(BlobHeader merger) {
		if (!merger.type.isNull) type = merger.type;
		if (!merger.indexdata.isNull) indexdata = merger.indexdata;
		if (!merger.datasize.isNull) datasize = merger.datasize;
	}

}
