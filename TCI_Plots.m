function [] = TCI_Plots(Temps, CaResponse, Stim, UIDs, n, numfiles, Results, time)
%% TCI_Plots
%   Generates and saves plots of YC3.6 Thermal Imaging
%   TCI_Plots(Temps, CaResponse, name, n, numfiles)
%
%   Version 1.0
%   Version Date: 3-31-20
%
%% Revision History
%   3-31-20:    Forked from older version by ASB
%   2021_01_27  Changed heatmap such that the heamtap rows (individual
%               traces) are now ordered using average linkage distance.
%               Also changed the inputs to the heatmap so that the traces
%               are normalized to the maximum Ca2+ response for the group.

global plotflag
global assaytype
global plteach
global pltheat
global pltshade
global pltmulti
global plttvr
global plttmax

%% Plot Individual Traces
plotflag = 1 ;
if plteach == 1
    for i = 1:numfiles
        DrawThePlots(Temps.full(:,i), CaResponse.full(:,i), UIDs{i});
    end
end
set(0,'DefaultFigureVisible','on');

%% Plot Average Traces and Heat Maps
if numfiles > 1
    % Calculate Mean and SD with non-normalized data
    % Note: by including NaN values, if a trace is missing values b/c it is
    % truncated, the entire average trace will be truncated to match. To
    % change this behavior, switch the nan flag to 'omitnan'
    avg_Ca = mean(CaResponse.full,2,'omitnan');
    sd_Ca = std(CaResponse.full,[],2,'omitnan');
    avg_Tmp = mean(Temps.full,2,'omitnan');
    sd_Tmp = std(Temps.full,[],2,'omitnan');
    
    % Average shaded plot
    if pltshade == 1
        MakeTheShadedPlot(avg_Ca, avg_Tmp, sd_Ca, sd_Tmp,  n, Results.Tx, Results.out, Results.Thresh_temp);
    end
    
    % Multiple line plot
    if pltmulti == 1
        MakeTheMultipleLinePlot(CaResponse.full, avg_Tmp, sd_Tmp, n, Results.out);
    end
    
     % Multiple line plot
    if plttmax == 1
        MakeTheMultipleLinePlot(CaResponse.Tmax, ...
            mean(Temps.Tmax,2,'omitnan'), ...
            std(Temps.Tmax,[],2,'omitnan'), ...
            strcat(n, '_TmaxZoom'), find(mean(Temps.Tmax,2,'omitnan') >= Stim.max, 1, 'first'));
    end
        
    % Normalize traces to the maximum calcium
    % response amongst all traces.
    % Used for % Correlation plots and Heatmap with normalized data
    
    CaResponse.norm = CaResponse.subset/max(max(CaResponse.subset));
    
    if assaytype ~= 2
        CaResponse.heat = CaResponse.norm;
        Temps.heat = Temps.subset;
    else
        
        % Align the full and subset traces
        for i = 1:numfiles
            [~, ia, ~] = intersect(CaResponse.full(:,i), CaResponse.subset(:,i), 'stable');
            time_adjustment_index(i) = ia(1) - 1;
        end
        CaResponse.heat = arrayfun(@(x)(CaResponse.full(time_adjustment_index(x):time_adjustment_index(x)+time.pad(4), x)), [1:numfiles], 'UniformOutput', false);
        CaResponse.heat = cell2mat(CaResponse.heat);
        CaResponse.heat =CaResponse.heat/max(max(CaResponse.heat));
        
        Temps.heat = arrayfun(@(x)(Temps.full(time_adjustment_index(x):time_adjustment_index(x)+time.pad(4), x)), [1:numfiles], 'UniformOutput', false);
        Temps.heat = cell2mat(Temps.heat);
    end
 
    if pltheat == 1
        setaxes = 1;
        while setaxes>0 % loop through the axes selection until you're happy
            switch assaytype
                case 1
                    range = {'-20', '100'};
                case 2
                    range = {'-10', '20'};
                case 3
                    range = {'-60', '60'};
            end
            
            answer = inputdlg({'Heatmap Range Min', 'Heatmap Range Max'}, ...
                'Heatmap Parameters', 1, range);
            range = [str2num(answer{1}), str2num(answer{2})];
            
            MakeTheHeatmap(CaResponse.heat'*100, mean(Temps.heat,2,'includenan'), std(Temps.heat,[],2,'includenan'), n, range);
            
            answer = questdlg('Adjust Heatmap Params', 'Plot adjustment', 'Yes');
            switch answer
                case 'Yes'
                    setaxes=1;
                    close all
                case 'No'
                    setaxes=-1;
                case 'Cancel'
                    setaxes=-1;
            end
        end
        close all
        
    end
    
    
    if assaytype == 1
        if plttvr == 1
            MakeTheTempVResponsePlot(Temps.AtTh, CaResponse.AtTh, Temps.AboveTh, CaResponse.AboveTh, n, Stim,{'AtTh';'AboveTh'});
        end
        
    elseif assaytype == 2
        if plttvr == 1
            MakeTheTempVResponsePlot(Temps.BelowTh, CaResponse.BelowTh, [], [], n, Stim,{'BelowTh',''});
        end
    elseif assaytype == 3
        if plttvr == 1
            MakeTheTempVResponsePlot(Temps.AtTh, CaResponse.AtTh, Temps.AboveTh, CaResponse.AboveTh, n, Stim,{'AtTh';'AboveTh'});
        end
    end
end
end

%% The bits that make the figures
% Oh look, an inline script!

function [] = DrawThePlots(T, Ca, name)
global pathstr
global assaytype
global newdir
global plotflag

%% Draw a figure where the calcium trace is a black line
fig=figure;
movegui('northeast');

% plot Calcium Trace
ax.up = subplot(3,1,[1:2]);
plot(Ca,'k');
xlim([0, round(size(Ca,1),-1)]);
ylim([floor(min(Ca)),ceil(max(Ca))]);
ylabel('dR/R0 (%)');

% plot Temperature trace
ax.dwn = subplot(3,1,3);
plot(T,'Color','k');
set(gca,'xtickMode', 'auto');
ylim([floor(min(T)),ceil(max(T))]);
xlim([0, round(size(Ca,1),-1)]);
ylabel('Temperature (celcius)','Color','k');
xlabel('Time (seconds)');

% Give the figure a title
currentFigure = gcf;
if contains(pathstr,{'pASB52', 'Ss AFD'})
    suffix = 'Ss-AFD_';
elseif contains(pathstr,'pASB53')
    suffix = 'Ss-BAG--rGC(35)_';
elseif contains(pathstr,{'pASB55', 'Ss BAG'})
    suffix = 'Ss-BAG_';
elseif contains(pathstr,{'IK890', 'Ce AFD'})
    suffix = 'Ce-AFD_';
elseif contains(pathstr,{'XL115', 'Ce ASE'})
    suffix = 'Ce-ASE_cameleon_';
else
    suffix = '';
end
title(currentFigure.Children(end), [strcat('Recording', {' '},suffix,string(name))],'Interpreter','none');

% Adjust axis values for the plot
if plotflag > 0
    setaxes = 1;
    while setaxes>0 % loop through the axes selection until you're happy
        answer = questdlg('Adjust X/Y Axes?', 'Axis adjustment', 'Yes','No','No for All','Yes');
        switch answer
            case 'Yes'
                setaxes=1;
                vals=inputdlg({'X Min','X Max','Y Min Upper', 'Y Max Upper','Y Min Lower', 'Y Max Lower'},...
                    'New X/Y Axes',[1 35; 1 35; 1 35;1 35; 1 35;1 35],{num2str(ax.up.XLim(1)) num2str(ax.up.XLim(2))  num2str(ax.up.YLim(1)) num2str(ax.up.YLim(2)) num2str(ax.dwn.YLim(1)) num2str(ax.dwn.YLim(2))});
                if isempty(vals)
                    setaxes = -1;
                else
                    ax.up.XLim(1) = str2double(vals{1});
                    ax.up.XLim(2) = str2double(vals{2});
                    ax.dwn.XLim(1) = str2double(vals{1});
                    ax.dwn.XLim(2) = str2double(vals{2});
                    ax.up.YLim(1) = str2double(vals{3});
                    ax.up.YLim(2) = str2double(vals{4});
                    ax.dwn.YLim(1) = str2double(vals{5});
                    ax.dwn.YLim(2) = str2double(vals{6});
                end
            case 'No'
                setaxes=-1;
            case 'No for All'
                setaxes=-1;
                plotflag = -1;
                set(0,'DefaultFigureVisible','off');
                disp('Remaining plots generated invisibly.');
        end
    end
end

saveas(gcf, fullfile(newdir,['/',name, '.eps']),'epsc');
saveas(gcf, fullfile(newdir,['/',name, '.jpeg']),'jpeg');


%% Draw a figure where the calcium trace color corresponds to the temperature
fig2 = figure;
%movegui('northeast');

if assaytype == 1
    C=inferno(45-15+1); %Full range of possible temperatures
    TickRange=[1:5:31];
    TickLab={'15','20','25','30','35','40','45'};
elseif assaytype ==2
    C=parula(25-10+1);
    TickRange=[1:5:16];
    TickLab={'10','15','20','25'};
elseif assaytype ==3
    C=inferno(35-5+1); %Full range of possible temperatures
    TickRange=[1:5:31];
    TickLab={'5','10','15','20','25','30','35'};
elseif assaytype ==4
    C=inferno(22-15+1); %Full range of possible temperatures
    TickRange=[1:2:8];
    TickLab={'15','17','19','22'};
end
colormap((C));
xx = [1:size(Ca,1)'; 1:size(Ca,1)']';
yy = [Ca, Ca];
zz = zeros (size(xx));
cc = [round((T)-15),round((T))-15];

ax2.up = subplot(4,1,1:3);
hs = surf(xx,yy,zz,cc,'EdgeColor','interp','FaceColor','none','CDataMapping','direct','LineWidth',2);
view(2);
grid off
ylabel('dR/R0 (%)');
colorbar('Ticks',TickRange,'TickLabels',TickLab);

ax2.dwn = subplot(4,1,4);
plot(T);
xlim([0, round(size(Ca,1),-1)]);
ylabel('Temperature (celcius)');
xlabel('Time (seconds)');
colorbar

ax2.up.XLim(1) = ax.up.XLim(1);
ax2.up.XLim(2) = ax.up.XLim(2);
ax2.dwn.XLim(1) = ax.dwn.XLim(1);
ax2.dwn.XLim(2) = ax.dwn.XLim(2);
ax2.up.YLim(1) = ax.up.YLim(1);
ax2.up.YLim(2) = ax.up.YLim(2);
ax2.dwn.YLim(1) = ax.dwn.YLim(1);
ax2.dwn.YLim(2) = ax.dwn.YLim(2);

currentFigure = gcf;
title(currentFigure.Children(end), [strcat('Recording', {' '},suffix,string(name))],'Interpreter','none');

saveas(gcf, fullfile(newdir,['/', 'rp_',name, '.jpeg']),'jpeg');
saveas(gcf, fullfile(newdir,['/', 'rp_',name, '.eps']),'epsc');
close all
end

function []= MakeTheShadedPlot(Ca, avg_Tmp, err_Ca, err_Tmp, n, Tx, out, Thresh_temp)
global newdir

fig = figure;
ax.up = subplot(3,1,[1:2]);
shadedErrorBar([1:size(Ca,1)],Ca,err_Ca,'k',0);
hold on;
plot(out,Tx,'bo');
hold off;

xlim([0, size(Ca,1)]);
ylim([floor(min(Ca)-max(err_Ca)),ceil(max(Ca)+max(err_Ca))]);

set(gca,'XTickLabel',[]);
ylabel('dR/R0 (%)');

ax.dwn = subplot(3,1,3);
shadedErrorBar([1:size(avg_Tmp,1)],avg_Tmp,err_Tmp,'k',0);
set(gca,'xtickMode', 'auto');
ylim([floor(min(avg_Tmp)-max(err_Tmp)),ceil(max(avg_Tmp)+max(err_Tmp))]);

hold on; plot(out, Thresh_temp, 'bo')
hold off;

xlim([0, size(Ca,1)]);
ylabel('Temperature (celcius)','Color','k');
xlabel('Time (seconds)');
currentFigure = gcf;

title(currentFigure.Children(end), strcat(n,'_Averaged Cameleon Response'),'Interpreter','none');

movegui('northeast');
setaxes = 1;
while setaxes>0 % loop through the axes selection until you're happy
    answer = questdlg('Adjust X/Y Axes?', 'Axis adjustment', 'Yes');
    switch answer
        case 'Yes'
            setaxes=1;
            vals=inputdlg({'X Min','X Max','Y Min Upper', 'Y Max Upper','Y Min Lower', 'Y Max Lower'},...
                'New X/Y Axes',[1 35; 1 35; 1 35;1 35; 1 35;1 35],{num2str(ax.up.XLim(1)) num2str(ax.up.XLim(2))  num2str(ax.up.YLim(1)) num2str(ax.up.YLim(2)) num2str(ax.dwn.YLim(1)) num2str(ax.dwn.YLim(2))});
            if isempty(vals)
                setaxes = -1;
            else
                ax.up.XLim(1) = str2double(vals{1});
                ax.up.XLim(2) = str2double(vals{2});
                ax.dwn.XLim(1) = str2double(vals{1});
                ax.dwn.XLim(2) = str2double(vals{2});
                ax.up.YLim(1) = str2double(vals{3});
                ax.up.YLim(2) = str2double(vals{4});
                ax.dwn.YLim(1) = str2double(vals{5});
                ax.dwn.YLim(2) = str2double(vals{6});
            end
        case 'No'
            setaxes=-1;
        case 'Cancel'
            setaxes=-1;
    end
end

saveas(gcf, fullfile(newdir,['/', n, '-mean_sd.jpeg']),'jpeg');
saveas(gcf, fullfile(newdir,['/', n, '-mean_sd.eps']),'epsc');

close all
end

function [] = MakeTheHeatmap(Ca, avg_Tmp, err_Tmp, n, range)

global newdir
global assaytype

% Use hierarchical clustering to determine optimal order for rows
% the method for the linkage is: Unweighted average distance (UPGMA), aka
% average linkage clustering
D = pdist(Ca);
tree = linkage(D, 'average');
leafOrder = optimalleaforder(tree, D);

% Reorder Calcium traces to reflect optimal leaf order
Ca = Ca(leafOrder, :);

figure
colormap(viridis);
subplot(3,1,[1:2]);
imagesc(Ca,range);
set(gca,'XTickLabel',[]);
xlim([0, round(size(avg_Tmp,1),-1)]);
ylabel('Worms');
colorbar

subplot(3,1,3);
colors = get(gca,'colororder');
shadedErrorBar([1:size(avg_Tmp,1)],avg_Tmp,err_Tmp,'r',0);
set(gca,'xtickMode', 'auto');
ylim([10, 41]);
xlim([0, round(size(avg_Tmp,1),-1)]);
ylabel('Temperature (celcius)','Color','r');
xlabel('Time (seconds)');
currentFigure = gcf;
colorbar

title(currentFigure.Children(end), strcat(n,'_Cameleon Response Heatmap'),'Interpreter','none');

movegui('northeast');

saveas(gcf, fullfile(newdir,['/', n, '-heatmap.eps']),'epsc');
saveas(gcf, fullfile(newdir,['/', n, '-heatmap.jpeg']),'jpeg');
end

function [] = MakeTheTempVResponsePlot(Bin1_Temps, Bin1_CaResponse, Bin2_Temps, Bin2_CaResponse, n, Stim,labels)
global newdir
global assaytype

fig = figure;
ax.L = subplot(1,15,1:5);
hold on; 

plot(Bin1_Temps, Bin1_CaResponse,'-');
% Calculate median calcium response at each unique temperature measurement,
% then smooth the temperature and calcium responses to reduce periodic
% trends triggered by outliers, which are likely instances where the specific
% temperature measurement are only observed in a small number of traces. 
[V, jj, kk] = unique(Bin1_Temps);
avg_Ca = accumarray(kk, (1:numel(kk))', [], @(x) median(Bin1_CaResponse(x), 'omitnan'));
avg_Temp = accumarray(kk, (1:numel(kk))', [], @(x) median(Bin1_Temps(x), 'omitnan'));
smoothed_Ca = smoothdata(avg_Ca,'movmedian',5);
smoothed_Temp = smoothdata(avg_Temp, 'movmedian',5);
plot(smoothed_Temp,smoothed_Ca,'LineWidth', 2, 'Color', 'k');
hold off
ylabel('dR/R0 (%)');xlabel('Temperature (C)');
ylim([-50 50]);
xlim([20 25]);
title(labels{1});

ax.R = subplot(1,15,6:15);
hold on;
plot(Bin2_Temps, Bin2_CaResponse,'-');

[V, jj, kk] = unique(Bin2_Temps);
avg_Ca = accumarray(kk, (1:numel(kk))', [], @(x) median(Bin2_CaResponse(x), 'omitnan'));
avg_Temp = accumarray(kk, (1:numel(kk))', [], @(x) median(Bin2_Temps(x), 'omitnan'));
smoothed_Ca = smoothdata(avg_Ca,'movmedian',10);
smoothed_Temp = smoothdata(avg_Temp, 'movmedian',10);
plot(smoothed_Temp,smoothed_Ca,'LineWidth', 2, 'Color', 'k');
hold off

set(gca,'YTickLabel',[]); xlabel('Temperature (C)');
ylim([-50 400]);
xlim([25 34]);
title(labels{2});

if exist('Stim.NearTh')
    ax.L.XLim = [Stim.NearTh(1) Stim.NearTh(2)];
    ax.L.XTick = [Stim.NearTh(1):2:Stim.NearTh(2)];
    ax.R.XLim = [Stim.AboveTh(1) Stim.max];
    ar.R.XTick = [Stim.AboveTh:5:Stim.max]
elseif exist('Stim.BelowTh')
    ax.L.XLim = [Stim.BelowTh(2) Stim.BelowTh(1)];
    ax.L.XTick = [Stim.BelowTh(2):2:Stim.BelowTh(1)];
end

movegui('northeast');
setaxes = 1;
while setaxes>0 % loop through the axes selection until you're happy
    answer = questdlg('Adjust X/Y Axes?', 'Axis adjustment', 'Yes');
    switch answer
        case 'Yes'
            setaxes=1;
            vals=inputdlg({'X Min Left','X Max Left','Y Min Left', 'Y Max Left','X Min Right','X Max Right','Y Min Right', 'Y Max Right'},...
                'New X/Y Axes',[1 35; 1 35; 1 35;1 35; 1 35;1 35; 1 35;1 35],{num2str(ax.L.XLim(1)) num2str(ax.L.XLim(2))  num2str(ax.L.YLim(1)) num2str(ax.L.YLim(2)) num2str(ax.R.XLim(1)) num2str(ax.R.XLim(2)) num2str(ax.R.YLim(1)) num2str(ax.R.YLim(2))});
            if isempty(vals)
                setaxes = -1;
            else
                ax.L.XLim(1) = str2double(vals{1});
                ax.L.XLim(2) = str2double(vals{2});
                
                ax.L.YLim(1) = str2double(vals{3});
                ax.L.YLim(2) = str2double(vals{4});
                
                ax.R.XLim(1) = str2double(vals{5});
                ax.R.XLim(2) = str2double(vals{6});
                
                ax.R.YLim(1) = str2double(vals{7});
                ax.R.YLim(2) = str2double(vals{8});
            end
        case 'No'
            setaxes=-1;
        case 'Cancel'
            setaxes=-1;
    end
end

saveas(gcf, fullfile(newdir,['/', n, '-Temperature vs CaResponse_lines']),'epsc');
saveas(gcf, fullfile(newdir,['/', n, '-Temperature vs CaResponse_lines']),'jpeg');

close all
end

function []= MakeTheMultipleLinePlot(Ca, avg_Tmp,  err_Tmp, n, vertline)
global newdir


C=cbrewer('qual', 'Dark2', 7, 'PCHIP');
set(groot, 'defaultAxesColorOrder', C);
fig = figure;
ax.up = subplot(3,1,[1:2]);

hold on;

xline(vertline,'LineWidth', 2, 'Color', [0.5 0.5 0.5], 'LineStyle', ':');
plot([1:size(Ca,1)],Ca, 'LineWidth', 1);
plot([1:size(Ca,1)],median(Ca,2, 'omitnan'),'LineWidth', 2, 'Color', 'k');

hold off;
xlim([0, size(Ca,1)]);
ylim([floor(min(min(Ca))),ceil(max(max(Ca)))]);
ylim([-50, 100]);

set(gca,'XTickLabel',[]);
ylabel('dR/R0 (%)');

ax.dwn = subplot(3,1,3);
shadedErrorBar([1:size(avg_Tmp,1)],avg_Tmp,err_Tmp,'k',0);
set(gca,'xtickMode', 'auto');
hold on; 
xline(vertline,'LineWidth', 2, 'Color', [0.5 0.5 0.5], 'LineStyle', ':');
hold off;
ylim([floor(min(avg_Tmp)-max(err_Tmp)),ceil(max(avg_Tmp)+max(err_Tmp))]);
ylim([10, 41]);
xlim([0, size(Ca,1)]);
ylabel('Temperature (celcius)','Color','k');
xlabel('Time (seconds)');
currentFigure = gcf;

title(currentFigure.Children(end), strcat(n,'_Individual Cameleon Response'),'Interpreter','none');

movegui('northeast');
setaxes = 1;
while setaxes>0 % loop through the axes selection until you're happy
    answer = questdlg('Adjust X/Y Axes?', 'Axis adjustment', 'Yes');
    switch answer
        case 'Yes'
            setaxes=1;
            vals=inputdlg({'X Min','X Max','Y Min Upper', 'Y Max Upper','Y Min Lower', 'Y Max Lower'},...
                'New X/Y Axes',[1 35; 1 35; 1 35;1 35; 1 35;1 35],{num2str(ax.up.XLim(1)) num2str(ax.up.XLim(2))  num2str(ax.up.YLim(1)) num2str(ax.up.YLim(2)) num2str(ax.dwn.YLim(1)) num2str(ax.dwn.YLim(2))});
            if isempty(vals)
                setaxes = -1;
            else
                ax.up.XLim(1) = str2double(vals{1});
                ax.up.XLim(2) = str2double(vals{2});
                ax.dwn.XLim(1) = str2double(vals{1});
                ax.dwn.XLim(2) = str2double(vals{2});
                ax.up.YLim(1) = str2double(vals{3});
                ax.up.YLim(2) = str2double(vals{4});
                ax.dwn.YLim(1) = str2double(vals{5});
                ax.dwn.YLim(2) = str2double(vals{6});
            end
        case 'No'
            setaxes=-1;
        case 'Cancel'
            setaxes=-1;
    end
end

saveas(gcf, fullfile(newdir,['/', n, '-multiplot.jpeg']),'jpeg');
saveas(gcf, fullfile(newdir,['/', n, '-multiplot.eps']),'epsc');

close all
end
