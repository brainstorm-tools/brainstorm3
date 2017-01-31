function [sFile, ChannelMat] = in_fopen_ant(DataFile)
% IN_FOPEN_ANT: Open an ANT EEProbe .cnt file (continuous recordings).
%
% USAGE:  [sFile, ChannelMat] = in_fopen_ant(DataFile)

% @=============================================================================
% This function is part of the Brainstorm software:
% http://neuroimage.usc.edu/brainstorm
% 
% Copyright (c)2000-2016 University of Southern California & McGill University
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
% Authors: Francois Tadel, 2012-2014
        

%% ===== READ HEADER =====
% Read a small block of data, to get all the extra information
hdr = read_eep_cnt(DataFile, 1, 2);

% Initialize returned file structure
sFile = db_template('sfile');
% Add information read from header
sFile.byteorder  = 'l';
sFile.filename   = DataFile;
sFile.format     = 'EEG-ANT-CNT';
sFile.prop.sfreq = double(hdr.rate);
sFile.device     = 'ANT';
sFile.header     = hdr;
% Comment: short filename
[fPath, fBase, fExt] = bst_fileparts(DataFile);
sFile.comment = fBase;
% Time and samples indices
sFile.prop.samples = [0, hdr.nsample - 1];
sFile.prop.times   = sFile.prop.samples ./ sFile.prop.sfreq;
sFile.prop.nAvg    = 1;
% Get bad channels
sFile.channelflag = ones(hdr.nchan, 1);


%% ===== EVENT FILE =====   
% If a .trg file exists with the same name: load it
[fPath, fBase, fExt] = bst_fileparts(DataFile);
TrgFile = bst_fullfile(fPath, [fBase '.trg']);
% If file exists
if file_exist(TrgFile)
    [sFile, newEvents] = import_events(sFile, [], TrgFile, 'ANT');
end


%% ===== CREATE DEFAULT CHANNEL FILE =====
% Create channel structure
Channel = repmat(db_template('channeldesc'), [1 hdr.nchan]);
for i = 1:hdr.nchan
    Channel(i).Name    = hdr.label{i};
    Channel(i).Type    = 'EEG';
    Channel(i).Orient  = [];
    Channel(i).Weight  = 1;
    Channel(i).Comment = [];
    Channel(i).Loc = [0; 0; 0];
end
ChannelMat.Comment = 'ANT standard position';
ChannelMat.Channel = Channel;
     



