function v = codeVersion()
%CODEVERSION  The Git commit of the vision code, or 'unknown' outside a Git checkout.
persistent cached
if isempty(cached)
    here = fileparts(fileparts(fileparts(mfilename('fullpath'))));
    [st, out] = system(sprintf('git -C "%s" rev-parse HEAD', here));
    if st == 0, cached = strtrim(out); else, cached = 'unknown'; end
    % uncommitted changes count as different code
    [st2, d] = system(sprintf('git -C "%s" status --porcelain -- .', here));
    if st2 == 0 && ~isempty(strtrim(d)), cached = [cached '+dirty']; end
end
v = cached;
end
