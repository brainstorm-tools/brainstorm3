function OutputFile = export_ssp(Projectors, ChannelNames, OutputFile)
% IMPORT_SSP: Saves SSP projectors to a file.
%
% USAGE:  SspFile = export_ssp(Projectors, ChannelNames, OutputFile=Ask)

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
% Authors: Francois Tadel, 2014

% Ask for filename if not defined
if (nargin < 2) || isempty(OutputFile)
    % Build a default file name
    OutputFile = bst_process('GetNewFilename', '', 'proj.mat');
    [fPath,fBase,fExt] = bst_fileparts(OutputFile);
    OutputFile = [fBase,fExt];
    % Get filename where to store the filename
    [OutputFile, ProjFormat] = java_getfile('save', 'Save projectors', OutputFile, 'single', 'files', ...
                            {{'.fif'}, 'Elekta-Neuromag/MNE (*.fif)',        'FIF'; ...
                            {'_proj'}, 'Brainstorm SSP (*proj*.mat)', 'BST'}, 2);
    if isempty(OutputFile)
        return;
    end
end

% Get file extension
[fPath, fBase, fExt] = bst_fileparts(OutputFile);
% Save file
switch (fExt)
    case '.fif'
        out_projector_fif(OutputFile, ChannelNames, Projectors);
    case '.mat'
        NewMat.Projector = Projectors;
        bst_save(OutputFile, NewMat, 'v7');
    otherwise
        error(['Unknown file extension "' fExt '"']);
end










