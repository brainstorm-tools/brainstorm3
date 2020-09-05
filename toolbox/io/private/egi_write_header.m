function header = egi_writeRawHeader( fid, header )
% Write EGI RAW header structure to an open file.
%
% USAGE:  header = egi_writeRawHeader( fid, header )
%
% INPUT:
%    - fid    : Matlab file handle to the EGI RAW file (file must be already open)
%    - header : Header structure of the same file
% OUTPUT:
%    - epochLength : length (in number of time samples) of each epoch in the RAW file

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

% WRITE RAW HEADER
fwrite(fid, header.versionNumber,           'integer*4');
fwrite(fid, header.recordingTime.Year     , 'integer*2');
fwrite(fid, header.recordingTime.Month    , 'integer*2');
fwrite(fid, header.recordingTime.Day      , 'integer*2');
fwrite(fid, header.recordingTime.Hour     , 'integer*2');
fwrite(fid, header.recordingTime.Minute   , 'integer*2');
fwrite(fid, header.recordingTime.Second   , 'integer*2');
fwrite(fid, header.recordingTime.Millisec , 'integer*4');
fwrite(fid, header.samplingRate           , 'integer*2');
fwrite(fid, header.numChans               , 'integer*2');
fwrite(fid, header.boardGain              , 'integer*2');
fwrite(fid, header.numConvBits            , 'integer*2');
fwrite(fid, header.ampRange               , 'integer*2');
fwrite(fid, header.numSamples             , 'integer*4');
fwrite(fid, header.numEvents              , 'integer*2');
 
% WRITE EVENTS
if (header.numEvents ~= 0)  % File contains event info.
    for i = 1:header.numEvents
        fwrite(fid, header.eventCodes{i}, 'uchar');
    end
end


