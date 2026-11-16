function rep = syncChecks(st, client, items)
%SYNCCHECKS  Upload new check crops, and fold Chris's answers into the test set.
%   1. each crop goes up through its session's upload link; then one
%      POST /checks lists them for the app
%   2. GET /checks/answered: answers join the test set (with the crop's
%      origin remembered in checks-out/pending.mat), then are marked applied
rep.uploaded = 0;  rep.answered = 0;
if nargin > 2 && ~isempty(items)
    for it = items(:)'
        sha = tv.ingest.sha256File(it.file);  d = dir(it.file);
        a = client.postJson(sprintf('/sessions/%s/upload-url', it.sessionId), struct('path', it.cropPath, 'sha256', sha, 'size', d.bytes));
        if ~(isfield(a, 'exists') && a.exists), client.putFile([a.url '&sha256=' sha], it.file); end
    end
    client.postJson('/checks', struct('checks', rmfield(items, {'originX', 'originY', 'cam', 'frame', 'file'})));
    rep.uploaded = numel(items);
end
A = client.getJson('/checks/answered');
if isempty(A), return; end
if iscell(A), A = [A{:}]; end
S = load(fullfile(st.checksOut, 'pending.mat'));  P = S.P;
keep = [];
for k = 1:numel(A)
    j = find(strcmp({P.sessionId}, A(k).sessionId) & strcmp({P.frameRef}, A(k).frameRef), 1);
    if isempty(j), continue; end
    A(k).originX = P(j).originX;  A(k).originY = P(j).originY;  A(k).cam = P(j).cam;  A(k).frame = P(j).frame;
    if ~isfield(A, 'ansX') || isempty(A(k).ansX), A(k).ansX = NaN; A(k).ansY = NaN; end
    keep(end+1) = k; %#ok<AGROW>
end
tv.learn.testsetAdd(st, A(keep));
for k = keep, client.postJson(sprintf('/checks/%d/applied', A(k).id), struct()); end
rep.answered = numel(keep);
end
