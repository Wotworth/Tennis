function n = calibrationCheck(outDir, sessionId, client)
%CALIBRATIONCHECK  Send a held session's calibration question to the app (TV-CAL-21).
%   n = tv.ops.calibrationCheck(outDir, sessionId, client)
%   tv.pipeline.run stops a session whose court-line fit is doubtful and leaves
%   outDir/calibration/calibration.json with each doubtful camera's picture (tv.calib.writeCheck).
%   Each picture goes up through the session's upload link; one POST /calibration then lists
%   the checks for the app's "court corners" page. Posting a check again (the taps did not make
%   a court) clears the earlier answer for that camera. n: how many checks were sent.
n = 0;
f = fullfile(outDir, 'calibration', 'calibration.json');
if ~exist(f, 'file'), return; end
J = tv.readJson(f);
C = J.checks;
if ~iscell(C), C = num2cell(C(:)'); end
items = cell(1, numel(C));
for k = 1:numel(C)
    c = C{k};
    file = fullfile(outDir, strrep(c.picturePath, '/', filesep));
    sha = tv.ingest.sha256File(file);  d = dir(file);
    a = client.postJson(sprintf('/sessions/%s/upload-url', sessionId), struct('path', c.picturePath, 'sha256', sha, 'size', d.bytes));
    if ~(isfield(a, 'exists') && a.exists), client.putFile([a.url '&sha256=' sha], file); end
    items{k} = struct('sessionId', sessionId, 'cam', c.cam, 'picturePath', c.picturePath, 'width', c.width, 'height', c.height, ...
        'scale', c.scale, 'support', c.support, 'reason', c.reason, 'lines', {lineList(c.lines)});
end
client.postJson('/calibration', struct('checks', {items}));
n = numel(items);
end

function L = lineList(x)
% the fitted lines as a list of N-by-2 runs, however the JSON reader shaped them (runs of equal
% length come back as one block of numbers), so they are written out again as a list of lines
if iscell(x), L = x(:)'; return; end
if ndims(x) == 3
    L = arrayfun(@(i) reshape(x(i, :, :), [], 2), 1:size(x, 1), 'UniformOutput', false);
else
    L = {x};
end
end
