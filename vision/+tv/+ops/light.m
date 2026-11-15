function light(cfg, state)
%LIGHT  The USB status light beside the card readers (TV-OPS-01).
%   copying: blue pulsing; safe: green; processing: slow white; error: red.
%   Uses blink1-tool when cfg.light.tool points at it; otherwise does nothing.
if ~isfield(cfg, 'light') || ~isfield(cfg.light, 'tool') || isempty(cfg.light.tool), return; end
args = struct('copying', '--blue --blink 1000', 'safe', '--green', 'processing', '--white --glimmer 1000', ...
              'error', '--red', 'off', '--off');
if ~isfield(args, state), return; end
system(sprintf('"%s" %s', cfg.light.tool, args.(state)));
end
