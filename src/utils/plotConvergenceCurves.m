function handleStruct = plotConvergenceCurves(dataStruct, opsPlot, callStage)
%PLOTCONVERGENCECURVES Plots iteration convergence curves for PowerBiMIP algorithms.
%
%   handleStruct = plotConvergenceCurves(dataStruct, opsPlot, callStage)
%
%   Description:
%       This function provides a unified plotting interface for all PowerBiMIP
%       algorithms (R&D, PADM, C&CG). It supports three stages: initialization,
%       real-time update, and final save. The plot style follows paper-quality
%       formatting standards.
%
%   Inputs:
%       dataStruct - struct: Contains iteration data to plot.
%           .algorithm    - string: 'R&D' | 'PADM' | 'C&CG'
%           .iteration    - vector: Iteration indices
%           .UB           - vector: Upper bound values (optional)
%           .LB           - vector: Lower bound values (optional)
%           .gap          - vector: Gap values (optional)
%           .objective    - vector: Objective values for PADM (optional)
%           .residual     - vector: Residual values for PADM (optional)
%       opsPlot - struct: Plot options.
%           .saveFig      - logical: Whether to save figure
%           .figFormat    - cell: Save formats {'png', 'eps'}
%           .style        - string: 'paper' | 'screen'
%           .verbose      - int: 0=no plot, 1=final plot, 2=real-time plot
%           .saveDir      - string: Directory to save figures (default: 'results/figures/')
%       callStage - string: 'init' | 'update' | 'final'
%
%   Output:
%       handleStruct - struct: Figure and axes handles for subsequent updates.
%           .figHandle    - figure handle
%           .axHandle     - axes handle(s)
%
%   Example:
%       % Initialize
%       data.algorithm = 'R&D';
%       data.iteration = 1;
%       data.UB = 100; data.LB = 80; data.gap = 20;
%       handles = plotConvergenceCurves(data, ops.plot, 'init');
%       
%       % Update
%       data.iteration = [1, 2];
%       data.UB = [100, 90]; data.LB = [80, 85]; data.gap = [20, 5];
%       plotConvergenceCurves(data, ops.plot, 'update');
%       
%       % Final save
%       plotConvergenceCurves(data, ops.plot, 'final');
%
%   See also solve_BiMIP, solve_TRO, algorithm_CCG

    % Initialize return structure
    handleStruct = struct();
    
    % Check if plotting is enabled
    if opsPlot.verbose == 0
        return;
    end
    
    % Only plot on 'update' if real-time plotting is enabled
    if strcmp(callStage, 'update') && opsPlot.verbose < 2
        return;
    end
    
    % Dispatch to specific plotting function based on algorithm
    switch dataStruct.algorithm
        case {'R&D', 'C&CG'}
            handleStruct = plotRDorCCG(dataStruct, opsPlot, callStage);
        case 'PADM'
            handleStruct = plotPADM(dataStruct, opsPlot, callStage);
        otherwise
            error('Unknown algorithm type: %s', dataStruct.algorithm);
    end
end

%% ========================================================================
% Subfunction: Plot R&D or C&CG convergence curve
% =========================================================================
function handleStruct = plotRDorCCG(dataStruct, opsPlot, callStage)
    handleStruct = struct();
    
    % --- Stage: Initialize ---
    if strcmp(callStage, 'init')
        % Create figure with 4:1 aspect ratio
        figHandle = figure('Name', sprintf('%s Convergence', dataStruct.algorithm), ...
            'NumberTitle', 'off', 'Position', [100, 100, 800, 200]);
        handleStruct.figHandle = figHandle;
        
        % Create left y-axis for objective
        yyaxis left;
        handleStruct.axLeft = gca;
        hold on;
        handleStruct.lineUB = plot(NaN, NaN, 'rs-', 'LineWidth', 1, 'MarkerSize', 6, 'DisplayName', 'UB');
        handleStruct.lineLB = plot(NaN, NaN, 'b^-', 'LineWidth', 1, 'MarkerSize', 6, 'DisplayName', 'LB');
        ylabel('Objective', 'FontName', 'Times New Roman', 'FontSize', 12);
        set(gca, 'YColor', 'k');
        
        % Create right y-axis for gap
        yyaxis right;
        handleStruct.axRight = gca;
        handleStruct.lineGap = plot(NaN, NaN, 'ko--', 'LineWidth', 1, 'MarkerSize', 6, 'DisplayName', 'Gap (%)');
        ylabel('Gap (%)', 'FontName', 'Times New Roman', 'FontSize', 12);
        set(gca, 'YColor', 'k');
        
        % Common settings
        xlabel('Iteration', 'FontName', 'Times New Roman', 'FontSize', 12);
        set(gca, 'FontName', 'Times New Roman', 'FontSize', 12);
        grid on;
        box on;
        set(gca, 'LineWidth', 0.75);
        
        % Legend without border, horizontal layout, positioned above the plot
        lgd = legend('Location', 'northoutside', 'Orientation', 'horizontal');
        lgd.Box = 'off';
        
        % Store handles in figure's UserData for later access
        setappdata(figHandle, 'plotHandles', handleStruct);
        
    % --- Stage: Update ---
    elseif strcmp(callStage, 'update')
        % Retrieve handles from the most recent figure with matching name
        figHandle = findobj('Type', 'figure', 'Name', sprintf('%s Convergence', dataStruct.algorithm));
        if isempty(figHandle)
            warning('Figure not found for update. Skipping...');
            return;
        end
        figHandle = figHandle(1); % Use the first match
        handleStruct = getappdata(figHandle, 'plotHandles');
        
        % Update data
        set(handleStruct.lineUB, 'XData', dataStruct.iteration, 'YData', dataStruct.UB);
        set(handleStruct.lineLB, 'XData', dataStruct.iteration, 'YData', dataStruct.LB);
        if isfield(dataStruct, 'gap')
            set(handleStruct.lineGap, 'XData', dataStruct.iteration, 'YData', dataStruct.gap);
        end
        
        drawnow;
        
    % --- Stage: Final ---
    elseif strcmp(callStage, 'final')
        % Retrieve handles
        figHandle = findobj('Type', 'figure', 'Name', sprintf('%s Convergence', dataStruct.algorithm));
        if isempty(figHandle)
            warning('Figure not found for final save. Skipping...');
            return;
        end
        figHandle = figHandle(1);
        handleStruct = getappdata(figHandle, 'plotHandles');
        
        % Update data one last time (in case update stage was skipped)
        if ~isempty(handleStruct) && isfield(handleStruct, 'lineUB')
            set(handleStruct.lineUB, 'XData', dataStruct.iteration, 'YData', dataStruct.UB);
            set(handleStruct.lineLB, 'XData', dataStruct.iteration, 'YData', dataStruct.LB);
            if isfield(dataStruct, 'gap')
                set(handleStruct.lineGap, 'XData', dataStruct.iteration, 'YData', dataStruct.gap);
            end
            drawnow;
        end
        
        % Save figure if requested
        if opsPlot.saveFig
            % Ensure save directory exists
            if ~isfield(opsPlot, 'saveDir')
                opsPlot.saveDir = 'results/figures/';
            end
            if ~exist(opsPlot.saveDir, 'dir')
                mkdir(opsPlot.saveDir);
            end
            
            % Generate filename
            timestamp = datestr(now, 'yyyymmdd_HHMMSS');
            baseFilename = sprintf('%s_%s_convergence', dataStruct.algorithm, timestamp);
            
            % Save in requested formats
            for i = 1:length(opsPlot.figFormat)
                fmt = opsPlot.figFormat{i};
                fullPath = fullfile(opsPlot.saveDir, [baseFilename, '.', fmt]);
                
                % Handle different format types
                if strcmpi(fmt, 'fig')
                    % Use savefig for .fig format
                    savefig(figHandle, fullPath);
                else
                    % Use exportgraphics for other formats (newer MATLAB)
                    if exist('exportgraphics', 'file')
                        exportgraphics(figHandle, fullPath, 'Resolution', 300);
                    else
                        % Fallback to saveas
                        saveas(figHandle, fullPath);
                    end
                end
            end
            fprintf('Figure saved to: %s\n', opsPlot.saveDir);
        end
    end
end

%% ========================================================================
% Subfunction: Plot PADM convergence curves (multiple subplots)
% =========================================================================
function handleStruct = plotPADM(dataStruct, opsPlot, callStage)
    handleStruct = struct();
    
    % --- Stage: Initialize ---
    if strcmp(callStage, 'init')
        % Create figure for PADM subplots
        figHandle = figure('Name', 'L1-PADM Convergence', ...
            'NumberTitle', 'off', 'Position', [100, 100, 600, 150]);
        handleStruct.figHandle = figHandle;
        handleStruct.subplotCount = 0;
        handleStruct.subplotHandles = [];
        
        % Store handles
        setappdata(figHandle, 'plotHandles', handleStruct);
        
    % --- Stage: Add New Subplot ---
    elseif strcmp(callStage, 'add_subplot')
        % Retrieve handles
        figHandle = findobj('Type', 'figure', 'Name', 'L1-PADM Convergence');
        if isempty(figHandle)
            warning('PADM figure not found. Initializing...');
            handleStruct = plotPADM(dataStruct, opsPlot, 'init');
            figHandle = handleStruct.figHandle;
        else
            figHandle = figHandle(1);
            handleStruct = getappdata(figHandle, 'plotHandles');
        end
        
        % Increment subplot count
        handleStruct.subplotCount = handleStruct.subplotCount + 1;
        n = handleStruct.subplotCount;
        
        % Adjust figure height dynamically
        pos = get(figHandle, 'Position');
        set(figHandle, 'Position', [pos(1), pos(2), pos(3), 150 * n]);
        
        % Create new subplot
        ax = subplot(n, 1, n);
        hold on;
        
        % Plot objective or residual
        if isfield(dataStruct, 'objective')
            plot(dataStruct.iteration, dataStruct.objective, 'b-o', 'LineWidth', 1, 'MarkerSize', 4);
            ylabel('Objective', 'FontName', 'Times New Roman', 'FontSize', 12);
        elseif isfield(dataStruct, 'residual')
            plot(dataStruct.iteration, dataStruct.residual, 'r-s', 'LineWidth', 1, 'MarkerSize', 4);
            ylabel('Residual', 'FontName', 'Times New Roman', 'FontSize', 12);
        end
        
        xlabel('Iteration', 'FontName', 'Times New Roman', 'FontSize', 12);
        title(sprintf('R&D Iteration %d', n), 'FontName', 'Times New Roman', 'FontSize', 12);
        set(gca, 'FontName', 'Times New Roman', 'FontSize', 12);
        grid on;
        box on;
        set(gca, 'LineWidth', 0.75);
        
        % Store subplot handle
        handleStruct.subplotHandles = [handleStruct.subplotHandles; ax];
        setappdata(figHandle, 'plotHandles', handleStruct);
        
        drawnow;
        
    % --- Stage: Final ---
    elseif strcmp(callStage, 'final')
        % Retrieve figure
        figHandle = findobj('Type', 'figure', 'Name', 'L1-PADM Convergence');
        if isempty(figHandle)
            return;
        end
        figHandle = figHandle(1);
        handleStruct = getappdata(figHandle, 'plotHandles');
        
        % Save figure
        if opsPlot.saveFig
            if ~isfield(opsPlot, 'saveDir')
                opsPlot.saveDir = 'results/figures/';
            end
            if ~exist(opsPlot.saveDir, 'dir')
                mkdir(opsPlot.saveDir);
            end
            
            timestamp = datestr(now, 'yyyymmdd_HHMMSS');
            baseFilename = sprintf('PADM_%s_convergence', timestamp);
            
            for i = 1:length(opsPlot.figFormat)
                fmt = opsPlot.figFormat{i};
                fullPath = fullfile(opsPlot.saveDir, [baseFilename, '.', fmt]);
                
                % Handle different format types
                if strcmpi(fmt, 'fig')
                    savefig(figHandle, fullPath);
                else
                    if exist('exportgraphics', 'file')
                        exportgraphics(figHandle, fullPath, 'Resolution', 300);
                    else
                        saveas(figHandle, fullPath);
                    end
                end
            end
            fprintf('PADM figure saved to: %s\n', opsPlot.saveDir);
        end
    end
end

