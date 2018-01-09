function [sFileOut, errMsg] = out_fopen(RawFile, FileFormat, sFileIn, ChannelMat)
% OUT_FOPEN: Saves the header of a new empty binary file.
%
% INPUTS:
%    - RawFile    : Full path of the file to create
%    - FileFormat : String ('EEG-EDF', 'BST-BIN', ...)
%    - sFileIn    : Structure of the header of the file to create
%    - ChannelMat : Channel file associated with the file to save

% @=============================================================================
% This function is part of the Brainstorm software:
% http://neuroimage.usc.edu/brainstorm
% 
% Copyright (c)2000-2018 University of Southern California & McGill University
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
% Authors: Francois Tadel, 2014-2017

% Output variables
sFileOut = [];
errMsg = [];
% Get default epoch size
EpochSize = bst_process('GetDefaultEpochSize', sFileIn);

% Trying to open the output file
try
    % Create file header
    switch (FileFormat)
        case 'EEG-EGI-RAW'
            sFileOut = out_fopen_egi(RawFile, sFileIn, ChannelMat);
        case 'BST-BIN'
            sFileOut = out_fopen_bst(RawFile, sFileIn, ChannelMat, EpochSize);
        case 'SPM-DAT'
            sFileOut = out_fopen_spm(RawFile, sFileIn, ChannelMat);
        case 'EEG-EDF'
            sFileOut = out_fopen_edf(RawFile, sFileIn, ChannelMat, EpochSize);
        case 'FIF'
            error('copy input file');
        case 'CTF-CONTINUOUS'
            error('copy input file');
        otherwise
            error('Unsupported file format');
    end
catch
    % Get error message
    e = lasterror();
    if ~isempty(e)
        errMsg = str_striptag(e.message);
    end
end
        
        


