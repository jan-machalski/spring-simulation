function study = runTask4SquareDisplacement(opts)

if nargin < 1 || isempty(opts)
    opts = struct();
end
if ~isstruct(opts) || ~isscalar(opts)
    error('runTask4SquareDisplacement:InvalidOptions', 'opts must be a scalar struct.');
end
opts = applyDefaults(opts);
validateOptions(opts);

results = cell(size(opts.kValues));
intervals = cell(size(opts.kValues));
firstRootIndex = ceil(opts.phase / pi);
lastRootIndex = floor((opts.omega*opts.tEnd + opts.phase) / pi);
rootIndices = firstRootIndex:lastRootIndex;
roots = (rootIndices*pi - opts.phase) ./ opts.omega;
roots = roots(roots > 0 & roots < opts.tEnd);
switchTimes = unique([0, roots, opts.tEnd]);
if numel(switchTimes) < 2
    error('runTask4SquareDisplacement:ShortDuration', ...
        'tEnd must include a nonzero portion of at least one half-period.');
end

for q = 1:numel(opts.kValues)
    k = opts.kValues(q);
    cfg = struct('m', opts.m, 'c', opts.c, 'k', k, ...
        'x0', opts.x0, 'v0', opts.v0, 'dt', opts.dt, 'tEnd', opts.tEnd, ...
        'w', struct('type', 'square', 'A', opts.A, ...
            'omega', opts.omega, 'phase', opts.phase), ...
        'h', struct('type', 'constant', 'A', 0));
    model = SpringMassSimulation(cfg);
    r = model.runToEnd();
    intervalResults = measureIntervals(r, opts, switchTimes);
    results{q} = r;
    intervals{q} = intervalResults;
end

[~, plotIndex] = min(abs(opts.kValues - opts.plotK));
rPlot = results{plotIndex};
figure('Name', 'Zadanie 4 - wymuszenie prostokątne');
plot(rPlot.t, rPlot.x, 'LineWidth', 1.2);
hold on;
plot(rPlot.t, rPlot.w, '--', 'LineWidth', 1.1);
plot(rPlot.t, rPlot.w - rPlot.x, ':', 'LineWidth', 1.1);
yline(opts.tolerance, ':k');
yline(-opts.tolerance, ':k');
grid on; xlabel('Czas t'); ylabel('Położenie / błąd');
legend('x(t)', 'w(t)', 'w(t)-x(t)', 'Location', 'best');
title(sprintf('Wymuszenie prostokątne, k = %.5g, \omega = %.5g', ...
    opts.kValues(plotIndex), opts.omega));
hold off;

figure('Name', 'Zadanie 4 - czas ustalania po przełączeniu');
hold on;
colors = lines(numel(opts.kValues));
for q = 1:numel(opts.kValues)
    rIntervals = intervals{q};
    delays = [rIntervals.settlingDelay];
    delays(~[rIntervals.settlesBeforeNextSwitch]) = NaN;
    plot([rIntervals.switchTime], delays, 'o-', ...
        'Color', colors(q, :), 'LineWidth', 1.1, ...
        'DisplayName', sprintf('k = %.4g', opts.kValues(q)));
end
grid on; xlabel('Czas przełączenia'); ylabel('Czas wejścia do pasma');
title(sprintf('Pasmo |w-x| < %.3g; NaN oznacza brak wejścia przed kolejnym skokiem', ...
    opts.tolerance));
legend('Location', 'best');
hold off;

fprintf('Dla wymuszenia okresowego nie istnieje skończone globalne T.\n');
fprintf('Mierzony jest czas wejścia do |w-x| < %.4g w każdym półokresie.\n', opts.tolerance);
for q = 1:numel(opts.kValues)
    rr = intervals{q};
    countSettled = sum([rr.settlesBeforeNextSwitch]);
    fprintf('k = %.5g: wejście do pasma przed następnym skokiem w %d/%d półokresach.\n', ...
        opts.kValues(q), countSettled, numel(rr));
end

study = struct('options', opts, 'switchTimes', switchTimes, ...
    'kValues', opts.kValues, 'responses', {results}, ...
    'intervalResults', {intervals}, 'plotK', opts.kValues(plotIndex), ...
    'globalSettlingTime', Inf, 'tolerance', opts.tolerance);
end

function opts = applyDefaults(opts)
defaults = struct('m', 1, 'c', 1, 'x0', 1, 'v0', 0, 'A', 1, ...
    'omega', 1, 'phase', 0, 'dt', 0.005, 'tEnd', 20, ...
    'kValues', [0.1 0.5 1 2 4], 'tolerance', 0.1, 'plotK', 1);
names = fieldnames(defaults);
for i = 1:numel(names)
    if ~isfield(opts, names{i}) || isempty(opts.(names{i}))
        opts.(names{i}) = defaults.(names{i});
    end
end
end

function validateOptions(opts)
scalarNames = {'m','c','x0','v0','A','omega','phase','dt','tEnd','tolerance','plotK'};
for i = 1:numel(scalarNames)
    value = opts.(scalarNames{i});
    if ~isnumeric(value) || ~isscalar(value) || ~isfinite(value)
        error('runTask4SquareDisplacement:InvalidOption', ...
            'Option "%s" must be a finite numeric scalar.', scalarNames{i});
    end
end
if ~isnumeric(opts.kValues) || isempty(opts.kValues) || ...
        any(~isfinite(opts.kValues(:))) || any(opts.kValues(:) < 0)
    error('runTask4SquareDisplacement:InvalidKValues', ...
        'kValues must be a nonempty vector of finite, nonnegative values.');
end
if opts.m <= 0 || opts.c <= 0 || opts.omega <= 0 || ...
        opts.dt <= 0 || opts.tEnd <= 0 || opts.tolerance <= 0
    error('runTask4SquareDisplacement:InvalidOption', ...
        'Require m,c,omega,dt,tEnd,tolerance > 0.');
end
end

function output = measureIntervals(r, opts, switchTimes)
template = struct('switchTime', 0, 'nextSwitchTime', 0, ...
    'targetW', 0, 'settlingDelay', NaN, 'settlesBeforeNextSwitch', false);
output = repmat(template, 1, numel(switchTimes)-1);
for j = 1:numel(switchTimes)-1
    t0 = switchTimes(j);
    t1 = switchTimes(j+1);
    midpoint = (t0 + t1) / 2;
    targetW = opts.A * sign(sin(opts.omega*midpoint + opts.phase));
    indices = find(r.t >= t0 & r.t < t1);
    if isempty(indices)
        output(j) = struct('switchTime', t0, 'nextSwitchTime', t1, ...
            'targetW', targetW, 'settlingDelay', NaN, ...
            'settlesBeforeNextSwitch', false);
        continue;
    end
    errorSignal = targetW - r.x(indices);
    inside = abs(errorSignal) < opts.tolerance;
    lastOutside = find(~inside, 1, 'last');
    if isempty(lastOutside)
        delay = 0;
        settled = true;
    elseif lastOutside < numel(indices)
        delay = r.t(indices(lastOutside + 1)) - t0;
        settled = true;
    else
        delay = NaN;
        settled = false;
    end
    output(j) = struct('switchTime', t0, 'nextSwitchTime', t1, ...
        'targetW', targetW, 'settlingDelay', delay, ...
        'settlesBeforeNextSwitch', settled);
end
end
