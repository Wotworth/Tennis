function waitedS = thermalGuard(cfg, readFn, pauseFn)
%THERMALGUARD  Pause processing while the PC is too hot (Chris, 16 Nov).
%   Between stages and between rallies of the heavy stages: if the CPU or GPU is at or
%   above its limit (cfg.tempLimitC.cpu, .gpu; defaults 90 and 80 C), wait in steps of
%   cfg.tempPauseS (30 s) until both are cfg.tempHysteresisC (5 C) below, for at most
%   cfg.tempMaxWaitS (1800 s); then carry on and alert. Each pause is logged. Returns
%   the seconds waited. readFn/pauseFn: tv.ops.temps / pause (replaced in tests).
if nargin < 2 || isempty(readFn), readFn = @tv.ops.temps; end
if nargin < 3 || isempty(pauseFn), pauseFn = @pause; end
d = struct('tempLimitC', struct('cpu', 90, 'gpu', 80), 'tempPauseS', 30, 'tempHysteresisC', 5, 'tempMaxWaitS', 1800);
fn = fieldnames(d);
for k = 1:numel(fn), if ~isfield(cfg, fn{k}), cfg.(fn{k}) = d.(fn{k}); end, end
lim = cfg.tempLimitC;  waitedS = 0;
T = readFn();
if ~(T.cpu >= lim.cpu || T.gpu >= lim.gpu), return; end
logLine(cfg, sprintf('too hot (CPU %.0f C, GPU %.0f C): pausing', T.cpu, T.gpu));
while waitedS < cfg.tempMaxWaitS
    pauseFn(cfg.tempPauseS);  waitedS = waitedS + cfg.tempPauseS;
    T = readFn();
    if ~(T.cpu >= lim.cpu - cfg.tempHysteresisC) && ~(T.gpu >= lim.gpu - cfg.tempHysteresisC), break; end
end
logLine(cfg, sprintf('resumed after %d s (CPU %.0f C, GPU %.0f C)', waitedS, T.cpu, T.gpu));
if waitedS >= cfg.tempMaxWaitS && isfield(cfg, 'notify')
    cfg.notify('Running hot', sprintf('Still CPU %.0f C, GPU %.0f C after %d min of pauses; carrying on. Is the closet door open?', T.cpu, T.gpu, round(waitedS / 60)));
end
end

function logLine(cfg, text)
if isfield(cfg, 'logs') && ~isempty(cfg.logs), tv.pipeline.log(cfg.logs, 'thermal', text); end
end
