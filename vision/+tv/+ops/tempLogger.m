function t = tempLogger(cfg, readFn)
%TEMPLOGGER  Log temperatures every minute while processing (Chris, 16 Nov).
%   t = tempLogger(cfg) starts a MATLAB timer writing tv.ops.tempLog every cfg.tempLogS
%   seconds (60) to cfg.logs; stop(t); delete(t) when processing ends.
if nargin < 2, readFn = []; end
if ~isfield(cfg, 'tempLogS'), cfg.tempLogS = 60; end
t = timer('ExecutionMode', 'fixedSpacing', 'Period', cfg.tempLogS, 'BusyMode', 'drop', ...
    'TimerFcn', @(~, ~) tv.ops.tempLog(cfg.logs, readFn, 'processing'), 'ErrorFcn', @(~, ~) []);
start(t);
end
