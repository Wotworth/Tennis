function rho = density(tempC, relHumidity, pressurePa)
%DENSITY  Moist-air density in kg/m^3 (TV-AIR-03).
%   rho = (p - pv)/(Rd*T) + pv/(Rv*T), with the water-vapour partial pressure
%   pv = phi * 610.94 * exp(17.625*Tc/(Tc + 243.04)) Pa  (Magnus form).
%   tempC: air temperature in deg C. relHumidity: 0-1 (not percent).
%   pressurePa: SURFACE pressure in Pa (not sea-level pressure; TV-AIR-01).
%   Humid air is slightly lighter than dry air, because water vapour
%   (18 g/mol) is lighter than the nitrogen and oxygen it replaces (29 g/mol).
Rd = 287.05;   % J/(kg K), dry air
Rv = 461.5;    % J/(kg K), water vapour
T  = tempC + 273.15;
pv = relHumidity .* 610.94 .* exp(17.625 .* tempC ./ (tempC + 243.04));
rho = (pressurePa - pv) ./ (Rd .* T) + pv ./ (Rv .* T);
end
