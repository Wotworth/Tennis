function a = acceleration(v, prm)
%ACCELERATION  Ball acceleration (m/s^2, 1-by-3) at velocity v (1-by-3, m/s).
%   m dv/dt = m g  -  1/2 rho A CD |u| u  +  1/2 rho A CL |u|^2 (omega-hat x u-hat)
%   where u = v - w is the velocity relative to the air (spec Part 5).
%   Drag opposes the motion through the air; the Magnus push is sideways to it.
u     = v - prm.wind;
speed = norm(u);
k     = 0.5 * prm.rho * prm.area / prm.mass;     % 1/m
a     = [0 0 -prm.g] - k * prm.CD * speed * u;
if prm.CL ~= 0 && speed > 0
    push = cross(prm.spinAxis, u / speed);      % omega-hat x u-hat
    a = a + k * prm.CL * speed^2 * push;
end
end
