%% GroupUnits

%% Parameters
showGraph = true;
eventTypeList = [4];
distanceCutoff = 0.70;
numberCutoff = 20;
%% Load Aligned Data
load('AllActivity_1010.mat');

%% Loop through 4 event types
% Pre-robot NP
% Pre-robot P
% Robot NP
% Robot P
eventName = ["Pre-robot NP", "Pre-robot P", "Robot NP", "Robot P"];
colors = lines(20);

% Check validity of neurons using number of spikes per event
isValid = NumSpikesEvents(:,4)./NumEvents(:,4) >= 1;

output_sessionNames = [];
output_unitFile = [];
output_unitId = [];
output_region = [];
output_group = [];

for region = {"BLA", "PFC"}
    region = region{1};
    if region == "BLA"
        numNeurons = sum(Region == "BLA" & isValid);
        groups = zeros(numNeurons, 4); % BLA
    else
        numNeurons = sum(Region == "PFC" & isValid);
        groups = zeros(numNeurons, 4);% PFC
    end

    for eventType = eventTypeList
        % -4 to +4 => 160 points
        zscoreMatrix = ActivityData(Region == region & isValid, :, eventType);
        %zscoreMatrix = ActivityData(Region == region, 40:119, eventType);
        sessionNames = SessionNames(Region == region & isValid, :);
        unitFile = UnitFile(Region == region & isValid, :);
        unitId = UnitId(Region == region & isValid, :);
        regionName = Region(Region == region & isValid, :);

        %% Use 'cosine' as distance between unit's activity
        Z_ = linkage(zscoreMatrix, 'average', 'cosine');
        
        %unitClusterId = cluster(Z_, 'maxclust', numCluster);
        unitClusterId = cluster(Z_, 'cutoff', distanceCutoff, 'criterion', 'distance');
        
        cnt = histcounts(unitClusterId, 0.5:1:(max(unitClusterId)+0.5));
        [val, idx] = sort(cnt, 'descend');
        
        numGroup = 0;
        groupingResult = zeros(size(zscoreMatrix,1),1);
        
        for clt = 1 : max(unitClusterId)
            if val(clt) >= numberCutoff
                numGroup = numGroup + 1;
                groupingResult(unitClusterId == idx(clt)) = numGroup;
            end
        end
        
        groups(:, eventType) = groupingResult;

        output_sessionNames = [output_sessionNames; sessionNames];
        output_unitFile = [output_unitFile; unitFile];
        output_unitId = [output_unitId; unitId];
        output_region = [output_region; regionName];
        output_group = [output_group; groupingResult];

        %% Draw Average activity of each group
        if showGraph
            fig = figure();
            axes();
            hold on;
            plot_lines = [];
            legends = {};
            for group = 1 : numGroup
                [~, obj_line, ~] = shadeplot(...
                    zscoreMatrix(groupingResult == group, :),...
                    'SD', 'sem',... %'LineWidth', sum(groupingResult == group)/100,...
                    'LineWidth', 1.3,...
                    'FaceAlpha', 0.3,...
                    'Color', colors(group,:));
                plot_lines = [plot_lines, obj_line];
                legends = [legends, strcat("Group " , num2str(group), " (", num2str(sum(groupingResult == group)), ")")];
            end
            xlim([0, size(zscoreMatrix, 2)]);
            ylim([-0.5, 3]);
            line(xlim, [0,0], 'LineStyle', ':', 'Color', [0.3, 0.3, 0.3]);
            ylabel('Z score');
            xlabel('Time (sec)');
            xticks(0:20:size(zscoreMatrix, 2));
            xticklabels(-size(zscoreMatrix, 2)/40:size(zscoreMatrix, 2)/40);
            legend(plot_lines, legends, 'FontSize', 10);
            set(gca, 'FontName', 'Noto Sans');
            pos = get(gcf, 'Position');
            %set(gcf, 'Position', [pos(1), pos(2), 400, 400]);
            if region == "BLA"
                set(gcf, 'Position', [2504, 497, 400, 400]);
            else
                set(gcf, 'Position', [2904, 497, 400, 400]);
            end

            title(eventName(eventType) + " dist: " + num2str(distanceCutoff) + " num: " + num2str(numberCutoff));
            %saveas(fig, eventName(eventType) + ".png");
            drawnow;
        end

        %% Draw sorted heatmap
        if false
            finalIdx = [];
            
            for g = 1:numGroup
                % 현재 그룹에 속한 뉴런들
                group_neurons = find(groupingResult == g);
            
                if numel(group_neurons) > 1
                    % 이 그룹만의 데이터
                    group_data = zscoreMatrix(group_neurons, :);
            
                    % 그룹 내에서 다시 hierarchical clustering
                    Z_group = linkage(group_data, 'average', 'correlation');
            
                    % Optimal leaf order
                    leafOrder_group = optimalleaforder(Z_group, pdist(group_data, 'correlation'));
            
                    % 원래 인덱스로 변환
                    finalIdx = [finalIdx; group_neurons(leafOrder_group)];
                else
                    finalIdx = [finalIdx; group_neurons];
                end
            end
            fig = figure;
            colormap('turbo');
            imagesc(zscoreMatrix(finalIdx, :));
            colorbar;
            
            % Group boundary
            hold on;
            cumVal = 0;
            boundaries = [];
            for g = 1:numGroup
                cumVal = cumVal + sum(groupingResult == g);
                line(xlim, [cumVal, cumVal] + 0.5, 'Color', [1, 1, 1], 'LineWidth', 2);
                boundaries = [boundaries, cumVal];
            end
            clim([-0.5, 5]);
            yticks(boundaries);
            yticklabels(1:numGroup);
            xlabel('Time (bins)');
            ylabel('Neurons (sorted)');
            title(eventName(eventType));
            pos = get(gcf, 'Position');
            set(gcf, 'Position', [pos(1)+400, pos(2)-360, 321, 760]);
            %saveas(fig, eventName(eventType) + "sorted.png");
        end
    end
end
%% Save
outputTable = table(output_sessionNames, output_unitFile, output_unitId, output_region, output_group, ...
    'VariableNames', {'SessionName', 'UnitFileName', 'UnitID', 'Region', 'Group by Robot P'});
filename = 'neuron_clustering_results.xlsx';

% Write each table to a separate sheet
writetable(outputTable, filename);

fprintf('Tables saved to %s\n', filename);
