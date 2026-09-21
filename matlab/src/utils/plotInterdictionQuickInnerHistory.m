function fig = plotInterdictionQuickInnerHistory(quick_history, varargin)
%PLOTINTERDICTIONQUICKINNERHISTORY Plot quick penalty alternating history.
%
%   fig = plotInterdictionQuickInnerHistory(history, 'SavePath', path)

p = inputParser;
addParameter(p, 'SavePath', '');
addParameter(p, 'Title', '');
addParameter(p, 'Visible', 'off');
parse(p, varargin{:});
params = p.Results;

[x, step_a_obj, step_b_obj, gap_pct] = local_history_series(quick_history);
if isempty(x)
    error('PowerBiMIP:PlotQuickHistory', 'quick_history is empty or missing plottable fields.');
end

fig = figure('Color', 'w', 'Visible', params.Visible, ...
    'Name', local_figure_name('Interdiction quick inner history', params.Title), ...
    'NumberTitle', 'off', ...
    'Units', 'pixels', 'Position', [100, 100, 620, 220]);
ax = axes(fig);
hold(ax, 'on');

yyaxis(ax, 'right');
hGap = plot(ax, x, gap_pct, 'o:', 'Color', [0.45, 0.45, 0.45], ...
    'MarkerFaceColor', 'w', 'LineWidth', 0.8, 'MarkerSize', 4, ...
    'DisplayName', '\fontname{Times New Roman}Gap (%)');
ylabel(ax, '\fontname{Times New Roman}Gap (%)', 'Interpreter', 'tex');
ax.YColor = [0, 0, 0];

yyaxis(ax, 'left');
hB = plot(ax, x, step_b_obj, '^-', 'Color', [0.10, 0.25, 0.85], ...
    'MarkerFaceColor', 'w', 'LineWidth', 1.25, 'MarkerSize', 5, ...
    'DisplayName', '\fontname{SimSun}子问题\fontname{Times New Roman}2');
hA = plot(ax, x, step_a_obj, 's-', 'Color', [0.85, 0.10, 0.10], ...
    'MarkerFaceColor', 'w', 'LineWidth', 1.45, 'MarkerSize', 6, ...
    'DisplayName', '\fontname{SimSun}子问题\fontname{Times New Roman}1');
ylabel(ax, '\fontname{SimSun}目标函数值', 'Interpreter', 'tex');
ylim(ax, local_axis_limits([step_a_obj(:); step_b_obj(:)]));
ax.YColor = [0, 0, 0];

xlabel(ax, '\fontname{Times New Roman}PADM\fontname{SimSun}迭代次数', ...
    'Interpreter', 'tex');
grid(ax, 'on');
box(ax, 'on');
set(ax, 'FontName', 'Times New Roman', 'FontSize', 10, ...
    'LineWidth', 0.75, 'GridColor', [0.82, 0.82, 0.82], ...
    'GridAlpha', 0.35, 'XLim', [min(x), max(x) + isscalar(x)]);
lgd = legend(ax, [hA, hB, hGap], 'Location', 'best', 'Box', 'on');
lgd.Interpreter = 'tex';

if ~isempty(params.SavePath)
    local_save_figure(fig, params.SavePath);
end

function limits = local_axis_limits(values)
values = values(isfinite(values));
if isempty(values)
    limits = [0, 1];
    return;
end
lo = min(values);
hi = max(values);
span = hi - lo;
scale = max(1, max(abs(values)));
if span < 1e-6 * scale
    pad = max(1, 0.05 * scale);
else
    pad = 0.08 * span;
end
limits = [lo - pad, hi + pad];
end
end

function [x, step_a_obj, step_b_obj, gap_pct] = local_history_series(history)
x = [];
step_a_obj = [];
step_b_obj = [];
gap_pct = [];
if isempty(history)
    return;
end

n = numel(history);
if isfield(history, 'iteration')
    x = [history.iteration];
else
    x = 1:n;
end

if isfield(history, 'step_a_core_objective')
    step_a_obj = [history.step_a_core_objective];
elseif isfield(history, 'step_a_eta')
    step_a_obj = [history.step_a_eta];
elseif isfield(history, 'core_objective')
    step_a_obj = [history.core_objective];
elseif isfield(history, 'objective')
    step_a_obj = [history.objective];
end

if isfield(history, 'step_b_core_objective')
    step_b_obj = [history.step_b_core_objective];
elseif isfield(history, 'core_objective')
    step_b_obj = [history.core_objective];
elseif isfield(history, 'objective')
    step_b_obj = [history.objective];
end

step_a_obj = local_pad_to_length(step_a_obj, n);
step_b_obj = local_pad_to_length(step_b_obj, n);
gap_pct = local_objective_gap_pct(step_a_obj, step_b_obj);
x = local_pad_to_length(x, n);
end

function gap_pct = local_objective_gap_pct(step_a_obj, step_b_obj)
denominator = max(abs(step_a_obj), abs(step_b_obj));
gap_pct = 100 * abs(step_b_obj - step_a_obj) ./ max(denominator, 1e-9);
gap_pct(~isfinite(gap_pct)) = NaN;
end

function out = local_pad_to_length(in, n)
out = in(:).';
if numel(out) < n
    out(end+1:n) = NaN;
elseif numel(out) > n
    out = out(1:n);
end
end

function local_save_figure(fig, save_path)
[folder, ~, ext] = fileparts(save_path);
if isempty(ext)
    save_path = [save_path, '.png'];
    ext = '.png';
end
if ~isempty(folder) && ~exist(folder, 'dir')
    mkdir(folder);
end
if exist('exportgraphics', 'file') && any(strcmpi(ext, {'.png', '.pdf', '.eps', '.tif', '.tiff'}))
    exportgraphics(fig, save_path, 'Resolution', 300);
else
    saveas(fig, save_path);
end
end

function name = local_figure_name(default_name, requested_name)
if isempty(requested_name)
    name = default_name;
else
    name = requested_name;
end
end
