function errMsg = bst_websave(filename, url)
% BST_WEBSAVE: Save the content of a URL to a file

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
% Authors: Francois Tadel, 2020

% Reading function: urlread replaced with webread in Matlab 2014b
if (bst_get('MatlabVersion') <= 803)
    url_read_fcn = @(f,u)urlwrite(u,f);
    url_read_alt = @(f,u)websave(f,u);
else
    url_read_fcn = @(f,u)websave(f,u);
    url_read_alt = @(f,u)urlwrite(u,f);
end
% Read online version.txt
errMsg = '';
try
    url_read_fcn(filename, url);
catch
    err = lasterror;
    try
        url_read_alt(filename, url);
    catch
        errMsg = ['websave and urlwrite failed reading URL: ' url 10 str_striptag(err.message)];
        disp(['BST> ERROR: ' errMsg]);
    end
end
