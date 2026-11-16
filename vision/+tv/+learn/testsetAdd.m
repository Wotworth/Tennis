function n = testsetAdd(st, answers)
%TESTSETADD  Add Chris's "Ball check" answers to the hand-labelled test set.
%   answers: struct array from GET /checks/answered, plus the crop's
%   origin in the full frame (originX, originY) and cam/frame, which the
%   PC kept when it made the crop (tv.learn.makeChecks). 'ok' keeps the
%   detector's position, 'moved' takes the tapped one, 'none' records that
%   there is no ball (a frame that tests false alarms). Returns the count.
f = fullfile(st.testset, 'testset.mat');
T = loadOr(f);
for a = answers(:)'
    key = sprintf('%s|%s', a.sessionId, a.frameRef);
    if any(strcmp({T.key}, key)), continue; end
    switch a.answer
        case 'ok',    xy = [a.originX + a.predX, a.originY + a.predY];  has = true;
        case 'moved', xy = [a.originX + a.ansX, a.originY + a.ansY];   has = true;
        otherwise,    xy = [NaN NaN];  has = false;
    end
    T(end+1) = struct('key', key, 'sessionId', a.sessionId, 'cam', a.cam, 'frame', a.frame, ... %#ok<AGROW>
        'xy', xy, 'hasBall', has, 'answeredUtc', a.answeredUtc);
end
save(f, 'T');
n = numel(T);
end

function T = loadOr(f)
if exist(f, 'file'), S = load(f); T = S.T;
else, T = struct('key', {}, 'sessionId', {}, 'cam', {}, 'frame', {}, 'xy', {}, 'hasBall', {}, 'answeredUtc', {}); end
end
