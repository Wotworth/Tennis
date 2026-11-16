function [kind, target, speed, CL, spinDir] = planShot(hitter, isServe, second, ends, side, c)
%PLANSHOT  A plausible club-level shot: target, speed (m/s) and spin (synthetic sessions).
%   hitter 1 is Chris; ends(h) is the sign of x at player h's end; side
%   +1/-1 is the deuce/ad court. Shared by tv.synth.dataSession and
%   tv.synth.studySession.
dir = -ends(hitter);                            % toward the other end
chris = hitter == 1;
if isServe
    kind = 'serve';
    target = [dir * (4.6 + 1.4 * rand()), side * ends(hitter) * (0.4 + 3.4 * rand())];   % the diagonal box
    if second
        speed = (chris * 36 + ~chris * 33) + 2.5 * randn();  CL = 0.12 + 0.03 * randn();
    else
        speed = (chris * 45 + ~chris * 42) + 2.2 * randn();  CL = 0.04 + 0.02 * rand();
        if rand() < 0.35, target(1) = dir * (c.serviceLine + 0.1 + 0.6 * rand()); end   % fault: long
    end
    spinDir = 1;
    return
end
fh = rand() < 0.58;
kind = ifelse(fh, 'forehand', 'backhand');
deep = c.halfLength - 2.4 - 1.6 * abs(randn());
if rand() < 0.05, deep = c.halfLength + 0.15 + 0.9 * rand(); end          % long
target = [dir * deep, (2 * rand() - 1) * 3.6];
if rand() < 0.02, target(2) = sign(target(2)) * (c.halfSingles + 0.1 + 0.5 * rand()); end   % wide
speed = (fh * 29.5 + ~fh * 26) * (chris * 1.0 + ~chris * 0.94) + 2.6 * randn();
CL = fh * (0.085 + 0.03 * randn()) + ~fh * (0.065 + 0.025 * randn());
spinDir = 1;
if ~fh && rand() < 0.22, spinDir = -1; CL = 0.07 + 0.02 * randn(); speed = speed * 0.8; end   % slice
CL = max(0.01, CL);
end

function v = ifelse(c, a, b)
if c, v = a; else, v = b; end
end
