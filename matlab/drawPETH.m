function ax = drawPETH(unit, TIMEWINDOW, ax_raster, ax_histo, normalize)
%% Draw PETH
% input : 
%   unit : cell array : Each cell represent one trial and it has n x 1 matrix.
%          n represent total spikes in that window.
%          Each element of the n x 1 matrix is the time point in millisecond.
%          Event onset time is zero.
%   TIMEWINDOW : array with two element : define range of the event.
%   ax_raster : axis : axis for raster plot
%   ax_histo : axis : axis for histogram plot
%   normalize : bool : if true, divide histogram with num Trial
% return :
%    This function returns two axes in a cell structure. Setting the Parent
%    property of each element can plot the axes to designated figure. 

%% Constants
HISTOGRAM_WIDTH = 50;

%% Raster Plot
numTrial = numel(unit);
set(ax_raster, 'YDir', 'reverse');
for t = 1 : numel(unit)
    for s = 1 : numel(unit{t})
        line(ax_raster,[unit{t}(s),unit{t}(s)],[t - 0.5, t + 0.5],'Color','k');
    end
end
line(ax_raster,[0,0],[0.5,numTrial+0.5],'Color','r','LineWidth',1);
ylabel(ax_raster, 'Trial');
xlim(ax_raster, TIMEWINDOW);
ylim(ax_raster, [0.5,numTrial+0.5]);

%% Histogram
unit_all = cat(1,unit{:});
[N,edges] = histcounts(unit_all,TIMEWINDOW(1):HISTOGRAM_WIDTH:TIMEWINDOW(2));
if normalize
    N = N ./ numTrial;
end
bar(ax_histo,edges(1:end-1) + HISTOGRAM_WIDTH / 2,N,'FaceColor','k','LineStyle','none','BarWidth',1);
xlim(ax_histo, TIMEWINDOW);
if normalize
    ylabel(ax_histo, 'Unit');
else
    ylabel(ax_histo, 'Unit');
end 
xticks(ax_histo, [-1000, -500, 0, 500, 1000]);
xlabel(ax_histo, 'Time(ms)');
set(findall(gcf,'-property','FontName'),'FontName','Noto Sans')
end
