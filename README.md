# libosm
Library which provides parsing of OpenStreetMap raw data. The exact scope is
not specifically defined and this is currently just hobby work.

The objective I have is to locate my address/street. That is, given data in a
osm.pbf file, can I locate the specific street in the specific city in the
specific state in the specific country in the specific world.

To achieve this I'm going to build this library in with a friendly API, rather
than brute forcing my way through the information. This way, when I inevitably
stop working on it, the library is possibly usable for other situations or
desires.

## Status
* Provides a range of [PBF](http://wiki.openstreetmap.org/wiki/PBF) data
  structures.

## Usage
This project is built with [dub](http://code.dlang.org/about) and expects
[ProtocolBuffer]() to be checked out into ../protobuf/ProtocolBuffer.

Build: $ dub build

Build library: $ dub build --config=libosm

Build example: $ dub build --config=osmexample

Example is run: ./osmexample planet.osm.pbf (don't do this at home)

## License
[Boost 1.0](http://www.boost.org/LICENSE_1_0.txt)
