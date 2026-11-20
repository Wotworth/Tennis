function ok = fairCall(call, truthCall, pBounce, pHit, isServe)
%FAIRCALL  Is a call right against the truth (synthetic tests; Chris, 21 Nov)?
%   The same call is right. "too close" is right only when the true bounce really is close: within
%   10 cm of the line that decides it (the stated band is about 3.7 cm; 10 cm allows for its error).
%   Anything else is wrong.
ok = strcmp(call, truthCall);
if ok || ~strcmp(call, 'too close') || any(~isfinite(pBounce(1:2))), return; end
[~, margin] = tv.metrics.lineCall(pBounce(1:2), 0, isServe, sign(pHit(2)) + (pHit(2) == 0) * -1, -sign(pHit(1)), struct('lines', 'singles'));
ok = abs(margin) < 0.10;
end
