function v = values(it, typeString)
%VALUES  Decode one GPMF item's samples (big-endian) into numbers or text.
%   Numeric types give a repeat-by-(size/element size) double matrix; 'c'
%   and 'U' give text; 'F' gives FourCC text. '?' (complex) needs the TYPE
%   string that precedes it in the stream: pass it as typeString.
%   Scaling (SCAL) is applied by the caller (tv.gpmf.streams).
raw = it.raw;
sizes = struct('b', 1, 'B', 1, 'c', 1, 'd', 8, 'f', 4, 'F', 4, 'j', 8, 'J', 8, 'l', 4, 'L', 4, ...
               'q', 4, 'Q', 8, 's', 2, 'S', 2, 'U', 16);
switch it.type
    case {'c', 'U'}
        v = deblank(char(raw(:)'));  v = v(v ~= 0);
        return
    case 'F'
        v = cellstr(reshape(char(raw), 4, [])');
        return
    case '?'
        if nargin < 2, v = raw; return; end
        v = complexValues(raw, typeString, it.repeat, sizes);
        return
end
if ~isfield(sizes, it.type), v = raw; return; end
es = sizes.(it.type);
x = double(swapToNative(raw, it.type));
v = reshape(x, it.size / es, it.repeat)';
    function x = swapToNative(r, t)
        cls = struct('b', 'int8', 'B', 'uint8', 'd', 'double', 'f', 'single', 'j', 'int64', 'J', 'uint64', ...
                     'l', 'int32', 'L', 'uint32', 'q', 'int32', 'Q', 'int64', 's', 'int16', 'S', 'uint16');
        e = sizes.(t);
        r = reshape(r, e, []);
        r = flipud(r);                                  % big-endian to little-endian
        x = typecast(r(:)', cls.(t));
        if t == 'q', x = double(x) / 65536; end          % Q15.16
        if t == 'Q', x = double(x) / 2^32; end           % Q31.32
    end
end

function v = complexValues(raw, ts, rep, sizes)
% a sample made of mixed types, e.g. TYPE = 'fffS'
w = arrayfun(@(t) sizes.(t), ts);
stride = sum(w);
v = zeros(rep, numel(ts));
for r = 1:rep
    o = (r - 1) * stride;
    for j = 1:numel(ts)
        it = struct('type', ts(j), 'size', w(j), 'repeat', 1, 'raw', raw(o + 1:o + w(j)));
        o = o + w(j);
        val = tv.gpmf.values(it);
        if isnumeric(val), v(r, j) = val(1); end
    end
end
end
