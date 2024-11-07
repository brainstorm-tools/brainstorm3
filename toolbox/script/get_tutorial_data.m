function dataFullFile = get_tutorial_data(dataDir, dataFile, bstUser, bstPwd)
% GET_TUTORIAL_DATA check if the 'dataFile' needed for tutorial scripts is in 'dataDir'
%                   otherwise, if BST user and password are provided, data is downloaded from server
%
% USAGE: get_tutorial_data(dataDir, dataFile, bstUser, bstPwd)
%
% INPUTS:
%    - dataDir  : Directory to search (or save) dataFile
%    - dataFile : File to search (or download)
%    - bstUser  : (opt) BST user               (default = empty)
%    - bstPwd   : (opt) Password for BST user  (default = empty)
%
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
% Authors: Raymundo Cassani, 2024


%% ===== PARAMETERS =====
if nargin < 2
    error('At least two parameters are needed');
end
if nargin <= 3 || isempty(bstUser) || isempty(bstPwd)
    bstUser = '';
    bstPwd  = '';
end


%% ===== GET FILE =====
% Search or download dataFile for tutorial
dataFullFile = bst_fullfile(dataDir, dataFile);
% Try to download if file does not exist
if ~exist(dataFullFile, 'file')
    if ~isempty(bstUser) && ~isempty(bstPwd)
        dwnUrl = sprintf('http://neuroimage.usc.edu/bst/download.php?file=%s&user=%s&mdp=%s', ...
                         urlencode(dataFile), urlencode(bstUser), urlencode(bstPwd));
        dataFullFile = bst_fullfile(dataDir, dataFile);
        errMsg = bst_websave(dataFullFile, dwnUrl);
        % Return if error
        if ~isempty(errMsg) || ~exist(dataFullFile, 'file')
            dataFullFile = '';
            return
        end
    else
        dataFullFile = '';
        return
    end
end
% Check size, if less than 50 bytes, error with the downloaded file
d = dir(dataFullFile);
if d.bytes < 50
    dataFullFile = '';
    return
end
