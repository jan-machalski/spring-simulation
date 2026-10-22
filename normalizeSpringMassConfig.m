function cfg = normalizeSpringMassConfig(cfg)
if ~isstruct(cfg) || ~isscalar(cfg)
    error('normalizeSpringMassConfig:InvalidConfig', 'Input must be a scalar configuration struct.');
end
required = {'m', 'c', 'k', 'x0', 'v0', 'dt', 'tEnd'};
for i = 1:numel(required)
    name = required{i};
    if ~isfield(cfg, name) || ~isnumeric(cfg.(name)) || ~isscalar(cfg.(name)) ...
            || ~isreal(cfg.(name)) || ~isfinite(cfg.(name))
        error('normalizeSpringMassConfig:MissingField', 'Configuration field "%s" must be a finite real scalar.', name);
    end
end
if cfg.m <= 0 || cfg.c <= 0 || cfg.k < 0
    error('normalizeSpringMassConfig:InvalidParameters', 'Require m > 0, c > 0, and k >= 0.');
end
if cfg.dt <= 0 || cfg.tEnd < 0
    error('normalizeSpringMassConfig:InvalidTime', 'Require dt > 0 and tEnd >= 0.');
end
for name = {'w', 'h'}
    field = name{1};
    if ~isfield(cfg, field) || isempty(cfg.(field))
        cfg.(field) = struct('type', 'constant', 'A', 0);
    end
    signalValue(cfg.(field), 0);
    if ~isfield(cfg.(field), 'type'), cfg.(field).type = 'constant'; end
end
if ~isfield(cfg, 'method') || isempty(cfg.method), cfg.method = 'rk4'; end
cfg.method = lower(char(cfg.method));
if ~any(strcmp(cfg.method, {'rk4', 'euler'}))
    error('normalizeSpringMassConfig:UnknownMethod', 'Use method="rk4" or method="euler".');
end
[initialState, ~] = initialSpringMassState(cfg);
cfg.x0 = initialState(1);
if isfield(cfg, 'restLength') && (~isnumeric(cfg.restLength) || ~isscalar(cfg.restLength) ...
        || ~isreal(cfg.restLength) || ~isfinite(cfg.restLength) || cfg.restLength <= 0)
    error('SpringMassSimulation:InvalidLength', 'Długość spoczynkowa musi być dodatnia.');
end
end

