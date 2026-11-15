function h = sha256File(file)
%SHA256FILE  SHA-256 of a whole file, read in 8 MB chunks.
fi = fopen(file, 'r');
if fi < 0, error('tv:ingest:read', 'Cannot read %s', file); end
md = javaMethod('getInstance', 'java.security.MessageDigest', 'SHA-256');
while true
    b = fread(fi, 8 * 2^20, 'uint8=>uint8');
    if isempty(b), break; end
    md.update(typecast(b(:), 'int8'));
end
fclose(fi);
h = tv.ingest.hex(md.digest());
end
