function varargout = bst_unzip(zipFilename, varargin)
% BST_UNZIP: Unzip wrapper function.
% This function abstracts the activation of different features regarding unzipping 
% within matlab. Depending on behaviour it retries the unzip call with previous versions.
%
% USAGE: fileNames = bst_unzip(zipFileName)
%        fileNames = bst_unzip(zipFileName, outputFolder)
%
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
% Authors: Juan GPC, Francois Tadel, 2021

narginchk(1,2);
nargoutchk(0,1);

try
    varargout = unzip(zipFilename, varargin{:});
catch
    if ~file_exist(zipFilename)
        error(['File does not exist: ' zipFilename]);
    elseif (bst_get('MatlabVersion') >= 910)
        disp(['BST> Error unzipping the file: ' zipFilename]);
        disp('BST> Attempting rollback to previous unzip function. [feature(''ZIPV2'',''off'')]');
        feature('ZIPV2','off')
        varargout = unzip(zipFilename, varargin{:});
        feature('ZIPV2','on')
    else
        error(['Error unzipping the file: ' zipFilename 10 lasterr]);
    end
end


