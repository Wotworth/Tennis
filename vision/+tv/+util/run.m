function out = run(cmd)
%RUN  Run a shell command; error with its output if it fails.
[status, out] = system(cmd);
if status ~= 0
    error('tv:run', 'Command failed (%d): %s\n%s', status, cmd, out);
end
end
