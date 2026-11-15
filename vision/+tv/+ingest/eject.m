function eject(cardRoot)
%EJECT  Flush and dismount a card on Windows, so it is safe to pull (TV-ING-06). Elsewhere: nothing.
if ~ispc, return; end
drive = cardRoot(1:2);
cmd = sprintf(['powershell -NoProfile -Command "(New-Object -ComObject Shell.Application)' ...
    '.Namespace(17).ParseName(''%s'').InvokeVerb(''Eject'')"'], drive);
system(cmd);
end
