function lens = atResolution(lens, widthPx, heightPx)
%ATRESOLUTION  The same lens at another frame size (same angles, scaled pixels).
%   The lens models measure image radius in half-widths, so only the pixel
%   counts change. Synthetic tests use small frames to stay fast.
lens.widthPx = widthPx;  lens.heightPx = heightPx;
end
