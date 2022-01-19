function hFig = view_noisecov( NoiseCovFile, Modality )
% VIEW_NOISECOV: View the noise covariance matrix as an image, normalized for each sensor type independently

% @=============================================================================
% This function is part of the Brainstorm software:
% https://neuroimage.usc.edu/brainstorm
% 
% Copyright (c) University of Southern California & McGill University
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
% Authors: Francois Tadel, 2013

% Parse inputs
if (nargin < 2) || isempty(Modality)
    Modality = [];
end

% Get study for this file
[sStudy, iStudy] = bst_get('AnyFile', NoiseCovFile);
% Read channel file
ChannelMat = in_bst_channel(sStudy.Channel.FileName);
% Get channel types
AllMod = unique({ChannelMat.Channel.Type});
% Load noise covariance file
NoiseCovMat = load(file_fullpath(NoiseCovFile));
NoiseCov = abs(NoiseCovMat.NoiseCov);

% All the sensors
if isempty(Modality)
    % Loop on the sensor type to normalize them
    for i = 1:length(AllMod)
        iChan = find(cellfun(@(c)isequal(c, AllMod{i}), {ChannelMat.Channel.Type}));
        maxMod = max(max(abs(NoiseCov(iChan,iChan))));
        if ~isempty(maxMod) && (maxMod ~= 0)
            NoiseCov(iChan,iChan) = NoiseCov(iChan,iChan) ./ maxMod;
        end
    end
% One sensor type only
else
    % Get channels corresponding to the selected modality
    iChan = find(cellfun(@(c)isequal(c, Modality), {ChannelMat.Channel.Type}));
    % Normalize and keep only this modality
    maxMod = max(max(abs(NoiseCov(iChan,iChan))));
    NoiseCov = NoiseCov(iChan,iChan) ./ maxMod;
end

% Display as image
hFig = view_image(NoiseCov, 'jet');





 
