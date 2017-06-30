% function to plot results

% clear the workspace
clear; clc; close all;

% run the offset calculation
% run calculateChamberEffects

% load in the data
load('dir_20_13dbm_patchsource.mat');

% set the 360 azimuth value to the same as the 0 azimuth value
updatedMeas = measurementInfo.measurements;
updatedMeas(end,:,:) = updatedMeas(1,:,:);
% updatedMeas = updatedMeas - offsets;
% updatedMeas = updatedMeas.*multOffsets;

% average across all the measurements for each position
avged = mean(updatedMeas(:,:,:),3);
avgedPos = -1*avged;

% calculate useful limits
minall = floor(min(avgedPos(:)));
maxall = ceil(max(avgedPos(:)));
rlims = [minall maxall];

% plot slide of el = 90 (azimuth profile)
figure(1);
polarplot(deg2rad(measurementInfo.azimuth), avgedPos(:,end,:), 'x-');
ax = gca;
ax.ThetaDir = 'clockwise';
ax.ThetaZeroLocation = 'top';
title('sweep at el = 90');
ax.RDir = 'reverse';
ax.RLim = rlims;


% plot slice of az = 0 (elevation profile)
figure(2);
polarplot(deg2rad(measurementInfo.elevation),avgedPos(1,:,:), 'x-');
title('sweep at az = 0');
ax = gca;
ax.ThetaDir = 'clockwise';
ax.ThetaZeroLocation = 'top';
ax.RDir = 'reverse';
ax.RLim = rlims;

% plot slice of az = 0 (elevation profile)
% with averages and all the data
figure(3);
polarplot(repmat(deg2rad(measurementInfo.elevation),41,1), avgedPos, 'x');
title('all sweep at az = 0');
ax = gca;
ax.ThetaDir = 'clockwise';
ax.ThetaZeroLocation = 'top';
ax.RDir = 'reverse';
ax.RLim = rlims;

% plot slide of az = 0 (elevation profile)
% with averages of averages
figure(4);
polarplot(deg2rad(measurementInfo.elevation), mean(avgedPos), 'x-');
title('averaged sweep at az = 0');
ax = gca;
ax.ThetaDir = 'clockwise';
ax.ThetaZeroLocation = 'top';
ax.RDir = 'reverse';
ax.RLim = [floor(min(mean(avgedPos))) ceil(max(mean(avgedPos)))];


%% Phased Array toolbox plotting
% convert from phi-theta to az el
phi = measurementInfo.azimuth;
theta = measurementInfo.elevation;
patternPhiTheta = mean(updatedMeas,3)';
[pattern_azel, az, el] = phitheta2azelpat(patternPhiTheta,phi,theta);
pattern_azel(isnan(pattern_azel)) = -70;
freqVector  = [1.570 1.580].*1e9;        % Frequency range for element pattern
antenna     = phased.CustomAntennaElement('FrequencyVector',freqVector,...
                              'AzimuthAngles',az,...
                              'ElevationAngles',el,...
                              'RadiationPattern',pattern_azel);

figure(10);
fmax = freqVector(end);
pattern(antenna,fmax,'Type','powerdb');

figure(11);
pattern(antenna,fmax,[-180:180],0,'Type','powerdb');

figure(12);
pattern(antenna,fmax,0,[-90:90],'Type','powerdb');

%% Trying to characterize effects of rotation

figure(20); clf(); hold on;
numEl = length(measurementInfo.elevation);
numAz = length(measurementInfo.azimuth);
mvsum = zeros(1, numAz);
for i = 1:numEl
    mv = mean(avged(:,i));
%     plot(measurementInfo.azimuth, avged(:,i), 'x-', measurementInfo.azimuth, ones(1,numAz).*mv, '--');
    plot(measurementInfo.azimuth, avged(:,i) - mv, 'x-');
    mvsum = mvsum + (avged(:,i) - mv);
end
hold off;

mvsum = mvsum./length(measurementInfo.elevation);



