%% ExportGroupingResult

%% Parameters
numCluster = 8;
cutoffLimit = 50;
showGraph = false;
colors = lines(10);

%% Load Aligned Data
load('AllActivity.mat');

targetRegion = "PFC";
numUnits = size(ActivityData, 1);

%% Loop through event types
% Pre-robot NP
% Pre-robot P
% Robot NP
% Robot P
eventName = ["Pre-robot NP", "Pre-robot P", "Robot NP", "Robot P"];

% Output Data
sessionNames = strings(numUnits, 1);
unitFileNames = strings(numUnits, 1);
unitIds = zeros(numUnits, 1);
groupData = zeros(numUnits, 4);

% Start Loop
for targetRegion = {"BLA", "PFC"}
    targetRegion = targetRegion{1};
    for eventType = 1 : 4
        if targetRegion == "BLA"
            zscoreMatrix = ActivityData(Region == "BLA", :, eventType);
            sessionNames = SessionNames(Region == "BLA", :);
            unitFile = UnitFile(Region == "BLA", :);
            unitId = UnitId(Region == "BLA", :);
        else
            zscoreMatrix = ActivityData(Region == "PFC", :, eventType);
            sessionNames = SessionNames(Region == "PFC", :);
            unitFile = UnitFile(Region == "PFC", :);
            unitId = UnitId(Region == "PFC", :);
        end
        
        %% Use 'correlation' as distance between unit's activity
        Z_ = linkage(zscoreMatrix, 'average', 'correlation');
        
        unitClusterId = cluster(Z_, 'maxclust', numCluster);
        
        cnt = histcounts(unitClusterId, 1:numCluster+1);
        [val, idx] = sort(cnt, 'descend');
        
        numGroup = 0;
        groupingResult = zeros(size(zscoreMatrix,1),1);
        
        for clt = 1 : numCluster
            if val(clt) >= cutoffLimit
                numGroup = numGroup + 1;
                groupingResult(unitClusterId == idx(clt)) = numGroup;
            end
        end
        
        % For BLA, remove Group2 as it is a group for noise.
        if targetRegion == "BLA"
            groupingResult(groupingResult == 3) = 2;
            groupingResult(groupingResult == 4) = 3;
            numGroup = 3;
        end
        
        groupData(Region == targetRegion, eventType) = groupingResult;
        fig = figure();
        axes();
        hold on;
        plot_lines = [];
        legends = {};
        for group = 1 : numGroup
            [~, obj_line, ~] = shadeplot(...
                zscoreMatrix(groupingResult == group, :),...
                'SD', 'sem',... 
                'LineWidth', 1.3,...
                'FaceAlpha', 0.3,...
                'Color', colors(group,:));
            plot_lines = [plot_lines, obj_line];
            legends = [legends, strcat("Group " , num2str(group), " (", num2str(sum(groupingResult == group)), ")")];
        end
        %xlim([0, 160]);
        xlim([0, 400]);
        ylim([-0.5, 1.5]);
        line(xlim, [0,0], 'LineStyle', ':', 'Color', [0.3, 0.3, 0.3]);
        ylabel('Z score');
        xlabel('Time (sec)');
        %xticks(0:20:160);
        %xticklabels(-4:4);
        xticks(0:20:400);
        xticklabels(-10:10);
        legend(plot_lines, legends, 'FontSize', 10);
        set(gca, 'FontName', 'Noto Sans');
        pos = get(gcf, 'Position');
        set(gcf, 'Position', [pos(1), pos(2), 400, 400]);
        title(eventName(eventType) + " " + targetRegion);
        saveas(fig, eventName(eventType) + targetRegion + ".png");
    end
end

%% Save
outputTable = table(SessionNames, UnitFile, UnitId, Region, groupData(:,1), groupData(:,2), groupData(:,3), groupData(:,4), ...
    'VariableNames', {'SessionName', 'UnitFileName', 'UnitID', 'Region', 'Group by Pre-robot NP', 'Group by Pre-robot P', 'Group by Robot NP', 'Group by Robot P'});
filename = 'neuron_clustering_results.xlsx';

% Write each table to a separate sheet
writetable(outputTable, filename);

fprintf('Tables saved to %s\n', filename);
