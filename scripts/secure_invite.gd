extends RefCounted
# Versioned, self-contained invite: endpoint + 128-bit certificate fingerprint.
# The checksum catches typing mistakes; authentication comes from the fingerprint.
const PREFIX="NC1-"
const DEFAULT_PORT=24567
const PIN_BYTES=16
const MAX_LENGTH=400

static func digest(bytes: PackedByteArray) -> PackedByteArray:
	var hash=HashingContext.new();hash.start(HashingContext.HASH_SHA256);hash.update(bytes)
	return hash.finish()

static func fingerprint(certificate: PackedByteArray) -> PackedByteArray:
	return digest(certificate).slice(0,PIN_BYTES)

static func endpoint(address: String) -> Dictionary:
	var parts=address.strip_edges().split(":")
	if parts.size()>2 or parts[0].is_empty():return {}
	var host=parts[0].to_lower();var port=DEFAULT_PORT
	if parts.size()==2:
		if parts[1].is_empty() or not parts[1].is_valid_int():return {}
		port=int(parts[1])
	if port<1 or port>65535 or host.length()>253:return {}
	var pattern=RegEx.new();pattern.compile("^[a-z0-9](?:[a-z0-9.-]*[a-z0-9])?$")
	if pattern.search(host)==null:return {}
	for label in host.split("."):
		if label.is_empty() or label.length()>63 or label.begins_with("-") or label.ends_with("-"):return {}
	# Do not quietly treat a mistyped numeric IPv4 address as a DNS name.
	var numeric=RegEx.new();numeric.compile("^[0-9.]+$")
	if numeric.search(host)!=null and not host.is_valid_ip_address():return {}
	return {"host":host,"port":port}

static func _base64(bytes: PackedByteArray) -> String:
	return Marshalls.raw_to_base64(bytes).replace("+","-").replace("/","_").trim_suffix("=").trim_suffix("=")

static func encode(address: String,pin: PackedByteArray) -> String:
	var target=endpoint(address)
	if target.is_empty() or pin.size()!=PIN_BYTES:return ""
	var ipv4=target.host.is_valid_ip_address()
	var data=PackedByteArray([0 if ipv4 else 1])
	if target.port!=DEFAULT_PORT:
		data[0]|=128;data.append(target.port>>8);data.append(target.port&255)
	if ipv4:
		for part in target.host.split("."):data.append(int(part))
	else:data.append_array(target.host.to_ascii_buffer())
	data.append_array(pin);data.append_array(digest(data).slice(0,2))
	return PREFIX+_base64(data)

static func decode(code: String) -> Dictionary:
	code=code.strip_edges()
	if not code.begins_with(PREFIX) or code.length()>MAX_LENGTH:return {}
	var text=code.trim_prefix(PREFIX)
	var pattern=RegEx.new();pattern.compile("^[A-Za-z0-9_-]+$")
	if text.length()<27 or pattern.search(text)==null or text.length()%4==1:return {}
	var padded=text.replace("-","+").replace("_","/")
	while padded.length()%4:padded+="="
	var data=Marshalls.base64_to_raw(padded)
	if data.size()<20 or _base64(data)!=text or data[0] not in [0,1,128,129]:return {}
	if data.slice(-2)!=digest(data.slice(0,-2)).slice(0,2):return {}
	var offset=1;var port=DEFAULT_PORT
	if data[0]&128:
		if data.size()<22:return {}
		port=(data[1]<<8)|data[2];offset=3
	var host_bytes=data.slice(offset,data.size()-PIN_BYTES-2)
	var host=""
	if data[0]&1:
		for byte in host_bytes:
			if byte>127:return {}
		host=host_bytes.get_string_from_ascii()
	else:
		if host_bytes.size()!=4:return {}
		host="%d.%d.%d.%d"%[host_bytes[0],host_bytes[1],host_bytes[2],host_bytes[3]]
	var target=endpoint(host+":"+str(port))
	if target.is_empty():return {}
	target["pin"]=data.slice(data.size()-PIN_BYTES-2,data.size()-2)
	if encode(host+":"+str(port),target.pin)!=code:return {}
	return target
