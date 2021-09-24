function [SplitFileNames, SplitNbEvents] = egi_split_raw(RawFileName, MaxFileSizeMo, EventDelimiter)
% EGI_SPLIT_RAW: Split an EGI RAW binary file in many RAW files with a limited size.
% Auto-detect .EVT and .EPOC file and also split them
% 
% USAGE: [SplitFileNames, SplitNbEvents] = egi_split_raw(RawFileName, MaxFileSizeMo, EventDelimiter)
%        [SplitFileNames, SplitNbEvents] = egi_split_raw(RawFileName, MaxFileSizeMo)
%
% INPUT:
%    - RawFileName    : Name of the EGI simple binary format file.
%                       Format: Unsegmented RAW binary format (version #2, 4 or 6)
%    - MaxFileSizeMo  : [double]  Maximum split files size, in MegaBytes
%    - EventDelimiter : [4 chars] Name of event used to separate coherent data blocks in RAW files (4 chars).
%                       Split will occur just before the <EventDelimiter> event following the 
%                       size limit (MaxFileSizeMo).
%                       If not specified, split exactly at MaxFileSizeMo.
% OUTPUT:
%    - SplitFileNames : [cell array of strings] Names of files produced by the function
%    - SplitNbEvents  : [array of int] Number of events 'EventDelimiter' present in each file 
%
% NOTE:
%    - At the beginning of each created file except the first one:
%      an empty sample is added (without data, without events)
%      => the delimiter event in present only in the second sample
%      Cause: many softwares do not read the events of the first sample...

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
% Authors: Francois Tadel, 2008
% ----------------------------- Script History ---------------------------------
% FT  24-Jun-2008  Creation
% ------------------------------------------------------------------------------

%% ===== PARSE INPUTS =====
% === Number and type of arguments ===
if (nargin < 2) || (nargin > 3) || ~ischar(RawFileName) || ~isnumeric(MaxFileSizeMo)
    error('Brainstorm:BadFunctionCall', 'Invalid call to egi_splitRaw().');
elseif ~exist(RawFileName, 'file')
    error('Brainstorm:BadFunctionCall', ['RAW file not found "' strrep(RawFileName,'\','\\') '"']);
elseif isempty(MaxFileSizeMo) || (MaxFileSizeMo < 0)
    error('Brainstorm:BadFunctionCall', 'Second argument must be the maximum file size in Megabytes (Mb).');
elseif (nargin < 3)
    EventDelimiter = [];
end

% === RAW file ===
[rawPath, rawBase, rawExt] = bst_fileparts(RawFileName);

% === .EPOCH file ===
% EpochFileName = bst_fullfile(rawPath, [rawBase '.epoc']);
% if ~exist(EpochFileName, 'file')
%     EpochFileName = [];
% end

% === .EVT file ===
EventFileName = bst_fullfile(rawPath, [rawBase '.evt']);
if ~exist(EventFileName, 'file')
    % Try to find one (and only one) .evt file in the directory
    fileList = dir(bst_fullfile(rawPath, '*.evt'));
    if (length(fileList) == 1)
        EventFileName = bst_fullfile(rawPath, fileList.name);
    else
        EventFileName = [];
    end
end



%% ===== READ FILE HEADER =====
% Open RAW file
fidSrc = fopen(RawFileName, 'r', 'b');
if (fidSrc == -1)
    error('Brainstorm:InvalidRawFile', ['Cannot open RAW file: ' strrep(RawFileName,'\','\\') '"']);
end
% Read file header
headerSrc = egi_read_header(fidSrc);
% Check version number
switch headerSrc.versionNumber
    case {2, 4, 6}
        % OK
    case {3, 5, 7}
        fclose(fidSrc);
        error('Brainstorm:InvalidRawFile', ['EGI RAW file does not contain UNSEGMENTED EEG data: "' strrep(RawFileName,'\','\\') '"']);
end
% Check if there are events
if (headerSrc.numEvents == 0)
    fclose(fidSrc);
    error('Brainstorm:InvalidRawFile', 'Function can segment only RAW epoch-marked EGI files.');
end

% Get data precision
switch headerSrc.versionNumber
   case 2
       precision = 'integer*2';  % Integer
   case 4
       precision = 'real*4';  % Single Precision Real
   case 6
       precision = 'real*8';  % Double Precision Real
end
% Find EventDelimiter event in events list
if ~isempty(EventDelimiter)
    iEventDelimiter = find(strcmpi(headerSrc.eventCodes, EventDelimiter), 1);
    if isempty(iEventDelimiter)
        availableEvents = '';
        for iEvent = 1:headerSrc.numEvents
            availableEvents = [availableEvents, ' ', '"' headerSrc.eventCodes{iEvent} '"'];
        end
        fclose(fidSrc);
        error('Brainstorm:InvalidArgument', ['No "' EventDelimiter '" event in target RAW file.\nAvailable events are:', availableEvents,'.']);
    end
else
    iEventDelimiter = [];
end


%% ===== SPLIT RAW FILE =====
% Initialization
SplitFileNames = {};
SplitNbEvents  = [];
SplitNbSamples = [];
iSplitFile = 0;
fidDest = [];
startNewFile = 1;
valueByteSize = str2double(precision(end));
MaxSamplesNb = MaxFileSizeMo * 1024 * 1024 / valueByteSize / (headerSrc.numEvents + headerSrc.numChans);

% Waitbar
progressBlockSize = round(headerSrc.numSamples/100);
bst_progress('start', 'Split EGI RAW recordings', ['Split "', rawBase, rawExt, '"...'], 0, 100);
% Loop on each time sample
for iSample = 1:headerSrc.numSamples
    % === READ A SOURCE SAMPLE ===
    % Read sample data
    [sampleData, eegTempCount] = fread(fidSrc, headerSrc.numChans, precision);
    % Read sample events structure
    [sampleEvents, eventTempCount] = fread(fidSrc, headerSrc.numEvents, precision);
    % Check file integrity
    if (eegTempCount ~= headerSrc.numChans) || (eventTempCount ~= headerSrc.numEvents) 
        bst_progress('stop');
        error('Brainstorm:InvalidFile', 'Incomplete RAW file');
    end
    
    % If delimiter event is found (or no events constraints)
    if (isempty(iEventDelimiter) || (sampleEvents(iEventDelimiter) ~= 0))
        % If max number of samples is reached : new file
        if ~isempty(SplitNbSamples) && (SplitNbSamples(iSplitFile) >= MaxSamplesNb * .98)
            startNewFile = 1;
        end
    end
        
    % === CLOSE PREVIOUS FILE ===
    % Event delimiter found and not first sample
    if (startNewFile && (iSample ~= 1))
        egiCloseFile();
    end
        
    % === START NEW FILE ===
    % Event delimiter found, or first sample
    if startNewFile || (iSample == 1)
        % Create new filename
        iSplitFile = iSplitFile + 1;
        newBase = sprintf('%s_%03d%s', rawBase, iSplitFile, rawExt);
        SplitFileNames{iSplitFile} = bst_fullfile(rawPath, newBase);
        SplitNbSamples(iSplitFile) = 0;
        SplitNbEvents(iSplitFile) = 0;
        % Update progress bar text
        bst_progress('text', ['Writing file: "' newBase '"...']);
        % Open file for output
        fidDest = fopen(SplitFileNames{iSplitFile}, 'wb', 'b');
        if (fidDest == -1)
            bst_progress('stop');
            error('Brainstorm:InvalidRawFile', ['Cannot open RAW file: ' strrep(SplitFileNames{iSplitFile},'\','\\') '"']);
        end
        % Write EGI RAW headerSrc in the file
        egi_write_header(fidDest, headerSrc);
        
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%% CHEAT: ADDING AN EMPTY SAMPLE 
%%%%%%% ELSE THE FIRST EVENT IS NOT READ BY MOST OF THE SOFTWARES 
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % Write an empty sample
        fwrite(fidDest, sampleData, precision);
        fwrite(fidDest, zeros(size(sampleEvents)), precision);
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

        startNewFile = 0;
    end
    
    % Increment number of events
    if (~isempty(iEventDelimiter) && (sampleEvents(iEventDelimiter) ~= 0))
        % Count this event
        SplitNbEvents(iSplitFile) = SplitNbEvents(iSplitFile) + 1;
    end
    
    % === WRITE DATA SAMPLE ===
    % Write measures
    fwrite(fidDest, sampleData, precision);
    % Write events array
    fwrite(fidDest, sampleEvents, precision);
    % Increment number of samples of current file
    SplitNbSamples(iSplitFile) = SplitNbSamples(iSplitFile) + 1;
    
    % Increment progress bar
    if (mod(iSample,progressBlockSize) == 0)
        bst_progress('inc', 1);
    end
end
    
% Close last output file
egiCloseFile();
% Close input file
fclose(fidSrc);


%% ===== SPLIT .EVT FILE =====
% Only if an EventDelimiter is specified
if ~isempty(EventFileName) && ~isempty(EventDelimiter)
    bst_progress('text', 'Split event file...');
    % Read whole input .evt file (ASCII file)
    % => 2 header lines : one with the corresponding data filename, the other with column names
    % => then one line per event
    fidEvtSrc = fopen(EventFileName, 'r');
    if (fidEvtSrc == -1)
        bst_progress('stop');
        warning('Brainstorm:InvalidFile', ['Cannot open input event file "' EventFileName '"']);
        return;
    end
    strEvt = fread(fidEvtSrc, '*char')';
    fclose(fidEvtSrc);
    % Split string: one cell per line
    listEvt = strSplit(strEvt, sprintf('\n'));

    % Initialize loop
    newEvtFile = [];
    iNewEvtFile = 0;
    currentNbEvent = 0;
    startNewFile = 1;
    fidEvtDest = -1;
    % Loop on each file line (each event)
    for iEvent = 3:length(listEvt)
        % === COUNT EVENTS ===
        % If line begin with the target event name
        if (length(listEvt{iEvent}) >= 4) && (strcmpi(listEvt{iEvent}(1:4), EventDelimiter))
            % If max number for this file is reached: close file and start another one
            if (iNewEvtFile <= 0) || (currentNbEvent > SplitNbEvents(iNewEvtFile))
                startNewFile = 1;
            end
        end
        
        % === CLOSE PREVIOUS FILE ===
        if startNewFile && (fidEvtDest ~= -1)
            fclose(fidEvtDest);
        end
        % === START NEW FILE ===
        if startNewFile || (fidEvtDest == -1)
            % Reinit counters
            iNewEvtFile = iNewEvtFile + 1;
            startNewFile = 0;
            currentNbEvent = 1;
            % Build filename
            [fPath, fBase, fExt] = bst_fileparts(SplitFileNames{iNewEvtFile});
            newEvtFile = bst_fullfile(fPath, [fBase, '.evt']);
            % Create file
            fidEvtDest = fopen(newEvtFile, 'w');
            if (fidEvtDest == -1)
                bst_progress('stop');
                error('Brainstorm:InvalidFile', ['Cannot open output event file "' EventFileName '"']);
            end
            % Write header into file
            fwrite(fidEvtDest, sprintf('%s\n%s\n', [fBase, fExt], listEvt{2}));
        end
        
        % SEPARATOR FOUND : Count this event in the current file counter
        if (length(listEvt{iEvent}) >= 4) && (strcmpi(listEvt{iEvent}(1:4), EventDelimiter))
            currentNbEvent = currentNbEvent + 1;
        end
        
        % === WRITE EVENT TO FILE ===
        fwrite(fidEvtDest, [listEvt{iEvent}, sprintf('\n')]);
    end
    % Close last output .evt file
    if (fidEvtDest ~= -1)
        fclose(fidEvtDest);  
    end
end

% Close progress bar
bst_progress('stop');


%% ===== HELPERS =====
    function egiCloseFile()
        % Update output file header
        headerDest = headerSrc;
        headerDest.numSamples = SplitNbSamples(iSplitFile);
        % Seek to the beginning of file 
        fseek(fidDest, 0, -1);
        % Write updated header
        egi_write_header(fidDest, headerDest);
        % Close file
        fclose(fidDest);
        fidDest = [];
    end
end



