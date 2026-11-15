function rep = session(outDir, sessionId, result, client, opts)
%SESSION  Upload one processed session to the cloud API (TV-UP-01 to TV-UP-03).
%   1. registers the session (POST /sessions)
%   2. uploads each file through a link the Worker issues; a file the
%      Worker already holds with the same SHA-256 is skipped (idempotent,
%      TV-UP-02); files over 100 MB go in parts (multipart)
%   3. sends the rows (PUT /sessions/{id}/data) with complete = true, so the
%      session shows in the app only once everything is there
%   client: struct of functions (tv.upload.httpClient on the PC; a fake in
%   tests): postJson(path, s), putJson(path, s), getJson(path),
%   putFile(url, file), putBytes(url, bytes) for multipart parts.
%   Nothing about courts or health goes up: the app keeps those.
if nargin < 5, opts = struct(); end
if ~isfield(opts, 'partBytes'), opts.partBytes = 64 * 2^20; end
retry = @(f) tv.upload.retry(f, 5);
s = result.summaryForUpload;
retry(@() client.postJson('/sessions', struct('id', sessionId, 'startUtc', s.startUtc, 'mode', s.mode)));
files = listFiles(outDir);
rep.uploaded = {};  rep.skipped = {};
for i = 1:numel(files)
    rel = files{i};  full = fullfile(outDir, rel);
    d = dir(full);
    sha = tv.ingest.sha256File(full);
    a = retry(@() client.postJson(sprintf('/sessions/%s/upload-url', sessionId), ...
        struct('path', strrep(rel, '\', '/'), 'sha256', sha, 'size', d.bytes)));
    if isfield(a, 'exists') && a.exists, rep.skipped{end+1} = rel; continue; end
    if isfield(a, 'multipart') && a.multipart
        c = retry(@() client.putJsonUrl([a.url '&action=mpu-create&sha256=' sha], struct()));
        fid = fopen(full, 'r');  n = 0;  parts = struct('partNumber', {}, 'etag', {});
        while true
            b = fread(fid, opts.partBytes, 'uint8=>uint8');
            if isempty(b), break; end
            n = n + 1;
            p = retry(@() client.putBytes(sprintf('%s&action=mpu-part&uploadId=%s&part=%d', a.url, c.uploadId, n), b));
            parts(end+1) = struct('partNumber', n, 'etag', p.etag); %#ok<AGROW>
        end
        fclose(fid);
        retry(@() client.putJsonUrl(sprintf('%s&action=mpu-complete&uploadId=%s', a.url, c.uploadId), struct('parts', parts)));
    else
        retry(@() client.putFile([a.url '&sha256=' sha], full));
    end
    rep.uploaded{end+1} = rel;
end
retry(@() client.putJson(sprintf('/sessions/%s/data', sessionId), result.dataForUpload));
end

function files = listFiles(outDir)
% the files the app uses (TV-OUT-01 to 05); the stages and logs stay on the PC
files = {};
for f = {'session.json', 'shots.json', 'rallies.json', 'trajectories.json.gz', 'reel_1080p.mp4'}
    if exist(fullfile(outDir, f{1}), 'file'), files{end+1} = f{1}; end %#ok<AGROW>
end
for sub = {'clips', 'plots'}
    d = dir(fullfile(outDir, sub{1}, '*.*'));
    for k = 1:numel(d)
        if ~d(k).isdir, files{end+1} = [sub{1} '/' d(k).name]; end %#ok<AGROW>
    end
end
end
