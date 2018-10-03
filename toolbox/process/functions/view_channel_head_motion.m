function ChannelMat = view_channel_head_motion(ChannelMat)
  % Update head position for displaying 3d sensors/helmet.
  % Called from view_channel line 125
  
  % Get current time point.
  %%% ?
  Trial = 1;
  Sample = 1;
  
  % Get current head coil locations.
  %%% ?
  sInput = [];
  if strcmpi(sInput.FileType, 'raw')
    DataMat = in_bst_data(sInput.FileName, 'F');
    sFile = DataMat.F;
  else
    sFile = in_fopen(sInput.FileName, 'BST-DATA');
  end
  iHLU = find(strcmp({ChannelMat.Channel.Type}, 'HLU'));
  HeadCoilLoc = in_fread(sFile, ChannelMat, Trial, [Sample, Sample], iHLU);
  
  % Compute transformation corresponding to coil position.
  TransfMat = process_adjust_head_position('LocationTransform', ...
    HeadCoilLoc, ChannelMat);
  
  % Modify channel positions.  
  ChannelMat = channel_apply_transf(ChannelMat, TransfMat, [], false);
  
end