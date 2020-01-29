function Whitener = bst_whitener(NoiseCov, ChannelFile, DataTypes, ChannelFlag)
% BST_WHITENER: Compute a whitener from a NoiseCov matrix
%
% USAGE:  Whitener = bst_whitener(NoiseCov);
%         Whitener = bst_whitener(NoiseCov, ChannelFile, DataTypes, ChannelFlag);
%         Whitener = bst_whitener(NoiseCov,     Channel, DataTypes, ChannelFlag);

% @=============================================================================
% This function is part of the Brainstorm software:
% https://neuroimage.usc.edu/brainstorm
% 
% Copyright (c)2000-2020 University of Southern California & McGill University
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
% Authors: Francois Tadel, 2009-2010

% If channels definition is not provided
if (nargin < 4)
    % Use all channels
    iChan = 1:length(NoiseCov);
else
    % If channel file provided: load ChannelFile
    if ischar(ChannelFile)
        ChannelMat = in_bst_channel(ChannelFile, 'Channel');
        Channel = ChannelMat.Channel;
    % If Channel structure provided
    elseif isstruct(ChannelFile)
        Channel = ChannelFile;
    end
    % Get good channels
    iChan = good_channel(Channel, ChannelFlag, DataTypes);
end

% Detect the rows with only zero values
iZeroRow = find(sum(NoiseCov .^ 2) == 0);
% Remove those channels from list of valid channels
iChan = setdiff(iChan, iZeroRow);

% Initialize output matrix
Whitener = zeros(size(NoiseCov));
% Decomposition
[U,S] = svd(NoiseCov(iChan,iChan));
% Check matrix rank
m = length(iChan);
r = sum(diag(S) > m * S(1) * eps('double'));
if (r < m)
    error(['You have deficient data. Please:' 10 10 ...
           '1) Look for bad channels in your recordings' 10 ...
           '2) Tag them bad channels in all your recordings' 10 ...
           '3) Try automatic detection of flat channels: Right click > Good/bad channels > ...' 10 ...
           '4) Recompute the noise covariance matrix' 10, ...
           '5) Restart this proces']);
end
% Create whitener
Whitener(iChan,iChan) = pinv(U * sqrt(S));




