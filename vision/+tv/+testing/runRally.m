function segs = runRally(cams, flights, fps, blind, air, prior, opts)
%RUNRALLY  Flights found in a synthetic rally's tracks (tests): rallyTracks, pieces, segments.
[tracks, rec, sync] = tv.testing.rallyTracks(cams, flights, fps, blind);
segs = tv.recon.segments(tv.recon.pieces(tracks, rec, sync), cams, rec, sync, air, prior, opts);
end
