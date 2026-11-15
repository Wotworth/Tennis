function out = retry(fn, tries)
%RETRY  Call fn, retrying with growing waits (1, 2, 4, 8 s) if it errors (TV-UP-02).
if nargin < 2, tries = 5; end
for k = 1:tries
    try
        if nargout > 0, out = fn(); else, fn(); end
        return
    catch err
        if k == tries, rethrow(err); end
        pause(2^(k - 1));
    end
end
end
