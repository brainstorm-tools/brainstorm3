function isLatest = bst_check_appjar(BstJar)
% BST_CHECK_APPJAR:  Check current brainstorm.jar is the lastest (equal to one in GitHub)

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
% Authors: Raymundo Cassani, 2025

if nargin < 1 || isempty(BstJar)
    [installDir, bstDir] = fileparts(fileparts(fileparts(fileparts(mfilename('fullpath')))));
    BstJar = fullfile(installDir, bstDir, 'java', 'brainstorm.jar');
end

if ~bst_check_internet()
    disp(['BST> No internet connection.' 10 ...
          '     Latest version of "brainstorm.jar" could not be verified']);
    isLatest = [];
    return
end

% Download brainstorm.jar from GitHub
BstJarGH =  file_unique(BstJar);
bst_webread('https://github.com/brainstorm-tools/bst-java/raw/master/brainstorm/dist/brainstorm.jar', BstJarGH);
% Binary comparison of files
fid1 = fopen(BstJar,   'rb');
fid2 = fopen(BstJarGH, 'rb');
data1 = fread(fid1, inf, '*uint8');
data2 = fread(fid2, inf, '*uint8');
fclose(fid1);
fclose(fid2);
delete(BstJarGH);
isLatest = isequal(data1, data2);
