function isEqual = channel_isequal( ChannelFile1, ChannelFile2 )
% CHANNEL_ISEQUAL: Check equivalence between two different channel files.
% 
% USAGE:  isEqual = channel_isequal( ChannelFile1, ChannelFile2 )
%         isEqual = channel_isequal( ChannelMat1,  ChannelMat2 )

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
% Authors: Francois Tadel, 2009-2011

isEqual = 0;

% Load both channels structure
if isstruct(ChannelFile1)
    ChannelMat1 = ChannelFile1;
elseif ~file_exist(ChannelFile1)
    warning('One of the channel files do not exist. Please reload database.');
    return
else
    ChannelMat1 = in_bst_channel(ChannelFile1);
end
if isstruct(ChannelFile2)
    ChannelMat2 = ChannelFile2;
elseif ~file_exist(ChannelFile2)
    warning('One of the channel files do not exist. Please reload database.');
    return
else
    ChannelMat2 = in_bst_channel(ChannelFile2);
end

% Check MegRefCoef field
isMegRef1 = isfield(ChannelMat1, 'MegRefCoef') && ~isempty(ChannelMat1.MegRefCoef);
isMegRef2 = isfield(ChannelMat2, 'MegRefCoef') && ~isempty(ChannelMat2.MegRefCoef);
if xor(isMegRef1, isMegRef2) || (isMegRef1 && isMegRef2 && ~isequal(ChannelMat1.MegRefCoef, ChannelMat2.MegRefCoef))
    return
end

% Check number of sensors
if (length(ChannelMat1.Channel) ~= length(ChannelMat1.Channel))
    return
end

% Check sensor by sensor
for iChan = 1:length(ChannelMat1.Channel)
    Chan1 = ChannelMat1.Channel(iChan);
    Chan2 = ChannelMat2.Channel(iChan);
    if ~strcmpi(Chan1.Type, Chan2.Type) || ~isequal(size(Chan1.Loc), size(Chan2.Loc)) || (numel(Chan1.Loc) < 3) || (max(abs(Chan1.Loc(:) - Chan2.Loc(:))) > 1e-12)
        return
    end
end

% Passed all checks: files are equivalent
isEqual = 1;









