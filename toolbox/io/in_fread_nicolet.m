function F = in_fread_nicolet(sFile, iEpoch, SamplesBounds, iChannels)
% IN_FREAD_NICOLET:  Read a block of recordings from a Nicolet .e file
%
% USAGE:  F = in_fread_nicolet(sFile, iEpoch, SamplesBounds=[], iChannels=[])

% @=============================================================================
% This function is part of the Brainstorm software:
% http://neuroimage.usc.edu/brainstorm
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
% Authors: Francois Tadel, 2017

% Parse inputs
if (nargin < 4) || isempty(iChannels)
    iChannels = 1:sFile.header.numchan;
end
if (nargin < 3) || isempty(SamplesBounds)
    if isempty(sFile.epochs)
        SamplesBounds = sFile.prop.samples;
    else
        SamplesBounds = sFile.epochs(iEpoch).samples;
    end
end

% % PATCH FOR UNKNOWN ERROR:
% % A user reported the obj structure not being saved correctly in the file link on MacOS, trying to reopen the Nicolet file
% % http://neuroimage.usc.edu/forums/t/error-in-loading-the-nicolet-eeg-data/4093/6
% if isempty(sFile.header.obj)
%     sFile.header.obj = NicoletFile(sFile.filename);
% end

% Read data block
F = getdata(sFile.header.obj, iEpoch, SamplesBounds + 1, sFile.header.selchan(iChannels))';

% Convert from uV to V
F = F .* 1e-6;



