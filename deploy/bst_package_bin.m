function bst_package_bin(McrVersion)
% Packagage binary distributions.
% 
% USAGE:  bst_package_bin('R2012b')
%         bst_package_bin('R2013b')
%         bst_package_bin('R2014a')

% @=============================================================================
% This software is part of the Brainstorm software:
% http://neuroimage.usc.edu/brainstorm
% 
% Copyright (c)2000-2016 University of Southern California & McGill University
% This software is distributed under the terms of the GNU General Public License
% as published by the Free Software Foundation. Further details on the GPL
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
% Authors: Francois Tadel, 2013

% Root brainstorm directory
bstDir = fileparts(fileparts(which(mfilename)));
% Deploy folder
deployDir = fullfile(fileparts(bstDir), 'brainstorm3_deploy');
baseDir = fullfile(deployDir, 'brainstorm3');
destDir = fullfile(deployDir, 'brainstorm3', 'bin', McrVersion);
srcDir  = fullfile(bstDir, 'bin', McrVersion);

% Check if distribution is available
if ~isdir(srcDir)
    error(['Distribution is not available: "' srcDir '"']);
end

% Delete existing folder brainstorm3_deploy/brainstorm3
if isdir(baseDir)
    try
        rmdir(baseDir, 's');
    catch
        error(['Could not delete folder: "' baseDir '"']);
    end
end
% Create again dir
isCreated = mkdir(destDir);
if ~isCreated
    error(['Cannot create output directory:' destDir]);
end

% Copy everything from srcDir to destDir
copyfile(fullfile(srcDir, '*.*'), destDir);

% Get date string
c = clock;
strDate = sprintf('%02d%02d%02d', c(1)-2000, c(2), c(3));
% Create output filename
zipFile = fullfile(deployDir, ['bst_bin_' McrVersion '_' strDate '.zip']);

% Zip folder
zip(zipFile, baseDir, fileparts(baseDir));

% Delete newly created dir
try
    rmdir(baseDir, 's');
catch
    error(['Could not delete folder: "' baseDir '"']);
end




