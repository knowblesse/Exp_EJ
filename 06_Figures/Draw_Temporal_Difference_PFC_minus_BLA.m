% Draw_Temporal_Difference_PFC_minus_BLA

% PFC minus BLA decoding accuracy difference across time windows.
% Paired difference per session, mean + SEM band, with Sidak-corrected stars.

%% Inputs
PARENT_PATH = 'H:\Data\Kim Data\PreRobotNP_PreRobotP';
BLA_CSV = fullfile(PARENT_PATH, 'temporal_BLA.csv');
PFC_CSV = fullfile(PARENT_PATH, 'temporal_PFC.csv');

%% Title
PLOT_TITLE = 'PFC − BLA';

%% Style
COLOR_DIFF = '#7B2D8E';     % purple

DRAW_SHADE  = true;
ALPHA_SHADE = 0.25;
LW_MEAN     = 2.5;
DOT_SIZE    = 5;

AXIS_LW     = 1.44;
FONT_NAME   = 'Arial';
FONT_SIZE   = 12;
FONT_WEIGHT = 'bold';

TITLE_SIZE  = 13.92;

STAR_FONT   = 'Arial';
STAR_SIZE   = 14;
STAR_OFFSET = 0.008;        % vertical offset above the mean dot, in data units
                            % smaller than original (0.015) since y-range is now 0.35

% Sizes — figure shrinks to the plotting block (no legend area)
TOTAL_WIDTH_MM   = 90;          % was 130.04 with legend; ~40mm saved
TOTAL_HEIGHT_MM  = 80.741;      % unchanged
AXES_WIDTH_MM    = 76;
AXES_HEIGHT_MM   = 51;

%% Time windows
TIME_WINDOWS = [-7 -3; -6 -2; -5 -1; -4 0; -3 1; -2 2; -1 3; 0 4; 1 5; 2 6];
n_win = size(TIME_WINDOWS, 1);
x = 1:n_win;
xtick_labels = arrayfun(@(i) sprintf('%d ~ %d', TIME_WINDOWS(i,1), TIME_WINDOWS(i,2)), ...
                        1:n_win, 'UniformOutput', false);

%% Load data
bla_T = readtable(BLA_CSV);
pfc_T = readtable(PFC_CSV);
n_bla = height(bla_T);
n_pfc = height(pfc_T);

if n_bla ~= n_pfc
    error('BLA and PFC tables have different numbers of sessions (%d vs %d)', n_bla, n_pfc);
end
n_sess = n_bla;

bla_real = zeros(n_sess, n_win);
pfc_real = zeros(n_sess, n_win);

bla_vars = bla_T.Properties.VariableNames;
pfc_vars = pfc_T.Properties.VariableNames;
norm_name = @(s) regexprep(s, '[^A-Za-z0-9]', '');

for j = 1:n_win
    t0 = TIME_WINDOWS(j,1); t1 = TIME_WINDOWS(j,2);
    target_real = norm_name(sprintf('T(%d,%d)_Real', t0, t1));

    bla_norm = cellfun(norm_name, bla_vars, 'UniformOutput', false);
    pfc_norm = cellfun(norm_name, pfc_vars, 'UniformOutput', false);

    bla_real(:,j) = bla_T.(bla_vars{strcmp(bla_norm, target_real)});
    pfc_real(:,j) = pfc_T.(pfc_vars{strcmp(pfc_norm, target_real)});
end

% Paired difference per session, per window
diff_mat = pfc_real - bla_real;   % sessions x windows

%% Per-window paired t-tests with Sidak correction
p_raw = zeros(1, n_win);
for j = 1:n_win
    [~, p_raw(j)] = ttest(pfc_real(:,j), bla_real(:,j));   % paired t-test
end

% % Sidak correction: p_corr = 1 - (1 - p)^m
% p_sidak = 1 - (1 - p_raw).^n_win;
% p_corr = min(p_sidak, 1);  % clip to [0,1]
 
% % Bonferroni
% p_corr = p_raw * n_win;
% p_corr = min(p_corr, 1);

% Sort p-values, apply BH adjustment, then enforce monotonicity
[p_sorted, sort_idx] = sort(p_raw);
ranks = 1:n_win;
p_bh_sorted = p_sorted .* n_win ./ ranks;

% Enforce monotonicity from largest to smallest
for k = n_win-1:-1:1
    p_bh_sorted(k) = min(p_bh_sorted(k), p_bh_sorted(k+1));
end
% Unsort back to original window order
p_corr = zeros(1, n_win);
p_corr(sort_idx) = p_bh_sorted;
p_corr = min(p_corr, 1);

% Convert corrected p-values to star counts
STARS = zeros(1, n_win);
STARS(p_corr < 0.05)  = 1;
STARS(p_corr < 0.01)  = 2;
STARS(p_corr < 0.001) = 3;

% Print to console for sanity check
fprintf('Window         raw p     Corr p   stars\n');
for j = 1:n_win
    fprintf('(%2d,%2d):    %8.4f   %8.4f    %s\n', ...
        TIME_WINDOWS(j,1), TIME_WINDOWS(j,2), ...
        p_raw(j), p_corr(j), repmat('*', 1, STARS(j)));
end

%% Plot
clf;
ax = axes(gcf);
ax.Color = 'none';
hold(ax, 'on');

% Reference line at zero
yline(ax, 0, '-', 'Color', [0 0 0], 'LineWidth', 0.6, 'Alpha', 0.5, 'HandleVisibility', 'off');

% PFC - BLA — thick line + SEM band
[~, h_diff, ~] = shadeplot(x, diff_mat, ...
    'SD', 'sem', 'Color', COLOR_DIFF, 'LineStyle', '-', ...
    'LineWidth', LW_MEAN, 'FaceColor', COLOR_DIFF, ...
    'FaceAlpha', ALPHA_SHADE * DRAW_SHADE, 'ax', ax);

diff_mean = mean(diff_mat, 1);
plot(ax, x, diff_mean, 'd', 'Color', COLOR_DIFF, ...
    'MarkerFaceColor', COLOR_DIFF, 'MarkerSize', DOT_SIZE, 'HandleVisibility', 'off');

% Significance stars above the mean dots
for j = 1:n_win
    if STARS(j) > 0
        text(ax, x(j), diff_mean(j) + STAR_OFFSET, repmat('*', 1, STARS(j)), ...
            'FontName', STAR_FONT, 'FontSize', STAR_SIZE, 'FontWeight', 'bold', ...
            'Color', COLOR_DIFF, 'HorizontalAlignment', 'center', ...
            'VerticalAlignment', 'bottom');
    end
end

% Axes — fonts, thickness, tick direction
ax.LineWidth   = AXIS_LW;
ax.FontName    = FONT_NAME;
ax.FontSize    = FONT_SIZE;
ax.FontWeight  = FONT_WEIGHT;
ax.TickDir     = 'out';
ax.TickDirMode = 'manual';

xlabel(ax, 'Time window (s, relative to event)', ...
    'FontName', FONT_NAME, 'FontSize', FONT_SIZE, 'FontWeight', FONT_WEIGHT);
ylabel(ax, 'Δ Balanced Accuracy (PFC − BLA)', ...
    'FontName', FONT_NAME, 'FontSize', FONT_SIZE, 'FontWeight', FONT_WEIGHT);
xticks(ax, x);
xticklabels(ax, xtick_labels);
xlim(ax, [0.5 n_win+0.5]);
ax.XTickLabelRotation = 45;
ax.Box = 'off';

% Title
title(ax, PLOT_TITLE, 'FontName', FONT_NAME, 'FontSize', TITLE_SIZE, 'FontWeight', 'bold');

% Y-axis: -0.10 to 0.25, 0.05 spacing
ylim(ax, [-0.10, 0.25]);
yticks(ax, -0.10:0.05:0.25);

hold(ax, 'off');

%% Set exact figure size
fig = gcf;
fig.Units = 'centimeters';
fig.Position = [fig.Position(1) fig.Position(2) TOTAL_WIDTH_MM/10 TOTAL_HEIGHT_MM/10];

fig.PaperUnits        = 'centimeters';
fig.PaperPosition     = [0 0 TOTAL_WIDTH_MM/10 TOTAL_HEIGHT_MM/10];
fig.PaperSize         = [TOTAL_WIDTH_MM/10 TOTAL_HEIGHT_MM/10];
fig.PaperPositionMode = 'manual';

ax.Units = 'centimeters';
left_margin   = 1.4;
bottom_margin = 1.6;
ax.Position = [left_margin bottom_margin AXES_WIDTH_MM/10 AXES_HEIGHT_MM/10];

%% Export to vector format for Illustrator
EXPORT_PATH = fullfile(PARENT_PATH, 'decoding_temporal_diff.svg');
exportgraphics(fig, EXPORT_PATH, 'ContentType', 'vector');