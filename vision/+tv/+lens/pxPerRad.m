function k = pxPerRad(lens)
%PXPERRAD  Pixels per radian at the image centre.
switch lens.type
    case 'rectilinear', k = lens.F  * lens.widthPx / 2;
    case 'radial',      k = lens.c1 * lens.widthPx / 2;
end
end
