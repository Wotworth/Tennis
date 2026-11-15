function h = netHeight(y)
%NETHEIGHT  Height of the net tape (m) at the across-court position y (m).
%   The net sags in a straight line from 1.07 m at the posts to 0.914 m at the
%   centre (TV-EVT-03). Beyond the posts there is no net: NaN.
c = tv.court.constants();
a = abs(y);
h = c.netHeightCentre + (c.netHeightPost - c.netHeightCentre) .* a ./ c.postY;
h(a > c.postY) = NaN;
end
