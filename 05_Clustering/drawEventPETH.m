function drawEventPETH(sessionName, targetUnitFile, targetUnit, eventType)
%% drawEventPETH
% Draw PETH for a specific unit with three panels:
%   Top: Mean convolved activity (z-scored)
%   Middle: Raster plot
%   Bottom: PSTH histogram
%
% Inputs:
%   sessionName    - string, e.g. '@AP18_031218'
%   targetUnitFile - string, e.g. 'BLA_TT01.ntt'
%   targetUnit     - scalar, unit ID (CellNumber) from NTT file
%   eventType      - 1=PreRobot NP, 2=PreRobot P, 3=Robot NP, 4=Robot P

%% Parameters
BASEPATH = "H:\Data\Kim Data";
timewindow_bin = 50;    % msec
kernel_size = 1000;
kernel_std = 100;
HISTOGRAM_WIDTH = 50;   % msec
timewindow = [-10000, 10000]; % -10 to +10 sec around event
windowSize = diff(timewindow);
binnedDataSize = windowSize / timewindow_bin;
halfWindow = windowSize / 2;
relativeRange = [-halfWindow, halfWindow];
eventNames = ["Pre-robot NP", "Pre-robot P", "Robot NP", "Robot P"];

%% Get tank path
tankPath = fullfile(BASEPATH, sessionName);
tankName = sessionName(2:end);

%% Get unit file Paths
unitFilePaths = glob(tankPath, '\.(N|n)(T|t)(T|t)', true);

%% Load helper file
load(fullfile(tankPath, strcat(tankName, '_helper.mat')));
if ~all([exist('expStat', 'var'), exist('time2TS', 'var'), exist('time2TS_filename', 'var')])
    error("Helper file not loaded properly")
end

%% Load event file
eventFilePath = fullfile(tankPath, strcat(tankName, '_event.mat'));
load(eventFilePath);

%% Define event times
eventTime_PR_NP = double(eventDataRaw.Time_ms(eventDataRaw.Robot == 0 & eventDataRaw.PelletType == "NP"));
eventTime_PR_P = double(eventDataRaw.Time_ms(eventDataRaw.Robot == 0 & eventDataRaw.PelletType == "P"));
eventTime_R_NP = double(eventDataRaw.Time_ms(eventDataRaw.Robot == 1 & eventDataRaw.PelletType == "NP"));
eventTime_R_P = double(eventDataRaw.Time_ms(eventDataRaw.Robot == 1 & eventDataRaw.PelletType == "P"));

allEventTimes = {eventTime_PR_NP, eventTime_PR_P, eventTime_R_NP, eventTime_R_P};
selectedEventTimes = allEventTimes{eventType};
nEvents = numel(selectedEventTimes);

if nEvents == 0
    error('No events found for event type %d (%s)', eventType, eventNames(eventType));
end

%% Generate gaussian kernel
kernel = gausswin(ceil(kernel_size/2)*2-1, (kernel_size - 1) / (2 * kernel_std));

%% Find target unit and load its spikes
unitFound = false;
allSpikes_ms = [];

for unitFilePath = unitFilePaths
    % Check if this is the target file
    if ~contains(unitFilePath{1}, targetUnitFile)
        continue;
    end

    [Timestamps, ~, CellNumbers, ~, ~] = Nlx2MatSpike(...
        unitFilePath{1}, [1, 1, 1, 1, 1], 0, 1);

    if ismember(targetUnit, unique(CellNumbers))
        temp_ = Timestamps(CellNumbers == targetUnit)';
        temp_ = (temp_ - expStat.startTS) / 1000;
        temp_ = temp_(temp_ > 0);
        allSpikes_ms = temp_;
        unitFound = true;
        break;
    end
end

if ~unitFound
    error('Unit %d not found in file %s, session %s', targetUnit, targetUnitFile, sessionName);
end

%% Build full serial data, convolve, z-score
serial_data = zeros(max(round(allSpikes_ms(end)), ...
    max([eventTime_PR_NP(end), eventTime_PR_P(end), ...
         eventTime_R_NP(end), eventTime_R_P(end)]) + 10000), 1);
serial_data(round(allSpikes_ms)) = 1;

serial_data_kerneled = conv(serial_data, kernel, 'same');
serial_data_mean = mean(serial_data_kerneled);
serial_data_std = std(serial_data_kerneled);
if serial_data_std == 0; serial_data_std = 1; end
whole_serial_data = (serial_data_kerneled - serial_data_mean) ./ serial_data_std;

%% Extract data for each event
binnedData = zeros(nEvents, binnedDataSize);
rasterSpikes = cell(nEvents, 1);

for e = 1:nEvents
    signal_window = round(timewindow + selectedEventTimes(e));

    % Bounds check
    if signal_window(1) < 1 || signal_window(2) > numel(whole_serial_data)
        warning('Event %d out of range. Skipping.', e);
        continue;
    end

    % Binned convolved activity
    snippet = whole_serial_data(signal_window(1)+1 : signal_window(2));
    binnedData(e, :) = mean(reshape(snippet, timewindow_bin, []), 1);

    % Spike times relative to event onset (time 0)
    eventSpikes = allSpikes_ms(allSpikes_ms >= signal_window(1) & allSpikes_ms < signal_window(2));
    rasterSpikes{e} = eventSpikes - selectedEventTimes(e);
end

%% Time axes
binCenters = linspace(relativeRange(1) + timewindow_bin/2, ...
                      relativeRange(2) - timewindow_bin/2, ...
                      binnedDataSize);

%% Draw figure
fig = figure('Position', [300, 200, 500, 700]);

% === Top panel: Mean convolved activity ===
ax1 = subplot(3, 1, 1);
hold on;
meanActivity = mean(binnedData, 1);
semActivity = std(binnedData, 0, 1) / sqrt(nEvents);

fill([binCenters, fliplr(binCenters)], ...
     [meanActivity + semActivity, fliplr(meanActivity - semActivity)], ...
     [0.7, 0.7, 1.0], 'EdgeColor', 'none', 'FaceAlpha', 0.4);
plot(binCenters, meanActivity, 'b', 'LineWidth', 1.5);
line([0, 0], ylim, 'Color', 'r', 'LineWidth', 1);
xlim(relativeRange);
ylabel('Z score');
title(sprintf('%s | %s | Unit %d | %s | %d trials', ...
    sessionName, targetUnitFile, targetUnit, eventNames(eventType), nEvents), ...
    'Interpreter', 'none');
set(gca, 'FontName', 'Noto Sans');
hold off;

% === Middle panel: Raster plot ===
ax2 = subplot(3, 1, 2);
hold on;
set(ax2, 'YDir', 'reverse');
for t = 1:nEvents
    for s = 1:numel(rasterSpikes{t})
        line([rasterSpikes{t}(s), rasterSpikes{t}(s)], ...
             [t - 0.5, t + 0.5], 'Color', 'k');
    end
end
line([0, 0], [0.5, nEvents + 0.5], 'Color', 'r', 'LineWidth', 1);
xlim(relativeRange);
ylim([0.5, nEvents + 0.5]);
ylabel('Trial');
set(gca, 'FontName', 'Noto Sans');
hold off;

% === Bottom panel: PSTH histogram ===
ax3 = subplot(3, 1, 3);
allRelativeSpikes = cat(1, rasterSpikes{:});
edges = relativeRange(1):HISTOGRAM_WIDTH:relativeRange(2);
N = histcounts(allRelativeSpikes, edges);
N = N ./ nEvents;
bar(ax3, edges(1:end-1) + HISTOGRAM_WIDTH/2, N, ...
    'FaceColor', 'k', 'LineStyle', 'none', 'BarWidth', 1);
line([0, 0], ylim, 'Color', 'r', 'LineWidth', 1);
xlim(relativeRange);
ylabel('Spikes / trial / bin');
xlabel('Time (ms)');
set(gca, 'FontName', 'Noto Sans');

% Link x axes
linkaxes([ax1, ax2, ax3], 'x');
set(findall(fig, '-property', 'FontName'), 'FontName', 'Noto Sans');

end