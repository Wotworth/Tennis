function h = hex(b)
%HEX  Lower-case hexadecimal text of a Java byte array (or int8/uint8 vector).
b = typecast(int8(b(:)'), 'uint8');
h = lower(reshape(dec2hex(b, 2)', 1, []));
end
