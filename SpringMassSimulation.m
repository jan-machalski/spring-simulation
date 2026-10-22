classdef SpringMassSimulation < handle
    properties (SetAccess = private)
        Config
        Time = 0
        State
        Revision = 0
    end
    properties (Access = private)
        History
        GridOrigin = 0
        GridIndex = 1
        BreakTimes = []
        SampleCount = 0
        Capacity = 256
    end
    methods
        function model = SpringMassSimulation(cfg)
            model.reset(cfg);
        end

        function reset(model, cfg)
            cfg = normalizeSpringMassConfig(cfg);
            state = [cfg.x0; cfg.v0];
            validateSpringMassGeometry(cfg, state, 0);
            model.Config = cfg;
            model.Time = 0;
            model.Revision = 0;
            model.State = state;
            model.GridOrigin = 0;
            model.GridIndex = 1;
            model.refreshBreaks();
            model.SampleCount = 0;
            model.Capacity = 256;
            empty = zeros(model.Capacity, 1);
            model.History = struct('t', empty, 'x', empty, 'v', empty, ...
                'a', empty, 'w', empty, 'h', empty, 'springForce', empty, ...
                'dampingForce', empty, 'externalForce', empty, 'state', zeros(2, model.Capacity));
            model.storeSample(1);
        end

        function updateConfiguration(model, cfg)
            cfg = normalizeSpringMassConfig(cfg);
            if cfg.tEnd < model.Time
                error('SpringMassSimulation:PastEnd', ...
                    'Czas końcowy nie może poprzedzać bieżącego czasu modelu.');
            end
            validateSpringMassGeometry(cfg, model.State, model.Time);
            if cfg.dt ~= model.Config.dt
                model.GridOrigin = model.Time;
                model.GridIndex = 1;
            end
            model.Config = cfg;
            model.refreshBreaks();
            model.storeSample(model.SampleCount);
        end

        function steps = advanceTo(model, targetTime, maxSteps, timeBudget)
            if nargin < 3, maxSteps = 250; end
            if nargin < 4, timeBudget = Inf; end
            if isfinite(timeBudget), started = tic; end
            targetTime = min(targetTime, model.Config.tEnd);
            steps = 0;
            while model.Time < model.Config.tEnd && steps < maxSteps
                cfg = model.Config;
                gridTime = model.GridOrigin + model.GridIndex * cfg.dt;
                tolerance = 8 * eps(max(1, abs(model.Time)));
                if gridTime <= model.Time + tolerance
                    model.GridIndex = model.GridIndex + 1;
                    continue;
                end
                futureBreaks = model.BreakTimes(model.BreakTimes > model.Time + tolerance);
                nextTime = min([gridTime, cfg.tEnd, futureBreaks]);
                if nextTime > targetTime + tolerance, break; end
                step = nextTime - model.Time;
                endsAtBreak = any(abs(model.BreakTimes - nextTime) <= tolerance);
                nextState = integrateSpringMassStep(model.Time, model.State, step, cfg, endsAtBreak);
                validateSpringMassGeometry(cfg, nextState, nextTime);
                model.Time = nextTime;
                model.State = nextState;
                if abs(nextTime - gridTime) <= tolerance
                    model.GridIndex = model.GridIndex + 1;
                end
                model.storeSample(model.SampleCount + 1);
                steps = steps + 1;
                if isfinite(timeBudget) && toc(started) >= timeBudget, break; end
            end
        end

        function result = runToEnd(model)
            model.advanceTo(model.Config.tEnd, Inf);
            result = model.snapshot();
        end

        function result = snapshot(model, maxPoints)
            if nargin < 2, maxPoints = Inf; end
            if model.SampleCount > maxPoints
                indices = unique(round(linspace(1, model.SampleCount, maxPoints)));
            else
                indices = 1:model.SampleCount;
            end
            result = model.readSamples(indices);
        end

        function result = currentSample(model)
            result = model.readSamples(model.SampleCount);
        end
    end

    methods (Access = private)
        function result = readSamples(model, indices)
            result = struct();
            names = fieldnames(model.History);
            for i = 1:numel(names)
                name = names{i};
                if strcmp(name, 'state')
                    result.state = model.History.state(:, indices);
                else
                    result.(name) = model.History.(name)(indices, :);
                end
            end
            result.config = model.Config;
        end
        function refreshBreaks(model)
            cfg = model.Config;
            values = [signalBreaks(cfg.w, cfg.tEnd), signalBreaks(cfg.h, cfg.tEnd)];
            model.BreakTimes = unique(values(isfinite(values) & values > 0 & values < cfg.tEnd));
        end

        function storeSample(model, index)
            if index > model.Capacity
                model.Capacity = max(index, 2 * model.Capacity);
                names = fieldnames(model.History);
                for i = 1:numel(names)
                    name = names{i};
                    if strcmp(name, 'state')
                        model.History.state(:, model.Capacity) = 0;
                    else
                        model.History.(name)(model.Capacity, 1) = 0;
                    end
                end
            end
            cfg = model.Config;
            x = model.State(1); v = model.State(2);
            w = signalValue(cfg.w, model.Time);
            h = signalValue(cfg.h, model.Time);
            [f, g, a] = springMassForces(x, v, w, h, cfg);
            model.History.t(index, 1) = model.Time;
            model.History.x(index, 1) = x;
            model.History.v(index, 1) = v;
            model.History.w(index, 1) = w;
            model.History.h(index, 1) = h;
            model.History.springForce(index, 1) = f;
            model.History.dampingForce(index, 1) = g;
            model.History.externalForce(index, 1) = h;
            model.History.a(index, 1) = a;
            model.History.state(:, index) = model.State;
            model.SampleCount = max(model.SampleCount, index);
            model.Revision = model.Revision + 1;
        end
    end
end
