module util.filerange;

import std.mmfile;

auto fileRange(ByteType = ubyte)(string file) {
	import std.traits;
	static if(is(ByteType == ubyte)) {
		FileRange!ByteType fr;
		fr.file = new MmFile(file);
		fr.end = fr.file.length;
		return fr;
	} else
	static if(isSomeChar!ByteType) {
		UtfFileRange!ByteType u8fr;
		u8fr.fr.file = new MmFile(file);
		u8fr.fr.end = u8fr.fr.file.length;
		u8fr.prime();
		return u8fr;
	} else
		static assert(false, "Supported FileRange bytes: ubyte, dchar, wchar, char");
}

struct UtfFileRange(C) {
	FileRange!C fr;
	dchar cur;
	@property auto empty() {
		return cur == dchar.init;
	}

	auto popFront() {
		assert(!empty, "Popping front of empty range");
		if(fr.empty) {
			cur = dchar.init;
			return;
		}
		prime();
	}

	auto prime() {
		import std.utf;
		cur = fr.decodeFront;
	}

	auto front() {
		return cur;
	}

	auto save() {
		return this;
	}
}

struct FileRange(ByteType = ubyte) {
private:
	ulong index;
	ulong end;
	MmFile file;

public:
	@property auto empty() {
		assert(index <= end);
		return index == end;
	}

	auto popFront() {
		index++;
	}

	auto front() {
		return cast(ByteType)file[index];
	}

	@property ulong length() {
		return end - index;
	}

	auto opSlice(size_t x, size_t y) {
		import core.exception;
		import std.exception;
		enforceEx!RangeError(y+index <= end);
		FileRange fr = this;
		fr.end = y + index;
		fr.index += x;
		return fr;
	}

	@property auto save() {
		return this;
	}
}
