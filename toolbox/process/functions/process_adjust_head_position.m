function varargout = process_adjust_head_position(varargin)
  %
  
  % @=============================================================================
  % This function is part of the Brainstorm software:
  % https://neuroimage.usc.edu/brainstorm
  %
  % Copyright (c)2000-2018 University of Southern California & McGill University
  % This software is distributed under the terms of the GNU General Public License
  % as published by the Free Software Foundation. Further details on the GPLv3
  % license can be found at http://www.gnu.org/copyleft/gpl.html.
  %
  % FOR RESEARCH PURPOSES ONLY. THE SOFTWARE IS PROVIDED "AS IS," AND THE
  % UNIVERSITY OF SOUTHERN CALIFORNIA AND ITS COLLABORATORS DO NOT MAKE ANY
  % WARRANTY, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO WARRANTIES OF
  % MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE, NOR DO THEY ASSUME ANY
  % LIABILITY OR RESPONSIBILITY FOR THE USE OF THIS SOFTWARE.
  %
  % For more information type "brainstorm license" at command prompt.
  % =============================================================================@
  %
  % Authors: Marc Lalancette, 2018
  
  eval(macro_method);
end



function sProcess = GetDescription() %#ok<DEFNU>
  % Description of the process
  sProcess.Comment     = 'Adjust head position (CTF)';
  sProcess.Description = 'https://neuroimage.usc.edu/brainstorm/Tutorials/HeadPosition';
  sProcess.Category    = 'Custom';
  sProcess.SubGroup    = 'Events';
  sProcess.Index       = 70;
  % Definition of the input accepted by this process
  sProcess.InputTypes  = {'raw', 'data'};
  sProcess.OutputTypes = {'raw', 'data'};
  sProcess.nInputs     = 1;
  sProcess.nMinFiles   = 1;
  % Option [to do: ignore bad segments]
  sProcess.options.warning.Comment = 'Only for CTF MEG recordings with HLC channels recorded.<BR><BR>';
  sProcess.options.warning.Type    = 'label';
  sProcess.options.action.Type     = 'radio_label';
  sProcess.options.action.Comment  = {'Adjust head position to median location.', ...
    'Remove last position correction (using median or head points).'; 'Adjust', 'Undo'};
  sProcess.options.action.Value    = 'Adjust';
  sProcess.options.display.Type    = 'checkbox';
  sProcess.options.display.Comment = 'Display "before" and "after" alignment figures.';
  sProcess.options.display.Value   = 1;
end



function Comment = FormatComment(sProcess)
    Comment = sProcess.Comment;
end



function OutputFiles = Run(sProcess, sInputs) 
  
  isDisplay = sProcess.options.display.Value;
  nFiles = length(sInputs);
  
  isFileOk = false(1, nFiles);
  if isDisplay
    % We can't do before/after because the figure updates when we draw the
    % second one.
    hFigAfter = [];
    hFigBefore = [];
  end
  switch sProcess.options.action.Value
    case 'Adjust'
      if isDisplay
        bst_memory('UnloadAll', 'Forced'); % Close all the existing figures. (Including progress?)
      end
      bst_progress('start', 'Adjust head position', 'Loading HLU locations...', 0, 2*nFiles);
      for iFile = 1:nFiles
        if isDisplay
          % Display "before" results.
          close(hFigBefore); %, hFigAfter]);
          hFigBefore = channel_align_manual(sInputs(iFile).ChannelFile, 'MEG', 0);
          % Need to "disconnect" this figure now so it doesn't update when
          % we save the channel file.
        end
        
        % First, verify if this has already been done.  If a user changed
        % the data such that the head position could be readjusted (e.g. by
        % deleting segments), then the previous adjustment should be
        % removed.
        ChannelMat = in_bst_channel(sInputs(iFile).ChannelFile);
        if any(strcmp(ChannelMat.TransfMegLabels, 'AdjustedNative'))
          fprintf('Head position already adjusted. Undo first if you wish to adjust again.\n');
          bst_progress('inc', 2);
          continue;
        end
        
        % Load head coil locations, in m.
        bst_progress('text', 'Loading HLU locations...');
        bst_progress('inc', 1);
        Locations = process_evt_head_motion('LoadHLU', sInputs(iFile), [], false);
        bst_progress('text', 'Correcting position...');
        bst_progress('inc', 1);
        % If a collection was aborted, the channels will be filled with
        % zeros. We must remove these locations.
        % This reshapes to continuous if in epochs, but works either way.
        Locations(:, all(Locations == 0, 1)) = [];
        
        MedianLoc = MedianLocation(Locations);
        %         disp(MedianLoc);
        
        % Compute transformation corresponding to coil position.
        if ~strcmp(ChannelMat.TransfMegLabels{1}, 'Dewar=>Native')
          bst_error('Dewar=>Native transformation not first.');
        end
        TransfMat = LocationTransform(MedianLoc, ChannelMat.TransfMeg);
        % This transformation would be identical even if the process was
        % allowed to run multiple times; it would not automatically give an
        % identity transformation. So "over-adjusting" is prevented by
        % checking for our specific label above.
        
        % Apply this transformation to the current head position.
        % This is a correction to the 'Dewar=>Native' transformation so it
        % applies to MEG channels only.
        iMeg  = sort([good_channel(ChannelMat.Channel, [], 'MEG'), ...
          good_channel(ChannelMat.Channel, [], 'MEG REF')]);
        ChannelMat = channel_apply_transf({sInputs(iFile).ChannelFile}, ...
          TransfMat, iMeg, false); % Don't apply to head points.
        ChannelMat = ChannelMat{1};
        % Change transformation label to something unique to this process.
        ChannelMat.TransfMegLabels{end} = 'AdjustedNative';
        bst_save(file_fullpath(sInputs(iFile).ChannelFile), ChannelMat, 'v7');
        isFileOk(iFile) = true;

        if isDisplay
          % Display "after" results, besides the "before" figure.
          close(hFigAfter);
          hFigAfter = channel_align_manual(sInputs(iFile).ChannelFile, 'MEG', 0);
        end
        bst_progress('stop');
      end
      
    case 'Undo'
      for iFile = 1:nFiles
        if isDisplay
          % Display "before" results.
          close(hFigBefore); %, hFigAfter]);
          hFigBefore = channel_align_manual(sInputs(iFile).ChannelFile, 'MEG', 0);
        end
        ChannelMat = in_bst_channel(sInputs(iFile).ChannelFile);
        
        nTransf = numel(ChannelMat.TransfMeg);
        isHeadPoints = false;
        isEEG = 0;
        iEEG = sort([good_channel(ChannelMat.Channel, [], 'EEG'), ...
          good_channel(ChannelMat.Channel, [], 'SEEG'), good_channel(ChannelMat.Channel, [], 'ECOG')]);
        switch ChannelMat.TransfMegLabels{nTransf}
          case {'AdjustedNative', 'manual correction'}
            iChan = sort([good_channel(ChannelMat.Channel, [], 'MEG'), ...
              good_channel(ChannelMat.Channel, [], 'MEG REF')]);
            % Check if EEG has the same last transformation.
            if strcmp(ChannelMat.TransfMegLabels{nTransf}, ChannelMat.TransfEegLabels{end}) && ...
                max(ChannelMat.TransfEeg{end}(:) - ChannelMat.TransfMeg{nTransf}(:)) > 1e-8
              if ~isempty(iEEG)
                iChan = [iChan, iEEG]; %#ok<AGROW>
                isEEG = 2;
              else
                isEEG = 1;
              end
            end
          case 'refine registration: head points'
            isHeadPoints = true;
            % This applies to all channels and is "listed" under TransfEeg
            % even if there are no EEG channels.
            iChan = [];
            if ~isempty(iEEG)
              isEEG = 2;
            else
              isEEG = 1;
            end
          otherwise
            fprintf('BST> No position correction found for %s.\n', sInputs(iFile).FileName);
            continue;
        end
          
        % Apply inverse transformation.
        ChannelMat = channel_apply_transf(ChannelMat, ...
          inv(ChannelMat.TransfMeg{nTransf}), iChan, isHeadPoints);
        ChannelMat = ChannelMat{1};
        % Remove last two tranformations that cancel each other.
        ChannelMat.TransfMegLabels(nTransf:end) = [];
        ChannelMat.TransfMeg(nTransf:end) = [];
        if isEEG
          % The inverse transformation is there only if there are EEG
          % channels.  But others can be there even in that case, e.g.
          % 'refine registration: head points'.
          ChannelMat.TransfEegLabels(end+1-isEEG:end) = [];
          ChannelMat.TransfEeg(end+1-isEEG:end) = [];
        end
        
        bst_save(file_fullpath(sInputs(iFile).ChannelFile), ChannelMat, 'v7');
        
        isFileOk(iFile) = true;
        if isDisplay
          % Display results.
          close(hFigAfter);
          hFigAfter = channel_align_manual(sInputs(iFile).ChannelFile, 'MEG', 0);
        end
      end
      
  end
  
  % Return the input files that were processed properly.
  OutputFiles = {sInputs(isFileOk).FileName};
end



function TransfMat = LocationTransform(Loc, TransfMeg)
  % Compute transformation corresponding to head coil positions.
  % We want this to be as efficient as possible, since used many times by
  % process_sss. 
  
  % The HLU channels are in dewar coordinates.  Thus apply the
  % transformations 'Dewar=>Native' and then compute the small head
  % position adjustment.  For efficiency, we should verify that this
  % transformation is first, outside this function.
  % Transformation matrices are in m, as are HLU channels.
  Loc = TransfMeg{1}(1:3, :) * [reshape(Loc, 3, 3); 1, 1, 1];

  % For efficiency, use these local functions.
  CrossProduct = @(a, b) [a(2).*b(3)-a(3).*b(2); a(3).*b(1)-a(1).*b(3); a(1).*b(2)-a(2).*b(1)];
  Norm = @(a) sqrt(sum(a.^2));
  
  Origin = (Loc(4:6)' + Loc(7:9)') / 2;
  X = Loc(1:3)' - Origin;
  X = X / Norm(X);
  Y = Loc(4:6)' - Origin; % Not yet perpendicular to X in general.
  Z = CrossProduct(X, Y);
  Z = Z / Norm(Z); 
  Y = CrossProduct(Z, X); % Doesn't go through ears anymore in general.
  %     Y = Y / Norm(Y); % Not necessary
  TransfMat = eye(4);
  TransfMat(1:3,1:3) = [X, Y, Z]';
  TransfMat(1:3,4) = - [X, Y, Z]' * Origin;

  % "Insert" this transformation at the right spot, i.e. right after
  % 'Dewar=>Native'. The following transformations, e.g.
  % 'Native=>Brainstorm/CTF' need to be removed and reapplied after.
  U = eye(4);
  for t = 2:numel(TransfMeg)
    U = U * TransfMeg{t};
  end
  TransfMat = U * TransfMat / U;
end



function MedianLoc = MedianLocation(Locations)
  % Overall geometric median location of each head coil.

  if size(Locations, 1) ~= 9
    bst_error('Expecting 9 HLU channels in first dimension.');
  end
  
  nSxnT = size(Locations, 2) * size(Locations, 3);
  MedianLoc = GeoMedian( ...
    permute(reshape(Locations, [3, 3, nSxnT]), [3, 1, 2]), 1e-3 );
  MedianLoc = reshape(MedianLoc, [9, 1]);
  
end % MedianLocation



function M = GeoMedian(X, Precision)
  % Geometric median of a list of points in d dimensions.
  %
  % M = GeoMedian(X, Precision)
  %
  % Calculate the geometric median: the point that minimizes sum of
  % Euclidean distances to all points.  size(X) = [n, d, ...], where n is
  % the number of data points, d is the number of components for each point
  % and any additional array dimension is treated as independent sets of
  % data and a median is calculated for each element along those dimensions
  % sequentially; size(M) = [1, d, ...].  This is an approximate iterative
  % procedure that stops once the desired precision is achieved.  If
  % Precision is not provided, 1e-4 of the max distance from the centroid
  % is used.
  % 
  % Weiszfeld's algorithm is used, which is a subgradient algorithm; with
  % (Verdi & Zhang 2001)'s modification to avoid non-optimal fixed points
  % (if at any iteration the approximation of M equals a data point).
  %
  % 
  % © Copyright 2018 Marc Lalancetteerror
  % The Hospital for Sick Children, Toronto, Canada
  % 
  % This file is part of a free repository of Matlab tools for MEG 
  % data processing and analysis <https://gitlab.com/moo.marc/MMM>.
  % You can redistribute it and/or modify it under the terms of the GNU
  % General Public License as published by the Free Software Foundation,
  % either version 3 of the License, or (at your option) a later version.
  % 
  % This program is distributed WITHOUT ANY WARRANTY. 
  % See the LICENSE file, or <http://www.gnu.org/licenses/> for details.
  % 
  % 2012-05

  nDims = ndims(X);
  XSize = size(X);
  n = XSize(1);
  d = XSize(2);
  if nDims > 3
    nSets = prod(XSize(3:nDims));
    X = reshape(X, [n, d, prod(XSize(3:nDims))]);
  elseif nDims == 3
    nSets = XSize(3);
  else
    nSets = 1;
  end
  
  % For better stability, center and normalize the data.
  Centroid = mean(X, 1);
  Scale = max(max(abs(X), [], 1), [], 2); % [1, 1, nSets]
  X = bsxfun(@rdivide, bsxfun(@minus, X, Centroid), Scale); % (X - Centroid(ones(n, 1), :, :)) ./ Scale(ones(n, 1), ones(d, 1), :);
  
  if ~exist('Precision', 'var') || isempty(Precision)
    Precision = 1e-4 * ones(1, 1, nSets);
  else
    Precision = bsxfun(@rdivide, Precision, Scale); % Precision ./ Scale; % [1, 1, nSets]
  end
  
  % Initial estimate: median in each dimension separately.  Though this
  % gives a chance of picking one of the data points, which requires
  % special treatment.
  M2 = median(X, 1);
  
  % It might be better to calculate separately each independent set,
  % otherwise, they are all iterated until the worst case converges.
  for s = 1:nSets
    
    % For convenience, pick another point far enough so the loop will always
    % start.
    M = bsxfun(@plus, M2(:, :, s), Precision(:, :, s));
    % Iterate.
    while  sum((M - M2(:, :, s)).^2 , 2) > Precision(s)^2  % any()scalar
      M = M2(:, :, s); % [n, d]
      % Distances from M.
      %       R = sqrt(sum( (M(ones(n, 1), :) - X(:, :, s)).^2 , 2 )); % [n, 1]
      R = sqrt(sum( bsxfun(@minus, M, X(:, :, s)).^2 , 2 )); % [n, 1]
      % Find data points not equal to M, that we use in the computation
      % below.
      Good = logical(R);
      nG = sum(Good);
      if nG % > 0
        %       D = sum( (M(ones(nG, 1), :) - X(Good, :, s)) ./ R(Good, ones(d, 1)) , 1 ); % [1, d, 1]
        D = sum( bsxfun(@rdivide, bsxfun(@minus, M, X(Good, :, s)), R(Good)) , 1 ); % [1, d, 1]
        %       DNorm = sqrt(sum( D.^2 , 2 )); % scalar
        %       W = sum(1 ./ R, 1); % scalar. Sum of "weights" (in one viewpoint of this problem).
      else % all points are in the same location 
        % Above formula would give error due to second bsxfun on empty.
        D = 0;
      end
      
      % New estimate. 
      % Note the possibility of D = 0 and (n - nG) = 0, in which case 0/0
      % should be 0, but here gives NaN, which the max function ignores,
      % returning 0 instead of 1. This is fine however since this
      % multiplies D (=0 in that case).
      M2(:, :, s) = M - max(0, 1 - (n - nG)/sqrt(sum( D.^2 , 2 ))) * ...
        D / sum(1 ./ R, 1);
    end
    
  end
  
  % Go back to original space and shape.
  %   M = M2 .* Scale(1, ones(d, 1), :) + Centroid;
  M = bsxfun(@times, M2, Scale) + Centroid;
  if nDims > 3
    M = reshape(M, [1, XSize(2:end)]);
  end
  
end % GeoMedian
  

