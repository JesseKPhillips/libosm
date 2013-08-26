module util.filerange;

import std.mmfile;

struct FileRange {
private:
	size_t index;
    MmFile file;
public:
	static auto opCall(string file) {
		FileRange fr;
		fr.file = new MmFile(file);
		return fr;
	}

	auto empty() {
		return file.length == index;
	}

	auto popFront() {
		index++;
	}

	auto front() {
		return file[index];
	}

    auto bufferLength() {
        return file.length - index;
    }

	auto opSlice(size_t x, size_t y) {
        assert(y+index <= file.length);
        return cast(ubyte[]) file[x+index..y+index];
	}
}
