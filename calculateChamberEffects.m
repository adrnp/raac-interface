% test to be able to try and remove the effects of the box on the patterns
% generated from the box - using a "known" antenna pattern

load('patchtest2.mat');

updatedMeas = measurementInfo.measurements;
updatedMeas(end,:,:) = updatedMeas(1,:,:);

% average across all the measurements for each position
avged = mean(updatedMeas(:,:,:),3);
avgedPos = -1*avged;

%%
% first going to just try with constant offsets - so each cell will contain
% a vlaue that should be added/subtracted to remove the effects

% calculate average of all values (we'll call this the truth - really bad
% estimate of the truth)
idealGain = mean(mean(avged));

offsets = avged - idealGain;


%%
% second going to try with relative offsets - so each cell will contain a
% multiplicative value

multOffsets = idealGain./avged;