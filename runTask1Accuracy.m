function study = runTask1Accuracy(cfg, dtValues)

if nargin < 1 || isempty(cfg)
    cfg = struct('m', 1, 'c', 1, 'k', 0.4, ...
        'x0', 1, 'v0', 0, 'tEnd', 15);
end
if nargin < 2 || isempty(dtValues)
    dtValues = [0.1, 0.05, 0.02, 0.01];
end
required = {'m', 'c', 'k', 'x0', 'v0', 'tEnd'};
for i = 1:numel(required)
    if ~isfield(cfg, required{i})
        error('runTask1Accuracy:MissingField', 'Missing configuration field "%s".', required{i});
    end
end
if ~isnumeric(dtValues) || isempty(dtValues) || any(~isfinite(dtValues(:))) || any(dtValues(:) <= 0)
    error('runTask1Accuracy:InvalidSteps', 'dtValues must contain positive finite values.');
end
dtValues = sort(unique(dtValues(:)'));

base = cfg;
base.method = 'rk4';
base.w = struct('type', 'constant', 'A', 0);
base.h = struct('type', 'constant', 'A', 0);
resultsRK4 = cell(size(dtValues));
resultsEuler = cell(size(dtValues));
maxAbsErrorRK4 = zeros(size(dtValues));
maxAbsErrorEuler = zeros(size(dtValues));
for i = 1:numel(dtValues)
    current = base;
    current.dt = dtValues(i);
    resultsRK4{i} = simulateFreeResponse(current, 'rk4');
    resultsEuler{i} = simulateFreeResponse(current, 'euler');
    maxAbsErrorRK4(i) = max(abs(resultsRK4{i}.positionError));
    maxAbsErrorEuler(i) = max(abs(resultsEuler{i}.positionError));
end

finest = 1;
r = resultsRK4{finest};
e = resultsEuler{finest};
figure('Name', 'Zadanie 1 - symulacja i rozwiązanie dokładne');
subplot(3, 1, 1);
plot(r.t, r.x, '-', e.t, e.x, ':', r.t, r.xExact, '--', 'LineWidth', 1.3);
grid on; xlabel('Czas t'); ylabel('Położenie x(t)');
legend('RK4', 'Euler', 'Rozwiązanie dokładne', 'Location', 'best');
title(sprintf('Porównanie dla dt = %.5g', dtValues(finest)));
subplot(3, 1, 2);
plot(r.t, r.positionError, 'LineWidth', 1.2);
grid on; xlabel('Czas t'); ylabel('x_s(t) - x_e(t)');
title(sprintf('RK4: maksymalny błąd bezwzględny %.4g', maxAbsErrorRK4(finest)));
subplot(3, 1, 3);
plot(e.t, e.positionError, 'LineWidth', 1.2);
grid on; xlabel('Czas t'); ylabel('x_s(t) - x_e(t)');
title(sprintf('Euler: maksymalny błąd bezwzględny %.4g', maxAbsErrorEuler(finest)));

figure('Name', 'Zadanie 1 - wpływ kroku całkowania');
loglog(dtValues, maxAbsErrorRK4, 'o-', dtValues, maxAbsErrorEuler, 's-', ...
    'LineWidth', 1.3, 'MarkerFaceColor', 'auto');
grid on; xlabel('Krok całkowania dt'); ylabel('Maksymalny błąd |x_s - x_e|');
title('Wpływ kroku całkowania na dokładność');
legend('RK4', 'Euler', 'Location', 'best');

study = struct('dtValues', dtValues, 'results', {resultsRK4}, ...
    'maxAbsError', maxAbsErrorRK4, 'config', base, ...
    'resultsRK4', {resultsRK4}, 'resultsEuler', {resultsEuler}, ...
    'maxAbsErrorRK4', maxAbsErrorRK4, 'maxAbsErrorEuler', maxAbsErrorEuler);
end

function result = simulateFreeResponse(cfg, method)
cfg.method = method;
model = SpringMassSimulation(cfg);
result = model.runToEnd();
[xExact, vExact] = exactFreeResponse(result.config, ...
    result.config.x0, result.config.v0, result.t);
result.xExact = xExact;
result.vExact = vExact;
result.positionError = result.x - xExact;
end
