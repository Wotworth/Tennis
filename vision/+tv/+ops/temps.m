function T = temps(runFn)
%TEMPS  CPU and GPU temperatures now, in degrees C (Chris, 16 Nov). NaN where unreadable.
%   GPU: nvidia-smi (also its power draw and limit, W). CPU: LibreHardwareMonitor's WMI
%   sensors (installed and started at log-on by the setup script; Windows itself has no
%   reliable CPU temperature), else the ACPI thermal zone. runFn(cmd) -> [status, text]
%   runs a shell command (tv.util.shell by default; replaced in tests).
if nargin < 1, runFn = @tv.util.shell; end
T = struct('cpu', NaN, 'gpu', NaN, 'gpuW', NaN, 'gpuLimitW', NaN);
[st, out] = runFn('nvidia-smi --query-gpu=temperature.gpu,power.draw,power.limit --format=csv,noheader,nounits');
if st == 0, [T.gpu, T.gpuW, T.gpuLimitW] = tv.ops.parseGpuQuery(out); end
if ispc() || ~strcmp(func2str(runFn), func2str(@tv.util.shell))   % Windows, or a test's stand-in
    ps = ['powershell -NoProfile -Command "$s = Get-CimInstance -Namespace root/LibreHardwareMonitor -ClassName Sensor ', ...
          '-ErrorAction SilentlyContinue | Where-Object { $_.SensorType -eq ''Temperature'' -and $_.Name -match ''CPU Package|Core Max'' } | ', ...
          'Sort-Object Value -Descending | Select-Object -First 1 -ExpandProperty Value; if ($s) { $s } else { ', ...
          '(Get-CimInstance -Namespace root/wmi -ClassName MSAcpi_ThermalZoneTemperature -ErrorAction SilentlyContinue | ', ...
          'Select-Object -First 1 -ExpandProperty CurrentTemperature) / 10 - 273.15 }"'];
    [st, out] = runFn(ps);
    if st == 0, T.cpu = tv.ops.parseNumber(out); end
end
end
