function r = recordCall(log, key, item, r)
%RECORDCALL  Append item to log(key) (a containers.Map, so the caller sees it) and return r (tests).
L = log(key);  L{end+1} = item;  log(key) = L;
end
