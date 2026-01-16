%% GroupUnits

%% Parameters
showGraph = true;
eventTypeList = [4];
%% Load Aligned Data
load('AllActivity.mat');

%% Loop through 4 event types
% Pre-robot NP
% Pre-robot P
% Robot NP
% Robot P
eventName = ["Pre-robot NP", "Pre-robot P", "Robot NP", "Robot P"];
colors = lines(10);

for region = {"BLA"}
    region = region{1};
    if region == "BLA"
        groups = zeros(375, 4); % BLA
        numCluster = 8;
        cutoffLimit = 30;
    else
        groups = zeros(500, 4);% PFC
        numCluster = 8;
        cutoffLimit = 50;
    end

    for eventType = eventTypeList
        % -4 to +4 => 160 points
        zscoreMatrix = ActivityData(Region == region, :, eventType);
        %zscoreMatrix = ActivityData(Region == region, 40:119, eventType);
        sessionNames = SessionNames(Region == region, :);
        unitFile = UnitFile(Region == region, :);
        unitId = UnitId(Region == region, :);

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
        
        groups(:, eventType) = groupingResult;

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
            xlim([0, 160]);
            ylim([-0.5, 1.5]);
            line(xlim, [0,0], 'LineStyle', ':', 'Color', [0.3, 0.3, 0.3]);
            ylabel('Z score');
            xlabel('Time (sec)');
            xticks(0:20:160);
            xticklabels(-4:4);
            legend(plot_lines, legends, 'FontSize', 10);
            set(gca, 'FontName', 'Noto Sans');
            pos = get(gcf, 'Position');
            set(gcf, 'Position', [pos(1), pos(2), 400, 400]);
            title(eventName(eventType));
            %saveas(fig, eventName(eventType) + ".png");
        end

        %% Draw sorted heatmap
        if showGraph
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
            set(gcf, 'Position', [pos(1), pos(2), 321, 760]);
            %saveas(fig, eventName(eventType) + "sorted.png");
        end
    end
end
% fig = figure(15);
% clf;
% [~, ax1, ~] = shadeplot(ActivityData(groups(:, 4) == 3 & Region == "BLA", :, 4), 'SD', 'sem', 'LineWidth', 2);
% hold on;
% [~, ax2, ~] = shadeplot(ActivityData(groups(:, 4) == 3 & Region == "PFC", :, 4), 'SD', 'sem', 'LineWidth', 2);
% 
% legend([ax1, ax2], ["BLA", "PFC"])
% title("Robot P Group 3's activity");
% xticks(0:20:160);
% xticklabels(-4:4);
% xlabel('Time (s)');
% ylabel('Activity (Z)');
% ylim([-0.5, 4]);