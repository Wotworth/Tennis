function items = parse(bytes)
%PARSE  GoPro GPMF telemetry (key-length-value) into a list of items (TV-ING-12).
%   bytes: uint8 vector of GPMF data (from tv.gpmf.extract or an MP4's udta
%   GPMF box). Each item has key (4 chars), type (1 char; char(0) for a
%   nested container), size (bytes per sample), repeat (samples), and either
%   children (containers) or raw (uint8 payload, before decoding).
%   Layout per item: 4-byte key, 1-byte type, 1-byte sample size, 2-byte
%   repeat count (big-endian), then size*repeat bytes padded to 4.
%   Decode values with tv.gpmf.values.
bytes = uint8(bytes(:)');
items = walk(1, numel(bytes));

    function out = walk(a, b)
        out = struct('key', {}, 'type', {}, 'size', {}, 'repeat', {}, 'raw', {}, 'children', {});
        p = a;
        while p + 7 <= b
            key = char(bytes(p:p+3));
            if all(bytes(p:p+3) == 0), break; end            % padding
            type = char(bytes(p+4));
            sz = double(bytes(p+5));
            rep = double(bytes(p+6)) * 256 + double(bytes(p+7));
            n = sz * rep;
            q = p + 8;
            if q + n - 1 > b, break; end                       % truncated: stop cleanly
            it = struct('key', key, 'type', type, 'size', sz, 'repeat', rep, 'raw', [], 'children', []);
            if bytes(p+4) == 0
                it.children = walk(q, q + n - 1);
            else
                it.raw = bytes(q:q + n - 1);
            end
            out(end+1) = it; %#ok<AGROW>
            p = q + ceil(n / 4) * 4;
        end
    end
end
