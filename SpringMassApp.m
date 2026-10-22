classdef SpringMassApp < handle

    properties (Access = private)
        UIFigure
        MainGrid
        LeftGrid
        ParameterPanel
        SignalPanel
        OutputPanel
        PlotGrid
        VisualizationAxes
        KinematicsAxes
        StateAxes
        ForcesAxes

        MassSlider
        DampingSlider
        StiffnessSlider
        InitialPositionSlider
        InitialVelocitySlider
        TimeStepSlider
        ParameterFields = {}
        ParameterSliders = {}
        SimulationTimeField
        MethodDropDown
        ViewRangeField
        StartButton
        StopButton
        ResetButton
        StatusLabel
        OutputValueLabels = {}
        SignalControls = struct()

        SpringLine
        AnchorLine
        MassMarker
        KinematicsLines = {}
        StateLine
        ForceLines = {}
        VisualizationScale = 0.065
        SpringRestLength = 25

        RenderTimer = []
        SimulationTimer = []
        Simulation = []
        LastRenderedRevision = -1
        Result = []
        TargetTime = 0
        ClockOffset = 0
        SimulationClock = []
        IsDirty = true
        IsClosing = false
        PendingSimulationError = []
        RenderClock = []
        LastPlotTime = -Inf
        LastReadoutTime = -Inf
        MaxPlotPoints = 1600
    end

    methods
        function app = SpringMassApp()
            app.createUI();
            app.RenderClock = tic;
            app.syncParameterFields();
            app.updateIdleReadouts();
            app.drawRestingMass();
        end

        function delete(app)
            app.IsClosing = true;
            app.stopTimer();
            timers = {app.SimulationTimer, app.RenderTimer};
            for i = 1:numel(timers)
                if ~isempty(timers{i}) && isvalid(timers{i}), delete(timers{i}); end
            end
            if ~isempty(app.UIFigure) && isvalid(app.UIFigure)
                delete(app.UIFigure);
            end
        end
    end

    methods (Access = private)
        function createUI(app)
            app.UIFigure = uifigure('Name', 'Symulacja sprężyna–masa', ...
                'Position', [80 80 1320 820], 'Color', [0.96 0.97 0.98]);
            app.UIFigure.CloseRequestFcn = @(~,~) delete(app);

            app.MainGrid = uigridlayout(app.UIFigure, [1 3]);
            app.MainGrid.ColumnWidth = {350, '1x', '1x'};
            app.MainGrid.RowHeight = {'1x'};
            app.MainGrid.Padding = [10 10 10 10];
            app.MainGrid.ColumnSpacing = 10;

            app.createControlColumn();
            app.createPlotColumn(2);
            app.createPlotColumn(3);
            app.createAxes();
            app.createTimers();
        end

        function createControlColumn(app)
            app.LeftGrid = uigridlayout(app.MainGrid, [3 1]);
            app.LeftGrid.Layout.Row = 1;
            app.LeftGrid.Layout.Column = 1;
            app.LeftGrid.RowHeight = {375, '1x', 140};
            app.LeftGrid.ColumnWidth = {'1x'};
            app.LeftGrid.Padding = [0 0 0 0];
            app.LeftGrid.RowSpacing = 8;

            app.createParameterPanel();
            app.createSignalPanel();
            app.createOutputPanel();
        end

        function createParameterPanel(app)
            app.ParameterPanel = uipanel(app.LeftGrid, 'Title', 'Parametry układu');
            app.ParameterPanel.Layout.Row = 1;
            app.ParameterPanel.Layout.Column = 1;
            grid = uigridlayout(app.ParameterPanel, [10 3]);
            grid.ColumnWidth = {84, '1x', 88};
            grid.RowHeight = {30, 30, 30, 30, 30, 30, 30, 30, 30, 38};
            grid.Padding = [8 6 8 6];
            grid.RowSpacing = 3;

            app.MassSlider = app.addSlider(grid, 1, 'm [kg]', [0.1 10], 1);
            app.DampingSlider = app.addSlider(grid, 2, 'k [N·s/m]', [0 5], 0.4);
            app.StiffnessSlider = app.addSlider(grid, 3, 'c [N/m]', [0.1 10], 1);
            app.InitialPositionSlider = app.addSlider(grid, 4, 'Δx₀ [m]', [-5 5], 1);
            app.InitialVelocitySlider = app.addSlider(grid, 5, 'v₀ [m/s]', [-2 2], 0);
            app.TimeStepSlider = app.addSlider(grid, 6, 'dt [s]', [0.001 0.05], 0.01);

            timeLabel = uilabel(grid, 'Text', 'Czas [s]', 'HorizontalAlignment', 'right');
            timeLabel.Layout.Row = 7; timeLabel.Layout.Column = 1;
            app.SimulationTimeField = uieditfield(grid, 'numeric', ...
                'Limits', [0 Inf], 'Value', 20, 'ValueDisplayFormat', '%.3g', ...
                'Tag', 'SimulationTimeField');
            app.SimulationTimeField.Layout.Row = 7;
            app.SimulationTimeField.Layout.Column = [2 3];
            app.SimulationTimeField.ValueChangedFcn = @(~,~) app.configurationChanged();

            methodLabel = uilabel(grid, 'Text', 'Metoda', 'HorizontalAlignment', 'right');
            methodLabel.Layout.Row = 8; methodLabel.Layout.Column = 1;
            app.MethodDropDown = uidropdown(grid, 'Items', {'RK4', 'Euler'}, ...
                'ItemsData', {'rk4', 'euler'}, 'Value', 'rk4', ...
                'Tag', 'MethodDropDown', ...
                'ValueChangedFcn', @(~,~) app.configurationChanged());
            app.MethodDropDown.Layout.Row = 8;
            app.MethodDropDown.Layout.Column = [2 3];

            rangeLabel = uilabel(grid, 'Text', 'Widok ± [m]', 'HorizontalAlignment', 'right');
            rangeLabel.Layout.Row = 9; rangeLabel.Layout.Column = 1;
            app.ViewRangeField = uieditfield(grid, 'numeric', 'Value', 10, ...
                'Limits', [0 Inf], 'LowerLimitInclusive', 'off', ...
                'Tag', 'ViewRangeField', ...
                'Tooltip', 'Stały zakres odchylenia x-w w animacji względem mocowania.', ...
                'ValueChangedFcn', @(~,~) app.fitLiveView());
            app.ViewRangeField.Layout.Row = 9;
            app.ViewRangeField.Layout.Column = 2;
            fitButton = uibutton(grid, 'Text', 'Dopasuj', 'Tag', 'FitPlotsButton', ...
                'Tooltip', 'Jednorazowo dopasuj zakresy wykresów do dotychczasowych danych.', ...
                'ButtonPushedFcn', @(~,~) app.fitPlotLimits(true));
            fitButton.Layout.Row = 9; fitButton.Layout.Column = 3;

            buttonGrid = uigridlayout(grid, [1 3]);
            buttonGrid.Layout.Row = 10; buttonGrid.Layout.Column = [1 3];
            buttonGrid.ColumnWidth = {'1x','1x','1x'};
            buttonGrid.Padding = [0 0 0 0];
            app.StartButton = uibutton(buttonGrid, 'push', 'Text', 'Start', ...
                'ButtonPushedFcn', @(~,~) app.startButtonPushed());
            app.StopButton = uibutton(buttonGrid, 'push', 'Text', 'Stop', ...
                'ButtonPushedFcn', @(~,~) app.stopButtonPushed());
            app.ResetButton = uibutton(buttonGrid, 'push', 'Text', 'Reset', ...
                'ButtonPushedFcn', @(~,~) app.resetButtonPushed());
            app.StopButton.Enable = 'off';
        end

        function slider = addSlider(app, parent, row, caption, limits, initialValue)
            label = uilabel(parent, 'Text', caption, 'HorizontalAlignment', 'right');
            label.Layout.Row = row; label.Layout.Column = 1;
            slider = uislider(parent, 'Limits', limits, 'Value', initialValue);
            slider.Tag = sprintf('ParameterSlider%d', row);
            slider.Layout.Row = row; slider.Layout.Column = 2;
            field = uieditfield(parent, 'numeric', 'Value', initialValue, ...
                'ValueDisplayFormat', '%.8g', 'Tag', sprintf('ParameterField%d', row));
            field.Layout.Row = row; field.Layout.Column = 3;
            if any(row == [1 3 6])
                field.Limits = [0 Inf];
                field.LowerLimitInclusive = 'off';
            elseif row == 2
                field.Limits = [0 Inf];
            end
            field.ValueChangedFcn = @(source,~) ...
                app.parameterFieldChanged(slider, source);
            slider.ValueChangedFcn = @(~,~) app.configurationChanged();
            if row == 6
                hint = 'Krok całkowania w sekundach. Model liczy tylko kroki, których czas już nadszedł; widok odczytuje jego stan około 30 razy/s.';
                field.Tooltip = hint;
                slider.Tooltip = hint;
            elseif row == 4
                hint = 'Odchylenie od równowagi początkowej: x(0)=w(0)+h(0)/c+Δx₀.';
                field.Tooltip = hint;
                slider.Tooltip = hint;
            end
            app.ParameterFields{end + 1} = field;
            app.ParameterSliders{end + 1} = slider;
        end

        function parameterFieldChanged(app, slider, field)
            value = field.Value;
            if ~isfinite(value)
                field.Value = slider.Value;
                uialert(app.UIFigure, 'Wprowadź skończoną wartość liczbową.', ...
                    'Nieprawidłowy parametr');
                return;
            end
            slider.Limits = [min(slider.Limits(1), value), ...
                max(slider.Limits(2), value)];
            slider.Value = value;
            app.configurationChanged();
        end

        function createSignalPanel(app)
            app.SignalPanel = uipanel(app.LeftGrid, 'Title', 'Wymuszenia');
            app.SignalPanel.Layout.Row = 2;
            app.SignalPanel.Layout.Column = 1;
            container = uigridlayout(app.SignalPanel, [1 1], 'Padding', [4 4 4 4]);
            tabs = uitabgroup(container);
            wTab = uitab(tabs, 'Title', 'w(t)');
            hTab = uitab(tabs, 'Title', 'h(t)');
            app.SignalControls.w = app.createSignalControls(wTab, 'w');
            app.SignalControls.h = app.createSignalControls(hTab, 'h');
        end

        function controls = createSignalControls(app, parent, prefix)
            grid = uigridlayout(parent, [5 2]);
            grid.ColumnWidth = {112, '1x'};
            grid.RowHeight = {30, 28, 28, 28, 28};
            grid.Padding = [8 8 8 8];
            grid.RowSpacing = 5;

            name = upper(prefix);
            label = uilabel(grid, 'Text', [name ' — typ']);
            label.Layout.Row = 1; label.Layout.Column = 1;
            controls.Type = uidropdown(grid, ...
                'Items', {'Stała','Skok','Prostokątna','Sinusoidalna'}, ...
                'Value', 'Stała');
            controls.Type.Layout.Row = 1; controls.Type.Layout.Column = 2;
            controls.Type.ValueChangedFcn = @(~,~) app.configurationChanged();

            controls.A = app.addNumericSignalField(grid, 2, 'Amplituda A', 0);
            controls.Omega = app.addNumericSignalField(grid, 3, 'Częstotliwość ω', 1);
            controls.Phase = app.addNumericSignalField(grid, 4, 'Faza φ [rad]', 0);
            controls.T0 = app.addNumericSignalField(grid, 5, 'Czas skoku t₀', 0);
            controls.Type.Tag = ['Signal_' prefix '_Type'];
            controls.A.Tag = ['Signal_' prefix '_A'];
            controls.Phase.Tag = ['Signal_' prefix '_Phase'];
        end

        function field = addNumericSignalField(app, parent, row, caption, initialValue)
            label = uilabel(parent, 'Text', caption);
            label.Layout.Row = row; label.Layout.Column = 1;
            field = uieditfield(parent, 'numeric', 'Value', initialValue, ...
                'Limits', [-Inf Inf], 'ValueDisplayFormat', '%.5g');
            field.Layout.Row = row; field.Layout.Column = 2;
            field.ValueChangedFcn = @(~,~) app.configurationChanged();
        end

        function createOutputPanel(app)
            app.OutputPanel = uipanel(app.LeftGrid, 'Title', 'Wartości bieżące');
            app.OutputPanel.Layout.Row = 3;
            app.OutputPanel.Layout.Column = 1;
            grid = uigridlayout(app.OutputPanel, [4 4]);
            grid.ColumnWidth = {34, '1x', 34, '1x'};
            grid.RowHeight = {25, 25, 25, 25};
            grid.Padding = [8 6 8 6];
            grid.RowSpacing = 1;
            captions = {'t','x','v','a','f','g','h'};
            initial = {'0.00','0','0','0','0','0','0'};
            positions = [1 1; 1 3; 2 1; 2 3; 3 1; 3 3; 4 1];
            app.OutputValueLabels = cell(1, numel(captions));
            for i = 1:numel(captions)
                lab = uilabel(grid, 'Text', [captions{i} ' ='], ...
                    'HorizontalAlignment', 'right');
                lab.Layout.Row = positions(i,1); lab.Layout.Column = positions(i,2);
                val = uilabel(grid, 'Text', initial{i}, 'FontWeight', 'bold');
                val.Tag = ['Readout_' captions{i}];
                val.Layout.Row = positions(i,1); val.Layout.Column = positions(i,2)+1;
                app.OutputValueLabels{i} = val;
            end
            app.StatusLabel = uilabel(grid, 'Text', 'Gotowe', 'FontColor', [0.2 0.35 0.2]);
            app.StatusLabel.Layout.Row = 4; app.StatusLabel.Layout.Column = [3 4];
        end

        function createPlotColumn(app, column)
            app.PlotGrid = uigridlayout(app.MainGrid, [2 1]);
            app.PlotGrid.Layout.Row = 1;
            app.PlotGrid.Layout.Column = column;
            app.PlotGrid.RowHeight = {'1x','1x'};
            app.PlotGrid.ColumnWidth = {'1x'};
            app.PlotGrid.RowSpacing = 10;
            app.PlotGrid.Padding = [0 0 0 0];
            if column == 2
                app.VisualizationAxes = uiaxes(app.PlotGrid);
                app.VisualizationAxes.Layout.Row = 1;
                app.KinematicsAxes = uiaxes(app.PlotGrid);
                app.KinematicsAxes.Layout.Row = 2;
            else
                app.StateAxes = uiaxes(app.PlotGrid);
                app.StateAxes.Layout.Row = 1;
                app.ForcesAxes = uiaxes(app.PlotGrid);
                app.ForcesAxes.Layout.Row = 2;
            end
        end

        function createAxes(app)
            app.VisualizationAxes.Tag = 'VisualizationAxes';
            title(app.VisualizationAxes, 'Sprężyna — widok względem mocowania');
            xlabel(app.VisualizationAxes, '');
            ylabel(app.VisualizationAxes, '');
            app.VisualizationAxes.XLim = [-0.8 0.8];
            app.VisualizationAxes.XTick = [];
            app.VisualizationAxes.XAxis.Visible = 'off';
            app.VisualizationAxes.YAxis.Visible = 'off';
            app.VisualizationAxes.YTick = [];
            app.VisualizationAxes.YLim = [0 4.4];
            app.VisualizationAxes.Box = 'off';
            app.VisualizationAxes.YGrid = 'off';
            hold(app.VisualizationAxes, 'on');
            app.SpringLine = plot(app.VisualizationAxes, nan, nan, ...
                'Color', [0.1 0.35 0.8], 'LineWidth', 2, 'Tag', 'SpringCoil');
            app.AnchorLine = plot(app.VisualizationAxes, nan, nan, ...
                'k-', 'LineWidth', 3, 'Tag', 'SpringMount');
            app.MassMarker = plot(app.VisualizationAxes, nan, nan, 's', ...
                'MarkerSize', 32, 'MarkerFaceColor', [0.85 0.25 0.18], ...
                'MarkerEdgeColor', [0.3 0.1 0.1], 'LineWidth', 1.2, ...
                'LineStyle', 'none', 'HandleVisibility', 'off', 'Tag', 'SpringMass');
            hold(app.VisualizationAxes, 'off');

            title(app.KinematicsAxes, 'Położenie, prędkość i przyspieszenie');
            xlabel(app.KinematicsAxes, 'Czas t [s]');
            ylabel(app.KinematicsAxes, 'Wartości (różne jednostki)');
            grid(app.KinematicsAxes, 'on');

            title(app.StateAxes, 'Trajektoria stanu (x, v)');
            xlabel(app.StateAxes, 'Położenie x [m]');
            ylabel(app.StateAxes, 'Prędkość v [m/s]');
            grid(app.StateAxes, 'on');

            title(app.ForcesAxes, 'Siły działające na masę');
            xlabel(app.ForcesAxes, 'Czas t [s]');
            ylabel(app.ForcesAxes, 'Siła [N]');
            grid(app.ForcesAxes, 'on');
            axes = [app.KinematicsAxes, app.StateAxes, app.ForcesAxes];
            for i = 1:numel(axes)
                axes(i).Interactions = [];
                axes(i).Toolbar.Visible = 'off';
            end
        end

        function createTimers(app)
            app.SimulationTimer = timer('ExecutionMode', 'fixedSpacing', ...
                'Period', 0.01, ...
                'TimerFcn', @(~,~) app.advanceSimulation());
            app.RenderTimer = timer('ExecutionMode', 'fixedSpacing', ...
                'Period', 0.033, ...
                'TimerFcn', @(~,~) app.renderFrame());
        end

        function configurationChanged(app)
            app.syncParameterFields();
            cfg = app.readConfiguration();
            if ~isempty(app.Simulation) && ~app.IsDirty
                old = app.Simulation.Config;
                restart = cfg.initialOffset ~= old.initialOffset ...
                    || cfg.v0 ~= old.v0 || cfg.tEnd ~= old.tEnd;
                if ~restart
                    try
                        if app.Simulation.Time == 0 && strcmp(app.SimulationTimer.Running, 'off')
                            app.Simulation.reset(cfg);
                            app.Result = app.Simulation.snapshot();
                            app.plotResult();
                        else
                            app.Simulation.updateConfiguration(cfg);
                        end
                    catch exception
                        app.stopTimer();
                        app.IsDirty = true;
                        app.clearResultPlots();
                        app.updateIdleReadouts();
                        app.drawRestingMass();
                        app.StopButton.Enable = 'off';
                        app.StatusLabel.Text = 'Zmień ustawienia i uruchom ponownie';
                        uialert(app.UIFigure, exception.message, 'Niedopuszczalna konfiguracja');
                        return;
                    end
                    app.renderFrame(true);
                    app.StatusLabel.Text = 'Parametry modelu zaktualizowane';
                    return;
                end
            end
            app.IsDirty = true;
            app.stopTimer();
            app.TargetTime = 0;
            app.StartButton.Enable = 'on';
            app.StopButton.Enable = 'off';
            app.clearResultPlots();
            app.updateIdleReadouts();
            if ~app.IsClosing
                app.StatusLabel.Text = 'Parametry zmienione — naciśnij Start';
                app.StatusLabel.FontColor = [0.65 0.35 0.05];
            end
            app.drawRestingMass();
            drawnow limitrate;
        end

        function syncParameterFields(app)
            for i = 1:numel(app.ParameterFields)
                app.ParameterFields{i}.Value = app.ParameterSliders{i}.Value;
            end
        end

        function clearResultPlots(app)
            lines = [app.KinematicsLines, app.ForceLines];
            for i = 1:numel(lines)
                if isgraphics(lines{i})
                    set(lines{i}, 'XData', nan, 'YData', nan);
                end
            end
            if ~isempty(app.StateLine) && isgraphics(app.StateLine)
                set(app.StateLine, 'XData', nan, 'YData', nan, ...
                    'MarkerIndices', []);
            end
        end

        function updateIdleReadouts(app)
            if isempty(app.OutputValueLabels) || numel(app.OutputValueLabels) < 7
                return;
            end
            cfg = app.readConfiguration();
            w0 = signalValue(cfg.w, 0); h0 = signalValue(cfg.h, 0);
            [f, g, a] = springMassForces(cfg.x0, cfg.v0, w0, h0, cfg);
            values = [0, cfg.x0, cfg.v0, a, f, g, h0];
            for i = 1:numel(values)
                app.OutputValueLabels{i}.Text = sprintf('%.5g', values(i));
            end
        end

        function startButtonPushed(app)
            try
                if strcmp(app.SimulationTimer.Running, 'on'), return; end
                app.PendingSimulationError = [];
                if isempty(app.Simulation) || app.IsDirty ...
                        || app.Simulation.Time >= app.Simulation.Config.tEnd
                    cfg = app.readConfiguration();
                    app.Simulation = SpringMassSimulation(cfg);
                    app.Result = app.Simulation.snapshot();
                    app.TargetTime = 0;
                    app.plotResult();
                    app.IsDirty = false;
                end
                app.renderFrame(true);
                if app.Simulation.Time < app.Simulation.Config.tEnd
                    app.ClockOffset = app.TargetTime;
                    app.SimulationClock = tic;
                    start(app.SimulationTimer);
                    start(app.RenderTimer);
                    app.StartButton.Enable = 'off';
                    app.StopButton.Enable = 'on';
                    app.StatusLabel.Text = 'Symulacja na żywo';
                    app.StatusLabel.FontColor = [0.1 0.4 0.2];
                else
                    app.StartButton.Enable = 'on';
                    app.StopButton.Enable = 'off';
                    app.StatusLabel.Text = 'Symulacja zakończona';
                    app.StatusLabel.FontColor = [0.2 0.35 0.2];
                end
            catch exception
                app.stopTimer();
                app.StartButton.Enable = 'on';
                app.StopButton.Enable = 'off';
                uialert(app.UIFigure, exception.message, 'Błąd symulacji');
                app.StatusLabel.Text = 'Błąd symulacji';
                app.StatusLabel.FontColor = [0.8 0.1 0.1];
            end
        end

        function stopButtonPushed(app)
            if strcmp(app.SimulationTimer.Running, 'on') && ~isempty(app.SimulationClock)
                app.TargetTime = min(app.Simulation.Config.tEnd, ...
                    app.ClockOffset + toc(app.SimulationClock));
            end
            app.stopTimer();
            app.renderFrame(true);
            app.StartButton.Enable = 'on';
            app.StopButton.Enable = 'off';
            if ~isempty(app.Simulation) && ~app.IsDirty
                if app.Simulation.Time >= app.Simulation.Config.tEnd
                    app.StatusLabel.Text = 'Symulacja zakończona';
                else
                    app.StatusLabel.Text = 'Symulacja wstrzymana';
                end
            else
                app.StatusLabel.Text = 'Zatrzymano';
            end
            app.StatusLabel.FontColor = [0.35 0.35 0.35];
        end

        function resetButtonPushed(app)
            app.stopTimer();
            app.TargetTime = 0;
            app.StartButton.Enable = 'on';
            app.StopButton.Enable = 'off';
            try
                app.Simulation = SpringMassSimulation(app.readConfiguration());
            catch exception
                app.IsDirty = true;
                app.clearResultPlots();
                app.updateIdleReadouts();
                app.drawRestingMass();
                uialert(app.UIFigure, exception.message, 'Niedopuszczalny start');
                return;
            end
            app.PendingSimulationError = [];
            app.Result = app.Simulation.snapshot();
            app.IsDirty = false;
            app.plotResult();
            app.renderFrame(true);
            app.StatusLabel.Text = 'Ustawiono stan początkowy';
            app.StatusLabel.FontColor = [0.2 0.35 0.2];
        end

        function cfg = readConfiguration(app)
            cfg = struct();
            cfg.m = app.MassSlider.Value;
            cfg.k = app.DampingSlider.Value;
            cfg.c = app.StiffnessSlider.Value;
            cfg.x0 = app.InitialPositionSlider.Value;
            cfg.initialOffset = app.InitialPositionSlider.Value;
            cfg.restLength = app.SpringRestLength;
            cfg.v0 = app.InitialVelocitySlider.Value;
            cfg.dt = app.TimeStepSlider.Value;
            cfg.tEnd = app.SimulationTimeField.Value;
            cfg.method = app.MethodDropDown.Value;
            cfg.w = app.readSignal('w');
            cfg.h = app.readSignal('h');
            initialState = initialSpringMassState(cfg);
            cfg.x0 = initialState(1);
        end

        function signal = readSignal(app, name)
            controls = app.SignalControls.(name);
            switch controls.Type.Value
                case 'Stała'
                    type = 'constant';
                case 'Skok'
                    type = 'step';
                case 'Prostokątna'
                    type = 'square';
                case 'Sinusoidalna'
                    type = 'sine';
                otherwise
                    error('Nieznany typ wymuszenia %s(t).', name);
            end
            signal = struct('type', type, 'A', controls.A.Value, ...
                'omega', controls.Omega.Value, 'phase', controls.Phase.Value, ...
                't0', controls.T0.Value);
        end

        function plotResult(app)
            app.LastRenderedRevision = -1;
            app.LastPlotTime = -Inf;
            app.LastReadoutTime = -Inf;
            r = app.Result;
            if numel(app.KinematicsLines) == 4 && numel(app.ForceLines) == 3 ...
                    && all(isgraphics([app.KinematicsLines{:}, app.ForceLines{:}])) ...
                    && ~isempty(app.StateLine) && isgraphics(app.StateLine)
                app.clearResultPlots();
                app.fitLiveView();
                app.fitPlotLimits(false);
                return;
            end
            legend(app.KinematicsAxes, 'off');
            cla(app.KinematicsAxes);
            hold(app.KinematicsAxes, 'on');
            app.KinematicsLines = cell(1, 4);
            app.KinematicsLines{1} = plot(app.KinematicsAxes, nan, nan, ...
                'LineWidth', 1.4, 'DisplayName', 'x(t) [m]');
            app.KinematicsLines{2} = plot(app.KinematicsAxes, nan, nan, '--', ...
                'LineWidth', 1.2, 'DisplayName', 'w(t) [m]');
            app.KinematicsLines{3} = plot(app.KinematicsAxes, nan, nan, ...
                'LineWidth', 1.2, 'DisplayName', 'v(t) [m/s]');
            app.KinematicsLines{4} = plot(app.KinematicsAxes, nan, nan, ...
                'LineWidth', 1.2, 'DisplayName', 'a(t) [m/s²]');
            hold(app.KinematicsAxes, 'off');
            legend(app.KinematicsAxes, [app.KinematicsLines{:}], ...
                'Location', 'northeast', 'AutoUpdate', 'off', 'Visible', 'on');
            xlim(app.KinematicsAxes, [0, max(r.config.tEnd, eps)]);
            grid(app.KinematicsAxes, 'on');

            legend(app.StateAxes, 'off');
            cla(app.StateAxes);
            hold(app.StateAxes, 'on');
            app.StateLine = plot(app.StateAxes, nan, nan, ...
                'LineWidth', 1.4, 'DisplayName', 'Trajektoria', ...
                'Marker', 'o', 'MarkerIndices', 1, 'MarkerSize', 7, ...
                'MarkerFaceColor', [0.85 0.2 0.15], ...
                'MarkerEdgeColor', [0.5 0.1 0.08]);
            hold(app.StateAxes, 'off');
            legend(app.StateAxes, app.StateLine, ...
                'Location', 'northeast', 'AutoUpdate', 'off', 'Visible', 'on');
            grid(app.StateAxes, 'on');

            legend(app.ForcesAxes, 'off');
            cla(app.ForcesAxes);
            hold(app.ForcesAxes, 'on');
            app.ForceLines = cell(1, 3);
            app.ForceLines{1} = plot(app.ForcesAxes, nan, nan, ...
                'LineWidth', 1.3, 'DisplayName', 'f(t) — sprężyna');
            app.ForceLines{2} = plot(app.ForcesAxes, nan, nan, ...
                'LineWidth', 1.3, 'DisplayName', 'g(t) — tłumienie');
            app.ForceLines{3} = plot(app.ForcesAxes, nan, nan, ...
                'LineWidth', 1.3, 'DisplayName', 'h(t) — zewnętrzna');
            hold(app.ForcesAxes, 'off');
            legend(app.ForcesAxes, [app.ForceLines{:}], ...
                'Location', 'northeast', 'AutoUpdate', 'off', 'Visible', 'on');
            xlim(app.ForcesAxes, [0, max(r.config.tEnd, eps)]);
            grid(app.ForcesAxes, 'on');

            app.fitLiveView();
            app.fitPlotLimits(false);
        end

        function advanceSimulation(app)
            if app.IsClosing || isempty(app.Simulation) || app.IsDirty ...
                    || isempty(app.SimulationClock)
                return;
            end
            try
                app.TargetTime = min(app.Simulation.Config.tEnd, ...
                    app.ClockOffset + toc(app.SimulationClock));
                app.Simulation.advanceTo(app.TargetTime, 250, 0.012);
                if app.Simulation.Time >= app.Simulation.Config.tEnd
                    stop(app.SimulationTimer);
                end
            catch exception
                stop(app.SimulationTimer);
                app.PendingSimulationError = exception;
                app.LastRenderedRevision = -1;
            end
        end

        function renderFrame(app, force)
            if nargin < 2, force = false; end
            if app.IsClosing || app.IsDirty || isempty(app.Simulation), return; end
            if ~force && app.LastRenderedRevision == app.Simulation.Revision, return; end
            sample = app.Simulation.currentSample();
            now = toc(app.RenderClock);
            flush = force || sample.t >= sample.config.tEnd || ~isempty(app.PendingSimulationError);
            app.updateSpringDrawing(sample.w, sample.x);
            if flush || now - app.LastPlotTime >= 0.1
                r = app.Simulation.snapshot(app.MaxPlotPoints);
                app.Result = r;
                visible = [r.x, r.w, r.v, r.a, r.springForce, ...
                    r.dampingForce, r.externalForce];
                for j = 1:numel(app.KinematicsLines)
                    set(app.KinematicsLines{j}, 'XData', r.t, 'YData', visible(:, j));
                end
                set(app.StateLine, 'XData', r.x, 'YData', r.v, 'MarkerIndices', numel(r.t));
                for j = 1:numel(app.ForceLines)
                    set(app.ForceLines{j}, 'XData', r.t, 'YData', visible(:, 4 + j));
                end
                app.LastPlotTime = now;
            end
            if flush || now - app.LastReadoutTime >= 0.2
                values = [sample.t, sample.x, sample.v, sample.a, ...
                    sample.springForce, sample.dampingForce, sample.externalForce];
                for i = 1:numel(values)
                    value = sprintf('%.5g', values(i));
                    if ~strcmp(app.OutputValueLabels{i}.Text, value)
                        app.OutputValueLabels{i}.Text = value;
                    end
                end
                app.LastReadoutTime = now;
            end
            app.LastRenderedRevision = app.Simulation.Revision;
            if ~isempty(app.PendingSimulationError)
                exception = app.PendingSimulationError;
                app.PendingSimulationError = [];
                if strcmp(app.RenderTimer.Running, 'on'), stop(app.RenderTimer); end
                app.StartButton.Enable = 'on';
                app.StopButton.Enable = 'off';
                app.StatusLabel.Text = 'Symulacja zatrzymana — granica modelu';
                app.StatusLabel.FontColor = [0.8 0.1 0.1];
                uialert(app.UIFigure, exception.message, 'Symulacja zatrzymana');
            elseif sample.t >= sample.config.tEnd
                if strcmp(app.RenderTimer.Running, 'on'), stop(app.RenderTimer); end
                app.StartButton.Enable = 'on';
                app.StopButton.Enable = 'off';
                app.StatusLabel.Text = 'Symulacja zakończona';
                app.StatusLabel.FontColor = [0.2 0.35 0.2];
            end
        end

        function drawRestingMass(app)
            if isempty(app.SpringLine) || ~isgraphics(app.SpringLine), return; end
            cfg = app.readConfiguration();
            x = cfg.x0;
            w0 = signalValue(cfg.w, 0);
            app.fitLiveView();
            app.fitPlotLimits(false);
            app.updateSpringDrawing(w0, x);
            if app.SpringRestLength + x - w0 <= 0
                app.StartButton.Enable = 'off';
                app.StatusLabel.Text = 'Niedopuszczalne odchylenie: ciężarek ponad mocowaniem';
                app.StatusLabel.FontColor = [0.8 0.1 0.1];
            end
        end

        function fitLiveView(app)
            range = app.ViewRangeField.Value;
            if ~isfinite(range)
                app.ViewRangeField.Value = 10;
                range = 10;
            end
            if isempty(app.Simulation) || app.IsDirty
                cfg = app.readConfiguration();
                x = cfg.x0;
                w = signalValue(cfg.w, 0);
            else
                x = app.Simulation.State(1);
                w = signalValue(app.Simulation.Config.w, app.Simulation.Time);
            end
            range = max(range, abs(x - w));
            app.ViewRangeField.Value = range;
            app.updateVisualizationAxis(range);
        end

        function updateSpringDrawing(app, anchor, massX)
            centerX = 0;
            coilWidth = 0.28;
            springTop = 3.8;
            massY = springTop - app.VisualizationScale ...
                * (app.SpringRestLength + massX - anchor);
            valid = app.SpringRestLength + massX - anchor > 0;
            if ~valid
                app.SpringLine.Visible = 'off';
                app.MassMarker.Visible = 'off';
                return;
            end
            app.SpringLine.Visible = 'on';
            app.MassMarker.Visible = 'on';
            s = linspace(0, 1, 100);
            xs = centerX + coilWidth .* sin(12*pi.*s);
            ys = springTop + (massY - springTop) .* s;
            xs([1 end]) = centerX;
            app.SpringLine.XData = xs;
            app.SpringLine.YData = ys;
            set(app.MassMarker, 'XData', centerX, 'YData', massY);
        end

        function updateVisualizationAxis(app, range)
            mountY = 3.8;
            app.VisualizationAxes.YLim = ...
                [mountY - app.VisualizationScale*(app.SpringRestLength + range) - 0.45, mountY];
            set(app.AnchorLine, 'XData', [-0.7 0.7], 'YData', [mountY mountY]);
        end

        function fitPlotLimits(app, useHistory)
            cfg = app.readConfiguration();
            if useHistory && ~app.IsDirty && ~isempty(app.Simulation)
                r = app.Simulation.snapshot(app.MaxPlotPoints);
                kin = [r.x; r.w; r.v; r.a];
                positions = r.x;
                velocities = r.v;
                forces = [r.springForce; r.dampingForce; r.externalForce];
            else
                naturalOmega = sqrt(cfg.c/cfg.m);
                wBound = abs(cfg.w.A); hBound = abs(cfg.h.A);
                xBound = max(0.5, abs(cfg.x0) + abs(cfg.v0)/naturalOmega ...
                    + 2*(wBound + hBound/cfg.c));
                vBound = max(0.5, naturalOmega*xBound + abs(cfg.v0));
                springBound = cfg.c*(xBound + wBound);
                dampingBound = cfg.k*vBound;
                aBound = (springBound + dampingBound + hBound)/cfg.m;
                kinBound = max([xBound, vBound, aBound, wBound]);
                kin = [-kinBound; kinBound];
                positions = [-xBound; xBound];
                velocities = [-vBound; vBound];
                forceBound = max([0.1, springBound, dampingBound, hBound]);
                forces = [-forceBound; forceBound];
            end
            app.KinematicsAxes.XLim = [0 max(cfg.tEnd, eps)];
            app.ForcesAxes.XLim = [0 max(cfg.tEnd, eps)];
            app.KinematicsAxes.YLim = app.paddedLimits(kin);
            app.StateAxes.XLim = app.paddedLimits(positions);
            app.StateAxes.YLim = app.paddedLimits(velocities);
            app.ForcesAxes.YLim = app.paddedLimits(forces);
        end

        function limits = paddedLimits(~, values)
            values = values(isfinite(values));
            if isempty(values), values = 0; end
            low = min(values); high = max(values);
            padding = max(0.1, 0.08*(high-low));
            limits = [low-padding high+padding];
        end

        function stopTimer(app)
            timers = {app.SimulationTimer, app.RenderTimer};
            for i = 1:numel(timers)
                if ~isempty(timers{i}) && isvalid(timers{i}) && strcmp(timers{i}.Running, 'on')
                    stop(timers{i});
                end
            end
        end
    end
end
