%% UnitDataCheck
BASEPATH = "H:\Data\Kim Data";
addpath('lib/Neuralynx/');

%% Get filepaths 
%tankPath = uigetdir(BASEPATH);
tankPath = "H:\Data\Kim Data\@AP18_031418";
tankName = regexp(tankPath, '\\(?:|#|##|$#|@)(AP.*)$', 'tokens');
tankName = tankName{1}{1};

unitFilePaths = glob(tankPath, '\.(N|n)(T|t)(T|t)', true);

%% Load helper file
load(fullfile(tankPath, strcat(tankName, '_helper.mat')));
if ~all([exist('expStat', 'var'), exist('time2TS', 'var'), exist('time2TS_filename', 'var')])
    error("Helper file not loaded properly")
end

%% Load event file
load(fullfile(tankPath, strcat(tankName, '_event.mat')));
if ~exist('eventData', 'var')
    error("Event data not loaded properly")
end

% path sanity check
for p_ = unitFilePaths
    if isempty(p_{1})
        error("File could not be loaded");
    end
end
clearvars p_;

%% Read unit file
fprintf("generateEventClassifierDataset : Loading unit data\n");
unitData = table([], [], {}, 'VariableName', {'unitNumber', 'numSpike', 'time_ms'});

unitNumber = 1;
for unitFilePath = unitFilePaths
    % Load Unit Data
    [Timestamps, ~, CellNumbers, ~, Samples] = Nlx2MatSpike(...
        unitFilePath{1},...
        [1, 1, 1, 1, 1],... % Time, Spike Channel Number, Cell Number, Spike Feature, Samples
        0,... %Extract Header
        1);

    % Separate Unit Data
    unitType = unique(CellNumbers);
    numUnit_ = numel(unitType);
    for i = 1 : numUnit_
        temp_ = Timestamps(CellNumbers == unitType(i))'; % selected unit's timestamps
        temp_ = (temp_ - expStat.startTS) / 1000; % timestamp to relative ms

        % Check if all spike occur after startTS.
        % => sometimes, spike occur before expStat.startTS. remove such data.
        temp_ = temp_(temp_ > 0);
        
        % Turn it into table
        unitData = [unitData; table(...
            unitNumber,...
            numel(temp_),...
            {temp_},...
            'VariableName', {'unitNumber', 'numSpike', 'time_ms'})];
        fprintf("UnitDataCheck: Unit %d data loaded\n", unitNumber);
        unitNumber = unitNumber + 1;
    end
end
numUnit = size(unitData, 1);
clearvars numunit i unitfilepath unittype unitfilepaths temp_ numUnit_
fprintf("generateEventclassifierdataset : all unit data loaded\n");


%%
fig1 = figure();
ax_raster1 = subplot(4,1,1:3);
ax_histo1 = subplot(4,1,4);
drawPETH(P_times, TIMEWINDOW, ax_raster1, ax_histo1, false);
title(ax_raster1, 'P Pellet');

fig2 = figure();
ax_raster2 = subplot(4,1,1:3);
ax_histo2 = subplot(4,1,4);
drawPETH(NP_times, TIMEWINDOW, ax_raster2, ax_histo2, false);
title(ax_raster2, 'NP Pellet');


