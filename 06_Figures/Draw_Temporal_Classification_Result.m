% Draw_Temporal_Classification_Result

% Plot temporal decoding accuracy across windows for BLA and PFC.
% Each region: per-session traces (thin) + group mean (thick) + optional SEM band.
% Random condition shown as two gray lines (one per region).

%% Inputs
PARENT_PATH = 'H:\Data\Kim Data\robot_iti_iti_2s';
BLA_CSV = fullfile(PARENT_PATH, 'temporal_BLA.csv');
PFC_CSV = fullfile(PARENT_PATH, 'temporal_PFC.csv');

%% Title
PLOT_TITLE = 'Pellet Type (robot) ITI';

%% Style
COLOR_BLA_REAL = '#E783B2';     % red
COLOR_PFC_REAL = '#7AA6A6';     % green
COLOR_BLA_RAND = '#999999';     % gray
COLOR_PFC_RAND = '#666666';     % darker gray

DRAW_SHADE  = true;             % toggle SEM band on/off
ALPHA_SHADE = 0.25;
ALPHA_INDIV = 0.1;
LW_MEAN     = 2.5;
LW_INDIV    = 0.6;
LW_RAND     = 1.8;
DOT_SIZE    = 5;                % mean dot size (MarkerSize, points)

AXIS_LW     = 1.44;             % axis line thickness (pt)
FONT_NAME   = 'Arial';
FONT_SIZE   = 12;
FONT_WEIGHT = 'normal';

TITLE_SIZE  = 13.92;            % title size (pt), Arial Bold

STAR_FONT   = 'Arial';
STAR_SIZE   = 14;
STAR_OFFSET = 0.015;            % vertical offset above the mean dot, in data units

% Sizes
AXES_WIDTH_MM   = 90.495;       % plotting area width
AXES_HEIGHT_MM  = 80.741;       % plotting area height
FIG_WIDTH_MM    = 130.91;       % figure width (axes + legend)

%% Significance stars per window (length must equal number of windows)
% 0 = no star, 1 = '*', 2 = '**', 3 = '***'
% STARS_BLA = [0 1 1 2 3 3 3 3 3 3];
% STARS_PFC = [0 0 0 2 2 3 3 3 3 3];
%STARS_BLA = [0 0 0 0 3 2 3 3];
%STARS_PFC = [0 0 1 2 3 3 3 3];
STARS_BLA = [0 0 0 0 3 2 2 3 0 0];
STARS_PFC = [0 0 0 1 3 3 2 1 2 2];
%% Time windows
%TIME_WINDOWS = [-7 -3; -6 -2; -5 -1; -4 0; -3 1; -2 2; -1 3; 0 4; 1 5; 2 6];
%TIME_WINDOWS = [-8 -6; -6 -4; -4 -2; -2 0; 0 2; 2 4; 4 6; 6 8];
TIME_WINDOWS = [-8 -6; -6 -4; -4 -2; -2 0; 0 2; 2 4; 4 6; 6 8; 8 10; 10 12];
n_win = size(TIME_WINDOWS, 1);
x = 1:n_win;
% xtick_labels = arrayfun(@(i) sprintf('%d ~ %d', TIME_WINDOWS(i,1), TIME_WINDOWS(i,2)), ...
%                         1:n_win, 'UniformOutput', false);
xtick_labels = arrayfun(@(i) sprintf('%d', (TIME_WINDOWS(i,2) + TIME_WINDOWS(i,1))/2), ...
                        1:n_win, 'UniformOutput', false);
%% Load data
bla_T = readtable(BLA_CSV);
pfc_T = readtable(PFC_CSV);
n_bla = height(bla_T);
n_pfc = height(pfc_T);

bla_real = zeros(n_bla, n_win);
bla_rand = zeros(n_bla, n_win);
pfc_real = zeros(n_pfc, n_win);
pfc_rand = zeros(n_pfc, n_win);

% readtable mangles column names like "T(-7,-3)_Real" -> "T__7__3__Real" etc.
% Match by stripping non-alphanumerics in both header and target name.
bla_vars = bla_T.Properties.VariableNames;
pfc_vars = pfc_T.Properties.VariableNames;
norm_name = @(s) regexprep(s, '[^A-Za-z0-9]', '');

for j = 1:n_win
    t0 = TIME_WINDOWS(j,1); t1 = TIME_WINDOWS(j,2);
    target_real = norm_name(sprintf('T(%d,%d)_Real',   t0, t1));
    target_rand = norm_name(sprintf('T(%d,%d)_Random', t0, t1));

    bla_norm = cellfun(norm_name, bla_vars, 'UniformOutput', false);
    pfc_norm = cellfun(norm_name, pfc_vars, 'UniformOutput', false);

    bla_real(:,j) = bla_T.(bla_vars{strcmp(bla_norm, target_real)});
    bla_rand(:,j) = bla_T.(bla_vars{strcmp(bla_norm, target_rand)});
    pfc_real(:,j) = pfc_T.(pfc_vars{strcmp(pfc_norm, target_real)});
    pfc_rand(:,j) = pfc_T.(pfc_vars{strcmp(pfc_norm, target_rand)});
end

%% Plot
clf;
ax = axes(gcf);
ax.Color = 'none';
hold(ax, 'on');

% Per-session thin traces (drawn first so they sit behind everything)
% for i = 1:n_bla
%     p = plot(ax, x, bla_real(i,:), 'Color', COLOR_BLA_REAL, 'LineWidth', LW_INDIV);
%     p.Color(4) = ALPHA_INDIV;  % alpha via 4th channel
% end
% for i = 1:n_pfc
%     p = plot(ax, x, pfc_real(i,:), 'Color', COLOR_PFC_REAL, 'LineWidth', LW_INDIV);
%     p.Color(4) = ALPHA_INDIV;
% end

% BLA Random — gray dashed
sem = std(bla_rand, 0, 1) ./ sqrt(n_bla);
[~, h_bla_rand, ~] = shadeplot(x, bla_rand, ...
    'SD', 'sem', 'Color', COLOR_BLA_RAND, 'LineStyle', '--', ...
    'LineWidth', LW_RAND, 'FaceColor', COLOR_BLA_RAND, ...
    'FaceAlpha', ALPHA_SHADE * DRAW_SHADE, 'ax', ax);

% PFC Random — darker gray dotted
[~, h_pfc_rand, ~] = shadeplot(x, pfc_rand, ...
    'SD', 'sem', 'Color', COLOR_PFC_RAND, 'LineStyle', ':', ...
    'LineWidth', LW_RAND, 'FaceColor', COLOR_PFC_RAND, ...
    'FaceAlpha', ALPHA_SHADE * DRAW_SHADE, 'ax', ax);

% BLA Real — thick line + SEM band
[~, h_bla_real, ~] = shadeplot(x, bla_real, ...
    'SD', 'sem', 'Color', COLOR_BLA_REAL, 'LineStyle', '-', ...
    'LineWidth', LW_MEAN, 'FaceColor', COLOR_BLA_REAL, ...
    'FaceAlpha', ALPHA_SHADE * DRAW_SHADE, 'ax', ax);
% Add markers on the mean line
bla_mean = mean(bla_real, 1);
plot(ax, x, bla_mean, 'o', 'Color', COLOR_BLA_REAL, ...
    'MarkerFaceColor', COLOR_BLA_REAL, 'MarkerSize', DOT_SIZE, 'HandleVisibility', 'off');

% PFC Real — thick line + SEM band
[~, h_pfc_real, ~] = shadeplot(x, pfc_real, ...
    'SD', 'sem', 'Color', COLOR_PFC_REAL, 'LineStyle', '-', ...
    'LineWidth', LW_MEAN, 'FaceColor', COLOR_PFC_REAL, ...
    'FaceAlpha', ALPHA_SHADE * DRAW_SHADE, 'ax', ax);
pfc_mean = mean(pfc_real, 1);
plot(ax, x, pfc_mean, 's', 'Color', COLOR_PFC_REAL, ...
    'MarkerFaceColor', COLOR_PFC_REAL, 'MarkerSize', DOT_SIZE, 'HandleVisibility', 'off');

% Significance stars above the mean dots
for j = 1:n_win
    if STARS_BLA(j) > 0
        text(ax, x(j), bla_mean(j) + STAR_OFFSET, repmat('*', 1, STARS_BLA(j)), ...
            'FontName', STAR_FONT, 'FontSize', STAR_SIZE, 'FontWeight', 'bold', ...
            'Color', COLOR_BLA_REAL, 'HorizontalAlignment', 'center', ...
            'VerticalAlignment', 'bottom');
    end
    if STARS_PFC(j) > 0
        text(ax, x(j), pfc_mean(j) + STAR_OFFSET, repmat('*', 1, STARS_PFC(j)), ...
            'FontName', STAR_FONT, 'FontSize', STAR_SIZE, 'FontWeight', 'bold', ...
            'Color', COLOR_PFC_REAL, 'HorizontalAlignment', 'center', ...
            'VerticalAlignment', 'bottom');
    end
end

% Reference line at chance
yline(ax, 0.5, ':', 'Color', [0 0 0], 'LineWidth', 0.6, 'Alpha', 0.5, 'HandleVisibility','off');

% Axes — fonts, thickness, tick direction
ax.LineWidth   = AXIS_LW;
ax.FontName    = FONT_NAME;
ax.FontSize    = FONT_SIZE;
ax.FontWeight  = FONT_WEIGHT;
ax.TickDir     = 'out';
ax.TickDirMode = 'manual';

xlabel(ax, 'Time window (s, relative to event)', ...
    'FontName', FONT_NAME, 'FontSize', FONT_SIZE, 'FontWeight', FONT_WEIGHT);
ylabel(ax, 'Balanced Accuracy', ...
    'FontName', FONT_NAME, 'FontSize', FONT_SIZE, 'FontWeight', FONT_WEIGHT);
xticks(ax, x);
xticklabels(ax, xtick_labels);
xlim(ax, [0.5 n_win+0.5]);
%ax.XTickLabelRotation = 45;
ax.Box = 'off';

% Title
title(ax, PLOT_TITLE, 'FontName', FONT_NAME, 'FontSize', TITLE_SIZE, 'FontWeight', 'normal');

% Y-axis: 0.1 spacing
ylim(ax, [0.4, 0.9]);
yticks(ax, 0.4:0.1:0.9);
xline(4.5, 'Color', 'r', 'LineStyle', '--')
legend(ax, [h_bla_rand, h_pfc_rand, h_bla_real, h_pfc_real], ...
    {'BLA Random', 'PFC Random', 'BLA Real', 'PFC Real'}, ...
    'Location', 'eastoutside', 'Box', 'off', ...
    'FontName', FONT_NAME, 'FontSize', FONT_SIZE, 'FontWeight', 'normal');

hold(ax, 'off');

%% Set exact figure size (matches Illustrator placeholder)
TOTAL_WIDTH_MM  = 130.04;
TOTAL_HEIGHT_MM = 80.741;
AXES_WIDTH_MM   = 76;        % approximate — x-axis length
AXES_HEIGHT_MM  = 51;        % approximate — y-axis length

fig = gcf;
fig.Units = 'centimeters';
fig.Position = [fig.Position(1) fig.Position(2) TOTAL_WIDTH_MM/10 TOTAL_HEIGHT_MM/10];

% Pin the paper size for vector export (so the SVG/PDF has the exact same dimensions)
fig.PaperUnits      = 'centimeters';
fig.PaperPosition   = [0 0 TOTAL_WIDTH_MM/10 TOTAL_HEIGHT_MM/10];
fig.PaperSize       = [TOTAL_WIDTH_MM/10 TOTAL_HEIGHT_MM/10];
fig.PaperPositionMode = 'manual';

% Set axes size (centered horizontally with room for legend on the right)
ax.Units = 'centimeters';
% Position: [left bottom width height] — leave space at left for ylabel,
% bottom for xlabel + tick labels, right for legend, top for title
left_margin   = 1.4;   % cm — room for ylabel + y-tick labels
bottom_margin = 1.6;   % cm — room for x-tick labels (rotated) + xlabel
ax.Position = [left_margin bottom_margin AXES_WIDTH_MM/10 AXES_HEIGHT_MM/10];

%% Export to vector format for Illustrator
EXPORT_PATH = fullfile(PARENT_PATH, 'decoding_temporal.svg');
exportgraphics(fig, EXPORT_PATH, 'ContentType', 'vector');