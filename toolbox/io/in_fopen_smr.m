function [sFile, ChannelMat] = in_fopen_smr(DataFile)
% IN_FOPEN_SMR: Open a Cambridge Electronic Design Spike2 file (.smr/.son).

% @=============================================================================
% This function is part of the Brainstorm software:
% http://neuroimage.usc.edu/brainstorm
% 
% Copyright (c)2000-2017 University of Southern California & McGill University
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
% Authors:  Malcolm Lidierth, 2006-2007, King's College London
%           Adapted by Francois Tadel for Brainstorm, 2017


%% ===== READ HEADER =====
% Get file type
[fPath, fBase, fExt]=fileparts(DataFile);
if (strcmpi(fExt,'.smr') == 1)
    byteorder = 'b';  % Spike2 for Windows source file: little-endian
elseif strcmpi(fExt,'.son')==1
    byteorder = 'b';  % Spike2 for Mac file: Big-endian
else
    error('Not a Spike2 file.');
end
% Open file
fid = fopen(DataFile, 'r', byteorder);
if (fid == -1)
    error('Could not open file.');
end

% Get file header
hdr = SONFileHeader(fid);
% Get list of channels
iChan = 0;
for i = 1:hdr.channels
    bst_progress('text', sprintf('Reading channel info... [%d%%]', round(i/hdr.channels*100)));
    try
        c = SONChannelInfo(fid, i);
        if (c.kind >= 1) && (c.kind <= 9)   % Only look at channels that are active and useful
            iChan = iChan + 1;
            hdr.chaninfo(iChan).number  = i;
            hdr.chaninfo(iChan).kind    = c.kind;
            hdr.chaninfo(iChan).title   = c.title;
            hdr.chaninfo(iChan).comment = c.comment;
            hdr.chaninfo(iChan).phyChan = c.phyChan;
        end
    catch
        disp(['No information for channel #' num2str(i)]);
    end
end
% Close file
fclose(fid);


%% ===== FILL STRUCTURE =====
% Initialize returned file structure
sFile = db_template('sfile');
% Add information read from header
sFile.byteorder    = byteorder;
sFile.filename     = DataFile;
sFile.format       = 'EEG-SMR';
sFile.prop.sfreq   = double(hdr.sampling_freq);
sFile.prop.samples = [0, hdr.num_samples - 1];
sFile.prop.times   = sFile.prop.samples ./ sFile.prop.sfreq;
sFile.prop.nAvg    = 1;
sFile.channelflag  = ones(hdr.num_channels,1);
sFile.device       = 'Micromed';
sFile.header       = hdr;
% Comment: short filename
[fPath, fBase, fExt] = bst_fileparts(DataFile);
sFile.comment = fBase;





