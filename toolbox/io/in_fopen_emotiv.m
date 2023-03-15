function [sFile, ChannelMat] = in_fopen_emotiv(DataFile)
% IN_FOPEN_EMOTIV: Open an EmotivPRO EDF file
% 
% EmotivPro file format specification:
%   - https://emotiv.gitbook.io/emotivpro/exported_data_files/edf_files
%   - https://emotiv.gitbook.io/emotivpro/exported_data_files/csv_files
%   - https://emotiv.gitbook.io/emotivpro/exported_data_files/json_files
%
% USAGE:  [sFile, ChannelMat] = in_fopen_emotiv(DataFile)

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
% Authors: Francois Tadel, 2020

% Get file format
[fPath, fBase, fExt] = bst_fileparts(DataFile);
% Initialize events channel
Fevt = [];
Fevt2 = [];

% File format
switch lower(fExt)
    case '.edf'
        % Reading options
        ImportOptions = db_template('ImportOptions');
        % Read the EDF file header
        [sFile, ChannelMat] = in_fopen_edf(DataFile, ImportOptions);
        % Read events channels: MarkerValueInt
        iEvt1 = find(strcmpi({ChannelMat.Channel.Name}, 'markervalueint'));
        if (length(iEvt1) == 1)
            Fevt = in_fread(sFile, ChannelMat, 1, [], iEvt1, ImportOptions);
            Fevt = Fevt .* sFile.header.signal(iEvt1).gain;
            % Add hardware triggers: MARKER_HARDWARE
            iEvt2 = find(strcmpi({ChannelMat.Channel.Name}, 'marker_hardware'));
            if (length(iEvt2) == 1)
                Fevt2 = in_fread(sFile, ChannelMat, 1, [], iEvt2, ImportOptions);
                Fevt2 = Fevt2 .* sFile.header.signal(iEvt2).gain;
            end
        end
        
    case '.csv'
        error('todo');
        
    otherwise
        error(['Unknown file extension: ' fExt]);
end


% Set the correct channel types
for iChan = 1:length(ChannelMat.Channel)
    switch lower(ChannelMat.Channel(iChan).Name)
        case {'time_stamp_s', 'time_stamp_ms', 'counter', 'interpolated'}
            ChannelMat.Channel(iChan).Type = 'TIME';
        case {'raw_cq', 'highbitflex'}
            ChannelMat.Channel(iChan).Type = 'CQ';
        case {'marker_hardware', 'markerindex', 'markertype', 'markervalueint'}
            ChannelMat.Channel(iChan).Type = 'EVT';
        case 'battery'
            ChannelMat.Channel(iChan).Type = 'OTHER';
        otherwise
            if ~isempty(strfind(ChannelMat.Channel(iChan).Name, 'CQ_'))
                ChannelMat.Channel(iChan).Type = 'CQ';
            end
    end
end

% Create events
if ~isempty(Fevt) && any(Fevt ~= 0)
    % Combine two events channels
    if ~isempty(Fevt2)
        Fevt(Fevt == 0) = -Fevt2(Fevt == 0);
    end
    % List events
    uniqueEvt = setdiff(unique(Fevt), 0);
    % Initialize events structur
    events = repmat(db_template('event'), 1, length(uniqueEvt));
    % Build Brainstorm events structure
    for iEvt = 1:length(uniqueEvt)
        % Find event occurrences
        samples = find(Fevt == uniqueEvt(iEvt));
        % Label
        if (uniqueEvt(iEvt) < 0)
            events(iEvt).label = sprintf('h%d', -round(uniqueEvt(iEvt)));
        else
            events(iEvt).label = sprintf('%d', round(uniqueEvt(iEvt)));
        end
        % Time
        events(iEvt).times      = samples ./ sFile.prop.sfreq;
        events(iEvt).epochs     = ones(size(samples));
        events(iEvt).reactTimes = [];
        events(iEvt).select     = 1;
        events(iEvt).channels   = [];
        events(iEvt).notes      = [];
    end
    % Save in file structure
    sFile.events = events;
end
