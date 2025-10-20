%% DrawPAttemptsGraph
% 2025 Ji Hoon Jeong
% Script for drawing attempts graph

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

    % Load event file
    eventFilePath = fullfile(tankPath, strcat(tankName(2:end), '_event.mat'));
    load(eventFilePath);

    if numel(eventData) ~= 20
        error("event Data size is not 20");
    end
    
    
    vals = [vals, {cumsum(eventDataRaw.Attempts(find([eventDataRaw.Trial] == 11, 1):end) > 0)}];

end
fprintf(strcat(repmat('=', 1, 80), '\n'));
fprintf("BatchScript : All Complete! \n")

%%

% figure(1);
% histogram(Accuracy3, 0:0.05:1, 'FaceColor', 'k', 'FaceAlpha', 0.8, 'LineStyle', 'none');
% xline(0.5, 'r');
% xlabel('Accuracy');
% ylabel('Count');

figure(2);
clf;
for i = 1 : numel(vals)
    plot(vals{i}, lineWidth=numel(vals{i})/5);
    hold on;
end
xlabel('Approach to a pellet');
ylabel('Approach to the preferred pellet')

