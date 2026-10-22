function study = runTask2CriticalDamping(opts)

if nargin < 1 || isempty(opts)
    opts = struct();
end
if ~isstruct(opts) || ~isscalar(opts)
    error('runTask2CriticalDamping:InvalidOptions', 'opts must be a scalar struct.');
end
opts = applyDefaults(opts);
validateOptions(opts);

kValues = opts.kMin:opts.kStep:opts.kMax;
if isempty(kValues) || kValues(end) < opts.kMax
    kValues(end + 1) = opts.kMax;
end
crosses = false(size(kValues));
crossingTimes = NaN(size(kValues));
for i = 1:numel(kValues)
    [crosses(i), crossingTimes(i)] = hasEquilibriumCrossing(opts, kValues(i));
end

lastCrossing = find(crosses, 1, 'last');
if isempty(lastCrossing)
    firstNoCrossing = [];
else
    firstNoCrossing = find(~crosses & (1:numel(crosses)) > lastCrossing, 1, 'first');
end
if isempty(lastCrossing) || isempty(firstNoCrossing)
    error('runTask2CriticalDamping:NoBracket', ...
        ['The scan did not bracket the transition. Increase kMax or tEnd, ' ...
         'or adjust kMin/kMax/kStep.']);
end
kLow = kValues(lastCrossing);
kHigh = kValues(firstNoCrossing);

while (kHigh - kLow) > opts.kTolerance
    kMid = (kLow + kHigh) / 2;
    didCross = hasEquilibriumCrossing(opts, kMid);
    if didCross
        kLow = kMid;
    else
        kHigh = kMid;
    end
end

kTheoretical = 2 * sqrt(opts.m * opts.c);
kExperimental = (kLow + kHigh) / 2;

kExamples = [kLow, kExperimental, kHigh];
responses = cell(1, numel(kExamples));
for i = 1:numel(kExamples)
    responses{i} = simulateAt(opts, kExamples(i));
end
figure('Name', 'Zadanie 2 - odpowiedź dla tłumienia krytycznego');
subplot(2, 1, 1);
hold on;
styles = {'-', '--', ':'};
for i = 1:numel(responses)
    plot(responses{i}.t, responses{i}.x, styles{i}, 'LineWidth', 1.25);
end
yline(0, ':k', 'Położenie równowagi');
grid on; xlabel('Czas t'); ylabel('Położenie x(t)');
legend(sprintf('k = %.5g (przecięcie)', kLow), ...
    sprintf('k = %.5g (granica z symulacji)', kExperimental), ...
    sprintf('k = %.5g (bez przecięcia w T)', kHigh), ...
    'Location', 'best');
title(sprintf('Czas symulacji T = %.4g', opts.tEnd));
hold off;

subplot(2, 1, 2);
stairs(kValues, double(crosses), 'o-', 'LineWidth', 1.2);
hold on;
xline(kExperimental, '--r', 'Granica z symulacji');
xline(kTheoretical, ':k', 'Wartość teoretyczna');
ylim([-0.1, 1.1]); yticks([0 1]); yticklabels({'brak przecięcia', 'przecięcie'});
grid on; xlabel('Współczynnik tłumienia k'); ylabel('Czy x(t) przecięło zero?');
hold off;

fprintf('Granica z symulacji: k = %.6g (przedział [%.6g, %.6g], T=%.6g s)\n', ...
    kExperimental, kLow, kHigh, opts.tEnd);
fprintf('Wartość teoretyczna: k_kr = %.6g\n', kTheoretical);
fprintf('Różnica: %.6g\n', abs(kExperimental - kTheoretical));

study = struct('options', opts, 'kValues', kValues, 'crosses', crosses, ...
    'crossingTimes', crossingTimes, 'kLow', kLow, 'kHigh', kHigh, ...
    'kExperimental', kExperimental, 'kTheoretical', kTheoretical, ...
    'absoluteDifference', abs(kExperimental - kTheoretical), ...
    'exampleK', kExamples, 'exampleResponses', {responses}, ...
    'lastCrossingScanIndex', lastCrossing, 'firstNoCrossingScanIndex', firstNoCrossing);
end

function opts = applyDefaults(opts)
defaults = struct('m', 1, 'c', 1, 'x0', 1, 'v0', 0, ...
    'dt', 0.02, 'tEnd', 150, 'kMin', 0, 'kMax', 4, ...
    'kStep', 0.2, 'kTolerance', 0.005);
names = fieldnames(defaults);
for i = 1:numel(names)
    if ~isfield(opts, names{i}) || isempty(opts.(names{i}))
        opts.(names{i}) = defaults.(names{i});
    end
end
end

function validateOptions(opts)
names = {'m','c','x0','v0','dt','tEnd','kMin','kMax','kStep','kTolerance'};
for i = 1:numel(names)
    value = opts.(names{i});
    if ~isnumeric(value) || ~isscalar(value) || ~isfinite(value)
        error('runTask2CriticalDamping:InvalidOption', ...
            'Option "%s" must be a finite numeric scalar.', names{i});
    end
end
if opts.m <= 0 || opts.c <= 0 || opts.dt <= 0 || opts.tEnd <= 0 || ...
        opts.kMin < 0 || opts.kMax <= opts.kMin || opts.kStep <= 0 || opts.kTolerance <= 0
    error('runTask2CriticalDamping:InvalidOption', ...
        'Require m,c,dt,tEnd,kStep,kTolerance > 0, kMin >= 0, and kMax > kMin.');
end
end

function [crosses, crossingTime] = hasEquilibriumCrossing(opts, k)
r = simulateAt(opts, k);
crossingIndex = find(r.x(1:end-1) > 0 & r.x(2:end) <= 0, 1, 'first');
crosses = ~isempty(crossingIndex);
crossingTime = NaN;
if crosses
    t1 = r.t(crossingIndex); t2 = r.t(crossingIndex + 1);
    x1 = r.x(crossingIndex); x2 = r.x(crossingIndex + 1);
    crossingTime = t1 - x1 * (t2 - t1) / (x2 - x1);
end
end

function r = simulateAt(opts, k)
cfg = struct('m', opts.m, 'c', opts.c, 'k', k, ...
    'x0', opts.x0, 'v0', opts.v0, 'dt', opts.dt, 'tEnd', opts.tEnd, ...
    'w', struct('type', 'constant', 'A', 0), ...
    'h', struct('type', 'constant', 'A', 0));
model = SpringMassSimulation(cfg);
r = model.runToEnd();
end
