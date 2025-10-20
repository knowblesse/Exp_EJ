%% MoveCustomSmiData
% 2025 Ji Hoon Jeong

%% Set Variables
BASEPATH = "H:\Data\Kim Data";

%% Get filepaths 
filelist = dir(BASEPATH);
sessionPaths = regexp({filelist.name},'@AP\S*','match');
sessionPaths = sessionPaths(~cellfun('isempty',sessionPaths));
fprintf('%d sessions detected.\n', numel(sessionPaths));
fprintf(strcat(repmat('=', 1, 80), '\n'));

vals = cell(0);

for session = 1 : numel(sessionPaths)
    tankName = cell2mat(sessionPaths{session});
    tankPath = fullfile(BASEPATH, tankName);
    
    targetPath = fullfile("H:\Data\PNP_Data_Send", tankName);

    if exist(targetPath) == 0
        mkdir(targetPath);
    end

    copyfile(glob(tankPath, '.*helper.mat', true), targetPath);
    copyfile(glob(tankPath, '.*event.mat', true), targetPath);

    list = glob(tankPath, '.*event.smi', true);
    if ~iscell(list)
        list = {list};
    end
    for val = list
        copyfile(val{1}, targetPath);
    end

    list = glob(tankPath, '.*.pbf', true);
    if ~iscell(list)
        list = {list};
    end
    for val = list
        copyfile(val{1}, targetPath);
    end

    fprintf("%s\n", tankName);
end
fprintf(strcat(repmat('=', 1, 80), '\n'));
fprintf("BatchScript : All Complete! \n")

