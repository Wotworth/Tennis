function [free, total] = freeSpace(folder)
%FREESPACE  Free and total bytes on the drive holding folder (Java, works on Windows and Linux).
f = javaObject('java.io.File', folder);
free = double(f.getUsableSpace());
total = double(f.getTotalSpace());
end
