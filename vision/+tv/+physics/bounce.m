function vOut = bounce(vIn, prm)
%BOUNCE  Ball velocity just after a bounce, from the velocity just before.
%   A simple court model: the vertical speed reverses and keeps the fraction
%   prm.restitution; the horizontal velocity keeps prm.horizontalKeep.
%   The pipeline never uses this to measure anything (it fits each flight
%   segment on its own, TV-PHY-02); it only drives the synthetic footage.
%   RETUNE(real footage): restitution and horizontal keep depend on the court
%   surface and the spin; the defaults suit a medium hard court.
if ~isfield(prm, 'restitution'),    prm.restitution = 0.75; end
if ~isfield(prm, 'horizontalKeep'), prm.horizontalKeep = 0.65; end
vOut = [prm.horizontalKeep * vIn(1:2), -prm.restitution * vIn(3)];
end
