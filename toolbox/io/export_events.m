function export_events(sFile, ChannelMat, OutputFile)
% EXPORT_EVENTS: Export events from a file or from the raw file viewer.
%
% USAGE:  export_events(sFile, ChannelMat=[], OutputFile)  : Get the events from sFile, save them to OutputFile
%         export_events(sFile, ChannelMat=[])              : Get the events from sFile, ask where to save them
%         export_events([], [], ...)                       : Get the events from the raw file viewer
%
% INPUT: 
%     - sFile      : Brainstorm file structure that contains the events to save
%     - ChannelMat : Only useful when saving in CTF Video Time
%     - OutputFile : Output events file

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
% Authors: Francois Tadel, 2010-2016

%% ===== PARSE INPUTS =====
global GlobalData;
% Default values
if (nargin < 3)
    OutputFile = [];
end
if (nargin < 2)
    ChannelMat = [];
end
% Get information from the raw viewer
if (nargin < 1) || isempty(sFile)
    % Get raw file viewer dataset
    [iDS, isRaw] = panel_record('GetCurrentDataset');
    if isempty(iDS)
        error('No events are currently loaded.');
    end
    % Get sFile structure
    sFile = GlobalData.DataSet(iDS).Measures.sFile;
    % Load channel file
    ChannelMat = in_bst_channel(GlobalData.DataSet(iDS).ChannelFile); 
end
% Check number of events
if isempty(sFile.events)
    error('No event available in this file.');
end


%% ===== SELECT OUTPUT FILE =====
if isempty(OutputFile)
    % === Build a default filename ===
    % Get raw path
    if isfield(sFile, 'filename') && ~isempty(sFile.filename)
        [fPath, fBase, fExt] = bst_fileparts(sFile.filename);
    else
        fPath = '';
        fBase = 'export';
    end
    % Get default directories and formats
    DefaultFormats = bst_get('DefaultFormats');
    if isempty(DefaultFormats.EventsOut)
        DefaultFormats.EventsOut = 'CTF';
    end
    % Get default extension
    switch (DefaultFormats.EventsOut)
        case 'ANYWAVE'
            OutputFile = bst_fullfile(fPath, [fBase, '.mrk']);
        case 'BST'
            OutputFile = bst_fullfile(fPath, ['events_' fBase '.mat']);
        case 'BRAINAMP'
            OutputFile = bst_fullfile(fPath, [fBase, '.vmrk']);
        case 'CTF'
            OutputFile = bst_fullfile(fPath, 'MarkerFile-bst.mrk');
        case 'FIF'
            OutputFile = bst_fullfile(fPath, [fBase, '.eve']);
        case 'GRAPH'
            OutputFile = bst_fullfile(fPath, ['events_' fBase, '.evl']);
        case {'ARRAY-TIMES', 'ARRAY-SAMPLES'}
            OutputFile = bst_fullfile(fPath, [file_standardize(sFile.events(1).label), '.txt']);
        case 'CSV-TIME'
            OutputFile = bst_fullfile(fPath, [fBase, '.csv']);
        case 'CTFVIDEO'
            OutputFile = bst_fullfile(fPath, 'video_events.txt');
        otherwise
            OutputFile = bst_fullfile(fPath, [fBase, '.eve']);
    end

    % === Ask filename ===
    [OutputFile, FileFormat] = java_getfile( 'save', ...
        'Export events...', ...  % Window title
        OutputFile, ...          % Default filename
        'single', 'files', ...   % Selection mode
        bst_get('FileFilters', 'eventsout'), ...
         DefaultFormats.EventsOut);
    % If no file was selected: exit
    if isempty(OutputFile)
        return
    end
    % Save default export format
    DefaultFormats.EventsOut = FileFormat;
    bst_set('DefaultFormats',  DefaultFormats);
else
    % Detect output file format
    [fPath, fBase, fExt] = bst_fileparts(OutputFile);
    switch(fExt)
        case '.mat',   FileFormat = 'BST';
        case '.vmrk',  FileFormat = 'BRAINAMP';
        case '.mrk',   FileFormat = 'CTF';
        case '.eve',   FileFormat = 'FIF';
        case '.evl',   FileFormat = 'GRAPH_ALT';
        case '.txt',   FileFormat = 'ARRAY-TIMES';
        case '.csv',   FileFormat = 'CSV-TIME';
    end
end


%% ===== SAVE EVENTS FILE =====
% Show progress bar
bst_progress('start', 'Export events', 'Saving file...');
% Switch between file formats
switch FileFormat
    case 'ANYWAVE'
        out_events_anywave(sFile, OutputFile);
    case 'BST'
        s.events = sFile.events;
        bst_save(OutputFile, s, 'v7');
    case 'BRAINAMP'
        out_events_brainamp(sFile, OutputFile);
    case 'CTF'
        out_events_ctf(sFile, OutputFile);
    case 'FIF'
        if strcmpi(OutputFile(end-4:end), '.fif')
            OutputFile(end-4:end) = '.eve';
        end
        out_events_eve(sFile, OutputFile);
    case 'GRAPH_ALT' 
        out_events_graph(sFile, OutputFile,'alternativeStyle');
    case 'CSV-TIME'
        out_events_csv(sFile, OutputFile);
    case 'ARRAY-TIMES'
        if (length(sFile.events) > 1)
            error('Cannot export more than one event at a time with this format.');
        end
        eve = sFile.events.times;
        strEve = sprintf(['%6.6f' 10], eve);
        % Save file
        fid = fopen(OutputFile, 'w');
        fwrite(fid, strEve, 'char');
        fclose(fid);
    case 'ARRAY-SAMPLES'
        if (length(sFile.events) > 1)
            error('Cannot export more than one event at a time with this format.');
        end
        eve = round(sFile.events.times * sFile.prop.sfreq);
        strEve = sprintf(['%d' 10], round(eve));
        % Save file
        fid = fopen(OutputFile, 'w');
        fwrite(fid, strEve, 'char');
        fclose(fid);
    case 'CTFVIDEO'
        out_events_video(sFile, ChannelMat, OutputFile);
    otherwise
        error(['Unsupported file format : "' FileFormat '"']);
end
% Hide progress bar
bst_progress('stop');






