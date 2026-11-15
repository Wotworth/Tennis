function [srcHash, bytes] = copyHashed(src, dst, opts)
%COPYHASHED  Copy a file and compute its SHA-256 in the same pass (TV-ING-05).
%   The card is read once: each chunk is hashed and written. While copying,
%   dst carries a '.incomplete' marker file beside it; the marker is removed
%   only when the whole file is written (TV-ING-07). If the source vanishes
%   mid-copy (card pulled), the error propagates and the marker stays.
%   opts.chunkBytes (default 8 MB); opts.faultAfterBytes simulates a pulled
%   card in tests.
if nargin < 3, opts = struct(); end
if ~isfield(opts, 'chunkBytes'), opts.chunkBytes = 8 * 2^20; end
if ~isfield(opts, 'faultAfterBytes'), opts.faultAfterBytes = Inf; end
d = fileparts(dst);
if ~exist(d, 'dir'), mkdir(d); end
marker = [dst '.incomplete'];
fclose(fopen(marker, 'w'));
fi = fopen(src, 'r');
if fi < 0, error('tv:ingest:read', 'Cannot read %s', src); end
fo = fopen(dst, 'w');
md = javaMethod('getInstance', 'java.security.MessageDigest', 'SHA-256');
bytes = 0;
try
    while true
        b = fread(fi, opts.chunkBytes, 'uint8=>uint8');
        if isempty(b), break; end
        if bytes + numel(b) > opts.faultAfterBytes
            error('tv:ingest:pulled', 'The card was removed during the copy (simulated).');
        end
        md.update(typecast(b(:), 'int8'));
        fwrite(fo, b, 'uint8');
        bytes = bytes + numel(b);
    end
catch err
    fclose(fi);  fclose(fo);
    rethrow(err);
end
fclose(fi);  fclose(fo);
srcHash = tv.ingest.hex(md.digest());
delete(marker);
end
