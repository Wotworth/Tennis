function h = hashText(txt)
%HASHTEXT  A short fingerprint of a text (for manifest keys).
if exist('OCTAVE_VERSION', 'builtin')
    h = hash('sha256', txt);
else
    md = java.security.MessageDigest.getInstance('SHA-256');
    b = typecast(md.digest(uint8(txt)), 'uint8');
    h = lower(reshape(dec2hex(b, 2)', 1, []));
end
end
