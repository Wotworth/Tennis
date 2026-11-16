function f = fakeShell(keys, outs)
%FAKESHELL  A stand-in for tv.util.shell (tests): the first key found in the command picks the output.
%   f = fakeShell({'nvidia-smi', 'powershell'}, {'64, 150, 200', '78.2'}); [status, text] = f(cmd).
%   A command matching no key returns status 1.
f = @(cmd) pick(cmd, keys, outs);
end

function [st, out] = pick(cmd, keys, outs)
st = 1;  out = '';
for i = 1:numel(keys)
    if ~isempty(strfind(cmd, keys{i})), st = 0; out = outs{i}; return; end %#ok<STREMP>
end
end
