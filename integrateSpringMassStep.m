function nextState = integrateSpringMassStep(t, state, step, cfg, endsAtBreak)
if nargin < 5, endsAtBreak = false; end
k1 = stateDerivative(t, state, cfg, cfg.w, cfg.h);
switch cfg.method
    case 'euler'
        nextState = state + step*k1;
    case 'rk4'
        k2 = stateDerivative(t + step/2, state + step*k1/2, cfg, cfg.w, cfg.h);
        k3 = stateDerivative(t + step/2, state + step*k2/2, cfg, cfg.w, cfg.h);
        endTime = t + step;
        if endsAtBreak
            endTime = endTime - eps(max(1, abs(endTime)));
        end
        k4 = stateDerivative(endTime, state + step*k3, cfg, cfg.w, cfg.h);
        nextState = state + step*(k1 + 2*k2 + 2*k3 + k4)/6;
    otherwise
        error('integrateSpringMassStep:UnknownMethod', 'Use method="rk4" or method="euler".');
end
if any(~isfinite(nextState))
    error('SpringMassSimulation:NonfiniteState', ...
        'Rozwiązanie przestało być skończone. Zmniejsz krok dt lub zmień metodę.');
end
end
