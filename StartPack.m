%% Set Variables

basePath = "C:\Users\Knowblesse\Desktop\drive-download-20230410T045830Z-001\AP18_041118";

eventFilePath = char(fullfile(basePath, glob(basePath, '.*.nev')));
nvtFilePath = char(fullfile(basePath, glob(basePath, '.*.nvt'))); % Video Tracking
nttFilePaths = cellfun(@(X) char(fullfile(basePath, X)), glob(basePath, '.*.(N|n)(T|t)(T|t)'), 'UniformOutput',false);


%% Read Event File
[TimeStamps, EventIDs, TTLs, Extras, EventStrings] = Nlx2MatEV(...
    eventFilePath,... % Filename
    [1, 1, 1, 1, 1],... % FieldSelectionFlag
    0,... % HeaderExtractionFlag
    1);

%% Read Video Tracking File 
[TimeStamps, ExtractedX, ExtractedY, ExtractedAngle, Targets, Points] = Nlx2MatVT(...
    nvtFilePath,...
    [1, 1, 1, 1, 1, 1],... % Time, X, Y, angle, targets, points
    0,... %ExtractHeader
    1);

%% Read Cell File
i = 1;

[Timestamps, ScNumbers, CellNumbers, Features, Samples] = Nlx2MatSpike(...
    nttFilePaths{1},...
    [1, 1, 1, 1, 1],... % Time, Spike Channel Number, Cell Number, Spike Feature, Samples
    0,... %Extract Header
    1);