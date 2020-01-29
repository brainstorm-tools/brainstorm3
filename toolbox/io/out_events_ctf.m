function out_events_ctf( sFile, EventsFile )
% OUT_EVENTS_CTF: Export events to a CTF MarkerFile.mrk
%
% USAGE:  out_events_ctf( sFile, EventsFile )

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
% Authors: Francois Tadel, 2012-2013

% Convert to epoched CTF
if strcmpi(sFile.format, 'CTF-CONTINUOUS')
    sFile = process_ctf_convert('Compute', sFile, 'epoch');
end

% Get events structure
evt = sFile.events;
% Open output file
fout = fopen(EventsFile, 'w');
if (fout < 0)
    warning('Cannot open file.');
    return
end

% Write the header of the file
fprintf(fout, 'PATH OF DATASET:\n%s\n\n\n', sFile.filename);
fprintf(fout, 'NUMBER OF MARKERS:\n%d\n', length(evt));

% Write all the value changes
for iEvt = 1:length(evt)
    nsmp = size(evt(iEvt).times, 2);
    color = round(evt(iEvt).color .* (256*256-1));
    fprintf(fout, '\n\nCLASSGROUPID:\n%d\n', 3);
    fprintf(fout, 'NAME:\n%s\n', evt(iEvt).label);
    fprintf(fout, 'COMMENT:\nExported from Brainstorm\n');
    fprintf(fout, 'COLOR:\n#%s%s%s\n', dec2hex(color(1),4), dec2hex(color(2),4), dec2hex(color(3),4));
    fprintf(fout, 'EDITABLE:\nYes\n');
    fprintf(fout, 'CLASSID:\n%d\n', iEvt);
    fprintf(fout, 'NUMBER OF SAMPLES:\n%d\n', nsmp);
    fprintf(fout, 'LIST OF SAMPLES:\n');
    fprintf(fout, 'TRIAL NUMBER		TIME FROM SYNC POINT (in seconds)\n');
    % Loop on each occurrence
    for iOcc = 1:nsmp
        fprintf(fout, '             %d          %4.6f\n', evt(iEvt).epochs(iOcc) - 1, evt(iEvt).times(1,iOcc));
    end
end
fprintf(fout, '\n\n');
% Close file
fclose(fout);





