function header = egi_read_header(fid)
% EGI_READ_HEADER: Read header from an open EGI .raw file.
%
% USAGE:  header = egi_read_header(fid);

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

% ===== READ RAW HEADER =====
header.versionNumber          = fread(fid, 1, 'integer*4');
header.recordingTime.Year     = fread(fid, 1, 'integer*2');
header.recordingTime.Month    = fread(fid, 1, 'integer*2');
header.recordingTime.Day      = fread(fid, 1, 'integer*2');
header.recordingTime.Hour     = fread(fid, 1, 'integer*2');
header.recordingTime.Minute   = fread(fid, 1, 'integer*2');
header.recordingTime.Second   = fread(fid, 1, 'integer*2');
header.recordingTime.Millisec = fread(fid, 1, 'integer*4');
header.samplingRate           = fread(fid, 1, 'integer*2');
header.numChans               = fread(fid, 1, 'integer*2');
header.boardGain              = fread(fid, 1, 'integer*2');
header.numConvBits            = fread(fid, 1, 'integer*2');
header.ampRange               = fread(fid, 1, 'integer*2');

% ===== DATA FORMAT =====
switch header.versionNumber
    case {2,3}
        header.byteformat = 'integer*2';
        header.bytesize   = 2;
    case {4,5}
        header.byteformat = 'real*4'; 
        header.bytesize   = 4;
    case {6,7}
        header.byteformat = 'real*8'; 
        header.bytesize   = 8;
    otherwise
        fclose(fid);
        error('Brainstorm:InvalidRawFile', 'Error (Version ID): %d', header.versionNumber);
end
isReadCell = ismember(header.versionNumber, [3 5 7]);
if isReadCell
    fclose(fid);
    error('Support only for continuous EGI RAW files.');
end

% % ===== READ CELL NAMES =====
% if isReadCell
%     header.numCell = fread(fid, 1, 'int16');
%     % Read cells info
%     header.cellCodes = cell(1,header.numCell);
%     for i = 1 : header.numCell
%         codeSize = fread(fid, 1, 'int8');
%         header.cellCodes{i} = fread(fid, [1, codeSize], '*char');
%     end
%     metaData.nSeg = fread(fid, 1, 'int16');
% else
%     header.numCell = 0;
%     header.nSeg = 0;
%     header.cellCodes = {};
% end

% ===== READ EVENTS =====
header.numSamples = fread(fid, 1, 'integer*4');
header.numEvents  = fread(fid, 1, 'integer*2');
% File contains event info.
if (header.numEvents ~= 0) 
    header.eventCodes = cell(header.numEvents, 1);
    for i = 1:header.numEvents
        header.eventCodes{i} = fread(fid, [1 4], '*char');
    end
else  % File does not contain event info.
    % warning('Brainstorm:IncompleteRawFile', 'RAW File does not contain event information');
    header.evtCode = [];
end

% Save beginning of the data block
header.datapos = ftell(fid);




