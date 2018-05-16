function [ChannelMat, header] = in_channel_ctf( ds_directory )
% IN_CHANNEL_CTF: Read a CTF .ds directory, and return a brainstorm Channel structure
%
% USAGE:  ChannelMat = in_channel_ctf( ds_directory );

% @=============================================================================
% This function is part of the Brainstorm software:
% https://neuroimage.usc.edu/brainstorm
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
% Authors: Francois Tadel, 2009

% Initialize returned structure
ChannelMat = db_template('channelmat');
ChannelMat.Comment = 'CTF channels';
                
% Make sure to get the directory (and not the .meg4 or .res4 file)
if ~isdir(ds_directory)
    ds_directory = bst_fileparts(ds_directory);
end
[DataSetName, meg4_files, res4_file] = ctf_get_files(ds_directory);

% Load Res4 mat
[header, ChannelMat] = ctf_read_res4( res4_file );

                
                
                





