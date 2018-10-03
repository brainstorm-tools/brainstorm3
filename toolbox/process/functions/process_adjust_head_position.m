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
end



function Comment = FormatComment(sProcess) %#ok<DEFNU>
    Comment = sProcess.Comment;
end



function OutputFiles = Run(sProcess, sInputs) %#ok<INUSL,DEFNU>
  
  OutputFiles = {}; %#ok<NASGU>
  isFileOk = false(1, length(sInputs));
  for iFile = 1:length(sInputs)
    % Load head coil locations, in m.
    Locations = process_evt_head_motion('LoadHLU', sInputs(iFile));
    
    MedianLoc = MedianLocation(Locations);
    
    ChannelMat = in_bst_channel(sInputs(iFile).ChannelFile);
    
    % Compute transformation corresponding to coil position.
    TransfMat = LocationTransform(MedianLoc, ChannelMat);
    
    % Test and don't apply if it was already corrected.
    TransfDiff = TransfMat - eye(4);
    if max(TransfDiff(:)) > 1e-8
      % Apply this transformation to the current head position.
      % By giving the file as input, it will be saved.
      channel_apply_transf({sInputs(iFile).ChannelFile}, TransfMat, [], false);
    end
    
    isFileOk(iFile) = true;
  end
  
  % Return the input files that were processed properly.
  OutputFiles = {sInputs(isFileOk).FileName};
end



function TransfMat = LocationTransform(Loc, ChannelMat)
  % Compute transformation corresponding to coil position.
  
  % We want the small head adjustment transformation, but the HLU
  % channels are in dewar coordinates.  Thus apply the transformations
  % that were already applied to the data, e.g. {'Dewar=>Native'
  % 'Native=>Brainstorm/CTF'}, to the Loc before computing the new
  % transformation.
  Loc = reshape(Loc, 3, []);
  Loc(end+1, :) = 1; 
  for t = 1:numel(ChannelMat.TransfMeg)
    % Transformation matrices are in m.
    Loc = ChannelMat.TransfMeg{t} * Loc;
  end
  Loc(end, :) = [];
  sMri.SCS.NAS = Loc(1:3);
  sMri.SCS.LPA = Loc(4:6);
  sMri.SCS.RPA = Loc(7:9);
  Transf = cs_compute(sMri, 'scs');
  
  % Repackage as 4x4 matrix.
  TransfMat = eye(4);
  TransfMat(1:3,1:3) = Transf.R;
  TransfMat(1:3,4) = Transf.T;
end



function MedianLoc = MedianLocation(Locations)
  % Overall geometric median location of each head coil.

  if size(Locations, 1) ~= 9
    error('Expecting 9 HLU channels in first dimension.');
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
  % © Copyright 2018 Marc Lalancette
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
  

