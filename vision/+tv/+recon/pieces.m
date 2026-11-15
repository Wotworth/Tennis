function P = pieces(tracksByCam, rec, sync)
%PIECES  Each camera's ball tracks cut at sudden changes, with their session times.
%   Returns a struct array: cam, obs ([cam frame u v]), t (session times),
%   tStart, tEnd. A cut point itself is left out of both pieces.
P = struct('cam', {}, 'obs', {}, 't', {}, 'tStart', {}, 'tEnd', {});
for k = 1:numel(tracksByCam)
    for trk = tracksByCam{k}(:)'
        cuts = tv.track.splitEvents(trk);
        edges = [trk.frames(1) - 1, cuts(:)', trk.frames(end) + 1];
        for e = 1:numel(edges) - 1
            in = trk.frames > edges(e) & trk.frames < edges(e + 1);
            if nnz(in) < 3, continue; end
            obs = [repmat(k, nnz(in), 1), double(trk.frames(in)), trk.uv(in, :)];
            t = tv.recon.detTimes(k, obs(:, 2), obs(:, 4), rec, sync);
            P(end+1) = struct('cam', k, 'obs', obs, 't', t, 'tStart', min(t), 'tEnd', max(t)); %#ok<AGROW>
        end
    end
end
end
