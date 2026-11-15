function notify(cfg, title, text)
%NOTIFY  A message to Chris's phone through ntfy, and the log (TV-OPS-01).
%   cfg.alerts.server and the topic name, read from the ignored file
%   config/secrets.local.json (field ntfyTopic) so the topic never reaches
%   Git. The topic should be long and random (anyone who guesses it can read
%   it), or protected with an access token (field ntfyToken).
%   Without a topic it only logs.
fprintf('[notify] %s: %s\n', title, text);
here = fileparts(fileparts(fileparts(mfilename('fullpath'))));
sf = fullfile(here, 'config', 'secrets.local.json');
if ~exist(sf, 'file'), return; end
sec = jsondecode(fileread(sf));
if ~isfield(sec, 'ntfyTopic') || isempty(sec.ntfyTopic), return; end
url = sprintf('%s/%s', cfg.alerts.ntfyServer, sec.ntfyTopic);
hdr = {'Title', title};
if isfield(sec, 'ntfyToken') && ~isempty(sec.ntfyToken), hdr(end+1, :) = {'Authorization', ['Bearer ' sec.ntfyToken]}; end
try
    webwrite(url, text, weboptions('HeaderFields', hdr, 'MediaType', 'text/plain', 'Timeout', 10));
catch err
    fprintf('[notify] could not reach ntfy: %s\n', err.message);
end
end
