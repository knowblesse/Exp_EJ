%% drawPETH
% Draw PETH using timepoints of spike and event markers
% input : 
%   unit_time : timepoint of the unit's spike. Time should be in ms.
%   event_time : timepoint of the event
%   timewindow : array with two element : define range of the event.
%   ax_raster : axis : axis for raster plot
%   ax_histo : axis : axis for histogram plot
%   normalize : bool : if true, divide histogram with num Trial
% return :
%    This function returns two axes in a cell structure. Setting the Parent
%    property of each element can plot the axes to designated figure. 
function ax = drawPETH(unit_time, event_time, timewindow, ax_raster, ax_histo, normalize)
%% Constants
HISTOGRAM_WIDTH = 50;

%% Match Dimension to vertical vector
if size(unit_time, 1) > 1 && size(unit_time, 2) == 1
    ;
elseif size(unit_time, 2) > 1 && size(unit_time, 1) == 1
    unit_time = unit_time';
else
    error('drawPETH : Wrong unit_time dimension');
end

if size(event_time, 1) > 1 && size(event_time, 2) == 1
    ;
elseif size(event_time, 2) > 1 && size(event_time, 1) == 1
    event_time = event_time';
else
    error('drawPETH : Wrong event_time dimension');
end

%% Raster Plot
numEvent = numel(event_time);
set(ax_raster, 'YDir', 'reverse');
all_within_spikes = [];
for idx_event = 1 : numEvent
    spike_within_window = unit_time(find(...
        and(...
        unit_time >= event_time(idx_event) + timewindow(1),...
        unit_time <  event_time(idx_event) + timewindow(2)...
        ))) - event_time(idx_event); % Event onset is time zero
    all_within_spikes = [all_within_spikes; spike_within_window];
    for idx_spike = 1 : numel(spike_within_window)
        line(ax_raster,repmat(spike_within_window(idx_spike),1,2),[idx_event - 0.5, idx_event + 0.5],'Color','k');
    end
end
line(ax_raster,[0,0],[0.5,numEvent+0.5],'Color','r','LineWidth',1);
ylabel(ax_raster, 'Event/Trial');
xlim(ax_raster, timewindow);
ylim(ax_raster, [0.5,numEvent+0.5]);

%% Histogram
[N,edges] = histcounts(all_within_spikes, timewindow(1):HISTOGRAM_WIDTH:timewindow(2));
if normalize
    N = N ./ numTrial;
end
bar(ax_histo,edges(1:end-1) + HISTOGRAM_WIDTH / 2,N,'FaceColor','k','LineStyle','none','BarWidth',1);
xlim(ax_histo, timewindow);
ylabel(ax_histo, 'Unit');
xticks(ax_histo, [-1000, -500, 0, 500, 1000]);
xlabel(ax_histo, 'Time(ms)');
set(findall(gcf,'-property','FontName'),'FontName','Noto Sans')
end
