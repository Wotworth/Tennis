function c = httpClient(endpoint, token)
%HTTPCLIENT  The PC's connection to the cloud API (TV-UP-01), with the write token.
%   Every call is HTTPS. The token comes from config/secrets.local.json
%   (uploadToken), never from Git. Not testable without the deployed Worker:
%   the tests use a fake with the same functions.
opt = weboptions('HeaderFields', {'Authorization', ['Bearer ' token]}, 'MediaType', 'application/json', 'Timeout', 120);
c.postJson = @(path, s) webwrite([endpoint path], s, opt);
c.putJson  = @(path, s) webwrite([endpoint path], s, setfield(opt, 'RequestMethod', 'put')); %#ok<SFLD>
c.getJson  = @(path) webread([endpoint path], opt);
c.putJsonUrl = @(url, s) webwrite(url, s, weboptions('MediaType', 'application/json', 'RequestMethod', 'put', 'Timeout', 120));
c.putFile  = @(url, file) putFile(url, file);
c.putBytes = @(url, b) webwrite(url, b, weboptions('MediaType', 'application/octet-stream', 'RequestMethod', 'put', 'Timeout', 600));
end

function r = putFile(url, file)
% streams the file from disk (matlab.net.http), so a 1 GB reel is not read into memory
import matlab.net.http.*
import matlab.net.http.io.*
req = RequestMessage('put', [], FileProvider(file));
resp = req.send(url);
if resp.StatusCode ~= StatusCode.OK, error('tv:upload', 'Upload of %s failed: %s', file, char(resp.StatusLine)); end
r = resp.Body.Data;
end
