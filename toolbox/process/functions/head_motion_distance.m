function Distance = head_motion_distance(Locations, ChannelFile)
  % Compute continuous head distance from initial/reference position.
  % Locations contains the HLU coordinates in meters, [9, nSamples].
  % Takes into account any adjustment to the reference position that is
  % saved as a transformation.

  
  % Compute initial head location.  This isn't exactly the coil positions
  % in the .hc file, but was verified to give the same transformation.
  % Use the SCS distances from origin, with left and right PA points
  % symmetrical.
  ChannelMat = in_bst_channel(ChannelFile);
  LeftRightDist = sqrt(sum((ChannelMat.SCS.LPA - ChannelMat.SCS.RPA).^2));
  InitLoc = [[ChannelMat.SCS.NAS(1); 0; 0; 1], [0; LeftRightDist; 0; 1], ...
    [0; -LeftRightDist; 0; 1]];
  % That InitLoc is in Native coordiates.  Bring it back to Dewar
  % coordinates to compare with HLU channels.
  %
  % Take into account if the initial/reference head position was
  % "adjusted", i.e. replaced by the median position throughout the
  % recording.  If so, use all transformations between 'Dewar=>Native' to
  % this adjustment transformation.  (In practice there shouldn't be any
  % between them.)
  iAdjust = find(strcmpi(ChannelMat.TransfMegLabels, 'AdjustedNative'));
  if isempty(iAdjust) || numel(iAdjust) > 1
    bst_error('Could not find required transformation.');
  end
  iDewToNat = find(strcmpi(ChannelMat.TransfMegLabels, 'Dewar=>Native'));
  if isempty(iDewToNat) || numel(iDewToNat) > 1
    bst_error('Could not find required transformation.');
  end
  for t = iDewToNat:iAdjust
    InitLoc = ChannelMat.TransfMeg{t} \ InitLoc;
  end
  InitLoc(4, :) = [];
  InitLoc = InitLoc(:);
  
  nSamples = size(Locations, 2);
  nChannels = size(Locations, 1);
  if nChannels < 9
    bst_error('Unexpected number of head coil position channels.');
  end
  
  % Downsample head localization channels to their real sampling rate.
  % This makes the following computation much faster.
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
    HeadSamplePeriod = min(HeadSamplePeriod, min(diff(TrueSamples(1:end-1))));
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
