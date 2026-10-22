function study = runTask3StepResponse(opts)

if nargin < 1 || isempty(opts)
    opts = struct();
end
if ~isstruct(opts) || ~isscalar(opts)
    error('runTask3StepResponse:InvalidOptions', 'opts must be a scalar struct.');
end
opts = applyDefaults(opts);
validateOptions(opts);

kCoarse = makeGrid(opts.kMin, opts.kMax, opts.kStep);
[coarseTimes, coarseResults] = evaluateGrid(opts, kCoarse);
if ~any(isfinite(coarseTimes))
    error('runTask3StepResponse:NoSettling', ...
        'No tested damping settled by tEnd. Increase tEnd or relax the tolerances.');
end
[~, bestCoarseIndex] = min(coarseTimes);
kCoarseBest = kCoarse(bestCoarseIndex);

fineStep = opts.kStep / opts.refinementDivisions;
kFine = makeGrid(max(opts.kMin, kCoarseBest - opts.kStep), ...
    min(opts.kMax, kCoarseBest + opts.kStep), fineStep);
kValues = unique([kCoarse, kFine]);
[settlingTimes, responses] = evaluateGrid(opts, kValues);
if ~any(isfinite(settlingTimes))
    error('runTask3StepResponse:NoSettling', ...
        'No tested damping settled by tEnd. Increase tEnd or relax the tolerances.');
end
[bestSettlingTime, bestIndex] = min(settlingTimes);
kBest = kValues(bestIndex);
kCritical = 2 * sqrt(opts.m * opts.c);

rBest = responses{bestIndex};
[~, rCriticalCell] = evaluateGrid(opts, kCritical);
rCritical = rCriticalCell{1};

figure('Name', 'Zadanie 3 - odpowiedź na skok');
subplot(2, 1, 1);
plot(rBest.t, rBest.x, 'LineWidth', 1.3);
hold on;
plot(rBest.t, rBest.w, '--', 'LineWidth', 1.2);
plot(rBest.t, rBest.w - rBest.x, ':', 'LineWidth', 1.2);
yline(opts.positionTolerance, ':k');
yline(-opts.positionTolerance, ':k');
grid on; xlabel('Czas t'); ylabel('Położenie / błąd');
legend('x(t), k optymalne', 'w(t)', 'w(t)-x(t)', 'Location', 'best');
title(sprintf('Odpowiedź dla k = %.5g; czas ustalania %.5g s', ...
    kBest, bestSettlingTime));
hold off;

subplot(2, 1, 2);
plot(rBest.t, rBest.x, 'LineWidth', 1.3);
hold on;
plot(rCritical.t, rCritical.x, '--', 'LineWidth', 1.2);
yline(opts.A, ':k', 'Położenie końcowe');
grid on; xlabel('Czas t'); ylabel('Położenie x(t)');
legend(sprintf('k optymalne = %.5g', kBest), ...
    sprintf('k krytyczne = %.5g', kCritical), 'Location', 'best');
title('Porównanie z tłumieniem krytycznym');
hold off;

figure('Name', 'Zadanie 3 - czas ustalania');
finitePlot = settlingTimes;
finitePlot(~isfinite(finitePlot)) = NaN;
plot(kValues, finitePlot, '.-', 'LineWidth', 1.1, 'MarkerSize', 10);
hold on;
xline(kBest, '--r', 'Minimum z przeszukania');
xline(kCritical, ':k', 'Tłumienie krytyczne');
grid on; xlabel('Współczynnik tłumienia k'); ylabel('Czas ustalania [s]');
title(sprintf('Pasmo: |x-A| <= %.3g, |v| <= %.3g', ...
    opts.positionTolerance, opts.velocityTolerance));
hold off;

criticalSettlingTime = settlingTimeOf(rCritical, opts);
fprintf('Minimum z przeszukania: k = %.7g, czas ustalania = %.7g s\n', ...
    kBest, bestSettlingTime);
fprintf('Tłumienie krytyczne: k_kr = %.7g\n', kCritical);
fprintf('Czas dla k_kr w tym samym kryterium: %.7g s\n', criticalSettlingTime);
fprintf('Kryterium: |x-A| <= %.4g oraz |v| <= %.4g do tEnd = %.4g s\n', ...
    opts.positionTolerance, opts.velocityTolerance, opts.tEnd);

study = struct('options', opts, 'kValues', kValues, ...
    'settlingTimes', settlingTimes, 'kBest', kBest, ...
    'bestSettlingTime', bestSettlingTime, 'kCritical', kCritical, ...
    'criticalSettlingTime', criticalSettlingTime, ...
    'responses', {responses}, 'bestResponse', rBest, ...
    'criticalResponse', rCritical, 'coarseKValues', kCoarse, ...
    'coarseSettlingTimes', coarseTimes, 'coarseResponses', {coarseResults});
end

function opts = applyDefaults(opts)
defaults = struct('m', 1, 'c', 1, 'x0', 0, 'v0', 0, 'A', 1, ...
    'dt', 0.01, 'tEnd', 30, 'kMin', 0, 'kMax', 4, 'kStep', 0.1, ...
    'refinementDivisions', 20, 'positionTolerance', 0.02, ...
    'velocityTolerance', 0.02);
names = fieldnames(defaults);
for i = 1:numel(names)
    if ~isfield(opts, names{i}) || isempty(opts.(names{i}))
        opts.(names{i}) = defaults.(names{i});
    end
end
end

function validateOptions(opts)
names = {'m','c','x0','v0','A','dt','tEnd','kMin','kMax','kStep', ...
    'refinementDivisions','positionTolerance','velocityTolerance'};
for i = 1:numel(names)
    value = opts.(names{i});
    if ~isnumeric(value) || ~isscalar(value) || ~isfinite(value)
        error('runTask3StepResponse:InvalidOption', ...
            'Option "%s" must be a finite numeric scalar.', names{i});
    end
end
if opts.m <= 0 || opts.c <= 0 || opts.dt <= 0 || opts.tEnd <= 0 || ...
        opts.kMin < 0 || opts.kMax <= opts.kMin || opts.kStep <= 0 || ...
        opts.refinementDivisions < 1 || opts.positionTolerance <= 0 || ...
        opts.velocityTolerance <= 0
    error('runTask3StepResponse:InvalidOption', ...
        'Require m,c,dt,tEnd,kStep,tolerances > 0, kMin >= 0, kMax > kMin, and refinementDivisions >= 1.');
end
end

function values = makeGrid(lo, hi, step)
values = lo:step:hi;
if isempty(values) || values(end) < hi
    values(end + 1) = hi;
end
end

function [times, results] = evaluateGrid(opts, kValues)
times = Inf(size(kValues));
results = cell(size(kValues));
for i = 1:numel(kValues)
    results{i} = simulateAt(opts, kValues(i));
    times(i) = settlingTimeOf(results{i}, opts);
end
end

function ts = settlingTimeOf(r, opts)
inside = abs(r.x - opts.A) <= opts.positionTolerance & ...
    abs(r.v) <= opts.velocityTolerance;
lastOutside = find(~inside, 1, 'last');
if isempty(lastOutside)
    ts = 0;
elseif lastOutside == numel(r.t)
    ts = Inf;
else
    ts = r.t(lastOutside + 1);
end
end

function r = simulateAt(opts, k)
cfg = struct('m', opts.m, 'c', opts.c, 'k', k, ...
    'x0', opts.x0, 'v0', opts.v0, 'dt', opts.dt, 'tEnd', opts.tEnd, ...
    'w', struct('type', 'step', 'A', opts.A, 't0', 0), ...
    'h', struct('type', 'constant', 'A', 0));
model = SpringMassSimulation(cfg);
r = model.runToEnd();
end
