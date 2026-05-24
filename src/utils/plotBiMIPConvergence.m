function fig = plotBiMIPConvergence(BiMIP_record, varargin)
%PLOTBIMIPCONVERGENCE Plot outer R&D/C&CG UB, LB, and gap history.
%
%   fig = plotBiMIPConvergence(BiMIP_record, 'SavePath', path)

p = inputParser;
addParameter(p, 'SavePath', '');
addParameter(p, 'Title', '');
addParameter(p, 'Visible', 'off');
parse(p, varargin{:});
params = p.Results;

[x, UB, LB, gap_pct] = local_outer_series(BiMIP_record);
if isempty(x)
    error('PowerBiMIP:PlotConvergence', 'BiMIP_record does not contain plottable UB/LB/gap data.');
end

fig = figure('Color', 'w', 'Visible', params.Visible, ...
    'Name', local_figure_name('BiMIP convergence', params.Title), ...
    'NumberTitle', 'off', ...
    'Units', 'pixels', 'Position', [100, 100, 560, 210]);
ax = axes(fig);
hold(ax, 'on');

yyaxis(ax, 'left');
hLB = plot(ax, x, LB, '^-', 'Color', [0.10, 0.25, 0.85], ...
    'MarkerFaceColor', 'w', 'LineWidth', 1.25, 'MarkerSize', 5, ...
    'DisplayName', '\fontname{Times New Roman}LB');
hUB = plot(ax, x, UB, 's-', 'Color', [0.85, 0.10, 0.10], ...
    'MarkerFaceColor', 'w', 'LineWidth', 1.25, 'MarkerSize', 5, ...
    'DisplayName', '\fontname{Times New Roman}UB');
ylabel(ax, '\fontname{SimSun}目标函数值', 'Interpreter', 'tex');
ylim(ax, local_axis_limits([UB(:); LB(:)]));
ax.YColor = [0, 0, 0];

yyaxis(ax, 'right');
hGap = plot(ax, x, gap_pct, 'o--', 'Color', [0, 0, 0], ...
    'MarkerFaceColor', 'w', 'LineWidth', 1.1, 'MarkerSize', 5, ...
    'DisplayName', '\fontname{Times New Roman}Gap (%)');
ylabel(ax, '\fontname{Times New Roman}Gap (%)', 'Interpreter', 'tex');
ax.YColor = [0, 0, 0];

xlabel(ax, '\fontname{Times New Roman}R&D\fontname{SimSun}迭代次数', ...
    'Interpreter', 'tex');
grid(ax, 'on');
box(ax, 'on');
set(ax, 'FontName', 'Times New Roman', 'FontSize', 10, ...
    'LineWidth', 0.75, 'GridColor', [0.82, 0.82, 0.82], ...
    'GridAlpha', 0.35, 'XLim', [min(x), max(x) + isscalar(x)]);
lgd = legend(ax, [hLB, hUB, hGap], 'Location', 'best', 'Box', 'on');
lgd.Interpreter = 'tex';
lgd.FontName = 'Times New Roman';

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

function [x, UB, LB, gap_pct] = local_outer_series(record)
UB = [];
LB = [];
gap_pct = [];
if isfield(record, 'UB') && isfield(record, 'LB')
    UB_raw = record.UB(:);
    LB_raw = record.LB(:);
    n = min([max(numel(UB_raw) - 1, 0), max(numel(LB_raw) - 1, 0)]);
    if n > 0
        UB = UB_raw(2:n+1);
        LB = LB_raw(2:n+1);
        gap_pct = local_bounded_gap_pct(LB, UB);
    else
        n = min([numel(UB_raw), numel(LB_raw)]);
        if n > 0
            UB = UB_raw(1:n);
            LB = LB_raw(1:n);
            gap_pct = local_bounded_gap_pct(LB, UB);
        end
    end
end
x = 1:numel(UB);
finite_gap = isfinite(gap_pct);
if any(~finite_gap)
    gap_pct(~finite_gap) = NaN;
end
end

function gap_pct = local_bounded_gap_pct(LB, UB)
width = max(0, UB - LB);
denominator = max(abs(LB) + abs(UB), 1e-9);
gap_pct = 100 * width ./ denominator;
gap_pct(~isfinite(gap_pct)) = NaN;
end

function name = local_figure_name(default_name, requested_name)
if isempty(requested_name)
    name = default_name;
else
    name = requested_name;
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
