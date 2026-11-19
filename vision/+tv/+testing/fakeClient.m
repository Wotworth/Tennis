function [c, log] = fakeClient(pending, existing)
%FAKECLIENT  A stand-in for the cloud API that records every call (tests).
%   pending: struct with fields conditions and identity, and optionally calibration
%   (lists the PC would fetch). existing: cell of file paths the "Worker" already holds.
%   log: containers.Map (a handle) from call kind to a cell of requests.
if nargin < 1, pending = struct('conditions', [], 'identity', []); end
if nargin < 2, existing = {}; end
log = containers.Map();
for k = {'post', 'put', 'get', 'file', 'bytes', 'urlput'}, log(k{1}) = {}; end
c.postJson = @(path, s) post(path, s);
c.putJson = @(path, s) add('put', {path, s});
c.getJson = @(path) get(path);
c.putJsonUrl = @(url, s) urlput(url, s);
c.putFile = @(url, f) add('file', {url, f});
c.putBytes = @(url, b) bytes(url, b);

    function r = add(kind, item)
        L = log(kind);  L{end+1} = item;  log(kind) = L;  r = struct('ok', true);
    end
    function r = post(path, s)
        add('post', {path, s});
        r = struct('ok', true);
        if ~isempty(strfind(path, '/upload-url'))
            if any(strcmp(existing, s.path)), r = struct('exists', true);
            else, r = struct('exists', false, 'url', ['https://api.test/x/' s.path '?exp=1&sig=s'], 'multipart', s.size > 100 * 2^20); end
        end
    end
    function r = get(path)
        add('get', {path});
        if strcmp(path, '/conditions/pending'), r = pending.conditions;
        elseif strcmp(path, '/identity/pending'), r = pending.identity;
        elseif strcmp(path, '/calibration/answered') && isfield(pending, 'calibration'), r = pending.calibration;
        else, r = []; end
    end
    function r = urlput(url, s)
        add('urlput', {url, s});
        r = struct('uploadId', 'up-1', 'ok', true);
    end
    function r = bytes(url, b)
        add('bytes', {url, numel(b)});
        r = struct('partNumber', 1, 'etag', 'e');
    end
end
