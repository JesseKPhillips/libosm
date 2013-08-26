pbformat=protobuf/osmpbffile.d protobuf/osmpbf.d
util=util/filerange.d
pblib=-L-ldprotobuf -L-L../protobuf/ProtocolBuffer -I../protobuf

testnav: osmpbfexample.d $(pbformat) $(util) 
	dmd $(pblib) $(args) $+
