function Distance = head_motion_distance(Locations, ChannelFile)
  % Compute continuous head distance from initial/reference position.
  % Locations contains the HLU coordinates in meters.

  
  % Compute initial head location.  This isn't exactly the coil positions
  % in the .hc file, but was verified to give the same transformation.
  % Use the SCS distances from origin, with left and right PA points
  % symmetrical.
  ChannelMat = in_bst_channel(ChannelFile);
  iTrans = find(strcmpi(ChannelMat.TransfMegLabels, 'Dewar=>Native'));
  if isempty(iTrans)
    error('Could not find required transformation.');
  end
  
  LeftRightDist = sqrt(sum((ChannelMat.SCS.LPA - ChannelMat.SCS.RPA).^2));
  InitLoc = [[ChannelMat.SCS.NAS(1); 0; 0; 1], [0; LeftRightDist; 0; 1], ...
    [0; -LeftRightDist; 0; 1]];
  InitLoc = ChannelMat.TransfMeg{iTrans} \ InitLoc;
  InitLoc(4, :) = [];
  InitLoc = InitLoc(:);
        
  nSamples = size(Locations, 2);
  nChannels = size(Locations, 1);
  if nChannels < 9
    error('Unexpected number of head coil position channels.');
  end
  
  % Downsample head localization channels to their real sampling rate.
  % HeadSamplePeriod is in (MEG) samples per (head) sample, not seconds.
  HeadSamplePeriod = nSamples; % Initialized to at least 1 point per epoch.
  % To find real localization sampling rate, look for changes in data, but
  % it seems it's common to get repeated values (code must have some
  % condition where it just keeps the same value), so we need to verify
  % carefully.  First, find times of changes.  This already ignores the
  % first few samples until the first change.
  TrueSamples = find(any(diff(Locations, 1, 2), 1)) + 1;
  % Then get the time intervals between these changes, and find the
  % smallest "step" between these intervals.  E.g. if we got intervals of
  % 80, 120, 240 samples, the smallest difference between these would be
  % 40, which is the sampling period we were looking for.
  if numel(TrueSamples) > 1 % to avoid empty which propagates in min.
    HeadSamplePeriod = min(HeadSamplePeriod, min(diff(TrueSamples)));
  end
  % Downsample.
  Locations = Locations(:, 1:HeadSamplePeriod:nSamples);
  %   nS = ceil(nS / HeadSamplePeriod);
  
  % Compute distance
  DistDowns = process_evt_head_motion('RigidDistances', Locations, InitLoc)';

  % Upsample back to MEG sampling rate.
  Distance = interp1(DistDowns, (1:nSamples)/HeadSamplePeriod);
  % Replace initial NaNs with first value.
  Distance(isnan(Distance)) = Distance(find(~isnan(Distance), 1));
  
end
