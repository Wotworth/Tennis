function bytes = udta(file)
%UDTA  The global GPMF block of a GoPro MP4 (moov/udta/GPMF): camera serial, firmware, lens.
%   Walks the MP4's boxes without reading the video data. Returns [] if absent.
bytes = [];
fid = fopen(file, 'r', 'ieee-be');
if fid < 0, return; end
c = onCleanup(@() fclose(fid));
fseek(fid, 0, 'eof');  total = ftell(fid);  fseek(fid, 0, 'bof');
moov = findBox(fid, 0, total, 'moov');
if isempty(moov), return; end
ud = findBox(fid, moov(1), moov(2), 'udta');
if isempty(ud), return; end
g = findBox(fid, ud(1), ud(2), 'GPMF');
if isempty(g), return; end
fseek(fid, g(1), 'bof');
bytes = fread(fid, g(2) - g(1), 'uint8=>uint8')';
end

function r = findBox(fid, a, b, want)
% [payloadStart payloadEnd] of the first box named want between byte a and b
r = [];  p = a;
while p + 8 <= b
    fseek(fid, p, 'bof');
    sz = fread(fid, 1, 'uint32');  typ = char(fread(fid, 4, 'uint8')');
    hdr = 8;
    if sz == 1, sz = fread(fid, 1, 'uint64'); hdr = 16; end
    if sz == 0, sz = b - p; end
    if sz < hdr, return; end
    if strcmp(typ, want), r = [p + hdr, p + sz]; return; end
    p = p + sz;
end
end
