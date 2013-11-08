module util.filerange;

import std.mmfile;

struct FileRange {
private:
	size_t index;
	size_t end;
	MmFile file;

public:
	static auto opCall(string file) {
		FileRange fr;
		fr.file = new MmFile(file);
		fr.end = fr.file.length;
		return fr;
	}

	@property auto empty() {
		assert(index <= end);
		return index == end;
	}

	auto popFront() {
		index++;
	}

	auto front() {
		return file[index];
	}

	@property auto length() {
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
