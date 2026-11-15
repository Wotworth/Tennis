function prm = defaultParams()
%DEFAULTPARAMS  Air and ball parameters for tv.physics.simulate.
%   CD 0.507 is the mean drag coefficient Cross & Lindsey measured in flight
%   (TV-PHY-04). CL = 0 means no spin. spinAxis is the unit vector omega-hat
%   (right-hand rule). For a ball flying along +x, omega-hat = +y is topspin:
%   the top of the ball moves forward and the Magnus push (omega-hat x u-hat)
%   points down. omega-hat = -y is slice (push up).
c = tv.court.constants();
prm.g        = c.g;
prm.mass     = c.ballMass;
prm.area     = c.ballArea;
prm.rho      = tv.air.density(15, 0.5, 101325);   % mild day at sea level
prm.CD       = 0.507;
prm.CL       = 0;
prm.spinAxis = [0 1 0];
prm.wind     = [0 0 0];                           % m/s, the air's own velocity w
end
