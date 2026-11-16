function r = frameRef(cam, frame)
%FRAMEREF  The key for one camera frame, as used in ball checks and labels.
r = sprintf('cam%d-f%d', cam, frame);
end
