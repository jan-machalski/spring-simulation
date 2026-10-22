function [state, equilibrium] = initialSpringMassState(cfg)
wSignal = []; hSignal = [];
if isfield(cfg, 'w'), wSignal = cfg.w; end
if isfield(cfg, 'h'), hSignal = cfg.h; end
equilibrium = signalValue(wSignal, 0) + signalValue(hSignal, 0) / cfg.c;
x = cfg.x0;
if isfield(cfg, 'initialOffset')
    offset = cfg.initialOffset;
    if ~isnumeric(offset) || ~isscalar(offset) || ~isreal(offset) || ~isfinite(offset)
        error('SpringMassSimulation:InvalidOffset', 'Odchylenie początkowe musi być skończoną liczbą.');
    end
    x = equilibrium + offset;
end
state = [x; cfg.v0];
end
