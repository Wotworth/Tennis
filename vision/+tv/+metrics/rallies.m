function [shots, R] = rallies(segsByRally, evByRally, rallyWindows, air, cams, players, playerInfo)
%RALLIES  Shots and rally summaries from each rally's flights and events (TV-MET-01).
%   A shot starts at a hit (the first one after a toss is a serve) and runs
%   to the next hit; its bounce and any net event in between decide the call.
%   Rally ending: the last shot's call ('out', 'net'), or 'winner' when it
%   landed in and nobody hit it back.
shots = [];  R = [];
cfg = struct('cams', cams, 'lines', 'singles');
for r = 1:numel(segsByRally)
    segs = segsByRally{r};  ev = evByRally{r};
    if isempty(segs), continue; end
    hits = find(strcmp({ev.type}, 'hit'));
    hasToss = any(strcmp({ev.type}, 'toss'));
    starts = arrayfun(@(e) ev(e).segAfter, hits);
    hitEvs = num2cell(ev(hits));
    if ~hasToss && ~isempty(segs)
        % the first flight starts a shot even if its hit was not seen
        if isempty(starts) || starts(1) ~= 1, starts = [1, starts]; hitEvs = [{[]}, hitEvs]; end
    end
    rs = [];
    for i = 1:numel(starts)
        s = starts(i);
        if s < 1 || s > numel(segs), continue; end
        nextStart = numel(segs) + 1;  if i < numel(starts), nextStart = starts(i + 1); end
        tNext = Inf;  if i < numel(hits), tNext = ev(hits(min(i + 1, end))).t; end
        inShot = [ev.t] > segs(s).t0 - 0.05 & [ev.t] < tNext;
        b = find(inShot & strcmp({ev.type}, 'bounce'), 1);
        nt = find(inShot & strcmp({ev.type}, 'net'), 1);
        bEv = [];  if ~isempty(b), bEv = ev(b); end
        nEv = [];  if ~isempty(nt) && (isempty(b) || ev(nt).t < ev(b).t), nEv = ev(nt); bEv = []; end
        after = [];  if ~isempty(bEv) && bEv.segAfter > 0 && bEv.segAfter < nextStart, after = segs(bEv.segAfter); end
        isServe = i == 1 && hasToss;
        serverSide = sign(segs(s).x(2));  if serverSide == 0, serverSide = -1; end
        m = tv.metrics.shot(segs(s), after, hitEvs{i}, bEv, nEv, air, cfg, players, playerInfo, isServe, serverSide);
        m.rally = r;  m.index = i;
        rs = [rs; m]; %#ok<AGROW>
    end
    if isempty(rs), continue; end
    last = rs(end);
    ending = last.call;
    if strcmp(ending, 'in'), ending = 'winner'; end
    R = [R; struct('index', r, 'start', rallyWindows(r, 1), 'stop', rallyWindows(r, 2), ...
        'shots', numel(rs), 'duration', max([ev.t]) - rs(1).t, 'ending', ending, ...
        'fastest', max([rs.speedContact]))]; %#ok<AGROW>
    shots = [shots; rs]; %#ok<AGROW>
end
end
