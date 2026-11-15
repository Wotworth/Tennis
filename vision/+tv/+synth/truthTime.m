function T = truthTime(cam, clock)
%TRUTHTIME  Truth time for a camera clock reading: T = c + Delta + epsilon*c (TV-SYNC).
T = clock + cam.clockOffset + cam.clockDrift .* clock;
end
