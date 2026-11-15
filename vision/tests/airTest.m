% Air density and speed of sound (TV-AIR-03, TV-SYNC-02; TV-TST-02).

%% Dry air at 0 C and sea level is about 1.29 kg/m^3
assert(abs(tv.air.density(0, 0, 101325) - 1.2922) < 0.001)

%% Dry air at 32 C and sea level is about 1.16 kg/m^3 (the spec's 11% swing)
assert(abs(tv.air.density(32, 0, 101325) - 1.1572) < 0.001)

%% Humid air is lighter than dry air at the same temperature and pressure
assert(tv.air.density(25, 0.9, 101325) < tv.air.density(25, 0, 101325))

%% Saturated air at 30 C is about 1.5% lighter than dry air
dry = tv.air.density(30, 0, 101325);  wet = tv.air.density(30, 1, 101325);
assert(abs((dry - wet) / dry - 0.0155) < 0.002)

%% Speed of sound at 20 C is 343.2 m/s
assert(abs(tv.air.speedOfSound(20) - 343.2) < 0.1)
