function c = speedOfSound(tempC)
%SPEEDOFSOUND  Speed of sound in air, m/s (TV-SYNC-02): 331.3*sqrt(1 + T/273.15).
c = 331.3 .* sqrt(1 + tempC ./ 273.15);
end
