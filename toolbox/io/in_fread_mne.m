function [F,TimeVector] = in_fread_mne(sFile, ChannelMat, iEpoch, SamplesBounds, iChannels)
% IN_READ_MNE:  Read a block of recordings from a MNE-Python object
%
% USAGE:  [F,TimeVector] = in_fread_mne(sFile, ChannelMat, iEpoch, SamplesBounds, iChannels)
%         [F,TimeVector] = in_fread_mne(sFile, ChannelMat, iEpoch, SamplesBounds)            : Read all the channels

% @=============================================================================
% This function is part of the Brainstorm software:
% https://neuroimage.usc.edu/brainstorm
% 
% Copyright (c)2000-2019 University of Southern California & McGill University
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
% Authors: Francois Tadel, 2019

% Get reference to python object
pyObj = sFile.filename;
% List of channels
if (nargin < 5) || isempty(iChannels)
    picks = 'all';
else
    picks = {ChannelMat.Channel(iChannels).Name};
end
% Times
FileBounds = [bst_py2mat(pyObj.first_samp), bst_py2mat(pyObj.last_samp)];
if (nargin < 4) || isempty(SamplesBounds)
    SamplesBounds = FileBounds;
end

% Raw data
% if ~py.isinstance(pyObj, py.sys.modules{'mne.io'}.BaseRaw) || strcmpi(class(pyObj), 'py.mne.io.fiff.raw.Raw')
if ismethod(pyObj, 'get_data')
    % Call reading function
    res = pyObj.get_data(pyargs('picks', picks, 'start', int32(SamplesBounds(1) - FileBounds(1)), 'stop', int32(SamplesBounds(2) - FileBounds(1) + 1), 'return_times', true));
    F = bst_py2mat(res{1});
    TimeVector = bst_py2mat(res{2}) + sFile.prop.times(1);
    
% Epoched data
else
    error('todo');
%     % Use data already read
%     if isfield(sFile.header, 'epochData') && ~isempty(sFile.header.epochData)
%         F = permute(sFile.header.epochData(iEpoch,:,:), [2,3,1]);
%         TimeVector = linspace(sFile.epochs(iEpoch).times(1), sFile.epochs(iEpoch).times(2), size(F,2));
%     % Read data from file
%     else
%         [F, TimeVector] = fif_read_evoked(sFile, sfid, iEpoch);
%     end
%     % Specific selection of channels
%     if ~isempty(iChannels)
%         F = F(iChannels, :);
%     end
%     % Specific time selection
%     if ~isempty(SamplesBounds)
%         iTime = SamplesBounds - round(sFile.epochs(iEpoch).times(1) .* sFile.prop.sfreq) + 1;
%         F = F(:, iTime(1):iTime(2));
%         TimeVector = TimeVector(iTime(1):iTime(2));
%     end
end


